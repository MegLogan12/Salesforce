public with sharing class LovingAcctCommLotWorkbenchSvc {
    private static final Integer PARENT_LIMIT = 100;
    private static final Integer DIVISION_LIMIT = 250;
    private static final Integer COMMUNITY_LIMIT = 400;
    private static final Integer LOT_LIMIT = 700;
    private static final Set<String> CLOSED_STATUSES = new Set<String>{'Closed', 'Completed', 'Canceled', 'Cancelled', 'Void'};

    public class WorkbenchData {
        @AuraEnabled public List<KpiDTO> kpis = new List<KpiDTO>();
        @AuraEnabled public List<NodeDTO> parents = new List<NodeDTO>();
        @AuraEnabled public List<NodeDTO> divisions = new List<NodeDTO>();
        @AuraEnabled public List<NodeDTO> communities = new List<NodeDTO>();
        @AuraEnabled public List<NodeDTO> lots = new List<NodeDTO>();
        @AuraEnabled public List<ActionDTO> parentActions = parentActions();
        @AuraEnabled public List<ActionDTO> divisionActions = divisionActions();
        @AuraEnabled public List<ActionDTO> communityActions = communityActions();
        @AuraEnabled public List<ActionDTO> lotActions = lotActions();
        @AuraEnabled public List<AuditDTO> audit = new List<AuditDTO>();
        @AuraEnabled public String lastRefreshed = String.valueOf(System.now());
        @AuraEnabled public String warning;
    }

    public class KpiDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String sublabel;
        @AuraEnabled public String tone;
    }

    public class NodeDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String parentId;
        @AuraEnabled public String divisionId;
        @AuraEnabled public String communityId;
        @AuraEnabled public String type;
        @AuraEnabled public String name;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String status;
        @AuraEnabled public String tone;
        @AuraEnabled public String packageStatus;
        @AuraEnabled public String packageLabel;
        @AuraEnabled public String fieldManager;
        @AuraEnabled public String territory;
        @AuraEnabled public String address;
        @AuraEnabled public String gpsStatus;
        @AuraEnabled public Boolean aquaActive;
        @AuraEnabled public Integer divisionCount = 0;
        @AuraEnabled public Integer communityCount = 0;
        @AuraEnabled public Integer lotCount = 0;
        @AuraEnabled public Integer openPoCount = 0;
        @AuraEnabled public Integer openWorkOrderCount = 0;
        @AuraEnabled public Integer issueCount = 0;
        @AuraEnabled public String currentPoId;
        @AuraEnabled public String currentPoName;
        @AuraEnabled public String currentWorkOrderId;
        @AuraEnabled public String currentWorkOrderName;
        @AuraEnabled public String lastCompletedWork;
        @AuraEnabled public List<ActionDTO> actions = new List<ActionDTO>();
    }

    public class ActionDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String targetObject;
        @AuraEnabled public String kind;
        @AuraEnabled public Boolean enabled;
        @AuraEnabled public String disabledReason;
    }

    public class AuditDTO {
        @AuraEnabled public String area;
        @AuraEnabled public String currentObjectField;
        @AuraEnabled public Boolean exists;
        @AuraEnabled public Boolean canUse;
        @AuraEnabled public String gapOrFixNeeded;
    }

    public class SummaryDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public String status;
        @AuraEnabled public List<KpiDTO> kpis = new List<KpiDTO>();
        @AuraEnabled public List<ActionDTO> actions = new List<ActionDTO>();
    }

    public class PackageSummaryDTO {
        @AuraEnabled public String status;
        @AuraEnabled public String detail;
        @AuraEnabled public Boolean configured;
    }

    public static WorkbenchData getWorkbenchData(String filtersJson) {
        Map<String, Object> filters = parseFilters(filtersJson);
        String search = value(filters.get('searchTerm'), '').toLowerCase();
        Boolean activeOnly = filters.containsKey('activeOnly') ? bool(filters.get('activeOnly')) : true;

        WorkbenchData data = new WorkbenchData();
        data.audit = buildAudit();

        List<Account> parents = queryParents(search);
        Set<Id> parentIds = ids(parents);
        List<Account> divisions = queryDivisions(parentIds, search);
        Set<Id> divisionIds = ids(divisions);
        List<Community__c> communities = queryCommunities(divisionIds, search, activeOnly);
        Set<Id> communityIds = communityIds(communities);
        List<Lot__c> lots = queryLots(communityIds, search, activeOnly);

        Map<Id, Integer> divisionCountByParent = new Map<Id, Integer>();
        Map<Id, Integer> communityCountByDivision = new Map<Id, Integer>();
        Map<Id, Integer> lotCountByCommunity = new Map<Id, Integer>();
        Map<Id, Integer> openPoByDivision = new Map<Id, Integer>();
        Map<Id, Integer> openPoByCommunity = new Map<Id, Integer>();
        Map<Id, Integer> openPoByLot = new Map<Id, Integer>();
        Map<Id, Integer> openWoByCommunity = new Map<Id, Integer>();
        Map<String, NodeDTO> lotByKey = new Map<String, NodeDTO>();

        for (Account d : divisions) {
            addCount(divisionCountByParent, d.ParentId, 1);
        }
        for (Community__c c : communities) {
            addCount(communityCountByDivision, c.Builder_Account__c, 1);
        }
        for (Lot__c l : lots) {
            addCount(lotCountByCommunity, l.Community__c, 1);
        }

        for (AggregateResult ar : [
            SELECT Division_Account__c divId, COUNT(Id) cnt
            FROM Purchase_Order__c
            WHERE Division_Account__c IN :divisionIds AND Status__c NOT IN :CLOSED_STATUSES
            GROUP BY Division_Account__c
        ]) {
            openPoByDivision.put((Id) ar.get('divId'), aggregateCount(ar));
        }
        for (AggregateResult ar : [
            SELECT Community__c commId, COUNT(Id) cnt
            FROM Purchase_Order__c
            WHERE Community__c IN :communityIds AND Status__c NOT IN :CLOSED_STATUSES
            GROUP BY Community__c
        ]) {
            openPoByCommunity.put((Id) ar.get('commId'), aggregateCount(ar));
        }
        for (Lot__c l : lots) {
            lotByKey.put(String.valueOf(l.Community__c) + '|' + String.valueOf(l.Name).toLowerCase(), null);
        }
        Set<Id> lotIds = new Set<Id>();
        for (Lot__c l : lots) lotIds.add(l.Id);
        if (!lotIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Lot__c lotId, COUNT(Id) cnt
                FROM Purchase_Order__c
                WHERE Lot__c IN :lotIds AND Status__c NOT IN :CLOSED_STATUSES
                GROUP BY Lot__c
            ]) {
                openPoByLot.put((Id) ar.get('lotId'), aggregateCount(ar));
            }
        }
        for (AggregateResult ar : [
            SELECT Community_FML__c commId, COUNT(Id) cnt
            FROM WorkOrder
            WHERE Community_FML__c IN :communityIds AND Status NOT IN :CLOSED_STATUSES
            GROUP BY Community_FML__c
        ]) {
            openWoByCommunity.put((Id) ar.get('commId'), aggregateCount(ar));
        }

        for (Account a : parents) {
            NodeDTO row = baseNode(a.Id, 'parent', a.Name);
            row.subtitle = 'Brand rollup only';
            row.status = 'Rollup';
            row.tone = 'blue';
            row.divisionCount = getCount(divisionCountByParent, a.Id);
            row.actions = parentActions();
            data.parents.add(row);
        }
        for (Account a : divisions) {
            NodeDTO row = baseNode(a.Id, 'division', a.Name);
            row.parentId = String.valueOf(a.ParentId);
            row.subtitle = a.Parent != null ? a.Parent.Name : 'Operating account';
            row.status = value(a.Onboarding_Status__c, 'Operating');
            row.territory = value(a.Territory__c, value(a.Market__c, a.Division_Region__c));
            row.fieldManager = a.Loving_FM__r != null ? a.Loving_FM__r.Name : 'Not assigned';
            row.communityCount = getCount(communityCountByDivision, a.Id);
            row.openPoCount = getCount(openPoByDivision, a.Id);
            row.actions = divisionActions();
            data.divisions.add(row);
        }
        for (Community__c c : communities) {
            NodeDTO row = baseNode(c.Id, 'community', c.Name);
            row.divisionId = String.valueOf(c.Builder_Account__c);
            row.parentId = c.Builder_Account__r != null ? String.valueOf(c.Builder_Account__r.ParentId) : null;
            row.subtitle = c.Builder_Account__r != null ? c.Builder_Account__r.Name : 'No division linked';
            row.status = c.Active__c ? 'Active' : value(c.Community_Status__c, 'Inactive / review');
            row.tone = c.Active__c ? 'green' : 'gray';
            row.territory = c.ServiceTerritory__r != null ? c.ServiceTerritory__r.Name : value(c.Territory__c, 'Not configured');
            row.fieldManager = value(c.Market_Loving_FM__c, 'Not assigned');
            row.packageLabel = packageLabel(c.Active_Community_Package__c, c.Active_Standard_Package__c, c.BMG_Package_Code__c);
            row.packageStatus = communityPackageStatus(c);
            row.aquaActive = c.Aqua_Active__c || c.Aqua_Included__c;
            row.lotCount = getCount(lotCountByCommunity, c.Id);
            row.openPoCount = getCount(openPoByCommunity, c.Id);
            row.openWorkOrderCount = getCount(openWoByCommunity, c.Id);
            row.actions = communityActions();
            data.communities.add(row);
        }
        Map<Id, NodeDTO> lotNodesById = new Map<Id, NodeDTO>();
        for (Lot__c l : lots) {
            NodeDTO row = baseNode(l.Id, 'lot', l.Name);
            row.communityId = String.valueOf(l.Community__c);
            row.divisionId = l.Community__r != null ? String.valueOf(l.Community__r.Builder_Account__c) : null;
            row.parentId = l.Community__r != null && l.Community__r.Builder_Account__r != null
                ? String.valueOf(l.Community__r.Builder_Account__r.ParentId) : null;
            row.subtitle = l.Community__r != null ? l.Community__r.Name : 'No community linked';
            row.status = value(l.Lot_Status__c, value(l.Status__c, 'Status not configured'));
            row.address = value(l.Street_Address__c, l.Address__c);
            row.gpsStatus = (l.Lot_Latitude__c != null && l.Lot_Longitude__c != null) ? 'GPS set' : 'GPS missing';
            row.packageLabel = lotPackageLabel(l);
            row.packageStatus = lotPackageStatus(l);
            row.aquaActive = l.Aqua_Installed__c;
            row.openPoCount = getCount(openPoByLot, l.Id);
            row.actions = lotActions();
            lotNodesById.put(l.Id, row);
            data.lots.add(row);
        }

        enrichCurrentPo(data.lots, lotNodesById);
        enrichWorkHistory(data.lots, lotNodesById);
        data.kpis = buildKpis(data.parents.size(), data.divisions.size(), data.communities, data.lots);
        return data;
    }

    public static WorkbenchData searchHierarchy(String searchTerm) {
        return getWorkbenchData(JSON.serialize(new Map<String, Object>{'searchTerm' => searchTerm, 'activeOnly' => false}));
    }

    public static SummaryDTO getParentSummary(Id parentAccountId) {
        SummaryDTO dto = new SummaryDTO();
        dto.id = String.valueOf(parentAccountId);
        dto.type = 'parent';
        dto.actions = parentActions();
        return dto;
    }

    public static SummaryDTO getDivisionSummary(Id divisionAccountId) {
        SummaryDTO dto = new SummaryDTO();
        dto.id = String.valueOf(divisionAccountId);
        dto.type = 'division';
        dto.actions = divisionActions();
        return dto;
    }

    public static SummaryDTO getCommunitySummary(Id communityId) {
        SummaryDTO dto = new SummaryDTO();
        dto.id = String.valueOf(communityId);
        dto.type = 'community';
        dto.actions = communityActions();
        return dto;
    }

    public static SummaryDTO getLotSummary(Id lotId) {
        SummaryDTO dto = new SummaryDTO();
        dto.id = String.valueOf(lotId);
        dto.type = 'lot';
        dto.actions = lotActions();
        return dto;
    }

    public static PackageSummaryDTO getPackageMatchSummary(Id contextId) {
        PackageSummaryDTO dto = new PackageSummaryDTO();
        dto.configured = true;
        dto.status = 'Not Configured';
        dto.detail = 'Package match is available when Purchase_Order__c.Package_BMG_Status__c is populated by the PO package validation process.';
        if (contextId == null) return dto;
        String prefix = String.valueOf(contextId).left(3);
        if (prefix == Community__c.SObjectType.getDescribe().getKeyPrefix()) {
            List<Purchase_Order__c> pos = [
                SELECT Package_BMG_Status__c
                FROM Purchase_Order__c
                WHERE Community__c = :contextId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!pos.isEmpty()) {
                dto.status = value(pos[0].Package_BMG_Status__c, 'Not Reviewed');
                dto.detail = 'Most recent PO package status for this community.';
            }
        } else if (prefix == Lot__c.SObjectType.getDescribe().getKeyPrefix()) {
            List<Purchase_Order__c> pos = [
                SELECT Package_BMG_Status__c
                FROM Purchase_Order__c
                WHERE Lot__c = :contextId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!pos.isEmpty()) {
                dto.status = value(pos[0].Package_BMG_Status__c, 'Not Reviewed');
                dto.detail = 'Most recent PO package status for this lot.';
            }
        }
        return dto;
    }

    private static List<Account> queryParents(String search) {
        if (String.isBlank(search)) {
            return [
                SELECT Id, Name
                FROM Account
                WHERE RecordType.DeveloperName = 'Builder_Parent'
                ORDER BY Name
                LIMIT :PARENT_LIMIT
            ];
        }
        String likeTerm = '%' + String.escapeSingleQuotes(search) + '%';
        return [
            SELECT Id, Name
            FROM Account
            WHERE RecordType.DeveloperName = 'Builder_Parent' AND Name LIKE :likeTerm
            ORDER BY Name
            LIMIT :PARENT_LIMIT
        ];
    }

    private static List<Account> queryDivisions(Set<Id> parentIds, String search) {
        if (String.isBlank(search)) {
            return [
                SELECT Id, Name, ParentId, Parent.Name, Market__c, Territory__c, Division_Region__c,
                       Onboarding_Status__c, Loving_FM__r.Name
                FROM Account
                WHERE RecordType.DeveloperName = 'Builder_Market'
                ORDER BY Name
                LIMIT :DIVISION_LIMIT
            ];
        }
        String likeTerm = '%' + String.escapeSingleQuotes(search) + '%';
        return [
            SELECT Id, Name, ParentId, Parent.Name, Market__c, Territory__c, Division_Region__c,
                   Onboarding_Status__c, Loving_FM__r.Name
            FROM Account
            WHERE RecordType.DeveloperName = 'Builder_Market'
            AND (Name LIKE :likeTerm OR Parent.Name LIKE :likeTerm)
            ORDER BY Name
            LIMIT :DIVISION_LIMIT
        ];
    }

    private static List<Community__c> queryCommunities(Set<Id> divisionIds, String search, Boolean activeOnly) {
        String base = 'SELECT Id, Name, Builder_Account__c, Builder_Account__r.Name, Builder_Account__r.ParentId, ' +
            'Active__c, Community_Status__c, Territory__c, Market_Loving_FM__c, BMG_Package_Code__c, ' +
            'Active_Community_Package__c, Active_Standard_Package__c, Active_Corner_Package__c, ' +
            'Aqua_Active__c, Aqua_Included__c, ServiceTerritory__r.Name FROM Community__c';
        List<String> clauses = new List<String>();
        if (activeOnly) clauses.add('Active__c = true');
        if (!String.isBlank(search)) clauses.add('Name LIKE \'%' + String.escapeSingleQuotes(search) + '%\'');
        String q = base + (clauses.isEmpty() ? '' : ' WHERE ' + String.join(clauses, ' AND ')) + ' ORDER BY Name LIMIT ' + COMMUNITY_LIMIT;
        return Database.query(q);
    }

    private static List<Lot__c> queryLots(Set<Id> communityIds, String search, Boolean activeOnly) {
        String base = 'SELECT Id, Name, Community__c, Community__r.Name, Community__r.Builder_Account__c, ' +
            'Community__r.Builder_Account__r.ParentId, Status__c, Lot_Status__c, Street_Address__c, Address__c, ' +
            'Lot_Latitude__c, Lot_Longitude__c, Aqua_Installed__c, Community_Package__c, Effective_Community_Package__c, ' +
            'Active_Corner_Package__c, Package_Override__c FROM Lot__c';
        List<String> clauses = new List<String>();
        if (!communityIds.isEmpty()) clauses.add('Community__c IN :communityIds');
        if (activeOnly) clauses.add('(Lot_Status__c = null OR Lot_Status__c NOT IN (\'Closed\', \'Inactive\', \'Cancelled\', \'Canceled\'))');
        if (!String.isBlank(search)) clauses.add('(Name LIKE \'%' + String.escapeSingleQuotes(search) + '%\' OR Address__c LIKE \'%' + String.escapeSingleQuotes(search) + '%\' OR Street_Address__c LIKE \'%' + String.escapeSingleQuotes(search) + '%\')');
        String q = base + (clauses.isEmpty() ? '' : ' WHERE ' + String.join(clauses, ' AND ')) + ' ORDER BY Name LIMIT ' + LOT_LIMIT;
        return Database.query(q);
    }

    private static void enrichCurrentPo(List<NodeDTO> lotNodes, Map<Id, NodeDTO> byId) {
        if (byId.isEmpty()) return;
        for (Purchase_Order__c po : [
            SELECT Id, Name, PO_Number__c, Lot__c, Package_BMG_Status__c
            FROM Purchase_Order__c
            WHERE Lot__c IN :byId.keySet() AND Status__c NOT IN :CLOSED_STATUSES
            ORDER BY CreatedDate DESC
            LIMIT 500
        ]) {
            NodeDTO lot = byId.get(po.Lot__c);
            if (lot != null && lot.currentPoId == null) {
                lot.currentPoId = String.valueOf(po.Id);
                lot.currentPoName = value(po.PO_Number__c, po.Name);
                lot.packageStatus = value(po.Package_BMG_Status__c, lot.packageStatus);
            }
        }
    }

    private static void enrichWorkHistory(List<NodeDTO> lotNodes, Map<Id, NodeDTO> byId) {
        if (lotNodes.isEmpty()) return;
        Set<Id> communityIds = new Set<Id>();
        Set<String> lotNames = new Set<String>();
        Map<String, NodeDTO> keyToLot = new Map<String, NodeDTO>();
        for (NodeDTO l : lotNodes) {
            if (l.communityId != null) communityIds.add((Id) l.communityId);
            if (l.name != null) {
                lotNames.add(l.name);
                keyToLot.put(l.communityId + '|' + l.name.toLowerCase(), l);
            }
        }
        if (communityIds.isEmpty() || lotNames.isEmpty()) return;
        for (WorkOrder wo : [
            SELECT Id, WorkOrderNumber, Status, Community_FML__c, Lot_Number__c
            FROM WorkOrder
            WHERE Community_FML__c IN :communityIds AND Lot_Number__c IN :lotNames
            ORDER BY CreatedDate DESC
            LIMIT 500
        ]) {
            NodeDTO lot = keyToLot.get(String.valueOf(wo.Community_FML__c) + '|' + String.valueOf(wo.Lot_Number__c).toLowerCase());
            if (lot == null) continue;
            if (!CLOSED_STATUSES.contains(wo.Status)) {
                lot.openWorkOrderCount++;
                if (lot.currentWorkOrderId == null) {
                    lot.currentWorkOrderId = String.valueOf(wo.Id);
                    lot.currentWorkOrderName = wo.WorkOrderNumber;
                }
            } else if (lot.lastCompletedWork == null) {
                lot.lastCompletedWork = wo.WorkOrderNumber;
            }
        }
    }

    private static List<KpiDTO> buildKpis(Integer parentCount, Integer divisionCount, List<NodeDTO> communities, List<NodeDTO> lots) {
        Integer activeCommunities = 0;
        Integer activeLots = 0;
        Integer packageIssues = 0;
        Integer lotsWithOpenWork = 0;
        for (NodeDTO c : communities) {
            if (c.status == 'Active') activeCommunities++;
            if (c.packageStatus == 'Mismatch' || c.packageStatus == 'Mismatch Review' || c.packageStatus == 'Missing Package') packageIssues++;
        }
        for (NodeDTO l : lots) {
            if (l.status == null || !CLOSED_STATUSES.contains(l.status)) activeLots++;
            if (l.packageStatus == 'Mismatch' || l.packageStatus == 'Mismatch Review' || l.packageStatus == 'Missing Package') packageIssues++;
            if (l.openWorkOrderCount > 0) lotsWithOpenWork++;
        }
        return new List<KpiDTO>{
            kpi('parents', 'Parent Builders', String.valueOf(parentCount), 'Account record type: Builder Parent', 'blue'),
            kpi('divisions', 'Division Accounts', String.valueOf(divisionCount), 'Account record type: Builder Division', 'green'),
            kpi('communities', 'Active Communities', String.valueOf(activeCommunities), 'Community__c.Active__c', 'amber'),
            kpi('lots', 'Active Lots', String.valueOf(activeLots), 'Open Lot__c records', 'blue'),
            kpi('packageIssues', 'Package Mismatches', String.valueOf(packageIssues), 'PO/package status where available', packageIssues > 0 ? 'red' : 'green'),
            kpi('openWork', 'Lots with Open Work', String.valueOf(lotsWithOpenWork), 'Standard WorkOrder linked by community + lot number', 'purple')
        };
    }

    private static List<AuditDTO> buildAudit() {
        return new List<AuditDTO>{
            audit('Parent Account record type', 'Account.RecordType = Builder_Parent', true, true, 'Use for brand rollup only.'),
            audit('Division Account record type', 'Account.RecordType = Builder_Market / Builder Division', true, true, 'Use as operating account.'),
            audit('Account hierarchy ParentId', 'Account.ParentId', true, true, 'Use parent-to-division hierarchy.'),
            audit('Builder contacts', 'Contact.AccountId', true, true, 'Use standard Contact under Account.'),
            audit('Community object', 'Community__c', true, true, 'Use existing custom community object.'),
            audit('Community to Division Account lookup', 'Community__c.Builder_Account__c', true, true, 'Confirmed lookup to Account.'),
            audit('Lot object', 'Lot__c', true, true, 'Use existing custom lot object.'),
            audit('Lot to Community lookup', 'Lot__c.Community__c', true, true, 'Confirmed lookup to Community__c.'),
            audit('Lot to Division/Builder lookup', 'Lot__c -> Community__c.Builder_Account__c', true, true, 'Resolve through Community; no separate direct lot division lookup required.'),
            audit('Builder Package / Community Package', 'Community_Package__c + Community package lookups', true, true, 'Use existing package object; package line detail still needs deeper validator service.'),
            audit('BMG package/pricing fields', 'Community__c.BMG_Package_Code__c, Account.BMG_Link__c, Builder_Pricing_Book__c', true, true, 'Use existing references/status; no new package object.'),
            audit('PO object', 'Purchase_Order__c', true, true, 'Canonical PO object.'),
            audit('PO to Lot/Community link', 'Purchase_Order__c.Lot__c / Community__c / Division_Account__c', true, true, 'Use for package and active work visibility.'),
            audit('WorkOrder to Lot/Community link', 'WorkOrder.Community_FML__c + WorkOrder.Lot_Number__c', true, true, 'Community lookup exists; lot is text match, so UI treats lot work history as best-effort.'),
            audit('ServiceAppointment to WorkOrder link', 'ServiceAppointment.ParentRecordId', true, true, 'Use standard FSL parent link.'),
            audit('Aqua fields on Lot/Community', 'Community__c.Aqua_Active__c, Lot__c.Aqua_Installed__c', true, true, 'Use existing flags.'),
            audit('Territory/market fields', 'Community__c.ServiceTerritory__c, Account.Market__c/Territory__c', true, true, 'Use FSL ServiceTerritory where configured.'),
            audit('Field Manager assignment', 'Account.Loving_FM__c, Community__c.Market_Loving_FM__c', true, true, 'Use division FM first; community market FM displayed where populated.')
        };
    }

    private static NodeDTO baseNode(Id id, String type, String name) {
        NodeDTO dto = new NodeDTO();
        dto.id = String.valueOf(id);
        dto.type = type;
        dto.name = name;
        dto.tone = 'blue';
        dto.packageStatus = 'Not Configured';
        return dto;
    }

    private static String communityPackageStatus(Community__c c) {
        if (c.Active_Community_Package__c != null || c.Active_Standard_Package__c != null || !String.isBlank(c.BMG_Package_Code__c)) return 'Configured';
        return 'Missing Package';
    }

    private static String lotPackageStatus(Lot__c l) {
        if (l.Package_Override__c == true) return 'Override';
        if (l.Effective_Community_Package__c != null || l.Community_Package__c != null || l.Active_Corner_Package__c != null) return 'Configured';
        return 'No Active PO';
    }

    private static String packageLabel(Id communityPackageId, Id standardPackageId, String bmgCode) {
        if (communityPackageId != null) return 'Community package set';
        if (standardPackageId != null) return 'Standard package set';
        if (!String.isBlank(bmgCode)) return bmgCode;
        return 'Missing package';
    }

    private static String lotPackageLabel(Lot__c l) {
        if (l.Effective_Community_Package__c != null) return 'Effective package set';
        if (l.Community_Package__c != null) return 'Lot package set';
        if (l.Active_Corner_Package__c != null) return 'Corner package set';
        return 'No package override';
    }

    private static List<ActionDTO> parentActions() {
        return new List<ActionDTO>{
            action('viewParent', 'View Parent Account', 'Account', 'record', true, null),
            action('viewDivisions', 'View Divisions', 'Account', 'filter', true, null),
            action('rollupDashboard', 'View Rollup Dashboard', null, 'disabled', false, 'Dashboard link is not configured in metadata yet.'),
            action('newPoBlocked', 'New PO', 'Purchase_Order__c', 'disabled', false, 'Parent Accounts are rollup only. Start PO from Division or Community.')
        };
    }

    private static List<ActionDTO> divisionActions() {
        return new List<ActionDTO>{
            action('newPo', 'New PO', 'Purchase_Order__c', 'new', true, null),
            action('viewCommunities', 'View Communities', 'Community__c', 'filter', true, null),
            action('viewContacts', 'View Contacts', 'Contact', 'related', true, null),
            action('viewPricing', 'View Pricing / BMG', 'Builder_Pricing_Book__c', 'related', true, null),
            action('viewOpenWork', 'View Open Work', 'WorkOrder', 'related', true, null)
        };
    }

    private static List<ActionDTO> communityActions() {
        return new List<ActionDTO>{
            action('startPo', 'Start PO', 'Purchase_Order__c', 'new', true, null),
            action('viewCommunity', 'View Community', 'Community__c', 'record', true, null),
            action('viewLots', 'View Lots', 'Lot__c', 'filter', true, null),
            action('viewPackage', 'View Package', 'Community_Package__c', 'related', true, null),
            action('viewAqua', 'View Aqua', null, 'related', true, null)
        };
    }

    private static List<ActionDTO> lotActions() {
        return new List<ActionDTO>{
            action('viewLot', 'View Lot', 'Lot__c', 'record', true, null),
            action('viewWorkHistory', 'View Work History', 'WorkOrder', 'related', true, null),
            action('viewCurrentWorkOrder', 'View Current WorkOrder', 'WorkOrder', 'recordOptional', true, null),
            action('viewPo', 'View PO', 'Purchase_Order__c', 'recordOptional', true, null),
            action('viewIssues', 'View Schedule Issues', 'Schedule_Issue__c', 'related', true, null),
            action('viewPhotos', 'View Photos', 'ContentDocumentLink', 'related', true, null),
            action('newWorkBlocked', 'New Production WorkOrder', 'WorkOrder', 'disabled', false, 'Production WorkOrders must come after PO/package match and Takeoff Complete.')
        };
    }

    private static ActionDTO action(String key, String label, String targetObject, String kind, Boolean enabled, String disabledReason) {
        ActionDTO a = new ActionDTO();
        a.key = key;
        a.label = label;
        a.targetObject = targetObject;
        a.kind = kind;
        a.enabled = enabled;
        a.disabledReason = disabledReason;
        return a;
    }

    private static KpiDTO kpi(String key, String label, String value, String sublabel, String tone) {
        KpiDTO k = new KpiDTO();
        k.key = key;
        k.label = label;
        k.value = value;
        k.sublabel = sublabel;
        k.tone = tone;
        return k;
    }

    private static AuditDTO audit(String area, String field, Boolean exists, Boolean canUse, String gap) {
        AuditDTO a = new AuditDTO();
        a.area = area;
        a.currentObjectField = field;
        a.exists = exists;
        a.canUse = canUse;
        a.gapOrFixNeeded = gap;
        return a;
    }

    private static Map<String, Object> parseFilters(String jsonText) {
        if (String.isBlank(jsonText)) return new Map<String, Object>();
        Object raw = JSON.deserializeUntyped(jsonText);
        return (Map<String, Object>) raw;
    }

    private static Set<Id> ids(List<Account> rows) {
        Set<Id> result = new Set<Id>();
        for (Account row : rows) result.add(row.Id);
        return result;
    }

    private static Set<Id> communityIds(List<Community__c> rows) {
        Set<Id> result = new Set<Id>();
        for (Community__c row : rows) result.add(row.Id);
        return result;
    }

    private static void addCount(Map<Id, Integer> counts, Id key, Integer amount) {
        if (key == null) return;
        counts.put(key, (counts.containsKey(key) ? counts.get(key) : 0) + amount);
    }

    private static Integer getCount(Map<Id, Integer> counts, Id key) {
        return key != null && counts.containsKey(key) ? counts.get(key) : 0;
    }

    private static Integer aggregateCount(AggregateResult row) {
        Object raw = row.get('cnt');
        return raw == null ? 0 : Integer.valueOf(String.valueOf(raw));
    }

    private static String value(Object candidate, Object fallback) {
        String s = candidate == null ? null : String.valueOf(candidate);
        return String.isBlank(s) ? (fallback == null ? null : String.valueOf(fallback)) : s;
    }

    private static String str(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Boolean bool(Object value) {
        if (value == null) return false;
        if (value instanceof Boolean) return (Boolean) value;
        return String.valueOf(value).equalsIgnoreCase('true');
    }
}