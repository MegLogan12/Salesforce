public with sharing class ODLOpportunityRecordController {
    public class RowData {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public String subtext;
        @AuraEnabled public String dateText;
        @AuraEnabled public String secondaryText;
        @AuraEnabled public String relatedLabel;
        @AuraEnabled public String relatedUrl;
        @AuraEnabled public String notesPreview;
        @AuraEnabled public String interactionType;
    }

    public class PageData {
        @AuraEnabled public Opportunity opportunityRecord;
        @AuraEnabled public String projectPath;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountUrl;
        @AuraEnabled public List<String> stagePath;
        @AuraEnabled public String lastAction;
        @AuraEnabled public String lastActionDate;
        @AuraEnabled public Boolean lastActionWasVoicemail;
        @AuraEnabled public String nextFollowUpSubject;
        @AuraEnabled public String nextFollowUpDate;
        @AuraEnabled public RowData propertyRecord;
        @AuraEnabled public RowData voucherRecord;
        @AuraEnabled public List<RowData> interactions;
        @AuraEnabled public List<RowData> designReviews;
        @AuraEnabled public List<RowData> paymentMilestones;
        @AuraEnabled public List<RowData> quotes;
        @AuraEnabled public List<RowData> files;
        @AuraEnabled public List<String> missingData;
    }

    private class DatedRow implements Comparable {
        RowData row;
        Datetime occurredAt;

        public Integer compareTo(Object other) {
            DatedRow right = (DatedRow) other;
            Long leftTime = occurredAt == null ? 0 : occurredAt.getTime();
            Long rightTime = right.occurredAt == null ? 0 : right.occurredAt.getTime();
            if (leftTime == rightTime) {
                return 0;
            }
            return leftTime > rightTime ? -1 : 1;
        }
    }

    @AuraEnabled(cacheable=true)
    public static PageData getPageData(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }

        PageData data = new PageData();
        data.interactions = new List<RowData>();
        data.designReviews = new List<RowData>();
        data.paymentMilestones = new List<RowData>();
        data.quotes = new List<RowData>();
        data.files = new List<RowData>();
        data.missingData = new List<String>();
        data.stagePath = new List<String>();

        data.opportunityRecord = [
            SELECT Id, Name, Type, StageName, Amount, CloseDate, AccountId, Account.Name, Owner.Name, LeadSource,
                   BMG_Package__c, Community_Name__c, Budget__c, Timeline__c, Budget_Confirmed__c,
                   Opportunity_Number__c, Deposit_Paid__c, Deposit_Paid_Date__c, Design_Link__c,
                   Lot_Layout_Link__c, Model_Pricing_Link__c, Services_Selected__c, Selected_Requirements__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        Map<String, String> typeLabels = picklistLabelByValue(Opportunity.Type);
        data.projectPath = deriveProjectPath(data.opportunityRecord, typeLabels);
        data.accountName = data.opportunityRecord.Account != null ? data.opportunityRecord.Account.Name : null;
        data.accountUrl = data.opportunityRecord.AccountId != null ? '/' + data.opportunityRecord.AccountId : null;
        data.stagePath = activeStagePath();

        Task nextTask = nextFollowUpTask(opportunityId);
        data.nextFollowUpSubject = nextTask != null ? nextTask.Subject : 'No follow-up task';
        data.nextFollowUpDate = nextTask != null && nextTask.ActivityDate != null ? String.valueOf(nextTask.ActivityDate) : 'No due date';

        data.interactions = recentInteractions(opportunityId);
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
        data.designReviews = designReviews(opportunityId);
        data.paymentMilestones = paymentMilestones(opportunityId);
        data.quotes = quotes(opportunityId);
        data.files = relatedFiles(opportunityId);
        data.propertyRecord = propertyRecord(opportunityId);
        data.voucherRecord = voucherRecord(opportunityId);

        if (String.isBlank(data.projectPath)) {
            data.missingData.add('This opportunity is not classified as UpgradeMyBackyard or Design Build.');
        }
        if (data.designReviews.isEmpty()) {
            data.missingData.add('No Design Review record is linked to this opportunity.');
        }
        if (data.paymentMilestones.isEmpty()) {
            data.missingData.add('No Payment Milestone records are linked to this opportunity.');
        }
        if (data.quotes.isEmpty()) {
            data.missingData.add('No Quote is linked to this opportunity.');
        }
        if (data.propertyRecord == null) {
            data.missingData.add('No Homeowner Property record is linked to this opportunity.');
        }

        return data;
    }

    private static List<RowData> recentInteractions(Id opportunityId) {
        List<DatedRow> datedRows = new List<DatedRow>();

        if (Schema.SObjectType.EmailMessage.isAccessible()) {
            for (EmailMessage emailRow : [
                SELECT Id, Subject, MessageDate, FromName, FromAddress, ToAddress, TextBody
                FROM EmailMessage
                WHERE RelatedToId = :opportunityId
                ORDER BY MessageDate DESC
                LIMIT 10
            ]) {
                RowData row = new RowData();
                row.id = emailRow.Id;
                row.url = '/' + emailRow.Id;
                row.label = firstNonBlank(new List<String>{ emailRow.Subject, 'Logged Email' });
            row.status = 'Logged Email';
            row.subtext = firstNonBlank(new List<String>{ emailRow.ToAddress, 'Email' });
            row.dateText = emailRow.MessageDate != null ? emailRow.MessageDate.format('M/d/yyyy h:mm a') : null;
            row.notesPreview = String.isBlank(emailRow.TextBody) ? 'No email preview' : trimPreview(emailRow.TextBody);
            row.interactionType = 'Email';
            datedRows.add(wrap(row, emailRow.MessageDate));
        }
        }

        for (Task taskRow : [
            SELECT Id, Subject, Status, TaskSubtype, ActivityDate, CreatedDate, Description
            FROM Task
            WHERE WhatId = :opportunityId
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
            datedRows.add(wrap(row, occurredAt));
        }

        for (Event eventRow : [
            SELECT Id, Subject, Type, ActivityDateTime, CreatedDate, Description
            FROM Event
            WHERE WhatId = :opportunityId
            ORDER BY ActivityDateTime DESC, CreatedDate DESC
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
            datedRows.add(wrap(row, occurredAt));
        }

        datedRows.sort();
        List<RowData> rows = new List<RowData>();
        Integer limitSize = Math.min(5, datedRows.size());
        for (Integer i = 0; i < limitSize; i++) {
            rows.add(datedRows[i].row);
        }
        return rows;
    }

    private static List<RowData> designReviews(Id opportunityId) {
        List<RowData> rows = new List<RowData>();
        for (Design_Review__c review : [
            SELECT Id, Name, Status__c, LastModifiedDate
            FROM Design_Review__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ]) {
            RowData row = new RowData();
            row.id = review.Id;
            row.url = '/' + review.Id;
            row.label = review.Name;
            row.status = review.Status__c;
            row.dateText = review.LastModifiedDate.format('M/d/yyyy');
            rows.add(row);
        }
        return rows;
    }

    private static List<RowData> paymentMilestones(Id opportunityId) {
        List<RowData> rows = new List<RowData>();
        for (Payment_Milestone__c milestone : [
            SELECT Id, Name, Type__c, Status__c, Amount__c, Due_Date__c, Paid_Date__c
            FROM Payment_Milestone__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY Due_Date__c ASC NULLS LAST, CreatedDate DESC
            LIMIT 5
        ]) {
            RowData row = new RowData();
            row.id = milestone.Id;
            row.url = '/' + milestone.Id;
            row.label = milestone.Type__c;
            row.status = milestone.Status__c;
            row.subtext = milestone.Amount__c != null ? '$' + String.valueOf(milestone.Amount__c.setScale(0)) : 'Amount not set';
            row.dateText = milestone.Due_Date__c != null ? String.valueOf(milestone.Due_Date__c) : 'No due date';
            row.secondaryText = milestone.Paid_Date__c != null ? 'Paid ' + String.valueOf(milestone.Paid_Date__c) : 'Not paid';
            rows.add(row);
        }
        return rows;
    }

    private static List<RowData> quotes(Id opportunityId) {
        List<RowData> rows = new List<RowData>();
        for (Quote quoteRow : [
            SELECT Id, Name, Status, GrandTotal, CreatedDate
            FROM Quote
            WHERE OpportunityId = :opportunityId
            ORDER BY CreatedDate DESC
            LIMIT 5
        ]) {
            RowData row = new RowData();
            row.id = quoteRow.Id;
            row.url = '/' + quoteRow.Id;
            row.label = quoteRow.Name;
            row.status = quoteRow.Status;
            row.subtext = quoteRow.GrandTotal != null ? '$' + String.valueOf(quoteRow.GrandTotal.setScale(0)) : 'Total not set';
            row.dateText = quoteRow.CreatedDate.format('M/d/yyyy');
            rows.add(row);
        }
        return rows;
    }

    private static RowData propertyRecord(Id opportunityId) {
        List<Homeowner_Property__c> rows = [
            SELECT Id, Name, Community__r.Name, Lot__r.Name, Homeowner_Account__r.Name
            FROM Homeowner_Property__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }
        Homeowner_Property__c propertyRow = rows[0];
        RowData row = new RowData();
        row.id = propertyRow.Id;
        row.url = '/' + propertyRow.Id;
        row.label = propertyRow.Name;
        row.status = propertyRow.Community__r != null ? propertyRow.Community__r.Name : null;
        row.subtext = propertyRow.Lot__r != null ? propertyRow.Lot__r.Name : null;
        row.secondaryText = propertyRow.Homeowner_Account__r != null ? propertyRow.Homeowner_Account__r.Name : null;
        return row;
    }

    private static RowData voucherRecord(Id opportunityId) {
        if (!Schema.getGlobalDescribe().containsKey('Voucher__c')) {
            return null;
        }
        List<SObject> rows = Database.query(
            'SELECT Id, Name, Voucher_Code__c, Status__c, Voucher_Type__c ' +
            'FROM Voucher__c WHERE Reserved_Opportunity__c = :opportunityId ORDER BY CreatedDate DESC LIMIT 1'
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
        row.notesPreview = String.valueOf(voucherRow.get('Name'));
        return row;
    }

    private static List<RowData> relatedFiles(Id opportunityId) {
        List<RowData> rows = new List<RowData>();
        for (ContentDocumentLink linkRow : [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.FileType, ContentDocument.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
            ORDER BY SystemModstamp DESC
            LIMIT 5
        ]) {
            RowData row = new RowData();
            row.id = linkRow.ContentDocumentId;
            row.url = '/' + linkRow.ContentDocumentId;
            row.label = linkRow.ContentDocument.Title;
            row.subtext = linkRow.ContentDocument.FileType;
            row.dateText = linkRow.ContentDocument.LastModifiedDate.format('M/d/yyyy');
            rows.add(row);
        }
        return rows;
    }

    private static Task nextFollowUpTask(Id opportunityId) {
        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate
            FROM Task
            WHERE WhatId = :opportunityId
            AND IsClosed = false
            ORDER BY ActivityDate ASC, CreatedDate ASC
            LIMIT 1
        ];
        return tasks.isEmpty() ? null : tasks[0];
    }

    private static List<String> activeStagePath() {
        List<String> steps = new List<String>();
        for (Schema.PicklistEntry entry : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                steps.add(entry.getLabel());
            }
        }
        return steps;
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

    private static Map<String, String> picklistLabelByValue(Schema.SObjectField fieldRef) {
        Map<String, String> labels = new Map<String, String>();
        for (Schema.PicklistEntry entry : fieldRef.getDescribe().getPicklistValues()) {
            labels.put(entry.getValue(), entry.getLabel());
        }
        return labels;
    }

    private static String deriveProjectPath(Opportunity opp, Map<String, String> typeLabels) {
        if (opp == null) {
            return null;
        }
        String label = typeLabels != null && typeLabels.containsKey(opp.Type) ? typeLabels.get(opp.Type) : opp.Type;
        String normalizedType = String.isBlank(opp.Type) ? '' : opp.Type.toLowerCase();
        String normalizedLabel = String.isBlank(label) ? '' : label.toLowerCase();
        String normalizedLeadSource = String.isBlank(opp.LeadSource) ? '' : opp.LeadSource.toLowerCase();
        String normalizedName = String.isBlank(opp.Name) ? '' : opp.Name.toLowerCase();

        if (normalizedType.contains('lawn') || normalizedLabel.contains('lawn')) {
            return null;
        }
        if (label == 'UpgradeMyBackyard' || opp.Type == 'UMB') {
            return 'UpgradeMyBackyard';
        }
        if (label == 'Design Build' || label == 'Design and Build') {
            return 'Design Build';
        }
        // Voucher/Lennar LeadSource check precedes name check — voucher opps are the UMB
        // homebuilder-partner channel even when named "- Backyard Design".
        if (
            normalizedLeadSource.contains('voucher') ||
            normalizedLeadSource.contains('lennar') ||
            normalizedName.contains('voucher') ||
            normalizedName.contains('upgrademybackyard')
        ) {
            return 'UpgradeMyBackyard';
        }
        if (
            normalizedType.contains('custom') ||
            normalizedLabel.contains('custom') ||
            normalizedName.contains('design build') ||
            normalizedName.contains('backyard design')
        ) {
            return 'Design Build';
        }
        // Home Builder type = homebuilder partner channel = UMB delivery path.
        if (
            opp.Type == 'New Business' ||
            opp.Type == 'Home Builder' ||
            !String.isBlank(opp.BMG_Package__c) ||
            normalizedLeadSource.contains('upgrade') ||
            normalizedLeadSource.contains('builder') ||
            normalizedName.contains('backyard') ||
            normalizedName.contains('umb')
        ) {
            return 'UpgradeMyBackyard';
        }
        return null;
    }

    private static String deriveInteractionType(String subject, String taskSubtype, String eventType) {
        String normalizedSubject = String.isBlank(subject) ? '' : subject.toLowerCase();
        String normalizedSubtype = String.isBlank(taskSubtype) ? '' : taskSubtype.toLowerCase();
        String normalizedEventType = String.isBlank(eventType) ? '' : eventType.toLowerCase();

        if (normalizedSubject.contains('voicemail')) {
            return 'Voicemail';
        }
        if (normalizedSubtype == 'call' || normalizedEventType == 'call' || normalizedSubject.contains('call')) {
            return 'Call';
        }
        if (normalizedSubtype == 'email' || normalizedSubject.contains('email') || normalizedEventType.contains('email')) {
            return 'Email';
        }
        if (!String.isBlank(eventType)) {
            return eventType;
        }
        return 'Task';
    }

    private static String deriveActionLabel(String interactionType, String subject, String status) {
        String phase = deriveActionPhase(subject);
        if (interactionType == 'Voicemail') {
            return 'Left Voicemail - ' + phase;
        }
        if (interactionType == 'Email') {
            return 'Sent Email - ' + phase;
        }
        if (interactionType == 'Call') {
            return 'Call Complete - ' + phase;
        }
        if (interactionType == 'Task' || String.isBlank(interactionType)) {
            return firstNonBlank(new List<String>{ subject, 'Activity Logged' });
        }
        return interactionType + ' - ' + phase;
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