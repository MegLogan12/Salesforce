public without sharing class ODLHomeownerPropertyIdentityService {
    private static final Set<String> ODL_TYPES = new Set<String>{
        'UpgradeMyBackyard',
        'Design Build',
        'UMB'
    };
    private static final Set<String> ODL_LEAD_SOURCES = new Set<String>{
        'Lennar Voucher',
        'Web - Design Form',
        'Web - Consultation Form',
        'UMB Builder Pop Up',
        'Homebuilder Event',
        'Website'
    };
    private static final String REVIEW_SUBJECT = 'ODL Property Identity Review';

    public static void syncFromOpportunities(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        List<Opportunity> candidates = new List<Opportunity>();
        Set<Id> oppIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : newList) {
            if (!isOdlOpportunity(opp) || opp.AccountId == null) {
                continue;
            }
            candidates.add(opp);
            oppIds.add(opp.Id);
            accountIds.add(opp.AccountId);
        }
        if (candidates.isEmpty()) {
            return;
        }

        Map<Id, Id> opportunityContactIds = resolveOpportunityContactIds(oppIds, candidates);
        List<Homeowner_Property__c> existingProperties = [
            SELECT Id, Name, Homeowner_Account__c, Contact__c, Opportunity__c, Community__c, Lot__c
            FROM Homeowner_Property__c
            WHERE Opportunity__c IN :oppIds OR Homeowner_Account__c IN :accountIds
            ORDER BY LastModifiedDate DESC
        ];

        Map<Id, Homeowner_Property__c> propertyByOpportunity = new Map<Id, Homeowner_Property__c>();
        Map<Id, List<Homeowner_Property__c>> propertiesByAccount = new Map<Id, List<Homeowner_Property__c>>();
        for (Homeowner_Property__c propertyRow : existingProperties) {
            if (propertyRow.Opportunity__c != null && !propertyByOpportunity.containsKey(propertyRow.Opportunity__c)) {
                propertyByOpportunity.put(propertyRow.Opportunity__c, propertyRow);
            }
            if (propertyRow.Homeowner_Account__c != null) {
                if (!propertiesByAccount.containsKey(propertyRow.Homeowner_Account__c)) {
                    propertiesByAccount.put(propertyRow.Homeowner_Account__c, new List<Homeowner_Property__c>());
                }
                propertiesByAccount.get(propertyRow.Homeowner_Account__c).add(propertyRow);
            }
        }

        List<Homeowner_Property__c> inserts = new List<Homeowner_Property__c>();
        List<Homeowner_Property__c> updates = new List<Homeowner_Property__c>();
        Set<Id> ambiguousOpportunityIds = new Set<Id>();

        for (Opportunity opp : candidates) {
            Homeowner_Property__c target = propertyByOpportunity.get(opp.Id);
            if (target == null) {
                List<Homeowner_Property__c> accountProperties = propertiesByAccount.containsKey(opp.AccountId)
                    ? propertiesByAccount.get(opp.AccountId)
                    : new List<Homeowner_Property__c>();
                if (accountProperties.size() == 1 && accountProperties[0].Opportunity__c == null) {
                    target = accountProperties[0];
                } else if (!accountProperties.isEmpty()) {
                    ambiguousOpportunityIds.add(opp.Id);
                    continue;
                } else {
                    target = new Homeowner_Property__c(
                        Name = buildPropertyName(opp),
                        Homeowner_Account__c = opp.AccountId,
                        Opportunity__c = opp.Id
                    );
                    inserts.add(target);
                    if (!propertiesByAccount.containsKey(opp.AccountId)) {
                        propertiesByAccount.put(opp.AccountId, new List<Homeowner_Property__c>());
                    }
                    propertiesByAccount.get(opp.AccountId).add(target);
                }
            } else {
                updates.add(target);
            }

            target.Homeowner_Account__c = opp.AccountId;
            target.Opportunity__c = opp.Id;
            Id selectedContactId = opportunityContactIds.get(opp.Id);
            if (selectedContactId != null) {
                target.Contact__c = selectedContactId;
            }
            if (target.Lot__c == null && opp.Community__c != null) {
                target.Community__c = opp.Community__c;
            }
        }

        if (!inserts.isEmpty()) {
            insert inserts;
        }
        if (!updates.isEmpty()) {
            update updates;
        }
        if (!ambiguousOpportunityIds.isEmpty()) {
            createReviewTasks(ambiguousOpportunityIds);
        }
    }

    public static void hydrateProperties(List<Homeowner_Property__c> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }

        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> lotIds = new Set<Id>();
        for (Homeowner_Property__c row : rows) {
            if (row.Opportunity__c != null) {
                opportunityIds.add(row.Opportunity__c);
            }
            if (row.Lot__c != null) {
                lotIds.add(row.Lot__c);
            }
        }

        Map<Id, Opportunity> opportunityMap = opportunityIds.isEmpty()
            ? new Map<Id, Opportunity>()
            : new Map<Id, Opportunity>([
                SELECT Id, AccountId, ContactId, Community__c
                FROM Opportunity
                WHERE Id IN :opportunityIds
            ]);
        Map<Id, Id> opportunityContactIds = resolveOpportunityContactIds(opportunityIds, opportunityMap.values());
        Map<Id, Lot__c> lotMap = lotIds.isEmpty()
            ? new Map<Id, Lot__c>()
            : new Map<Id, Lot__c>([
                SELECT Id, Community__c
                FROM Lot__c
                WHERE Id IN :lotIds
            ]);

        for (Homeowner_Property__c row : rows) {
            Opportunity opp = row.Opportunity__c == null ? null : opportunityMap.get(row.Opportunity__c);
            if (opp != null) {
                if (row.Homeowner_Account__c == null && opp.AccountId != null) {
                    row.Homeowner_Account__c = opp.AccountId;
                }
                if (row.Contact__c == null && opportunityContactIds.containsKey(opp.Id)) {
                    row.Contact__c = opportunityContactIds.get(opp.Id);
                }
                if (row.Lot__c == null && row.Community__c == null && opp.Community__c != null) {
                    row.Community__c = opp.Community__c;
                }
            }

            if (row.Lot__c != null && lotMap.containsKey(row.Lot__c) && lotMap.get(row.Lot__c).Community__c != null) {
                row.Community__c = lotMap.get(row.Lot__c).Community__c;
            }
        }
    }

    @TestVisible
    private static Boolean isOdlOpportunity(Opportunity opp) {
        if (opp == null) {
            return false;
        }
        if (!String.isBlank(opp.Type) && ODL_TYPES.contains(opp.Type)) {
            return true;
        }
        if (!String.isBlank(opp.LeadSource) && ODL_LEAD_SOURCES.contains(opp.LeadSource)) {
            return true;
        }
        return !String.isBlank(opp.BMG_Package__c);
    }

    private static Map<Id, Id> resolveOpportunityContactIds(Set<Id> opportunityIds, List<Opportunity> opportunities) {
        Map<Id, Id> contactIdsByOpportunity = new Map<Id, Id>();
        if (opportunities != null) {
            for (Opportunity opp : opportunities) {
                if (opp != null && opp.Id != null && opp.ContactId != null) {
                    contactIdsByOpportunity.put(opp.Id, opp.ContactId);
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

    private static void createReviewTasks(Set<Id> opportunityIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return;
        }
        Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>([
            SELECT Id, Name, OwnerId
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]);
        Set<Id> existingTaskWhatIds = new Set<Id>();
        for (Task taskRow : [
            SELECT Id, WhatId
            FROM Task
            WHERE WhatId IN :opportunityIds
              AND Subject = :REVIEW_SUBJECT
              AND IsClosed = false
        ]) {
            existingTaskWhatIds.add(taskRow.WhatId);
        }

        List<Task> tasks = new List<Task>();
        for (Id opportunityId : opportunityIds) {
            if (existingTaskWhatIds.contains(opportunityId) || !opportunityMap.containsKey(opportunityId)) {
                continue;
            }
            Opportunity opp = opportunityMap.get(opportunityId);
            tasks.add(new Task(
                Subject = REVIEW_SUBJECT,
                Status = 'Not Started',
                Priority = 'Normal',
                WhatId = opportunityId,
                OwnerId = opp.OwnerId,
                Description = 'ODL property identity automation found an ambiguous existing Homeowner Property match. Review Contact, Lot, and Community before voucher use.'
            ));
        }
        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }

    private static String buildPropertyName(Opportunity opp) {
        String baseName = 'ODL Property - ' + (opp == null || String.isBlank(opp.Name) ? 'Opportunity' : opp.Name);
        return baseName.length() > 80 ? baseName.substring(0, 80) : baseName;
    }
}