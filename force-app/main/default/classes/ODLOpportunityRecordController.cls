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
        @AuraEnabled public String chipClass;
    }

    public class ReadinessGate {
        @AuraEnabled public Boolean voucherLinked;
        @AuraEnabled public String voucherStatus;
        @AuraEnabled public String voucherCode;
        @AuraEnabled public Boolean quoteAccepted;
        @AuraEnabled public String quoteStatus;
        @AuraEnabled public Boolean contractSigned;
        @AuraEnabled public String contractStatus;
        @AuraEnabled public Boolean depositPaid;
        @AuraEnabled public Boolean woReady;
        @AuraEnabled public String blockerLine;
        @AuraEnabled public String readinessBadge;
        @AuraEnabled public String badgeClass;
        @AuraEnabled public Boolean isUmb;
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
        @AuraEnabled public ReadinessGate readiness;
        @AuraEnabled public String nextActionText;
        @AuraEnabled public String nextActionButton;
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

    private static final List<String> STAGE_ORDER = new List<String>{
        'Discovery', 'Consult Scheduled', 'Design In Progress',
        'Quote Review', 'Contract Sent', 'Deposit Pending', 'Closed Won', 'Closed Lost'
    };

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
            SELECT Id, Name, Type, StageName, Amount, CloseDate, AccountId, Account.Name,
                   Owner.Name, LeadSource, RecordType.DeveloperName,
                   BMG_Package__c, Community_Name__c, Budget__c, Timeline__c, Budget_Confirmed__c,
                   Opportunity_Number__c, Deposit_Paid__c, Deposit_Paid_Date__c,
                   Design_Link__c, Lot_Layout_Link__c, Model_Pricing_Link__c,
                   Services_Selected__c, Selected_Requirements__c, Selected_Package__c,
                   Quote_Status__c, Contract_Status__c, Voicemail_Left__c, LastActivityDate
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        Opportunity opp = data.opportunityRecord;
        data.projectPath = deriveProjectPath(opp);
        data.accountName = opp.Account != null ? opp.Account.Name : null;
        data.accountUrl = opp.AccountId != null ? '/lightning/r/Account/' + opp.AccountId + '/view' : null;
        data.stagePath = stagePathForRecord(opp);

        Task nextTask = nextFollowUpTask(opportunityId);
        data.nextFollowUpSubject = nextTask != null ? nextTask.Subject : 'No follow-up task';
        data.nextFollowUpDate = nextTask != null && nextTask.ActivityDate != null
            ? String.valueOf(nextTask.ActivityDate) : 'No due date';

        data.interactions = recentInteractions(opportunityId);
        if (!data.interactions.isEmpty()) {
            RowData latestInteraction = data.interactions[0];
            data.lastAction = deriveActionLabel(latestInteraction.interactionType, latestInteraction.label, latestInteraction.status);
            data.lastActionDate = latestInteraction.dateText;
            data.lastActionWasVoicemail = latestInteraction.interactionType == 'Left Voicemail';
        } else {
            data.lastAction = 'No action logged';
            data.lastActionDate = 'No activity';
            data.lastActionWasVoicemail = false;
        }

        data.designReviews = designReviews(opportunityId);
        data.paymentMilestones = paymentMilestones(opportunityId);
        data.quotes = quoteFromStatus(opp);
        data.files = relatedFiles(opportunityId);
        data.propertyRecord = propertyRecord(opportunityId);
        data.voucherRecord = voucherRecord(opportunityId);
        data.readiness = buildReadiness(opp, data.voucherRecord);
        data.nextActionText = deriveNextActionText(opp, data.readiness, nextTask, data.lastActionWasVoicemail);
        data.nextActionButton = deriveNextActionButton(opp, data.readiness, nextTask);

        if (String.isBlank(data.projectPath)) {
            data.missingData.add('This opportunity is not classified as UpgradeMyBackyard or Design Build.');
        }
        if (data.designReviews.isEmpty()) {
            data.missingData.add('No Design Review record is linked to this opportunity.');
        }
        if (data.paymentMilestones.isEmpty()) {
            data.missingData.add('No Payment Milestone records are linked to this opportunity.');
        }
        if (data.propertyRecord == null) {
            data.missingData.add('No Homeowner Property record is linked to this opportunity.');
        }

        return data;
    }

    // ─── Path derivation ────────────────────────────────────────────────────────

    private static String deriveProjectPath(Opportunity opp) {
        if (opp == null) return null;
        String rtName = opp.RecordType != null ? opp.RecordType.DeveloperName : null;
        if (rtName == 'UMB') return 'UpgradeMyBackyard';
        if (rtName == 'Design_Build') return 'Design Build';
        // Fallback: heuristic from Type and name for older records without record type
        String normalizedType = String.isBlank(opp.Type) ? '' : opp.Type.toLowerCase();
        if (normalizedType.contains('lawn')) return null;
        if (opp.Type == 'UMB' || normalizedType.contains('upgrade')) return 'UpgradeMyBackyard';
        if (opp.Type == 'Design Build' || normalizedType.contains('design') || normalizedType.contains('custom')) return 'Design Build';
        return null;
    }

    private static List<String> stagePathForRecord(Opportunity opp) {
        String rtName = opp.RecordType != null ? opp.RecordType.DeveloperName : null;
        if (rtName == 'UMB' || rtName == 'Design_Build') {
            // Return the 8 spec stages in order (omit Closed Lost from the visual path)
            return new List<String>{
                'Discovery', 'Consult Scheduled', 'Design In Progress',
                'Quote Review', 'Contract Sent', 'Deposit Pending', 'Closed Won'
            };
        }
        // Fallback: return all active global picklist values
        List<String> steps = new List<String>();
        for (Schema.PicklistEntry entry : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                steps.add(entry.getLabel());
            }
        }
        return steps;
    }

    // ─── Readiness gate ─────────────────────────────────────────────────────────

    private static ReadinessGate buildReadiness(Opportunity opp, RowData voucher) {
        ReadinessGate gate = new ReadinessGate();
        String rtName = opp.RecordType != null ? opp.RecordType.DeveloperName : null;
        gate.isUmb = rtName == 'UMB';

        gate.voucherLinked = voucher != null;
        gate.voucherCode = voucher != null ? voucher.label : null;
        gate.voucherStatus = voucher != null ? voucher.status : null;

        gate.quoteStatus = opp.Quote_Status__c;
        gate.quoteAccepted = opp.Quote_Status__c == 'Accepted';

        gate.contractStatus = opp.Contract_Status__c;
        gate.contractSigned = opp.Contract_Status__c == 'Signed';

        gate.depositPaid = opp.Deposit_Paid__c;

        gate.woReady = gate.quoteAccepted && gate.contractSigned && gate.depositPaid;

        // Derive badge + blocker
        if (gate.woReady) {
            gate.readinessBadge = 'WO Ready';
            gate.badgeClass = 'badge badge-green';
            gate.blockerLine = null;
        } else if (!gate.quoteAccepted) {
            gate.readinessBadge = 'Blocked';
            gate.badgeClass = 'badge badge-red';
            gate.blockerLine = 'Quote has not been accepted';
        } else if (!gate.contractSigned) {
            gate.readinessBadge = 'Blocked';
            gate.badgeClass = 'badge badge-red';
            gate.blockerLine = 'Contract has not been signed';
        } else if (!gate.depositPaid) {
            gate.readinessBadge = 'Blocked';
            gate.badgeClass = 'badge badge-amber';
            gate.blockerLine = 'Deposit has not been collected';
        } else {
            gate.readinessBadge = 'In Progress';
            gate.badgeClass = 'badge badge-blue';
            gate.blockerLine = null;
        }

        return gate;
    }

    // ─── Next action engine (11 rules, spec-ordered, matches workspace) ─────────

    private static String deriveNextActionText(Opportunity opp, ReadinessGate gate,
                                               Task nextTask, Boolean lastWasVoicemail) {
        // 1. Closed Won
        if (opp.StageName == 'Closed Won') return 'Handoff to ops';
        // 2. Closed Lost
        if (opp.StageName == 'Closed Lost') return 'Move to nurture';
        // 3. No Activity
        if (opp.LastActivityDate == null) return 'Make first contact';
        // 4. Ready
        if (gate != null && gate.woReady) return 'Release work order';
        // 5. Blocked on contract
        if (gate != null && gate.quoteAccepted && !gate.contractSigned) return 'Confirm contract signature';
        // 6. Blocked otherwise (deposit)
        if (gate != null && gate.quoteAccepted && gate.contractSigned && !gate.depositPaid) return 'Collect deposit';
        // 7. Quote Sent or Presented
        if (opp.Quote_Status__c == 'Sent' || opp.StageName == 'Quote Review') return 'Follow up on quote';
        // 8. Quote Draft / Design in progress
        if (opp.StageName == 'Design In Progress') return 'Finalize and send quote';
        // 9. Consult Scheduled
        if (opp.StageName == 'Consult Scheduled') return 'Prep design for consult';
        // 10. Discovery
        if (opp.StageName == 'Discovery') return 'Book consult';
        // 11. Default
        return 'Advance the deal';
    }

    private static String deriveNextActionButton(Opportunity opp, ReadinessGate gate, Task nextTask) {
        if (opp.StageName == 'Closed Won' || opp.StageName == 'Closed Lost') return null;
        if (opp.LastActivityDate == null) return 'Call';
        if (gate != null && gate.woReady) return 'Release';
        if (gate != null && gate.quoteAccepted && !gate.contractSigned) return 'Mark Signed';
        if (gate != null && gate.quoteAccepted && gate.contractSigned && !gate.depositPaid) return 'Request';
        if (opp.Quote_Status__c == 'Sent' || opp.StageName == 'Quote Review') return 'Call';
        if (opp.StageName == 'Design In Progress') return 'Send';
        if (opp.StageName == 'Consult Scheduled') return 'Open';
        if (opp.StageName == 'Discovery') return 'Schedule';
        return 'Open';
    }

    // ─── Quote from opportunity status field (standard Quote not in use) ─────────

    private static List<RowData> quoteFromStatus(Opportunity opp) {
        List<RowData> rows = new List<RowData>();
        if (String.isBlank(opp.Quote_Status__c) || opp.Quote_Status__c == 'Not Sent') {
            return rows;
        }
        RowData row = new RowData();
        row.id = opp.Id;
        row.url = '/lightning/r/Opportunity/' + opp.Id + '/view';
        row.label = opp.Name + ' — Quote';
        row.status = opp.Quote_Status__c;
        row.subtext = opp.Amount != null ? '$' + String.valueOf(opp.Amount.setScale(0)) : 'Amount not set';
        row.chipClass = quoteStatusChipClass(opp.Quote_Status__c);
        rows.add(row);
        return rows;
    }

    private static String quoteStatusChipClass(String status) {
        if (status == 'Accepted') return 'chip chip-green';
        if (status == 'Sent') return 'chip chip-amber';
        if (status == 'Rejected') return 'chip chip-red';
        return 'chip chip-gray';
    }

    // ─── Activity: Tasks + Events + EmailMessages ────────────────────────────────

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
                row.chipClass = 'chip chip-blue';
                datedRows.add(wrap(row, emailRow.MessageDate));
            }
        }

        for (Task taskRow : [
            SELECT Id, Subject, Status, TaskSubtype, ActivityDate, CreatedDate, Description, CallDisposition
            FROM Task
            WHERE WhatId = :opportunityId
            ORDER BY CreatedDate DESC
            LIMIT 15
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
            row.interactionType = deriveInteractionType(taskRow.Subject, taskRow.TaskSubtype, null, taskRow.CallDisposition);
            row.chipClass = interactionChipClass(row.interactionType);
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
            row.interactionType = deriveInteractionType(eventRow.Subject, null, eventRow.Type, null);
            row.chipClass = interactionChipClass(row.interactionType);
            datedRows.add(wrap(row, occurredAt));
        }

        datedRows.sort();
        List<RowData> rows = new List<RowData>();
        Integer limitSize = Math.min(8, datedRows.size());
        for (Integer i = 0; i < limitSize; i++) {
            rows.add(datedRows[i].row);
        }
        return rows;
    }

    private static String interactionChipClass(String interactionType) {
        if (interactionType == 'Left Voicemail') return 'chip chip-amber';
        if (interactionType == 'Email Sent') return 'chip chip-blue';
        if (interactionType == 'Call Completed') return 'chip chip-green';
        if (interactionType == 'Consult Scheduled') return 'chip chip-blue';
        if (interactionType == 'Quote Sent') return 'chip chip-amber';
        if (interactionType == 'Activity Logged') return 'chip chip-gray';
        return 'chip chip-gray';
    }

    // ─── Other related data ───────────────────────────────────────────────────────

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
            'SELECT Id, Name, Voucher_Code__c, Status__c, Voucher_Type__c, Builder_Account__c ' +
            'FROM Voucher__c WHERE Reserved_Opportunity__c = :opportunityId ORDER BY CreatedDate DESC LIMIT 1'
        );
        if (rows.isEmpty()) {
            return null;
        }
        SObject voucherRow = rows[0];
        RowData row = new RowData();
        row.id = (Id) voucherRow.get('Id');
        row.url = '/lightning/r/Voucher__c/' + row.id + '/view';
        row.label = String.valueOf(voucherRow.get('Voucher_Code__c'));
        row.status = String.valueOf(voucherRow.get('Status__c'));
        row.subtext = String.valueOf(voucherRow.get('Voucher_Type__c'));
        row.notesPreview = String.valueOf(voucherRow.get('Name'));
        row.secondaryText = voucherRow.get('Builder_Account__c') != null ? 'Builder Voucher' : 'Standard Voucher';
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
            ORDER BY ActivityDate ASC NULLS LAST, CreatedDate ASC
            LIMIT 1
        ];
        return tasks.isEmpty() ? null : tasks[0];
    }

    // ─── Utilities ────────────────────────────────────────────────────────────────

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

    private static String deriveInteractionType(String subject, String taskSubtype, String eventType, String callDisposition) {
        if (!String.isBlank(callDisposition)) {
            String disp = callDisposition.toLowerCase();
            if (disp.contains('voicemail')) return 'Left Voicemail';
            if (disp.contains('connected') || disp.contains('reached') || disp.contains('answered')) return 'Call Completed';
        }
        String normalizedSubject = String.isBlank(subject) ? '' : subject.toLowerCase();
        String normalizedSubtype = String.isBlank(taskSubtype) ? '' : taskSubtype.toLowerCase();
        String normalizedEventType = String.isBlank(eventType) ? '' : eventType.toLowerCase();

        if (normalizedSubject.contains('voicemail')) return 'Left Voicemail';
        if (normalizedSubject.contains('quote')) return 'Quote Sent';
        if (normalizedSubject.contains('consult') || normalizedSubject.contains('schedule')) return 'Consult Scheduled';
        if (normalizedSubtype == 'call' || normalizedEventType == 'call' || normalizedSubject.contains('call')) return 'Call Completed';
        if (normalizedSubtype == 'email' || normalizedSubject.contains('email') || normalizedEventType.contains('email')) return 'Email Sent';
        if (normalizedSubject.contains('text') || normalizedSubject.contains('sms')) return 'Activity Logged';
        if (!String.isBlank(callDisposition) || !String.isBlank(eventType)) return 'Activity Logged';
        return 'Result Not Categorized';
    }

    private static String deriveActionLabel(String interactionType, String subject, String status) {
        if (!String.isBlank(interactionType) && interactionType != 'Result Not Categorized') return interactionType;
        return firstNonBlank(new List<String>{ subject, 'Activity Logged' });
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (!String.isBlank(value)) return value;
        }
        return null;
    }

    private static String trimPreview(String value) {
        String normalized = value.replace('\r', ' ').replace('\n', ' ').trim();
        if (normalized.length() <= 80) return normalized;
        return normalized.substring(0, 77) + '...';
    }
}
