/**
 * MeasuringCupConsoleController
 * Backend for the lovingMeasuringCupConsole LWC (Measuring Cup home page).
 * Returns KPI counts and open measurement WorkOrders.
 */
public with sharing class MeasuringCupConsoleController {

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class HomeDTO {
        @AuraEnabled public Integer pendingMeasurements;
        @AuraEnabled public Integer completedToday;
        @AuraEnabled public Integer crewCount;
        @AuraEnabled public List<WorkOrderRow> workOrders;
    }

    public class WorkOrderRow {
        @AuraEnabled public String id;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String createdDateLabel;
        @AuraEnabled public String statusChip;
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private static String chipClass(String status) {
        if (status == null) return 'chip-neutral';
        String s = status.toLowerCase();
        if (s.contains('progress') || s.contains('open'))   return 'chip-orange';
        if (s.contains('complet') || s.contains('closed'))  return 'chip-green';
        if (s.contains('cancel'))                            return 'chip-neutral';
        return 'chip-blue';
    }

    // ── Main query ────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static HomeDTO getHomeData() {
        try {
            HomeDTO dto = new HomeDTO();
            Date today = Date.today();

            // KPI: pending measurements (open work orders of Measure type)
            // Try Work_Order_Type__c field; fall back gracefully at runtime
            dto.pendingMeasurements = [
                SELECT COUNT() FROM WorkOrder
                WHERE Status NOT IN ('Completed', 'Cancelled', 'Closed')
                  AND Work_Order_Type__c = 'Measure'
            ];

            // KPI: completed today
            dto.completedToday = [
                SELECT COUNT() FROM WorkOrder
                WHERE Status = 'Completed'
                  AND LastModifiedDate >= :Datetime.newInstance(today, Time.newInstance(0,0,0,0))
                  AND Work_Order_Type__c = 'Measure'
            ];

            // KPI: active crews
            dto.crewCount = [
                SELECT COUNT() FROM Crew__c
                WHERE Status__c = 'Active'
            ];

            // Recent open measure work orders
            List<WorkOrderRow> rows = new List<WorkOrderRow>();
            for (WorkOrder wo : [
                SELECT Id, WorkOrderNumber, Subject, Status,
                       Owner.Name, CreatedDate
                FROM WorkOrder
                WHERE Work_Order_Type__c = 'Measure'
                  AND Status NOT IN ('Completed', 'Cancelled', 'Closed')
                ORDER BY CreatedDate DESC
                LIMIT 20
            ]) {
                WorkOrderRow r = new WorkOrderRow();
                r.id               = wo.Id;
                r.workOrderNumber  = wo.WorkOrderNumber;
                r.subject          = wo.Subject != null ? wo.Subject : wo.WorkOrderNumber;
                r.status           = wo.Status  != null ? wo.Status  : '';
                r.ownerName        = wo.Owner   != null ? wo.Owner.Name : '';
                r.createdDateLabel = wo.CreatedDate != null
                    ? wo.CreatedDate.format('M/d/yyyy')
                    : '';
                r.statusChip       = chipClass(wo.Status);
                rows.add(r);
            }
            dto.workOrders = rows;
            return dto;

        } catch (Exception e) {
            throw new AuraHandledException('Unable to load measuring cup data: ' + e.getMessage());
        }
    }
}
