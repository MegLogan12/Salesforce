public with sharing class ODLEmailViewController {
    private static final Integer DEFAULT_LIMIT = 25;
    private static final Integer MAX_LIMIT = 100;

    public class EmailSummary {
        @AuraEnabled public Boolean sourceAvailable;
        @AuraEnabled public String unavailableReason;
        @AuraEnabled public Integer totalEmails;
        @AuraEnabled public Datetime lastEmailDate;
        @AuraEnabled public String lastEmailDirection;
        @AuraEnabled public String lastEmailOwner;
        @AuraEnabled public String unreadOrNeedsReplyLabel;
    }

    public class EmailRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String sourceType;
        @AuraEnabled public String direction;
        @AuraEnabled public String subject;
        @AuraEnabled public String fromAddress;
        @AuraEnabled public String toAddress;
        @AuraEnabled public String ccAddress;
        @AuraEnabled public String relatedRecordLabel;
        @AuraEnabled public Datetime sentDate;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean hasAttachment;
        @AuraEnabled public Boolean openable;
        @AuraEnabled public String previewText;
        @AuraEnabled public Id parentId;
        @AuraEnabled public Id relatedToId;
    }

    public class EmailDetail {
        @AuraEnabled public Id id;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String sourceType;
        @AuraEnabled public String subject;
        @AuraEnabled public String fromAddress;
        @AuraEnabled public String toAddress;
        @AuraEnabled public String ccAddress;
        @AuraEnabled public Datetime sentDate;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean incoming;
        @AuraEnabled public Boolean hasAttachment;
        @AuraEnabled public String plainTextPreview;
        @AuraEnabled public String relatedRecordLabel;
        @AuraEnabled public Id parentId;
        @AuraEnabled public Id relatedToId;
    }

    public class FollowUpResult {
        @AuraEnabled public Id taskId;
        @AuraEnabled public String subject;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Id ownerId;
    }

    private class QueryTargets {
        Set<Id> emailIds = new Set<Id>();
        Set<Id> taskWhatIds = new Set<Id>();
        Set<Id> taskWhoIds = new Set<Id>();
    }

    private class TimelineItem implements Comparable {
        Datetime sortValue;
        EmailRow row;

        TimelineItem(EmailRow rowData, Datetime sortDate) {
            row = rowData;
            sortValue = sortDate;
        }

        public Integer compareTo(Object otherValue) {
            TimelineItem otherItem = (TimelineItem) otherValue;
            Long left = sortValue == null ? 0 : sortValue.getTime();
            Long right = otherItem.sortValue == null ? 0 : otherItem.sortValue.getTime();
            if (left == right) {
                return 0;
            }
            return left > right ? -1 : 1;
        }
    }

    @AuraEnabled(cacheable=true)
    public static EmailSummary getEmailSummary(Id recordId) {
        validateRecordId(recordId);
        EmailSummary summary = new EmailSummary();
        if (!Schema.SObjectType.EmailMessage.isAccessible() && !Schema.SObjectType.Task.isAccessible()) {
            summary.sourceAvailable = false;
            summary.unavailableReason = 'Email history is unavailable because Enhanced Email, Activity Timeline, or approved email sync is not configured for this record type.';
            summary.totalEmails = 0;
            summary.unreadOrNeedsReplyLabel = 'Unavailable';
            return summary;
        }

        List<EmailRow> rows = buildTimeline(recordId, MAX_LIMIT);
        summary.sourceAvailable = true;
        summary.totalEmails = rows.size();
        summary.unreadOrNeedsReplyLabel = 'Unavailable';
        Integer inboundCount = 0;
        for (EmailRow row : rows) {
            if (row.direction == 'Inbound') {
                inboundCount++;
            }
        }
        if (inboundCount > 0) {
            summary.unreadOrNeedsReplyLabel = String.valueOf(inboundCount);
        }
        if (!rows.isEmpty()) {
            EmailRow firstRow = rows[0];
            summary.lastEmailDate = firstRow.sentDate;
            summary.lastEmailDirection = firstRow.direction;
            summary.lastEmailOwner = firstRow.ownerName;
        }
        return summary;
    }

    @AuraEnabled(cacheable=true)
    public static List<EmailRow> getRelatedEmails(Id recordId, Integer limitSize, Integer offsetSize) {
        validateRecordId(recordId);
        Integer safeLimit = limitSize == null || limitSize <= 0 ? DEFAULT_LIMIT : Math.min(limitSize, MAX_LIMIT);
        Integer safeOffset = offsetSize == null || offsetSize < 0 ? 0 : offsetSize;
        List<EmailRow> rows = buildTimeline(recordId, MAX_LIMIT);
        if (safeOffset >= rows.size()) {
            return new List<EmailRow>();
        }
        Integer endIndex = Math.min(rows.size(), safeOffset + safeLimit);
        List<EmailRow> slicedRows = new List<EmailRow>();
        for (Integer index = safeOffset; index < endIndex; index++) {
            slicedRows.add(rows[index]);
        }
        return slicedRows;
    }

    @AuraEnabled(cacheable=true)
    public static EmailDetail getEmailDetail(Id emailMessageId) {
        if (emailMessageId == null) {
            throw new AuraHandledException('Email Id is required.');
        }
        String typeName = String.valueOf(emailMessageId.getSObjectType());
        if (typeName == 'Task') {
            return getTaskDetail(emailMessageId);
        }
        if (typeName != 'EmailMessage') {
            throw new AuraHandledException('Only EmailMessage and Task email records are supported.');
        }
        if (!Schema.SObjectType.EmailMessage.isAccessible()) {
            throw new AuraHandledException('EmailMessage access is not available for this user.');
        }

        List<EmailMessage> rows = [
            SELECT Id, Subject, FromAddress, ToAddress, CcAddress, MessageDate, Status,
                   Incoming, HasAttachment, ParentId, RelatedToId, CreatedBy.Name, TextBody
            FROM EmailMessage
            WHERE Id = :emailMessageId
            LIMIT 1
        ];
        List<EmailMessage> safeRows = (List<EmailMessage>) Security.stripInaccessible(AccessType.READABLE, rows).getRecords();
        if (safeRows.isEmpty()) {
            throw new AuraHandledException('Email record could not be loaded.');
        }
        EmailMessage row = safeRows[0];
        Id parentId = safeId(row, 'ParentId');
        Id relatedToId = safeId(row, 'RelatedToId');
        Map<Id, String> labels = buildRecordLabelMap(new Set<Id>{parentId, relatedToId});
        EmailDetail detail = new EmailDetail();
        detail.id = row.Id;
        detail.objectApiName = 'EmailMessage';
        detail.sourceType = 'EmailMessage';
        detail.subject = safeString(row, 'Subject');
        detail.fromAddress = safeString(row, 'FromAddress');
        detail.toAddress = safeString(row, 'ToAddress');
        detail.ccAddress = safeString(row, 'CcAddress');
        detail.sentDate = safeDatetime(row, 'MessageDate');
        detail.ownerName = safeRelationshipName(row, 'CreatedBy');
        detail.status = safeString(row, 'Status');
        detail.incoming = safeBoolean(row, 'Incoming');
        detail.hasAttachment = safeBoolean(row, 'HasAttachment');
        detail.plainTextPreview = trimPreview(safeString(row, 'TextBody'));
        detail.relatedRecordLabel = firstNonBlank(new List<String>{
            labels.get(relatedToId),
            labels.get(parentId)
        });
        detail.parentId = parentId;
        detail.relatedToId = relatedToId;
        return detail;
    }

    @AuraEnabled
    public static FollowUpResult createFollowUpTask(Id recordId, Id emailMessageId, String subject, Date dueDate, Id ownerId) {
        validateRecordId(recordId);
        if (!Schema.SObjectType.Task.isCreateable()) {
            throw new AuraHandledException('Task creation is not available for this user.');
        }

        Schema.DescribeFieldResult subjectField = Task.Subject.getDescribe();
        Schema.DescribeFieldResult activityDateField = Task.ActivityDate.getDescribe();
        Schema.DescribeFieldResult ownerField = Task.OwnerId.getDescribe();
        Schema.DescribeFieldResult whatField = Task.WhatId.getDescribe();
        Schema.DescribeFieldResult whoField = Task.WhoId.getDescribe();
        Schema.DescribeFieldResult statusField = Task.Status.getDescribe();
        Schema.DescribeFieldResult descriptionField = Task.Description.getDescribe();

        Task followUp = new Task();
        Date safeDueDate = dueDate == null ? Date.today().addDays(1) : dueDate;
        Id safeOwnerId = ownerId == null ? UserInfo.getUserId() : ownerId;
        String safeSubject = String.isBlank(subject) ? buildDefaultFollowUpSubject(recordId, emailMessageId) : subject;

        if (subjectField.isCreateable()) {
            followUp.Subject = safeSubject;
        }
        if (activityDateField.isCreateable()) {
            followUp.ActivityDate = safeDueDate;
        }
        if (ownerField.isCreateable()) {
            followUp.OwnerId = safeOwnerId;
        }
        if (statusField.isCreateable()) {
            followUp.Status = 'Not Started';
        }
        if (descriptionField.isCreateable()) {
            followUp.Description = buildFollowUpDescription(emailMessageId, recordId);
        }

        String typeName = String.valueOf(recordId.getSObjectType());
        if ((typeName == 'Lead' || typeName == 'Contact') && whoField.isCreateable()) {
            followUp.WhoId = recordId;
        } else if (whatField.isCreateable()) {
            followUp.WhatId = recordId;
        }

        insert followUp;

        FollowUpResult result = new FollowUpResult();
        result.taskId = followUp.Id;
        result.subject = followUp.Subject;
        result.dueDate = followUp.ActivityDate;
        result.ownerId = followUp.OwnerId;
        return result;
    }

    private static EmailDetail getTaskDetail(Id taskId) {
        if (!Schema.SObjectType.Task.isAccessible()) {
            throw new AuraHandledException('Task access is not available for this user.');
        }
        List<Task> rows = [
            SELECT Id, Subject, Status, ActivityDate, WhatId, WhoId, TaskSubtype, Owner.Name, Description
            FROM Task
            WHERE Id = :taskId
            LIMIT 1
        ];
        List<Task> safeRows = (List<Task>) Security.stripInaccessible(AccessType.READABLE, rows).getRecords();
        if (safeRows.isEmpty()) {
            throw new AuraHandledException('Task email record could not be loaded.');
        }
        Task row = safeRows[0];
        Id whatId = safeId(row, 'WhatId');
        Id whoId = safeId(row, 'WhoId');
        Map<Id, String> labels = buildRecordLabelMap(new Set<Id>{whatId, whoId});
        EmailDetail detail = new EmailDetail();
        detail.id = row.Id;
        detail.objectApiName = 'Task';
        detail.sourceType = 'Task';
        detail.subject = safeString(row, 'Subject');
        Date activityDate = safeDate(row, 'ActivityDate');
        detail.sentDate = activityDate == null ? null : Datetime.newInstance(activityDate, Time.newInstance(12, 0, 0, 0));
        detail.ownerName = safeRelationshipName(row, 'Owner');
        detail.status = safeString(row, 'Status');
        detail.incoming = false;
        detail.hasAttachment = false;
        detail.plainTextPreview = trimPreview(safeString(row, 'Description'));
        detail.relatedRecordLabel = firstNonBlank(new List<String>{labels.get(whatId), labels.get(whoId)});
        detail.relatedToId = whatId;
        return detail;
    }

    private static List<EmailRow> buildTimeline(Id recordId, Integer maxRows) {
        QueryTargets targets = buildTargets(recordId);
        Set<Id> labelIds = new Set<Id>();
        List<TimelineItem> timeline = new List<TimelineItem>();

        if (Schema.SObjectType.EmailMessage.isAccessible() && !targets.emailIds.isEmpty()) {
            List<EmailMessage> emails = [
                SELECT Id, Subject, FromAddress, ToAddress, CcAddress, MessageDate, Status,
                       Incoming, HasAttachment, ParentId, RelatedToId, CreatedBy.Name, TextBody
                FROM EmailMessage
                WHERE ParentId IN :targets.emailIds OR RelatedToId IN :targets.emailIds
                ORDER BY MessageDate DESC
                LIMIT :maxRows
            ];
            emails = (List<EmailMessage>) Security.stripInaccessible(AccessType.READABLE, emails).getRecords();
            for (EmailMessage email : emails) {
                labelIds.add(safeId(email, 'ParentId'));
                labelIds.add(safeId(email, 'RelatedToId'));
            }
            Map<Id, String> emailLabels = buildRecordLabelMap(labelIds);
            for (EmailMessage email : emails) {
                Id parentId = safeId(email, 'ParentId');
                Id relatedToId = safeId(email, 'RelatedToId');
                Datetime messageDate = safeDatetime(email, 'MessageDate');
                EmailRow row = new EmailRow();
                row.id = email.Id;
                row.objectApiName = 'EmailMessage';
                row.sourceType = 'EmailMessage';
                row.direction = directionLabel(safeBoolean(email, 'Incoming'), safeString(email, 'FromAddress'));
                row.subject = safeString(email, 'Subject');
                row.fromAddress = safeString(email, 'FromAddress');
                row.toAddress = safeString(email, 'ToAddress');
                row.ccAddress = safeString(email, 'CcAddress');
                row.relatedRecordLabel = firstNonBlank(new List<String>{
                    emailLabels.get(relatedToId),
                    emailLabels.get(parentId)
                });
                row.sentDate = messageDate;
                row.ownerName = safeRelationshipName(email, 'CreatedBy');
                row.status = safeString(email, 'Status');
                row.hasAttachment = safeBoolean(email, 'HasAttachment');
                row.openable = true;
                row.previewText = trimPreview(safeString(email, 'TextBody'));
                row.parentId = parentId;
                row.relatedToId = relatedToId;
                timeline.add(new TimelineItem(row, messageDate));
            }
        }

        if (Schema.SObjectType.Task.isAccessible() && (!targets.taskWhatIds.isEmpty() || !targets.taskWhoIds.isEmpty())) {
            Set<Id> taskWhatIds = targets.taskWhatIds;
            Set<Id> taskWhoIds = targets.taskWhoIds;
            String queryText =
                'SELECT Id, Subject, Status, ActivityDate, WhatId, WhoId, TaskSubtype, CallDisposition, Owner.Name, Description ' +
                'FROM Task WHERE (TaskSubtype = \'Email\' OR Subject LIKE \'Email:%\')';
            if (!taskWhatIds.isEmpty() && !taskWhoIds.isEmpty()) {
                queryText += ' AND (WhatId IN :taskWhatIds OR WhoId IN :taskWhoIds)';
            } else if (!taskWhatIds.isEmpty()) {
                queryText += ' AND WhatId IN :taskWhatIds';
            } else {
                queryText += ' AND WhoId IN :taskWhoIds';
            }
            queryText += ' ORDER BY ActivityDate DESC, CreatedDate DESC LIMIT ' + String.valueOf(maxRows);
            List<Task> tasks = Database.query(queryText);
            tasks = (List<Task>) Security.stripInaccessible(AccessType.READABLE, tasks).getRecords();
            Set<Id> taskLabelIds = new Set<Id>();
            for (Task taskRow : tasks) {
                taskLabelIds.add(safeId(taskRow, 'WhatId'));
                taskLabelIds.add(safeId(taskRow, 'WhoId'));
            }
            Map<Id, String> taskLabels = buildRecordLabelMap(taskLabelIds);
            for (Task taskRow : tasks) {
                Id whatId = safeId(taskRow, 'WhatId');
                Id whoId = safeId(taskRow, 'WhoId');
                Date activityDate = safeDate(taskRow, 'ActivityDate');
                EmailRow row = new EmailRow();
                row.id = taskRow.Id;
                row.objectApiName = 'Task';
                row.sourceType = 'Task';
                row.direction = 'Logged Email';
                row.subject = safeString(taskRow, 'Subject');
                row.fromAddress = null;
                row.toAddress = null;
                row.ccAddress = null;
                row.relatedRecordLabel = firstNonBlank(new List<String>{
                    taskLabels.get(whatId),
                    taskLabels.get(whoId)
                });
                row.sentDate = activityDate == null ? null : Datetime.newInstance(activityDate, Time.newInstance(12, 0, 0, 0));
                row.ownerName = safeRelationshipName(taskRow, 'Owner');
                row.status = safeString(taskRow, 'Status');
                row.hasAttachment = false;
                row.openable = true;
                row.previewText = trimPreview(safeString(taskRow, 'Description'));
                row.relatedToId = whatId;
                timeline.add(new TimelineItem(row, row.sentDate));
            }
        }

        timeline.sort();
        List<EmailRow> rows = new List<EmailRow>();
        for (TimelineItem item : timeline) {
            rows.add(item.row);
        }
        return rows;
    }

    private static QueryTargets buildTargets(Id recordId) {
        QueryTargets targets = new QueryTargets();
        String typeName = String.valueOf(recordId.getSObjectType());
        targets.emailIds.add(recordId);

        if (typeName == 'Lead') {
            targets.taskWhoIds.add(recordId);
            return targets;
        }
        if (typeName == 'Contact') {
            targets.taskWhoIds.add(recordId);
            targets.taskWhatIds.add(recordId);
            Contact contactRow = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (contactRow.AccountId != null) {
                targets.emailIds.add(contactRow.AccountId);
                targets.taskWhatIds.add(contactRow.AccountId);
            }
            return targets;
        }
        if (typeName == 'Account') {
            targets.taskWhatIds.add(recordId);
            Account accountRow = [
                SELECT Id, ParentId, PersonContactId, ODL_Secondary_Contact__c
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (accountRow.PersonContactId != null) {
                targets.emailIds.add(accountRow.PersonContactId);
                targets.taskWhoIds.add(accountRow.PersonContactId);
            }
            if (accountRow.ODL_Secondary_Contact__c != null) {
                targets.emailIds.add(accountRow.ODL_Secondary_Contact__c);
                targets.taskWhoIds.add(accountRow.ODL_Secondary_Contact__c);
            }
            Set<Id> scopedAccountIds = new Set<Id>{recordId};
            for (Account childAccount : [SELECT Id FROM Account WHERE ParentId = :recordId LIMIT 50]) {
                scopedAccountIds.add(childAccount.Id);
                targets.emailIds.add(childAccount.Id);
                targets.taskWhatIds.add(childAccount.Id);
            }
            for (Contact childContact : [SELECT Id FROM Contact WHERE AccountId IN :scopedAccountIds LIMIT 100]) {
                targets.emailIds.add(childContact.Id);
                targets.taskWhoIds.add(childContact.Id);
            }
            for (Opportunity opp : [SELECT Id FROM Opportunity WHERE AccountId IN :scopedAccountIds LIMIT 100]) {
                targets.emailIds.add(opp.Id);
                targets.taskWhatIds.add(opp.Id);
            }
            for (Case caseRow : [SELECT Id, ContactId FROM Case WHERE AccountId IN :scopedAccountIds LIMIT 100]) {
                targets.emailIds.add(caseRow.Id);
                targets.taskWhatIds.add(caseRow.Id);
                if (caseRow.ContactId != null) {
                    targets.emailIds.add(caseRow.ContactId);
                    targets.taskWhoIds.add(caseRow.ContactId);
                }
            }
            for (WorkOrder workOrderRow : [SELECT Id FROM WorkOrder WHERE AccountId IN :scopedAccountIds LIMIT 100]) {
                targets.emailIds.add(workOrderRow.Id);
                targets.taskWhatIds.add(workOrderRow.Id);
            }
            Set<Id> communityIds = new Set<Id>();
            Set<Id> lotIds = new Set<Id>();
            for (Community__c communityRow : [SELECT Id FROM Community__c WHERE Builder_Account__c IN :scopedAccountIds LIMIT 100]) {
                communityIds.add(communityRow.Id);
                targets.emailIds.add(communityRow.Id);
                targets.taskWhatIds.add(communityRow.Id);
            }
            if (!communityIds.isEmpty()) {
                for (Lot__c lotRow : [SELECT Id FROM Lot__c WHERE Community__c IN :communityIds LIMIT 100]) {
                    lotIds.add(lotRow.Id);
                    targets.emailIds.add(lotRow.Id);
                    targets.taskWhatIds.add(lotRow.Id);
                }
                for (WorkOrder communityWorkOrder : [SELECT Id FROM WorkOrder WHERE Lot__c IN :lotIds LIMIT 100]) {
                    targets.emailIds.add(communityWorkOrder.Id);
                    targets.taskWhatIds.add(communityWorkOrder.Id);
                }
                for (Opportunity communityOpportunity : [SELECT Id FROM Opportunity WHERE Community__c IN :communityIds LIMIT 100]) {
                    targets.emailIds.add(communityOpportunity.Id);
                    targets.taskWhatIds.add(communityOpportunity.Id);
                }
            }
            for (Quote quoteRow : [
                SELECT Id
                FROM Quote
                WHERE Opportunity.AccountId IN :scopedAccountIds
                LIMIT 100
            ]) {
                targets.emailIds.add(quoteRow.Id);
                targets.taskWhatIds.add(quoteRow.Id);
            }
            return targets;
        }
        if (typeName == 'Opportunity') {
            targets.taskWhatIds.add(recordId);
            Opportunity opp = [
                SELECT Id, AccountId, Account.ODL_Secondary_Contact__c
                FROM Opportunity
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (opp.AccountId != null) {
                targets.emailIds.add(opp.AccountId);
                targets.taskWhatIds.add(opp.AccountId);
            }
            if (opp.Account != null && opp.Account.ODL_Secondary_Contact__c != null) {
                targets.emailIds.add(opp.Account.ODL_Secondary_Contact__c);
                targets.taskWhoIds.add(opp.Account.ODL_Secondary_Contact__c);
            }
            for (OpportunityContactRole role : [
                SELECT ContactId
                FROM OpportunityContactRole
                WHERE OpportunityId = :recordId
                LIMIT 50
            ]) {
                if (role.ContactId != null) {
                    targets.emailIds.add(role.ContactId);
                    targets.taskWhoIds.add(role.ContactId);
                }
            }
            return targets;
        }
        if (typeName == 'Case') {
            targets.taskWhatIds.add(recordId);
            Case caseRow = [
                SELECT Id, AccountId, ContactId
                FROM Case
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (caseRow.AccountId != null) {
                targets.emailIds.add(caseRow.AccountId);
                targets.taskWhatIds.add(caseRow.AccountId);
            }
            if (caseRow.ContactId != null) {
                targets.emailIds.add(caseRow.ContactId);
                targets.taskWhoIds.add(caseRow.ContactId);
            }
            return targets;
        }
        if (typeName == 'WorkOrder') {
            targets.taskWhatIds.add(recordId);
            WorkOrder workOrderRow = [
                SELECT Id, AccountId, ContactId, Lot__c
                FROM WorkOrder
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (workOrderRow.AccountId != null) {
                targets.emailIds.add(workOrderRow.AccountId);
                targets.taskWhatIds.add(workOrderRow.AccountId);
            }
            if (workOrderRow.ContactId != null) {
                targets.emailIds.add(workOrderRow.ContactId);
                targets.taskWhoIds.add(workOrderRow.ContactId);
            }
            if (workOrderRow.Lot__c != null) {
                targets.emailIds.add(workOrderRow.Lot__c);
                targets.taskWhatIds.add(workOrderRow.Lot__c);
                mergeTargets(targets, buildTargets(workOrderRow.Lot__c));
            }
            return targets;
        }
        if (typeName == 'Quote') {
            targets.taskWhatIds.add(recordId);
            Quote quoteRow = [
                SELECT Id, OpportunityId, Opportunity.AccountId
                FROM Quote
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (quoteRow.OpportunityId != null) {
                targets.emailIds.add(quoteRow.OpportunityId);
                targets.taskWhatIds.add(quoteRow.OpportunityId);
            }
            if (quoteRow.Opportunity != null && quoteRow.Opportunity.AccountId != null) {
                targets.emailIds.add(quoteRow.Opportunity.AccountId);
                targets.taskWhatIds.add(quoteRow.Opportunity.AccountId);
            }
            return targets;
        }
        if (typeName == 'Campaign') {
            targets.taskWhatIds.add(recordId);
            for (CampaignMember member : [
                SELECT LeadId, ContactId
                FROM CampaignMember
                WHERE CampaignId = :recordId
                LIMIT 100
            ]) {
                if (member.LeadId != null) {
                    targets.emailIds.add(member.LeadId);
                    targets.taskWhoIds.add(member.LeadId);
                }
                if (member.ContactId != null) {
                    targets.emailIds.add(member.ContactId);
                    targets.taskWhoIds.add(member.ContactId);
                }
            }
            return targets;
        }
        if (typeName == 'Community__c') {
            targets.taskWhatIds.add(recordId);
            Community__c communityRow = [
                SELECT Id, Builder_Account__c
                FROM Community__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            Set<Id> builderAccountIds = new Set<Id>();
            if (communityRow.Builder_Account__c != null) {
                builderAccountIds.add(communityRow.Builder_Account__c);
                targets.emailIds.add(communityRow.Builder_Account__c);
                targets.taskWhatIds.add(communityRow.Builder_Account__c);
                for (Account builderAccount : [SELECT Id, ParentId FROM Account WHERE Id = :communityRow.Builder_Account__c LIMIT 1]) {
                    if (builderAccount.ParentId != null) {
                        builderAccountIds.add(builderAccount.ParentId);
                        targets.emailIds.add(builderAccount.ParentId);
                        targets.taskWhatIds.add(builderAccount.ParentId);
                    }
                }
            }
            if (!builderAccountIds.isEmpty()) {
                for (Contact builderContact : [SELECT Id FROM Contact WHERE AccountId IN :builderAccountIds LIMIT 100]) {
                    targets.emailIds.add(builderContact.Id);
                    targets.taskWhoIds.add(builderContact.Id);
                }
                for (Case builderCase : [SELECT Id, ContactId FROM Case WHERE AccountId IN :builderAccountIds LIMIT 100]) {
                    targets.emailIds.add(builderCase.Id);
                    targets.taskWhatIds.add(builderCase.Id);
                    if (builderCase.ContactId != null) {
                        targets.emailIds.add(builderCase.ContactId);
                        targets.taskWhoIds.add(builderCase.ContactId);
                    }
                }
            }
            Set<Id> lotIds = new Set<Id>();
            for (Lot__c lotRow : [SELECT Id FROM Lot__c WHERE Community__c = :recordId LIMIT 100]) {
                lotIds.add(lotRow.Id);
                targets.emailIds.add(lotRow.Id);
                targets.taskWhatIds.add(lotRow.Id);
            }
            if (!lotIds.isEmpty()) {
                for (WorkOrder workOrderRow : [SELECT Id FROM WorkOrder WHERE Lot__c IN :lotIds LIMIT 100]) {
                    targets.emailIds.add(workOrderRow.Id);
                    targets.taskWhatIds.add(workOrderRow.Id);
                }
            }
            for (Opportunity opp : [SELECT Id FROM Opportunity WHERE Community__c = :recordId LIMIT 100]) {
                targets.emailIds.add(opp.Id);
                targets.taskWhatIds.add(opp.Id);
            }
            for (Quote quoteRow : [SELECT Id FROM Quote WHERE Opportunity.Community__c = :recordId LIMIT 100]) {
                targets.emailIds.add(quoteRow.Id);
                targets.taskWhatIds.add(quoteRow.Id);
            }
            return targets;
        }
        if (typeName == 'Lot__c') {
            targets.taskWhatIds.add(recordId);
            Lot__c lotRow = [
                SELECT Id, Name, Community__c
                FROM Lot__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (lotRow.Community__c != null) {
                targets.emailIds.add(lotRow.Community__c);
                targets.taskWhatIds.add(lotRow.Community__c);
                QueryTargets communityTargets = buildTargets(lotRow.Community__c);
                mergeTargets(targets, communityTargets);
                for (WorkOrder workOrderRow : [
                    SELECT Id
                    FROM WorkOrder
                    WHERE Lot__c = :recordId
                    LIMIT 100
                ]) {
                    targets.emailIds.add(workOrderRow.Id);
                    targets.taskWhatIds.add(workOrderRow.Id);
                }
            }
            return targets;
        }
        if (typeName == 'ServiceAppointment') {
            targets.taskWhatIds.add(recordId);
            ServiceAppointment appointmentRow = [
                SELECT Id, ParentRecordId, AccountId, ContactId
                FROM ServiceAppointment
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (appointmentRow.AccountId != null) {
                targets.emailIds.add(appointmentRow.AccountId);
                targets.taskWhatIds.add(appointmentRow.AccountId);
            }
            if (appointmentRow.ContactId != null) {
                targets.emailIds.add(appointmentRow.ContactId);
                targets.taskWhoIds.add(appointmentRow.ContactId);
            }
            if (appointmentRow.ParentRecordId != null && appointmentRow.ParentRecordId != recordId) {
                targets.emailIds.add(appointmentRow.ParentRecordId);
                targets.taskWhatIds.add(appointmentRow.ParentRecordId);
                mergeTargets(targets, buildTargets(appointmentRow.ParentRecordId));
            }
            return targets;
        }

        targets.taskWhatIds.add(recordId);
        return targets;
    }

    private static void mergeTargets(QueryTargets baseTargets, QueryTargets extraTargets) {
        if (baseTargets == null || extraTargets == null) {
            return;
        }
        baseTargets.emailIds.addAll(extraTargets.emailIds);
        baseTargets.taskWhatIds.addAll(extraTargets.taskWhatIds);
        baseTargets.taskWhoIds.addAll(extraTargets.taskWhoIds);
    }

    private static Map<Id, String> buildRecordLabelMap(Set<Id> rawIds) {
        Map<Id, String> labels = new Map<Id, String>();
        if (rawIds == null || rawIds.isEmpty()) {
            return labels;
        }

        Map<String, Set<Id>> idsByType = new Map<String, Set<Id>>();
        for (Id value : rawIds) {
            if (value == null) {
                continue;
            }
            String typeName = String.valueOf(value.getSObjectType());
            if (!idsByType.containsKey(typeName)) {
                idsByType.put(typeName, new Set<Id>());
            }
            idsByType.get(typeName).add(value);
        }

        if (idsByType.containsKey('Account')) {
            for (Account row : [SELECT Id, Name FROM Account WHERE Id IN :idsByType.get('Account')]) {
                labels.put(row.Id, row.Name);
            }
        }
        if (idsByType.containsKey('Contact')) {
            for (Contact row : [SELECT Id, Name FROM Contact WHERE Id IN :idsByType.get('Contact')]) {
                labels.put(row.Id, row.Name);
            }
        }
        if (idsByType.containsKey('Lead')) {
            for (Lead row : [SELECT Id, FirstName, LastName, Company FROM Lead WHERE Id IN :idsByType.get('Lead')]) {
                String leadName = firstNonBlank(new List<String>{
                    String.join(new List<String>{row.FirstName, row.LastName}, ' ').trim(),
                    row.Company
                });
                labels.put(row.Id, leadName);
            }
        }
        if (idsByType.containsKey('Opportunity')) {
            for (Opportunity row : [SELECT Id, Name FROM Opportunity WHERE Id IN :idsByType.get('Opportunity')]) {
                labels.put(row.Id, row.Name);
            }
        }
        if (idsByType.containsKey('Case')) {
            for (Case row : [SELECT Id, CaseNumber, Subject FROM Case WHERE Id IN :idsByType.get('Case')]) {
                labels.put(row.Id, firstNonBlank(new List<String>{row.Subject, row.CaseNumber}));
            }
        }
        if (idsByType.containsKey('WorkOrder')) {
            for (WorkOrder row : [SELECT Id, WorkOrderNumber, Subject FROM WorkOrder WHERE Id IN :idsByType.get('WorkOrder')]) {
                labels.put(row.Id, firstNonBlank(new List<String>{row.Subject, row.WorkOrderNumber}));
            }
        }
        if (idsByType.containsKey('Quote')) {
            for (Quote row : [SELECT Id, Name, QuoteNumber FROM Quote WHERE Id IN :idsByType.get('Quote')]) {
                labels.put(row.Id, firstNonBlank(new List<String>{row.Name, row.QuoteNumber}));
            }
        }
        if (idsByType.containsKey('Community__c')) {
            for (Community__c row : [SELECT Id, Name FROM Community__c WHERE Id IN :idsByType.get('Community__c')]) {
                labels.put(row.Id, row.Name);
            }
        }
        if (idsByType.containsKey('Lot__c')) {
            for (Lot__c row : [SELECT Id, Name FROM Lot__c WHERE Id IN :idsByType.get('Lot__c')]) {
                labels.put(row.Id, row.Name);
            }
        }
        if (idsByType.containsKey('ServiceAppointment')) {
            for (ServiceAppointment row : [SELECT Id, AppointmentNumber, Subject FROM ServiceAppointment WHERE Id IN :idsByType.get('ServiceAppointment')]) {
                labels.put(row.Id, firstNonBlank(new List<String>{row.Subject, row.AppointmentNumber}));
            }
        }
        if (idsByType.containsKey('Campaign')) {
            for (Campaign row : [SELECT Id, Name FROM Campaign WHERE Id IN :idsByType.get('Campaign')]) {
                labels.put(row.Id, row.Name);
            }
        }
        if (idsByType.containsKey('Task')) {
            for (Task row : [SELECT Id, Subject FROM Task WHERE Id IN :idsByType.get('Task')]) {
                labels.put(row.Id, row.Subject);
            }
        }

        return labels;
    }

    private static Id safeId(SObject row, String fieldApiName) {
        Object value = safeGet(row, fieldApiName);
        return value == null ? null : (Id) value;
    }

    private static String safeString(SObject row, String fieldApiName) {
        Object value = safeGet(row, fieldApiName);
        return value == null ? null : String.valueOf(value);
    }

    private static Boolean safeBoolean(SObject row, String fieldApiName) {
        Object value = safeGet(row, fieldApiName);
        return value == null ? null : (Boolean) value;
    }

    private static Datetime safeDatetime(SObject row, String fieldApiName) {
        Object value = safeGet(row, fieldApiName);
        return value == null ? null : (Datetime) value;
    }

    private static Date safeDate(SObject row, String fieldApiName) {
        Object value = safeGet(row, fieldApiName);
        return value == null ? null : (Date) value;
    }

    private static String safeRelationshipName(SObject row, String relationshipName) {
        try {
            SObject related = row.getSObject(relationshipName);
            if (related == null) {
                return null;
            }
            Object nameValue = related.get('Name');
            return nameValue == null ? null : String.valueOf(nameValue);
        } catch (Exception ex) {
            return null;
        }
    }

    private static Object safeGet(SObject row, String fieldApiName) {
        try {
            return row.get(fieldApiName);
        } catch (Exception ex) {
            return null;
        }
    }

    private static String directionLabel(Boolean incoming, String fromAddress) {
        if (incoming == true) {
            return 'Inbound';
        }
        if (!String.isBlank(fromAddress) && fromAddress.toLowerCase().contains('no-reply')) {
            return 'System Email';
        }
        return 'Outbound';
    }

    private static String trimPreview(String bodyValue) {
        if (String.isBlank(bodyValue)) {
            return null;
        }
        String cleaned = bodyValue.replace('\r', ' ').replace('\n', ' ').trim();
        return cleaned.length() > 240 ? cleaned.substring(0, 240) + '...' : cleaned;
    }

    private static String buildDefaultFollowUpSubject(Id recordId, Id emailMessageId) {
        if (emailMessageId != null) {
            String typeName = String.valueOf(emailMessageId.getSObjectType());
            if (typeName == 'EmailMessage') {
                EmailDetail detail = getEmailDetail(emailMessageId);
                if (!String.isBlank(detail.subject)) {
                    return 'Follow up: ' + detail.subject;
                }
            } else if (typeName == 'Task') {
                EmailDetail detail = getTaskDetail(emailMessageId);
                if (!String.isBlank(detail.subject)) {
                    return 'Follow up: ' + detail.subject;
                }
            }
        }
        return 'Follow up on recent email';
    }

    private static String buildFollowUpDescription(Id emailMessageId, Id recordId) {
        if (emailMessageId == null) {
            return 'Created from Outdoor Living Email History for record ' + String.valueOf(recordId) + '.';
        }
        String typeName = String.valueOf(emailMessageId.getSObjectType());
        if (typeName == 'EmailMessage') {
            EmailDetail detail = getEmailDetail(emailMessageId);
            return 'Created from email: ' + firstNonBlank(new List<String>{detail.subject, String.valueOf(emailMessageId)});
        }
        if (typeName == 'Task') {
            EmailDetail detail = getTaskDetail(emailMessageId);
            return 'Created from logged email task: ' + firstNonBlank(new List<String>{detail.subject, String.valueOf(emailMessageId)});
        }
        return 'Created from Outdoor Living Email History for record ' + String.valueOf(recordId) + '.';
    }

    private static void validateRecordId(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('A record Id is required.');
        }
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