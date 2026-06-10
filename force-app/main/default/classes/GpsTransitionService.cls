/**
 * GpsTransitionService
 * Stage 9 — Mobile crew flow
 *
 * Invoked from GpsRestResource (mobile) or test classes. Two actions:
 *
 *  beginDrive(workOrderId, lat, lng)
 *      - Precondition: Morning_Check_Complete__c = true
 *      - Effect: Drive_Started_At__c = now, Drive_Start_Lat/Lng captured,
 *                Status__c = 'In Route'
 *
 *  gpsPing(workOrderId, lat, lng)
 *      - Stores Last_GPS_Ping_At__c + Last_GPS_Lat/Lng
 *      - If distance to (Lot_Latitude__c, Lot_Longitude__c) <= Geofence_Radius_M__c
 *        (default 150m) AND Arrived_At__c is null, the WO auto-transitions:
 *          Arrived_At__c = now
 *          Arrival_Lat/Lng captured
 *          Status__c = 'In Progress'
 *
 * Designed to be called repeatedly — idempotent once arrived.
 */
public with sharing class GpsTransitionService {

    public class GpsException extends Exception {}

    public static WorkOrder beginDrive(Id workOrderId, Decimal lat, Decimal lng) {
        if (workOrderId == null) throw new GpsException('workOrderId is required');
        WorkOrder wo = [
            SELECT Id, Status__c, Morning_Check_Complete__c,
                   Drive_Started_At__c, Drive_Start_Lat__c, Drive_Start_Lng__c
            FROM WorkOrder WHERE Id = :workOrderId LIMIT 1
        ];
        if (wo.Morning_Check_Complete__c != true) {
            throw new GpsException('Morning Vehicle Check must be completed before Begin Drive.');
        }
        wo.Drive_Started_At__c = System.now();
        wo.Drive_Start_Lat__c  = lat;
        wo.Drive_Start_Lng__c  = lng;
        if (wo.Status__c != 'In Progress') wo.Status__c = 'In Route';
        update wo;
        return wo;
    }

    public static WorkOrder gpsPing(Id workOrderId, Decimal lat, Decimal lng) {
        if (workOrderId == null) throw new GpsException('workOrderId is required');
        WorkOrder wo = [
            SELECT Id, Status__c, Lot_Latitude__c, Lot_Longitude__c,
                   Geofence_Radius_M__c, Arrived_At__c, Arrival_Lat__c, Arrival_Lng__c,
                   Last_GPS_Ping_At__c, Last_GPS_Lat__c, Last_GPS_Lng__c
            FROM WorkOrder WHERE Id = :workOrderId LIMIT 1
        ];

        wo.Last_GPS_Ping_At__c = System.now();
        wo.Last_GPS_Lat__c     = lat;
        wo.Last_GPS_Lng__c     = lng;

        Decimal radiusM = (wo.Geofence_Radius_M__c == null ? 150 : wo.Geofence_Radius_M__c);

        if (wo.Arrived_At__c == null && wo.Lot_Latitude__c != null && wo.Lot_Longitude__c != null) {
            Double meters = AutoScheduleService.haversineMeters(
                lat, lng, wo.Lot_Latitude__c, wo.Lot_Longitude__c
            );
            if (meters <= radiusM.doubleValue()) {
                wo.Arrived_At__c = System.now();
                wo.Arrival_Lat__c = lat;
                wo.Arrival_Lng__c = lng;
                wo.Status__c = 'In Progress';
            }
        }
        update wo;
        return wo;
    }

    /**
     * Promote a Proposed schedule to the real Scheduled_Date/Crew once the
     * Scheduling Manager flips Schedule_Proposal_Status__c to 'Manager Approved'.
     * Called from WorkOrderHandler before update.
     */
    public static void promoteApprovedProposals(List<WorkOrder> newList, Map<Id,WorkOrder> oldMap) {
        for (WorkOrder wo : newList) {
            WorkOrder old = (oldMap == null) ? null : oldMap.get(wo.Id);
            Boolean justApproved =
                wo.Schedule_Proposal_Status__c == 'Manager Approved' &&
                (old == null || old.Schedule_Proposal_Status__c != 'Manager Approved');
            if (!justApproved) continue;

            if (wo.Proposed_Schedule_Date__c != null) wo.Scheduled_Date__c = wo.Proposed_Schedule_Date__c;
            if (wo.Proposed_Crew__c != null)          wo.Crew__c           = wo.Proposed_Crew__c;
            wo.Status__c          = 'Scheduled';
            wo.Schedule_Locked__c = true; // fires existing SchedulingService.onScheduleLocked downstream
        }
    }
}