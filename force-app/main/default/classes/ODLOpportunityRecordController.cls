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
        @AuraEnabled public String relatedOpportunityLabel;
        @AuraEnabled public String relatedOpportunityUrl;
        @AuraEnabled public String actionLabel;
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
        @AuraEnabled public List<RowData> vouchers;
        @AuraEnabled public List<RowData> interactions;
        @AuraEnabled public List<RowData> designReviews;
        @AuraEnabled public List<RowData> paymentMilestones;
        @AuraEnabled public List<RowData> quotes;
        @AuraEnabled public List<RowData> files;
        @AuraEnabled public List<RowData> notes;
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
        data.notes = new List<RowData>();
        data.vouchers = new List<RowData>();
        data.missingData = new List<String>();
        data.stagePath = new List<String>();

        data.opportunityRecord = [
            SELECT Id, Name, Type, StageName, Amount, CloseDate, AccountId, ContactId,
                   Account.Name, Account.Phone, Account.PersonMobilePhone, Account.PersonEmail, Account.BillingStreet, Owner.Name, LeadSource,
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
        data.stagePath = activeStagePath(data.projectPath);

        Task nextTask = nextFollowUpTask(opportunityId);
        data.nextFollowUpSubject = nextTask != null ? nextTask.Subject : null;
        data.nextFollowUpDate = nextTask != null && nextTask.ActivityDate != null ? String.valueOf(nextTask.ActivityDate) : null;

        data.interactions = recentInteractions(opportunityId);
        if (!data.interactions.isEmpty()) {
            RowData latestInteraction = data.interactions[0];
            data.lastAction = deriveActionLabel(latestInteraction.interactionType, latestInteraction.label, latestInteraction.status);
            data.lastActionDate = latestInteraction.dateText;
            data.lastActionWasVoicemail = latestInteraction.interactionType == 'Voicemail';
        } else {
            data.lastAction = null;
            data.lastActionDate = null;
            data.lastActionWasVoicemail = false;
        }
        data.designReviews = designReviews(opportunityId);
        data.paymentMilestones = paymentMilestones(opportunityId);
        data.quotes = quotes(opportunityId);
        data.files = relatedFiles(opportunityId);
        data.notes = relatedNotes(opportunityId);
        data.propertyRecord = propertyRecord(opportunityId);
        data.voucherRecord = voucherRecord(opportunityId);
        data.vouchers = voucherRows(opportunityId);
        if (String.isBlank(data.projectPath)) {
            data.missingData.add('This opportunity is not classified as an outdoor living sales path.');
        }
        return data;
    }

    @AuraEnabled
    public static String advanceStage(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }

        Opportunity oppRow = [
            SELECT Id, Name, Type, StageName, LeadSource, BMG_Package__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        Map<String, String> typeLabels = picklistLabelByValue(Opportunity.Type);
        String projectPath = deriveProjectPath(oppRow, typeLabels);
        List<String> stagePath = activeStagePath(projectPath);
        if (stagePath.isEmpty()) {
            throw new AuraHandledException('No active stage path is available for this opportunity.');
        }

        Integer currentIndex = stagePath.indexOf(oppRow.StageName);
        if (currentIndex == -1) {
            throw new AuraHandledException('Current stage is not on the active ODL path. Use Edit to correct the stage.');
        }
        if (currentIndex >= stagePath.size() - 1) {
            return oppRow.StageName;
        }

        String nextStage = stagePath[currentIndex + 1];
        update new Opportunity(
            Id = oppRow.Id,
            StageName = nextStage
        );
        return nextStage;
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
            row.notesPreview = trimPreview(emailRow.TextBody);
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
            row.notesPreview = trimPreview(taskRow.Description);
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
            row.notesPreview = trimPreview(eventRow.Description);
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
            row.subtext = milestone.Amount__c != null ? '$' + String.valueOf(milestone.Amount__c.setScale(0)) : null;
            row.dateText = milestone.Due_Date__c != null ? String.valueOf(milestone.Due_Date__c) : null;
            row.secondaryText = milestone.Paid_Date__c != null ? 'Paid ' + String.valueOf(milestone.Paid_Date__c) : null;
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
            row.subtext = quoteRow.GrandTotal != null ? '$' + String.valueOf(quoteRow.GrandTotal.setScale(0)) : null;
            row.dateText = quoteRow.CreatedDate.format('M/d/yyyy');
            rows.add(row);
        }
        return rows;
    }

    private static RowData propertyRecord(Id opportunityId) {
        List<Homeowner_Property__c> rows = [
            SELECT Id, Name, Community__r.Name, Lot__r.Name, Lot__r.Street_Address__c, Homeowner_Account__r.Name, Homeowner_Account__r.BillingStreet
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
        String homeownerLast = extractLastToken(propertyRow.Homeowner_Account__r != null ? propertyRow.Homeowner_Account__r.Name : null);
        String lotStreet = propertyRow.Lot__r != null ? (String) propertyRow.Lot__r.get('Street_Address__c') : null;
        String streetForLabel = firstNonBlank(new List<String>{
            lotStreet,
            propertyRow.Homeowner_Account__r != null ? propertyRow.Homeowner_Account__r.BillingStreet : null
        });
        row.label = buildPropertyLabel(homeownerLast, streetForLabel, propertyRow.Name);
        row.status = propertyRow.Community__r != null ? propertyRow.Community__r.Name : null;
        row.subtext = propertyRow.Lot__r != null ? propertyRow.Lot__r.Name : null;
        row.secondaryText = propertyRow.Homeowner_Account__r != null ? propertyRow.Homeowner_Account__r.Name : null;
        row.notesPreview = firstNonBlank(new List<String>{ streetForLabel, propertyRow.Name });
        return row;
    }

    private static RowData voucherRecord(Id opportunityId) {
        if (!Schema.getGlobalDescribe().containsKey('Voucher__c')) {
            return null;
        }
        Map<String, Schema.SObjectField> voucherFields = Schema.SObjectType.Voucher__c.fields.getMap();
        Set<Id> quoteIds = new Set<Id>();
        for (Quote quoteRow : [
            SELECT Id
            FROM Quote
            WHERE OpportunityId = :opportunityId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            quoteIds.add(quoteRow.Id);
        }

        Set<Id> contactIds = new Set<Id>();
        for (Homeowner_Property__c propertyRow : [
            SELECT Id, Homeowner_Account__r.PersonContactId
            FROM Homeowner_Property__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ]) {
            if (propertyRow.Homeowner_Account__r != null && propertyRow.Homeowner_Account__r.PersonContactId != null) {
                contactIds.add(propertyRow.Homeowner_Account__r.PersonContactId);
            }
        }

        Opportunity oppRow = [
            SELECT Id, Name, StageName, LeadSource, Description, ContactId, Account.PersonContactId
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (oppRow.ContactId != null) {
            contactIds.add(oppRow.ContactId);
        }
        if (oppRow.Account != null && oppRow.Account.PersonContactId != null) {
            contactIds.add(oppRow.Account.PersonContactId);
        }

        List<String> filters = new List<String>();
        if (voucherFields.containsKey('Reserved_Opportunity__c')) {
            filters.add('Reserved_Opportunity__c = :opportunityId');
        }
        if (!quoteIds.isEmpty() && voucherFields.containsKey('Redeemed_Quote__c')) {
            filters.add('Redeemed_Quote__c IN :quoteIds');
        }
        if (!contactIds.isEmpty() && voucherFields.containsKey('Contact__c')) {
            filters.add('Contact__c IN :contactIds');
        }
        if (filters.isEmpty()) {
            return null;
        }

        List<SObject> rows = Database.query(
            'SELECT Id, Name, Voucher_Code__c, Status__c, Voucher_Type__c, Campaign__c, Campaign__r.Name, ' +
            'Reserved_Opportunity__c, Reserved_Opportunity__r.Name, Redeemed_Quote__c, Redeemed_Quote__r.Name ' +
            'FROM Voucher__c WHERE ' + String.join(filters, ' OR ') + ' ORDER BY CreatedDate DESC LIMIT 1'
        );
        if (rows.isEmpty()) {
            String fallbackVoucherCode = voucherCodeFromOpportunity(oppRow);
            if (isVoucherSourcedOpportunity(oppRow) && String.isNotBlank(fallbackVoucherCode)) {
                RowData fallbackRow = new RowData();
                fallbackRow.id = oppRow.Id;
                fallbackRow.url = '/' + oppRow.Id;
                fallbackRow.label = fallbackVoucherCode;
                fallbackRow.status = oppRow.StageName;
                fallbackRow.subtext = 'Voucher-sourced opportunity';
                fallbackRow.secondaryText = oppRow.LeadSource;
                fallbackRow.notesPreview = null;
                return fallbackRow;
            }
            return null;
        }
        SObject voucherRow = rows[0];
        RowData row = new RowData();
        row.id = (Id) voucherRow.get('Id');
        row.url = '/' + row.id;
        row.label = firstNonBlank(new List<String>{
            String.valueOf(voucherRow.get('Voucher_Code__c')),
            String.valueOf(voucherRow.get('Name'))
        });
        row.status = String.valueOf(voucherRow.get('Status__c'));
        row.subtext = String.valueOf(voucherRow.get('Voucher_Type__c'));
        SObject campaignRow = voucherRow.getSObject('Campaign__r');
        SObject redeemedQuoteRow = voucherRow.getSObject('Redeemed_Quote__r');
        row.secondaryText = campaignRow == null ? null : String.valueOf(campaignRow.get('Name'));
        row.relatedLabel = redeemedQuoteRow == null ? null : String.valueOf(redeemedQuoteRow.get('Name'));
        row.notesPreview = String.valueOf(voucherRow.get('Name'));
        return row;
    }

    private static List<RowData> voucherRows(Id opportunityId) {
        List<RowData> rows = new List<RowData>();
        if (!Schema.getGlobalDescribe().containsKey('Voucher__c')) {
            return rows;
        }
        Map<String, Schema.SObjectField> voucherFields = Schema.SObjectType.Voucher__c.fields.getMap();
        Set<Id> quoteIds = new Set<Id>();
        for (Quote quoteRow : [
            SELECT Id
            FROM Quote
            WHERE OpportunityId = :opportunityId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            quoteIds.add(quoteRow.Id);
        }

        Set<Id> contactIds = new Set<Id>();
        for (Homeowner_Property__c propertyRow : [
            SELECT Id, Homeowner_Account__r.PersonContactId
            FROM Homeowner_Property__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ]) {
            if (propertyRow.Homeowner_Account__r != null && propertyRow.Homeowner_Account__r.PersonContactId != null) {
                contactIds.add(propertyRow.Homeowner_Account__r.PersonContactId);
            }
        }

        Opportunity oppRow = [
            SELECT Id, Name, StageName, LeadSource, Description, ContactId, AccountId, Account.PersonContactId
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (oppRow.ContactId != null) {
            contactIds.add(oppRow.ContactId);
        }
        if (oppRow.Account != null && oppRow.Account.PersonContactId != null) {
            contactIds.add(oppRow.Account.PersonContactId);
        }

        List<String> filters = new List<String>();
        if (voucherFields.containsKey('Reserved_Opportunity__c')) {
            filters.add('Reserved_Opportunity__c = :opportunityId');
        }
        if (!quoteIds.isEmpty() && voucherFields.containsKey('Redeemed_Quote__c')) {
            filters.add('Redeemed_Quote__c IN :quoteIds');
        }
        if (!contactIds.isEmpty() && voucherFields.containsKey('Contact__c')) {
            filters.add('Contact__c IN :contactIds');
        }

        Set<Id> seenIds = new Set<Id>();
        if (!filters.isEmpty()) {
            for (SObject voucherRow : Database.query(
                'SELECT Id, Name, Voucher_Code__c, Status__c, Voucher_Type__c, Campaign__c, Campaign__r.Name, ' +
                'Reserved_Opportunity__c, Reserved_Opportunity__r.Name, Redeemed_Quote__c, Redeemed_Quote__r.Name, Expiration_Date__c ' +
                'FROM Voucher__c WHERE ' + String.join(filters, ' OR ') + ' ORDER BY CreatedDate DESC LIMIT 10'
            )) {
                RowData row = new RowData();
                row.id = (Id) voucherRow.get('Id');
                row.url = '/' + row.id;
                row.label = firstNonBlank(new List<String>{
                    String.valueOf(voucherRow.get('Voucher_Code__c')),
                    String.valueOf(voucherRow.get('Name'))
                });
                row.status = String.valueOf(voucherRow.get('Status__c'));
                row.subtext = String.valueOf(voucherRow.get('Voucher_Type__c'));
                SObject campaignRow = voucherRow.getSObject('Campaign__r');
                SObject reservedOppRow = voucherRow.getSObject('Reserved_Opportunity__r');
                SObject redeemedQuoteRow = voucherRow.getSObject('Redeemed_Quote__r');
                row.relatedLabel = campaignRow == null ? null : String.valueOf(campaignRow.get('Name'));
                row.relatedUrl = voucherRow.get('Campaign__c') == null ? null : '/' + String.valueOf(voucherRow.get('Campaign__c'));
                row.relatedOpportunityLabel = reservedOppRow == null ? null : String.valueOf(reservedOppRow.get('Name'));
                row.relatedOpportunityUrl = voucherRow.get('Reserved_Opportunity__c') == null ? null : '/' + String.valueOf(voucherRow.get('Reserved_Opportunity__c'));
                row.secondaryText = redeemedQuoteRow == null ? null : String.valueOf(redeemedQuoteRow.get('Name'));
                row.dateText = voucherRow.get('Expiration_Date__c') == null ? null : String.valueOf(voucherRow.get('Expiration_Date__c'));
                row.actionLabel = 'Open';
                row.notesPreview = String.valueOf(voucherRow.get('Name'));
                rows.add(row);
                seenIds.add(row.id);
            }
        }

        String fallbackVoucherCode = voucherCodeFromOpportunity(oppRow);
        if (rows.isEmpty() && isVoucherSourcedOpportunity(oppRow) && String.isNotBlank(fallbackVoucherCode)) {
            RowData fallbackRow = new RowData();
            fallbackRow.id = oppRow.Id;
            fallbackRow.url = '/' + oppRow.Id;
            fallbackRow.label = fallbackVoucherCode;
            fallbackRow.status = oppRow.StageName;
            fallbackRow.subtext = 'Voucher-sourced opportunity';
            fallbackRow.secondaryText = oppRow.LeadSource;
            fallbackRow.relatedOpportunityLabel = oppRow.Name;
            fallbackRow.relatedOpportunityUrl = '/' + oppRow.Id;
            fallbackRow.actionLabel = 'Open Opportunity';
            fallbackRow.notesPreview = null;
            rows.add(fallbackRow);
            seenIds.add(fallbackRow.id);
        }

        if (oppRow.AccountId != null) {
            for (Opportunity voucherOpp : [
                SELECT Id, Name, StageName, LeadSource, Description
                FROM Opportunity
                WHERE AccountId = :oppRow.AccountId
                AND Id != :opportunityId
                AND IsClosed = false
                AND (Name LIKE '%Voucher%' OR LeadSource LIKE '%Voucher%')
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ]) {
                if (seenIds.contains(voucherOpp.Id)) {
                    continue;
                }
                RowData row = new RowData();
                row.id = voucherOpp.Id;
                row.url = '/' + voucherOpp.Id;
                String voucherCode = voucherCodeFromOpportunity(voucherOpp);
                if (String.isBlank(voucherCode)) {
                    continue;
                }
                row.label = voucherCode;
                row.status = voucherOpp.StageName;
                row.subtext = 'Voucher-sourced opportunity';
                row.relatedOpportunityLabel = voucherOpp.Name;
                row.relatedOpportunityUrl = '/' + voucherOpp.Id;
                row.secondaryText = voucherOpp.LeadSource;
                row.actionLabel = 'Open Opportunity';
                row.notesPreview = null;
                rows.add(row);
                seenIds.add(row.id);
            }
        }
        return rows;
    }

    private static String voucherCodeFromOpportunity(Opportunity oppRow) {
        if (oppRow == null) {
            return null;
        }
        String raw = oppRow.Description;
        if (String.isBlank(raw)) {
            return null;
        }
        String candidate = raw.trim();
        if (candidate.contains(' ') || candidate.length() < 4 || candidate.length() > 24) {
            return null;
        }
        if (!Pattern.matches('[A-Za-z0-9\\-]+', candidate)) {
            return null;
        }
        return candidate;
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
            if (linkRow.ContentDocument.FileType == 'SNOTE') {
                continue;
            }
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

    private static List<RowData> relatedNotes(Id opportunityId) {
        List<RowData> rows = new List<RowData>();
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.FileType, ContentDocument.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
            ORDER BY SystemModstamp DESC
            LIMIT 10
        ];
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink linkRow : links) {
            if (linkRow.ContentDocument.FileType == 'SNOTE') {
                docIds.add(linkRow.ContentDocumentId);
            }
        }

        Map<Id, String> notePreviewByDocId = new Map<Id, String>();
        if (!docIds.isEmpty()) {
            for (ContentVersion versionRow : [
                SELECT ContentDocumentId, TextPreview, VersionData, FileExtension
                FROM ContentVersion
                WHERE IsLatest = true
                AND ContentDocumentId IN :docIds
            ]) {
                String preview = String.isNotBlank(versionRow.TextPreview)
                    ? versionRow.TextPreview
                    : (versionRow.VersionData != null && String.valueOf(versionRow.FileExtension).toLowerCase() == 'snote'
                        ? trimPreview(versionRow.VersionData.toString())
                        : null);
                if (String.isNotBlank(preview)) {
                    notePreviewByDocId.put(versionRow.ContentDocumentId, trimPreview(preview));
                }
            }
        }

        for (ContentDocumentLink linkRow : links) {
            if (linkRow.ContentDocument.FileType != 'SNOTE') {
                continue;
            }
            RowData row = new RowData();
            row.id = linkRow.ContentDocumentId;
            row.url = '/' + linkRow.ContentDocumentId;
            row.label = linkRow.ContentDocument.Title;
            row.subtext = 'Salesforce Note';
            row.dateText = linkRow.ContentDocument.LastModifiedDate.format('M/d/yyyy');
            row.notesPreview = notePreviewByDocId.get(linkRow.ContentDocumentId);
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

    private static List<String> activeStagePath(String projectPath) {
        if (projectPath == 'Upgrade My Backyard') {
            return new List<String>{
                'Community Activated',
                'Quote Requested',
                'Consultation Scheduled',
                'Design In Progress',
                'Proposal Presented',
                'Contract Sent',
                'Financing Review',
                'Contract Signed',
                'Deposit Paid',
                'Pre-Production',
                'In Progress',
                'Pre Close',
                'Job Completed',
                'Closed Lost'
            };
        }
        if (projectPath == 'Design Build') {
            return new List<String>{
                'Inquiry',
                'Discovery',
                'Proposal',
                'Negotiation',
                'Contract Signed',
                'Deposit Paid',
                'In Progress',
                'Job Completed',
                'Closed Lost'
            };
        }
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
        if (
            label == 'UpgradeMyBackyard' ||
            opp.Type == 'UMB' ||
            opp.Type == 'UpgradeMyBackyard'
        ) {
            return 'Upgrade My Backyard';
        }
        if (label == 'Design Build' || label == 'Design and Build') {
            return 'Design Build';
        }
        // Voucher/Lennar LeadSource check precedes name check — voucher opps are the UMB
        if (
            normalizedLeadSource.contains('voucher') ||
            normalizedLeadSource.contains('lennar') ||
            normalizedName.contains('voucher') ||
            normalizedName.contains('upgrademybackyard')
        ) {
            return 'Upgrade My Backyard';
        }
        if (
            normalizedType.contains('custom') ||
            normalizedLabel.contains('custom') ||
            normalizedName.contains('design build') ||
            normalizedName.contains('backyard design')
        ) {
            return 'Design Build';
        }
        if (
            opp.Type == 'New Business' ||
            !String.isBlank(opp.BMG_Package__c) ||
            normalizedLeadSource.contains('upgrade') ||
            normalizedName.contains('backyard') ||
            normalizedName.contains('umb')
        ) {
            return 'Upgrade My Backyard';
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

    private static Boolean isVoucherSourcedOpportunity(Opportunity oppRow) {
        if (oppRow == null) {
            return false;
        }
        String normalizedLeadSource = String.isBlank(oppRow.LeadSource) ? '' : oppRow.LeadSource.toLowerCase();
        String normalizedName = String.isBlank(oppRow.Name) ? '' : oppRow.Name.toLowerCase();
        return normalizedLeadSource.contains('voucher')
            || normalizedLeadSource.contains('lennar')
            || normalizedName.contains('voucher')
            || normalizedName.contains('lennar');
    }

    private static String extractLastToken(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        List<String> parts = value.trim().split('\\s+');
        return parts.isEmpty() ? value : parts[parts.size() - 1];
    }

    private static String buildPropertyLabel(String lastName, String street, String fallbackLabel) {
        if (String.isNotBlank(lastName) && String.isNotBlank(street)) {
            return lastName + ' - ' + street;
        }
        return firstNonBlank(new List<String>{ street, fallbackLabel });
    }

    private static String trimPreview(String value) {
        if (value == null) {
            return null;
        }
        String normalized = value.replace('\r', ' ').replace('\n', ' ').trim();
        if (String.isBlank(normalized)) {
            return null;
        }
        if (normalized.length() <= 80) {
            return normalized;
        }
        return normalized.substring(0, 77) + '...';
    }
}