public with sharing class ODLHouseholdService {
    private static final Set<String> SCOPED_LEAD_SOURCES = new Set<String>{
        'Lennar Voucher',
        'Site',
        'Web - Design Form',
        'Web - Consultation Form',
        'Website'
    };

    public static Id getUmbOpportunityRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> infoByName = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();
        Schema.RecordTypeInfo info = infoByName.get('UMB');
        return info != null ? info.getRecordTypeId() : null;
    }

    public static String buildHouseholdDisplayName(String lastName) {
        if (String.isBlank(lastName)) {
            return null;
        }
        return lastName.trim() + ' Household';
    }

    public static void applyHouseholdFields(Account accountRow, String lastName) {
        if (accountRow == null) {
            return;
        }
        String displayName = buildHouseholdDisplayName(lastName);
        if (!String.isBlank(displayName)) {
            accountRow.ODL_Household_Display_Name__c = displayName;
        }
    }

    public static Id preferredHouseholdContactId(Account accountRow) {
        if (accountRow == null) {
            return null;
        }
        if (accountRow.PersonContactId != null) {
            return accountRow.PersonContactId;
        }
        return (Id) accountRow.get('ODL_Secondary_Contact__c');
    }

    public static void enforceScopedOpportunityUniqueness(List<Opportunity> newRows) {
        if (newRows == null || newRows.isEmpty()) {
            return;
        }

        Id umbRecordTypeId = getUmbOpportunityRecordTypeId();
        Set<Id> accountIds = new Set<Id>();
        List<Opportunity> scopedRows = new List<Opportunity>();
        for (Opportunity opp : newRows) {
            if (isScopedHouseholdOpportunity(opp, umbRecordTypeId) && opp.AccountId != null) {
                scopedRows.add(opp);
                accountIds.add(opp.AccountId);
            }
        }
        if (scopedRows.isEmpty()) {
            return;
        }

        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, Name, ODL_Household_Display_Name__c, BillingStreet, BillingCity, BillingState, BillingPostalCode
            FROM Account
            WHERE Id IN :accountIds
        ]);

        Map<Id, HouseholdSeed> seedByAccountId = new Map<Id, HouseholdSeed>();
        Set<String> postalCodes = new Set<String>();
        for (Opportunity opp : scopedRows) {
            Account acct = accountsById.get(opp.AccountId);
            HouseholdSeed seed = new HouseholdSeed(opp, acct);
            seedByAccountId.put(opp.AccountId, seed);
            if (!String.isBlank(seed.postalCode)) {
                postalCodes.add(seed.postalCode);
            }
        }

        List<Opportunity> existingOpps = [
            SELECT Id, Name, AccountId, Type, LeadSource, RecordTypeId, IsClosed,
                   Account.Name, Account.ODL_Household_Display_Name__c,
                   Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode
            FROM Opportunity
            WHERE IsClosed = false
            AND (
                AccountId IN :accountIds
                OR Account.BillingPostalCode IN :postalCodes
            )
        ];

        Map<Id, Opportunity> firstExistingByAccountId = new Map<Id, Opportunity>();
        Map<String, Opportunity> firstExistingByHouseholdKey = new Map<String, Opportunity>();
        for (Opportunity existing : existingOpps) {
            if (!isScopedHouseholdOpportunity(existing, umbRecordTypeId)) {
                continue;
            }
            if (!firstExistingByAccountId.containsKey(existing.AccountId)) {
                firstExistingByAccountId.put(existing.AccountId, existing);
            }
            String key = buildHouseholdKey(existing.Account);
            if (!String.isBlank(key) && !firstExistingByHouseholdKey.containsKey(key)) {
                firstExistingByHouseholdKey.put(key, existing);
            }
        }

        Set<String> seenPendingKeys = new Set<String>();
        Set<Id> seenPendingAccounts = new Set<Id>();
        for (Opportunity opp : scopedRows) {
            HouseholdSeed seed = seedByAccountId.get(opp.AccountId);
            Opportunity accountDuplicate = firstExistingByAccountId.get(opp.AccountId);
            if (accountDuplicate != null) {
                opp.addError(buildDuplicateMessage(accountDuplicate));
                continue;
            }

            if (!String.isBlank(seed.householdKey)) {
                Opportunity householdDuplicate = firstExistingByHouseholdKey.get(seed.householdKey);
                if (householdDuplicate != null) {
                    opp.addError(buildDuplicateMessage(householdDuplicate));
                    continue;
                }
                if (!seenPendingKeys.add(seed.householdKey)) {
                    opp.addError('Another active ODL household opportunity for this same household is being created in the current transaction. Create or keep only one active UMB household opportunity.');
                    continue;
                }
            }

            if (!seenPendingAccounts.add(opp.AccountId)) {
                opp.addError('Another active ODL household opportunity for this account is being created in the current transaction. Create or keep only one active UMB household opportunity.');
            }
        }
    }

    private static Boolean isScopedHouseholdOpportunity(Opportunity opp, Id umbRecordTypeId) {
        if (opp == null) {
            return false;
        }
        if (umbRecordTypeId != null && opp.RecordTypeId == umbRecordTypeId) {
            return true;
        }
        if (opp.Type == 'UMB') {
            return true;
        }
        return !String.isBlank(opp.LeadSource) && SCOPED_LEAD_SOURCES.contains(opp.LeadSource);
    }

    private static String buildDuplicateMessage(Opportunity existingOpp) {
        return 'An active ODL household opportunity already exists for this household: '
            + existingOpp.Name
            + '. Open the existing opportunity instead of creating a duplicate.';
    }

    private static String buildHouseholdKey(Account accountRow) {
        if (accountRow == null) {
            return null;
        }
        String householdName = firstNonBlank(new List<String>{
            accountRow.ODL_Household_Display_Name__c,
            accountRow.Name
        });
        String surname = extractHouseholdSurname(householdName);
        String street = normalize(accountRow.BillingStreet);
        String postalCode = normalize(accountRow.BillingPostalCode);
        if (String.isBlank(surname) || String.isBlank(street) || String.isBlank(postalCode)) {
            return null;
        }
        return surname + '|' + street + '|' + postalCode;
    }

    private static String extractHouseholdSurname(String source) {
        if (String.isBlank(source)) {
            return null;
        }
        String value = source.trim().toLowerCase();
        if (value.endsWith(' household')) {
            value = value.substring(0, value.length() - ' household'.length()).trim();
        }
        List<String> tokens = value.split('\\s+');
        if (tokens.isEmpty()) {
            return null;
        }
        return normalize(tokens[tokens.size() - 1]);
    }

    private static String normalize(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        return value.toLowerCase().replaceAll('[^a-z0-9]', '');
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private class HouseholdSeed {
        String householdKey;
        String postalCode;

        HouseholdSeed(Opportunity opp, Account accountRow) {
            this.householdKey = buildHouseholdKey(accountRow);
            this.postalCode = normalize(accountRow != null ? accountRow.BillingPostalCode : null);
        }
    }
}