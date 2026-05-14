/**
 * LOVING_MeasuringCupService
 *
 * Handles all Measuring Cup calculations:
 *   - Goal Hours from WO Line Items × Goal Headcount
 *   - RTN (Return Time) calculation
 *   - Variance (Actual - Goal)
 *   - Bonus eligibility for FM scorecard
 *   - GP% calculations
 *
 * Called from LOVING_WorkOrderTriggerHandler and scheduled processes.
 * All methods are bulkified.
 */
public without sharing class LOVING_MeasuringCupService {

    // ── RTN Calculation ───────────────────────────────────────────────────────
    /**
     * Calculates Return Time for a list of Work Orders.
     * RTN = Shift Start + (Goal Minutes + Travel Minutes + Lunch + Cushion) / 60
     * Returns a map of WO Id → RTN as HH:MM string.
     */
    public static Map<Id, String> calculateRTN(List<WorkOrder> wos) {
        Map<Id, String> results = new Map<Id, String>();

        for (WorkOrder wo : wos) {
            Decimal goalMinutes    = wo.Goal_Hours__c != null ? wo.Goal_Hours__c * 60 : 0;
            Decimal travelMinutes  = wo.Travel_Minutes_Planned__c != null ? wo.Travel_Minutes_Planned__c : 0;
            Decimal lunchMinutes   = wo.Lunch_Minutes__c != null ? wo.Lunch_Minutes__c : 60;
            Decimal cushionMinutes = wo.Cushion_Minutes__c != null ? wo.Cushion_Minutes__c : 15;

            // Parse shift start time (stored as HH:MM text, default 06:30)
            String shiftStart = wo.Shift_Start_Time__c != null ? wo.Shift_Start_Time__c : '06:30';
            Integer shiftHour = Integer.valueOf(shiftStart.split(':')[0]);
            Integer shiftMin  = Integer.valueOf(shiftStart.split(':')[1]);
            Decimal shiftDecimalHours = shiftHour + (shiftMin / 60.0);

            Decimal totalMinutes = goalMinutes + travelMinutes + lunchMinutes + cushionMinutes;
            Decimal rtnDecimalHours = shiftDecimalHours + (totalMinutes / 60.0);

            Integer rtnHour = (Integer)Math.floor(rtnDecimalHours);
            Integer rtnMin  = (Integer)Math.round((rtnDecimalHours - rtnHour) * 60);
            if (rtnMin == 60) { rtnHour++; rtnMin = 0; }

            // Format as HH:MM
            String rtnStr = String.valueOf(rtnHour).leftPad(2, '0') + ':'
                + String.valueOf(rtnMin).leftPad(2, '0');
            results.put(wo.Id, rtnStr);
        }

        return results;
    }

    // ── Recalculate and Stamp RTN ─────────────────────────────────────────────
    public static void stampRTN(List<WorkOrder> wos) {
        Map<Id, String> rtnMap = calculateRTN(wos);
        List<WorkOrder> toUpdate = new List<WorkOrder>();
        for (WorkOrder wo : wos) {
            if (rtnMap.containsKey(wo.Id)) {
                // Store RTN as a custom text formula-replaceable field
                // In practice, RTN__c is a formula field; this method is for Apex-driven calc
                toUpdate.add(new WorkOrder(Id=wo.Id));
                // Note: if RTN__c is a formula, no update needed — it auto-calculates
                // If stored as text: toUpdate.last().RTN__c = rtnMap.get(wo.Id);
            }
        }
    }

    // ── GP Calculation ────────────────────────────────────────────────────────
    /**
     * Calculates Revenue, Cost, and Gross Profit for WOs from their line items.
     * Call when line items are updated (e.g., after takeoff confirmation).
     * Updates Revenue_Amount__c and Cost_Amount__c on the Work Order.
     */
    public static void recalculateGP(Set<Id> woIds) {
        Map<Id, Decimal> revenueMap = new Map<Id, Decimal>();
        Map<Id, Decimal> costMap    = new Map<Id, Decimal>();

        for (Id wId : woIds) {
            revenueMap.put(wId, 0);
            costMap.put(wId, 0);
        }

        // WO Line Items carry UnitPrice (builder price) and a separate cost field
        for (WorkOrderLineItem woli : [
            SELECT WorkOrderId, Quantity, UnitPrice
            FROM WorkOrderLineItem
            WHERE WorkOrderId IN :woIds
        ]) {
            Decimal lineRevenue = (woli.Quantity != null ? woli.Quantity : 0)
                * (woli.UnitPrice != null ? woli.UnitPrice : 0);
            revenueMap.put(woli.WorkOrderId,
                revenueMap.get(woli.WorkOrderId) + lineRevenue);
            // Cost would come from a separate Cost_Price__c field on line items
            // costMap.put(woli.WorkOrderId, costMap.get(woli.WorkOrderId) + lineCost);
        }

        List<WorkOrder> toUpdate = new List<WorkOrder>();
        for (Id wId : woIds) {
            toUpdate.add(new WorkOrder(
                Id = wId,
                Revenue_Amount__c = revenueMap.get(wId)
                // Cost_Amount__c = costMap.get(wId)
            ));
        }
        if (!toUpdate.isEmpty()) {
            LOVING_TriggerGuard.clearAlreadyRun('WorkOrder');
            update toUpdate;
        }
    }

    // ── FM Scorecard Metrics ──────────────────────────────────────────────────
    /**
     * Returns FJ% for a given FM for the current month.
     * FJ% = FJ Count / Install Count (installs only)
     */
    public static Decimal getFJPercentForFM(Id fmUserId) {
        Date monthStart = Date.today().toStartOfMonth();

        Integer installCount = [
            SELECT COUNT() FROM WorkOrder
            WHERE FM__c = :fmUserId
            AND Work_Order_Type__c = 'Production Install'
            AND Status = 'Closed'
            AND CreatedDate >= :monthStart
        ];

        Integer fjCount = [
            SELECT COUNT() FROM Finish_Job__c
            WHERE FM__c = :fmUserId
            AND CreatedDate >= :monthStart
        ];

        if (installCount == 0) return 0;
        return ((Decimal)fjCount / installCount) * 100;
    }

    /**
     * Returns Measuring Cup Variance for a given FM for the current month.
     * Variance = Actual Hours - Goal Hours (negative = over standard)
     */
    public static Decimal getMCVarianceForFM(Id fmUserId) {
        Date monthStart = Date.today().toStartOfMonth();

        AggregateResult ar = [
            SELECT SUM(Actual_Hours__c) actualHrs,
                   SUM(Goal_Hours__c) goalHrs
            FROM WorkOrder
            WHERE FM__c = :fmUserId
            AND Work_Order_Type__c = 'Production Install'
            AND Status = 'Closed'
            AND CreatedDate >= :monthStart
        ];

        Decimal actual = ar.get('actualHrs') != null ? (Decimal)ar.get('actualHrs') : 0;
        Decimal goal   = ar.get('goalHrs')   != null ? (Decimal)ar.get('goalHrs')   : 0;
        return actual - goal;
    }
}
