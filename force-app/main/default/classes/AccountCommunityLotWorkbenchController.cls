public with sharing class AccountCommunityLotWorkbenchController {

    private static final Map<String, String> BUCKET_MAP = new Map<String, String>{
        '90+ Days'           => '90+',
        '60+ Days'           => '60+',
        '30 Days'            => '30',
        'Pending Scheduling' => '30',
        'Clear to Schedule'  => 'clear',
        'Clear for Schedule' => 'clear',
        'Site Ready'         => 'clear',
        'Takeoff Complete'   => 'takeoff',
        'Scheduled'          => 'scheduled',
        'In Progress'        => 'active',
        'QI'                 => 'active',
        'Closed'             => 'closed',
        'Ready to Invoice'   => 'closed',
        'Invoiced'           => 'closed',
        'New'                => '90+'
    };

    @AuraEnabled(cacheable=true)
    public static WorkbenchPageDTO getWorkbenchData() {
        WorkbenchPageDTO dto = new WorkbenchPageDTO();

        // Builders and Divisions share the Account object; Divisions have a Parent
        List<Account> accounts = [
            SELECT Id, Name, RecordType.Name, ParentId, Parent.Name,
                   BillingCity, BillingState,
                   Construction_Mgr_Name__c, Construction_Mgr_Phone__c,
                   Division_Phone__c, Scheduling_Contact_Name__c
            FROM Account
            WHERE RecordType.Name IN ('Home Builder', 'Division Builder')
            ORDER BY RecordType.Name DESC, Name
        ];

        dto.builders  = new List<BuilderDTO>();
        dto.divisions = new List<DivisionDTO>();
        for (Account a : accounts) {
            if (a.RecordType.Name == 'Home Builder') {
                BuilderDTO b  = new BuilderDTO();
                b.id   = a.Id;
                b.name = a.Name;
                b.type = 'National Builder';
                b.hq   = joinNonBlank(new List<String>{ a.BillingCity, a.BillingState }, ', ');
                dto.builders.add(b);
            } else {
                DivisionDTO d  = new DivisionDTO();
                d.id        = a.Id;
                d.builderId = a.ParentId;
                d.name      = a.Name;
                d.contact   = a.Construction_Mgr_Name__c != null ? a.Construction_Mgr_Name__c
                            : (a.Scheduling_Contact_Name__c != null ? a.Scheduling_Contact_Name__c : '');
                d.phone     = a.Division_Phone__c != null ? a.Division_Phone__c
                            : (a.Construction_Mgr_Phone__c != null ? a.Construction_Mgr_Phone__c : '');
                d.stdSodRate = null;
                d.pricebook  = '';
                dto.divisions.add(d);
            }
        }

        // Communities
        List<Community__c> communities = [
            SELECT Id, Name,
                   Builder_Account__c, Builder_Account__r.Name, Builder_Account__r.ParentId,
                   Community_Status__c, FM_Assignment__c, FM_Assignment__r.Name,
                   Number_of_Lots__c, Active_Lot_Count__c, Closed_Lot_Count__c,
                   Aqua_Customer__c,
                   Community_Address__c, Community_City__c, Community_State__c,
                   BMG_Package_Code__c, Active_Community_Package__c,
                   Phases__c,
                   First_Lot_Install_Date__c, Last_Lot_Install_Date__c,
                   Avg_Sod_Roll_Coverage__c
            FROM Community__c
            WHERE Active__c = true
            ORDER BY Name
        ];

        dto.communities = new List<CommunityDTO>();
        for (Community__c c : communities) {
            CommunityDTO cd = new CommunityDTO();
            cd.id         = c.Id;
            cd.divisionId = c.Builder_Account__c;
            cd.name       = c.Name;
            cd.fm         = c.FM_Assignment__r.Name != null ? c.FM_Assignment__r.Name : '';
            cd.stage      = c.Community_Status__c != null ? c.Community_Status__c : 'Active';
            cd.totalLots  = c.Number_of_Lots__c   != null ? Integer.valueOf(c.Number_of_Lots__c)   : 0;
            cd.activeLots = c.Active_Lot_Count__c  != null ? Integer.valueOf(c.Active_Lot_Count__c)  : 0;
            cd.closedLots = c.Closed_Lot_Count__c  != null ? Integer.valueOf(c.Closed_Lot_Count__c)  : 0;
            cd.aqua       = c.Aqua_Customer__c == true;
            cd.pkg        = c.BMG_Package_Code__c != null ? c.BMG_Package_Code__c
                          : (c.Active_Community_Package__c != null ? String.valueOf(c.Active_Community_Package__c) : '');
            cd.stdPkg     = null;
            cd.aquaAddon  = null;
            cd.goalHrs    = null;
            cd.phases     = c.Phases__c != null ? Integer.valueOf(c.Phases__c) : null;
            cd.address    = joinNonBlank(new List<String>{ c.Community_Address__c, c.Community_City__c, c.Community_State__c }, ', ');
            cd.startDate  = c.First_Lot_Install_Date__c != null ? String.valueOf(c.First_Lot_Install_Date__c) : null;
            cd.closeDate  = c.Last_Lot_Install_Date__c  != null ? String.valueOf(c.Last_Lot_Install_Date__c)  : null;
            cd.specType   = 'Average';
            cd.sodRate    = c.Avg_Sod_Roll_Coverage__c;
            cd.lotSize    = '';
            dto.communities.add(cd);
        }

        // Lots — with child takeoff (most recent) and standard WorkOrder count
        List<Lot__c> lots = [
            SELECT Id, Name, Lot_Number__c, Community__c,
                   Builder_Division__c,
                   Street_Address__c, Address__c, Requested_Install_Date__c,
                   Pipeline_Bucket__c, Lot_Status__c, Eight11_Task_Status__c,
                   Spec_Type__c, Builder_PO_Number__c, Phase__c,
                   Sod_Sf__c, Aqua_Installed__c, Aqua_Add_On__c,
                   Latitude__c, Longitude__c,
                   (SELECT Status__c, Scheduled_Date__c FROM Takeoffs__r
                    ORDER BY CreatedDate DESC LIMIT 1),
                   (SELECT Id FROM Work_Orders__r LIMIT 200)
            FROM Lot__c
            ORDER BY Community__r.Name, Lot_Number__c NULLS LAST, Name
        ];

        dto.lots = new List<LotDTO>();
        for (Lot__c l : lots) {
            LotDTO ld       = new LotDTO();
            ld.id           = l.Id;
            ld.communityId  = l.Community__c;
            ld.num          = l.Lot_Number__c != null ? l.Lot_Number__c : l.Name;
            ld.lotId        = l.Name;
            ld.address      = l.Street_Address__c != null ? l.Street_Address__c
                            : (l.Address__c != null ? l.Address__c : '');
            ld.reqInstall   = l.Requested_Install_Date__c != null
                            ? String.valueOf(l.Requested_Install_Date__c) : null;
            ld.bucket       = mapBucket(l.Pipeline_Bucket__c);
            ld.lotStatus    = l.Lot_Status__c != null ? l.Lot_Status__c : '';
            ld.eighty11     = l.Eight11_Task_Status__c != null ? l.Eight11_Task_Status__c : 'Not Filed';
            ld.takeoff      = resolveTakeoff(l.Takeoffs__r);
            ld.aqua         = l.Aqua_Installed__c == true ? 'Installed'
                            : (l.Aqua_Add_On__c  != null  ? 'Auto' : 'N/A');
            ld.po           = l.Builder_PO_Number__c != null ? l.Builder_PO_Number__c : '';
            ld.poAmt        = null;
            ld.specType     = l.Spec_Type__c != null ? l.Spec_Type__c : '';
            ld.fm           = '';
            ld.phase        = l.Phase__c != null ? l.Phase__c : '';
            ld.gps          = (l.Latitude__c != null && l.Longitude__c != null)
                            ? String.valueOf(l.Latitude__c) + ',' + String.valueOf(l.Longitude__c) : '';
            ld.sodSf        = l.Sod_Sf__c;
            ld.goalHrs      = null;
            ld.crew         = '';
            ld.woCount      = l.Work_Orders__r.size();
            ld.photoCount   = 0;
            dto.lots.add(ld);
        }

        return dto;
    }

    private static String mapBucket(String bucket) {
        if (bucket == null) return '90+';
        String mapped = BUCKET_MAP.get(bucket);
        return mapped != null ? mapped : '90+';
    }

    private static String resolveTakeoff(List<Takeoff__c> tks) {
        if (tks == null || tks.isEmpty()) return 'Not Started';
        Takeoff__c tk = tks[0];
        String st = tk.Status__c != null ? tk.Status__c : '';
        if (st == 'Approved' || st == 'Locked') return 'Locked';
        if (tk.Scheduled_Date__c != null) return 'Scheduled ' + tk.Scheduled_Date__c.format();
        return String.isNotBlank(st) ? st : 'Not Started';
    }

    private static String joinNonBlank(List<String> parts, String sep) {
        List<String> out = new List<String>();
        for (String p : parts) { if (String.isNotBlank(p)) out.add(p); }
        return String.join(out, sep);
    }

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class WorkbenchPageDTO {
        @AuraEnabled public List<BuilderDTO>   builders;
        @AuraEnabled public List<DivisionDTO>  divisions;
        @AuraEnabled public List<CommunityDTO> communities;
        @AuraEnabled public List<LotDTO>       lots;
    }

    public class BuilderDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  type;
        @AuraEnabled public String  hq;
    }

    public class DivisionDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  builderId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  contact;
        @AuraEnabled public String  phone;
        @AuraEnabled public Decimal stdSodRate;
        @AuraEnabled public String  pricebook;
    }

    public class CommunityDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  divisionId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  fm;
        @AuraEnabled public String  stage;
        @AuraEnabled public Integer totalLots;
        @AuraEnabled public Integer activeLots;
        @AuraEnabled public Integer closedLots;
        @AuraEnabled public Boolean aqua;
        @AuraEnabled public String  pkg;
        @AuraEnabled public Decimal stdPkg;
        @AuraEnabled public Decimal aquaAddon;
        @AuraEnabled public Decimal goalHrs;
        @AuraEnabled public Integer phases;
        @AuraEnabled public String  address;
        @AuraEnabled public String  startDate;
        @AuraEnabled public String  closeDate;
        @AuraEnabled public String  specType;
        @AuraEnabled public Decimal sodRate;
        @AuraEnabled public String  lotSize;
    }

    public class LotDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  communityId;
        @AuraEnabled public String  num;
        @AuraEnabled public String  lotId;
        @AuraEnabled public String  address;
        @AuraEnabled public String  reqInstall;
        @AuraEnabled public String  bucket;
        @AuraEnabled public String  lotStatus;
        @AuraEnabled public String  eighty11;
        @AuraEnabled public String  takeoff;
        @AuraEnabled public String  aqua;
        @AuraEnabled public String  po;
        @AuraEnabled public Decimal poAmt;
        @AuraEnabled public String  specType;
        @AuraEnabled public String  fm;
        @AuraEnabled public String  phase;
        @AuraEnabled public String  gps;
        @AuraEnabled public Decimal sodSf;
        @AuraEnabled public Decimal goalHrs;
        @AuraEnabled public String  crew;
        @AuraEnabled public Integer woCount;
        @AuraEnabled public Integer photoCount;
    }
}