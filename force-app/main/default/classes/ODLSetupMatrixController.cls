public with sharing class ODLSetupMatrixController {
    public class ObjectMatrixRow {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String standardFirst;
        @AuraEnabled public String existingReuse;
        @AuraEnabled public String customOnlyIfNeeded;
        @AuraEnabled public String lobNote;
    }

    public class PageInventoryRow {
        @AuraEnabled public String page;
        @AuraEnabled public String cards;
    }

    public class PicklistScopeRow {
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String values;
    }

    public class PageData {
        @AuraEnabled public String sourceRule;
        @AuraEnabled public List<ObjectMatrixRow> objectRows;
        @AuraEnabled public List<PageInventoryRow> pageRows;
        @AuraEnabled public List<PicklistScopeRow> picklistRows;
    }

    @AuraEnabled(cacheable=true)
    public static PageData getPageData() {
        PageData data = new PageData();
        data.sourceRule = 'Standard Salesforce field first, existing LOVING field second, new custom field last.';
        data.objectRows = new List<ObjectMatrixRow>();
        data.pageRows = new List<PageInventoryRow>();
        data.picklistRows = new List<PicklistScopeRow>();

        data.objectRows.add(matrixRow(
            'Account',
            new List<String>{ 'Name', 'Phone', 'Website', 'OwnerId' },
            new List<String>{ 'Account_Status__c', 'BMG_Package__c', 'Contract_Status__c' },
            new List<String>{ 'Customer_Health__c' },
            'Use homeowner-specific record type and package governance.'
        ));
        data.objectRows.add(matrixRow(
            'Lead',
            new List<String>{ 'FirstName', 'LastName', 'Company', 'Email', 'Phone', 'LeadSource', 'Status', 'OwnerId' },
            new List<String>{ 'Market__c' },
            new List<String>{ 'ODL_Path__c', 'Service_Interest__c', 'Budget_Range__c' },
            'Lane-specific lead handling remains scoped by ODL path.'
        ));
        data.objectRows.add(matrixRow(
            'Opportunity',
            new List<String>{ 'Name', 'AccountId', 'StageName', 'Amount', 'CloseDate', 'OwnerId', 'Type' },
            new List<String>{ 'BMG_Package__c', 'Community_Name__c', 'Services_Selected__c' },
            new List<String>{ 'Selected_Package__c', 'Customer_Visible_Status__c' },
            'Opportunity routing is split by UMB and Design Build.'
        ));
        data.objectRows.add(matrixRow(
            'Homeowner_Property__c',
            new List<String>{},
            new List<String>{ 'Opportunity__c', 'Community__c', 'Lot__c', 'Homeowner_Account__c' },
            new List<String>{},
            'Related under homeowner account and opportunity pages.'
        ));
        data.objectRows.add(matrixRow(
            'Campaign',
            new List<String>{ 'Name', 'Type', 'Status', 'StartDate', 'EndDate' },
            new List<String>{ 'Builder_Account__c' },
            new List<String>{ 'Voucher__c' },
            'Voucher campaigns remain separate from homeowner demand-gen campaigns.'
        ));
        data.objectRows.add(matrixRow(
            'Work_Order__c',
            new List<String>{},
            new List<String>{ 'Status__c', 'BMG_Package__c', 'Schedule_Proposal_Status__c', 'Site_Readiness_Status__c' },
            new List<String>{ 'Homeowner_Property__c' },
            'Work-order status and customer-visible updates must stay lane-safe.'
        ));

        data.pageRows.add(pageRow('Account', 'Account Snapshot, Property Related Record, Related Opportunities, Activity Timeline, Files and Photos, Payment Summary'));
        data.pageRows.add(pageRow('Opportunity UMB', 'Opportunity Path, Opportunity Snapshot, Package Selection, Activity and Next Follow-Up, Design Review, Quote Contract Payment, Related Property, Files and Photos, Open Items'));
        data.pageRows.add(pageRow('Opportunity Custom Build', 'Opportunity Path, Opportunity Snapshot, Discovery Summary, Site Visit and Scope, Activity and Next Follow-Up, Estimate, Related Property, Files and Photos, Open Items'));
        data.pageRows.add(pageRow('Campaign', 'Campaign Summary, Campaign Member Work Queue, Voucher Readiness, Related Opportunities'));
        data.pageRows.add(pageRow('Quote / Payment', 'Quote Header, Quote Lines, Contract Status, Payment Milestones, Voucher Coverage, Open Items'));
        data.pageRows.add(pageRow('Work Order', 'Work Order Header, Status, Crew and Schedule, Line Items, Photos, Punch Items'));

        data.picklistRows.add(picklistRow('Opportunity', 'Type'));
        data.picklistRows.add(picklistRow('Opportunity', 'BMG_Package__c'));
        data.picklistRows.add(picklistRow('Campaign', 'Type'));
        data.picklistRows.add(picklistRow('Voucher__c', 'Status__c'));
        data.picklistRows.add(picklistRow('Payment_Milestone__c', 'Status__c'));
        data.picklistRows.add(picklistRow('Design_Review__c', 'Status__c'));
        data.picklistRows.add(picklistRow('Work_Order__c', 'Status__c'));
        data.picklistRows.add(picklistRow('Account', 'Contract_Status__c'));

        return data;
    }

    private static ObjectMatrixRow matrixRow(String objectApiName, List<String> standardFields, List<String> existingFields, List<String> customFields, String note) {
        Map<String, Schema.SObjectField> fieldsByApi = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        ObjectMatrixRow row = new ObjectMatrixRow();
        row.objectApiName = objectApiName;
        row.standardFirst = joinExisting(fieldsByApi, standardFields);
        row.existingReuse = joinExisting(fieldsByApi, existingFields);
        row.customOnlyIfNeeded = joinExisting(fieldsByApi, customFields);
        row.lobNote = note;
        return row;
    }

    private static PageInventoryRow pageRow(String page, String cards) {
        PageInventoryRow row = new PageInventoryRow();
        row.page = page;
        row.cards = cards;
        return row;
    }

    private static PicklistScopeRow picklistRow(String objectApiName, String fieldApiName) {
        PicklistScopeRow row = new PicklistScopeRow();
        row.objectApiName = objectApiName;
        row.fieldApiName = fieldApiName;
        Map<String, Schema.SObjectField> fieldsByApi = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        Schema.DescribeFieldResult describeResult = fieldsByApi.containsKey(fieldApiName) ? fieldsByApi.get(fieldApiName).getDescribe() : null;
        row.fieldLabel = describeResult != null ? describeResult.getLabel() : fieldApiName;
        List<String> values = new List<String>();
        if (describeResult != null) {
            for (Schema.PicklistEntry entry : describeResult.getPicklistValues()) {
                if (entry.isActive()) {
                    values.add(entry.getLabel());
                }
            }
        }
        row.values = values.isEmpty() ? 'No active values found' : String.join(values, ', ');
        return row;
    }

    private static String joinExisting(Map<String, Schema.SObjectField> fieldsByApi, List<String> candidates) {
        List<String> present = new List<String>();
        for (String candidate : candidates) {
            if (fieldsByApi.containsKey(candidate)) {
                present.add(candidate);
            }
        }
        return present.isEmpty() ? '—' : String.join(present, ', ');
    }
}