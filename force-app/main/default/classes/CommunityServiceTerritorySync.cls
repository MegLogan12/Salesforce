/**
 * CommunityServiceTerritorySync
 * FSL Bridge — Phase FSL-3
 *
 * Links Community__c records to FSL ServiceTerritory via Community__c.ServiceTerritory__c.
 * Matches on Community__c.Service_Territory_Name__c (text) → ServiceTerritory.Name.
 * Falls back to Community__c.Division__c if Service_Territory_Name__c is blank.
 *
 * Does NOT delete or modify Community__c or ServiceTerritory records.
 *
 * Usage (run once after deploy):
 *   CommunityServiceTerritorySync.syncAll();
 */
public with sharing class CommunityServiceTerritorySync {

    public static void syncAll() {
        List<Community__c> communities = [
            SELECT Id, Name, Service_Territory_Name__c, ServiceTerritory__c,
                   Loving_Operating_Division__c
            FROM Community__c
            WHERE Aqua_Active__c = true OR ServiceTerritory__c = null
        ];
        if (!communities.isEmpty()) syncCommunities(communities);
    }

    @TestVisible
    static void syncCommunities(List<Community__c> communities) {
        Map<String, Id> territoryByName = getTerritoryMap();
        if (territoryByName.isEmpty()) return;

        List<Community__c> toUpdate = new List<Community__c>();

        for (Community__c c : communities) {
            if (c.ServiceTerritory__c != null) continue;

            Id matched = resolveTerritory(c, territoryByName);
            if (matched != null) {
                toUpdate.add(new Community__c(Id = c.Id, ServiceTerritory__c = matched));
            }
        }

        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // ── territory resolution — name match first, then division fallback ───────

    @TestVisible
    static Id resolveTerritory(Community__c c, Map<String, Id> territoryByName) {
        if (!String.isBlank(c.Service_Territory_Name__c)) {
            Id matched = territoryByName.get(c.Service_Territory_Name__c.trim().toLowerCase());
            if (matched != null) return matched;
        }
        if (!String.isBlank(c.Loving_Operating_Division__c)) {
            return territoryByName.get(c.Loving_Operating_Division__c.trim().toLowerCase());
        }
        return null;
    }

    @TestVisible
    static Map<String, Id> getTerritoryMap() {
        Map<String, Id> result = new Map<String, Id>();
        for (ServiceTerritory st : [SELECT Id, Name FROM ServiceTerritory WHERE IsActive = true]) {
            result.put(st.Name.trim().toLowerCase(), st.Id);
        }
        return result;
    }
}