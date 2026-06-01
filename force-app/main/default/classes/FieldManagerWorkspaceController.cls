/**
 * FieldManagerWorkspaceController
 * Backend for the lovingFieldManagerWorkspace LWC.
 * Returns today's ServiceAppointments, open WorkOrder count, and unassigned SA count.
 */
public with sharing class FieldManagerWorkspaceController {

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class WorkspaceDTO {
        @AuraEnabled public Integer todayAppointments;
        @AuraEnabled public Integer openWorkOrders;
        @AuraEnabled public Integer unassignedAppointments;
        @AuraEnabled public Integer overdueAppointments;
        @AuraEnabled public List<AppointmentRow> appointments;
    }

    public class AppointmentRow {
        @AuraEnabled public String  id;
        @AuraEnabled public String  subject;
        @AuraEnabled public String  status;
        @AuraEnabled public String  schedStartLabel;
        @AuraEnabled public String  schedEndLabel;
        @AuraEnabled public String  serviceResourceName;
        @AuraEnabled public String  workOrderSubject;
        @AuraEnabled public Boolean isUnassigned;
        @AuraEnabled public Boolean isOverdue;
        @AuraEnabled public String  statusChip;
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private static String chipClass(String status) {
        if (status == null) return 'chip-neutral';
        String s = status.toLowerCase();
        if (s.contains('progress') || s.contains('dispatch')) return 'chip-blue';
        if (s.contains('complet') || s.contains('closed'))    return 'chip-green';
        if (s.contains('cancel'))                              return 'chip-neutral';
        return 'chip-orange';
    }

    // ── Main query ────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static WorkspaceDTO getWorkspaceData() {
        try {
            WorkspaceDTO dto = new WorkspaceDTO();
            Date today = Date.today();

            // KPI: open work orders
            dto.openWorkOrders = [
                SELECT COUNT() FROM WorkOrder
                WHERE Status NOT IN ('Completed', 'Cancelled', 'Closed')
            ];

            // Fetch today's service appointments
            List<ServiceAppointment> saList = [
                SELECT Id, Subject, Status,
                       SchedStartTime, SchedEndTime,
                       ServiceResourceId,
                       ParentRecordId
                FROM ServiceAppointment
                WHERE Status NOT IN ('Completed', 'Cancelled')
                  AND SchedStartTime >= :Datetime.newInstance(today, Time.newInstance(0,0,0,0))
                  AND SchedStartTime <  :Datetime.newInstance(today.addDays(1), Time.newInstance(0,0,0,0))
                ORDER BY SchedStartTime
                LIMIT 50
            ];

            // Collect resource IDs and parent (WorkOrder) IDs
            Set<Id> resourceIds   = new Set<Id>();
            Set<Id> workOrderIds  = new Set<Id>();
            for (ServiceAppointment sa : saList) {
                if (sa.ServiceResourceId != null) resourceIds.add(sa.ServiceResourceId);
                if (sa.ParentRecordId   != null) workOrderIds.add(sa.ParentRecordId);
            }

            // Resource name lookup
            Map<Id, String> resourceNameMap = new Map<Id, String>();
            for (ServiceResource sr : [
                SELECT Id, Name FROM ServiceResource WHERE Id IN :resourceIds
            ]) {
                resourceNameMap.put(sr.Id, sr.Name);
            }

            // WorkOrder subject lookup
            Map<Id, String> workOrderSubjectMap = new Map<Id, String>();
            for (WorkOrder wo : [
                SELECT Id, Subject FROM WorkOrder WHERE Id IN :workOrderIds
            ]) {
                workOrderSubjectMap.put(wo.Id, wo.Subject != null ? wo.Subject : wo.Id);
            }

            Integer unassigned  = 0;
            Integer overdue     = 0;
            Datetime now        = Datetime.now();
            List<AppointmentRow> rows = new List<AppointmentRow>();

            for (ServiceAppointment sa : saList) {
                AppointmentRow r = new AppointmentRow();
                r.id                 = sa.Id;
                r.subject            = sa.Subject != null ? sa.Subject : sa.Id;
                r.status             = sa.Status  != null ? sa.Status  : '';
                r.schedStartLabel    = sa.SchedStartTime != null
                    ? sa.SchedStartTime.format('h:mm a')
                    : '';
                r.schedEndLabel      = sa.SchedEndTime != null
                    ? sa.SchedEndTime.format('h:mm a')
                    : '';
                r.isUnassigned       = (sa.ServiceResourceId == null);
                r.serviceResourceName = sa.ServiceResourceId != null
                    ? (resourceNameMap.containsKey(sa.ServiceResourceId)
                        ? resourceNameMap.get(sa.ServiceResourceId)
                        : '')
                    : 'Unassigned';
                r.workOrderSubject   = sa.ParentRecordId != null
                    ? (workOrderSubjectMap.containsKey(sa.ParentRecordId)
                        ? workOrderSubjectMap.get(sa.ParentRecordId)
                        : '')
                    : '';
                r.isOverdue          = (sa.SchedEndTime != null && sa.SchedEndTime < now);
                r.statusChip         = chipClass(sa.Status);
                if (r.isUnassigned) unassigned++;
                if (r.isOverdue)    overdue++;
                rows.add(r);
            }

            dto.todayAppointments      = saList.size();
            dto.unassignedAppointments = unassigned;
            dto.overdueAppointments    = overdue;
            dto.appointments           = rows;
            return dto;

        } catch (Exception e) {
            throw new AuraHandledException('Unable to load workspace data: ' + e.getMessage());
        }
    }
}
