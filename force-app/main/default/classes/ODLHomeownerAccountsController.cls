public with sharing class ODLHomeownerAccountsController {
    private static final Integer ROW_LIMIT = 75;

    public class WorkspaceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String householdName;
        @AuraEnabled public String primaryEmail;
        @AuraEnabled public String phone;
        @AuraEnabled public String relationshipStatus;
        @AuraEnabled public String propertyLabel;
        @AuraEnabled public String propertyUrl;
        @AuraEnabled public String lastActivityDate;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Integer openOpportunities;
        @AuraEnabled public Integer activeWorkOrders;
        @AuraEnabled public Integer vouchers;
        @AuraEnabled public String filterBucket;
    }

    public class WorkspaceData {
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public Integer totalHouseholds;
        @AuraEnabled public Integer activeProjectHouseholds;
        @AuraEnabled public Integer voucherLinkedHouseholds;
        @AuraEnabled public Integer fieldExecutionHouseholds;
        @AuraEnabled public String latestAccountUrl;
        @AuraEnabled public List<WorkspaceRow> rows;
    }

    @AuraEnabled(cacheable=true)
    public static WorkspaceData getWorkspaceData() {
        WorkspaceData data = new WorkspaceData();
        data.title = 'Homeowner Account List';
        data.subtitle = 'Outdoor Living homeowner households only. Open projects, vouchers, work orders, and last activity pull from live Salesforce data.';
        data.rows = new List<WorkspaceRow>();
        data.totalHouseholds = 0;
        data.activeProjectHouseholds = 0;
        data.voucherLinkedHouseholds = 0;
        data.fieldExecutionHouseholds = 0;

        Set<Id> opportunityAccountIds = odlOpportunityAccountIds();
        Set<Id> accountIds = new Set<Id>();

        List<Account> accounts = [
            SELECT Id, Name, Type, IsPersonAccount, Owner.Name, Phone, PersonMobilePhone, PersonEmail,
                   LastActivityDate, LastModifiedDate, ODL_Household_Display_Name__c
            FROM Account
            WHERE IsDeleted = false
            AND (
                Type = 'Home Owner'
                OR IsPersonAccount = true
                OR Id IN :opportunityAccountIds
            )
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ];

        for (Account row : accounts) {
            accountIds.add(row.Id);
        }
        if (accountIds.isEmpty()) {
            return data;
        }

        Map<Id, Integer> openOppCounts = aggregateCounts([
            SELECT AccountId accountId, COUNT(Id) totalCount
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND IsClosed = false
            AND (
                Type IN ('UMB', 'UpgradeMyBackyard', 'Custom Build', 'Design Build', 'Lawn Care')
                OR RecordType.DeveloperName IN ('UMB', 'Design_Build')
            )
            GROUP BY AccountId
        ]);

        Map<Id, Integer> workOrderCounts = aggregateCounts([
            SELECT AccountId accountId, COUNT(Id) totalCount
            FROM WorkOrder
            WHERE AccountId IN :accountIds
            AND Status NOT IN ('Closed', 'Canceled', 'Cancelled', 'Complete', 'Completed')
            GROUP BY AccountId
        ]);

        Map<Id, Integer> voucherCounts = new Map<Id, Integer>();
        for (Voucher__c voucherRow : [
            SELECT Id, Contact__r.AccountId, Reserved_Opportunity__r.AccountId
            FROM Voucher__c
            WHERE Contact__r.AccountId IN :accountIds
               OR Reserved_Opportunity__r.AccountId IN :accountIds
        ]) {
            Id accountId = voucherRow.Contact__r != null ? voucherRow.Contact__r.AccountId : null;
            if (accountId == null && voucherRow.Reserved_Opportunity__r != null) {
                accountId = voucherRow.Reserved_Opportunity__r.AccountId;
            }
            if (accountId == null) {
                continue;
            }
            voucherCounts.put(accountId, (voucherCounts.containsKey(accountId) ? voucherCounts.get(accountId) : 0) + 1);
        }

        Map<Id, Homeowner_Property__c> propertyByAccount = new Map<Id, Homeowner_Property__c>();
        for (Homeowner_Property__c row : [
            SELECT Id, Name, Homeowner_Account__c
            FROM Homeowner_Property__c
            WHERE Homeowner_Account__c IN :accountIds
            ORDER BY LastModifiedDate DESC
        ]) {
            if (!propertyByAccount.containsKey(row.Homeowner_Account__c)) {
                propertyByAccount.put(row.Homeowner_Account__c, row);
            }
        }

        for (Account row : accounts) {
            WorkspaceRow out = new WorkspaceRow();
            out.id = row.Id;
            out.url = '/' + row.Id;
            out.householdName = firstNonBlank(new List<String>{
                (String) row.get('ODL_Household_Display_Name__c'),
                row.Name
            });
            out.primaryEmail = row.PersonEmail;
            out.phone = firstNonBlank(new List<String>{ row.PersonMobilePhone, row.Phone });
            out.ownerName = row.Owner != null ? row.Owner.Name : null;
            out.lastActivityDate = row.LastActivityDate == null ? 'No activity' : String.valueOf(row.LastActivityDate);
            out.openOpportunities = safeCount(openOppCounts, row.Id);
            out.activeWorkOrders = safeCount(workOrderCounts, row.Id);
            out.vouchers = safeCount(voucherCounts, row.Id);

            Homeowner_Property__c propertyRow = propertyByAccount.get(row.Id);
            out.propertyLabel = propertyRow == null ? null : propertyRow.Name;
            out.propertyUrl = propertyRow == null ? null : '/' + propertyRow.Id;
            out.relationshipStatus = deriveRelationshipStatus(out);
            out.filterBucket = deriveFilterBucket(out);

            data.rows.add(out);
            data.totalHouseholds++;
            if (String.isBlank(data.latestAccountUrl)) {
                data.latestAccountUrl = out.url;
            }
            if (out.openOpportunities > 0) {
                data.activeProjectHouseholds++;
            }
            if (out.vouchers > 0) {
                data.voucherLinkedHouseholds++;
            }
            if (out.activeWorkOrders > 0) {
                data.fieldExecutionHouseholds++;
            }
        }

        return data;
    }

    private static Set<Id> odlOpportunityAccountIds() {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity row : [
            SELECT AccountId, Type, RecordType.DeveloperName
            FROM Opportunity
            WHERE IsClosed = false
            AND AccountId != null
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ]) {
            if (!String.isBlank(laneForOpportunity(row))) {
                accountIds.add(row.AccountId);
            }
        }
        return accountIds;
    }

    private static String laneForOpportunity(Opportunity row) {
        String recordTypeName = row.RecordType != null ? row.RecordType.DeveloperName : null;
        if (recordTypeName == 'UMB' || row.Type == 'UMB' || row.Type == 'UpgradeMyBackyard') {
            return 'UMB';
        }
        if (recordTypeName == 'Design_Build' || row.Type == 'Design Build' || row.Type == 'Custom Build') {
            return 'Custom Build';
        }
        if (row.Type == 'Lawn Care') {
            return 'Lawn Care';
        }
        return null;
    }

    private static Map<Id, Integer> aggregateCounts(List<AggregateResult> rows) {
        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (AggregateResult row : rows) {
            Id accountId = (Id) row.get('accountId');
            counts.put(accountId, (Integer) row.get('totalCount'));
        }
        return counts;
    }

    private static Integer safeCount(Map<Id, Integer> counts, Id accountId) {
        return counts.containsKey(accountId) ? counts.get(accountId) : 0;
    }

    private static String deriveRelationshipStatus(WorkspaceRow row) {
        if (row.activeWorkOrders > 0) {
            return 'Field Execution';
        }
        if (row.openOpportunities > 0) {
            return 'Active Project';
        }
        if (row.vouchers > 0) {
            return 'Voucher Linked';
        }
        return 'Homeowner';
    }

    private static String deriveFilterBucket(WorkspaceRow row) {
        if (row.activeWorkOrders > 0) {
            return 'Field Execution';
        }
        if (row.openOpportunities > 0) {
            return 'Active Project';
        }
        if (row.vouchers > 0) {
            return 'Voucher Linked';
        }
        return 'All Homeowners';
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