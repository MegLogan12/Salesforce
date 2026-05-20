public with sharing class ODLLeadListController {
    private static final Integer ROW_LIMIT = 50;
    private static final Integer CHILD_LIMIT = 500;

    public class WorkspaceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String name;
        @AuraEnabled public String odPath;
        @AuraEnabled public String leadSource;
        @AuraEnabled public String status;
        @AuraEnabled public String interest;
        @AuraEnabled public String lastAction;
        @AuraEnabled public String lastActionCategory;
        @AuraEnabled public String dateOfAction;
        @AuraEnabled public String voicemail;
        @AuraEnabled public String followUpTask;
        @AuraEnabled public String followUpDue;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Boolean isConverted;
    }

    public class WorkspaceData {
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public List<WorkspaceRow> rows;
        @AuraEnabled public Boolean designBuildSourceMissing;
    }

    private class ActivitySnapshot {
        Datetime occurredAt;
        String label;
        String category;
    }

    private class FollowUpSnapshot {
        Date dueDate;
        String subject;
    }

    @AuraEnabled(cacheable=true)
    public static WorkspaceData getWorkspaceData() {
        WorkspaceData data = new WorkspaceData();
        data.title = 'Homeowner Lead List';
        data.subtitle = 'Homeowner ODL leads only. Last Action and Follow-Up pull from live Salesforce activity where it exists.';
        data.rows = new List<WorkspaceRow>();
        data.designBuildSourceMissing = true;

        List<Lead> leads = [
            SELECT Id, Name, Status, LeadSource, Lead_Type__c, Company, Email, Phone, MobilePhone,
                   Community_Name__c, SMS_Consent__c, ConvertedAccountId, Owner.Name,
                   Service_Flag_Aqua__c, Service_Flag_Grading__c, Service_Flag_Irrigation__c,
                   Service_Flag_Lawn_Care__c, Service_Flag_Refreshes__c, LastModifiedDate
            FROM Lead
            WHERE IsDeleted = false
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ];

        if (leads.isEmpty()) {
            return data;
        }

        List<Lead> filteredLeads = new List<Lead>();
        Set<Id> leadIds = new Set<Id>();
        for (Lead leadRow : leads) {
            if (!isHomeownerOdlLead(leadRow)) {
                continue;
            }
            filteredLeads.add(leadRow);
            leadIds.add(leadRow.Id);
        }

        Map<Id, ActivitySnapshot> latestActivityByLead = latestActivityByLead(leadIds);
        Map<Id, FollowUpSnapshot> nextFollowUpByLead = nextFollowUpByLead(leadIds);

        for (Lead leadRow : filteredLeads) {
            WorkspaceRow row = new WorkspaceRow();
            row.id = leadRow.Id;
            row.url = '/' + leadRow.Id;
            row.name = leadRow.Name;
            row.odPath = derivePath(leadRow);
            row.leadSource = leadRow.LeadSource;
            row.status = leadRow.Status;
            row.interest = deriveInterest(leadRow);
            row.ownerName = leadRow.Owner != null ? leadRow.Owner.Name : null;
            row.isConverted = leadRow.ConvertedAccountId != null;

            ActivitySnapshot activity = latestActivityByLead.get(leadRow.Id);
            if (activity != null) {
                row.lastAction = activity.label;
                row.lastActionCategory = activity.category;
                row.dateOfAction = activity.occurredAt != null ? activity.occurredAt.format('M/d/yyyy') : 'No activity';
                row.voicemail = activity.category == 'voicemail' ? 'Yes' : 'No';
            } else {
                row.lastAction = 'No action logged';
                row.lastActionCategory = 'none';
                row.dateOfAction = 'No activity';
                row.voicemail = 'No';
            }

            FollowUpSnapshot followUp = nextFollowUpByLead.get(leadRow.Id);
            if (followUp != null) {
                row.followUpTask = followUp.subject;
                row.followUpDue = followUp.dueDate != null ? String.valueOf(followUp.dueDate) : 'No due date';
            } else {
                row.followUpTask = 'No follow-up task';
                row.followUpDue = 'No follow-up due';
            }

            data.rows.add(row);
        }

        return data;
    }

    private static Boolean isHomeownerOdlLead(Lead leadRow) {
        if (leadRow == null) {
            return false;
        }
        if (leadRow.Service_Flag_Lawn_Care__c == true) {
            return true;
        }
        if (leadRow.Lead_Type__c == 'Homeowner') {
            return true;
        }
        if (leadRow.LeadSource == 'Lennar Voucher' || leadRow.LeadSource == 'Homebuilder Event') {
            return true;
        }
        if (leadRow.LeadSource == 'Website' || leadRow.LeadSource == 'Google' || leadRow.LeadSource == 'Social Media' || leadRow.LeadSource == 'External Referral' || leadRow.LeadSource == 'Employee Referral') {
            return true;
        }
        if (!String.isBlank(leadRow.Company) && leadRow.Company.toLowerCase() == 'homeowner') {
            return true;
        }
        return false;
    }

    private static String derivePath(Lead leadRow) {
        if (leadRow.Service_Flag_Lawn_Care__c == true) {
            return 'Lawn Care';
        }
        String normalized = String.isBlank(leadRow.Name) ? '' : leadRow.Name.toLowerCase();
        String community = String.isBlank(leadRow.Community_Name__c) ? '' : leadRow.Community_Name__c.toLowerCase();
        if (normalized.contains('design build') || normalized.contains('custom build') || normalized.contains('backyard design') || community.contains('design build')) {
            return 'Design Build';
        }
        if (isHomeownerOdlLead(leadRow)) {
            return 'UpgradeMyBackyard';
        }
        return 'Not captured';
    }

    private static String deriveInterest(Lead leadRow) {
        List<String> flags = new List<String>();
        if (leadRow.Service_Flag_Lawn_Care__c == true) flags.add('Lawn Care');
        if (leadRow.Service_Flag_Irrigation__c == true) flags.add('Irrigation');
        if (leadRow.Service_Flag_Grading__c == true) flags.add('Grading');
        if (leadRow.Service_Flag_Aqua__c == true) flags.add('Aqua');
        if (leadRow.Service_Flag_Refreshes__c == true) flags.add('Refreshes');
        if (!flags.isEmpty()) {
            return String.join(flags, ', ');
        }
        return 'Not captured';
    }

    private static Map<Id, ActivitySnapshot> latestActivityByLead(Set<Id> leadIds) {
        Map<Id, ActivitySnapshot> snapshots = new Map<Id, ActivitySnapshot>();
        if (leadIds.isEmpty()) {
            return snapshots;
        }

        for (Task taskRow : [
            SELECT Id, WhoId, Subject, Status, TaskSubtype, ActivityDate, CreatedDate
            FROM Task
            WHERE WhoId IN :leadIds
            ORDER BY CreatedDate DESC
            LIMIT :CHILD_LIMIT
        ]) {
            if (!isCompletedTask(taskRow)) {
                continue;
            }
            Datetime occurredAt = taskRow.ActivityDate != null
                ? Datetime.newInstance(taskRow.ActivityDate, Time.newInstance(12, 0, 0, 0))
                : taskRow.CreatedDate;
            String category = taskRow.TaskSubtype == 'Call' ? 'call'
                : taskRow.TaskSubtype == 'Email' ? 'email'
                : subjectContains(taskRow.Subject, 'voicemail') ? 'voicemail'
                : subjectContains(taskRow.Subject, 'call') ? 'call'
                : 'task';
            considerSnapshot(snapshots, taskRow.WhoId, occurredAt, deriveActionLabel(category, taskRow.Subject, null), category);
        }

        for (Event eventRow : [
            SELECT Id, WhoId, Subject, Type, ActivityDateTime, CreatedDate
            FROM Event
            WHERE WhoId IN :leadIds
            ORDER BY CreatedDate DESC
            LIMIT :CHILD_LIMIT
        ]) {
            Datetime occurredAt = eventRow.ActivityDateTime != null ? eventRow.ActivityDateTime : eventRow.CreatedDate;
            String category = subjectContains(eventRow.Subject, 'voicemail') ? 'voicemail'
                : subjectContains(eventRow.Subject, 'call') || eventRow.Type == 'Call' ? 'call'
                : subjectContains(eventRow.Subject, 'email') ? 'email'
                : 'event';
            considerSnapshot(snapshots, eventRow.WhoId, occurredAt, deriveActionLabel(category, eventRow.Subject, eventRow.Type), category);
        }

        return snapshots;
    }

    private static Map<Id, FollowUpSnapshot> nextFollowUpByLead(Set<Id> leadIds) {
        Map<Id, FollowUpSnapshot> followUps = new Map<Id, FollowUpSnapshot>();
        if (leadIds.isEmpty()) {
            return followUps;
        }
        for (Task taskRow : [
            SELECT Id, WhoId, Subject, ActivityDate
            FROM Task
            WHERE WhoId IN :leadIds
            AND IsClosed = false
            ORDER BY ActivityDate ASC, CreatedDate ASC
            LIMIT :CHILD_LIMIT
        ]) {
            if (!followUps.containsKey(taskRow.WhoId)) {
                FollowUpSnapshot snapshot = new FollowUpSnapshot();
                snapshot.dueDate = taskRow.ActivityDate;
                snapshot.subject = taskRow.Subject;
                followUps.put(taskRow.WhoId, snapshot);
            }
        }
        return followUps;
    }

    private static void considerSnapshot(Map<Id, ActivitySnapshot> snapshots, Id leadId, Datetime occurredAt, String label, String category) {
        if (leadId == null || occurredAt == null) {
            return;
        }
        ActivitySnapshot current = snapshots.get(leadId);
        if (current == null || occurredAt.getTime() > current.occurredAt.getTime()) {
            ActivitySnapshot snapshot = new ActivitySnapshot();
            snapshot.occurredAt = occurredAt;
            snapshot.label = label;
            snapshot.category = category;
            snapshots.put(leadId, snapshot);
        }
    }

    private static Boolean isCompletedTask(Task taskRow) {
        return taskRow != null
            && !String.isBlank(taskRow.Status)
            && taskRow.Status.toLowerCase().contains('complete');
    }

    private static String deriveActionLabel(String category, String subject, String eventType) {
        String phase = deriveActionPhase(subject);
        if (category == 'voicemail') {
            return 'Left Voicemail - ' + phase;
        }
        if (category == 'email') {
            return 'Sent Email - ' + phase;
        }
        if (category == 'call') {
            return 'Call Complete - ' + phase;
        }
        if (category == 'event') {
            String base = String.isBlank(eventType) ? 'Scheduled Action' : eventType;
            return base + ' - ' + phase;
        }
        return firstNonBlank(new List<String>{ subject, 'Activity Logged' });
    }

    private static String deriveActionPhase(String subject) {
        String normalized = String.isBlank(subject) ? '' : subject.toLowerCase();
        if (normalized.contains('presentation')) {
            return 'Presentation';
        }
        if (normalized.contains('follow-up') || normalized.contains('follow up') || normalized.contains('callback')) {
            return 'Follow-Up';
        }
        return 'Initial';
    }

    private static Boolean subjectContains(String subject, String token) {
        return !String.isBlank(subject) && subject.toLowerCase().contains(token);
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }
}