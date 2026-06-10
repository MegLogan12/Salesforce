public with sharing class ODLLeadRecordController {
    public class RowData {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public String subtext;
        @AuraEnabled public String dateText;
        @AuraEnabled public String secondaryText;
        @AuraEnabled public String notesPreview;
        @AuraEnabled public String interactionType;
    }

    public class PageData {
        @AuraEnabled public Lead leadRecord;
        @AuraEnabled public String odPath;
        @AuraEnabled public List<String> statusPath;
        @AuraEnabled public String lastAction;
        @AuraEnabled public String lastActionDate;
        @AuraEnabled public Boolean lastActionWasVoicemail;
        @AuraEnabled public String nextFollowUpSubject;
        @AuraEnabled public String nextFollowUpDate;
        @AuraEnabled public RowData latestCampaign;
        @AuraEnabled public RowData voucherRecord;
        @AuraEnabled public List<RowData> interactions;
        @AuraEnabled public List<String> serviceInterests;
        @AuraEnabled public List<String> missingData;
        @AuraEnabled public String convertedAccountUrl;
        @AuraEnabled public String convertedAccountName;
    }

    private class DatedRow implements Comparable {
        RowData row;
        Datetime occurredAt;

        public Integer compareTo(Object other) {
            DatedRow right = (DatedRow) other;
            Long leftTime = occurredAt == null ? 0 : occurredAt.getTime();
            Long rightTime = right.occurredAt == null ? 0 : right.occurredAt.getTime();
            if (leftTime == rightTime) return 0;
            return leftTime > rightTime ? -1 : 1;
        }
    }

    @AuraEnabled(cacheable=true)
    public static PageData getPageData(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required.');
        }

        PageData data = new PageData();
        data.statusPath = new List<String>();
        data.interactions = new List<RowData>();
        data.serviceInterests = new List<String>();
        data.missingData = new List<String>();

        data.leadRecord = [
            SELECT Id, Name, Status, LeadSource, Lead_Type__c, Company, Email, Phone, MobilePhone,
                   Community_Name__c, SMS_Consent__c, ConvertedAccountId,
                   Service_Flag_Aqua__c, Service_Flag_Grading__c, Service_Flag_Irrigation__c,
                   Service_Flag_Lawn_Care__c, Service_Flag_Refreshes__c, Owner.Name
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        data.odPath = derivePath(data.leadRecord);
        data.statusPath = activeStatusPath(data.leadRecord.ConvertedAccountId != null);
        data.serviceInterests = deriveInterests(data.leadRecord);

        if (data.leadRecord.ConvertedAccountId != null) {
            Account convertedAccount = [
                SELECT Id, Name
                FROM Account
                WHERE Id = :data.leadRecord.ConvertedAccountId
                LIMIT 1
            ];
            data.convertedAccountUrl = '/' + convertedAccount.Id;
            data.convertedAccountName = convertedAccount.Name;
        }

        Task nextTask = nextFollowUpTask(leadId);
        data.nextFollowUpSubject = nextTask != null ? nextTask.Subject : 'No follow-up task';
        data.nextFollowUpDate = nextTask != null && nextTask.ActivityDate != null ? String.valueOf(nextTask.ActivityDate) : 'No due date';

        data.interactions = recentInteractions(leadId);
        if (!data.interactions.isEmpty()) {
            RowData latestInteraction = data.interactions[0];
            data.lastAction = deriveActionLabel(latestInteraction.interactionType, latestInteraction.label, latestInteraction.status);
            data.lastActionDate = latestInteraction.dateText;
            data.lastActionWasVoicemail = latestInteraction.interactionType == 'Voicemail';
        } else {
            data.lastAction = 'No action logged';
            data.lastActionDate = 'No activity';
            data.lastActionWasVoicemail = false;
        }

        data.latestCampaign = latestCampaign(leadId);
        data.voucherRecord = voucherRecord(leadId);

        if (data.odPath == 'Not captured') {
            data.missingData.add('Lead does not have a reliable ODL path source field for UpgradeMyBackyard versus Design Build.');
        }
        if (data.serviceInterests.isEmpty()) {
            data.missingData.add('No service interest fields are populated on this lead.');
        }
        if (data.latestCampaign == null) {
            data.missingData.add('No Campaign Member record is linked to this lead.');
        }
        if (String.isBlank(data.leadRecord.Community_Name__c)) {
            data.missingData.add('Community Name is blank on this lead.');
        }

        return data;
    }

    private static List<RowData> recentInteractions(Id leadId) {
        List<DatedRow> rows = new List<DatedRow>();

        for (Task taskRow : [
            SELECT Id, Subject, Status, TaskSubtype, ActivityDate, CreatedDate, Description
            FROM Task
            WHERE WhoId = :leadId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            if (!isCompletedTask(taskRow)) {
                continue;
            }
            Datetime occurredAt = taskRow.ActivityDate != null
                ? Datetime.newInstance(taskRow.ActivityDate, Time.newInstance(12, 0, 0, 0))
                : taskRow.CreatedDate;
            RowData row = new RowData();
            row.id = taskRow.Id;
            row.url = '/' + taskRow.Id;
            row.label = taskRow.Subject;
            row.status = taskRow.Status;
            row.dateText = taskRow.ActivityDate != null ? String.valueOf(taskRow.ActivityDate) : null;
            row.notesPreview = String.isBlank(taskRow.Description) ? 'No notes yet' : trimPreview(taskRow.Description);
            row.interactionType = deriveInteractionType(taskRow.Subject, taskRow.TaskSubtype, null);
            rows.add(wrap(row, occurredAt));
        }

        for (Event eventRow : [
            SELECT Id, Subject, Type, ActivityDateTime, CreatedDate, Description
            FROM Event
            WHERE WhoId = :leadId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            Datetime occurredAt = eventRow.ActivityDateTime != null ? eventRow.ActivityDateTime : eventRow.CreatedDate;
            RowData row = new RowData();
            row.id = eventRow.Id;
            row.url = '/' + eventRow.Id;
            row.label = eventRow.Subject;
            row.status = eventRow.ActivityDateTime != null && eventRow.ActivityDateTime >= System.now() ? 'Scheduled' : 'Completed';
            row.dateText = occurredAt != null ? occurredAt.format('M/d/yyyy h:mm a') : null;
            row.notesPreview = String.isBlank(eventRow.Description) ? 'No notes yet' : trimPreview(eventRow.Description);
            row.interactionType = deriveInteractionType(eventRow.Subject, null, eventRow.Type);
            rows.add(wrap(row, occurredAt));
        }

        rows.sort();
        List<RowData> result = new List<RowData>();
        Integer limitSize = Math.min(5, rows.size());
        for (Integer i = 0; i < limitSize; i++) {
            result.add(rows[i].row);
        }
        return result;
    }

    private static Task nextFollowUpTask(Id leadId) {
        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate
            FROM Task
            WHERE WhoId = :leadId
            AND IsClosed = false
            ORDER BY ActivityDate ASC, CreatedDate ASC
            LIMIT 1
        ];
        return tasks.isEmpty() ? null : tasks[0];
    }

    private static List<String> activeStatusPath(Boolean includeConverted) {
        List<String> statuses = new List<String>();
        for (Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                statuses.add(entry.getLabel());
            }
        }
        if (includeConverted) {
            statuses.add('Converted');
        }
        return statuses;
    }

    private static List<String> deriveInterests(Lead leadRow) {
        List<String> values = new List<String>();
        if (leadRow.Service_Flag_Lawn_Care__c == true) values.add('Lawn Care');
        if (leadRow.Service_Flag_Irrigation__c == true) values.add('Irrigation');
        if (leadRow.Service_Flag_Grading__c == true) values.add('Grading');
        if (leadRow.Service_Flag_Aqua__c == true) values.add('Aqua');
        if (leadRow.Service_Flag_Refreshes__c == true) values.add('Refreshes');
        return values;
    }

    private static String derivePath(Lead leadRow) {
        if (leadRow.Service_Flag_Lawn_Care__c == true) return 'Lawn Care';
        String normalized = String.isBlank(leadRow.Name) ? '' : leadRow.Name.toLowerCase();
        String community = String.isBlank(leadRow.Community_Name__c) ? '' : leadRow.Community_Name__c.toLowerCase();
        if (normalized.contains('design build') || normalized.contains('custom build') || normalized.contains('backyard design') || community.contains('design build')) {
            return 'Design Build';
        }
        if (leadRow.Lead_Type__c == 'Homeowner'
            || leadRow.LeadSource == 'Lennar Voucher'
            || leadRow.LeadSource == 'Homebuilder Event'
            || leadRow.LeadSource == 'Website'
            || leadRow.LeadSource == 'Google'
            || leadRow.LeadSource == 'Social Media'
            || leadRow.LeadSource == 'External Referral'
            || leadRow.LeadSource == 'Employee Referral'
            || (!String.isBlank(leadRow.Company) && leadRow.Company.toLowerCase() == 'homeowner')) {
            return 'UpgradeMyBackyard';
        }
        return 'Not captured';
    }

    private static RowData latestCampaign(Id leadId) {
        List<CampaignMember> rows = [
            SELECT CampaignId, Campaign.Name, Status, CreatedDate
            FROM CampaignMember
            WHERE LeadId = :leadId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }
        CampaignMember memberRow = rows[0];
        RowData row = new RowData();
        row.id = memberRow.CampaignId;
        row.url = '/' + memberRow.CampaignId;
        row.label = memberRow.Campaign != null ? memberRow.Campaign.Name : 'Campaign';
        row.status = memberRow.Status;
        row.dateText = memberRow.CreatedDate.format('M/d/yyyy');
        return row;
    }

    private static RowData voucherRecord(Id leadId) {
        if (!Schema.getGlobalDescribe().containsKey('Voucher__c')) {
            return null;
        }
        List<SObject> rows = Database.query(
            'SELECT Id, Name, Voucher_Code__c, Status__c, Voucher_Type__c ' +
            'FROM Voucher__c WHERE Homeowner_Lead__c = :leadId ORDER BY CreatedDate DESC LIMIT 1'
        );
        if (rows.isEmpty()) {
            return null;
        }
        SObject voucherRow = rows[0];
        RowData row = new RowData();
        row.id = (Id) voucherRow.get('Id');
        row.url = '/' + row.id;
        row.label = String.valueOf(voucherRow.get('Voucher_Code__c'));
        row.status = String.valueOf(voucherRow.get('Status__c'));
        row.subtext = String.valueOf(voucherRow.get('Voucher_Type__c'));
        row.secondaryText = String.valueOf(voucherRow.get('Name'));
        return row;
    }

    private static DatedRow wrap(RowData row, Datetime occurredAt) {
        DatedRow wrapped = new DatedRow();
        wrapped.row = row;
        wrapped.occurredAt = occurredAt;
        return wrapped;
    }

    private static Boolean isCompletedTask(Task taskRow) {
        return taskRow != null
            && !String.isBlank(taskRow.Status)
            && taskRow.Status.toLowerCase().contains('complete');
    }

    private static String deriveInteractionType(String subject, String taskSubtype, String eventType) {
        String normalizedSubject = String.isBlank(subject) ? '' : subject.toLowerCase();
        String normalizedSubtype = String.isBlank(taskSubtype) ? '' : taskSubtype.toLowerCase();
        String normalizedEventType = String.isBlank(eventType) ? '' : eventType.toLowerCase();
        if (normalizedSubject.contains('voicemail')) return 'Voicemail';
        if (normalizedSubtype == 'call' || normalizedEventType == 'call' || normalizedSubject.contains('call')) return 'Call';
        if (normalizedSubtype == 'email' || normalizedSubject.contains('email') || normalizedEventType.contains('email')) return 'Email';
        if (!String.isBlank(eventType)) return eventType;
        return 'Task';
    }

    private static String deriveActionLabel(String interactionType, String subject, String status) {
        String phase = deriveActionPhase(subject);
        if (interactionType == 'Voicemail') return 'Left Voicemail - ' + phase;
        if (interactionType == 'Email') return 'Sent Email - ' + phase;
        if (interactionType == 'Call') return 'Call Complete - ' + phase;
        if (interactionType == 'Task' || String.isBlank(interactionType)) return firstNonBlank(new List<String>{ subject, 'Activity Logged' });
        return interactionType + ' - ' + phase;
    }

    private static String deriveActionPhase(String subject) {
        String normalized = String.isBlank(subject) ? '' : subject.toLowerCase();
        if (normalized.contains('presentation')) return 'Presentation';
        if (normalized.contains('follow-up') || normalized.contains('follow up') || normalized.contains('callback')) return 'Follow-Up';
        return 'Initial';
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String trimPreview(String value) {
        String normalized = value.replace('\r', ' ').replace('\n', ' ').trim();
        if (normalized.length() <= 80) {
            return normalized;
        }
        return normalized.substring(0, 77) + '...';
    }
}