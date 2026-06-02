public with sharing class ODLServiceAppointmentConsoleController {
    public class ListRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String appointmentNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String scheduledWindow;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String workOrderUrl;
        @AuraEnabled public String homeownerName;
        @AuraEnabled public String homeownerUrl;
        @AuraEnabled public String territory;
        @AuraEnabled public String crewName;
        @AuraEnabled public String address;
    }

    public class ListPageData {
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer scheduledCount;
        @AuraEnabled public Integer unscheduledCount;
        @AuraEnabled public Integer withWorkOrderCount;
        @AuraEnabled public List<ListRow> rows;
    }

    public class DetailRow {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class ActivityRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public String dateText;
        @AuraEnabled public String url;
    }

    public class DetailPageData {
        @AuraEnabled public Id serviceAppointmentId;
        @AuraEnabled public String appointmentNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String appointmentType;
        @AuraEnabled public String scheduledWindow;
        @AuraEnabled public String territory;
        @AuraEnabled public String crewName;
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String homeownerName;
        @AuraEnabled public Id homeownerId;
        @AuraEnabled public String contactName;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String address;
        @AuraEnabled public String fieldManager;
        @AuraEnabled public String subject;
        @AuraEnabled public List<DetailRow> overviewRows;
        @AuraEnabled public List<DetailRow> contextRows;
        @AuraEnabled public List<DetailRow> executionRows;
        @AuraEnabled public List<ActivityRow> activityRows;
        @AuraEnabled public List<String> openItems;
    }

    @AuraEnabled(cacheable=true)
    public static ListPageData getListData() {
        ListPageData data = new ListPageData();
        data.rows = new List<ListRow>();
        data.totalCount = 0;
        data.scheduledCount = 0;
        data.unscheduledCount = 0;
        data.withWorkOrderCount = 0;

        List<ServiceAppointment> appointments = [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, SchedEndTime, ServiceTerritory.Name,
                   ParentRecordId, AccountId, Account.Name, Street, City, State, PostalCode
            FROM ServiceAppointment
            ORDER BY LastModifiedDate DESC
            LIMIT 75
        ];

        Set<Id> workOrderIds = new Set<Id>();
        Set<Id> appointmentIds = new Set<Id>();
        for (ServiceAppointment row : appointments) {
            appointmentIds.add(row.Id);
            if (row.ParentRecordId != null && String.valueOf(row.ParentRecordId).startsWith('0WO')) {
                workOrderIds.add(row.ParentRecordId);
            }
        }

        Map<Id, WorkOrder> workOrdersById = workOrderIds.isEmpty()
            ? new Map<Id, WorkOrder>()
            : new Map<Id, WorkOrder>([
                SELECT Id, WorkOrderNumber, Subject, AccountId, Account.Name, ContactId, Contact.Name,
                       Field_Manager__r.Name
                FROM WorkOrder
                WHERE Id IN :workOrderIds
            ]);

        Map<Id, String> crewByAppointmentId = new Map<Id, String>();
        if (!appointmentIds.isEmpty()) {
            for (AssignedResource row : [
                SELECT ServiceAppointmentId, ServiceResource.Name
                FROM AssignedResource
                WHERE ServiceAppointmentId IN :appointmentIds
                ORDER BY CreatedDate ASC
            ]) {
                if (!crewByAppointmentId.containsKey(row.ServiceAppointmentId)) {
                    crewByAppointmentId.put(row.ServiceAppointmentId, row.ServiceResource == null ? 'Unassigned' : row.ServiceResource.Name);
                }
            }
        }

        for (ServiceAppointment row : appointments) {
            ListRow out = new ListRow();
            WorkOrder relatedWorkOrder = workOrdersById.get(row.ParentRecordId);
            out.id = row.Id;
            out.url = '/' + row.Id;
            out.appointmentNumber = row.AppointmentNumber;
            out.status = row.Status;
            out.scheduledWindow = formatWindow(row.SchedStartTime, row.SchedEndTime);
            out.workOrderNumber = relatedWorkOrder == null ? null : relatedWorkOrder.WorkOrderNumber;
            out.workOrderUrl = relatedWorkOrder == null ? null : '/' + relatedWorkOrder.Id;
            out.homeownerName = relatedWorkOrder != null && relatedWorkOrder.Account != null
                ? relatedWorkOrder.Account.Name
                : (row.Account == null ? null : row.Account.Name);
            out.homeownerUrl = relatedWorkOrder != null && relatedWorkOrder.AccountId != null
                ? '/' + relatedWorkOrder.AccountId
                : (row.AccountId == null ? null : '/' + row.AccountId);
            out.territory = row.ServiceTerritory == null ? 'Unassigned' : row.ServiceTerritory.Name;
            out.crewName = crewByAppointmentId.containsKey(row.Id) ? crewByAppointmentId.get(row.Id) : 'Unassigned';
            out.address = joinAddress(row.Street, row.City, row.State, row.PostalCode);
            data.rows.add(out);
            data.totalCount++;
            if (row.Status == 'Scheduled') data.scheduledCount++;
            if (row.ParentRecordId == null) data.unscheduledCount++;
            if (relatedWorkOrder != null) data.withWorkOrderCount++;
        }
        return data;
    }

    @AuraEnabled(cacheable=true)
    public static DetailPageData getRecordData(Id serviceAppointmentId) {
        DetailPageData data = new DetailPageData();
        data.overviewRows = new List<DetailRow>();
        data.contextRows = new List<DetailRow>();
        data.executionRows = new List<DetailRow>();
        data.activityRows = new List<ActivityRow>();
        data.openItems = new List<String>();
        if (serviceAppointmentId == null) {
            return data;
        }

        ServiceAppointment appointment = [
            SELECT Id, AppointmentNumber, Status, Subject, Description, SchedStartTime, SchedEndTime,
                   ServiceTerritory.Name, ParentRecordId, AccountId, Account.Name, ContactId, Contact.Name,
                   Street, City, State, PostalCode, WorkType.Name
            FROM ServiceAppointment
            WHERE Id = :serviceAppointmentId
            LIMIT 1
        ];

        WorkOrder relatedWorkOrder = null;
        if (appointment.ParentRecordId != null && String.valueOf(appointment.ParentRecordId).startsWith('0WO')) {
            List<WorkOrder> rows = [
                SELECT Id, WorkOrderNumber, Subject, AccountId, Account.Name, ContactId, Contact.Name,
                       Field_Manager__r.Name, Work_Order_Type__c, Scheduled_Date__c
                FROM WorkOrder
                WHERE Id = :appointment.ParentRecordId
                LIMIT 1
            ];
            if (!rows.isEmpty()) {
                relatedWorkOrder = rows[0];
            }
        }

        String crewName = 'Unassigned';
        List<AssignedResource> assignedRows = [
            SELECT ServiceResource.Name
            FROM AssignedResource
            WHERE ServiceAppointmentId = :serviceAppointmentId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (!assignedRows.isEmpty() && assignedRows[0].ServiceResource != null) {
            crewName = assignedRows[0].ServiceResource.Name;
        }

        data.serviceAppointmentId = appointment.Id;
        data.appointmentNumber = appointment.AppointmentNumber;
        data.status = appointment.Status;
        data.appointmentType = appointment.WorkType == null ? 'Field Execution Appointment' : appointment.WorkType.Name;
        data.scheduledWindow = formatWindow(appointment.SchedStartTime, appointment.SchedEndTime);
        data.territory = appointment.ServiceTerritory == null ? 'Unassigned' : appointment.ServiceTerritory.Name;
        data.crewName = crewName;
        data.workOrderId = relatedWorkOrder == null ? null : relatedWorkOrder.Id;
        data.workOrderNumber = relatedWorkOrder == null ? null : relatedWorkOrder.WorkOrderNumber;
        data.homeownerId = relatedWorkOrder != null ? relatedWorkOrder.AccountId : appointment.AccountId;
        data.homeownerName = relatedWorkOrder != null && relatedWorkOrder.Account != null ? relatedWorkOrder.Account.Name : (appointment.Account == null ? null : appointment.Account.Name);
        data.contactId = relatedWorkOrder != null ? relatedWorkOrder.ContactId : appointment.ContactId;
        data.contactName = relatedWorkOrder != null && relatedWorkOrder.Contact != null ? relatedWorkOrder.Contact.Name : (appointment.Contact == null ? null : appointment.Contact.Name);
        data.address = joinAddress(appointment.Street, appointment.City, appointment.State, appointment.PostalCode);
        data.fieldManager = relatedWorkOrder == null || relatedWorkOrder.Field_Manager__r == null ? 'Unassigned' : relatedWorkOrder.Field_Manager__r.Name;
        data.subject = String.isBlank(appointment.Subject) ? (relatedWorkOrder == null ? null : relatedWorkOrder.Subject) : appointment.Subject;

        data.overviewRows.add(detail('Appointment Type', data.appointmentType));
        data.overviewRows.add(detail('Status', data.status));
        data.overviewRows.add(detail('Scheduled Window', data.scheduledWindow));
        data.overviewRows.add(detail('Service Territory', data.territory));

        data.contextRows.add(detail('Homeowner Account', data.homeownerName));
        data.contextRows.add(detail('Contact', data.contactName));
        data.contextRows.add(detail('Address', data.address));
        data.contextRows.add(detail('Work Order', data.workOrderNumber));

        data.executionRows.add(detail('Crew', data.crewName));
        data.executionRows.add(detail('Field Manager', data.fieldManager));
        data.executionRows.add(detail('Work Order Type', relatedWorkOrder == null ? null : relatedWorkOrder.Work_Order_Type__c));
        data.executionRows.add(detail('Work Order Scheduled Date', relatedWorkOrder == null ? null : String.valueOf(relatedWorkOrder.Scheduled_Date__c)));

        for (Task taskRow : [
            SELECT Id, Subject, Status, ActivityDate
            FROM Task
            WHERE WhatId = :serviceAppointmentId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            data.activityRows.add(activity(taskRow.Id, taskRow.Subject, taskRow.Status, taskRow.ActivityDate == null ? null : String.valueOf(taskRow.ActivityDate)));
        }
        for (Event eventRow : [
            SELECT Id, Subject, Type, ActivityDateTime
            FROM Event
            WHERE WhatId = :serviceAppointmentId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            data.activityRows.add(activity(eventRow.Id, eventRow.Subject, eventRow.Type, eventRow.ActivityDateTime == null ? null : eventRow.ActivityDateTime.format('M/d/yyyy h:mm a')));
        }

        if (data.workOrderId == null) data.openItems.add('No Work Order is linked to this Service Appointment.');
        if (String.isBlank(data.homeownerName)) data.openItems.add('No homeowner account is linked to this Service Appointment.');
        if (data.activityRows.isEmpty()) data.openItems.add('No activity is logged on this Service Appointment.');
        return data;
    }

    private static DetailRow detail(String label, String value) {
        DetailRow row = new DetailRow();
        row.label = label;
        row.value = String.isBlank(value) ? '—' : value;
        return row;
    }

    private static ActivityRow activity(Id idValue, String label, String status, String dateText) {
        ActivityRow row = new ActivityRow();
        row.id = idValue;
        row.label = String.isBlank(label) ? 'Activity' : label;
        row.status = status;
        row.dateText = dateText;
        row.url = idValue == null ? null : '/' + idValue;
        return row;
    }

    private static String joinAddress(String street, String city, String state, String postalCode) {
        List<String> parts = new List<String>();
        if (!String.isBlank(street)) parts.add(street);
        String cityState = '';
        if (!String.isBlank(city)) cityState += city;
        if (!String.isBlank(state)) cityState += (String.isBlank(cityState) ? '' : ', ') + state;
        if (!String.isBlank(postalCode)) cityState += (String.isBlank(cityState) ? '' : ' ') + postalCode;
        if (!String.isBlank(cityState)) parts.add(cityState);
        return parts.isEmpty() ? 'Address not available' : String.join(parts, ' · ');
    }

    private static String formatWindow(Datetime startValue, Datetime endValue) {
        if (startValue == null && endValue == null) return 'Not scheduled';
        if (startValue != null && endValue != null) return startValue.format('M/d/yyyy h:mm a') + ' - ' + endValue.format('h:mm a');
        return startValue != null ? startValue.format('M/d/yyyy h:mm a') : endValue.format('M/d/yyyy h:mm a');
    }
}