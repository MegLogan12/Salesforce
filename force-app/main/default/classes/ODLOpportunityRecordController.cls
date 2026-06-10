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

    public class EngagementHealth {
        @AuraEnabled public String state;           // Active | Slowing | Going Dark | Re-engaged
        @AuraEnabled public Integer daysSinceResponse;
        @AuraEnabled public Integer outreachAttemptsSince;
        @AuraEnabled public String lastResponseDate;
        @AuraEnabled public String stateClass;      // CSS modifier
        @AuraEnabled public String stateLabel;      // Display label
        @AuraEnabled public String callToAction;    // Going-dark guidance text
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
        @AuraEnabled public EngagementHealth engagement;
        @AuraEnabled public String nextActionText;
        @AuraEnabled public String nextActionButton;
        @AuraEnabled public String designFeeStatus;
        @AuraEnabled public String designFeePaidDate;
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

    // UMB Sales Path — spec section 4
    private static final List<String> UMB_STAGE_PATH = new List<String>{
        'Qualifying', 'Package Selected', 'Consult Scheduled',
        'Quote Sent', 'Quote Accepted', 'Proposal Presented', 'Closed Won'
    };

    // Design Build Sales Path — spec section 4
    private static final List<String> DB_STAGE_PATH = new List<String>{
        'Discovery Consult', 'Design Agreement', 'Consult Scheduled',
        'Design Development', 'Proposal Presented', 'Closed Won'
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
                   Quote_Status__c, Contract_Status__c, Voicemail_Left__c, LastActivityDate,
                   Last_Customer_Response_Date__c, Design_Fee_Status__c, Design_Fee_Paid_Date__c,
                   Design_Status__c
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        Opportunity opp = data.opportunityRecord;
        String rtName = opp.RecordType != null ? opp.RecordType.DeveloperName : null;

        data.projectPath = deriveProjectPath(opp);
        data.accountName = opp.Account != null ? opp.Account.Name : null;
        data.accountUrl = opp.AccountId != null ? '/lightning/r/Account/' + opp.AccountId + '/view' : null;
        data.stagePath = stagePathForRecord(rtName);

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

        Integer outreachCount = outreachAttemptsSince(opportunityId, opp.Last_Customer_Response_Date__c);
        data.engagement = buildEngagementHealth(opp, rtName, outreachCount);

        data.nextActionText = deriveNextActionText(opp, rtName, data.readiness, data.engagement, nextTask, data.lastActionWasVoicemail);
        data.nextActionButton = deriveNextActionButton(opp, rtName, data.readiness, data.engagement);

        data.designFeeStatus = opp.Design_Fee_Status__c;
        data.designFeePaidDate = opp.Design_Fee_Paid_Date__c != null ? String.valueOf(opp.Design_Fee_Paid_Date__c) : null;

        if (String.isBlank(data.projectPath)) {
            data.missingData.add('This opportunity is not classified as UpgradeMyBackyard or Design Build.');
        }
        if (data.propertyRecord == null) {
            data.missingData.add('No Homeowner Property record is linked to this opportunity.');
        }

        return data;
    }

    // ─── Engagement Health ───────────────────────────────────────────────────────

    private static Integer outreachAttemptsSince(Id oppId, Date lastResponseDate) {
        Date sinceDate = lastResponseDate != null ? lastResponseDate : Date.today().addDays(-180);
        Integer count = [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :oppId
            AND Status = 'Completed'
            AND ActivityDate >= :sinceDate
            AND (Subject LIKE '%call%' OR Subject LIKE '%voicemail%' OR Subject LIKE '%follow%' OR Subject LIKE '%text%')
        ];
        return count;
    }

    private static EngagementHealth buildEngagementHealth(Opportunity opp, String rtName, Integer outreachCount) {
        EngagementHealth eng = new EngagementHealth();

        if (opp.StageName == 'Closed Won' || opp.StageName == 'Closed Lost') {
            eng.state = 'N/A';
            eng.stateClass = 'engagement-na';
            eng.stateLabel = 'Closed';
            eng.daysSinceResponse = null;
            eng.outreachAttemptsSince = 0;
            eng.lastResponseDate = null;
            eng.callToAction = null;
            return eng;
        }

        ODL_Engagement_Threshold__mdt threshold = getThreshold(rtName);
        Integer slowingDays = threshold != null ? (Integer) threshold.Slowing_Days__c : 7;
        Integer goingDarkDays = threshold != null ? (Integer) threshold.Going_Dark_Days__c : 14;
        Integer minAttempts = threshold != null ? (Integer) threshold.Going_Dark_Min_Attempts__c : 3;
        Integer goingDarkWithAttemptsDays = threshold != null ? (Integer) threshold.Going_Dark_With_Attempts_Days__c : 7;

        Date responseDate = opp.Last_Customer_Response_Date__c;
        Integer daysSince = responseDate != null ? responseDate.daysBetween(Date.today()) : null;

        eng.daysSinceResponse = daysSince;
        eng.outreachAttemptsSince = outreachCount;
        eng.lastResponseDate = responseDate != null ? String.valueOf(responseDate) : null;

        if (daysSince == null) {
            // No response on record yet — treat as Going Dark if outreach has been made
            if (outreachCount >= minAttempts) {
                eng.state = 'Going Dark';
                eng.stateClass = 'engagement-dark';
                eng.stateLabel = 'Going Dark';
                eng.callToAction = 'Send final follow-up. If no reply, recycle to Marketing Cloud nurture or mark Closed Lost — No Decision / Non-Responsive.';
            } else {
                eng.state = 'Active';
                eng.stateClass = 'engagement-active';
                eng.stateLabel = 'Active';
                eng.callToAction = null;
            }
            return eng;
        }

        Boolean isGoingDarkByDays = daysSince >= goingDarkDays;
        Boolean isGoingDarkByAttempts = daysSince >= goingDarkWithAttemptsDays && outreachCount >= minAttempts;

        if (isGoingDarkByDays || isGoingDarkByAttempts) {
            eng.state = 'Going Dark';
            eng.stateClass = 'engagement-dark';
            eng.stateLabel = 'Going Dark';
            eng.callToAction = 'Send final follow-up. If no reply, recycle to Marketing Cloud nurture or mark Closed Lost — No Decision / Non-Responsive.';
        } else if (daysSince >= slowingDays) {
            eng.state = 'Slowing';
            eng.stateClass = 'engagement-slowing';
            eng.stateLabel = 'Slowing';
            eng.callToAction = 'Re-engage: call, text, or email today.';
        } else if (daysSince <= 1 && opp.Last_Customer_Response_Date__c != null) {
            eng.state = 'Re-engaged';
            eng.stateClass = 'engagement-reengaged';
            eng.stateLabel = 'Re-engaged';
            eng.callToAction = null;
        } else {
            eng.state = 'Active';
            eng.stateClass = 'engagement-active';
            eng.stateLabel = 'Active';
            eng.callToAction = null;
        }
        return eng;
    }

    @TestVisible
    private static ODL_Engagement_Threshold__mdt getThreshold(String rtName) {
        if (String.isBlank(rtName)) return null;
        List<ODL_Engagement_Threshold__mdt> rows = [
            SELECT Slowing_Days__c, Going_Dark_Days__c, Going_Dark_Min_Attempts__c, Going_Dark_With_Attempts_Days__c
            FROM ODL_Engagement_Threshold__mdt
            WHERE Record_Type_Name__c = :rtName
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    // ─── Path derivation ─────────────────────────────────────────────────────────

    private static String deriveProjectPath(Opportunity opp) {
        if (opp == null) return null;
        String rtName = opp.RecordType != null ? opp.RecordType.DeveloperName : null;
        if (rtName == 'UMB') return 'UpgradeMyBackyard';
        if (rtName == 'Design_Build') return 'Design Build';
        return null;
    }

    private static List<String> stagePathForRecord(String rtName) {
        if (rtName == 'UMB') return UMB_STAGE_PATH;
        if (rtName == 'Design_Build') return DB_STAGE_PATH;
        List<String> steps = new List<String>();
        for (Schema.PicklistEntry entry : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive()) steps.add(entry.getLabel());
        }
        return steps;
    }

    // ─── Readiness gate ──────────────────────────────────────────────────────────

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

    // ─── Next action engine — engagement-first, two paths by record type ─────────

    private static String deriveNextActionText(Opportunity opp, String rtName, ReadinessGate gate,
                                               EngagementHealth eng, Task nextTask, Boolean lastWasVoicemail) {
        if (opp.StageName == 'Closed Won') return 'Handoff to ops — opportunity is won';
        if (opp.StageName == 'Closed Lost') return 'Move to nurture — opportunity is lost';

        // Engagement gates first
        if (eng != null && eng.state == 'Going Dark') {
            return 'Going dark — send final follow-up, then recycle to nurture or mark Closed Lost (No Decision / Non-Responsive)';
        }
        if (eng != null && eng.state == 'Slowing') {
            return 'Slowing — re-engage: call, text, or email today';
        }

        if (rtName == 'UMB') return deriveUmbNextActionText(opp, gate);
        if (rtName == 'Design_Build') return deriveDbNextActionText(opp, gate);

        // Fallback for non-ODL records
        if (opp.LastActivityDate == null) return 'Make first contact';
        if (gate != null && gate.woReady) return 'Release work order';
        return 'Advance the deal';
    }

    private static String deriveUmbNextActionText(Opportunity opp, ReadinessGate gate) {
        if (opp.LastActivityDate == null) return 'Make first contact';
        if (gate != null && gate.woReady) return 'Release work order';
        if (gate != null && gate.quoteAccepted && !gate.contractSigned) return 'Confirm contract signature';
        if (gate != null && gate.quoteAccepted && gate.contractSigned && !gate.depositPaid) return 'Collect deposit';
        if (opp.Quote_Status__c == 'Sent') return 'Follow up on quote';
        if (opp.StageName == 'Quote Accepted' || opp.StageName == 'Proposal Presented') return 'Send contract';
        if (opp.StageName == 'Quote Sent') return 'Follow up on quote';
        if (opp.StageName == 'Consult Scheduled') return 'Prep package for consult';
        if (opp.StageName == 'Package Selected') return 'Book consult';
        if (opp.StageName == 'Qualifying') return 'Select a package';
        return 'Advance the deal';
    }

    private static String deriveDbNextActionText(Opportunity opp, ReadinessGate gate) {
        if (opp.LastActivityDate == null) return 'Make first contact';
        if (gate != null && gate.woReady) return 'Release work order';
        if (gate != null && gate.quoteAccepted && !gate.contractSigned) return 'Confirm contract signature';
        if (gate != null && gate.quoteAccepted && gate.contractSigned && !gate.depositPaid) return 'Collect deposit';
        if (opp.Quote_Status__c == 'Sent') return 'Follow up on proposal';
        if (opp.StageName == 'Proposal Presented') return 'Send contract';
        if (opp.StageName == 'Design Development') return 'Finalize proposal';
        if (opp.StageName == 'Consult Scheduled') return 'Prep design concepts for consult';
        if (opp.StageName == 'Design Agreement') return 'Collect design fee and schedule consult';
        if (opp.StageName == 'Discovery Consult') return 'Send design agreement';
        return 'Advance the deal';
    }

    private static String deriveNextActionButton(Opportunity opp, String rtName, ReadinessGate gate, EngagementHealth eng) {
        if (opp.StageName == 'Closed Won' || opp.StageName == 'Closed Lost') return null;

        if (eng != null && eng.state == 'Going Dark') return 'Follow Up';
        if (eng != null && eng.state == 'Slowing') return 'Call';

        if (opp.LastActivityDate == null) return 'Call';
        if (gate != null && gate.woReady) return 'Release';
        if (gate != null && gate.quoteAccepted && !gate.contractSigned) return 'Mark Signed';
        if (gate != null && gate.quoteAccepted && gate.contractSigned && !gate.depositPaid) return 'Request';

        if (opp.Quote_Status__c == 'Sent') return 'Call';
        if (opp.StageName == 'Quote Accepted' || opp.StageName == 'Proposal Presented') return 'Send';
        if (opp.StageName == 'Quote Sent') return 'Call';
        if (opp.StageName == 'Design Development') return 'Open';
        if (opp.StageName == 'Consult Scheduled') return 'Open';
        if (opp.StageName == 'Package Selected' || opp.StageName == 'Design Agreement') return 'Schedule';
        if (opp.StageName == 'Qualifying' || opp.StageName == 'Discovery Consult') return 'Advance';
        return 'Open';
    }

    // ─── Quote from opportunity status field ─────────────────────────────────────

    private static List<RowData> quoteFromStatus(Opportunity opp) {
        List<RowData> rows = new List<RowData>();
        if (String.isBlank(opp.Quote_Status__c) || opp.Quote_Status__c == 'Not Sent') return rows;
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
                SELECT Id, Subject, MessageDate, FromName, FromAddress, ToAddress, TextBody, Incoming
                FROM EmailMessage
                WHERE RelatedToId = :opportunityId
                ORDER BY MessageDate DESC
                LIMIT 10
            ]) {
                RowData row = new RowData();
                row.id = emailRow.Id;
                row.url = '/' + emailRow.Id;
                row.label = firstNonBlank(new List<String>{ emailRow.Subject, 'Logged Email' });
                row.status = emailRow.Incoming ? 'Inbound Email' : 'Outbound Email';
                row.subtext = emailRow.Incoming ? emailRow.FromAddress : emailRow.ToAddress;
                row.dateText = emailRow.MessageDate != null ? emailRow.MessageDate.format('M/d/yyyy h:mm a') : null;
                row.notesPreview = String.isBlank(emailRow.TextBody) ? 'No email preview' : trimPreview(emailRow.TextBody);
                row.interactionType = emailRow.Incoming ? 'Inbound Email' : 'Email Sent';
                row.chipClass = emailRow.Incoming ? 'chip chip-green' : 'chip chip-blue';
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
            if (!isCompletedTask(taskRow)) continue;
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
        if (interactionType == 'Email Sent' || interactionType == 'Outbound Email') return 'chip chip-blue';
        if (interactionType == 'Inbound Email') return 'chip chip-green';
        if (interactionType == 'Call Completed') return 'chip chip-green';
        if (interactionType == 'Consult Scheduled') return 'chip chip-blue';
        if (interactionType == 'Quote Sent') return 'chip chip-amber';
        return 'chip chip-gray';
    }

    // ─── Other related data ───────────────────────────────────────────────────────

    private static List<RowData> designReviews(Id opportunityId) {
        List<RowData> rows = new List<RowData>();
        try {
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
        } catch (Exception e) {
            // Design_Review__c may not exist in all orgs; return empty
        }
        return rows;
    }

    private static List<RowData> paymentMilestones(Id opportunityId) {
        List<RowData> rows = new List<RowData>();
        try {
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
        } catch (Exception e) {
            // Payment_Milestone__c may not exist; return empty
        }
        return rows;
    }

    private static RowData propertyRecord(Id opportunityId) {
        try {
            List<Homeowner_Property__c> rows = [
                SELECT Id, Name, Community__r.Name, Lot__r.Name, Homeowner_Account__r.Name
                FROM Homeowner_Property__c
                WHERE Opportunity__c = :opportunityId
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (rows.isEmpty()) return null;
            Homeowner_Property__c propertyRow = rows[0];
            RowData row = new RowData();
            row.id = propertyRow.Id;
            row.url = '/' + propertyRow.Id;
            row.label = propertyRow.Name;
            row.status = propertyRow.Community__r != null ? propertyRow.Community__r.Name : null;
            row.subtext = propertyRow.Lot__r != null ? propertyRow.Lot__r.Name : null;
            row.secondaryText = propertyRow.Homeowner_Account__r != null ? propertyRow.Homeowner_Account__r.Name : null;
            return row;
        } catch (Exception e) {
            return null;
        }
    }

    private static RowData voucherRecord(Id opportunityId) {
        if (!Schema.getGlobalDescribe().containsKey('Voucher__c')) return null;
        List<SObject> rows = Database.query(
            'SELECT Id, Name, Voucher_Code__c, Status__c, Voucher_Type__c, Builder_Account__c ' +
            'FROM Voucher__c WHERE Reserved_Opportunity__c = :opportunityId ORDER BY CreatedDate DESC LIMIT 1'
        );
        if (rows.isEmpty()) return null;
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
        return 'Activity Logged';
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