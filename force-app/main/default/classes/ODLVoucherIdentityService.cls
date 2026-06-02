public without sharing class ODLVoucherIdentityService {
    @TestVisible private static final Set<String> CLAIM_READY_STATUSES = new Set<String>{
        'Validated',
        'Reserved',
        'Applied to Quote',
        'Contract Signed',
        'Deposit Paid',
        'Builder Invoice Pending',
        'Builder Invoiced',
        'Paid by Builder',
        'Redeemed'
    };
    @TestVisible private static final Set<String> LOT_CONFLICT_STATUSES = new Set<String>{
        'Draft',
        'Active',
        'Submitted',
        'Validated',
        'Reserved',
        'Applied to Quote',
        'Contract Signed',
        'Deposit Paid',
        'Builder Invoice Pending',
        'Builder Invoiced',
        'Paid by Builder',
        'Redeemed'
    };
    private static final Set<String> STANDARD_VALUE_TYPES = new Set<String>{
        'Standard Grilling Island',
        'Deluxe Grilling Island Upgrade'
    };
    private static final String STANDARD_GRILL_NAME = 'Standard Grilling Island';
    private static final String UMB_PRICEBOOK_NAME = 'Upgrade My Backyard Price Book';

    @TestVisible private static Decimal cachedStandardGrillValue;
    @TestVisible private static Boolean standardGrillValueLoaded = false;

    private class ContextData {
        Map<Id, Opportunity> opportunities = new Map<Id, Opportunity>();
        Map<Id, Id> opportunityContactIds = new Map<Id, Id>();
        Map<Id, Lead> leads = new Map<Id, Lead>();
        Map<Id, Campaign> campaigns = new Map<Id, Campaign>();
        Map<Id, Homeowner_Property__c> propertiesById = new Map<Id, Homeowner_Property__c>();
        Map<Id, Homeowner_Property__c> propertyByOpportunity = new Map<Id, Homeowner_Property__c>();
        Map<Id, List<Homeowner_Property__c>> propertiesByContact = new Map<Id, List<Homeowner_Property__c>>();
        Map<Id, List<Homeowner_Property__c>> propertiesByAccount = new Map<Id, List<Homeowner_Property__c>>();
        Map<Id, Lot__c> lots = new Map<Id, Lot__c>();
        Map<Id, Community__c> communities = new Map<Id, Community__c>();
    }

    public static void hydrateAndValidate(List<Voucher__c> rows, Map<Id, Voucher__c> oldMap) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        List<Voucher__c> rowsNeedingHydration = new List<Voucher__c>();
        for (Voucher__c row : rows) {
            if (needsHydration(row)) {
                rowsNeedingHydration.add(row);
            }
        }
        ContextData context = rowsNeedingHydration.isEmpty() ? new ContextData() : loadContext(rowsNeedingHydration);
        for (Voucher__c row : rows) {
            if (needsHydration(row)) {
                hydrateRow(row, context);
            }
            validateIdentity(row);
        }
        enforceLotUniqueness(rows, oldMap);
    }

    public static void hydrateForService(Voucher__c row) {
        if (row == null) {
            return;
        }
        if (!needsHydration(row)) {
            return;
        }
        ContextData context = loadContext(new List<Voucher__c>{ row });
        hydrateRow(row, context);
    }

    private static void hydrateRow(Voucher__c row, ContextData context) {
        Id contactId = deriveContactId(row, context);
        if (row.Contact__c == null && contactId != null) {
            row.Contact__c = contactId;
        }

        Id accountId = deriveAccountId(row, context);
        Homeowner_Property__c propertyRow = resolveProperty(row, accountId, contactId, context);
        if (row.Homeowner_Property__c == null && propertyRow != null) {
            row.Homeowner_Property__c = propertyRow.Id;
        }
        if (row.Lot__c == null && propertyRow != null && propertyRow.Lot__c != null) {
            row.Lot__c = propertyRow.Lot__c;
        }
        if (row.Community__c == null && propertyRow != null && propertyRow.Community__c != null) {
            row.Community__c = propertyRow.Community__c;
        }

        if (row.Lot__c != null && context.lots.containsKey(row.Lot__c) && context.lots.get(row.Lot__c).Community__c != null) {
            row.Community__c = context.lots.get(row.Lot__c).Community__c;
        }

        Opportunity opportunityRow = row.Reserved_Opportunity__c == null ? null : context.opportunities.get(row.Reserved_Opportunity__c);
        if (row.Community__c == null && opportunityRow != null && opportunityRow.Community__c != null) {
            row.Community__c = opportunityRow.Community__c;
        }

        Campaign campaignRow = row.Campaign__c == null ? null : context.campaigns.get(row.Campaign__c);
        Community__c communityRow = row.Community__c == null ? null : context.communities.get(row.Community__c);
        if (row.Builder_Account__c == null) {
            if (communityRow != null && communityRow.Builder_Account__c != null) {
                row.Builder_Account__c = communityRow.Builder_Account__c;
            } else if (campaignRow != null && campaignRow.Builder_Account__c != null) {
                row.Builder_Account__c = campaignRow.Builder_Account__c;
            }
        }

        if (shouldUseStandardFaceValue(row) && row.Voucher_Face_Value__c == null) {
            Decimal standardValue = getStandardGrillValue();
            if (standardValue != null) {
                row.Voucher_Face_Value__c = standardValue;
            }
        }
    }

    private static void validateIdentity(Voucher__c row) {
        if (!requiresClaimIdentity(row)) {
            return;
        }
        if (row.Homeowner_Property__c == null) {
            row.addError('A Homeowner Property must be linked before this voucher can advance to ' + row.Status__c + '.');
        }
        if (row.Lot__c == null) {
            row.addError('A Lot must be linked before this voucher can advance to ' + row.Status__c + '.');
        }
        if (row.Community__c == null) {
            row.addError('A Community must be linked before this voucher can advance to ' + row.Status__c + '.');
        }
        if (shouldUseStandardFaceValue(row) && row.Voucher_Face_Value__c == null) {
            row.addError('Voucher_Face_Value__c could not be populated from the Standard Grilling Island price source.');
        }
    }

    private static void enforceLotUniqueness(List<Voucher__c> rows, Map<Id, Voucher__c> oldMap) {
        Set<Id> lotIds = new Set<Id>();
        Map<Id, Integer> incomingByLot = new Map<Id, Integer>();
        for (Voucher__c row : rows) {
            if (!shouldCheckLotConflict(row, oldMap == null ? null : oldMap.get(row.Id))) {
                continue;
            }
            lotIds.add(row.Lot__c);
            incomingByLot.put(row.Lot__c, (incomingByLot.containsKey(row.Lot__c) ? incomingByLot.get(row.Lot__c) : 0) + 1);
        }
        if (lotIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> existingByLot = new Map<Id, Integer>();
        for (Voucher__c existingRow : [
            SELECT Id, Lot__c, Status__c
            FROM Voucher__c
            WHERE Lot__c IN :lotIds
              AND Voucher_Type__c = :STANDARD_GRILL_NAME
              AND Status__c IN :LOT_CONFLICT_STATUSES
        ]) {
            existingByLot.put(existingRow.Lot__c, (existingByLot.containsKey(existingRow.Lot__c) ? existingByLot.get(existingRow.Lot__c) : 0) + 1);
        }

        for (Voucher__c row : rows) {
            Voucher__c oldRow = oldMap == null ? null : oldMap.get(row.Id);
            if (!shouldCheckLotConflict(row, oldRow)) {
                continue;
            }
            Integer existingCount = existingByLot.containsKey(row.Lot__c) ? existingByLot.get(row.Lot__c) : 0;
            if (oldRow != null && oldRow.Lot__c == row.Lot__c && LOT_CONFLICT_STATUSES.contains(oldRow.Status__c) && shouldUseStandardFaceValue(oldRow)) {
                existingCount = Math.max(0, existingCount - 1);
            }
            Integer incomingCount = incomingByLot.containsKey(row.Lot__c) ? incomingByLot.get(row.Lot__c) : 0;
            if (existingCount > 0 || incomingCount > 1) {
                row.addError('A duplicate Lennar grilling island voucher already exists for this Lot. Only one active voucher per lot is allowed.');
            }
        }
    }

    private static Boolean shouldCheckLotConflict(Voucher__c row, Voucher__c oldRow) {
        if (row == null || row.Lot__c == null || !shouldUseStandardFaceValue(row) || !LOT_CONFLICT_STATUSES.contains(row.Status__c)) {
            return false;
        }
        if (oldRow == null) {
            return true;
        }
        return oldRow.Lot__c != row.Lot__c
            || oldRow.Status__c != row.Status__c
            || oldRow.Voucher_Type__c != row.Voucher_Type__c
            || oldRow.Voucher_Entitlement__c != row.Voucher_Entitlement__c;
    }

    private static Boolean requiresClaimIdentity(Voucher__c row) {
        return row != null && row.Status__c != null && CLAIM_READY_STATUSES.contains(row.Status__c);
    }

    private static Boolean shouldUseStandardFaceValue(Voucher__c row) {
        if (row == null) {
            return false;
        }
        if (!String.isBlank(row.Voucher_Entitlement__c) && row.Voucher_Entitlement__c == STANDARD_GRILL_NAME) {
            return true;
        }
        return !String.isBlank(row.Voucher_Type__c) && STANDARD_VALUE_TYPES.contains(row.Voucher_Type__c);
    }

    private static Boolean needsHydration(Voucher__c row) {
        if (row == null) {
            return false;
        }
        if (row.Contact__c == null && (row.Reserved_Opportunity__c != null || row.Homeowner_Lead__c != null)) {
            return true;
        }
        if (row.Homeowner_Property__c == null && (row.Reserved_Opportunity__c != null || row.Contact__c != null || row.Homeowner_Lead__c != null)) {
            return true;
        }
        if (row.Lot__c == null && (row.Homeowner_Property__c != null || row.Reserved_Opportunity__c != null || row.Contact__c != null || row.Homeowner_Lead__c != null)) {
            return true;
        }
        if (row.Community__c == null && (row.Lot__c != null || row.Homeowner_Property__c != null || row.Reserved_Opportunity__c != null)) {
            return true;
        }
        if (row.Builder_Account__c == null && (row.Community__c != null || row.Campaign__c != null)) {
            return true;
        }
        return shouldUseStandardFaceValue(row) && row.Voucher_Face_Value__c == null;
    }

    private static Id deriveContactId(Voucher__c row, ContextData context) {
        if (row.Contact__c != null) {
            return row.Contact__c;
        }
        if (row.Reserved_Opportunity__c != null && context.opportunityContactIds.containsKey(row.Reserved_Opportunity__c)) {
            return context.opportunityContactIds.get(row.Reserved_Opportunity__c);
        }
        if (row.Homeowner_Lead__c != null && context.leads.containsKey(row.Homeowner_Lead__c)) {
            return context.leads.get(row.Homeowner_Lead__c).ConvertedContactId;
        }
        return null;
    }

    private static Id deriveAccountId(Voucher__c row, ContextData context) {
        if (row.Reserved_Opportunity__c != null && context.opportunities.containsKey(row.Reserved_Opportunity__c)) {
            return context.opportunities.get(row.Reserved_Opportunity__c).AccountId;
        }
        if (row.Homeowner_Lead__c != null && context.leads.containsKey(row.Homeowner_Lead__c)) {
            return context.leads.get(row.Homeowner_Lead__c).ConvertedAccountId;
        }
        return null;
    }

    private static Homeowner_Property__c resolveProperty(Voucher__c row, Id accountId, Id contactId, ContextData context) {
        if (row.Homeowner_Property__c != null && context.propertiesById.containsKey(row.Homeowner_Property__c)) {
            return context.propertiesById.get(row.Homeowner_Property__c);
        }
        if (row.Reserved_Opportunity__c != null && context.propertyByOpportunity.containsKey(row.Reserved_Opportunity__c)) {
            return context.propertyByOpportunity.get(row.Reserved_Opportunity__c);
        }

        Homeowner_Property__c match = chooseProperty(contactId == null ? null : context.propertiesByContact.get(contactId), row.Lot__c);
        if (match != null) {
            return match;
        }
        return chooseProperty(accountId == null ? null : context.propertiesByAccount.get(accountId), row.Lot__c);
    }

    private static Homeowner_Property__c chooseProperty(List<Homeowner_Property__c> rows, Id lotId) {
        if (rows == null || rows.isEmpty()) {
            return null;
        }
        if (lotId != null) {
            List<Homeowner_Property__c> lotMatches = new List<Homeowner_Property__c>();
            for (Homeowner_Property__c row : rows) {
                if (row.Lot__c == lotId) {
                    lotMatches.add(row);
                }
            }
            if (lotMatches.size() == 1) {
                return lotMatches[0];
            }
            if (!lotMatches.isEmpty()) {
                return null;
            }
        }
        return rows.size() == 1 ? rows[0] : null;
    }

    private static ContextData loadContext(List<Voucher__c> rows) {
        ContextData context = new ContextData();
        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> leadIds = new Set<Id>();
        Set<Id> directContactIds = new Set<Id>();
        Set<Id> directPropertyIds = new Set<Id>();
        Set<Id> directLotIds = new Set<Id>();
        Set<Id> directCommunityIds = new Set<Id>();
        Set<Id> campaignIds = new Set<Id>();

        for (Voucher__c row : rows) {
            if (row.Reserved_Opportunity__c != null) opportunityIds.add(row.Reserved_Opportunity__c);
            if (row.Homeowner_Lead__c != null) leadIds.add(row.Homeowner_Lead__c);
            if (row.Contact__c != null) directContactIds.add(row.Contact__c);
            if (row.Homeowner_Property__c != null) directPropertyIds.add(row.Homeowner_Property__c);
            if (row.Lot__c != null) directLotIds.add(row.Lot__c);
            if (row.Community__c != null) directCommunityIds.add(row.Community__c);
            if (row.Campaign__c != null) campaignIds.add(row.Campaign__c);
        }

        if (!opportunityIds.isEmpty()) {
            context.opportunities = new Map<Id, Opportunity>([
                SELECT Id, AccountId, ContactId, Community__c, Account.IsPersonAccount, Account.PersonContactId
                FROM Opportunity
                WHERE Id IN :opportunityIds
            ]);
            context.opportunityContactIds = resolveOpportunityContactIds(opportunityIds, context.opportunities.values());
        }
        if (!leadIds.isEmpty()) {
            context.leads = new Map<Id, Lead>([
                SELECT Id, ConvertedAccountId, ConvertedContactId
                FROM Lead
                WHERE Id IN :leadIds
            ]);
        }
        if (!campaignIds.isEmpty()) {
            context.campaigns = new Map<Id, Campaign>([
                SELECT Id, Builder_Account__c
                FROM Campaign
                WHERE Id IN :campaignIds
            ]);
        }

        Set<Id> contactIds = new Set<Id>();
        contactIds.addAll(directContactIds);
        contactIds.addAll(context.opportunityContactIds.values());
        for (Lead leadRow : context.leads.values()) {
            if (leadRow.ConvertedContactId != null) {
                contactIds.add(leadRow.ConvertedContactId);
            }
        }

        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opportunityRow : context.opportunities.values()) {
            if (opportunityRow.AccountId != null) {
                accountIds.add(opportunityRow.AccountId);
            }
            if (opportunityRow.Community__c != null) {
                directCommunityIds.add(opportunityRow.Community__c);
            }
        }
        for (Lead leadRow : context.leads.values()) {
            if (leadRow.ConvertedAccountId != null) {
                accountIds.add(leadRow.ConvertedAccountId);
            }
        }

        if (!directPropertyIds.isEmpty() || !opportunityIds.isEmpty() || !contactIds.isEmpty() || !accountIds.isEmpty()) {
            for (Homeowner_Property__c propertyRow : [
                SELECT Id, Name, Homeowner_Account__c, Contact__c, Opportunity__c, Lot__c, Community__c
                FROM Homeowner_Property__c
                WHERE Id IN :directPropertyIds
                   OR Opportunity__c IN :opportunityIds
                   OR Contact__c IN :contactIds
                   OR Homeowner_Account__c IN :accountIds
                ORDER BY LastModifiedDate DESC
            ]) {
                context.propertiesById.put(propertyRow.Id, propertyRow);
                if (propertyRow.Opportunity__c != null && !context.propertyByOpportunity.containsKey(propertyRow.Opportunity__c)) {
                    context.propertyByOpportunity.put(propertyRow.Opportunity__c, propertyRow);
                }
                if (propertyRow.Contact__c != null) {
                    if (!context.propertiesByContact.containsKey(propertyRow.Contact__c)) {
                        context.propertiesByContact.put(propertyRow.Contact__c, new List<Homeowner_Property__c>());
                    }
                    context.propertiesByContact.get(propertyRow.Contact__c).add(propertyRow);
                }
                if (propertyRow.Homeowner_Account__c != null) {
                    if (!context.propertiesByAccount.containsKey(propertyRow.Homeowner_Account__c)) {
                        context.propertiesByAccount.put(propertyRow.Homeowner_Account__c, new List<Homeowner_Property__c>());
                    }
                    context.propertiesByAccount.get(propertyRow.Homeowner_Account__c).add(propertyRow);
                }
                if (propertyRow.Lot__c != null) {
                    directLotIds.add(propertyRow.Lot__c);
                }
                if (propertyRow.Community__c != null) {
                    directCommunityIds.add(propertyRow.Community__c);
                }
            }
        }

        if (!directLotIds.isEmpty()) {
            context.lots = new Map<Id, Lot__c>([
                SELECT Id, Community__c
                FROM Lot__c
                WHERE Id IN :directLotIds
            ]);
            for (Lot__c lotRow : context.lots.values()) {
                if (lotRow.Community__c != null) {
                    directCommunityIds.add(lotRow.Community__c);
                }
            }
        }

        if (!directCommunityIds.isEmpty()) {
            context.communities = new Map<Id, Community__c>([
                SELECT Id, Builder_Account__c
                FROM Community__c
                WHERE Id IN :directCommunityIds
            ]);
        }
        return context;
    }

    private static Map<Id, Id> resolveOpportunityContactIds(Set<Id> opportunityIds, List<Opportunity> opportunities) {
        Map<Id, Id> contactIdsByOpportunity = new Map<Id, Id>();
        if (opportunities != null) {
            for (Opportunity opp : opportunities) {
                if (opp == null || opp.Id == null) {
                    continue;
                }
                if (opp.ContactId != null) {
                    contactIdsByOpportunity.put(opp.Id, opp.ContactId);
                } else if (opp.Account != null && opp.Account.IsPersonAccount && opp.Account.PersonContactId != null) {
                    contactIdsByOpportunity.put(opp.Id, opp.Account.PersonContactId);
                }
            }
        }
        Set<Id> remainingIds = new Set<Id>();
        if (opportunityIds != null) {
            remainingIds.addAll(opportunityIds);
            remainingIds.removeAll(contactIdsByOpportunity.keySet());
        }
        if (!remainingIds.isEmpty()) {
            for (OpportunityContactRole roleRow : [
                SELECT OpportunityId, ContactId, IsPrimary
                FROM OpportunityContactRole
                WHERE OpportunityId IN :remainingIds
                ORDER BY IsPrimary DESC, CreatedDate ASC
            ]) {
                if (!contactIdsByOpportunity.containsKey(roleRow.OpportunityId) && roleRow.ContactId != null) {
                    contactIdsByOpportunity.put(roleRow.OpportunityId, roleRow.ContactId);
                }
            }
        }
        return contactIdsByOpportunity;
    }

    @TestVisible
    private static Decimal getStandardGrillValue() {
        if (standardGrillValueLoaded) {
            return cachedStandardGrillValue;
        }
        standardGrillValueLoaded = true;

        List<PricebookEntry> preferredRows = [
            SELECT UnitPrice
            FROM PricebookEntry
            WHERE Product2.Name = :STANDARD_GRILL_NAME
              AND Pricebook2.Name = :UMB_PRICEBOOK_NAME
              AND IsActive = true
              AND Pricebook2.IsActive = true
            LIMIT 1
        ];
        if (!preferredRows.isEmpty()) {
            cachedStandardGrillValue = preferredRows[0].UnitPrice;
            return cachedStandardGrillValue;
        }

        List<PricebookEntry> fallbackRows = [
            SELECT UnitPrice
            FROM PricebookEntry
            WHERE Product2.Name = :STANDARD_GRILL_NAME
              AND IsActive = true
            LIMIT 1
        ];
        cachedStandardGrillValue = fallbackRows.isEmpty() ? null : fallbackRows[0].UnitPrice;
        return cachedStandardGrillValue;
    }
}