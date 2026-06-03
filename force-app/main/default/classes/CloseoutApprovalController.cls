/**
 * CloseoutApprovalController
 * Returns WorkOrders with Status='Completed' that are awaiting Field Manager
 * closeout sign-off (Crew_Completed__c = true, Loading_Check_Completed__c = true
 * but no Invoice_Amount__c set yet).
 *
 * Screen 20 — Closeout Approval Queue
 */
public with sharing class CloseoutApprovalController {

    // ─── Inner classes ───────────────────────────────────────────────────────

    public class WoRow {
        @AuraEnabled public Id       woId;
        @AuraEnabled public String   woNumber;
        @AuraEnabled public String   lotInfo;            // Lot__r.Name or Subject
        @AuraEnabled public String   jobType;
        @AuraEnabled public Integer  photoCount;         // Takeoff_Photo_Count__c + Closeout_Photo_Count__c
        @AuraEnabled public Decimal  billedAmt;          // GrandTotal
        @AuraEnabled public Decimal  invoiceAmt;         // Invoice_Amount__c
        @AuraEnabled public Boolean  variance;           // Invoice_Amount__c != null && Invoice_Amount__c != GrandTotal
        @AuraEnabled public String   notes;
        @AuraEnabled public String   status;
        @AuraEnabled public DateTime fieldCompleteDate;
    }

    public class CloseoutView {
        @AuraEnabled public Integer     total;
        @AuraEnabled public Integer     variance;
        @AuraEnabled public List<WoRow> rows;
    }

    // ─── Public read method ──────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static CloseoutView getQueue() {
        if (!Schema.sObjectType.WorkOrder.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Work Order records.');
        }

        List<WorkOrder> wos = [
            SELECT Id,
                   WorkOrderNumber,
                   Subject,
                   Lot__c,
                   Lot__r.Name,
                   Job_Type__c,
                   GrandTotal,
                   Invoice_Amount__c,
                   Invoice_Notes__c,
                   Status,
                   Crew_Completed__c,
                   Loading_Check_Completed__c,
                   Field_Complete_Date__c,
                   Takeoff_Photo_Count__c,
                   Closeout_Photo_Count__c
            FROM WorkOrder
            WHERE Status = 'Completed'
              AND Crew_Completed__c = true
            ORDER BY Field_Complete_Date__c DESC NULLS LAST
            LIMIT 100
        ];

        return buildView(wos);
    }

    // ─── Testable helper ─────────────────────────────────────────────────────

    @TestVisible
    private static CloseoutView buildView(List<WorkOrder> wos) {
        CloseoutView view = new CloseoutView();
        view.rows         = new List<WoRow>();
        view.total        = 0;
        view.variance     = 0;

        for (WorkOrder wo : wos) {
            WoRow row = new WoRow();
            row.woId    = wo.Id;
            row.woNumber = wo.WorkOrderNumber;
            row.lotInfo  = (wo.Lot__r != null && String.isNotBlank(wo.Lot__r.Name))
                            ? wo.Lot__r.Name
                            : wo.Subject;
            row.jobType  = wo.Job_Type__c;
            row.status   = wo.Status;
            row.notes    = wo.Invoice_Notes__c;

            // Photo count — guard for null
            Integer takeoff  = wo.Takeoff_Photo_Count__c  != null ? (Integer) wo.Takeoff_Photo_Count__c  : 0;
            Integer closeout = wo.Closeout_Photo_Count__c != null ? (Integer) wo.Closeout_Photo_Count__c : 0;
            row.photoCount = takeoff + closeout;

            row.billedAmt  = wo.GrandTotal;
            row.invoiceAmt = wo.Invoice_Amount__c;

            Boolean hasVariance = (wo.Invoice_Amount__c != null && wo.Invoice_Amount__c != wo.GrandTotal);
            row.variance = hasVariance;

            row.fieldCompleteDate = wo.Field_Complete_Date__c;

            if (hasVariance) {
                view.variance++;
            }
            view.total++;
            view.rows.add(row);
        }

        return view;
    }

    // ─── Action method ───────────────────────────────────────────────────────

    @AuraEnabled
    public static void approveCloseout(Id workOrderId, String notes) {
        if (!Schema.sObjectType.WorkOrder.isUpdateable()) {
            throw new AuraHandledException('Insufficient access to update Work Order records.');
        }
        try {
            update new WorkOrder(
                Id               = workOrderId,
                Invoice_Notes__c = notes
            );
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }
}
