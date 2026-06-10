public with sharing class ODLWarrantyCaseController {
    public class WarrantyCaseData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public String reason;
        @AuraEnabled public String type;
        @AuraEnabled public String reportedDate;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String contactName;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String coverageState;
        @AuraEnabled public String coverageChip;
        @AuraEnabled public String inCoverage;
        @AuraEnabled public String recommendation;
        @AuraEnabled public String nextActionTitle;
        @AuraEnabled public String nextActionReason;
        @AuraEnabled public Boolean decisionEnabled;
        @AuraEnabled public String decisionDisabledReason;
        @AuraEnabled public Integer fileCount;
        @AuraEnabled public Integer taskCount;
        @AuraEnabled public List<Row> highlights;
        @AuraEnabled public List<Row> periods;
        @AuraEnabled public List<Row> evidence;
        @AuraEnabled public List<Row> resolutionPath;
        @AuraEnabled public List<Row> relatedWorkOrders;
        @AuraEnabled public List<Row> activity;
        @AuraEnabled public List<Row> auditGaps;
    }

    public class Row {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public String status;
        @AuraEnabled public String value;
        @AuraEnabled public String detail;
        @AuraEnabled public String url;

        public Row(Id id, String label, String type, String status, String value, String detail) {
            this.id = id;
            this.label = label;
            this.type = type;
            this.status = status;
            this.value = value;
            this.detail = detail;
            this.url = id == null ? null : '/' + String.valueOf(id);
        }
    }

    @AuraEnabled(cacheable=true)
    public static WarrantyCaseData getWarrantyCaseData(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Case record id is required.');
        }
        if (!Schema.sObjectType.Case.isAccessible()) {
            throw new AuraHandledException('You do not have access to Case.');
        }

        Case c = [
            SELECT Id, CaseNumber, Subject, Status, Priority, Reason, Type, AccountId, Account.Name,
                   ContactId, Contact.Name, Owner.Name, CreatedDate, ClosedDate, IsClosed, Origin
            FROM Case
            WHERE Id = :recordId
            LIMIT 1
        ];

        WarrantyCaseData data = new WarrantyCaseData();
        data.caseId = c.Id;
        data.caseNumber = c.CaseNumber;
        data.subject = firstNonBlank(new List<String>{ c.Subject, 'Warranty case' });
        data.status = c.Status;
        data.priority = c.Priority;
        data.reason = c.Reason;
        data.type = c.Type;
        data.reportedDate = fmtDate(c.CreatedDate);
        data.accountId = c.AccountId;
        data.accountName = c.Account == null ? 'No account linked' : c.Account.Name;
        data.contactId = c.ContactId;
        data.contactName = c.Contact == null ? 'No contact linked' : c.Contact.Name;
        data.ownerName = c.Owner == null ? 'Unassigned' : c.Owner.Name;
        data.fileCount = countFiles(new Set<Id>{ c.Id });
        data.taskCount = countTasks(c.Id);
        data.relatedWorkOrders = loadRelatedWorkOrders(c.AccountId);
        data.periods = buildPeriods(data.relatedWorkOrders);
        data.coverageState = determineCoverageState(data.relatedWorkOrders);
        data.coverageChip = chipForCoverage(data.coverageState);
        data.inCoverage = data.coverageState == 'Covered' ? 'Yes' : data.coverageState == 'Pending Determination' ? 'Pending' : 'No';
        data.decisionEnabled = false;
        data.decisionDisabledReason = 'No Case coverage determination field is deployed. Capture the determination field/model before enabling money or work-order actions.';
        data.recommendation = buildRecommendation(data);
        data.nextActionTitle = buildNextActionTitle(data);
        data.nextActionReason = buildNextActionReason(data);
        data.highlights = buildHighlights(data);
        data.evidence = buildEvidence(data);
        data.resolutionPath = buildResolutionPath(data);
        data.activity = loadActivity(c.Id);
        data.auditGaps = buildAuditGaps();
        return data;
    }

    private static List<Row> loadRelatedWorkOrders(Id accountId) {
        List<Row> rows = new List<Row>();
        if (accountId == null || !Schema.getGlobalDescribe().containsKey('Work_Order__c')) return rows;
        Schema.SObjectType woType = Schema.getGlobalDescribe().get('Work_Order__c');
        if (!woType.getDescribe().isAccessible()) return rows;
        Map<String, Schema.SObjectField> fields = woType.getDescribe().fields.getMap();
        List<String> selectFields = new List<String>{ 'Id', 'Name' };
        for (String f : new List<String>{ 'Status__c', 'Work_Order_Type__c', 'Is_Warranty__c', 'Warranty_Coverage_Type__c', 'Warranty_Coverage_Status__c', 'Warranty_Determination__c', 'Warranty_Start_Date__c', 'Warranty_End_Date__c', 'Warranty_Voided_Reason__c', 'Parent_Account__c' }) {
            addIfReadable(selectFields, fields, f);
        }
        String query = 'SELECT ' + String.join(selectFields, ',') +
            ' FROM Work_Order__c WHERE Parent_Account__c = :accountId ORDER BY LastModifiedDate DESC LIMIT 8';
        for (SObject wo : Database.query(query)) {
            String type = firstNonBlank(new List<String>{ stringVal(wo, 'Work_Order_Type__c'), 'Work Order' });
            String status = firstNonBlank(new List<String>{ stringVal(wo, 'Status__c'), 'Not captured' });
            String coverage = firstNonBlank(new List<String>{ stringVal(wo, 'Warranty_Coverage_Type__c'), stringVal(wo, 'Warranty_Coverage_Status__c'), 'Coverage not captured' });
            String dates = dateVal(wo, 'Warranty_Start_Date__c') + ' to ' + dateVal(wo, 'Warranty_End_Date__c');
            rows.add(new Row((Id) wo.get('Id'), String.valueOf(wo.get('Name')), type, status, coverage, dates));
        }
        return rows;
    }

    private static List<Row> buildPeriods(List<Row> workOrders) {
        List<Row> rows = new List<Row>();
        Boolean foundPeriod = false;
        for (Row wo : workOrders) {
            if (String.isNotBlank(wo.detail) && !wo.detail.contains('Not captured')) {
                foundPeriod = true;
                rows.add(new Row(wo.id, wo.label, 'Warranty period', wo.value, wo.detail, wo.type + ' · ' + wo.status));
            }
        }
        if (!foundPeriod) {
            rows.add(new Row(null, 'Workmanship period', 'Gap', 'Missing', 'Start/end not captured', 'The Case page cannot compute coverage until a real substantial completion/warranty period source is linked.'));
            rows.add(new Row(null, 'Extended warranty', 'Gap', 'Missing', 'Not configured', 'If extended coverage was sold, add the source field/model before enabling determinations.'));
        }
        return rows;
    }

    private static String determineCoverageState(List<Row> workOrders) {
        for (Row row : workOrders) {
            String combined = (row.value + ' ' + row.detail + ' ' + row.status).toLowerCase();
            if (combined.contains('pending')) return 'Pending Determination';
            if (combined.contains('goodwill')) return 'Goodwill';
            if (combined.contains('void') || combined.contains('out of period')) return 'Denied';
            if (combined.contains('warranty') && !combined.contains('out of period')) return 'Needs Inspection';
        }
        return 'Pending Determination';
    }

    private static String chipForCoverage(String state) {
        if (state == 'Covered') return 'green';
        if (state == 'Denied') return 'red';
        if (state == 'Goodwill') return 'purple';
        if (state == 'Needs Inspection') return 'blue';
        return 'amber';
    }

    private static String buildRecommendation(WarrantyCaseData data) {
        if (data.relatedWorkOrders.isEmpty()) {
            return 'Link the original project or warranty Work Order before determining coverage. The page is intentionally not guessing warranty eligibility.';
        }
        if (data.coverageState == 'Needs Inspection') {
            return 'Inspect and confirm cause before a human records coverage. Covered work and chargeable quote actions stay locked until that decision exists.';
        }
        return 'Review the linked warranty source, evidence, and customer report, then record a human coverage decision.';
    }

    private static String buildNextActionTitle(WarrantyCaseData data) {
        if (data.relatedWorkOrders.isEmpty()) return 'Link warranty source before determination';
        if (data.fileCount == 0) return 'Capture claim evidence';
        if (!data.decisionEnabled) return 'Configure determination field/model';
        return 'Record coverage decision';
    }

    private static String buildNextActionReason(WarrantyCaseData data) {
        if (data.relatedWorkOrders.isEmpty()) {
            return 'No linked warranty/source Work Order was found for this customer. Coverage depends on the original completion date, scope, and warranty period.';
        }
        if (data.fileCount == 0) {
            return 'No files are linked to the Case yet. Capture photos or signed scope before determining coverage.';
        }
        return data.decisionDisabledReason;
    }

    private static List<Row> buildHighlights(WarrantyCaseData data) {
        return new List<Row>{
            new Row(null, 'Issue category', 'Highlight', data.reason, null, 'Case Reason'),
            new Row(null, 'Reported', 'Highlight', data.reportedDate, null, null),
            new Row(null, 'Original project', 'Highlight', data.relatedWorkOrders.isEmpty() ? 'Not linked' : data.relatedWorkOrders[0].label, null, null),
            new Row(null, 'In coverage', 'Highlight', data.inCoverage, null, null),
            new Row(null, 'Determination', 'Highlight', data.coverageState, null, null),
            new Row(null, 'Owner', 'Highlight', data.ownerName, null, null)
        };
    }

    private static List<Row> buildEvidence(WarrantyCaseData data) {
        return new List<Row>{
            new Row(null, 'Case files', 'Evidence', String.valueOf(data.fileCount), 'Salesforce Files', 'Files linked directly to this Case.'),
            new Row(null, 'Activities', 'Evidence', String.valueOf(data.taskCount), 'Tasks', 'Tasks/calls linked directly to this Case.'),
            new Row(null, 'Original project photos', 'Evidence', data.relatedWorkOrders.isEmpty() ? 'Missing link' : 'Use linked Work Order', null, 'No stock images are shown.')
        };
    }

    private static List<Row> buildResolutionPath(WarrantyCaseData data) {
        return new List<Row>{
            new Row(null, 'Covered', 'Resolution', 'Locked', 'No-charge warranty Work Order', 'Disabled until a human coverage decision is recorded.'),
            new Row(null, 'Chargeable Repair', 'Resolution', 'Locked', 'Repair quote', 'Disabled until a human coverage decision is recorded.'),
            new Row(null, 'Goodwill', 'Resolution', 'Locked', 'Manager-approved goodwill path', 'Disabled until decision and approval path are configured.'),
            new Row(null, 'Denied', 'Resolution', 'Locked', 'Determination notice', 'Disabled until the denial reason is recorded.')
        };
    }

    private static List<Row> loadActivity(Id caseId) {
        List<Row> rows = new List<Row>();
        if (!Schema.sObjectType.Task.isAccessible()) return rows;
        for (Task t : [
            SELECT Id, Subject, Status, ActivityDate, Owner.Name
            FROM Task
            WHERE WhatId = :caseId
            ORDER BY LastModifiedDate DESC
            LIMIT 8
        ]) {
            rows.add(new Row(t.Id, t.Subject, 'Task', t.Status, t.ActivityDate == null ? null : String.valueOf(t.ActivityDate), t.Owner == null ? null : t.Owner.Name));
        }
        return rows;
    }

    private static List<Row> buildAuditGaps() {
        List<Row> rows = new List<Row>();
        Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
        if (!caseFields.containsKey('Coverage_Determination__c') && !caseFields.containsKey('Warranty_Determination__c')) {
            rows.add(new Row(null, 'Case determination field', 'Gap', 'Missing', null, 'No Case field found for a recorded warranty decision.'));
        }
        if (!caseFields.containsKey('Determination_Reason__c')) {
            rows.add(new Row(null, 'Determination reason', 'Gap', 'Missing', null, 'Decision buttons stay disabled until a reason field/model exists.'));
        }
        if (Schema.getGlobalDescribe().containsKey('Warranty_Record__c')) {
            Schema.SObjectType wr = Schema.getGlobalDescribe().get('Warranty_Record__c');
            Map<String, Schema.SObjectField> wrFields = wr.getDescribe().fields.getMap();
            if (!wrFields.containsKey('Case__c')) {
                rows.add(new Row(null, 'Warranty_Record__c linkage', 'Gap', 'Missing', null, 'Warranty_Record__c exists but is not linked to Case in the live describe.'));
            }
        } else {
            rows.add(new Row(null, 'Warranty_Record__c', 'Gap', 'Missing', null, 'No custom warranty object was found.'));
        }
        rows.add(new Row(null, 'Resolution automation', 'Control', 'Locked', null, 'No work order or quote action fires before a recorded human determination.'));
        return rows;
    }

    private static Integer countFiles(Set<Id> ids) {
        if (ids == null || ids.isEmpty() || !Schema.sObjectType.ContentDocumentLink.isAccessible()) return 0;
        return [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId IN :ids];
    }

    private static Integer countTasks(Id caseId) {
        if (caseId == null || !Schema.sObjectType.Task.isAccessible()) return 0;
        return [SELECT COUNT() FROM Task WHERE WhatId = :caseId];
    }

    private static void addIfReadable(List<String> selectFields, Map<String, Schema.SObjectField> fieldMap, String apiName) {
        if (fieldMap.containsKey(apiName) && fieldMap.get(apiName).getDescribe().isAccessible()) {
            selectFields.add(apiName);
        }
    }

    private static String stringVal(SObject row, String fieldName) {
        try {
            Object val = row.get(fieldName);
            return val == null ? null : String.valueOf(val);
        } catch (Exception e) {
            return null;
        }
    }

    private static String dateVal(SObject row, String fieldName) {
        try {
            Object val = row.get(fieldName);
            return val == null ? 'Not captured' : String.valueOf((Date) val);
        } catch (Exception e) {
            return 'Not captured';
        }
    }

    private static String fmtDate(Datetime value) {
        return value == null ? 'Not captured' : String.valueOf(value.date());
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (String.isNotBlank(value)) return value;
        }
        return null;
    }
}