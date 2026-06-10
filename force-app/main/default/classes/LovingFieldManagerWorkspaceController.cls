public with sharing class LovingFieldManagerWorkspaceController {

    private static final Integer ROW_LIMIT = 100;
    private static final Set<String> CLOSED_WO_STATUSES = new Set<String>{ 'Closed', 'Cancelled', 'Paid' };
    private static final Set<String> CLOSED_TAKEOFF_STATUSES = new Set<String>{ 'Approved', 'Cancelled', 'Void' };
    private static final Set<String> ACTIVE_APPOINTMENT_STATUSES = new Set<String>{ 'Scheduled', 'Dispatched', 'En Route', 'In Progress', 'None' };

    public class WorkspaceData {
        @AuraEnabled public Datetime generatedAt;
        @AuraEnabled public List<MetricDto> metrics;
        @AuraEnabled public List<RowDto> scheduleRows;
        @AuraEnabled public List<RowDto> takeoffRows;
        @AuraEnabled public List<RowDto> siteReadinessRows;
        @AuraEnabled public List<RowDto> approvalRows;
        @AuraEnabled public List<RowDto> foremanRows;
        @AuraEnabled public List<RowDto> aquaRows;
        @AuraEnabled public List<String> warnings;
    }

    public class MetricDto {
        @AuraEnabled public String label;
        @AuraEnabled public Integer value;
        @AuraEnabled public String tone;
    }

    public class RowDto {
        @AuraEnabled public String id;
        @AuraEnabled public String parentId;
        @AuraEnabled public String parentLabel;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String status;
        @AuraEnabled public String workType;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String scheduledLabel;
        @AuraEnabled public String foremanName;
        @AuraEnabled public String source;
        @AuraEnabled public String detail;
        @AuraEnabled public String tone;
        @AuraEnabled public Integer lineItemCount;
        @AuraEnabled public Integer photoCount;
        @AuraEnabled public Integer issueCount;
    }

    @AuraEnabled(cacheable=true)
    public static WorkspaceData getWorkspaceData() {
        Id userId = UserInfo.getUserId();
        WorkspaceData data = new WorkspaceData();
        data.generatedAt = System.now();
        data.warnings = new List<String>();
        data.metrics = new List<MetricDto>();
        data.scheduleRows = new List<RowDto>();
        data.takeoffRows = new List<RowDto>();
        data.siteReadinessRows = new List<RowDto>();
        data.approvalRows = new List<RowDto>();
        data.foremanRows = new List<RowDto>();
        data.aquaRows = new List<RowDto>();

        List<WorkOrder> workOrders = [
            SELECT Id, WorkOrderNumber, Subject, Status, Priority,
                   Work_Order_Type__c, Field_Manager__c, Field_Manager__r.Name,
                   Foreman__c, Foreman__r.Name, Division__c, Lot_Number__c,
                   Community__c, Community__r.Name,
                   (SELECT Id, AppointmentNumber, Subject, Status, SchedStartTime, SchedEndTime
                    FROM ServiceAppointments
                    ORDER BY SchedStartTime ASC NULLS LAST, CreatedDate DESC)
            FROM WorkOrder
            WHERE Field_Manager__c = :userId
              AND Status NOT IN :CLOSED_WO_STATUSES
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ];

        Set<Id> workOrderIds = new Set<Id>();
        for (WorkOrder row : workOrders) {
            workOrderIds.add(row.Id);
        }

        Map<Id, Integer> lineItemCounts = new Map<Id, Integer>();
        Map<Id, Integer> photoCounts = new Map<Id, Integer>();
        Map<Id, Integer> issueCounts = new Map<Id, Integer>();

        if (!workOrderIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT WorkOrderId workOrderId, COUNT(Id) total
                FROM WorkOrderLineItem
                WHERE WorkOrderId IN :workOrderIds
                GROUP BY WorkOrderId
            ]) {
                lineItemCounts.put((Id) ar.get('workOrderId'), (Integer) ar.get('total'));
            }

            for (AggregateResult ar : [
                SELECT LinkedEntityId linkedEntityId, COUNT(Id) total
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :workOrderIds
                GROUP BY LinkedEntityId
            ]) {
                photoCounts.put((Id) ar.get('linkedEntityId'), (Integer) ar.get('total'));
            }

            for (AggregateResult ar : [
                SELECT Standard_WorkOrder__c workOrderId, COUNT(Id) total
                FROM Schedule_Issue__c
                WHERE Standard_WorkOrder__c IN :workOrderIds
                  AND Status__c != 'Closed'
                GROUP BY Standard_WorkOrder__c
            ]) {
                issueCounts.put((Id) ar.get('workOrderId'), (Integer) ar.get('total'));
            }
        }

        Date today = Date.today();
        Integer scheduledToday = 0;
        Integer activeFieldJobs = 0;
        Integer siteReadinessCount = 0;

        for (WorkOrder wo : workOrders) {
            Integer lineCount = lineItemCounts.containsKey(wo.Id) ? lineItemCounts.get(wo.Id) : 0;
            Integer photoCount = photoCounts.containsKey(wo.Id) ? photoCounts.get(wo.Id) : 0;
            Integer openIssues = issueCounts.containsKey(wo.Id) ? issueCounts.get(wo.Id) : 0;

            if (wo.Status == 'Site Readiness') {
                data.siteReadinessRows.add(buildWorkOrderRow(wo, lineCount, photoCount, openIssues, 'Site Readiness'));
                siteReadinessCount++;
            }

            RowDto foremanRow = buildWorkOrderRow(wo, lineCount, photoCount, openIssues, 'Foreman Oversight');
            foremanRow.detail = buildForemanDetail(wo, lineCount, photoCount, openIssues);
            data.foremanRows.add(foremanRow);

            Boolean hasScheduleRows = false;
            for (ServiceAppointment sa : wo.ServiceAppointments) {
                if (!ACTIVE_APPOINTMENT_STATUSES.contains(sa.Status)) {
                    continue;
                }
                RowDto row = buildAppointmentRow(wo, sa, lineCount, photoCount, openIssues);
                data.scheduleRows.add(row);
                hasScheduleRows = true;
                if (sa.SchedStartTime != null && sa.SchedStartTime.date() == today) {
                    scheduledToday++;
                }
                if (sa.Status == 'In Progress' || sa.Status == 'Dispatched' || sa.Status == 'En Route') {
                    activeFieldJobs++;
                }
            }

            if (!hasScheduleRows && isWorkOrderScheduleRelevant(wo)) {
                RowDto row = buildWorkOrderRow(wo, lineCount, photoCount, openIssues, 'Work Order');
                row.scheduledLabel = wo.Status;
                row.detail = buildWorkOrderDetail(wo, lineCount, photoCount, openIssues);
                data.scheduleRows.add(row);
            }
        }

        List<Takeoff__c> takeoffs = [
            SELECT Id, Name, Status__c, Scheduled_Date__c, Submitted_Date__c,
                   Community__c, Community__r.Name, Lot__c, Lot__r.Name,
                   FM_Assignment__c, FM_Assignment__r.Name,
                   Notes__c, Checklist_Complete__c, Eight11_Confirmed__c,
                   NFI_Count__c, CS_Approved__c
            FROM Takeoff__c
            WHERE Status__c NOT IN :CLOSED_TAKEOFF_STATUSES
              AND (FM_Assignment__c = :userId OR (FM_Assignment__c = null AND Community__r.FM_Assignment__c = :userId))
            ORDER BY Scheduled_Date__c ASC NULLS LAST, CreatedDate DESC
            LIMIT :ROW_LIMIT
        ];
        for (Takeoff__c takeoff : takeoffs) {
            RowDto row = new RowDto();
            row.id = takeoff.Id;
            row.name = takeoff.Name;
            row.title = 'Takeoff';
            row.status = takeoff.Status__c;
            row.workType = 'Takeoff';
            row.communityName = takeoff.Community__r != null ? takeoff.Community__r.Name : null;
            row.lotName = takeoff.Lot__r != null ? takeoff.Lot__r.Name : null;
            row.scheduledLabel = takeoff.Scheduled_Date__c == null ? 'Not yet scheduled' : String.valueOf(takeoff.Scheduled_Date__c);
            row.foremanName = takeoff.FM_Assignment__r != null ? takeoff.FM_Assignment__r.Name : null;
            row.source = 'Takeoff__c';
            row.detail = buildTakeoffDetail(takeoff);
            row.tone = toneForTakeoff(takeoff.Status__c, takeoff.NFI_Count__c);
            row.issueCount = takeoff.NFI_Count__c == null ? 0 : Integer.valueOf(takeoff.NFI_Count__c);
            data.takeoffRows.add(row);
            if (takeoff.Scheduled_Date__c == today) {
                scheduledToday++;
            }
        }

        List<Aqua_Check_Ticket__c> aquaChecks = [
            SELECT Id, Name, Aqua_Community__c, Aqua_Community__r.Name, Assigned_To__c, Assigned_To__r.Name,
                   Scheduled_Date__c, Status__c, Billing_Reason_Code__c, Check_Notes__c
            FROM Aqua_Check_Ticket__c
            WHERE Status__c = 'Open'
              AND Assigned_To__c = :userId
            ORDER BY Scheduled_Date__c ASC NULLS LAST, CreatedDate DESC
            LIMIT :ROW_LIMIT
        ];
        for (Aqua_Check_Ticket__c ticket : aquaChecks) {
            RowDto row = new RowDto();
            row.id = ticket.Id;
            row.name = ticket.Name;
            row.title = 'Aqua Check';
            row.status = ticket.Status__c;
            row.workType = String.isBlank(ticket.Billing_Reason_Code__c) ? 'Aqua Check' : 'Aqua Same-Day';
            row.communityName = ticket.Aqua_Community__r != null ? ticket.Aqua_Community__r.Name : null;
            row.scheduledLabel = ticket.Scheduled_Date__c == null ? 'Unscheduled' : String.valueOf(ticket.Scheduled_Date__c);
            row.foremanName = ticket.Assigned_To__r != null ? ticket.Assigned_To__r.Name : null;
            row.source = 'Aqua_Check_Ticket__c';
            row.detail = String.isBlank(ticket.Check_Notes__c) ? 'Routine check pending closeout.' : ticket.Check_Notes__c;
            row.tone = String.isBlank(ticket.Billing_Reason_Code__c) ? 'blue' : 'red';
            data.aquaRows.add(row);
            data.scheduleRows.add(row);
            if (ticket.Scheduled_Date__c == today) {
                scheduledToday++;
            }
        }

        List<Aqua_Pickup_Ticket__c> aquaPickups = [
            SELECT Id, Name, Aqua_Community__c, Aqua_Community__r.Name, Assigned_To__c, Assigned_To__r.Name,
                   Scheduled_Date__c, Status__c, Pickup_Notes__c
            FROM Aqua_Pickup_Ticket__c
            WHERE Status__c = 'Open'
              AND Assigned_To__c = :userId
            ORDER BY Scheduled_Date__c ASC NULLS LAST, CreatedDate DESC
            LIMIT :ROW_LIMIT
        ];
        for (Aqua_Pickup_Ticket__c ticket : aquaPickups) {
            RowDto row = new RowDto();
            row.id = ticket.Id;
            row.name = ticket.Name;
            row.title = 'Aqua Pickup';
            row.status = ticket.Status__c;
            row.workType = 'Aqua Pickup';
            row.communityName = ticket.Aqua_Community__r != null ? ticket.Aqua_Community__r.Name : null;
            row.scheduledLabel = ticket.Scheduled_Date__c == null ? 'Unscheduled' : String.valueOf(ticket.Scheduled_Date__c);
            row.foremanName = ticket.Assigned_To__r != null ? ticket.Assigned_To__r.Name : null;
            row.source = 'Aqua_Pickup_Ticket__c';
            row.detail = String.isBlank(ticket.Pickup_Notes__c) ? 'Pickup pending retrieval and reconciliation.' : ticket.Pickup_Notes__c;
            row.tone = 'purple';
            data.aquaRows.add(row);
            data.scheduleRows.add(row);
            if (ticket.Scheduled_Date__c == today) {
                scheduledToday++;
            }
        }

        List<ProcessInstanceWorkitem> approvals = [
            SELECT Id, ProcessInstanceId, ActorId, OriginalActorId, CreatedDate, ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ActorId = :userId
            ORDER BY CreatedDate DESC
            LIMIT 25
        ];
        for (ProcessInstanceWorkitem item : approvals) {
            RowDto row = new RowDto();
            row.id = item.Id;
            row.parentId = item.ProcessInstance != null ? (String) item.ProcessInstance.TargetObjectId : null;
            row.parentLabel = row.parentId;
            row.name = 'Approval';
            row.title = 'Pending approval';
            row.status = 'Pending';
            row.workType = 'Approval';
            row.scheduledLabel = item.CreatedDate == null ? '' : item.CreatedDate.format('M/d/yyyy h:mm a');
            row.source = 'ProcessInstanceWorkitem';
            row.detail = 'Approval work assigned to you.';
            row.tone = 'orange';
            data.approvalRows.add(row);
        }

        data.metrics.add(metric('Scheduled today', scheduledToday, 'blue'));
        data.metrics.add(metric('Takeoffs open', data.takeoffRows.size(), 'green'));
        data.metrics.add(metric('Site readiness', siteReadinessCount, 'amber'));
        data.metrics.add(metric('Approvals', data.approvalRows.size(), 'orange'));
        data.metrics.add(metric('Foreman live', activeFieldJobs, 'red'));
        data.metrics.add(metric('Aqua open', data.aquaRows.size(), 'purple'));

        if (data.scheduleRows.isEmpty()) {
            data.warnings.add('No active schedule rows are assigned to this Field Manager yet.');
        }
        if (data.takeoffRows.isEmpty()) {
            data.warnings.add('No active Takeoffs are assigned to this Field Manager yet.');
        }
        return data;
    }

    private static MetricDto metric(String label, Integer value, String tone) {
        MetricDto dto = new MetricDto();
        dto.label = label;
        dto.value = value;
        dto.tone = tone;
        return dto;
    }

    private static Boolean isWorkOrderScheduleRelevant(WorkOrder wo) {
        return wo.Status == 'Site Readiness'
            || wo.Status == 'Ready to Schedule'
            || wo.Status == 'Scheduled'
            || wo.Status == 'In Progress'
            || wo.Work_Order_Type__c == 'Aqua Check'
            || wo.Work_Order_Type__c == 'Aqua Pickup'
            || wo.Work_Order_Type__c == 'Customer Success'
            || wo.Work_Order_Type__c == 'Finished Job'
            || wo.Work_Order_Type__c == 'Warranty';
    }

    private static RowDto buildAppointmentRow(WorkOrder wo, ServiceAppointment sa, Integer lineCount, Integer photoCount, Integer openIssues) {
        RowDto row = new RowDto();
        row.id = sa.Id;
        row.parentId = wo.Id;
        row.parentLabel = wo.WorkOrderNumber;
        row.name = String.isBlank(sa.AppointmentNumber) ? wo.Subject : sa.AppointmentNumber;
        row.title = String.isBlank(wo.Subject) ? (String.isBlank(sa.Subject) ? 'Service Appointment' : sa.Subject) : wo.Subject;
        row.status = sa.Status;
        row.workType = normalizedWorkType(wo.Work_Order_Type__c);
        row.communityName = wo.Community__r != null ? wo.Community__r.Name : null;
        row.lotName = wo.Lot_Number__c;
        row.scheduledLabel = formatWindow(sa.SchedStartTime, sa.SchedEndTime);
        row.foremanName = wo.Foreman__r != null ? wo.Foreman__r.Name : null;
        row.source = 'ServiceAppointment';
        row.detail = buildWorkOrderDetail(wo, lineCount, photoCount, openIssues);
        row.tone = toneFor(sa.Status, wo.Status, openIssues);
        row.lineItemCount = lineCount;
        row.photoCount = photoCount;
        row.issueCount = openIssues;
        return row;
    }

    private static RowDto buildWorkOrderRow(WorkOrder wo, Integer lineCount, Integer photoCount, Integer openIssues, String source) {
        RowDto row = new RowDto();
        row.id = wo.Id;
        row.name = String.isBlank(wo.WorkOrderNumber) ? wo.Subject : wo.WorkOrderNumber;
        row.title = String.isBlank(wo.Subject) ? normalizedWorkType(wo.Work_Order_Type__c) : wo.Subject;
        row.status = wo.Status;
        row.workType = normalizedWorkType(wo.Work_Order_Type__c);
        row.communityName = wo.Community__r != null ? wo.Community__r.Name : null;
        row.lotName = wo.Lot_Number__c;
        row.foremanName = wo.Foreman__r != null ? wo.Foreman__r.Name : null;
        row.source = source;
        row.detail = buildWorkOrderDetail(wo, lineCount, photoCount, openIssues);
        row.tone = toneFor(null, wo.Status, openIssues);
        row.lineItemCount = lineCount;
        row.photoCount = photoCount;
        row.issueCount = openIssues;
        return row;
    }

    private static String buildWorkOrderDetail(WorkOrder wo, Integer lineCount, Integer photoCount, Integer openIssues) {
        List<String> parts = new List<String>();
        if (!String.isBlank(wo.Division__c)) {
            parts.add(wo.Division__c);
        }
        if (lineCount > 0) {
            parts.add(String.valueOf(lineCount) + ' scope lines');
        }
        if (photoCount > 0) {
            parts.add(String.valueOf(photoCount) + ' photos');
        }
        if (openIssues > 0) {
            parts.add(String.valueOf(openIssues) + ' open issues');
        }
        return parts.isEmpty() ? 'No additional field details yet.' : String.join(parts, ' · ');
    }

    private static String buildForemanDetail(WorkOrder wo, Integer lineCount, Integer photoCount, Integer openIssues) {
        List<String> parts = new List<String>();
        if (wo.Foreman__r != null && !String.isBlank(wo.Foreman__r.Name)) {
            parts.add('Foreman: ' + wo.Foreman__r.Name);
        }
        parts.add(buildWorkOrderDetail(wo, lineCount, photoCount, openIssues));
        return String.join(parts, ' · ');
    }

    private static String buildTakeoffDetail(Takeoff__c takeoff) {
        List<String> parts = new List<String>();
        if (takeoff.CS_Approved__c == true) {
            parts.add('CS approved');
        }
        if (takeoff.Checklist_Complete__c == true) {
            parts.add('Checklist complete');
        }
        if (takeoff.Eight11_Confirmed__c == true) {
            parts.add('811 confirmed');
        }
        if (!String.isBlank(takeoff.Notes__c)) {
            parts.add(takeoff.Notes__c);
        }
        return parts.isEmpty() ? 'Takeoff pending FM review.' : String.join(parts, ' · ');
    }

    private static String normalizedWorkType(String typeValue) {
        if (typeValue == 'Customer Care') return 'Customer Success';
        if (String.isBlank(typeValue)) return 'Work Order';
        return typeValue;
    }

    private static String formatWindow(Datetime startValue, Datetime endValue) {
        if (startValue == null && endValue == null) {
            return 'Unscheduled';
        }
        if (startValue != null && endValue != null) {
            return startValue.format('M/d/yyyy h:mm a') + ' - ' + endValue.format('h:mm a');
        }
        return startValue != null ? startValue.format('M/d/yyyy h:mm a') : endValue.format('M/d/yyyy h:mm a');
    }

    private static String toneFor(String appointmentStatus, String workOrderStatus, Integer openIssues) {
        if (openIssues != null && openIssues > 0) return 'red';
        if (appointmentStatus == 'In Progress' || appointmentStatus == 'Dispatched' || appointmentStatus == 'En Route') return 'red';
        if (workOrderStatus == 'Site Readiness' || workOrderStatus == 'FM/QI Review' || workOrderStatus == 'Pending Closeout') return 'amber';
        if (appointmentStatus == 'Scheduled' || workOrderStatus == 'Scheduled') return 'blue';
        if (workOrderStatus == 'Ready to Schedule' || appointmentStatus == 'None') return 'green';
        return 'gray';
    }

    private static String toneForTakeoff(String statusValue, Decimal nfiCount) {
        if (nfiCount != null && nfiCount > 0) return 'red';
        if (statusValue == 'Submitted') return 'orange';
        if (statusValue == 'In Progress') return 'blue';
        if (statusValue == 'Draft') return 'gray';
        return 'green';
    }
}