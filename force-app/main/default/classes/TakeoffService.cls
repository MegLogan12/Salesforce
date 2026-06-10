/**
 * TakeoffService
 * Stage 5 — Takeoff Performed
 * Stage 6 — Takeoff Complete → Ready to Schedule
 *
 * Handles:
 *   - Geotag distance validation (must be within 150m of lot address)
 *   - Takeoff submission locking (FM cannot edit after submission)
 *   - Ops Manager approval/return routing
 *   - Auto-advance to Ready to Schedule on approval
 *   - Escalation if takeoff not submitted within 48 hours of starting
 */
public with sharing class TakeoffService {

    private static final Double MAX_GEOTAG_DISTANCE_METERS = 150.0;

    // ─────────────────────────────────────────────
    // GEOTAG VALIDATION
    // Called from WorkOrderHandler.validateTakeoffSubmission (before trigger)
    // ─────────────────────────────────────────────
    public static Boolean isGeotagValid(Work_Order__c wo) {
        if (wo.Takeoff_Geotag_Lat__c == null || wo.Takeoff_Geotag_Lng__c == null) return false;
        if (wo.Lot_Latitude__c == null || wo.Lot_Longitude__c == null) return true; // skip if lot not geocoded yet

        Double distance = haversineDistanceMeters(
            (Double)wo.Lot_Latitude__c,   (Double)wo.Lot_Longitude__c,
            (Double)wo.Takeoff_Geotag_Lat__c, (Double)wo.Takeoff_Geotag_Lng__c
        );
        return distance <= MAX_GEOTAG_DISTANCE_METERS;
    }

    // ─────────────────────────────────────────────
    // OPS MANAGER APPROVAL
    // ─────────────────────────────────────────────

    /**
     * Approves the takeoff.
     * Sets Takeoff_Status__c = 'Locked', advances WO to Ready to Schedule.
     */
    public static void approveTakeoff(Id workOrderId) {
        Work_Order__c wo = [
            SELECT Id, Takeoff_Status__c, Status__c, Requested_Install_Date__c
            FROM Work_Order__c WHERE Id = :workOrderId
        ];

        if (wo.Takeoff_Status__c != 'Submitted for Approval') {
            throw new TakeoffException('Cannot approve a takeoff that is not in "Submitted for Approval" status. Current status: ' + wo.Takeoff_Status__c);
        }

        wo.Takeoff_Status__c = 'Locked';
        wo.Status__c         = 'Ready to Schedule';
        wo.Takeoff_Approved_Date__c = Date.today();
        update wo;

        // Notify Scheduling Manager
        EscalationService.notifySchedulingManagerReadyToSchedule(wo.Id);
    }

    /**
     * Returns the takeoff to the FM for correction.
     * Increments NFI_Count__c. Notifies FM with reason.
     * If NFI_Count > 2: escalates to COO.
     */
    public static void returnTakeoffForCorrection(Id workOrderId, String returnReason) {
        if (String.isBlank(returnReason)) {
            throw new TakeoffException('Return Reason is required when returning a takeoff for correction.');
        }

        Work_Order__c wo = [
            SELECT Id, Takeoff_Status__c, NFI_Count__c, FM_Assignment__c
            FROM Work_Order__c WHERE Id = :workOrderId
        ];

        wo.Takeoff_Status__c    = 'Returned';
        wo.NFI_Count__c         = (wo.NFI_Count__c == null ? 0 : wo.NFI_Count__c) + 1;
        wo.Takeoff_Return_Reason__c = returnReason;
        update wo;

        if (wo.NFI_Count__c > 2) {
            EscalationService.escalateTakeoffTooCOO(wo.Id, (Integer)wo.NFI_Count__c);
        } else {
            EscalationService.notifyFMTakeoffReturned(wo.Id, returnReason);
        }
    }

    // ─────────────────────────────────────────────
    // 48-HOUR SLA ESCALATION
    // ─────────────────────────────────────────────
    public static void checkTakeoffSLA() {
        Datetime cutoff = Datetime.now().addHours(-48);
        List<Work_Order__c> overdue = [
            SELECT Id, Name, FM_Assignment__c, Takeoff_Started_Date__c
            FROM Work_Order__c
            WHERE Takeoff_Status__c = 'In Progress'
            AND Takeoff_Started_Date__c <= :cutoff
        ];

        for (Work_Order__c wo : overdue) {
            EscalationService.escalateTakeoffSLABreach(wo.Id);
        }
    }

    // ─────────────────────────────────────────────
    // HAVERSINE DISTANCE (meters)
    // ─────────────────────────────────────────────
    private static Double haversineDistanceMeters(
        Double lat1, Double lng1,
        Double lat2, Double lng2
    ) {
        Double earthRadius = 6371000; // meters
        Double dLat = (lat2 - lat1) * Math.PI / 180.0;
        Double dLng = (lng2 - lng1) * Math.PI / 180.0;
        Double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(lat1 * Math.PI / 180.0) * Math.cos(lat2 * Math.PI / 180.0)
                 * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return earthRadius * c;
    }

    public class TakeoffException extends Exception {}
}