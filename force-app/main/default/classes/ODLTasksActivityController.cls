public with sharing class ODLTasksActivityController {
    public class TaskRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String subject;
        @AuraEnabled public String relatedLabel;
        @AuraEnabled public String relatedUrl;
        @AuraEnabled public String lob;
        @AuraEnabled public String type;
        @AuraEnabled public String dueDate;
        @AuraEnabled public String lastActivity;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String status;
    }

    public class CalendarDay {
        @AuraEnabled public String label;
        @AuraEnabled public String dateLabel;
        @AuraEnabled public Integer count;
        @AuraEnabled public List<String> events;
    }

    public class PageData {
        @AuraEnabled public Integer overdueCount;
        @AuraEnabled public Integer dueTodayCount;
        @AuraEnabled public Integer voicemailCount;
        @AuraEnabled public Integer completedTodayCount;
        @AuraEnabled public String lastTouch;
        @AuraEnabled public String voicemailStatus;
        @AuraEnabled public String nextFollowUp;
        @AuraEnabled public Integer openTasks;
        @AuraEnabled public List<TaskRow> taskRows;
        @AuraEnabled public List<CalendarDay> calendarDays;
    }

    @AuraEnabled(cacheable=true)
    public static PageData getPageData() {
        PageData data = new PageData();
        data.taskRows = new List<TaskRow>();
        data.calendarDays = new List<CalendarDay>();
        data.overdueCount = 0;
        data.dueTodayCount = 0;
        data.voicemailCount = 0;
        data.completedTodayCount = 0;
        data.openTasks = 0;

        Date todayDate = Date.today();
        Datetime nowValue = System.now();

        List<Task> taskRows = [
            SELECT Id, Subject, Status, ActivityDate, TaskSubtype, CallDisposition, CreatedDate, LastModifiedDate,
                   Owner.Name, WhatId, What.Name, WhoId, Who.Name
            FROM Task
            WHERE CreatedDate = LAST_N_DAYS:45
            ORDER BY ActivityDate ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 75
        ];

        Set<Id> opportunityIds = new Set<Id>();
        for (Task row : taskRows) {
            if (row.WhatId != null && String.valueOf(row.WhatId).startsWith('006')) {
                opportunityIds.add(row.WhatId);
            }
        }

        Map<Id, Opportunity> opportunityById = opportunityIds.isEmpty()
            ? new Map<Id, Opportunity>()
            : new Map<Id, Opportunity>([
                SELECT Id, Name, Type, LeadSource, BMG_Package__c, Design_Link__c
                FROM Opportunity
                WHERE Id IN :opportunityIds
            ]);

        Task latestTask;
        Task latestVoicemail;
        Date nextFollowUpDate;
        for (Task row : taskRows) {
            if (latestTask == null || row.LastModifiedDate > latestTask.LastModifiedDate) {
                latestTask = row;
            }
            if (isVoicemailTask(row)) {
                if (latestVoicemail == null || row.LastModifiedDate > latestVoicemail.LastModifiedDate) {
                    latestVoicemail = row;
                }
                data.voicemailCount++;
            }
            if (!isClosed(row.Status)) {
                data.openTasks++;
                if (row.ActivityDate != null) {
                    if (row.ActivityDate < todayDate) data.overdueCount++;
                    if (row.ActivityDate == todayDate) data.dueTodayCount++;
                    if (nextFollowUpDate == null || row.ActivityDate < nextFollowUpDate) {
                        nextFollowUpDate = row.ActivityDate;
                    }
                }
            } else if (row.LastModifiedDate != null && row.LastModifiedDate.date() == todayDate) {
                data.completedTodayCount++;
            }

            TaskRow out = new TaskRow();
            out.id = row.Id;
            out.url = '/' + row.Id;
            out.subject = row.Subject;
            out.relatedLabel = row.What != null ? row.What.Name : (row.Who != null ? row.Who.Name : 'Task');
            out.relatedUrl = row.WhatId != null ? '/' + row.WhatId : (row.WhoId != null ? '/' + row.WhoId : null);
            out.lob = deriveLob(row.WhatId, opportunityById.get(row.WhatId));
            out.type = firstNonBlank(new List<String>{ row.TaskSubtype, row.CallDisposition, 'Task' });
            out.dueDate = row.ActivityDate == null ? 'No due date' : String.valueOf(row.ActivityDate);
            out.lastActivity = row.LastModifiedDate == null ? null : row.LastModifiedDate.format('M/d/yyyy');
            out.ownerName = row.Owner == null ? null : row.Owner.Name;
            out.status = row.Status;
            data.taskRows.add(out);
        }

        data.lastTouch = latestTask == null || latestTask.LastModifiedDate == null
            ? 'No recent activity'
            : latestTask.LastModifiedDate.format('M/d/yyyy');
        data.voicemailStatus = latestVoicemail == null || latestVoicemail.LastModifiedDate == null
            ? 'No recent voicemail'
            : 'Left ' + latestVoicemail.LastModifiedDate.format('M/d/yyyy');
        data.nextFollowUp = nextFollowUpDate == null ? 'No open follow-up task' : String.valueOf(nextFollowUpDate);

        Map<Date, CalendarDay> dayByDate = new Map<Date, CalendarDay>();
        for (Integer offset = 0; offset < 7; offset++) {
            Date dayValue = todayDate.addDays(offset);
            CalendarDay day = new CalendarDay();
            day.label = formatDayLabel(dayValue);
            day.dateLabel = String.valueOf(dayValue.day());
            day.count = 0;
            day.events = new List<String>();
            dayByDate.put(dayValue, day);
            data.calendarDays.add(day);
        }

        List<Event> events = [
            SELECT Id, Subject, ActivityDateTime, WhatId, What.Name
            FROM Event
            WHERE ActivityDateTime >= :nowValue
            AND ActivityDateTime < :nowValue.addDays(7)
            ORDER BY ActivityDateTime ASC
            LIMIT 50
        ];
        for (Event row : events) {
            if (row.ActivityDateTime == null) continue;
            Date dayKey = row.ActivityDateTime.date();
            if (!dayByDate.containsKey(dayKey)) continue;
            CalendarDay day = dayByDate.get(dayKey);
            day.count++;
            if (day.events.size() < 3) {
                day.events.add(firstNonBlank(new List<String>{
                    row.Subject,
                    row.What != null ? row.What.Name : null,
                    'Scheduled activity'
                }));
            }
        }

        return data;
    }

    private static Boolean isClosed(String status) {
        return status == 'Completed' || status == 'Closed';
    }

    private static Boolean isVoicemailTask(Task row) {
        String haystack = String.join(new List<String>{
            row.Subject,
            row.TaskSubtype,
            row.CallDisposition
        }, ' ').toLowerCase();
        return haystack.contains('voicemail');
    }

    private static String deriveLob(Id whatId, Opportunity opp) {
        if (opp != null) {
            String raw = firstNonBlank(new List<String>{ opp.Type, opp.LeadSource, opp.BMG_Package__c });
            String normalized = raw == null ? '' : raw.toLowerCase();
            if (normalized.contains('lawn')) return 'Lawn Care';
            if (normalized.contains('design')) return 'Custom Build';
            if (normalized.contains('upgrade') || normalized.contains('umb')) return 'UMB';
            return raw;
        }
        if (whatId != null && String.valueOf(whatId).startsWith('00Q')) return 'Lead';
        if (whatId != null && String.valueOf(whatId).startsWith('001')) return 'Account';
        return 'Homeowner';
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String formatDayLabel(Date dayValue) {
        return Datetime.newInstance(dayValue, Time.newInstance(0, 0, 0, 0)).format('EEE');
    }
}