public with sharing class HomeownerAccountPageController {
    public class KpiData {
        @AuraEnabled public Integer openOpportunities;
        @AuraEnabled public Integer openWorkOrders;
        @AuraEnabled public Integer openCases;
        @AuraEnabled public Integer scheduledInteractions;
        @AuraEnabled public Integer openTasks;
    }

    public class RowData {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public String subjectText;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String subtext;
        @AuraEnabled public String dateText;
        @AuraEnabled public String relatedLabel;
        @AuraEnabled public String relatedUrl;
        @AuraEnabled public String notesPreview;
        @AuraEnabled public String interactionType;
        @AuraEnabled public String actionLabel;
        @AuraEnabled public String secondaryText;
        @AuraEnabled public String relationshipSource;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotLabel;
        @AuraEnabled public String relatedOpportunityLabel;
        @AuraEnabled public String relatedOpportunityUrl;
        @AuraEnabled public String scheduledDateText;
        @AuraEnabled public String serviceAppointmentLabel;
        @AuraEnabled public String serviceAppointmentUrl;
    }

    public class MissingDataItem {
        @AuraEnabled public String label;
        @AuraEnabled public String detail;

        public MissingDataItem(String label, String detail) {
            this.label = label;
            this.detail = detail;
        }
    }

    public class PropertyContextData {
        @AuraEnabled public String address;
        @AuraEnabled public String propertyName;
        @AuraEnabled public String propertyLabel;
        @AuraEnabled public String propertyUrl;
        @AuraEnabled public String projectLabel;
        @AuraEnabled public String projectUrl;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotLabel;
        @AuraEnabled public String packageName;
        @AuraEnabled public String layoutUrl;
        @AuraEnabled public Boolean layoutAttached;
        @AuraEnabled public String note;
        @AuraEnabled public String accessType;
        @AuraEnabled public String drainageRisk;
        @AuraEnabled public String utilityReviewStatus;
        @AuraEnabled public String customerReadiness;
        @AuraEnabled public String propertyNotes;
    }

    public class PageData {
        @AuraEnabled public Account accountRecord;
        @AuraEnabled public KpiData kpis;
        @AuraEnabled public List<RowData> opportunities;
        @AuraEnabled public List<RowData> vouchers;
        @AuraEnabled public List<RowData> workOrders;
        @AuraEnabled public List<RowData> interactions;
        @AuraEnabled public List<RowData> designReviews;
        @AuraEnabled public List<RowData> paymentMilestones;
        @AuraEnabled public List<RowData> files;
        @AuraEnabled public List<RowData> notes;
        @AuraEnabled public List<MissingDataItem> missingData;
        @AuraEnabled public String mailingAddress;
        @AuraEnabled public String contactDisplay;
        @AuraEnabled public String householdDisplayName;
        @AuraEnabled public Id secondaryContactId;
        @AuraEnabled public String secondaryContactName;
        @AuraEnabled public String secondaryContactEmail;
        @AuraEnabled public String secondaryContactPhone;
        @AuraEnabled public String householdEmailDisplay;
        @AuraEnabled public PropertyContextData propertyContext;
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

    public class ScheduledInteractionResult {
        @AuraEnabled public Id eventId;
        @AuraEnabled public Boolean confirmationSent;
        @AuraEnabled public String confirmationMessage;
    }

    @AuraEnabled(cacheable=true)
    public static PageData getPageData(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is required.');
        }

        PageData data = new PageData();
        data.accountRecord = [
            SELECT Id, Name, Type, Owner.Name, Phone, PersonMobilePhone, PersonEmail, PersonContactId,
                   PersonMailingStreet, PersonMailingCity, PersonMailingState,
                   PersonMailingPostalCode, BillingStreet, BillingCity, BillingState, BillingPostalCode,
                   Payment_Method__c, Description, Customer_Health__c, Preferred_Contact_Method__c,
                   Portal_Status__c, SMS_Opt_In__c,
                   ODL_Household_Display_Name__c, ODL_Secondary_Contact__c,
                   ODL_Secondary_Contact__r.Name, ODL_Secondary_Contact__r.Email,
                   ODL_Secondary_Contact__r.Phone, ODL_Secondary_Contact__r.MobilePhone
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        data.kpis = new KpiData();
        data.opportunities = new List<RowData>();
        data.vouchers = new List<RowData>();
        data.workOrders = new List<RowData>();
        data.interactions = new List<RowData>();
        data.designReviews = new List<RowData>();
        data.paymentMilestones = new List<RowData>();
        data.files = new List<RowData>();
        data.notes = new List<RowData>();
        data.missingData = new List<MissingDataItem>();
        Set<Id> householdContactIds = householdContactIds(data.accountRecord);
        data.mailingAddress = formatAddress(
            firstNonBlank(new List<String>{ data.accountRecord.PersonMailingStreet, data.accountRecord.BillingStreet }),
            firstNonBlank(new List<String>{ data.accountRecord.PersonMailingCity, data.accountRecord.BillingCity }),
            firstNonBlank(new List<String>{ data.accountRecord.PersonMailingState, data.accountRecord.BillingState }),
            firstNonBlank(new List<String>{ data.accountRecord.PersonMailingPostalCode, data.accountRecord.BillingPostalCode })
        );
        data.householdDisplayName = firstNonBlank(new List<String>{
            (String) data.accountRecord.get('ODL_Household_Display_Name__c'),
            data.accountRecord.Name
        });
        data.secondaryContactId = (Id) data.accountRecord.get('ODL_Secondary_Contact__c');
        SObject secondaryContact = data.accountRecord.getSObject('ODL_Secondary_Contact__r');
        if (secondaryContact != null) {
            data.secondaryContactName = (String) secondaryContact.get('Name');
            data.secondaryContactEmail = (String) secondaryContact.get('Email');
            data.secondaryContactPhone = firstNonBlank(new List<String>{
                (String) secondaryContact.get('MobilePhone'),
                (String) secondaryContact.get('Phone')
            });
        }
        data.householdEmailDisplay = String.join(new List<String>(householdRecipientEmails(data.accountRecord)), '; ');

        Map<String, String> opportunityTypeLabels = picklistLabelByValue(Opportunity.Type);
        List<Opportunity> candidateOpps = [
            SELECT Id, Name, StageName, Amount, CloseDate, Owner.Name, Type, LastActivityDate,
                   Community_Name__c, Lot_Layout_Attached__c, Lot_Layout_Link__c, BMG_Package__c,
                   Services_Selected__c, LeadSource
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = false
            ORDER BY LastModifiedDate DESC
            LIMIT 25
        ];
        List<Opportunity> opps = filterOdlOpportunities(candidateOpps, opportunityTypeLabels, 5);
        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opp : opps) {
            opportunityIds.add(opp.Id);
        }
        Set<Id> interactionWhatIds = new Set<Id>{ accountId };
        interactionWhatIds.addAll(opportunityIds);

        data.kpis.openOpportunities = opps.size();
        data.kpis.openCases = (Integer) [SELECT COUNT() FROM Case WHERE AccountId = :accountId AND IsClosed = false];
        data.kpis.openTasks = !householdContactIds.isEmpty()
            ? (Integer) [SELECT COUNT() FROM Task WHERE (WhatId = :accountId OR WhoId IN :householdContactIds) AND IsClosed = false]
            : (Integer) [SELECT COUNT() FROM Task WHERE WhatId = :accountId AND IsClosed = false];
        data.kpis.scheduledInteractions = (Integer) [
            SELECT COUNT()
            FROM Event
            WHERE WhatId IN :interactionWhatIds
            AND ActivityDateTime >= :System.now()
        ];
        Map<Id, ActivitySnapshot> latestActivityByOpportunity = latestActivityByOpportunity(opportunityIds);
        Map<Id, Date> nextOpportunityFollowUp = nextTaskDateByWhatId(opportunityIds);
        for (Opportunity opp : opps) {
            RowData row = new RowData();
            row.id = opp.Id;
            row.url = '/' + opp.Id;
            row.label = opp.Name;
            row.status = opp.StageName;
            row.ownerName = opp.Owner != null ? opp.Owner.Name : null;
            row.subtext = deriveProjectPath(opp, opportunityTypeLabels);
            ActivitySnapshot activity = latestActivityByOpportunity.get(opp.Id);
            row.subjectText = activity != null ? activity.label : null;
            row.dateText = activity != null && activity.occurredAt != null
                ? activity.occurredAt.format('M/d/yyyy')
                : (opp.LastActivityDate != null ? String.valueOf(opp.LastActivityDate) : null);
            row.secondaryText = nextOpportunityFollowUp.containsKey(opp.Id)
                ? String.valueOf(nextOpportunityFollowUp.get(opp.Id))
                : null;
            row.notesPreview = opp.Amount != null ? '$' + String.valueOf(opp.Amount.setScale(0)) : null;
            row.relatedLabel = firstNonBlank(new List<String>{
                normalizePackageName(opp.BMG_Package__c),
                opp.Services_Selected__c
            });
            row.actionLabel = 'Open';
            data.opportunities.add(row);
        }

        Map<Id, RowData> designReviewByOpportunity = designReviewByOpportunity(opportunityIds);
        for (Opportunity opp : opps) {
            RowData designReview = designReviewByOpportunity.get(opp.Id);
            if (designReview != null) {
                data.designReviews.add(designReview);
            }
        }

        Map<Id, List<RowData>> milestonesByOpportunity = paymentMilestonesByOpportunity(opportunityIds);
        for (Opportunity opp : opps) {
            if (milestonesByOpportunity.containsKey(opp.Id)) {
                data.paymentMilestones.addAll(milestonesByOpportunity.get(opp.Id));
            }
        }
        if (data.paymentMilestones.size() > 5) {
            List<RowData> limitedMilestones = new List<RowData>();
            for (Integer i = 0; i < 5; i++) {
                limitedMilestones.add(data.paymentMilestones[i]);
            }
            data.paymentMilestones = limitedMilestones;
        }

        Set<Id> voucherContactIds = new Set<Id>();
        if (data.accountRecord.PersonContactId != null) {
            voucherContactIds.add(data.accountRecord.PersonContactId);
        }
        voucherContactIds.addAll(householdContactIds);
        List<Voucher__c> voucherRows = [
            SELECT Id, Name, Voucher_Code__c, Status__c, Voucher_Type__c, Campaign__c, Campaign__r.Name,
                   Reserved_Opportunity__c, Reserved_Opportunity__r.Name, Redeemed_Quote__c, Redeemed_Quote__r.Name,
                   Expiration_Date__c, Contact__c, Homeowner_Lead__c
            FROM Voucher__c
            WHERE Reserved_Opportunity__c IN :opportunityIds
               OR Contact__c IN :voucherContactIds
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
        for (Voucher__c voucherRow : voucherRows) {
            RowData row = new RowData();
            row.id = voucherRow.Id;
            row.url = '/' + voucherRow.Id;
            row.label = firstNonBlank(new List<String>{ voucherRow.Voucher_Code__c, voucherRow.Name });
            row.status = voucherRow.Status__c;
            row.subtext = voucherRow.Voucher_Type__c;
            row.relatedLabel = voucherRow.Campaign__r == null ? null : voucherRow.Campaign__r.Name;
            row.relatedUrl = voucherRow.Campaign__c == null ? null : '/' + voucherRow.Campaign__c;
            row.relatedOpportunityLabel = voucherRow.Reserved_Opportunity__r == null ? null : voucherRow.Reserved_Opportunity__r.Name;
            row.relatedOpportunityUrl = voucherRow.Reserved_Opportunity__c == null ? null : '/' + voucherRow.Reserved_Opportunity__c;
            row.secondaryText = voucherRow.Redeemed_Quote__r == null ? null : voucherRow.Redeemed_Quote__r.Name;
            row.dateText = voucherRow.Expiration_Date__c == null ? null : String.valueOf(voucherRow.Expiration_Date__c);
            row.actionLabel = 'Open';
            data.vouchers.add(row);
        }
        if (data.vouchers.isEmpty()) {
            for (Opportunity voucherOpp : [
                SELECT Id, Name, StageName, LeadSource, Type
                FROM Opportunity
                WHERE AccountId = :accountId
                AND (Name LIKE '%Voucher%' OR LeadSource LIKE '%Voucher%')
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ]) {
                RowData row = new RowData();
                row.id = voucherOpp.Id;
                row.url = '/' + voucherOpp.Id;
                row.label = voucherOpp.Name;
                row.status = voucherOpp.StageName;
                row.subtext = 'Voucher-sourced opportunity';
                row.relatedOpportunityLabel = voucherOpp.Name;
                row.relatedOpportunityUrl = '/' + voucherOpp.Id;
                row.secondaryText = voucherOpp.LeadSource;
                row.actionLabel = 'Open Opportunity';
                data.vouchers.add(row);
            }
        }

        data.files = relatedFiles(accountId, opportunityIds);
        data.notes = relatedNotes(accountId, opportunityIds);

        List<RowData> workOrderRows = resolveHomeownerWorkOrders(accountId, householdContactIds, opportunityIds);
        data.kpis.openWorkOrders = workOrderRows.size();
        for (RowData row : workOrderRows) {
            data.workOrders.add(row);
        }

        Set<Id> workOrderIds = new Set<Id>();
        for (RowData row : workOrderRows) {
            workOrderIds.add(row.id);
        }
        Map<Id, ServiceAppointment> appointmentByWorkOrder = firstAppointmentByWorkOrder(workOrderIds);
        for (RowData row : data.workOrders) {
            ServiceAppointment appt = appointmentByWorkOrder.get(row.id);
            if (appt != null) {
                row.serviceAppointmentLabel = 'SA ' + firstNonBlank(new List<String>{ appt.AppointmentNumber, appt.Id });
                row.serviceAppointmentUrl = '/' + appt.Id;
                row.scheduledDateText = appt.SchedStartTime != null ? appt.SchedStartTime.format('M/d/yyyy h:mm a') : null;
            } else {
                row.serviceAppointmentLabel = null;
                row.scheduledDateText = null;
            }
            row.relatedLabel = row.serviceAppointmentLabel;
            row.relatedUrl = row.serviceAppointmentUrl;
            row.actionLabel = row.scheduledDateText;
        }

        Map<Id, String> relatedLabels = new Map<Id, String>();
        relatedLabels.put(accountId, data.accountRecord.Name);
        for (Opportunity opp : opps) {
            relatedLabels.put(opp.Id, opp.Name);
        }

        List<DatedRow> datedInteractions = new List<DatedRow>();

        if (Schema.SObjectType.EmailMessage.isAccessible()) {
            for (EmailMessage emailRow : [
                SELECT Id, RelatedToId, Subject, MessageDate, FromName, FromAddress, ToAddress, TextBody
                FROM EmailMessage
                WHERE RelatedToId IN :interactionWhatIds
                ORDER BY MessageDate DESC
                LIMIT 10
            ]) {
                RowData row = new RowData();
                row.id = emailRow.Id;
                row.url = '/' + emailRow.Id;
                row.label = firstNonBlank(new List<String>{ emailRow.Subject, 'Logged Email' });
                row.subjectText = row.label;
                row.status = 'Logged Email';
                row.ownerName = firstNonBlank(new List<String>{ emailRow.FromName, emailRow.FromAddress });
                row.subtext = firstNonBlank(new List<String>{ emailRow.ToAddress, 'Email' });
                row.dateText = emailRow.MessageDate != null ? emailRow.MessageDate.format('M/d/yyyy h:mm a') : null;
                row.relatedLabel = relatedLabels.containsKey(emailRow.RelatedToId) ? relatedLabels.get(emailRow.RelatedToId) : data.accountRecord.Name;
                row.relatedUrl = emailRow.RelatedToId != null ? '/' + emailRow.RelatedToId : '/' + accountId;
                row.notesPreview = trimPreview(emailRow.TextBody);
                row.interactionType = 'Email';
                row.actionLabel = 'Open';
                datedInteractions.add(wrapDatedRow(row, emailRow.MessageDate));
            }
        }

        for (Event evt : [
            SELECT Id, Subject, Type, ActivityDateTime, DurationInMinutes, Description, Location, Owner.Name, WhatId, WhoId
            FROM Event
            WHERE WhatId IN :interactionWhatIds
            ORDER BY ActivityDateTime DESC, LastModifiedDate DESC
            LIMIT 10
        ]) {
            RowData row = new RowData();
            row.id = evt.Id;
            row.url = '/' + evt.Id;
            row.label = evt.Subject;
            row.subjectText = evt.Subject;
            row.status = evt.ActivityDateTime != null && evt.ActivityDateTime >= System.now() ? 'Scheduled' : 'Completed';
            row.ownerName = evt.Owner != null ? evt.Owner.Name : null;
            row.subtext = evt.DurationInMinutes != null ? String.valueOf(evt.DurationInMinutes) + ' min' : firstNonBlank(new List<String>{ evt.Location, 'Event' });
            row.dateText = evt.ActivityDateTime != null ? evt.ActivityDateTime.format('M/d/yyyy h:mm a') : null;
            row.relatedLabel = relatedLabels.containsKey(evt.WhatId) ? relatedLabels.get(evt.WhatId) : data.accountRecord.Name;
            row.relatedUrl = evt.WhatId != null ? '/' + evt.WhatId : '/' + accountId;
            row.notesPreview = trimPreview(evt.Description);
            row.interactionType = deriveInteractionLabel(evt);
            row.actionLabel = 'Open';
            datedInteractions.add(wrapDatedRow(row, evt.ActivityDateTime));
        }

        List<Task> tasks;
        if (!householdContactIds.isEmpty()) {
            tasks = [
                SELECT Id, Subject, Status, ActivityDate, Description, TaskSubtype, CallDisposition, Owner.Name, WhatId, WhoId, CreatedDate
                FROM Task
                WHERE (WhatId = :accountId OR WhatId IN :opportunityIds OR WhoId IN :householdContactIds)
                ORDER BY CreatedDate DESC, LastModifiedDate DESC
                LIMIT 20
            ];
        } else {
            tasks = [
                SELECT Id, Subject, Status, ActivityDate, Description, TaskSubtype, CallDisposition, Owner.Name, WhatId, WhoId, CreatedDate
                FROM Task
                WHERE WhatId = :accountId OR WhatId IN :opportunityIds
                ORDER BY CreatedDate DESC, LastModifiedDate DESC
                LIMIT 20
            ];
        }

        for (Task task : tasks) {
            if (!isCompletedTask(task)) {
                continue;
            }
            Datetime occurredAt = task.CreatedDate;
            if (task.ActivityDate != null) {
                occurredAt = Datetime.newInstance(task.ActivityDate, Time.newInstance(12, 0, 0, 0));
            }
            RowData row = new RowData();
            row.id = task.Id;
            row.url = '/' + task.Id;
            row.label = task.Subject;
            row.subjectText = task.Subject;
            row.status = task.Status;
            row.ownerName = task.Owner != null ? task.Owner.Name : null;
            row.subtext = task.CallDisposition;
            row.dateText = task.ActivityDate != null ? String.valueOf(task.ActivityDate) : null;
            row.relatedLabel = relatedLabels.containsKey(task.WhatId) ? relatedLabels.get(task.WhatId) : data.accountRecord.Name;
            row.relatedUrl = task.WhatId != null ? '/' + task.WhatId : '/' + accountId;
            row.notesPreview = trimPreview(task.Description);
            row.interactionType = deriveTaskInteractionType(task);
            row.actionLabel = 'Open';
            datedInteractions.add(wrapDatedRow(row, occurredAt));
        }
        datedInteractions.sort();
        Integer interactionLimit = Math.min(8, datedInteractions.size());
        for (Integer i = 0; i < interactionLimit; i++) {
            data.interactions.add(datedInteractions[i].row);
        }

        data.contactDisplay = firstNonBlank(new List<String>{
            data.accountRecord.Name,
            data.accountRecord.PersonEmail,
            data.accountRecord.PersonMobilePhone,
            data.accountRecord.Phone
        });
        data.propertyContext = buildPropertyContext(accountId, data.mailingAddress, opps, opportunityIds);

        return data;
    }

    @AuraEnabled
    public static ScheduledInteractionResult createScheduledInteraction(
        Id accountId,
        String interactionType,
        Datetime startDateTime,
        Integer durationMinutes,
        String notes
    ) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is required.');
        }
        if (String.isBlank(interactionType)) {
            throw new AuraHandledException('Interaction type is required.');
        }
        if (startDateTime == null) {
            throw new AuraHandledException('Start date and time are required.');
        }
        if (!Schema.SObjectType.Event.isCreateable()) {
            throw new AuraHandledException('You do not have access to schedule interactions.');
        }

        Account acct = [
            SELECT Id, Name, PersonContactId, PersonEmail, PersonMailingStreet, PersonMailingCity, PersonMailingState, PersonMailingPostalCode,
                   ODL_Household_Display_Name__c, ODL_Secondary_Contact__c,
                   ODL_Secondary_Contact__r.Name, ODL_Secondary_Contact__r.Email,
                   ODL_Secondary_Contact__r.Phone, ODL_Secondary_Contact__r.MobilePhone
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        Opportunity contextOpportunity = resolveSingleActiveOpportunity(accountId);
        Id relatedRecordId = contextOpportunity != null ? contextOpportunity.Id : accountId;
        Id preferredWhoId = ODLHouseholdService.preferredHouseholdContactId(acct);

        Event evt = new Event();
        evt.ActivityDateTime = startDateTime;
        evt.DurationInMinutes = (durationMinutes == null || durationMinutes <= 0) ? 30 : durationMinutes;
        evt.WhatId = relatedRecordId;
        if (preferredWhoId != null && Schema.SObjectType.Event.fields.getMap().get('WhoId').getDescribe().isCreateable()) {
            evt.WhoId = preferredWhoId;
        }

        String normalizedType = interactionType.trim().toLowerCase();
        if (normalizedType == 'call') {
            putIfCreateable(evt, 'Subject', 'Call');
            putIfCreateable(evt, 'Type', pickFirstSupportedEventType(new List<String>{ 'Call' }));
            putIfCreateable(evt, 'Description', buildNotes('Call summary', notes));
        } else if (normalizedType == 'virtual') {
            putIfCreateable(evt, 'Subject', 'Virtual Visit');
            putIfCreateable(evt, 'Type', pickFirstSupportedEventType(new List<String>{ 'Meeting' }));
            putIfCreateable(evt, 'Description', buildNotes('Visit notes', notes));
            putIfCreateable(evt, 'Location', 'Virtual');
        } else if (normalizedType == 'onsite') {
            putIfCreateable(evt, 'Subject', 'Onsite Visit');
            putIfCreateable(evt, 'Type', pickFirstSupportedEventType(new List<String>{ 'Consultation Meeting', 'Meeting' }));
            putIfCreateable(evt, 'Description', buildNotes('Visit notes', notes));
            putIfCreateable(evt, 'Location', firstNonBlank(new List<String>{
                formatAddress(acct.PersonMailingStreet, acct.PersonMailingCity, acct.PersonMailingState, acct.PersonMailingPostalCode),
                'Onsite'
            }));
        } else {
            throw new AuraHandledException('Unsupported interaction type.');
        }

        insert evt;
        ScheduledInteractionResult result = new ScheduledInteractionResult();
        result.eventId = evt.Id;
        result.confirmationSent = false;
        result.confirmationMessage = sendHomeownerSchedulingConfirmation(acct, contextOpportunity, evt, normalizedType);
        if (result.confirmationMessage == 'Confirmation email sent.') {
            result.confirmationSent = true;
        }
        return result;
    }

    private static String formatAddress(String street, String city, String state, String postalCode) {
        List<String> lines = new List<String>();
        if (!String.isBlank(street)) {
            lines.add(street);
        }
        List<String> cityStateZip = new List<String>();
        if (!String.isBlank(city)) {
            cityStateZip.add(city);
        }
        if (!String.isBlank(state)) {
            cityStateZip.add(state);
        }
        String suffix = String.join(cityStateZip, ', ');
        if (!String.isBlank(postalCode)) {
            suffix = String.isBlank(suffix) ? postalCode : suffix + ' ' + postalCode;
        }
        if (!String.isBlank(suffix)) {
            lines.add(suffix);
        }
        return String.join(lines, '\n');
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String deriveInteractionLabel(Event evt) {
        String typeValue = String.isBlank(evt.Type) ? evt.Subject : evt.Type;
        if (typeValue == 'Call') {
            return 'Call';
        }
        if (typeValue == 'Consultation Meeting') {
            return 'Onsite Visit';
        }
        if (typeValue == 'Meeting') {
            if (!String.isBlank(evt.Location) && evt.Location.toLowerCase().contains('virtual')) {
                return 'Virtual Visit';
            }
            return 'Virtual Visit';
        }
        return String.isBlank(evt.Subject) ? 'Scheduled interaction' : evt.Subject;
    }

    private static String deriveTaskInteractionLabel(Task task) {
        if (task.TaskSubtype == 'Call') {
            return 'Call';
        }
        return String.isBlank(task.Subject) ? 'Task' : task.Subject;
    }

    private static String deriveTaskInteractionType(Task task) {
        if (task.TaskSubtype == 'Call') {
            return 'Call';
        }
        return 'Task';
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

    private static String buildNotes(String heading, String notes) {
        if (String.isBlank(notes)) {
            return heading + ':';
        }
        return heading + ':\n' + notes.trim();
    }

    private static void putIfCreateable(SObject target, String fieldApiName, Object value) {
        if (value == null) {
            return;
        }
        Schema.DescribeFieldResult describe = target.getSObjectType().getDescribe().fields.getMap().get(fieldApiName).getDescribe();
        if (describe != null && describe.isCreateable()) {
            target.put(fieldApiName, value);
        }
    }

    private static String pickFirstSupportedEventType(List<String> values) {
        return pickFirstSupportedPicklistValue(Event.SObjectType, 'Type', values);
    }

    private static String pickFirstSupportedEventSubject(List<String> values) {
        return pickFirstSupportedPicklistValue(Event.SObjectType, 'Subject', values);
    }

    private static Opportunity resolveSingleActiveOpportunity(Id accountId) {
        Map<String, String> typeLabels = picklistLabelByValue(Opportunity.Type);
        List<Opportunity> candidates = [
            SELECT Id, Name, Type, LeadSource
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = false
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ];
        List<Opportunity> activeOpps = filterOdlOpportunities(candidates, typeLabels, 2);
        if (activeOpps.size() > 1) {
            throw new AuraHandledException('Multiple active opportunities were found. Open the specific opportunity to schedule this interaction.');
        }
        return activeOpps.isEmpty() ? null : activeOpps[0];
    }

    private static String sendHomeownerSchedulingConfirmation(Account acct, Opportunity opp, Event evt, String interactionType) {
        Set<String> recipientEmails = householdRecipientEmails(acct);
        if (recipientEmails.isEmpty()) {
            return 'Homeowner appointment confirmation not sent because no primary or secondary household email is available.';
        }

        String businessPath = resolveBusinessPath(opp);
        String briefDescription = resolveBriefDescription(opp, businessPath);
        String interactionLabel = interactionTypeLabel(interactionType);
        String subject = businessPath + ' | ' + briefDescription + ' | ' + interactionLabel + ' Scheduled';
        if (subject.contains('thread::')) {
            subject = subject.replace('thread::', '');
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setToAddresses(new List<String>(recipientEmails));
        Id targetObjectId = ODLHouseholdService.preferredHouseholdContactId(acct);
        if (targetObjectId != null) {
            message.setTargetObjectId(targetObjectId);
            message.setTreatTargetObjectAsRecipient(false);
        }
        if (opp != null) {
            message.setWhatId(opp.Id);
        }
        message.setSaveAsActivity(true);
        message.setUseSignature(false);
        message.setSubject(subject);
        message.setHtmlBody(buildHomeownerConfirmationBody(acct, opp, evt, businessPath, briefDescription, interactionLabel));
        Id orgWideEmailAddressId = noReplyOrgWideEmailAddressId();
        if (orgWideEmailAddressId != null) {
            message.setOrgWideEmailAddressId(orgWideEmailAddressId);
        }
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ message });
        return 'Confirmation email sent.';
    }

    private static Id noReplyOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> matches = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = 'no-reply@upgrademybackyard.com'
            LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0].Id;
    }

    private static String resolveBusinessPath(Opportunity opp) {
        String path = deriveProjectPath(opp, picklistLabelByValue(Opportunity.Type));
        if (!String.isBlank(path)) {
            return path;
        }
        if (opp != null && opp.Type != null && opp.Type.toLowerCase().contains('lawn')) {
            return 'Lawn Care';
        }
        return 'Upgrade My Backyard';
    }

    private static String resolveBriefDescription(Opportunity opp, String businessPath) {
        if (opp != null && !String.isBlank(opp.Name)) {
            String candidate = opp.Name.trim();
            if (candidate.contains(' - ')) {
                candidate = candidate.substringAfterLast(' - ').trim();
            } else if (candidate.contains('-')) {
                candidate = candidate.substringAfterLast('-').trim();
            }
            if (isHumanReadableDescription(candidate)) {
                return candidate;
            }
        }

        if (businessPath == 'Design Build') {
            return 'Custom Build Site Visit';
        }
        return 'Design Consultation';
    }

    private static Boolean isHumanReadableDescription(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        if (Pattern.matches('^[a-zA-Z0-9]{15,18}$', value)) {
            return false;
        }
        return true;
    }

    private static String interactionTypeLabel(String interactionType) {
        if (interactionType == 'call') {
            return 'Call';
        }
        if (interactionType == 'virtual') {
            return 'Virtual Visit';
        }
        if (interactionType == 'onsite') {
            return 'Onsite Visit';
        }
        return 'Visit';
    }

    private static String buildHomeownerConfirmationBody(
        Account acct,
        Opportunity opp,
        Event evt,
        String businessPath,
        String briefDescription,
        String interactionLabel
    ) {
        List<String> lines = new List<String>();
        lines.add('<p>Hi ' + escapeHtml(firstNameFromAccount(acct)) + ',</p>');
        lines.add('<p>Your ' + escapeHtml(interactionLabel) + ' has been scheduled.</p>');
        lines.add('<p><strong>Details:</strong></p>');
        lines.add('<ul>');
        lines.add('<li><strong>Type:</strong> ' + escapeHtml(interactionLabel) + '</li>');
        lines.add('<li><strong>Date:</strong> ' + escapeHtml(evt.ActivityDateTime.format('M/d/yyyy')) + '</li>');
        lines.add('<li><strong>Time:</strong> ' + escapeHtml(evt.ActivityDateTime.format('h:mm a')) + '</li>');
        lines.add('<li><strong>Project:</strong> ' + escapeHtml(businessPath) + '</li>');
        lines.add('<li><strong>Description:</strong> ' + escapeHtml(briefDescription) + '</li>');
        if (interactionLabel == 'Onsite Visit') {
            lines.add('<li><strong>Address:</strong> ' + escapeHtml(firstNonBlank(new List<String>{
                formatAddress(acct.PersonMailingStreet, acct.PersonMailingCity, acct.PersonMailingState, acct.PersonMailingPostalCode),
                evt.Location
            })) + '</li>');
        } else if (!String.isBlank(evt.Location)) {
            lines.add('<li><strong>Location:</strong> ' + escapeHtml(evt.Location) + '</li>');
        }
        lines.add('</ul>');
        lines.add('<p>What to expect:<br/>A LOVING team member will review your project goals, confirm the scope, and answer any questions about next steps.</p>');
        lines.add('<p>Thank you,</p>');
        lines.add('<p>The Upgrade My Backyard Team<br/>The LOVING Companies<br/>no-reply@upgrademybackyard.com<br/><a href=\"https://www.upgrademybackyard.com/\" target=\"_blank\" rel=\"noopener noreferrer\">www.upgrademybackyard.com</a></p>');
        return String.join(lines, '');
    }

    private static String firstNameFromAccount(Account acct) {
        if (acct == null) {
            return 'there';
        }
        SObject secondaryContact = acct.getSObject('ODL_Secondary_Contact__r');
        if (secondaryContact != null) {
            String secondaryName = (String) secondaryContact.get('Name');
            if (!String.isBlank(secondaryName)) {
                return secondaryName.contains(' ') ? secondaryName.substringBefore(' ') : secondaryName;
            }
        }
        if (String.isBlank(acct.Name)) {
            return 'there';
        }
        return acct.Name.contains(' ') ? acct.Name.substringBefore(' ') : acct.Name;
    }

    private static Set<Id> householdContactIds(Account acct) {
        Set<Id> contactIds = new Set<Id>();
        if (acct == null) {
            return contactIds;
        }
        if (acct.PersonContactId != null) {
            contactIds.add(acct.PersonContactId);
        }
        Id secondaryContactId = (Id) acct.get('ODL_Secondary_Contact__c');
        if (secondaryContactId != null) {
            contactIds.add(secondaryContactId);
        }
        return contactIds;
    }

    private static Set<String> householdRecipientEmails(Account acct) {
        Set<String> emails = new Set<String>();
        if (acct == null) {
            return emails;
        }
        if (!String.isBlank(acct.PersonEmail)) {
            emails.add(acct.PersonEmail.trim());
        }
        SObject secondaryContact = acct.getSObject('ODL_Secondary_Contact__r');
        if (secondaryContact != null) {
            String secondaryEmail = (String) secondaryContact.get('Email');
            if (!String.isBlank(secondaryEmail)) {
                emails.add(secondaryEmail.trim());
            }
        }
        return emails;
    }

    private static PropertyContextData buildPropertyContext(Id accountId, String mailingAddress, List<Opportunity> opps, Set<Id> opportunityIds) {
        PropertyContextData context = new PropertyContextData();
        context.address = mailingAddress;
        List<Homeowner_Property__c> properties;
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            properties = [
                SELECT Id, Name, Opportunity__c, Opportunity__r.Name, Opportunity__r.IsClosed, Community__r.Name, Lot__r.Name,
                       Lot__r.Street_Address__c, Homeowner_Account__r.Name, Homeowner_Account__r.BillingStreet,
                       Access_Type__c, Drainage_Risk__c, Utility_Review_Status__c, Customer_Readiness__c, Property_Notes__c
                FROM Homeowner_Property__c
                WHERE Homeowner_Account__c = :accountId
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ];
        } else {
            properties = [
                SELECT Id, Name, Opportunity__c, Opportunity__r.Name, Opportunity__r.IsClosed, Community__r.Name, Lot__r.Name,
                       Lot__r.Street_Address__c, Homeowner_Account__r.Name, Homeowner_Account__r.BillingStreet,
                       Access_Type__c, Drainage_Risk__c, Utility_Review_Status__c, Customer_Readiness__c, Property_Notes__c
                FROM Homeowner_Property__c
                WHERE Homeowner_Account__c = :accountId OR Opportunity__c IN :opportunityIds
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ];
        }

        if (!properties.isEmpty()) {
            Homeowner_Property__c propertyRow = selectBestProperty(properties);
            String homeownerLast = extractLastToken(propertyRow.Homeowner_Account__r != null ? propertyRow.Homeowner_Account__r.Name : null);
            String streetForLabel = firstNonBlank(new List<String>{
                propertyRow.Lot__r != null ? (String) propertyRow.Lot__r.get('Street_Address__c') : null,
                propertyRow.Homeowner_Account__r != null ? propertyRow.Homeowner_Account__r.BillingStreet : null,
                mailingAddress
            });
            context.propertyName = buildPropertyLabel(homeownerLast, streetForLabel, propertyRow.Name);
            context.propertyLabel = firstNonBlank(new List<String>{ streetForLabel, propertyRow.Name, mailingAddress });
            context.propertyUrl = '/' + propertyRow.Id;
            context.address = firstNonBlank(new List<String>{ streetForLabel, propertyRow.Name, mailingAddress });
            context.communityName = propertyRow.Community__r != null ? propertyRow.Community__r.Name : null;
            context.lotLabel = propertyRow.Lot__r != null ? propertyRow.Lot__r.Name : null;
            context.accessType = (String) propertyRow.get('Access_Type__c');
            context.drainageRisk = (String) propertyRow.get('Drainage_Risk__c');
            context.utilityReviewStatus = (String) propertyRow.get('Utility_Review_Status__c');
            context.customerReadiness = (String) propertyRow.get('Customer_Readiness__c');
            context.propertyNotes = (String) propertyRow.get('Property_Notes__c');
            if (propertyRow.Opportunity__c != null && propertyRow.Opportunity__r != null && propertyRow.Opportunity__r.IsClosed == false) {
                context.projectLabel = propertyRow.Opportunity__r != null ? propertyRow.Opportunity__r.Name : 'Related Opportunity';
                context.projectUrl = '/' + propertyRow.Opportunity__c;
            }
        }

        if (opps != null && !opps.isEmpty()) {
            Opportunity primaryOpp = opps[0];
            if (String.isBlank(context.projectLabel)) {
                context.projectLabel = primaryOpp.Name;
                context.projectUrl = '/' + primaryOpp.Id;
            }
            if (String.isBlank(context.communityName)) {
                context.communityName = primaryOpp.Community_Name__c;
            }
            context.packageName = firstNonBlank(new List<String>{
                normalizePackageName(primaryOpp.BMG_Package__c),
                deriveProjectPath(primaryOpp, picklistLabelByValue(Opportunity.Type))
            });
            context.layoutUrl = primaryOpp.Lot_Layout_Link__c;
            context.layoutAttached = primaryOpp.Lot_Layout_Attached__c;
        }

        if (properties.isEmpty() && (opps == null || opps.isEmpty())) {
            context.note = null;
        } else if (properties.isEmpty()) {
            context.note = null;
        } else if (String.isBlank(context.communityName) && String.isBlank(context.layoutUrl) && context.layoutAttached != true) {
            context.note = null;
        }
        return context;
    }

    private static Homeowner_Property__c selectBestProperty(List<Homeowner_Property__c> properties) {
        if (properties == null || properties.isEmpty()) {
            return null;
        }

        Homeowner_Property__c best = properties[0];
        Integer bestScore = scoreProperty(best);
        for (Integer i = 1; i < properties.size(); i++) {
            Homeowner_Property__c candidate = properties[i];
            Integer candidateScore = scoreProperty(candidate);
            if (candidateScore > bestScore) {
                best = candidate;
                bestScore = candidateScore;
            }
        }
        return best;
    }

    private static Integer scoreProperty(Homeowner_Property__c propertyRow) {
        if (propertyRow == null) {
            return -9999;
        }

        Integer score = 0;
        String lotStreet = propertyRow.Lot__r != null ? (String) propertyRow.Lot__r.get('Street_Address__c') : null;
        String homeownerStreet = propertyRow.Homeowner_Account__r != null ? propertyRow.Homeowner_Account__r.BillingStreet : null;

        if (!String.isBlank(lotStreet)) {
            score += 40;
        }
        if (!String.isBlank(homeownerStreet)) {
            score += 20;
        }
        if (looksLikeAddress(propertyRow.Name)) {
            score += 15;
        }
        if (!String.isBlank((String) propertyRow.get('Property_Notes__c'))) {
            score += 5;
        }
        if (!String.isBlank((String) propertyRow.get('Access_Type__c'))) {
            score += 5;
        }
        if (!String.isBlank((String) propertyRow.get('Utility_Review_Status__c'))) {
            score += 5;
        }
        if (propertyRow.Opportunity__r != null && propertyRow.Opportunity__r.IsClosed == false) {
            score += 20;
        }
        if (propertyRow.Opportunity__r != null && propertyRow.Opportunity__r.IsClosed == true) {
            score -= 20;
        }
        if (!String.isBlank(propertyRow.Name) && propertyRow.Name.startsWith('ODL Property -')) {
            score -= 25;
        }
        return score;
    }

    private static Boolean looksLikeAddress(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        return Pattern.matches('^[0-9].*', value.trim());
    }

    private static String escapeHtml(String value) {
        return String.isBlank(value) ? '' : value.escapeHtml4();
    }

    private static String normalizePackageName(String rawValue) {
        if (String.isBlank(rawValue)) {
            return rawValue;
        }

        String normalized = rawValue.trim().toLowerCase();
        if (normalized == 'good' || normalized == 'retreat') {
            return 'Retreat';
        }
        if (normalized == 'better' || normalized == 'entertainer') {
            return 'Entertainer';
        }
        if (normalized == 'best' || normalized == 'signature') {
            return 'Signature';
        }
        return rawValue;
    }

    private static String extractLastToken(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        List<String> tokens = value.trim().split('\\s+');
        return tokens.isEmpty() ? value.trim() : tokens[tokens.size() - 1];
    }

    private static String buildPropertyLabel(String lastName, String street, String fallbackLabel) {
        if (!String.isBlank(lastName) && !String.isBlank(street)) {
            return lastName + ' - ' + street;
        }
        if (!String.isBlank(street)) {
            return street;
        }
        return fallbackLabel;
    }

    private static String pickFirstSupportedPicklistValue(Schema.SObjectType objectType, String fieldApiName, List<String> desiredValues) {
        Schema.DescribeFieldResult describe = objectType.getDescribe().fields.getMap().get(fieldApiName).getDescribe();
        if (describe == null) {
            return null;
        }
        Set<String> allowed = new Set<String>();
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (entry.isActive()) {
                allowed.add(entry.getValue());
            }
        }
        for (String desired : desiredValues) {
            if (allowed.contains(desired)) {
                return desired;
            }
        }
        return null;
    }

    private static Map<Id, Date> nextTaskDateByWhatId(Set<Id> recordIds) {
        Map<Id, Date> results = new Map<Id, Date>();
        if (recordIds == null || recordIds.isEmpty()) {
            return results;
        }
        for (Task task : [
            SELECT WhatId, ActivityDate
            FROM Task
            WHERE WhatId IN :recordIds
            AND IsClosed = false
            ORDER BY ActivityDate ASC, LastModifiedDate DESC
        ]) {
            if (task.WhatId != null && !results.containsKey(task.WhatId)) {
                results.put(task.WhatId, task.ActivityDate);
            }
        }
        return results;
    }

    private static Map<String, String> picklistLabelByValue(Schema.SObjectField fieldRef) {
        Map<String, String> labels = new Map<String, String>();
        for (Schema.PicklistEntry entry : fieldRef.getDescribe().getPicklistValues()) {
            labels.put(entry.getValue(), entry.getLabel());
        }
        return labels;
    }

    private static List<Opportunity> filterOdlOpportunities(List<Opportunity> candidates, Map<String, String> typeLabels, Integer limitSize) {
        List<Opportunity> results = new List<Opportunity>();
        if (candidates == null) {
            return results;
        }
        for (Opportunity opp : candidates) {
            if (!String.isBlank(deriveProjectPath(opp, typeLabels))) {
                results.add(opp);
            }
            if (limitSize != null && results.size() >= limitSize) {
                break;
            }
        }
        return results;
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
            normalizedLeadSource.contains('voucher') ||
            normalizedName.contains('voucher') ||
            normalizedName.contains('upgrademybackyard') ||
            normalizedName.contains('backyard')
        ) {
            return 'Upgrade My Backyard';
        }
        return null;
    }

    private static Map<Id, ActivitySnapshot> latestActivityByOpportunity(Set<Id> opportunityIds) {
        Map<Id, ActivitySnapshot> snapshots = new Map<Id, ActivitySnapshot>();
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return snapshots;
        }

        if (Schema.SObjectType.EmailMessage.isAccessible()) {
            for (EmailMessage emailRow : [
                SELECT RelatedToId, Subject, MessageDate
                FROM EmailMessage
                WHERE RelatedToId IN :opportunityIds
                ORDER BY MessageDate DESC
                LIMIT 250
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
                SELECT WhatId, Subject, Status, TaskSubtype, ActivityDate, CreatedDate
                FROM Task
                WHERE WhatId IN :opportunityIds
                ORDER BY CreatedDate DESC
                LIMIT 250
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
                SELECT WhatId, Subject, Type, ActivityDateTime, CreatedDate
                FROM Event
                WHERE WhatId IN :opportunityIds
                ORDER BY CreatedDate DESC
                LIMIT 250
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

    private static Map<Id, RowData> designReviewByOpportunity(Set<Id> opportunityIds) {
        Map<Id, RowData> results = new Map<Id, RowData>();
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return results;
        }
        for (Design_Review__c review : [
            SELECT Id, Name, Status__c, Opportunity__c, Opportunity__r.Name, LastModifiedDate
            FROM Design_Review__c
            WHERE Opportunity__c IN :opportunityIds
            ORDER BY LastModifiedDate DESC
            LIMIT 25
        ]) {
            if (review.Opportunity__c == null || results.containsKey(review.Opportunity__c)) {
                continue;
            }
            RowData row = new RowData();
            row.id = review.Id;
            row.url = '/' + review.Id;
            row.label = review.Name;
            row.status = review.Status__c;
            row.relatedOpportunityLabel = review.Opportunity__r != null ? review.Opportunity__r.Name : 'Related Opportunity';
            row.relatedOpportunityUrl = review.Opportunity__c != null ? '/' + review.Opportunity__c : null;
            row.dateText = review.LastModifiedDate != null ? review.LastModifiedDate.format('M/d/yyyy') : null;
            row.actionLabel = 'Open';
            results.put(review.Opportunity__c, row);
        }
        return results;
    }

    private static Map<Id, List<RowData>> paymentMilestonesByOpportunity(Set<Id> opportunityIds) {
        Map<Id, List<RowData>> results = new Map<Id, List<RowData>>();
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return results;
        }
        for (Payment_Milestone__c milestone : [
            SELECT Id, Name, Opportunity__c, Opportunity__r.Name, Type__c, Status__c, Amount__c, Due_Date__c, Paid_Date__c
            FROM Payment_Milestone__c
            WHERE Opportunity__c IN :opportunityIds
            ORDER BY Due_Date__c ASC NULLS LAST, CreatedDate DESC
            LIMIT 25
        ]) {
            if (milestone.Opportunity__c == null) {
                continue;
            }
            if (!results.containsKey(milestone.Opportunity__c)) {
                results.put(milestone.Opportunity__c, new List<RowData>());
            }
            RowData row = new RowData();
            row.id = milestone.Id;
            row.url = '/' + milestone.Id;
            row.label = milestone.Type__c;
            row.status = milestone.Status__c;
            row.notesPreview = milestone.Amount__c != null ? '$' + String.valueOf(milestone.Amount__c.setScale(0)) : null;
            row.dateText = milestone.Due_Date__c != null ? String.valueOf(milestone.Due_Date__c) : null;
            row.secondaryText = milestone.Paid_Date__c != null ? 'Paid ' + String.valueOf(milestone.Paid_Date__c) : null;
            row.relatedOpportunityLabel = milestone.Opportunity__r != null ? milestone.Opportunity__r.Name : 'Related Opportunity';
            row.relatedOpportunityUrl = milestone.Opportunity__c != null ? '/' + milestone.Opportunity__c : null;
            row.actionLabel = 'Open';
            results.get(milestone.Opportunity__c).add(row);
        }
        return results;
    }

    private static List<RowData> relatedFiles(Id accountId, Set<Id> opportunityIds) {
        List<RowData> results = new List<RowData>();
        Set<Id> linkedIds = new Set<Id>{ accountId };
        if (opportunityIds != null) {
            linkedIds.addAll(opportunityIds);
        }
        for (ContentDocumentLink linkRow : [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.FileType, ContentDocument.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :linkedIds
            AND ContentDocument.FileType != 'SNOTE'
            ORDER BY SystemModstamp DESC
            LIMIT 10
        ]) {
            RowData row = new RowData();
            row.id = linkRow.ContentDocumentId;
            row.url = '/' + linkRow.ContentDocumentId;
            row.label = linkRow.ContentDocument != null ? linkRow.ContentDocument.Title : 'File';
            row.subtext = linkRow.ContentDocument != null ? linkRow.ContentDocument.FileType : null;
            row.dateText = linkRow.ContentDocument != null && linkRow.ContentDocument.LastModifiedDate != null
                ? linkRow.ContentDocument.LastModifiedDate.format('M/d/yyyy')
                : null;
            row.relatedLabel = linkRow.LinkedEntityId == accountId ? 'Homeowner Account' : 'Opportunity';
            row.relatedUrl = linkRow.LinkedEntityId != null ? '/' + linkRow.LinkedEntityId : null;
            row.actionLabel = 'Open';
            results.add(row);
        }
        return results;
    }

    private static List<RowData> relatedNotes(Id accountId, Set<Id> opportunityIds) {
        List<RowData> results = new List<RowData>();
        Set<Id> linkedIds = new Set<Id>{ accountId };
        if (opportunityIds != null) {
            linkedIds.addAll(opportunityIds);
        }
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.FileType, ContentDocument.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :linkedIds
            AND ContentDocument.FileType = 'SNOTE'
            ORDER BY SystemModstamp DESC
            LIMIT 10
        ];
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink linkRow : links) {
            docIds.add(linkRow.ContentDocumentId);
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
            RowData row = new RowData();
            row.id = linkRow.ContentDocumentId;
            row.url = '/' + linkRow.ContentDocumentId;
            row.label = linkRow.ContentDocument != null ? linkRow.ContentDocument.Title : 'Note';
            row.subtext = 'Salesforce Note';
            row.dateText = linkRow.ContentDocument != null && linkRow.ContentDocument.LastModifiedDate != null
                ? linkRow.ContentDocument.LastModifiedDate.format('M/d/yyyy')
                : null;
            row.relatedLabel = linkRow.LinkedEntityId == accountId ? 'Homeowner Account' : 'Opportunity';
            row.relatedUrl = linkRow.LinkedEntityId != null ? '/' + linkRow.LinkedEntityId : null;
            row.notesPreview = notePreviewByDocId.get(linkRow.ContentDocumentId);
            row.actionLabel = 'Open';
            results.add(row);
        }
        return results;
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

    private static DatedRow wrapDatedRow(RowData row, Datetime occurredAt) {
        DatedRow wrapped = new DatedRow();
        wrapped.row = row;
        wrapped.occurredAt = occurredAt;
        return wrapped;
    }

    private static Map<Id, ServiceAppointment> firstAppointmentByWorkOrder(Set<Id> workOrderIds) {
        Map<Id, ServiceAppointment> results = new Map<Id, ServiceAppointment>();
        if (workOrderIds == null || workOrderIds.isEmpty()) {
            return results;
        }
        for (ServiceAppointment appt : [
            SELECT Id, ParentRecordId, AppointmentNumber, SchedStartTime, Status
            FROM ServiceAppointment
            WHERE ParentRecordId IN :workOrderIds
            ORDER BY SchedStartTime ASC NULLS LAST, CreatedDate DESC
        ]) {
            if (appt.ParentRecordId != null && !results.containsKey(appt.ParentRecordId)) {
                results.put(appt.ParentRecordId, appt);
            }
        }
        return results;
    }

    private static List<RowData> resolveHomeownerWorkOrders(Id accountId, Set<Id> householdContactIds, Set<Id> opportunityIds) {
        List<RowData> results = new List<RowData>();
        Set<Id> seenIds = new Set<Id>();

        if (householdContactIds != null && !householdContactIds.isEmpty()) {
            for (WorkOrder wo : [
                SELECT Id, WorkOrderNumber, Subject, Status, Work_Order_Type__c, CreatedDate, LastModifiedDate,
                       Owner.Name, AccountId, ContactId, Community__c, Community__r.Name, Lot_Number__c
                FROM WorkOrder
                WHERE ContactId IN :householdContactIds
                AND IsClosed = false
                ORDER BY LastModifiedDate DESC
                LIMIT 25
            ]) {
                addWorkOrderRow(results, seenIds, wo, 'ContactId');
            }
        }

        if (hasWorkOrderOpportunityField() && opportunityIds != null && !opportunityIds.isEmpty()) {
            String opportunityQuery =
                'SELECT Id, WorkOrderNumber, Subject, Status, Work_Order_Type__c, CreatedDate, LastModifiedDate, ' +
                'Owner.Name, AccountId, ContactId, Community__c, Community__r.Name, Lot_Number__c, Opportunity__c ' +
                'FROM WorkOrder ' +
                'WHERE Opportunity__c IN :opportunityIds ' +
                'AND IsClosed = false ' +
                'ORDER BY LastModifiedDate DESC ' +
                'LIMIT 25';
            for (SObject record : Database.query(opportunityQuery)) {
                WorkOrder wo = (WorkOrder) record;
                addWorkOrderRow(results, seenIds, wo, 'Opportunity__c');
            }
        }

        for (WorkOrder wo : [
            SELECT Id, WorkOrderNumber, Subject, Status, Work_Order_Type__c, CreatedDate, LastModifiedDate,
                   Owner.Name, AccountId, ContactId, Community__c, Community__r.Name, Lot_Number__c
            FROM WorkOrder
            WHERE AccountId = :accountId
            AND IsClosed = false
            ORDER BY LastModifiedDate DESC
            LIMIT 25
        ]) {
            addWorkOrderRow(results, seenIds, wo, 'AccountId');
        }

        hydrateWorkOrderOpportunityLabels(results);
        return results;
    }

    private static void addWorkOrderRow(List<RowData> rows, Set<Id> seenIds, WorkOrder wo, String relationshipSource) {
        if (wo == null || seenIds.contains(wo.Id)) {
            return;
        }
        seenIds.add(wo.Id);

        RowData row = new RowData();
        row.id = wo.Id;
        row.url = '/' + wo.Id;
        row.label = String.isBlank(wo.Subject) ? wo.WorkOrderNumber : wo.Subject;
        row.status = wo.Status;
        row.ownerName = wo.Owner != null ? wo.Owner.Name : null;
        row.subtext = wo.Work_Order_Type__c;
        row.dateText = String.valueOf(wo.CreatedDate.date());
        row.secondaryText = 'Open';
        row.notesPreview = wo.WorkOrderNumber;
        row.relationshipSource = relationshipSource;
        row.communityName = wo.Community__r != null ? wo.Community__r.Name : null;
        row.lotLabel = wo.Lot_Number__c;

        if (hasWorkOrderOpportunityField() && wo.getPopulatedFieldsAsMap().containsKey('Opportunity__c')) {
            Object opportunityIdValue = wo.get('Opportunity__c');
            if (opportunityIdValue != null) {
                row.relatedOpportunityUrl = '/' + String.valueOf(opportunityIdValue);
                row.relatedOpportunityLabel = 'Related Opportunity';
            }
        }

        rows.add(row);
    }

    private static Boolean hasWorkOrderOpportunityField() {
        return WorkOrder.SObjectType.getDescribe().fields.getMap().containsKey('Opportunity__c');
    }

    private static void hydrateWorkOrderOpportunityLabels(List<RowData> rows) {
        Set<Id> opportunityIds = new Set<Id>();
        for (RowData row : rows) {
            if (!String.isBlank(row.relatedOpportunityUrl) && row.relatedOpportunityUrl.startsWith('/')) {
                opportunityIds.add((Id) row.relatedOpportunityUrl.substring(1));
            }
        }
        if (opportunityIds.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> oppById = new Map<Id, Opportunity>([
            SELECT Id, Name
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]);
        for (RowData row : rows) {
            if (!String.isBlank(row.relatedOpportunityUrl) && row.relatedOpportunityUrl.startsWith('/')) {
                Id oppId = (Id) row.relatedOpportunityUrl.substring(1);
                Opportunity opp = oppById.get(oppId);
                row.relatedOpportunityLabel = opp != null ? opp.Name : 'Related Opportunity';
            }
        }
    }
}