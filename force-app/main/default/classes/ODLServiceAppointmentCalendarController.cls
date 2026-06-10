public with sharing class ODLServiceAppointmentCalendarController {
    public class AppointmentRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String appointmentNumber;
        @AuraEnabled public String type;
        @AuraEnabled public String relatedLabel;
        @AuraEnabled public String relatedUrl;
        @AuraEnabled public String dateText;
        @AuraEnabled public String windowText;
        @AuraEnabled public String assignedTo;
        @AuraEnabled public String status;
    }

    public class CalendarDay {
        @AuraEnabled public String label;
        @AuraEnabled public String dateLabel;
        @AuraEnabled public Integer count;
        @AuraEnabled public List<String> events;
    }

    public class PageData {
        @AuraEnabled public Integer consultCount;
        @AuraEnabled public Integer siteVisitCount;
        @AuraEnabled public Integer installCount;
        @AuraEnabled public Integer followUpCount;
        @AuraEnabled public List<CalendarDay> calendarDays;
        @AuraEnabled public List<AppointmentRow> rows;
        @AuraEnabled public String lastTouch;
        @AuraEnabled public String voicemailStatus;
        @AuraEnabled public String nextFollowUp;
        @AuraEnabled public Integer openTasks;
    }

    @AuraEnabled(cacheable=true)
    public static PageData getPageData() {
        PageData data = new PageData();
        data.calendarDays = new List<CalendarDay>();
        data.rows = new List<AppointmentRow>();
        data.consultCount = 0;
        data.siteVisitCount = 0;
        data.installCount = 0;
        data.followUpCount = 0;

        Date startDate = Date.today();
        Datetime startTime = System.now();
        Datetime endTime = startTime.addDays(7);
        Map<Date, CalendarDay> dayByDate = new Map<Date, CalendarDay>();
        for (Integer offset = 0; offset < 7; offset++) {
            Date dayValue = startDate.addDays(offset);
            CalendarDay day = new CalendarDay();
            day.label = formatDayLabel(dayValue);
            day.dateLabel = String.valueOf(dayValue.day());
            day.count = 0;
            day.events = new List<String>();
            dayByDate.put(dayValue, day);
            data.calendarDays.add(day);
        }

        List<ServiceAppointment> appointments = [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, SchedEndTime, ParentRecordId, WorkType.Name
            FROM ServiceAppointment
            WHERE SchedStartTime >= :startTime
            AND SchedStartTime < :endTime
            ORDER BY SchedStartTime ASC
            LIMIT 50
        ];

        Set<Id> appointmentIds = new Set<Id>();
        Set<Id> workOrderIds = new Set<Id>();
        for (ServiceAppointment row : appointments) {
            appointmentIds.add(row.Id);
            if (row.ParentRecordId != null && String.valueOf(row.ParentRecordId).startsWith('0WO')) {
                workOrderIds.add(row.ParentRecordId);
            }
        }

        Map<Id, WorkOrder> workOrderById = workOrderIds.isEmpty()
            ? new Map<Id, WorkOrder>()
            : new Map<Id, WorkOrder>([
                SELECT Id, WorkOrderNumber, Account.Name
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
            String typeLabel = row.WorkType == null ? 'Appointment' : row.WorkType.Name;
            String typeKey = typeLabel.toLowerCase();
            if (typeKey.contains('consult')) {
                data.consultCount++;
            } else if (typeKey.contains('site')) {
                data.siteVisitCount++;
            } else if (typeKey.contains('install')) {
                data.installCount++;
            } else {
                data.followUpCount++;
            }

            if (row.SchedStartTime != null && dayByDate.containsKey(row.SchedStartTime.date())) {
                CalendarDay day = dayByDate.get(row.SchedStartTime.date());
                day.count++;
                if (day.events.size() < 3) {
                    day.events.add(typeLabel);
                }
            }

            WorkOrder workOrder = workOrderById.get(row.ParentRecordId);
            AppointmentRow out = new AppointmentRow();
            out.id = row.Id;
            out.url = '/' + row.Id;
            out.appointmentNumber = row.AppointmentNumber;
            out.type = typeLabel;
            out.relatedLabel = workOrder == null
                ? 'Service Appointment'
                : firstNonBlank(new List<String>{ workOrder.WorkOrderNumber, workOrder.Account == null ? null : workOrder.Account.Name });
            out.relatedUrl = workOrder == null ? out.url : '/' + workOrder.Id;
            out.dateText = row.SchedStartTime == null ? 'Not scheduled' : row.SchedStartTime.format('M/d/yyyy');
            out.windowText = formatWindow(row.SchedStartTime, row.SchedEndTime);
            out.assignedTo = crewByAppointmentId.containsKey(row.Id) ? crewByAppointmentId.get(row.Id) : 'Unassigned';
            out.status = row.Status;
            data.rows.add(out);
        }

        Task latestTask;
        Task latestVoicemail;
        Date nextFollowUpDate;
        Integer openTaskCount = 0;
        for (Task row : [
            SELECT Id, Subject, Status, ActivityDate, TaskSubtype, CallDisposition, LastModifiedDate
            FROM Task
            WHERE WhatId IN :appointmentIds
            ORDER BY LastModifiedDate DESC
            LIMIT 25
        ]) {
            if (latestTask == null || row.LastModifiedDate > latestTask.LastModifiedDate) {
                latestTask = row;
            }
            if ((String.join(new List<String>{ row.Subject, row.CallDisposition }, ' ')).toLowerCase().contains('voicemail')) {
                if (latestVoicemail == null || row.LastModifiedDate > latestVoicemail.LastModifiedDate) {
                    latestVoicemail = row;
                }
            }
            if (row.Status != 'Completed' && row.Status != 'Closed') {
                openTaskCount++;
                if (row.ActivityDate != null && (nextFollowUpDate == null || row.ActivityDate < nextFollowUpDate)) {
                    nextFollowUpDate = row.ActivityDate;
                }
            }
        }
        data.lastTouch = latestTask == null || latestTask.LastModifiedDate == null ? 'No recent activity' : latestTask.LastModifiedDate.format('M/d/yyyy');
        data.voicemailStatus = latestVoicemail == null || latestVoicemail.LastModifiedDate == null ? 'No recent voicemail' : 'Left ' + latestVoicemail.LastModifiedDate.format('M/d/yyyy');
        data.nextFollowUp = nextFollowUpDate == null ? 'No open follow-up task' : String.valueOf(nextFollowUpDate);
        data.openTasks = openTaskCount;
        return data;
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String formatWindow(Datetime startValue, Datetime endValue) {
        if (startValue == null && endValue == null) return 'Not scheduled';
        if (startValue != null && endValue != null) return startValue.format('h:mm a') + ' - ' + endValue.format('h:mm a');
        return startValue != null ? startValue.format('h:mm a') : endValue.format('h:mm a');
    }

    private static String formatDayLabel(Date dayValue) {
        return Datetime.newInstance(dayValue, Time.newInstance(0, 0, 0, 0)).format('EEE');
    }
}