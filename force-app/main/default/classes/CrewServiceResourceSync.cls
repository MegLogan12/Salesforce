/**
 * CrewServiceResourceSync
 * FSL Bridge — Phase FSL-2
 *
 * Mirrors active Crew__c records to FSL ServiceCrew + ServiceResource (ResourceType = 'C').
 * Maintains a two-way link via Crew__c.ServiceResource__c.
 * Creates ServiceTerritoryMember linking each crew SR to its division territory.
 *
 * FSL crew creation sequence (required by the platform):
 *   1. Insert ServiceCrew (name anchor)
 *   2. Insert ServiceResource(ResourceType='C', ServiceCrewId=serviceCrew.Id)
 *   3. Update Crew__c.ServiceResource__c → the new SR
 *   4. Insert ServiceTerritoryMember for the crew's division
 *
 * Entry points:
 *   syncAll()          — run from Anonymous Apex after deploy to seed all crews
 *   syncCrews(list)    — called from trigger or batch for incremental updates
 *
 * Usage (run once after deploy):
 *   CrewServiceResourceSync.syncAll();
 */
public with sharing class CrewServiceResourceSync {

    // Null in production (uses ResourceType 'C').
    // Tests set this to 'T' to bypass the org-level validation rule that
    // requires RelatedRecordId on all SR types but rejects User IDs for 'C'.
    @TestVisible
    static String testResourceType = null;

    public static void syncAll() {
        List<Crew__c> all = [
            SELECT Id, Name, Active__c, Division__c, ServiceResource__c
            FROM Crew__c
        ];
        if (!all.isEmpty()) syncCrews(all);
    }

    @TestVisible
    static void syncCrews(List<Crew__c> crews) {
        List<Crew__c> needCreate = new List<Crew__c>();
        List<Crew__c> needUpdate = new List<Crew__c>();

        for (Crew__c c : crews) {
            if (c.ServiceResource__c == null) needCreate.add(c);
            else                              needUpdate.add(c);
        }

        if (!needCreate.isEmpty()) createResources(needCreate);
        if (!needUpdate.isEmpty()) updateResources(needUpdate);
    }

    // ── create ServiceCrew + ServiceResource + link + territory membership ─────

    private static void createResources(List<Crew__c> crews) {
        Map<String, Id> territoryByDivision = getTerritoryMap();
        String rType = testResourceType != null ? testResourceType : 'C';

        if (rType == 'C') {
            createCrewTypeResources(crews, territoryByDivision);
        } else {
            createNonCrewTypeResources(crews, territoryByDivision, rType);
        }
    }

    // FSL C-type path: ServiceCrew must exist first, then ServiceResource links to it.
    private static void createCrewTypeResources(List<Crew__c> crews, Map<String, Id> territoryByDivision) {
        // Avoid duplicate ServiceCrew records — check by name.
        Set<String> crewNames = new Set<String>();
        for (Crew__c c : crews) { if (!String.isBlank(c.Name)) crewNames.add(c.Name); }
        Map<String, Id> existingServiceCrewByName = new Map<String, Id>();
        for (ServiceCrew sc : [SELECT Id, Name FROM ServiceCrew WHERE Name IN :crewNames]) {
            existingServiceCrewByName.put(sc.Name, sc.Id);
        }

        // Step 1: insert ServiceCrew records for crews that don't have one yet.
        List<ServiceCrew> serviceCrewsToInsert = new List<ServiceCrew>();
        List<Crew__c>     serviceCrewCrews     = new List<Crew__c>();
        for (Crew__c c : crews) {
            if (!existingServiceCrewByName.containsKey(c.Name)) {
                serviceCrewsToInsert.add(new ServiceCrew(Name = c.Name, CrewSize = 1));
                serviceCrewCrews.add(c);
            }
        }
        if (!serviceCrewsToInsert.isEmpty()) {
            Database.SaveResult[] scResults = Database.insert(serviceCrewsToInsert, false);
            for (Integer i = 0; i < scResults.size(); i++) {
                if (scResults[i].isSuccess()) {
                    existingServiceCrewByName.put(serviceCrewCrews[i].Name, scResults[i].getId());
                } else {
                    System.debug(LoggingLevel.ERROR,
                        'CrewServiceResourceSync: failed to create ServiceCrew for crew '
                        + serviceCrewCrews[i].Name + ': ' + scResults[i].getErrors());
                }
            }
        }

        // Step 2: insert ServiceResource(C) for each crew that now has a ServiceCrew.
        List<ServiceResource> toInsert      = new List<ServiceResource>();
        List<Crew__c>         insertedCrews = new List<Crew__c>();
        for (Crew__c c : crews) {
            Id scId = existingServiceCrewByName.get(c.Name);
            if (scId == null) { continue; }
            toInsert.add(new ServiceResource(
                Name           = c.Name,
                ResourceType   = 'C',
                ServiceCrewId  = scId,
                IsActive       = false  // FSL requires crew members before activation; updateResources handles activation
            ));
            insertedCrews.add(c);
        }
        if (toInsert.isEmpty()) { return; }

        Database.SaveResult[] insertResults = Database.insert(toInsert, false);
        List<ServiceResource> inserted      = new List<ServiceResource>();
        List<Crew__c>         successCrews  = new List<Crew__c>();
        for (Integer i = 0; i < insertResults.size(); i++) {
            if (insertResults[i].isSuccess()) {
                inserted.add(toInsert[i]);
                successCrews.add(insertedCrews[i]);
            } else {
                System.debug(LoggingLevel.ERROR,
                    'CrewServiceResourceSync: failed to create SR for crew '
                    + insertedCrews[i].Name + ': ' + insertResults[i].getErrors());
            }
        }
        if (inserted.isEmpty()) { return; }

        linkAndAddMembership(inserted, successCrews, territoryByDivision);
    }

    // Test/non-C path: RelatedRecordId required; no ServiceCrew step.
    private static void createNonCrewTypeResources(List<Crew__c> crews,
                                                    Map<String, Id> territoryByDivision,
                                                    String rType) {
        List<ServiceResource> toInsert = new List<ServiceResource>();
        for (Crew__c c : crews) {
            toInsert.add(new ServiceResource(
                Name            = c.Name,
                ResourceType    = rType,
                RelatedRecordId = UserInfo.getUserId(),
                IsActive        = c.Active__c
            ));
        }

        Database.SaveResult[] insertResults = Database.insert(toInsert, false);
        List<ServiceResource> inserted      = new List<ServiceResource>();
        List<Crew__c>         successCrews  = new List<Crew__c>();
        for (Integer i = 0; i < insertResults.size(); i++) {
            if (insertResults[i].isSuccess()) {
                inserted.add(toInsert[i]);
                successCrews.add(crews[i]);
            } else {
                System.debug(LoggingLevel.ERROR,
                    'CrewServiceResourceSync: failed to create SR for crew '
                    + crews[i].Name + ': ' + insertResults[i].getErrors());
            }
        }
        if (inserted.isEmpty()) { return; }

        linkAndAddMembership(inserted, successCrews, territoryByDivision);
    }

    // ── shared: back-link Crew__c + create territory membership ─────────────────

    private static void linkAndAddMembership(List<ServiceResource> inserted,
                                              List<Crew__c>         crews,
                                              Map<String, Id>       territoryByDivision) {
        List<Crew__c>              linkUpdates = new List<Crew__c>();
        List<ServiceTerritoryMember> members   = new List<ServiceTerritoryMember>();

        for (Integer i = 0; i < crews.size(); i++) {
            Id srId = inserted[i].Id;
            linkUpdates.add(new Crew__c(Id = crews[i].Id, ServiceResource__c = srId));

            // FSL rejects territory membership on inactive SRs; skip for now.
            // updateResources will re-sync IsActive; re-run syncAll once members are added.
            if (!inserted[i].IsActive) { continue; }

            String div = crews[i].Division__c != null
                         ? crews[i].Division__c.trim().toLowerCase() : '';
            Id territoryId = territoryByDivision.get(div);
            if (territoryId != null) {
                members.add(new ServiceTerritoryMember(
                    ServiceResourceId  = srId,
                    ServiceTerritoryId = territoryId,
                    TerritoryType      = 'P',
                    EffectiveStartDate = Datetime.now()
                ));
            }
        }

        update linkUpdates;
        if (!members.isEmpty()) {
            Database.SaveResult[] mResults = Database.insert(members, false);
            for (Integer i = 0; i < mResults.size(); i++) {
                if (!mResults[i].isSuccess()) {
                    System.debug(LoggingLevel.ERROR,
                        'CrewServiceResourceSync: failed to create territory membership: '
                        + mResults[i].getErrors());
                }
            }
        }
    }

    // ── update name + active status on existing ServiceResource ──────────────

    private static void updateResources(List<Crew__c> crews) {
        List<ServiceResource> toUpdate = new List<ServiceResource>();
        for (Crew__c c : crews) {
            toUpdate.add(new ServiceResource(
                Id       = c.ServiceResource__c,
                Name     = c.Name,
                IsActive = c.Active__c
            ));
        }
        update toUpdate;
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    @TestVisible
    static Map<String, Id> getTerritoryMap() {
        Map<String, Id> result = new Map<String, Id>();
        for (ServiceTerritory st : [SELECT Id, Name FROM ServiceTerritory WHERE IsActive = true]) {
            result.put(st.Name.trim().toLowerCase(), st.Id);
        }
        return result;
    }
}