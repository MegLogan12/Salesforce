public with sharing class LovingCommunityWorkbenchController {

    @AuraEnabled(cacheable=true)
    public static WorkbenchDataDto getWorkbenchData() {
        WorkbenchDataDto result = new WorkbenchDataDto();
        result.builders    = loadBuilders();
        result.divisions   = loadDivisions();
        result.communities = loadCommunities();
        result.lots        = loadLots();
        return result;
    }

    private static List<BuilderDto> loadBuilders() {
        List<BuilderDto> dtos = new List<BuilderDto>();
        for (Account a : [
            SELECT Id, Name, Type, BillingCity, BillingState
            FROM Account
            WHERE RecordType.DeveloperName = 'Builder_Parent'
            ORDER BY Name
            LIMIT 200
        ]) {
            BuilderDto d    = new BuilderDto();
            d.id   = a.Id;
            d.name = a.Name;
            d.type = String.isNotBlank(a.Type) ? a.Type : 'Builder';
            d.hq   = buildCityState(a.BillingCity, a.BillingState);
            dtos.add(d);
        }
        return dtos;
    }

    private static List<DivisionDto> loadDivisions() {
        List<DivisionDto> dtos = new List<DivisionDto>();
        for (Account a : [
            SELECT Id, Name, ParentId, Phone
            FROM Account
            WHERE RecordType.DeveloperName = 'Builder_Market'
            ORDER BY Name
            LIMIT 200
        ]) {
            DivisionDto d   = new DivisionDto();
            d.id        = a.Id;
            d.builderId = a.ParentId;
            d.name      = a.Name;
            d.contact   = '';
            d.phone     = a.Phone != null ? a.Phone : '';
            d.stdSodRate = 0;
            d.pricebook  = '';
            dtos.add(d);
        }
        return dtos;
    }

    private static List<CommunityDto> loadCommunities() {
        List<CommunityDto> dtos = new List<CommunityDto>();
        for (Community__c c : [
            SELECT Id, Name,
                   Builder_Account__c,
                   Assigned_FM__r.Name,
                   Community_Status__c,
                   Active_Lot_Count__c,
                   Closed_Lot_Count__c,
                   Number_Of_Lots__c,
                   Aqua_Customer__c,
                   BMG_Package_Code__c,
                   Community_Address__c,
                   Community_City__c,
                   Community_State__c,
                   First_Lot_Install_Date__c,
                   Last_Lot_Install_Date__c
            FROM Community__c
            WHERE Community_Status__c != 'Closed'
            ORDER BY Name
            LIMIT 500
        ]) {
            CommunityDto d   = new CommunityDto();
            d.id         = c.Id;
            d.divisionId = c.Builder_Account__c;
            d.name       = c.Name;
            d.fm         = c.Assigned_FM__r != null ? c.Assigned_FM__r.Name : '';
            d.stage      = mapStage(c.Community_Status__c);
            d.totalLots  = c.Number_Of_Lots__c  != null ? c.Number_Of_Lots__c.intValue()  : 0;
            d.activeLots = c.Active_Lot_Count__c != null ? c.Active_Lot_Count__c.intValue() : 0;
            d.closedLots = c.Closed_Lot_Count__c != null ? c.Closed_Lot_Count__c.intValue() : 0;
            d.phases     = 1; // Phases__c is Text; numeric parse not safe
            d.aqua       = c.Aqua_Customer__c == true;
            d.pkg        = c.BMG_Package_Code__c != null ? c.BMG_Package_Code__c : '';
            d.stdPkg     = 0;
            d.aquaAddon  = 0;
            d.goalHrs    = 0;
            d.address    = buildAddress(c.Community_Address__c, c.Community_City__c, c.Community_State__c);
            d.startDate  = c.First_Lot_Install_Date__c  != null ? String.valueOf(c.First_Lot_Install_Date__c)  : '';
            d.closeDate  = c.Last_Lot_Install_Date__c   != null ? String.valueOf(c.Last_Lot_Install_Date__c)   : '';
            d.specType   = '';
            d.sodRate    = 0;
            d.lotSize    = '';
            dtos.add(d);
        }
        return dtos;
    }

    private static List<LotDto> loadLots() {
        List<LotDto> dtos = new List<LotDto>();
        for (Lot__c l : [
            SELECT Id, Name, Lot_Number__c,
                   Community__c, Community__r.Assigned_FM__r.Name,
                   Street_Address__c, City__c, State__c,
                   Requested_Install_Date__c,
                   Pipeline_Bucket__c,
                   Lot_Status__c,
                   Eight11_Task_Status__c,
                   Aqua_Installed__c, Aqua_Add_On__c,
                   Builder_PO_Number__c,
                   Spec_Type__c,
                   Phase__c,
                   Lot_Latitude__c, Lot_Longitude__c,
                   Sod_SF__c
            FROM Lot__c
            WHERE Community__r.Community_Status__c != 'Closed'
            ORDER BY Lot_Number__c
            LIMIT 2000
        ]) {
            LotDto d      = new LotDto();
            d.id          = l.Id;
            d.communityId = l.Community__c;
            d.num         = l.Lot_Number__c != null ? l.Lot_Number__c : '';
            d.lotId       = l.Name;
            d.address     = buildAddress(l.Street_Address__c, l.City__c, l.State__c);
            d.reqInstall  = l.Requested_Install_Date__c != null ? String.valueOf(l.Requested_Install_Date__c) : '';
            d.bucket      = mapLotBucket(l.Pipeline_Bucket__c, l.Lot_Status__c);
            d.lotStatus   = l.Lot_Status__c != null ? l.Lot_Status__c : '';
            d.eighty11    = l.Eight11_Task_Status__c != null ? l.Eight11_Task_Status__c : 'Not Filed';
            d.takeoff     = '';
            d.aqua        = l.Aqua_Installed__c == true ? 'Installed'
                          : (l.Aqua_Add_On__c != null && l.Aqua_Add_On__c > 0 ? 'Auto' : 'N/A');
            d.po          = l.Builder_PO_Number__c != null ? l.Builder_PO_Number__c : '';
            d.poAmt       = 0;
            d.specType    = l.Spec_Type__c != null ? l.Spec_Type__c : '';
            d.fm          = l.Community__r?.Assigned_FM__r?.Name != null
                            ? l.Community__r.Assigned_FM__r.Name : '';
            d.phase       = l.Phase__c != null ? l.Phase__c : '';
            d.gps         = (l.Lot_Latitude__c != null && l.Lot_Longitude__c != null)
                            ? l.Lot_Latitude__c + ',' + l.Lot_Longitude__c : '';
            d.sodSf       = l.Sod_SF__c != null ? l.Sod_SF__c : 0;
            d.goalHrs     = 0;
            d.crew        = '';
            d.woCount     = 0;
            d.photoCount  = 0;
            dtos.add(d);
        }
        return dtos;
    }

    private static String mapStage(String status) {
        if (status == null)        return 'Active Selling';
        if (status == 'Active')    return 'Active Selling';
        if (status == 'Built Out') return 'Fully Sold';
        if (status == 'Closed')    return 'Closed Out';
        return status;
    }

    private static String mapLotBucket(String pb, String ls) {
        if (pb != null) {
            if (pb == 'Scheduled')                                     return 'scheduled';
            if (pb == 'In Progress')                                   return 'active';
            if (pb == 'Takeoff Complete' || pb == 'Site Ready')        return 'clear';
            if (pb == 'QI' || pb == 'Closed' ||
                pb == 'Ready to Invoice' || pb == 'Invoiced')          return 'closed';
        }
        if (ls == null)                          return '90+';
        if (ls == 'Open')                        return '90+';
        if (ls == 'Under Construction')          return '60+';
        if (ls == 'PO Received')                 return '30';
        if (ls == 'Pending Takeoff' ||
            ls == 'Takeoff Scheduled')           return 'takeoff';
        if (ls == 'Clear for Schedule')          return 'clear';
        if (ls == 'Scheduled')                   return 'scheduled';
        if (ls == 'In Progress')                 return 'active';
        if (ls == 'Installed' || ls == 'Closed'
            || ls == 'Cancelled')                return 'closed';
        return '90+';
    }

    private static String buildAddress(String street, String city, String state) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(street)) parts.add(street);
        if (String.isNotBlank(city))   parts.add(city);
        if (String.isNotBlank(state))  parts.add(state);
        return parts.isEmpty() ? '' : String.join(parts, ', ');
    }

    private static String buildCityState(String city, String state) {
        if (String.isNotBlank(city) && String.isNotBlank(state)) return city + ', ' + state;
        if (String.isNotBlank(city))  return city;
        if (String.isNotBlank(state)) return state;
        return '';
    }

    // ─── DTOs ─────────────────────────────────────────────────────────────────

    public class WorkbenchDataDto {
        @AuraEnabled public List<BuilderDto>   builders    { get; set; }
        @AuraEnabled public List<DivisionDto>  divisions   { get; set; }
        @AuraEnabled public List<CommunityDto> communities { get; set; }
        @AuraEnabled public List<LotDto>       lots        { get; set; }
    }

    public class BuilderDto {
        @AuraEnabled public String id   { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public String hq   { get; set; }
    }

    public class DivisionDto {
        @AuraEnabled public String  id         { get; set; }
        @AuraEnabled public String  builderId  { get; set; }
        @AuraEnabled public String  name       { get; set; }
        @AuraEnabled public String  contact    { get; set; }
        @AuraEnabled public String  phone      { get; set; }
        @AuraEnabled public Decimal stdSodRate { get; set; }
        @AuraEnabled public String  pricebook  { get; set; }
    }

    public class CommunityDto {
        @AuraEnabled public String  id         { get; set; }
        @AuraEnabled public String  divisionId { get; set; }
        @AuraEnabled public String  name       { get; set; }
        @AuraEnabled public String  fm         { get; set; }
        @AuraEnabled public String  stage      { get; set; }
        @AuraEnabled public Integer totalLots  { get; set; }
        @AuraEnabled public Integer activeLots { get; set; }
        @AuraEnabled public Integer closedLots { get; set; }
        @AuraEnabled public Integer phases     { get; set; }
        @AuraEnabled public Boolean aqua       { get; set; }
        @AuraEnabled public String  pkg        { get; set; }
        @AuraEnabled public Decimal stdPkg     { get; set; }
        @AuraEnabled public Decimal aquaAddon  { get; set; }
        @AuraEnabled public Decimal goalHrs    { get; set; }
        @AuraEnabled public String  address    { get; set; }
        @AuraEnabled public String  startDate  { get; set; }
        @AuraEnabled public String  closeDate  { get; set; }
        @AuraEnabled public String  specType   { get; set; }
        @AuraEnabled public Decimal sodRate    { get; set; }
        @AuraEnabled public String  lotSize    { get; set; }
    }

    public class LotDto {
        @AuraEnabled public String  id          { get; set; }
        @AuraEnabled public String  communityId { get; set; }
        @AuraEnabled public String  num         { get; set; }
        @AuraEnabled public String  lotId       { get; set; }
        @AuraEnabled public String  address     { get; set; }
        @AuraEnabled public String  reqInstall  { get; set; }
        @AuraEnabled public String  bucket      { get; set; }
        @AuraEnabled public String  lotStatus   { get; set; }
        @AuraEnabled public String  eighty11    { get; set; }
        @AuraEnabled public String  takeoff     { get; set; }
        @AuraEnabled public String  aqua        { get; set; }
        @AuraEnabled public String  po          { get; set; }
        @AuraEnabled public Decimal poAmt       { get; set; }
        @AuraEnabled public String  specType    { get; set; }
        @AuraEnabled public String  fm          { get; set; }
        @AuraEnabled public String  phase       { get; set; }
        @AuraEnabled public String  gps         { get; set; }
        @AuraEnabled public Decimal sodSf       { get; set; }
        @AuraEnabled public Decimal goalHrs     { get; set; }
        @AuraEnabled public String  crew        { get; set; }
        @AuraEnabled public Integer woCount     { get; set; }
        @AuraEnabled public Integer photoCount  { get; set; }
    }
}
