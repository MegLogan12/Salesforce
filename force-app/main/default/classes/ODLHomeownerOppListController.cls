public with sharing class ODLHomeownerOppListController {
    private static final Integer ROW_LIMIT = 50;
    private static final Integer CHILD_LIMIT = 500;

    public class WorkspaceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String name;
        @AuraEnabled public String accountName;
        @AuraEnabled public String projectPath;
        @AuraEnabled public String projectPathValue;
        @AuraEnabled public String stage;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String packageOrService;
        @AuraEnabled public String lastAction;
        @AuraEnabled public String lastActionCategory;
        @AuraEnabled public String dateOfAction;
        @AuraEnabled public String followUpTask;
        @AuraEnabled public String followUpDue;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String openItem;
    }

    public class WorkspaceData {
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public List<WorkspaceRow> rows;
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
        data.title = 'Homeowner Opportunity List';
        data.subtitle = 'Homeowner-only operating list with live last action, date of action, and follow-up context.';
        data.rows = new List<WorkspaceRow>();

        Map<String, String> typeLabels = picklistLabelByValue(Opportunity.Type);

        List<Opportunity> opportunities = [
            SELECT Id, Name, Type, StageName, Amount, BMG_Package__c, Services_Selected__c,
                   Owner.Name, Account.Name, LastModifiedDate
            FROM Opportunity
            WHERE Account.IsPersonAccount = true
            AND IsClosed = false
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ];

        if (opportunities.isEmpty()) {
            return data;
        }

        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity row : opportunities) {
            opportunityIds.add(row.Id);
        }

        Map<Id, ActivitySnapshot> latestActivityByOpportunity = latestActivityByOpportunity(opportunityIds);
        Map<Id, FollowUpSnapshot> nextFollowUpByOpportunity = nextFollowUpByOpportunity(opportunityIds);

        for (Opportunity opp : opportunities) {
            WorkspaceRow row = new WorkspaceRow();
            row.id = opp.Id;
            row.url = '/' + opp.Id;
            row.name = opp.Name;
            row.accountName = opp.Account != null ? opp.Account.Name : null;
            row.projectPathValue = opp.Type;
            row.projectPath = deriveProjectPath(opp, typeLabels);
            row.stage = opp.StageName;
            row.amount = opp.Amount;
            row.packageOrService = firstNonBlank(new List<String>{ opp.BMG_Package__c, opp.Services_Selected__c, 'Not set' });
            row.ownerName = opp.Owner != null ? opp.Owner.Name : null;

            ActivitySnapshot activity = latestActivityByOpportunity.get(opp.Id);
            if (activity != null) {
                row.lastAction = activity.label;
                row.lastActionCategory = activity.category;
                row.dateOfAction = activity.occurredAt != null ? activity.occurredAt.format('M/d/yyyy') : 'No activity';
            } else {
                row.lastAction = 'No action logged';
                row.lastActionCategory = 'none';
                row.dateOfAction = 'No activity';
            }

            FollowUpSnapshot followUp = nextFollowUpByOpportunity.get(opp.Id);
            if (followUp != null) {
                row.followUpTask = followUp.subject;
                row.followUpDue = followUp.dueDate != null ? String.valueOf(followUp.dueDate) : 'No due date';
                row.openItem = firstNonBlank(new List<String>{ followUp.subject, 'Follow-up due' });
            } else {
                row.followUpTask = 'No follow-up task';
                row.followUpDue = 'No follow-up due';
                row.openItem = 'No open item';
            }

            data.rows.add(row);
        }

        return data;
    }

    private static Map<Id, ActivitySnapshot> latestActivityByOpportunity(Set<Id> opportunityIds) {
        Map<Id, ActivitySnapshot> snapshots = new Map<Id, ActivitySnapshot>();

        if (Schema.SObjectType.EmailMessage.isAccessible()) {
            for (EmailMessage emailRow : [
                SELECT Id, RelatedToId, Subject, MessageDate
                FROM EmailMessage
                WHERE RelatedToId IN :opportunityIds
                ORDER BY MessageDate DESC
                LIMIT :CHILD_LIMIT
            ]) {
                considerSnapshot(
                    snapshots,
                    emailRow.RelatedToId,
                    emailRow.MessageDate,
                    deriveActionLabel('email', emailRow.Subject, null),
                    'email'
                );
            }
        }

        if (Schema.SObjectType.Task.isAccessible()) {
            for (Task taskRow : [
                SELECT Id, WhatId, Subject, Status, TaskSubtype, ActivityDate, CreatedDate
                FROM Task
                WHERE WhatId IN :opportunityIds
                ORDER BY CreatedDate DESC
                LIMIT :CHILD_LIMIT
            ]) {
                if (!isCompletedTask(taskRow)) {
                    continue;
                }
                Datetime occurredAt = taskRow.CreatedDate;
                if (taskRow.ActivityDate != null) {
                    occurredAt = Datetime.newInstance(taskRow.ActivityDate, Time.newInstance(12, 0, 0, 0));
                }
                String category = taskRow.TaskSubtype == 'Call' ? 'call'
                    : taskRow.TaskSubtype == 'Email' ? 'email'
                    : subjectContains(taskRow.Subject, 'voicemail') ? 'voicemail'
                    : subjectContains(taskRow.Subject, 'call') ? 'call'
                    : 'task';
                considerSnapshot(
                    snapshots,
                    taskRow.WhatId,
                    occurredAt,
                    deriveActionLabel(category, taskRow.Subject, null),
                    category
                );
            }
        }

        if (Schema.SObjectType.Event.isAccessible()) {
            for (Event eventRow : [
                SELECT Id, WhatId, Subject, Type, ActivityDateTime, CreatedDate
                FROM Event
                WHERE WhatId IN :opportunityIds
                ORDER BY CreatedDate DESC
                LIMIT :CHILD_LIMIT
            ]) {
                Datetime occurredAt = eventRow.ActivityDateTime != null ? eventRow.ActivityDateTime : eventRow.CreatedDate;
                String category = subjectContains(eventRow.Subject, 'voicemail') ? 'voicemail'
                    : subjectContains(eventRow.Subject, 'call') || eventRow.Type == 'Call' ? 'call'
                    : subjectContains(eventRow.Subject, 'email') ? 'email'
                    : 'event';
                considerSnapshot(
                    snapshots,
                    eventRow.WhatId,
                    occurredAt,
                    deriveActionLabel(category, eventRow.Subject, eventRow.Type),
                    category
                );
            }
        }

        return snapshots;
    }

    private static Map<Id, FollowUpSnapshot> nextFollowUpByOpportunity(Set<Id> opportunityIds) {
        Map<Id, FollowUpSnapshot> followUps = new Map<Id, FollowUpSnapshot>();
        if (!Schema.SObjectType.Task.isAccessible()) {
            return followUps;
        }

        for (Task taskRow : [
            SELECT Id, WhatId, Subject, ActivityDate
            FROM Task
            WHERE WhatId IN :opportunityIds
            AND IsClosed = false
            ORDER BY ActivityDate ASC, CreatedDate ASC
            LIMIT :CHILD_LIMIT
        ]) {
            if (!followUps.containsKey(taskRow.WhatId)) {
                FollowUpSnapshot snapshot = new FollowUpSnapshot();
                snapshot.dueDate = taskRow.ActivityDate;
                snapshot.subject = taskRow.Subject;
                followUps.put(taskRow.WhatId, snapshot);
            }
        }
        return followUps;
    }

    private static Boolean isCompletedTask(Task taskRow) {
        return taskRow != null
            && !String.isBlank(taskRow.Status)
            && taskRow.Status.toLowerCase().contains('complete');
    }

    private static void considerSnapshot(
        Map<Id, ActivitySnapshot> snapshots,
        Id opportunityId,
        Datetime occurredAt,
        String label,
        String category
    ) {
        if (opportunityId == null || occurredAt == null) {
            return;
        }

        ActivitySnapshot current = snapshots.get(opportunityId);
        if (current == null || occurredAt.getTime() > current.occurredAt.getTime()) {
            ActivitySnapshot snapshot = new ActivitySnapshot();
            snapshot.occurredAt = occurredAt;
            snapshot.label = label;
            snapshot.category = category;
            snapshots.put(opportunityId, snapshot);
        }
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

    private static Map<String, String> picklistLabelByValue(Schema.SObjectField fieldRef) {
        Map<String, String> labels = new Map<String, String>();
        for (Schema.PicklistEntry entry : fieldRef.getDescribe().getPicklistValues()) {
            labels.put(entry.getValue(), entry.getLabel());
        }
        return labels;
    }

    private static String deriveProjectPath(Opportunity opp, Map<String, String> typeLabels) {
        String label = typeLabels.containsKey(opp.Type) ? typeLabels.get(opp.Type) : opp.Type;
        if (label == 'UpgradeMyBackyard' || label == 'Design Build') {
            return label;
        }
        if (opp.Type == 'New Business' || !String.isBlank(opp.BMG_Package__c) || subjectContains(opp.Name, 'voucher')) {
            return 'UpgradeMyBackyard';
        }
        if (subjectContains(opp.Name, 'design build') || subjectContains(opp.Name, 'backyard design')) {
            return 'Design Build';
        }
        return firstNonBlank(new List<String>{ label, 'Homeowner' });
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