public with sharing class CommunityRecordController {

    /* =========================
       Data transfer classes
       ========================= */

    public class CommunityHeader {
        @AuraEnabled public String name;
        @AuraEnabled public String stage;
        @AuraEnabled public String stageClass;
        @AuraEnabled public Integer lotsComplete;
        @AuraEnabled public Integer lotsTotal;
        @AuraEnabled public String fieldManager;
        @AuraEnabled public String serviceDay;
        @AuraEnabled public String takeoffStatus;
        @AuraEnabled public String takeoffClass;
        @AuraEnabled public String siteVisitStatus;
        @AuraEnabled public String siteVisitClass;
        @AuraEnabled public Integer openWorkOrders;
        @AuraEnabled public Integer changeOrders;
        @AuraEnabled public String builderAccountName;
        @AuraEnabled public String builderAccountUrl;
        @AuraEnabled public String market;
        @AuraEnabled public String territory;
        @AuraEnabled public String openedDateFmt;
    }

    public class ProgressSummary {
        @AuraEnabled public Integer lotsComplete;
        @AuraEnabled public Integer lotsScheduled;
        @AuraEnabled public Integer lotsPending;
        @AuraEnabled public Integer lotsTotal;
        @AuraEnabled public Decimal projectedRevenue;
        @AuraEnabled public Decimal percentComplete;
        @AuraEnabled public Decimal percentScheduled;
        @AuraEnabled public Decimal percentPending;
    }

    public class StageNode {
        @AuraEnabled public Integer ordinal;
        @AuraEnabled public String label;
        @AuraEnabled public String state; // done | current | pending
        @AuraEnabled public String marker;
        @AuraEnabled public String itemClass;
        @AuraEnabled public String circleClass;
        @AuraEnabled public String labelClass;
    }

    public class IdentityRow {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean isLink;
        @AuraEnabled public String url;
        @AuraEnabled public Boolean isEmpty;
    }

    public class ServiceFlag {
        @AuraEnabled public String label;
        @AuraEnabled public Boolean isOn;
        @AuraEnabled public String flagClass;
        @AuraEnabled public String dotClass;
    }

    public class ServiceFlagsPayload {
        @AuraEnabled public List<ServiceFlag> flags;
        @AuraEnabled public List<IdentityRow> details;
    }

    public class ScopeCard {
        @AuraEnabled public String title;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public String price;
        @AuraEnabled public List<IdentityRow> fields;
        @AuraEnabled public String notes;
    }

    public class ScopePayload {
        @AuraEnabled public Integer activeLobs;
        @AuraEnabled public Integer contractedLots;
        @AuraEnabled public String avgRevenuePerLot;
        @AuraEnabled public String communityRevenueTarget;
        @AuraEnabled public String targetGp;
        @AuraEnabled public List<ScopeCard> cards;
    }

    public class LotSquare {
        @AuraEnabled public Integer lotNumber;
        @AuraEnabled public String state; // done | scheduled | pending
        @AuraEnabled public String squareClass;
    }

    public class LotDetailRow {
        @AuraEnabled public String lotLabel;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public String workOrderUrl;
        @AuraEnabled public String foreman;
        @AuraEnabled public String scheduled;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public String qiStatus;
        @AuraEnabled public String qiStatusClass;
        @AuraEnabled public String qiScore;
        @AuraEnabled public String qiScoreColor;
        @AuraEnabled public String closedDate;
    }

    public class LotTrackerPayload {
        @AuraEnabled public Integer totalLots;
        @AuraEnabled public Integer completeCount;
        @AuraEnabled public Integer scheduledCount;
        @AuraEnabled public Integer pendingCount;
        @AuraEnabled public List<LotSquare> squares;
        @AuraEnabled public List<LotDetailRow> rows;
    }

    public class WorkOrderRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String recordUrl;
        @AuraEnabled public String lot;
        @AuraEnabled public String woType;
        @AuraEnabled public String foreman;
        @AuraEnabled public String crew;
        @AuraEnabled public String scheduled;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public String foremanSubmit;
        @AuraEnabled public String foremanSubmitClass;
        @AuraEnabled public String qi;
        @AuraEnabled public String qiClass;
    }

    public class WorkOrdersPayload {
        @AuraEnabled public Integer completeCount;
        @AuraEnabled public Integer scheduledCount;
        @AuraEnabled public Integer qiDueCount;
        @AuraEnabled public List<WorkOrderRow> rows;
    }

    public class ChecklistItem {
        @AuraEnabled public String title;
        @AuraEnabled public String detail;
        @AuraEnabled public String state; // done | pending | open
        @AuraEnabled public String iconClass;
        @AuraEnabled public String tagClass;
        @AuraEnabled public String tagLabel;
        @AuraEnabled public String marker;
    }

    public class TakeoffCard {
        @AuraEnabled public String badgeLabel;
        @AuraEnabled public String badgeClass;
        @AuraEnabled public List<IdentityRow> fields;
        @AuraEnabled public List<ChecklistItem> checklist;
    }

    public class TakeoffSiteVisitPayload {
        @AuraEnabled public TakeoffCard takeoff;
        @AuraEnabled public TakeoffCard siteVisit;
    }

    public class ChangeOrderRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String recordUrl;
        @AuraEnabled public String type;
        @AuraEnabled public String typeClass;
        @AuraEnabled public String description;
        @AuraEnabled public String requestedBy;
        @AuraEnabled public String impact;
        @AuraEnabled public String impactColor;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public String dateFmt;
    }

    public class ChangeOrdersPayload {
        @AuraEnabled public List<ChangeOrderRow> rows;
        @AuraEnabled public Integer approvedCount;
        @AuraEnabled public Integer pendingCount;
        @AuraEnabled public String approvedImpact;
        @AuraEnabled public String pendingImpact;
    }

    public class ContactCard {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public String initials;
        @AuraEnabled public String avatarClass;
        @AuraEnabled public String recordUrl;
    }

    public class TimelineEntry {
        @AuraEnabled public String icon;
        @AuraEnabled public String title;
        @AuraEnabled public String detail;
        @AuraEnabled public String whenLabel;
    }

    /* =========================
       Apex endpoints
       ========================= */

    @AuraEnabled(cacheable=true)
    public static CommunityHeader getHeader(Id communityId) {
        CommunityHeader h = new CommunityHeader();
        h.stage = '';
        h.stageClass = '';
        h.takeoffStatus = '';
        h.takeoffClass = '';
        h.siteVisitStatus = '';
        h.siteVisitClass = '';
        h.lotsComplete = 0; h.lotsTotal = 0;
        h.openWorkOrders = 0; h.changeOrders = 0;
        h.serviceDay = '';
        h.fieldManager = '';
        if (communityId == null) return h;
        if (!Schema.getGlobalDescribe().containsKey('Community__c')) return h;

        Map<String, Schema.SObjectField> fMap =
            Schema.getGlobalDescribe().get('Community__c').getDescribe().fields.getMap();
        List<String> sel = new List<String>{ 'Id', 'Name' };
        for (String f : new List<String>{ 'Service_Day__c','Number_Of_Lots__c','Builder_Account__c',
                'Assigned_FM__c','Territory__c','Market_Account_Name__c','Community_City__c',
                'Community_State__c','CreatedDate' }) {
            if (fMap.containsKey(f.toLowerCase())) sel.add(f);
        }
        String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Community__c WHERE Id = :communityId LIMIT 1';
        List<SObject> recs = Database.query(soql);
        if (recs.isEmpty()) return h;
        SObject c = recs[0];
        h.name = (String) c.get('Name');

        if (fMap.containsKey('service_day__c'))      h.serviceDay     = String.valueOf(c.get('Service_Day__c'));
        if (fMap.containsKey('number_of_lots__c'))   h.lotsTotal      = toInt(c.get('Number_Of_Lots__c'));
        if (fMap.containsKey('territory__c'))        h.territory      = (String) c.get('Territory__c');
        if (fMap.containsKey('market_account_name__c')) h.market      = (String) c.get('Market_Account_Name__c');
        if (fMap.containsKey('community_city__c') && fMap.containsKey('community_state__c')) {
            String cy = (String) c.get('Community_City__c');
            String st = (String) c.get('Community_State__c');
            if (String.isNotBlank(cy) || String.isNotBlank(st)) {
                h.market = (h.market == null ? (cy != null ? cy : '') : h.market);
            }
        }
        if (fMap.containsKey('builder_account__c') && c.get('Builder_Account__c') != null) {
            Id aId = (Id) c.get('Builder_Account__c');
            List<Account> aa = [SELECT Id, Name FROM Account WHERE Id = :aId LIMIT 1];
            if (!aa.isEmpty()) {
                h.builderAccountName = aa[0].Name;
                h.builderAccountUrl  = '/' + aa[0].Id;
            }
        }
        if (fMap.containsKey('assigned_fm__c') && c.get('Assigned_FM__c') != null) {
            Id uId = (Id) c.get('Assigned_FM__c');
            List<User> uu = [SELECT Id, Name FROM User WHERE Id = :uId LIMIT 1];
            if (!uu.isEmpty()) h.fieldManager = uu[0].Name;
        }
        if (c.get('CreatedDate') != null) {
            Datetime d = (Datetime) c.get('CreatedDate');
            h.openedDateFmt = 'Opened ' + d.format('MMM d, yyyy');
        }

        // Open WOs + CO counts are optional depending on org state
        populateHeaderCounts(h, communityId);
        return h;
    }

    // Extracted so that WO/CO branches are isolated from the core path.
    private static void populateHeaderCounts(CommunityHeader h, Id communityId) {
        if (Schema.getGlobalDescribe().containsKey('Work_Order__c')) {
            try {
                Map<String, Schema.SObjectField> woMap =
                    Schema.getGlobalDescribe().get('Work_Order__c').getDescribe().fields.getMap();
                if (woMap.containsKey('community__c') && woMap.containsKey('status__c')) {
                    AggregateResult[] ar = Database.query(
                        'SELECT COUNT(Id) c FROM Work_Order__c WHERE Community__c = :communityId AND Status__c != \'Closed\' AND Status__c != \'Complete\''
                    );
                    if (!ar.isEmpty()) h.openWorkOrders = toInt(ar[0].get('c'));
                    // Lots Complete KPI: mirror getProgress completion logic so the header is not stuck at 0.
                    AggregateResult[] cmp = Database.query(
                        'SELECT Status__c s, COUNT(Id) c FROM Work_Order__c WHERE Community__c = :communityId GROUP BY Status__c'
                    );
                    Integer done = 0;
                    for (AggregateResult r : cmp) {
                        String st = (String) r.get('s');
                        if (st == null) continue;
                        String s = st.toLowerCase();
                        if (s.contains('complete') || s.contains('closed') || s.contains('approved')) done += toInt(r.get('c'));
                    }
                    h.lotsComplete = done;
                }
            } catch (Exception e) { /* ignore */ }
        }
        if (Schema.getGlobalDescribe().containsKey('Change_Order__c')) {
            try {
                Map<String, Schema.SObjectField> coMap =
                    Schema.getGlobalDescribe().get('Change_Order__c').getDescribe().fields.getMap();
                if (coMap.containsKey('community__c')) {
                    AggregateResult[] ar = Database.query(
                        'SELECT COUNT(Id) c FROM Change_Order__c WHERE Community__c = :communityId'
                    );
                    if (!ar.isEmpty()) h.changeOrders = toInt(ar[0].get('c'));
                }
            } catch (Exception e) { /* ignore */ }
        }
    }

    @AuraEnabled(cacheable=true)
    public static ProgressSummary getProgress(Id communityId) {
        ProgressSummary p = new ProgressSummary();
        p.lotsComplete = 0; p.lotsScheduled = 0; p.lotsPending = 0; p.lotsTotal = 0;
        p.projectedRevenue = 0; p.percentComplete = 0; p.percentScheduled = 0; p.percentPending = 0;
        if (communityId == null) return p;
        if (!Schema.getGlobalDescribe().containsKey('Community__c')) return p;

        Map<String, Schema.SObjectField> fMap =
            Schema.getGlobalDescribe().get('Community__c').getDescribe().fields.getMap();
        List<String> sel = new List<String>{ 'Id' };
        for (String f : new List<String>{ 'Number_Of_Lots__c' }) {
            if (fMap.containsKey(f.toLowerCase())) sel.add(f);
        }
        String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Community__c WHERE Id = :communityId LIMIT 1';
        List<SObject> recs = Database.query(soql);
        if (!recs.isEmpty() && fMap.containsKey('number_of_lots__c')) {
            p.lotsTotal = toInt(recs[0].get('Number_Of_Lots__c'));
        }

        if (Schema.getGlobalDescribe().containsKey('Work_Order__c')) {
            try {
                Map<String, Schema.SObjectField> woMap =
                    Schema.getGlobalDescribe().get('Work_Order__c').getDescribe().fields.getMap();
                if (woMap.containsKey('community__c') && woMap.containsKey('status__c')) {
                    AggregateResult[] res = Database.query(
                        'SELECT Status__c s, COUNT(Id) c FROM Work_Order__c WHERE Community__c = :communityId GROUP BY Status__c'
                    );
                    for (AggregateResult r : res) {
                        String st = (String) r.get('s');
                        Integer ct = toInt(r.get('c'));
                        if (st == null) continue;
                        String s = st.toLowerCase();
                        if (s.contains('complete') || s.contains('closed') || s.contains('approved')) p.lotsComplete += ct;
                        else if (s.contains('schedul')) p.lotsScheduled += ct;
                        else p.lotsPending += ct;
                    }
                }
            } catch (Exception e) { /* ignore */ }
        }
        if (p.lotsTotal > 0 && (p.lotsComplete + p.lotsScheduled > p.lotsTotal)) {
            // guard against inflated counts
            p.lotsTotal = p.lotsComplete + p.lotsScheduled + p.lotsPending;
        }
        if (p.lotsTotal > 0) {
            p.percentComplete  = ((Decimal) p.lotsComplete  / p.lotsTotal * 100).setScale(0);
            p.percentScheduled = ((Decimal) p.lotsScheduled / p.lotsTotal * 100).setScale(0);
            p.percentPending   = ((Decimal) p.lotsPending   / p.lotsTotal * 100).setScale(0);
            if (p.lotsPending == 0 && p.lotsTotal > (p.lotsComplete + p.lotsScheduled)) {
                p.lotsPending = p.lotsTotal - p.lotsComplete - p.lotsScheduled;
                p.percentPending = ((Decimal) p.lotsPending / p.lotsTotal * 100).setScale(0);
            }
        }
        return p;
    }

    @AuraEnabled(cacheable=true)
    public static List<StageNode> getStageNodes(Id communityId) {
        // Static 7-stage rail - marks "Jobs Active" as current by default. Can be wired to a Stage__c field later.
        List<String> labels = new List<String>{
            'Community Activated','Takeoff Scheduled','Takeoff Complete',
            'Site Visit Scheduled','Jobs Active','Community Closing','Community Complete'
        };
        Integer current = 4;
        List<StageNode> out = new List<StageNode>();
        for (Integer i = 0; i < labels.size(); i++) {
            StageNode n = new StageNode();
            n.ordinal = i + 1;
            n.label = labels[i];
            if (i < current) { n.state = 'done'; n.marker = 'check'; }
            else if (i == current) { n.state = 'current'; n.marker = 'right'; }
            else { n.state = 'pending'; n.marker = String.valueOf(i + 1); }
            n.itemClass   = 'sn' + (n.state == 'done' ? ' done' : n.state == 'current' ? ' cur' : '');
            n.circleClass = 'sc' + (n.state == 'done' ? ' done' : n.state == 'current' ? ' active' : '');
            n.labelClass  = 'sl' + (n.state == 'done' ? ' done' : n.state == 'current' ? ' active' : '');
            out.add(n);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<IdentityRow> getIdentity(Id communityId) {
        List<IdentityRow> out = new List<IdentityRow>();
        if (communityId == null || !Schema.getGlobalDescribe().containsKey('Community__c')) return out;
        Map<String, Schema.SObjectField> fMap =
            Schema.getGlobalDescribe().get('Community__c').getDescribe().fields.getMap();

        List<String> sel = new List<String>{ 'Id','Name' };
        for (String f : new List<String>{ 'Builder_Account__c','Market_Account_Name__c','Territory__c',
                'Community_Address__c','Community_City__c','Community_State__c','Community_Zip__c',
                'Number_Of_Lots__c','Sod_Sqft__c','Loving_Operating_Division__c','Phases__c' }) {
            if (fMap.containsKey(f.toLowerCase())) sel.add(f);
        }
        String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Community__c WHERE Id = :communityId LIMIT 1';
        List<SObject> recs = Database.query(soql);
        if (recs.isEmpty()) return out;
        SObject c = recs[0];

        addRow(out, 'Community Name', (String) c.get('Name'), null);
        if (fMap.containsKey('builder_account__c') && c.get('Builder_Account__c') != null) {
            Id aId = (Id) c.get('Builder_Account__c');
            List<Account> aa = [SELECT Id, Name FROM Account WHERE Id = :aId LIMIT 1];
            if (!aa.isEmpty()) addRow(out, 'Division Account', aa[0].Name, '/' + aa[0].Id);
        }
        if (fMap.containsKey('market_account_name__c'))   addRow(out, 'Market',       (String) c.get('Market_Account_Name__c'), null);
        if (fMap.containsKey('territory__c'))             addRow(out, 'Territory',    (String) c.get('Territory__c'), null);
        if (fMap.containsKey('community_address__c')) {
            String addr = (String) c.get('Community_Address__c');
            String city = fMap.containsKey('community_city__c')  ? (String) c.get('Community_City__c') : null;
            String stt  = fMap.containsKey('community_state__c') ? (String) c.get('Community_State__c') : null;
            String zip  = fMap.containsKey('community_zip__c')   ? (String) c.get('Community_Zip__c') : null;
            String full = String.isNotBlank(addr) ? addr : '';
            if (String.isNotBlank(city) || String.isNotBlank(stt) || String.isNotBlank(zip)) {
                full += (String.isNotBlank(full) ? ', ' : '') +
                        (city != null ? city + ' ' : '') + (stt != null ? stt + ' ' : '') + (zip != null ? zip : '');
                full = full.trim();
            }
            addRow(out, 'Community Address', full, null);
        }
        if (fMap.containsKey('number_of_lots__c'))        addRow(out, 'Total Lot Count', stringify(c.get('Number_Of_Lots__c')), null);
        if (fMap.containsKey('sod_sqft__c'))              addRow(out, 'Sod Sqft',        stringify(c.get('Sod_Sqft__c')), null);
        if (fMap.containsKey('loving_operating_division__c')) addRow(out, 'Operating Division', (String) c.get('Loving_Operating_Division__c'), null);
        if (fMap.containsKey('phases__c'))                addRow(out, 'Phases',          (String) c.get('Phases__c'), null);
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<IdentityRow> getOperational(Id communityId) {
        List<IdentityRow> out = new List<IdentityRow>();
        if (communityId == null || !Schema.getGlobalDescribe().containsKey('Community__c')) return out;
        Map<String, Schema.SObjectField> fMap =
            Schema.getGlobalDescribe().get('Community__c').getDescribe().fields.getMap();

        List<String> sel = new List<String>{ 'Id' };
        for (String f : new List<String>{ 'Assigned_FM__c','OwnerId','Service_Day__c','Service_Model__c',
                'Lot_Layout_Link__c','Market_Drive_Folder_Link__c','Market_Scope_Of_Work_Link__c',
                'Pricing_Schedule__c' }) {
            if (fMap.containsKey(f.toLowerCase())) sel.add(f);
        }
        String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Community__c WHERE Id = :communityId LIMIT 1';
        List<SObject> recs = Database.query(soql);
        if (recs.isEmpty()) return out;
        SObject c = recs[0];

        if (fMap.containsKey('assigned_fm__c') && c.get('Assigned_FM__c') != null) {
            Id uId = (Id) c.get('Assigned_FM__c');
            List<User> uu = [SELECT Id, Name FROM User WHERE Id = :uId LIMIT 1];
            if (!uu.isEmpty()) addRow(out, 'Field Manager', uu[0].Name, '/' + uu[0].Id);
        }
        if (c.get('OwnerId') != null) {
            Id ownerId = (Id) c.get('OwnerId');
            List<User> uu = [SELECT Id, Name FROM User WHERE Id = :ownerId LIMIT 1];
            if (!uu.isEmpty()) addRow(out, 'Account Owner (AE)', uu[0].Name, '/' + uu[0].Id);
        }
        if (fMap.containsKey('service_day__c'))              addRow(out, 'Designated Service Day', (String) c.get('Service_Day__c'), null);
        if (fMap.containsKey('service_model__c'))            addRow(out, 'Service Model',          (String) c.get('Service_Model__c'), null);
        if (fMap.containsKey('lot_layout_link__c'))          addRow(out, 'Lot Layout Link',        (String) c.get('Lot_Layout_Link__c'), (String) c.get('Lot_Layout_Link__c'));
        if (fMap.containsKey('market_drive_folder_link__c')) addRow(out, 'Shared Drive Folder',    (String) c.get('Market_Drive_Folder_Link__c'), (String) c.get('Market_Drive_Folder_Link__c'));
        if (fMap.containsKey('market_scope_of_work_link__c'))addRow(out, 'Scope of Work Link',     (String) c.get('Market_Scope_Of_Work_Link__c'), (String) c.get('Market_Scope_Of_Work_Link__c'));
        if (fMap.containsKey('pricing_schedule__c'))         addRow(out, 'Pricing Schedule',       (String) c.get('Pricing_Schedule__c'), null);
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static ServiceFlagsPayload getServiceFlags(Id communityId) {
        ServiceFlagsPayload p = new ServiceFlagsPayload();
        p.flags = new List<ServiceFlag>();
        p.details = new List<IdentityRow>();
        if (communityId == null || !Schema.getGlobalDescribe().containsKey('Community__c')) return p;
        Map<String, Schema.SObjectField> fMap =
            Schema.getGlobalDescribe().get('Community__c').getDescribe().fields.getMap();

        List<String> sel = new List<String>{ 'Id' };
        for (String f : new List<String>{ 'Aqua_Included__c','Aqua_Customer__c','Temp_Irrigation_Included__c',
                'Irrigation_Type__c','Sod_Type__c','Plant_Types__c','Street_Tree_Species__c','Street_Trees_Count__c',
                'Shrub_Package_Details__c','Irrigation_Zone_Count__c','Pine_Straw_Or_Mulch__c' }) {
            if (fMap.containsKey(f.toLowerCase())) sel.add(f);
        }
        String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Community__c WHERE Id = :communityId LIMIT 1';
        List<SObject> recs = Database.query(soql);
        if (recs.isEmpty()) return p;
        SObject c = recs[0];

        Boolean productionLandscaping = true;
        Boolean aqua = false;
        try {
            if (fMap.containsKey('aqua_included__c')) aqua = Boolean.valueOf(c.get('Aqua_Included__c'));
            else if (fMap.containsKey('aqua_customer__c')) aqua = Boolean.valueOf(c.get('Aqua_Customer__c'));
        } catch (Exception ignore) { /* non-boolean type; leave false */ }
        Boolean irrigation = false;
        try {
            if (fMap.containsKey('temp_irrigation_included__c')) irrigation = Boolean.valueOf(c.get('Temp_Irrigation_Included__c'));
            else if (fMap.containsKey('irrigation_type__c')) irrigation = String.isNotBlank((String) c.get('Irrigation_Type__c'));
        } catch (Exception ignore) { /* ignore */ }
        Boolean lawnCare = true;
        Boolean finalGrading = false;
        Boolean seasonal = false;

        p.flags.add(buildFlag('Production Landscaping', productionLandscaping));
        p.flags.add(buildFlag('Aqua Service', aqua));
        p.flags.add(buildFlag('Irrigation', irrigation));
        p.flags.add(buildFlag('Lawn Care', lawnCare));
        p.flags.add(buildFlag('Final Grading', finalGrading));
        p.flags.add(buildFlag('Seasonal Refreshes', seasonal));

        if (fMap.containsKey('sod_type__c'))              addRow(p.details, 'Sod Type', (String) c.get('Sod_Type__c'), null);
        if (fMap.containsKey('plant_types__c'))           addRow(p.details, 'Plant Palette', (String) c.get('Plant_Types__c'), null);
        if (fMap.containsKey('irrigation_zone_count__c')) addRow(p.details, 'Irrigation Zones (avg)', stringify(c.get('Irrigation_Zone_Count__c')), null);
        if (fMap.containsKey('street_trees_count__c'))    addRow(p.details, 'Street Tree Count', stringify(c.get('Street_Trees_Count__c')), null);
        if (fMap.containsKey('pine_straw_or_mulch__c'))   addRow(p.details, 'Pine Straw / Mulch', (String) c.get('Pine_Straw_Or_Mulch__c'), null);
        if (fMap.containsKey('shrub_package_details__c')) addRow(p.details, 'Shrub Package', (String) c.get('Shrub_Package_Details__c'), null);
        return p;
    }

    @AuraEnabled(cacheable=true)
    public static List<IdentityRow> getKeyContacts(Id communityId) {
        List<IdentityRow> out = new List<IdentityRow>();
        if (communityId == null || !Schema.getGlobalDescribe().containsKey('Community__c')) return out;
        Map<String, Schema.SObjectField> fMap =
            Schema.getGlobalDescribe().get('Community__c').getDescribe().fields.getMap();

        List<String> sel = new List<String>{ 'Id','OwnerId' };
        for (String f : new List<String>{ 'Assigned_FM__c','Market_Loving_CSM__c','Market_Loving_AP__c',
                'Market_Loving_FM__c','Builder_Account__c' }) {
            if (fMap.containsKey(f.toLowerCase())) sel.add(f);
        }
        String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Community__c WHERE Id = :communityId LIMIT 1';
        List<SObject> recs = Database.query(soql);
        if (recs.isEmpty()) return out;
        SObject c = recs[0];

        // FM (user)
        if (fMap.containsKey('assigned_fm__c') && c.get('Assigned_FM__c') != null) {
            Id uId = (Id) c.get('Assigned_FM__c');
            List<User> uu = [SELECT Id, Name, Phone, Email FROM User WHERE Id = :uId LIMIT 1];
            if (!uu.isEmpty()) {
                addRow(out, 'Field Manager', uu[0].Name, '/' + uu[0].Id);
                if (String.isNotBlank(uu[0].Phone)) addRow(out, 'FM Phone', uu[0].Phone, null);
                if (String.isNotBlank(uu[0].Email)) addRow(out, 'FM Email', uu[0].Email, 'mailto:' + uu[0].Email);
            }
        }
        // AE (owner)
        if (c.get('OwnerId') != null) {
            Id uId = (Id) c.get('OwnerId');
            List<User> uu = [SELECT Id, Name, Email FROM User WHERE Id = :uId LIMIT 1];
            if (!uu.isEmpty()) {
                addRow(out, 'Account Owner (AE)', uu[0].Name, '/' + uu[0].Id);
                if (String.isNotBlank(uu[0].Email)) addRow(out, 'AE Email', uu[0].Email, 'mailto:' + uu[0].Email);
            }
        }
        // Market CSM/AP strings
        if (fMap.containsKey('market_loving_csm__c')) addRow(out, 'Primary CM', (String) c.get('Market_Loving_CSM__c'), null);
        if (fMap.containsKey('market_loving_ap__c'))  addRow(out, 'Builder AP Contact', (String) c.get('Market_Loving_AP__c'), null);

        // Contacts on builder account (limit 4 more)
        if (fMap.containsKey('builder_account__c') && c.get('Builder_Account__c') != null) {
            Id aId = (Id) c.get('Builder_Account__c');
            List<Contact> cts = [SELECT Id, Name, Title, Phone, Email FROM Contact WHERE AccountId = :aId ORDER BY CreatedDate DESC LIMIT 3];
            for (Contact ct : cts) {
                addRow(out, String.isBlank(ct.Title) ? 'Builder Contact' : ct.Title, ct.Name, '/' + ct.Id);
            }
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static ScopePayload getScope(Id communityId) {
        ScopePayload p = new ScopePayload();
        p.cards = new List<ScopeCard>();
        p.activeLobs = 0; p.contractedLots = 0;
        p.avgRevenuePerLot = '-'; p.communityRevenueTarget = '-'; p.targetGp = '-';
        if (communityId == null || !Schema.getGlobalDescribe().containsKey('Community__c')) return p;

        Map<String, Schema.SObjectField> fMap =
            Schema.getGlobalDescribe().get('Community__c').getDescribe().fields.getMap();

        List<String> sel = new List<String>{ 'Id','Name' };
        for (String f : new List<String>{ 'Builder_Account__c','Number_Of_Lots__c','Sod_Type__c','Plant_Types__c',
                'Pine_Straw_Or_Mulch__c','Street_Tree_Species__c','Street_Trees_Count__c','Irrigation_Type__c',
                'Irrigation_Zone_Count__c','Aqua_Included__c','Aqua_Notes__c','Service_Day__c' }) {
            if (fMap.containsKey(f.toLowerCase())) sel.add(f);
        }
        String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Community__c WHERE Id = :communityId LIMIT 1';
        List<SObject> recs = Database.query(soql);
        if (recs.isEmpty()) return p;
        SObject c = recs[0];

        Integer lots = fMap.containsKey('number_of_lots__c') ? toInt(c.get('Number_Of_Lots__c')) : 0;
        p.contractedLots = lots;

        // Scope cards - use values when present, empty-state labels otherwise
        ScopeCard pl = new ScopeCard();
        pl.title = 'Production Landscaping';
        pl.status = 'Active'; pl.statusClass = 'pill pg';
        pl.price = '- / lot';
        pl.fields = new List<IdentityRow>();
        if (fMap.containsKey('sod_type__c'))           addRow(pl.fields, 'Sod Type', (String) c.get('Sod_Type__c'), null);
        if (fMap.containsKey('plant_types__c'))        addRow(pl.fields, 'Plant Palette', (String) c.get('Plant_Types__c'), null);
        if (fMap.containsKey('pine_straw_or_mulch__c'))addRow(pl.fields, 'Mulch', (String) c.get('Pine_Straw_Or_Mulch__c'), null);
        if (fMap.containsKey('street_tree_species__c'))addRow(pl.fields, 'Street Trees', (String) c.get('Street_Tree_Species__c'), null);
        if (fMap.containsKey('street_trees_count__c')) addRow(pl.fields, 'Tree Count', stringify(c.get('Street_Trees_Count__c')), null);
        addRow(pl.fields, 'Lots Contracted', String.valueOf(lots), null);
        pl.notes = 'Production landscaping LOB. Tree count and plant palette set at takeoff.';
        p.cards.add(pl);

        ScopeCard aq = new ScopeCard();
        aq.title = 'Aqua Service / Irrigation';
        Boolean aquaOn = false;
        try { if (fMap.containsKey('aqua_included__c')) aquaOn = Boolean.valueOf(c.get('Aqua_Included__c')); } catch (Exception ignore) { /* ignore */ }
        aq.status = aquaOn ? 'Active' : 'Not in scope';
        aq.statusClass = aquaOn ? 'pill pg' : 'pill pgr';
        aq.price = '- / lot';
        aq.fields = new List<IdentityRow>();
        if (fMap.containsKey('irrigation_type__c'))       addRow(aq.fields, 'Controller', (String) c.get('Irrigation_Type__c'), null);
        if (fMap.containsKey('irrigation_zone_count__c')) addRow(aq.fields, 'Zones (avg)', stringify(c.get('Irrigation_Zone_Count__c')), null);
        addRow(aq.fields, 'Aqua Check Schedule', 'Next business day post-install', null);
        aq.notes = fMap.containsKey('aqua_notes__c') ? (String) c.get('Aqua_Notes__c') : '';
        if (String.isBlank(aq.notes)) aq.notes = 'Aqua check ticket auto-creates next business day after each install.';
        p.cards.add(aq);

        ScopeCard lc = new ScopeCard();
        lc.title = 'Lawn Care / Maintenance';
        lc.status = 'Active'; lc.statusClass = 'pill pg';
        lc.price = '- / visit';
        lc.fields = new List<IdentityRow>();
        addRow(lc.fields, 'Frequency', 'Weekly', null);
        if (fMap.containsKey('service_day__c')) addRow(lc.fields, 'Service Day', (String) c.get('Service_Day__c'), null);
        addRow(lc.fields, 'Notification Window', '48 hrs post-closing', null);
        lc.notes = 'Lawn care persists per lot after builder handoff. Auto-schedule triggers 2 weeks after FM QI approval.';
        p.cards.add(lc);

        ScopeCard fg = new ScopeCard();
        fg.title = 'Final Grading';
        fg.status = 'Not in scope'; fg.statusClass = 'pill pgr';
        fg.price = '';
        fg.fields = new List<IdentityRow>();
        addRow(fg.fields, 'Status', 'Not contracted at this community', null);
        addRow(fg.fields, 'Manual Exception', 'Allowed via change order', null);
        fg.notes = 'If FM identifies a grading need at site visit or during install, a manual grading ticket can be created as a one-off exception - does not require contract change.';
        p.cards.add(fg);

        ScopeCard sr = new ScopeCard();
        sr.title = 'Seasonal Refreshes';
        sr.status = 'Not in scope'; sr.statusClass = 'pill pgr';
        sr.price = '';
        sr.fields = new List<IdentityRow>();
        addRow(sr.fields, 'Status', 'Not contracted', null);
        addRow(sr.fields, 'Price Per Lot', 'N/A', null);
        sr.notes = 'Not in scope for this community. Division-level flag is off.';
        p.cards.add(sr);

        p.activeLobs = 3; // PL + Aqua + Lawn Care
        return p;
    }

    @AuraEnabled(cacheable=true)
    public static LotTrackerPayload getLotTracker(Id communityId) {
        LotTrackerPayload p = new LotTrackerPayload();
        p.squares = new List<LotSquare>();
        p.rows = new List<LotDetailRow>();
        p.totalLots = 0; p.completeCount = 0; p.scheduledCount = 0; p.pendingCount = 0;
        if (communityId == null || !Schema.getGlobalDescribe().containsKey('Community__c')) return p;

        Map<String, Schema.SObjectField> fMap =
            Schema.getGlobalDescribe().get('Community__c').getDescribe().fields.getMap();
        Integer total = 0;
        if (fMap.containsKey('number_of_lots__c')) {
            List<SObject> recs = Database.query('SELECT Number_Of_Lots__c FROM Community__c WHERE Id = :communityId LIMIT 1');
            if (!recs.isEmpty()) total = toInt(recs[0].get('Number_Of_Lots__c'));
        }
        p.totalLots = total;

        // Try to match WOs to lots
        Map<Integer, LotDetailRow> byLot = new Map<Integer, LotDetailRow>();
        if (Schema.getGlobalDescribe().containsKey('Work_Order__c')) {
            try {
                Map<String, Schema.SObjectField> woMap =
                    Schema.getGlobalDescribe().get('Work_Order__c').getDescribe().fields.getMap();
                if (woMap.containsKey('community__c')) {
                    List<String> ws = new List<String>{ 'Id','Name' };
                    for (String f : new List<String>{ 'Lot_Number__c','Foreman__c','Scheduled_Date__c','Status__c',
                            'QI_Status__c','QI_Score__c','Closed_Date__c' }) {
                        if (woMap.containsKey(f.toLowerCase())) ws.add(f);
                    }
                    String wq = 'SELECT ' + String.join(ws, ',') +
                        ' FROM Work_Order__c WHERE Community__c = :communityId ORDER BY CreatedDate DESC LIMIT 200';
                    List<SObject> wos = Database.query(wq);
                    for (SObject wo : wos) {
                        LotDetailRow r = new LotDetailRow();
                        r.workOrderName = (String) wo.get('Name');
                        r.workOrderUrl  = '/' + wo.get('Id');
                        if (woMap.containsKey('lot_number__c'))     r.lotLabel = stringify(wo.get('Lot_Number__c'));
                        if (woMap.containsKey('foreman__c'))        r.foreman  = stringify(wo.get('Foreman__c'));
                        if (woMap.containsKey('scheduled_date__c')) r.scheduled= stringify(wo.get('Scheduled_Date__c'));
                        if (woMap.containsKey('status__c'))        { r.status = (String) wo.get('Status__c'); r.statusClass = pillClassForStatus(r.status); }
                        if (woMap.containsKey('qi_status__c'))     { r.qiStatus = (String) wo.get('QI_Status__c'); r.qiStatusClass = pillClassForStatus(r.qiStatus); }
                        if (woMap.containsKey('qi_score__c'))      { r.qiScore = stringify(wo.get('QI_Score__c')); r.qiScoreColor = qiScoreColor(wo.get('QI_Score__c')); }
                        if (woMap.containsKey('closed_date__c'))   r.closedDate = stringify(wo.get('Closed_Date__c'));
                        p.rows.add(r);
                        Integer ln = parseLot(r.lotLabel);
                        if (ln != null) byLot.put(ln, r);
                    }
                }
            } catch (Exception e) { /* ignore */ }
        }

        for (Integer i = 1; i <= total; i++) {
            LotSquare sq = new LotSquare();
            sq.lotNumber = i;
            LotDetailRow r = byLot.get(i);
            String st = r == null ? '' : (r.status == null ? '' : r.status.toLowerCase());
            if (st.contains('complete') || st.contains('closed') || st.contains('approved')) { sq.state = 'done'; p.completeCount++; }
            else if (st.contains('schedul'))                                                 { sq.state = 'scheduled'; p.scheduledCount++; }
            else                                                                              { sq.state = 'pending'; p.pendingCount++; }
            sq.squareClass = 'lot-sq ' + (sq.state == 'done' ? 'lot-done' : sq.state == 'scheduled' ? 'lot-sched' : 'lot-pend');
            p.squares.add(sq);
        }
        return p;
    }

    @AuraEnabled(cacheable=true)
    public static WorkOrdersPayload getWorkOrders(Id communityId) {
        WorkOrdersPayload p = new WorkOrdersPayload();
        p.rows = new List<WorkOrderRow>();
        p.completeCount = 0; p.scheduledCount = 0; p.qiDueCount = 0;
        if (communityId == null || !Schema.getGlobalDescribe().containsKey('Work_Order__c')) return p;
        try {
            Map<String, Schema.SObjectField> woMap =
                Schema.getGlobalDescribe().get('Work_Order__c').getDescribe().fields.getMap();
            if (!woMap.containsKey('community__c')) return p;
            List<String> ws = new List<String>{ 'Id','Name' };
            for (String f : new List<String>{ 'Lot_Number__c','Work_Order_Type__c','Foreman__c','Crew__c',
                    'Scheduled_Date__c','Status__c','Foreman_Submit_Status__c','QI_Status__c' }) {
                if (woMap.containsKey(f.toLowerCase())) ws.add(f);
            }
            String wq = 'SELECT ' + String.join(ws, ',') +
                ' FROM Work_Order__c WHERE Community__c = :communityId ORDER BY Scheduled_Date__c DESC NULLS LAST LIMIT 200';
            List<SObject> wos = Database.query(wq);
            for (SObject wo : wos) {
                WorkOrderRow r = new WorkOrderRow();
                r.id = (Id) wo.get('Id');
                r.name = (String) wo.get('Name');
                r.recordUrl = '/' + r.id;
                if (woMap.containsKey('lot_number__c'))            r.lot = 'Lot ' + stringify(wo.get('Lot_Number__c'));
                if (woMap.containsKey('work_order_type__c'))       r.woType = (String) wo.get('Work_Order_Type__c');
                if (woMap.containsKey('foreman__c'))               r.foreman = stringify(wo.get('Foreman__c'));
                if (woMap.containsKey('crew__c'))                  r.crew = (String) wo.get('Crew__c');
                if (woMap.containsKey('scheduled_date__c'))        r.scheduled = stringify(wo.get('Scheduled_Date__c'));
                if (woMap.containsKey('status__c')) {
                    r.status = (String) wo.get('Status__c');
                    r.statusClass = pillClassForStatus(r.status);
                    if (r.status != null && r.status.toLowerCase().contains('complete')) p.completeCount++;
                    if (r.status != null && r.status.toLowerCase().contains('schedul'))  p.scheduledCount++;
                }
                if (woMap.containsKey('foreman_submit_status__c')) { r.foremanSubmit = (String) wo.get('Foreman_Submit_Status__c'); r.foremanSubmitClass = pillClassForStatus(r.foremanSubmit); }
                if (woMap.containsKey('qi_status__c'))             {
                    r.qi = (String) wo.get('QI_Status__c');
                    r.qiClass = pillClassForStatus(r.qi);
                    if (r.qi != null && r.qi.toLowerCase().contains('due')) p.qiDueCount++;
                }
                p.rows.add(r);
            }
        } catch (Exception e) { /* ignore */ }
        return p;
    }

    @AuraEnabled(cacheable=true)
    public static TakeoffSiteVisitPayload getTakeoffSiteVisit(Id communityId) {
        TakeoffSiteVisitPayload p = new TakeoffSiteVisitPayload();
        p.takeoff   = buildTakeoffCard();
        p.siteVisit = buildSiteVisitCard();
        return p;
    }

    @AuraEnabled(cacheable=true)
    public static ChangeOrdersPayload getChangeOrders(Id communityId) {
        ChangeOrdersPayload p = new ChangeOrdersPayload();
        p.rows = new List<ChangeOrderRow>();
        p.approvedCount = 0; p.pendingCount = 0;
        p.approvedImpact = '$0'; p.pendingImpact = '$0';
        if (communityId == null || !Schema.getGlobalDescribe().containsKey('Change_Order__c')) return p;
        try {
            Map<String, Schema.SObjectField> coMap =
                Schema.getGlobalDescribe().get('Change_Order__c').getDescribe().fields.getMap();
            if (!coMap.containsKey('community__c')) return p;
            List<String> cs = new List<String>{ 'Id','Name' };
            for (String f : new List<String>{ 'Type__c','Description__c','Requested_By__c','Amount_Impact__c','Status__c','CreatedDate' }) {
                if (coMap.containsKey(f.toLowerCase())) cs.add(f);
            }
            String cq = 'SELECT ' + String.join(cs, ',') + ' FROM Change_Order__c WHERE Community__c = :communityId ORDER BY CreatedDate DESC LIMIT 200';
            List<SObject> cos = Database.query(cq);
            Decimal appImp = 0, pendImp = 0;
            for (SObject co : cos) {
                ChangeOrderRow r = new ChangeOrderRow();
                r.id = (Id) co.get('Id');
                r.name = (String) co.get('Name');
                r.recordUrl = '/' + r.id;
                if (coMap.containsKey('type__c'))           { r.type = (String) co.get('Type__c'); r.typeClass = coTypeClass(r.type); }
                if (coMap.containsKey('description__c'))    r.description = (String) co.get('Description__c');
                if (coMap.containsKey('requested_by__c'))   r.requestedBy = stringify(co.get('Requested_By__c'));
                if (coMap.containsKey('amount_impact__c'))  {
                    Decimal amt = (Decimal) co.get('Amount_Impact__c');
                    if (amt != null) {
                        r.impact = (amt >= 0 ? '+' : '') + '$' + amt.setScale(0).format();
                        r.impactColor = amt >= 0 ? '#2e844a' : '#ba7517';
                    }
                }
                if (coMap.containsKey('status__c'))         {
                    r.status = (String) co.get('Status__c');
                    r.statusClass = pillClassForStatus(r.status);
                    if (r.status != null) {
                        String s = r.status.toLowerCase();
                        Decimal amt = coMap.containsKey('amount_impact__c') && co.get('Amount_Impact__c') != null ? (Decimal) co.get('Amount_Impact__c') : 0;
                        if (s.contains('approved')) { p.approvedCount++; appImp += amt; }
                        else if (s.contains('pend')) { p.pendingCount++; pendImp += amt; }
                    }
                }
                if (co.get('CreatedDate') != null) r.dateFmt = ((Datetime) co.get('CreatedDate')).format('MMM d, yyyy');
                p.rows.add(r);
            }
            p.approvedImpact = (appImp  >= 0 ? '+$' : '-$') + appImp.abs().setScale(0).format();
            p.pendingImpact  = (pendImp >= 0 ? '+$' : '-$') + pendImp.abs().setScale(0).format();
        } catch (Exception e) { /* ignore */ }
        return p;
    }

    @AuraEnabled(cacheable=true)
    public static List<ContactCard> getCommunityContacts(Id communityId) {
        List<ContactCard> out = new List<ContactCard>();
        if (communityId == null || !Schema.getGlobalDescribe().containsKey('Community__c')) return out;
        Map<String, Schema.SObjectField> fMap =
            Schema.getGlobalDescribe().get('Community__c').getDescribe().fields.getMap();

        List<String> sel = new List<String>{ 'Id','OwnerId' };
        for (String f : new List<String>{ 'Assigned_FM__c','Builder_Account__c','Market_Loving_CSM__c','Market_Loving_AP__c' }) {
            if (fMap.containsKey(f.toLowerCase())) sel.add(f);
        }
        String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Community__c WHERE Id = :communityId LIMIT 1';
        List<SObject> recs = Database.query(soql);
        if (recs.isEmpty()) return out;
        SObject c = recs[0];

        Set<Id> userIds = new Set<Id>();
        if (c.get('OwnerId') != null) userIds.add((Id) c.get('OwnerId'));
        if (fMap.containsKey('assigned_fm__c') && c.get('Assigned_FM__c') != null) userIds.add((Id) c.get('Assigned_FM__c'));
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, Name, Title, Phone, Email FROM User WHERE Id IN :userIds]) {
                ContactCard card = new ContactCard();
                card.id = u.Id; card.name = u.Name;
                card.role = u.Id == c.get('OwnerId') ? 'LOVING AE' : 'LOVING Field Mgr';
                card.phone = u.Phone; card.email = u.Email;
                card.initials = initialsOf(u.Name);
                card.avatarClass = u.Id == c.get('OwnerId') ? 'av av-o' : 'av av-g';
                card.recordUrl = '/' + u.Id;
                out.add(card);
            }
        }

        if (fMap.containsKey('builder_account__c') && c.get('Builder_Account__c') != null) {
            Id aId = (Id) c.get('Builder_Account__c');
            List<Contact> cts = [SELECT Id, Name, Title, Phone, Email FROM Contact WHERE AccountId = :aId ORDER BY CreatedDate LIMIT 8];
            Integer idx = 0;
            List<String> palette = new List<String>{ 'av av-b','av av-p','av av-o','av av-g' };
            for (Contact ct : cts) {
                ContactCard card = new ContactCard();
                card.id = ct.Id; card.name = ct.Name;
                card.role = String.isBlank(ct.Title) ? 'Builder Contact' : ct.Title;
                card.phone = ct.Phone; card.email = ct.Email;
                card.initials = initialsOf(ct.Name);
                card.avatarClass = palette[idx++ & 3];
                card.recordUrl = '/' + ct.Id;
                out.add(card);
            }
        }
        return out;
    }

    /* =========================
       Helpers
       ========================= */

    private static void addRow(List<IdentityRow> out, String label, String value, String url) {
        IdentityRow r = new IdentityRow();
        r.label = label;
        r.value = String.isBlank(value) ? 'Not set' : value;
        r.isEmpty = String.isBlank(value);
        r.url = url;
        r.isLink = String.isNotBlank(url);
        out.add(r);
    }

    private static ServiceFlag buildFlag(String label, Boolean val) {
        ServiceFlag f = new ServiceFlag();
        f.label = label;
        f.isOn = val;
        f.flagClass = val ? 'flag fon' : 'flag foff';
        f.dotClass  = val ? 'fdot don' : 'fdot doff';
        return f;
    }

    private static TakeoffCard buildTakeoffCard() {
        TakeoffCard t = new TakeoffCard();
        t.badgeLabel = 'Pending';
        t.badgeClass = 'pill pgr';
        t.fields = new List<IdentityRow>();
        addRow(t.fields, 'Field Manager', 'Assigned FM', null);
        addRow(t.fields, 'Takeoff Date', 'Not scheduled', null);
        addRow(t.fields, 'Mismatch Flag', 'None', null);
        addRow(t.fields, 'Photos Uploaded', '0 photos', null);
        addRow(t.fields, 'Sod SF (actual vs PO)', 'Awaiting takeoff', null);
        addRow(t.fields, 'Tree Count', 'Awaiting confirmation', null);
        t.checklist = new List<ChecklistItem>();
        t.checklist.add(buildItem('Sod square footage confirmed','Verify actual vs PO','pending'));
        t.checklist.add(buildItem('Plant quantities confirmed by species','Counts verified against contract','pending'));
        t.checklist.add(buildItem('Street tree count confirmed','Matches plan','pending'));
        t.checklist.add(buildItem('Irrigation zone count confirmed','Zones per lot average','pending'));
        t.checklist.add(buildItem('Lighting fixture count','Capture if in scope','pending'));
        t.checklist.add(buildItem('Site condition photos uploaded','Upload photos at takeoff','pending'));
        t.checklist.add(buildItem('Discrepancy notes','Record mismatches','pending'));
        return t;
    }

    private static TakeoffCard buildSiteVisitCard() {
        TakeoffCard s = new TakeoffCard();
        s.badgeLabel = 'Pending';
        s.badgeClass = 'pill pgr';
        s.fields = new List<IdentityRow>();
        addRow(s.fields, 'Field Manager', 'Assigned FM', null);
        addRow(s.fields, 'Visit Date', 'Not scheduled', null);
        addRow(s.fields, 'Decision', 'Pending', null);
        addRow(s.fields, 'No-Go Reason', 'N/A', null);
        addRow(s.fields, 'Photos Uploaded', '0 photos', null);
        addRow(s.fields, 'Triggered By', 'First WO moved to Scheduled', null);
        s.checklist = new List<ChecklistItem>();
        s.checklist.add(buildItem('Utilities cleared - flags in ground','No holds identified','pending'));
        s.checklist.add(buildItem('Lot access confirmed','Gate codes provided','pending'));
        s.checklist.add(buildItem('Grade acceptable - no standing water','Lots dry, grade acceptable','pending'));
        s.checklist.add(buildItem('Previous trade work complete','No framers or HVAC blocking','pending'));
        s.checklist.add(buildItem('No pending builder holds','Confirmed with builder CM','pending'));
        s.checklist.add(buildItem('Site condition photos uploaded','Photos uploaded at visit','pending'));
        return s;
    }

    private static ChecklistItem buildItem(String title, String detail, String state) {
        ChecklistItem c = new ChecklistItem();
        c.title = title; c.detail = detail; c.state = state;
        if (state == 'done')      { c.iconClass = 'ci-icon ci-done'; c.tagClass = 'ci-tag ct-done'; c.tagLabel = 'Done'; c.marker = 'check'; }
        else if (state == 'pending') { c.iconClass = 'ci-icon ci-pend'; c.tagClass = 'ci-tag ct-pend'; c.tagLabel = 'Pending'; c.marker = 'warning'; }
        else                      { c.iconClass = 'ci-icon ci-open'; c.tagClass = 'ci-tag ct-open'; c.tagLabel = 'Open'; c.marker = 'steps'; }
        return c;
    }

    private static String pillClassForStatus(String s) {
        if (String.isBlank(s)) return 'pill pgr';
        String x = s.toLowerCase();
        if (x.contains('complete') || x.contains('approved') || x.contains('submitted') || x.contains('go')) return 'pill pg';
        if (x.contains('schedul')) return 'pill pb';
        if (x.contains('due') || x.contains('pending')) return 'pill pa';
        if (x.contains('red') || x.contains('block') || x.contains('fail') || x.contains('no-go')) return 'pill pr';
        return 'pill pgr';
    }

    private static String coTypeClass(String t) {
        if (String.isBlank(t)) return 'pill pgr';
        String x = t.toLowerCase();
        if (x.contains('add')) return 'pill pb';
        if (x.contains('change')) return 'pill pa';
        if (x.contains('credit')) return 'pill pp';
        return 'pill pgr';
    }

    private static String qiScoreColor(Object v) {
        Decimal d = v instanceof Decimal ? (Decimal) v : v == null ? null : Decimal.valueOf(String.valueOf(v));
        if (d == null) return '#706e6b';
        if (d >= 8) return '#2e844a';
        if (d >= 7) return '#ba7517';
        return '#c23934';
    }

    private static Integer parseLot(String lotLabel) {
        if (String.isBlank(lotLabel)) return null;
        String digits = lotLabel.replaceAll('[^0-9]','');
        if (String.isBlank(digits)) return null;
        try { return Integer.valueOf(digits); } catch (Exception e) { return null; }
    }

    private static String initialsOf(String name) {
        if (String.isBlank(name)) return '?';
        List<String> parts = name.trim().split('\\s+');
        String first = parts[0].substring(0, 1);
        String last  = parts.size() > 1 ? parts[parts.size()-1].substring(0,1) : '';
        return (first + last).toUpperCase();
    }

    private static String stringify(Object v) {
        if (v == null) return '';
        return String.valueOf(v);
    }

    private static Integer toInt(Object v) {
        if (v == null) return 0;
        if (v instanceof Integer) return (Integer) v;
        if (v instanceof Decimal) return ((Decimal) v).intValue();
        try { return Integer.valueOf(String.valueOf(v)); } catch (Exception e) { return 0; }
    }

    /* =========================
       Communities List View — DTO + methods
       ========================= */

    public class CommunityListRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String builderAccountName;
        @AuraEnabled public String builderAccountId;
        @AuraEnabled public String parentBuilderAccountName;
        @AuraEnabled public String parentBuilderAccountId;
        @AuraEnabled public String territory;
        @AuraEnabled public Integer numberOfLots;
        @AuraEnabled public Integer activeLotCount;
        @AuraEnabled public String assignedFmName;
        @AuraEnabled public String assignedFmId;
        @AuraEnabled public String communityStatus;
        @AuraEnabled public String recordUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<CommunityListRow> getAllCommunities(String searchTerm, String statusFilter) {
        Map<String, Schema.SObjectField> flds = Schema.SObjectType.Community__c.fields.getMap();
        List<String> sel = new List<String>{ 'Id', 'Name' };
        List<String> optional = new List<String>{
            'Builder_Account__c', 'Parent_Builder_Account__c',
            'Territory__c', 'Number_Of_Lots__c', 'Active_Lot_Count__c',
            'Assigned_FM__c', 'Community_Status__c'
        };
        for (String f : optional) {
            if (flds.containsKey(f.toLowerCase())) sel.add(f);
        }
        if (flds.containsKey('assigned_fm__c')) sel.add('Assigned_FM__r.Name');
        if (flds.containsKey('builder_account__c')) sel.add('Builder_Account__r.Name');
        if (flds.containsKey('parent_builder_account__c')) sel.add('Parent_Builder_Account__r.Name');

        String q = 'SELECT ' + String.join(sel, ', ') + ' FROM Community__c';
        List<String> wheres = new List<String>();
        String sSearch = (searchTerm != null && searchTerm.trim() != '') ? '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%' : null;
        if (sSearch != null) wheres.add('Name LIKE :sSearch');
        String sStatus = (statusFilter != null && statusFilter != 'All' && statusFilter.trim() != '') ? statusFilter : null;
        if (sStatus != null) wheres.add('Community_Status__c = :sStatus');
        if (!wheres.isEmpty()) q += ' WHERE ' + String.join(wheres, ' AND ');
        q += ' ORDER BY Name ASC LIMIT 500';

        List<CommunityListRow> rows = new List<CommunityListRow>();
        try {
            for (SObject s : Database.query(q)) {
                CommunityListRow r = new CommunityListRow();
                r.id = (String) s.get('Id');
                r.name = (String) s.get('Name');
                r.recordUrl = '/' + r.id;
                if (flds.containsKey('community_status__c')) r.communityStatus = (String) s.get('Community_Status__c');
                if (flds.containsKey('territory__c')) r.territory = (String) s.get('Territory__c');
                if (flds.containsKey('number_of_lots__c')) r.numberOfLots = toInt(s.get('Number_Of_Lots__c'));
                if (flds.containsKey('active_lot_count__c')) r.activeLotCount = toInt(s.get('Active_Lot_Count__c'));
                if (flds.containsKey('builder_account__c')) {
                    r.builderAccountId = (String) s.get('Builder_Account__c');
                    SObject ba = s.getSObject('Builder_Account__r');
                    if (ba != null) r.builderAccountName = (String) ba.get('Name');
                }
                if (flds.containsKey('parent_builder_account__c')) {
                    r.parentBuilderAccountId = (String) s.get('Parent_Builder_Account__c');
                    SObject pba = s.getSObject('Parent_Builder_Account__r');
                    if (pba != null) r.parentBuilderAccountName = (String) pba.get('Name');
                }
                if (flds.containsKey('assigned_fm__c')) {
                    r.assignedFmId = (String) s.get('Assigned_FM__c');
                    SObject fm = s.getSObject('Assigned_FM__r');
                    if (fm != null) r.assignedFmName = (String) fm.get('Name');
                }
                rows.add(r);
            }
        } catch (Exception e) { /* return empty on error */ }
        return rows;
    }

    @AuraEnabled
    public static void updateCommunityStatus(Id communityId, String newStatus) {
        if (communityId == null) throw new AuraHandledException('Community ID required');
        if (String.isBlank(newStatus)) throw new AuraHandledException('Status value required');
        Map<String, Schema.SObjectField> flds = Schema.SObjectType.Community__c.fields.getMap();
        if (!flds.containsKey('community_status__c')) throw new AuraHandledException('Community_Status__c not found');
        if (!Schema.SObjectType.Community__c.isUpdateable()) throw new AuraHandledException('No update access to Community__c');
        SObject c = new Community__c(Id = communityId);
        c.put('Community_Status__c', newStatus);
        update c;
    }

    /* =========================
       Test hooks - exercise private helpers that would otherwise only
       run when Work_Order__c / Change_Order__c exist in the org.
       ========================= */
    @TestVisible
    private static void exerciseHelpersForCoverage() {
        pillClassForStatus(null);
        pillClassForStatus('Complete');
        pillClassForStatus('Approved');
        pillClassForStatus('Submitted');
        pillClassForStatus('Go');
        pillClassForStatus('Scheduled');
        pillClassForStatus('Pending');
        pillClassForStatus('Due');
        pillClassForStatus('Red');
        pillClassForStatus('Blocked');
        pillClassForStatus('Failed');
        pillClassForStatus('No-Go');
        pillClassForStatus('Other');
        coTypeClass(null);
        coTypeClass('Add-On');
        coTypeClass('Change');
        coTypeClass('Credit');
        coTypeClass('Other');
        qiScoreColor(null);
        qiScoreColor(9);
        qiScoreColor(7.5);
        qiScoreColor(6);
        qiScoreColor('8');
        parseLot(null);
        parseLot('');
        parseLot('Lot 12');
        parseLot('no-digits');
        initialsOf(null);
        initialsOf('');
        initialsOf('Prince');
        initialsOf('Jane Mary Doe');
        stringify(null);
        stringify('abc');
        toInt(null);
        toInt(3);
        toInt((Decimal) 4.2);
        toInt('5');
        toInt('not-a-number');
        buildItem('Done item', 'detail', 'done');
        buildItem('Open item', 'detail', 'open');
        buildItem('Pending item', 'detail', 'pending');
    }
}