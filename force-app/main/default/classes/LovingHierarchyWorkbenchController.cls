/**
 * LovingHierarchyWorkbenchController
 * Apex controller for the lovingAccountCommunityLotWorkbench LWC.
 * Returns the full 4-level hierarchy: Builder Parent → Division Account → Community → Lot.
 *
 * Data model:
 *   Parent   = Account WHERE Type = 'Home Builder'
 *   Division = Account WHERE Type = 'Division Builder', ParentId → Parent
 *   Community= Community__c, Builder_Account__c → Division
 *   Lot      = Lot__c, Community__c → Community
 *
 * Hard rules enforced:
 *   - No transactions (PO/WO/Invoice) may originate from a Parent Account.
 *   - PO creation requires Division Account + Community + Lot.
 *   - Exceptions column surfaces: Communities with no Division, Lots with no Community.
 *
 * @author  LOVING Salesforce Transformation Team
 * @version 2026-05-11
 */
public with sharing class LovingHierarchyWorkbenchController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class WorkbenchDTO {
        @AuraEnabled public Integer                parentCount    { get; set; }
        @AuraEnabled public Integer                divisionCount  { get; set; }
        @AuraEnabled public Integer                communityCount { get; set; }
        @AuraEnabled public Integer                lotCount       { get; set; }
        @AuraEnabled public Integer                exceptionCount { get; set; }
        @AuraEnabled public List<ParentCardDTO>    parents        { get; set; }
        @AuraEnabled public List<DivisionCardDTO>  divisions      { get; set; }
        @AuraEnabled public List<CommunityCardDTO> communities    { get; set; }
        @AuraEnabled public List<LotCardDTO>       lots           { get; set; }
        @AuraEnabled public List<ExceptionCardDTO> exceptions     { get; set; }
    }

    public class ParentCardDTO {
        @AuraEnabled public String  id             { get; set; }
        @AuraEnabled public String  name           { get; set; }
        @AuraEnabled public String  accountStatus  { get; set; }
        @AuraEnabled public Integer divisionCount  { get; set; }
        @AuraEnabled public Integer communityCount { get; set; }
        @AuraEnabled public Integer lotCount       { get; set; }
        @AuraEnabled public String  meta           { get; set; }
        @AuraEnabled public String  statusLabel    { get; set; }
        @AuraEnabled public String  csmName        { get; set; }
        @AuraEnabled public String  openPoLabel    { get; set; }
        @AuraEnabled public String  market         { get; set; }
    }

    public class DivisionCardDTO {
        @AuraEnabled public String  id             { get; set; }
        @AuraEnabled public String  name           { get; set; }
        @AuraEnabled public String  parentId       { get; set; }
        @AuraEnabled public String  parentName     { get; set; }
        @AuraEnabled public String  market         { get; set; }
        @AuraEnabled public String  territory      { get; set; }
        @AuraEnabled public String  csmName        { get; set; }
        @AuraEnabled public String  accountStatus  { get; set; }
        @AuraEnabled public Integer communityCount { get; set; }
        @AuraEnabled public Integer lotCount       { get; set; }
        @AuraEnabled public Decimal openPoValue    { get; set; }
        @AuraEnabled public String  openPoLabel    { get; set; }
        @AuraEnabled public String  meta           { get; set; }
        @AuraEnabled public String  statusLabel    { get; set; }
    }

    public class CommunityCardDTO {
        @AuraEnabled public String  id             { get; set; }
        @AuraEnabled public String  name           { get; set; }
        @AuraEnabled public String  divisionId     { get; set; }
        @AuraEnabled public String  divisionName   { get; set; }
        @AuraEnabled public String  parentId       { get; set; }
        @AuraEnabled public String  parentName     { get; set; }
        @AuraEnabled public String  territory      { get; set; }
        @AuraEnabled public String  fmName         { get; set; }
        @AuraEnabled public Integer lotCount       { get; set; }
        @AuraEnabled public Boolean aquaActive     { get; set; }
        @AuraEnabled public String  sodType        { get; set; }
        @AuraEnabled public Decimal openPoValue    { get; set; }
        @AuraEnabled public String  openPoLabel    { get; set; }
        @AuraEnabled public String  meta           { get; set; }
        @AuraEnabled public String  statusLabel    { get; set; }
    }

    public class LotCardDTO {
        @AuraEnabled public String  id             { get; set; }
        @AuraEnabled public String  name           { get; set; }
        @AuraEnabled public String  lotNumber      { get; set; }
        @AuraEnabled public String  communityId    { get; set; }
        @AuraEnabled public String  communityName  { get; set; }
        @AuraEnabled public String  divisionId     { get; set; }
        @AuraEnabled public String  parentId       { get; set; }
        @AuraEnabled public String  address        { get; set; }
        @AuraEnabled public String  status         { get; set; }
        @AuraEnabled public String  statusChipClass{ get; set; }
        @AuraEnabled public String  bmgPackage     { get; set; }
        @AuraEnabled public String  workOrderId    { get; set; }
        @AuraEnabled public String  meta           { get; set; }
        @AuraEnabled public String  statusLabel    { get; set; }
        @AuraEnabled public String  valueLabel     { get; set; }
        @AuraEnabled public String  valueClass     { get; set; }
    }

    public class ExceptionCardDTO {
        @AuraEnabled public String  id             { get; set; }
        @AuraEnabled public String  name           { get; set; }
        @AuraEnabled public String  exceptionType  { get; set; }
        @AuraEnabled public String  description    { get; set; }
        @AuraEnabled public String  severity       { get; set; }
        @AuraEnabled public String  objectType     { get; set; }
    }

    // ─── Main Method ─────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static WorkbenchDTO getWorkbenchData() {
        WorkbenchDTO dto        = new WorkbenchDTO();
        dto.parents             = new List<ParentCardDTO>();
        dto.divisions           = new List<DivisionCardDTO>();
        dto.communities         = new List<CommunityCardDTO>();
        dto.lots                = new List<LotCardDTO>();
        dto.exceptions          = new List<ExceptionCardDTO>();

        // ── 1. Parent Accounts ───────────────────────────────────────────────
        Map<Id, ParentCardDTO> parentMap = new Map<Id, ParentCardDTO>();
        for (Account a : [
            SELECT Id, Name, Account_Status__c, Market__c,
                   Loving_CSM__r.Name,
                   (SELECT Id FROM ChildAccounts
                    WHERE Type = 'Division Builder' LIMIT 500)
            FROM Account
            WHERE Type = 'Home Builder'
            ORDER BY Name
            LIMIT 200
        ]) {
            ParentCardDTO p   = new ParentCardDTO();
            p.id              = a.Id;
            p.name            = a.Name;
            p.accountStatus   = a.Account_Status__c;
            p.divisionCount   = a.ChildAccounts != null ? a.ChildAccounts.size() : 0;
            p.communityCount  = 0;
            p.lotCount        = 0;
            p.market          = a.Market__c;
            p.csmName         = a.Loving_CSM__r != null ? a.Loving_CSM__r.Name : null;
            p.openPoLabel     = '';
            p.meta            = 'Brand roll-up and QBR';
            p.statusLabel     = 'Roll-up only';
            parentMap.put(a.Id, p);
            dto.parents.add(p);
        }

        // ── 2. Division Accounts ─────────────────────────────────────────────
        Map<Id, DivisionCardDTO> divisionMap = new Map<Id, DivisionCardDTO>();
        for (Account a : [
            SELECT Id, Name, ParentId, Parent.Name,
                   Market__c, Account_Status__c,
                   Loving_CSM__r.Name
            FROM Account
            WHERE Type = 'Division Builder'
            ORDER BY Name
            LIMIT 500
        ]) {
            DivisionCardDTO d = new DivisionCardDTO();
            d.id              = a.Id;
            d.name            = a.Name;
            d.parentId        = a.ParentId;
            d.parentName      = a.Parent != null ? a.Parent.Name : null;
            d.market          = a.Market__c;
            d.territory       = territoryFromMarket(a.Market__c);
            d.csmName         = a.Loving_CSM__r != null ? a.Loving_CSM__r.Name : null;
            d.accountStatus   = a.Account_Status__c;
            d.communityCount  = 0;
            d.lotCount        = 0;
            d.openPoValue     = 0;
            d.openPoLabel     = '';
            d.meta            = buildDivisionMeta(a.Market__c, a.Loving_CSM__r != null ? a.Loving_CSM__r.Name : null);
            d.statusLabel     = 'Operating';
            divisionMap.put(a.Id, d);
            dto.divisions.add(d);
        }

        // ── 3. Communities ───────────────────────────────────────────────────
        Map<Id, CommunityCardDTO> communityMap = new Map<Id, CommunityCardDTO>();
        for (Community__c c : [
            SELECT Id, Name,
                   Builder_Account__c,
                   Builder_Account__r.Name,
                   Builder_Account__r.ParentId,
                   Builder_Account__r.Parent.Name,
                   Parent_Builder_Account__c,
                   Territory__c,
                   Assigned_FM__r.Name,
                   Number_Of_Lots__c,
                   Aqua_Customer__c,
                   Sod_Type__c
            FROM Community__c
            WHERE Builder_Account__c != null
            ORDER BY Name
            LIMIT 1000
        ]) {
            CommunityCardDTO comm = new CommunityCardDTO();
            comm.id              = c.Id;
            comm.name            = c.Name;
            comm.divisionId      = c.Builder_Account__c;
            comm.divisionName    = c.Builder_Account__r != null ? c.Builder_Account__r.Name : null;
            comm.parentId        = c.Builder_Account__r != null ? String.valueOf(c.Builder_Account__r.ParentId) : null;
            comm.parentName      = c.Parent_Builder_Account__c;
            comm.territory       = c.Territory__c;
            comm.fmName          = c.Assigned_FM__r != null ? c.Assigned_FM__r.Name : null;
            comm.lotCount        = c.Number_Of_Lots__c != null ? Integer.valueOf(c.Number_Of_Lots__c) : 0;
            comm.aquaActive      = c.Aqua_Customer__c == true;
            comm.sodType         = c.Sod_Type__c;
            comm.openPoValue     = 0;
            comm.openPoLabel     = '';
            comm.meta            = buildCommunityMeta(
                                        c.Builder_Account__r != null ? c.Builder_Account__r.Name : null,
                                        c.Assigned_FM__r != null ? c.Assigned_FM__r.Name : null
                                    );
            comm.statusLabel     = 'Active';
            communityMap.put(c.Id, comm);
            dto.communities.add(comm);

            // Roll up community count to Division
            if (c.Builder_Account__c != null && divisionMap.containsKey(c.Builder_Account__c)) {
                divisionMap.get(c.Builder_Account__c).communityCount++;
            }
            // Roll up community count to Parent
            String parentIdStr = c.Builder_Account__r != null ? String.valueOf(c.Builder_Account__r.ParentId) : null;
            if (String.isNotBlank(parentIdStr)) {
                try {
                    Id pid = (Id) parentIdStr;
                    if (parentMap.containsKey(pid)) {
                        parentMap.get(pid).communityCount++;
                    }
                } catch (Exception e) { /* skip malformed id */ }
            }
        }

        // Communities with no Division Account (exceptions)
        for (Community__c c : [
            SELECT Id, Name
            FROM Community__c
            WHERE Builder_Account__c = null
            ORDER BY Name
            LIMIT 100
        ]) {
            ExceptionCardDTO ex = new ExceptionCardDTO();
            ex.id               = c.Id;
            ex.name             = c.Name;
            ex.exceptionType    = 'Community — No Division Account';
            ex.description      = 'Assign a Division Account to include in the hierarchy.';
            ex.severity         = 'warn';
            ex.objectType       = 'Community';
            dto.exceptions.add(ex);
        }

        // ── 4. Lots ──────────────────────────────────────────────────────────
        for (Lot__c l : [
            SELECT Id, Name, Lot_Number__c,
                   Community__c,
                   Community__r.Name,
                   Community__r.Builder_Account__c,
                   Community__r.Builder_Account__r.ParentId,
                   Builder_Account__c,
                   Street_Address__c, City__c, State__c,
                   Status__c,
                   BMG_Package__c,
                   Current_Work_Order__c
            FROM Lot__c
            WHERE Community__c != null
            ORDER BY Name
            LIMIT 2000
        ]) {
            LotCardDTO lot       = new LotCardDTO();
            lot.id               = l.Id;
            lot.name             = String.isNotBlank(l.Lot_Number__c) ? l.Lot_Number__c : l.Name;
            lot.lotNumber        = l.Lot_Number__c;
            lot.communityId      = l.Community__c;
            lot.communityName    = l.Community__r != null ? l.Community__r.Name : null;
            lot.divisionId       = l.Community__r != null ? String.valueOf(l.Community__r.Builder_Account__c) : null;
            lot.parentId         = (l.Community__r != null && l.Community__r.Builder_Account__r != null)
                                        ? String.valueOf(l.Community__r.Builder_Account__r.ParentId)
                                        : null;
            lot.address          = formatAddress(l.Street_Address__c, l.City__c, l.State__c);
            lot.status           = l.Status__c;
            lot.statusChipClass  = statusChipClass(l.Status__c);
            lot.bmgPackage       = l.BMG_Package__c;
            lot.workOrderId      = l.Current_Work_Order__c;
            lot.meta             = buildLotMeta(l.Community__r != null ? l.Community__r.Name : null, l.Status__c);
            lot.statusLabel      = l.Status__c != null ? l.Status__c : 'Unknown';
            lot.valueLabel       = l.Status__c;
            lot.valueClass       = statusChipClass(l.Status__c);
            dto.lots.add(lot);

            // Roll up lot count to Community
            if (l.Community__c != null && communityMap.containsKey(l.Community__c)) {
                communityMap.get(l.Community__c).lotCount++;
            }
            // Roll up lot count to Division
            Id divId = (l.Community__r != null && l.Community__r.Builder_Account__c != null)
                            ? l.Community__r.Builder_Account__c : null;
            if (divId != null && divisionMap.containsKey(divId)) {
                divisionMap.get(divId).lotCount++;
            }
            // Roll up lot count to Parent
            Id parentId2 = (l.Community__r != null && l.Community__r.Builder_Account__r != null)
                                ? l.Community__r.Builder_Account__r.ParentId : null;
            if (parentId2 != null && parentMap.containsKey(parentId2)) {
                parentMap.get(parentId2).lotCount++;
            }
        }

        // Lots with no Community (exceptions)
        for (Lot__c l : [
            SELECT Id, Name FROM Lot__c WHERE Community__c = null ORDER BY Name LIMIT 100
        ]) {
            ExceptionCardDTO ex = new ExceptionCardDTO();
            ex.id               = l.Id;
            ex.name             = l.Name;
            ex.exceptionType    = 'Lot — No Community Linked';
            ex.description      = 'Link to a Community to include in the hierarchy.';
            ex.severity         = 'warn';
            ex.objectType       = 'Lot';
            dto.exceptions.add(ex);
        }

        // ── 5. Open PO value rollup to Division ──────────────────────────────
        for (AggregateResult ar : [
            SELECT Division_Account__c divId, SUM(Total_Amount__c) total
            FROM Purchase_Order__c
            WHERE Status__c NOT IN ('Cancelled', 'Closed')
              AND Division_Account__c != null
            GROUP BY Division_Account__c
            LIMIT 500
        ]) {
            Id   divId  = (Id)      ar.get('divId');
            Decimal val = (Decimal) ar.get('total');
            if (divisionMap.containsKey(divId)) {
                divisionMap.get(divId).openPoValue = val != null ? val : 0;
                divisionMap.get(divId).openPoLabel = formatCurrency(val);
            }
        }

        // Open PO value rollup to Community
        for (AggregateResult ar : [
            SELECT Community__c commId, SUM(Total_Amount__c) total
            FROM Purchase_Order__c
            WHERE Status__c NOT IN ('Cancelled', 'Closed')
              AND Community__c != null
            GROUP BY Community__c
            LIMIT 500
        ]) {
            Id   commId = (Id)      ar.get('commId');
            Decimal val = (Decimal) ar.get('total');
            if (communityMap.containsKey(commId)) {
                communityMap.get(commId).openPoValue = val != null ? val : 0;
                communityMap.get(commId).openPoLabel = formatCurrency(val);
            }
        }

        // ── 6. Finalize counts ───────────────────────────────────────────────
        dto.parentCount    = dto.parents.size();
        dto.divisionCount  = dto.divisions.size();
        dto.communityCount = dto.communities.size();
        dto.lotCount       = dto.lots.size();
        dto.exceptionCount = dto.exceptions.size();

        return dto;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static String territoryFromMarket(String market) {
        if (String.isBlank(market)) return null;
        if (market == 'Charlotte')                          return 'Metro Charlotte';
        if (market == 'Asheville')                          return 'Western NC';
        if (market == 'Greenville' || market == 'Spartanburg') return 'Upstate SC';
        return market;
    }

    private static String buildDivisionMeta(String market, String csmName) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(market)) parts.add(market);
        if (String.isNotBlank(csmName)) parts.add('CSM: ' + csmName);
        return parts.isEmpty() ? 'Division account' : String.join(parts, ' · ');
    }

    private static String buildCommunityMeta(String divisionName, String fmName) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(divisionName)) parts.add(divisionName);
        if (String.isNotBlank(fmName)) parts.add('FM: ' + fmName);
        return parts.isEmpty() ? 'Community' : String.join(parts, ' · ');
    }

    private static String buildLotMeta(String communityName, String status) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(communityName)) parts.add(communityName);
        if (String.isNotBlank(status)) parts.add(status);
        return parts.isEmpty() ? 'Lot' : String.join(parts, ' · ');
    }

    private static String formatAddress(String street, String city, String state) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(street)) parts.add(street);
        if (String.isNotBlank(city))   parts.add(city);
        if (String.isNotBlank(state))  parts.add(state);
        return parts.isEmpty() ? '' : String.join(parts, ', ');
    }

    private static String formatCurrency(Decimal val) {
        if (val == null || val == 0) return '';
        if (val >= 1000000) return '$' + (val / 1000000).setScale(1) + 'M';
        if (val >= 1000)    return '$' + (val / 1000).setScale(0) + 'k';
        return '$' + val.setScale(0);
    }

    private static String statusChipClass(String status) {
        if (status == 'Active' || status == 'Available' || status == 'Delivered') return 'g';
        if (status == 'In Progress')                                               return 'b';
        if (status == 'Sold')                                                      return 'a';
        if (status == 'Warranty')                                                  return 'p';
        if (status == 'Closed')                                                    return 'x';
        return 'x';
    }
}