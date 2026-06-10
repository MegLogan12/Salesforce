public with sharing class LovingCustomerSuccessConsoleController {
    private static final Integer ROW_LIMIT = 8;

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getConsoleData() {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('generatedAt', System.now());
        payload.put('features', buildFeatures());
        payload.put('metrics', buildMetrics());
        payload.put('recordsByTab', buildRecordsByTab());
        payload.put('sourceMap', buildSourceMap());
        payload.put('buttonMatrix', buildButtonMatrix());
        return payload;
    }

    private static List<Map<String, Object>> buildFeatures() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        rows.add(feature('Omni-Channel', hasObject('AgentWork') && hasObject('PendingServiceRouting'), hasObject('AgentWork'), 'Show routed work if present; otherwise fall back to Case inbox.', 'Service Cloud Admin'));
        rows.add(feature('Agentforce Assist', false, false, 'Right rail shows setup-needed state until an approved Agentforce action is available.', 'Salesforce Admin / AI Owner'));
        rows.add(feature('Knowledge', hasObject('KnowledgeArticleVersion'), hasObject('KnowledgeArticleVersion'), 'Show published articles or setup-needed state.', 'Knowledge Manager'));
        rows.add(feature('Entitlements', hasObject('Entitlement'), hasObject('Entitlement'), 'Show SLA card from Entitlement/CaseMilestone where available.', 'Service Cloud Admin'));
        rows.add(feature('Case Milestones', hasObject('CaseMilestone'), hasObject('CaseMilestone'), 'Show milestone rows where available.', 'Service Cloud Admin'));
        rows.add(feature('Email-to-Case', hasObject('EmailMessage'), hasObject('EmailMessage'), 'Use EmailMessage timeline; otherwise fall back to Case list.', 'Service Cloud Admin'));
        rows.add(feature('Web-to-Case', hasField('Case', 'Origin'), hasObject('Case'), 'Use Case Origin; otherwise manual Case creation only.', 'Service Cloud Admin'));
        rows.add(feature('Service Cloud Voice', hasObject('VoiceCall'), hasObject('VoiceCall'), 'Use VoiceCall timeline; otherwise use Task call logging fallback.', 'Service Cloud Admin'));
        rows.add(feature('Messaging', hasObject('MessagingSession'), hasObject('MessagingSession'), 'Use MessagingSession where present; otherwise Case/email fallback.', 'Service Cloud Admin'));
        rows.add(feature('Macros', hasObject('Macro'), hasObject('Macro'), 'Show available macros; run action remains disabled until approved integration exists.', 'Service Cloud Admin'));
        rows.add(feature('Quick Text', hasObject('QuickText'), hasObject('QuickText'), 'Show QuickText snippets; insert action remains disabled until composer integration exists.', 'Service Cloud Admin'));
        rows.add(feature('Queues', hasObject('Group'), hasObject('Group'), 'Queue counts are surfaced when Group queue records are available.', 'Salesforce Admin'));
        rows.add(feature('Case Assignment Rules', false, false, 'Setup audit item only; no runtime button is exposed.', 'Salesforce Admin'));
        rows.add(feature('Auto-response Rules', false, false, 'Setup audit item only; no runtime button is exposed.', 'Salesforce Admin'));
        return rows;
    }

    private static Map<String, Object> feature(String name, Boolean enabled, Boolean available, String behavior, String owner) {
        return new Map<String, Object>{
            'feature' => name,
            'enabled' => enabled,
            'objectAvailable' => available,
            'uiBehaviorIfMissing' => behavior,
            'setupOwner' => owner
        };
    }

    private static Map<String, Object> buildMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();
        metrics.put('openCases', countRows('Case', 'IsClosed = false'));
        metrics.put('urgentCases', countRows('Case', 'IsClosed = false AND Priority IN (\'High\', \'Critical\')'));
        metrics.put('newToday', countRows('Case', 'CreatedDate = TODAY'));
        metrics.put('omniWork', countRows('AgentWork', null) + countRows('PendingServiceRouting', null));
        metrics.put('siteVisits', countRows('ServiceAppointment', 'SchedStartTime = TODAY'));
        metrics.put('openWarranty', countRows('Case', 'IsClosed = false AND (Type = \'Warranty\' OR Reason = \'Warranty\')'));
        metrics.put('sameDay', countRows('Case', 'IsClosed = false AND Priority IN (\'High\', \'Critical\')'));
        metrics.put('approvals', countRows('ProcessInstanceWorkitem', null));
        metrics.put('quotes', countRows('Quote', null));
        metrics.put('knowledge', countRows('KnowledgeArticleVersion', 'PublishStatus = \'Online\''));
        return metrics;
    }

    private static Map<String, Object> buildRecordsByTab() {
        Map<String, Object> rows = new Map<String, Object>();
        List<Map<String, Object>> cases = queryCases(null, ROW_LIMIT);
        rows.put('home', cases);
        rows.put('omni', queryOmni());
        rows.put('cases', cases);
        rows.put('builder360', queryAccounts());
        rows.put('siteVisits', queryServiceAppointments());
        rows.put('epo', queryCases('IsClosed = false AND (Type = \'EPO\' OR Type = \'PO Change\' OR Subject LIKE \'%EPO%\' OR Subject LIKE \'%PO Change%\')', ROW_LIMIT));
        rows.put('warranty', queryCases('IsClosed = false AND (Type = \'Warranty\' OR Reason = \'Warranty\' OR Subject LIKE \'%Warranty%\')', ROW_LIMIT));
        rows.put('sameDay', queryCases('IsClosed = false AND Priority IN (\'High\', \'Critical\')', ROW_LIMIT));
        rows.put('closeout', queryWorkOrders());
        rows.put('knowledge', queryKnowledge());
        rows.put('reports', queryReports());
        rows.put('approvals', queryApprovals());
        rows.put('quotes', queryQuotes());
        return rows;
    }

    private static List<Map<String, Object>> queryCases(String whereClause, Integer rowLimit) {
        if (!hasObject('Case')) {
            return new List<Map<String, Object>>();
        }
        String queryText = 'SELECT Id, CaseNumber, Subject, Status, Priority, Origin, AccountId, ContactId, CreatedDate';
        if (hasRelationship('Case', 'Account')) {
            queryText += ', Account.Name';
        }
        if (hasRelationship('Case', 'Contact')) {
            queryText += ', Contact.Name';
        }
        queryText += ' FROM Case';
        if (String.isNotBlank(whereClause)) {
            queryText += ' WHERE ' + whereClause;
        }
        queryText += ' ORDER BY CreatedDate DESC LIMIT ' + String.valueOf(rowLimit);
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (SObject item : Database.query(queryText)) {
            rows.add(recordRow(
                (Id)item.get('Id'),
                safeString(item.get('CaseNumber')),
                safeString(item.get('Subject')),
                safeString(item.get('Status')),
                safeString(item.get('Priority')),
                safeString(item.get('Origin')),
                getRelatedName(item, 'Account'),
                getRelatedName(item, 'Contact')
            ));
        }
        return rows;
    }

    private static List<Map<String, Object>> queryOmni() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        rows.addAll(queryGeneric('AgentWork', new List<String>{'Id', 'Status', 'WorkItemId', 'CreatedDate'}, null, 'CreatedDate DESC', 4, 'Agent Work'));
        rows.addAll(queryGeneric('PendingServiceRouting', new List<String>{'Id', 'WorkItemId', 'CreatedDate'}, null, 'CreatedDate DESC', 4, 'Pending Routing'));
        if (rows.isEmpty()) {
            rows.addAll(queryCases('IsClosed = false', ROW_LIMIT));
        }
        return rows;
    }

    private static List<Map<String, Object>> queryAccounts() {
        return queryGeneric('Account', new List<String>{'Id', 'Name', 'Type', 'OwnerId', 'CreatedDate'}, null, 'LastModifiedDate DESC', ROW_LIMIT, 'Account');
    }

    private static List<Map<String, Object>> queryServiceAppointments() {
        return queryGeneric('ServiceAppointment', new List<String>{'Id', 'Subject', 'Status', 'SchedStartTime', 'ParentRecordId', 'CreatedDate'}, null, 'SchedStartTime ASC NULLS LAST', ROW_LIMIT, 'Service Appointment');
    }

    private static List<Map<String, Object>> queryWorkOrders() {
        return queryGeneric('WorkOrder', new List<String>{'Id', 'WorkOrderNumber', 'Subject', 'Status', 'Priority', 'CreatedDate'}, null, 'CreatedDate DESC', ROW_LIMIT, 'Work Order');
    }

    private static List<Map<String, Object>> queryKnowledge() {
        return queryGeneric('KnowledgeArticleVersion', new List<String>{'Id', 'Title', 'ArticleNumber', 'Summary', 'PublishStatus'}, 'PublishStatus = \'Online\'', 'LastPublishedDate DESC NULLS LAST', ROW_LIMIT, 'Knowledge');
    }

    private static List<Map<String, Object>> queryReports() {
        return queryGeneric('Report', new List<String>{'Id', 'Name', 'DeveloperName', 'CreatedDate'}, null, 'LastModifiedDate DESC', ROW_LIMIT, 'Report');
    }

    private static List<Map<String, Object>> queryApprovals() {
        return queryGeneric('ProcessInstanceWorkitem', new List<String>{'Id', 'ActorId', 'OriginalActorId', 'ProcessInstanceId', 'CreatedDate'}, null, 'CreatedDate DESC', ROW_LIMIT, 'Approval');
    }

    private static List<Map<String, Object>> queryQuotes() {
        return queryGeneric('Quote', new List<String>{'Id', 'Name', 'QuoteNumber', 'Status', 'GrandTotal', 'CreatedDate'}, null, 'CreatedDate DESC', ROW_LIMIT, 'Quote');
    }

    private static List<Map<String, Object>> queryGeneric(String objectApiName, List<String> desiredFields, String whereClause, String orderBy, Integer rowLimit, String source) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        if (!hasObject(objectApiName)) {
            return rows;
        }
        List<String> fields = new List<String>();
        for (String fieldName : desiredFields) {
            if (hasField(objectApiName, fieldName)) {
                fields.add(fieldName);
            }
        }
        if (!fields.contains('Id')) {
            fields.add('Id');
        }
        String queryText = 'SELECT ' + String.join(fields, ', ') + ' FROM ' + objectApiName;
        if (String.isNotBlank(whereClause)) {
            queryText += ' WHERE ' + whereClause;
        }
        if (String.isNotBlank(orderBy)) {
            queryText += ' ORDER BY ' + orderBy;
        }
        queryText += ' LIMIT ' + String.valueOf(rowLimit);
        try {
            for (SObject item : Database.query(queryText)) {
                rows.add(genericRow(item, fields, source));
            }
        } catch (Exception ex) {
            rows.add(new Map<String, Object>{
                'id' => null,
                'name' => source,
                'title' => 'Setup needed',
                'status' => 'Unavailable',
                'tone' => 'amber',
                'detail' => ex.getMessage(),
                'source' => source
            });
        }
        return rows;
    }

    private static Map<String, Object> genericRow(SObject item, List<String> fields, String source) {
        String nameValue = firstValue(item, new List<String>{'Name', 'CaseNumber', 'WorkOrderNumber', 'QuoteNumber', 'Title', 'Subject', 'Status', 'Id'});
        String titleValue = firstValue(item, new List<String>{'Subject', 'Name', 'Title', 'QuoteNumber', 'WorkOrderNumber', 'CaseNumber', 'Id'});
        String statusValue = firstValue(item, new List<String>{'Status', 'PublishStatus', 'StepStatus'});
        return new Map<String, Object>{
            'id' => safeString(item.get('Id')),
            'name' => nameValue,
            'title' => titleValue,
            'status' => statusValue,
            'priority' => firstValue(item, new List<String>{'Priority'}),
            'source' => source,
            'detail' => buildDetail(item, fields),
            'tone' => toneFor(statusValue, firstValue(item, new List<String>{'Priority'}))
        };
    }

    private static Map<String, Object> recordRow(Id recordId, String nameValue, String titleValue, String statusValue, String priorityValue, String sourceValue, String accountName, String contactName) {
        return new Map<String, Object>{
            'id' => recordId,
            'name' => nameValue,
            'title' => titleValue,
            'status' => statusValue,
            'priority' => priorityValue,
            'source' => String.isBlank(sourceValue) ? 'Case' : sourceValue,
            'accountName' => accountName,
            'contactName' => contactName,
            'detail' => String.join(new List<String>{blankToDash(accountName), blankToDash(contactName)}, ' / '),
            'tone' => toneFor(statusValue, priorityValue)
        };
    }

    private static List<Map<String, Object>> buildSourceMap() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        rows.add(source('Omni Inbox', 'AgentWork, PendingServiceRouting, Case', 'WorkItemId, Status, OwnerId', hasObject('AgentWork') && hasObject('PendingServiceRouting'), false, 'Use Omni objects first; fall back to Case list.'));
        rows.add(source('Case workspace', 'Case', 'CaseNumber, Subject, Status, Priority, Origin, AccountId, ContactId', hasObject('Case'), false, 'Case is the Customer Success intake source of truth.'));
        rows.add(source('Builder 360', 'Account, Contact, Case', 'ParentId, AccountId, ContactId', hasObject('Account') && hasObject('Contact'), false, 'Use Account hierarchy and related Case activity.'));
        rows.add(source('Site Visits', 'WorkOrder, ServiceAppointment', 'ParentRecordId, SchedStartTime, Status', hasObject('ServiceAppointment'), false, 'Use FSL objects for field follow-up only.'));
        rows.add(source('EPO / PO Changes', 'Case, Quote, WorkOrder', 'Type, Subject, Quote Status, ParentWorkOrderId', hasObject('Case') && hasObject('Quote'), false, 'Represent review queue without creating child Work Orders yet.'));
        rows.add(source('Warranty', 'Case, WorkOrder', 'Type, Reason, Status, Priority', hasObject('Case'), false, 'Case-first, WorkOrder follow-up.'));
        rows.add(source('Same-Day', 'Case, WorkOrder, ServiceAppointment', 'Priority, Status, SchedStartTime', hasObject('Case'), false, 'High-priority Case plus field follow-up.'));
        rows.add(source('Closeout Queue', 'WorkOrder, ServiceAppointment, Case', 'Status, completed field where present', hasObject('WorkOrder'), false, 'Read-only review queue.'));
        rows.add(source('Knowledge + Playbooks', 'KnowledgeArticleVersion, Macro, QuickText', 'Title, ArticleNumber, Name', hasObject('KnowledgeArticleVersion'), false, 'Do not fake articles; show setup state if empty.'));
        rows.add(source('Reports', 'Report, Dashboard', 'Name, DeveloperName', hasObject('Report'), false, 'Summaries link to real reports where present.'));
        rows.add(source('Approvals', 'ProcessInstanceWorkitem, Case, Quote, WorkOrder, Task', 'TargetObjectId, ActorId, Status', hasObject('ProcessInstanceWorkitem'), false, 'Approval actions disabled until approved flow/action is identified.'));
        rows.add(source('Quotes + Quote Builder', 'Quote, QuoteLineItem, PricebookEntry', 'QuoteNumber, Status, GrandTotal', hasObject('Quote') && hasObject('QuoteLineItem'), false, 'Standard Quote first; CPQ not assumed.'));
        return rows;
    }

    private static Map<String, Object> source(String area, String obj, String fields, Boolean exists, Boolean lovingNeeded, String recommendation) {
        return new Map<String, Object>{
            'uiArea' => area,
            'standardObject' => obj,
            'standardFieldRelationship' => fields,
            'exists' => exists,
            'lovingFieldNeeded' => lovingNeeded,
            'recommendation' => recommendation
        };
    }

    private static List<Map<String, Object>> buildButtonMatrix() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        rows.add(button('+ New Case', 'Home/Cases', 'Open standard Case create modal', 'Case', hasObject('Case'), 'navigateNew'));
        rows.add(button('Accept next', 'Omni Inbox', 'Disabled until Omni accept action is approved', 'AgentWork', false, 'disabled'));
        rows.add(button('Open Case', 'Cases/Omni', 'Navigate to Case record', 'Case', hasObject('Case'), 'navigateRecord'));
        rows.add(button('Create SA', 'Same-Day/Site Visits', 'Open standard ServiceAppointment create modal', 'ServiceAppointment', hasObject('ServiceAppointment'), 'navigateNew'));
        rows.add(button('Send reminder', 'EPO / PO Changes', 'Disabled until approved email action/template exists', 'EmailMessage/Task', false, 'disabled'));
        rows.add(button('Escalate', 'EPO / PO Changes', 'Disabled until escalation flow is approved', 'Case/Task', false, 'disabled'));
        rows.add(button('Review', 'Approvals', 'Open target record where available', 'ProcessInstanceWorkitem', hasObject('ProcessInstanceWorkitem'), 'navigateRecord'));
        rows.add(button('Approve Selected', 'Approvals', 'Disabled until approval flow/action is approved', 'ProcessInstanceWorkitem', false, 'disabled'));
        rows.add(button('Return for correction', 'Approvals', 'Disabled until correction flow is approved', 'Case/Task', false, 'disabled'));
        rows.add(button('Reject with reason', 'Approvals', 'Disabled until rejection flow is approved', 'ProcessInstanceWorkitem/Case/Quote', false, 'disabled'));
        rows.add(button('Run macro', 'Right rail', 'Disabled until macro execution integration is approved', 'Macro', false, 'disabled'));
        rows.add(button('Insert quick text', 'Right rail', 'Disabled until composer integration is approved', 'QuickText', false, 'disabled'));
        rows.add(button('Send to Builder', 'Quotes + Quote Builder', 'Disabled until approved send action/template exists', 'Quote/EmailMessage', false, 'disabled'));
        return rows;
    }

    private static Map<String, Object> button(String label, String tab, String behavior, String primaryObject, Boolean enabled, String actionType) {
        return new Map<String, Object>{
            'button' => label,
            'tab' => tab,
            'requiredBehavior' => behavior,
            'primaryObject' => primaryObject,
            'enabled' => enabled,
            'actionType' => actionType
        };
    }

    private static Integer countRows(String objectApiName, String whereClause) {
        if (!hasObject(objectApiName)) {
            return 0;
        }
        try {
            String queryText = 'SELECT COUNT() FROM ' + objectApiName;
            if (String.isNotBlank(whereClause)) {
                queryText += ' WHERE ' + whereClause;
            }
            return Database.countQuery(queryText);
        } catch (Exception ex) {
            return 0;
        }
    }

    private static Boolean hasObject(String objectApiName) {
        return Schema.getGlobalDescribe().containsKey(objectApiName);
    }

    private static Boolean hasField(String objectApiName, String fieldApiName) {
        if (!hasObject(objectApiName)) {
            return false;
        }
        return Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().containsKey(fieldApiName);
    }

    private static Boolean hasRelationship(String objectApiName, String relationshipName) {
        if (!hasObject(objectApiName)) {
            return false;
        }
        Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
        for (Schema.SObjectField fieldRef : describeResult.fields.getMap().values()) {
            Schema.DescribeFieldResult fieldDescribe = fieldRef.getDescribe();
            if (fieldDescribe.getRelationshipName() == relationshipName) {
                return true;
            }
        }
        return false;
    }

    private static String getRelatedName(SObject item, String relationshipName) {
        try {
            SObject relatedRecord = item.getSObject(relationshipName);
            return relatedRecord == null ? '' : safeString(relatedRecord.get('Name'));
        } catch (Exception ex) {
            return '';
        }
    }

    private static String firstValue(SObject item, List<String> fieldNames) {
        for (String fieldName : fieldNames) {
            try {
                Object value = item.get(fieldName);
                if (value != null && String.isNotBlank(String.valueOf(value))) {
                    return String.valueOf(value);
                }
            } catch (Exception ex) {
                continue;
            }
        }
        return '';
    }

    private static String buildDetail(SObject item, List<String> fields) {
        List<String> parts = new List<String>();
        for (String fieldName : fields) {
            if (fieldName == 'Id' || fieldName == 'Name' || fieldName == 'Subject' || fieldName == 'Title') {
                continue;
            }
            try {
                Object value = item.get(fieldName);
                if (value != null && parts.size() < 3) {
                    parts.add(fieldName + ': ' + String.valueOf(value));
                }
            } catch (Exception ex) {
                continue;
            }
        }
        return String.join(parts, ' / ');
    }

    private static String toneFor(String statusValue, String priorityValue) {
        String combined = (String.valueOf(statusValue) + ' ' + String.valueOf(priorityValue)).toLowerCase();
        if (combined.contains('critical') || combined.contains('high') || combined.contains('escalat') || combined.contains('breach')) {
            return 'red';
        }
        if (combined.contains('new') || combined.contains('pending') || combined.contains('working') || combined.contains('open')) {
            return 'amber';
        }
        if (combined.contains('closed') || combined.contains('complete') || combined.contains('online')) {
            return 'green';
        }
        return 'blue';
    }

    private static String safeString(Object value) {
        return value == null ? '' : String.valueOf(value);
    }

    private static String blankToDash(String value) {
        return String.isBlank(value) ? '-' : value;
    }
}