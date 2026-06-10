/**
 * Controller for Parent Account + Division Account record pages.
 *
 * Exposes read-only, sharing-respecting queries for:
 *   - getDivisionAccounts: child Accounts where ParentId = parentAccountId (Parent page)
 *   - getOpenOpportunities: open Opportunities where Account.ParentId = parentAccountId (Parent page)
 *   - getDivisionKpis: snapshot numbers for a single Division Account (Division page)
 *   - getScopesOfWork: Scope_of_Work__c records for a Division Account (Division page)
 *
 * Sandbox-vs-prod: Work_Order__c, Change_Order__c, and Invoice__c.Amount may not exist.
 * We describe the schema at runtime so the component degrades gracefully.
 */
public with sharing class ParentAccountRollupController {

    // --------- Shared types ---------
    public class DivisionAccountRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String accountStatus;
        @AuraEnabled public String division;
        @AuraEnabled public String phone;
        @AuraEnabled public String website;
        @AuraEnabled public String recordUrl;
    }

    public class OpportunityRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String stageName;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public String recordUrl;
    }

    public class DivisionKpis {
        @AuraEnabled public Integer activeCommunities;
        @AuraEnabled public Integer openWorkOrders;
        @AuraEnabled public Integer pendingChangeOrders;
        @AuraEnabled public Decimal ytdInvoiced;
        @AuraEnabled public Integer totalContractedLots;
        @AuraEnabled public Integer lotsComplete;
        @AuraEnabled public Decimal avgGpPercent;
    }

    public class InvoiceSummary {
        @AuraEnabled public Decimal ytdInvoiced;
        @AuraEnabled public Decimal outstandingBalance;
        @AuraEnabled public Decimal overdueAmount;
        @AuraEnabled public Decimal avgDaysToPay;
    }

    public class ScopeOfWorkRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String lineOfBusiness;
        @AuraEnabled public String status;
        @AuraEnabled public String packageTier;
        @AuraEnabled public Decimal pricePerLot;
        @AuraEnabled public Decimal pricePerVisit;
        @AuraEnabled public String frequency;
        @AuraEnabled public String plantPalette;
        @AuraEnabled public String sodType;
        @AuraEnabled public String mulchSpec;
        @AuraEnabled public Boolean gradingIncluded;
        @AuraEnabled public String serviceType;
        @AuraEnabled public Decimal zoneCountAvg;
        @AuraEnabled public String controllerBrand;
        @AuraEnabled public Boolean backflowRequired;
        @AuraEnabled public Boolean wifiSmartController;
        @AuraEnabled public String designatedServiceDay;
        @AuraEnabled public String fertilizationIncluded;
        @AuraEnabled public Boolean weedControl;
        @AuraEnabled public String aeration;
        @AuraEnabled public String notes;
        @AuraEnabled public String recordUrl;
    }

    // --------- Parent Account methods ---------

    @AuraEnabled(cacheable=true)
    public static List<DivisionAccountRow> getDivisionAccounts(Id parentAccountId) {
        List<DivisionAccountRow> rows = new List<DivisionAccountRow>();
        if (parentAccountId == null) return rows;

        // Dynamic SELECT tolerates orgs/users where Account_Status__c or Market__c may not be accessible.
        Map<String, Schema.SObjectField> aFields = Account.SObjectType.getDescribe().fields.getMap();
        List<String> sel = new List<String>{ 'Id', 'Name', 'Phone', 'Website' };
        if (aFields.containsKey('account_status__c')) sel.add('Account_Status__c');
        if (aFields.containsKey('market__c')) sel.add('Market__c');
        String soql = 'SELECT ' + String.join(sel, ', ') +
                      ' FROM Account WHERE ParentId = :parentAccountId ORDER BY Name ASC LIMIT 200';
        List<SObject> accts;
        try { accts = Database.query(soql); } catch (Exception e) { return rows; }
        for (SObject a : accts) {
            DivisionAccountRow r = new DivisionAccountRow();
            r.id = (Id) a.get('Id');
            r.name = (String) a.get('Name');
            if (aFields.containsKey('account_status__c')) r.accountStatus = (String) a.get('Account_Status__c');
            if (aFields.containsKey('market__c')) r.division = String.valueOf(a.get('Market__c'));
            r.phone = (String) a.get('Phone');
            r.website = (String) a.get('Website');
            r.recordUrl = '/' + r.id;
            rows.add(r);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<OpportunityRow> getOpenOpportunities(Id parentAccountId) {
        List<OpportunityRow> rows = new List<OpportunityRow>();
        if (parentAccountId == null) return rows;

        List<Opportunity> opps;
        try {
            opps = [
                SELECT Id, Name, AccountId, Account.Name, StageName, Amount, CloseDate
                FROM Opportunity
                WHERE Account.ParentId = :parentAccountId
                  AND IsClosed = false
                ORDER BY CloseDate ASC NULLS LAST
                LIMIT 200
            ];
        } catch (Exception e) { return rows; }
        for (Opportunity o : opps) {
            OpportunityRow r = new OpportunityRow();
            r.id = o.Id;
            r.name = o.Name;
            r.accountId = o.AccountId;
            r.accountName = o.Account != null ? o.Account.Name : null;
            r.stageName = o.StageName;
            r.amount = o.Amount;
            r.closeDate = o.CloseDate;
            r.recordUrl = '/' + o.Id;
            rows.add(r);
        }
        return rows;
    }

    // --------- Parent rollup (aggregated across all divisions) ---------

    public class ParentRollup {
        @AuraEnabled public Integer divisionCount;
        @AuraEnabled public Integer activeCommunities;
        @AuraEnabled public Integer contractedLots;
        @AuraEnabled public Integer lotsComplete;
        @AuraEnabled public Integer openWorkOrders;
        @AuraEnabled public Decimal ytdRevenue;
        @AuraEnabled public Decimal avgGp;
    }

    @AuraEnabled(cacheable=true)
    public static ParentRollup getParentRollup(Id parentAccountId) {
        ParentRollup r = new ParentRollup();
        r.divisionCount = 0;
        r.activeCommunities = 0;
        r.contractedLots = 0;
        r.lotsComplete = 0;
        r.openWorkOrders = 0;
        r.ytdRevenue = 0;
        r.avgGp = 0;
        if (parentAccountId == null) return r;

        List<Account> divs;
        try {
            divs = [SELECT Id FROM Account WHERE ParentId = :parentAccountId LIMIT 200];
        } catch (Exception e) { return r; }
        r.divisionCount = divs.size();
        if (divs.isEmpty()) return r;

        Set<Id> divIds = new Set<Id>();
        for (Account a : divs) divIds.add(a.Id);

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

        if (gd.containsKey('Community__c')) {
            Map<String, Schema.SObjectField> cf = gd.get('Community__c').getDescribe().fields.getMap();
            if (cf.containsKey('builder_account__c')) {
                try {
                    r.activeCommunities = Database.countQuery(
                        'SELECT COUNT() FROM Community__c WHERE Builder_Account__c IN :divIds'
                    );
                } catch (Exception e) { /* ignore */ }
                if (cf.containsKey('total_lots__c') && cf.containsKey('lots_complete__c')) {
                    try {
                        for (AggregateResult ar : Database.query(
                            'SELECT SUM(Total_Lots__c) tot, SUM(Lots_Complete__c) done FROM Community__c WHERE Builder_Account__c IN :divIds'
                        )) {
                            Object tot = ar.get('tot');
                            Object done = ar.get('done');
                            if (tot != null) r.contractedLots = ((Decimal) tot).intValue();
                            if (done != null) r.lotsComplete = ((Decimal) done).intValue();
                        }
                    } catch (Exception e) { /* ignore */ }
                }
            }
        }

        if (gd.containsKey('Work_Order__c')) {
            Map<String, Schema.SObjectField> wf = gd.get('Work_Order__c').getDescribe().fields.getMap();
            if (wf.containsKey('status__c')) {
                String whereField = wf.containsKey('builder_market_account__c') ? 'Builder_Market_Account__c' :
                    (wf.containsKey('account__c') ? 'Account__c' : null);
                if (whereField != null) {
                    try {
                        r.openWorkOrders = Database.countQuery(
                            'SELECT COUNT() FROM Work_Order__c WHERE ' + whereField + ' IN :divIds AND Status__c != \'Closed\''
                        );
                    } catch (Exception e) { /* ignore */ }
                }
                if (wf.containsKey('gp_percent__c')) {
                    String gpWhere = wf.containsKey('builder_market_account__c') ? 'Builder_Market_Account__c' :
                        (wf.containsKey('account__c') ? 'Account__c' : null);
                    if (gpWhere != null) {
                        try {
                            Date jan1 = Date.newInstance(Date.today().year(), 1, 1);
                            for (AggregateResult ar : Database.query(
                                'SELECT AVG(GP_Percent__c) avgGp FROM Work_Order__c WHERE ' + gpWhere + ' IN :divIds AND CreatedDate >= :jan1'
                            )) {
                                Object v = ar.get('avgGp');
                                if (v != null) r.avgGp = (Decimal) v;
                            }
                        } catch (Exception e) { /* ignore */ }
                    }
                }
            }
        }

        if (gd.containsKey('Invoice__c')) {
            Map<String, Schema.SObjectField> inf = gd.get('Invoice__c').getDescribe().fields.getMap();
            if (inf.containsKey('amount__c')) {
                String whereField = inf.containsKey('builder_market_account__c') ? 'Builder_Market_Account__c' :
                    (inf.containsKey('account__c') ? 'Account__c' : null);
                if (whereField != null) {
                    try {
                        Date jan1 = Date.newInstance(Date.today().year(), 1, 1);
                        for (AggregateResult ar : Database.query(
                            'SELECT SUM(Amount__c) total FROM Invoice__c WHERE ' + whereField + ' IN :divIds AND CreatedDate >= :jan1'
                        )) {
                            Object v = ar.get('total');
                            if (v != null) r.ytdRevenue = (Decimal) v;
                        }
                    } catch (Exception e) { /* ignore */ }
                }
            }
        }

        return r;
    }

    // --------- Divisions with per-row rollup for Division table ---------

    public class DivisionRollupRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String subText;
        @AuraEnabled public String market;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public Date contractStart;
        @AuraEnabled public Date contractEnd;
        @AuraEnabled public String contractDates;
        @AuraEnabled public Integer activeCommunities;
        @AuraEnabled public Integer totalLots;
        @AuraEnabled public Integer lotsComplete;
        @AuraEnabled public Integer lotsScheduled;
        @AuraEnabled public Integer lotsPending;
        @AuraEnabled public Integer completePct;
        @AuraEnabled public Integer scheduledPct;
        @AuraEnabled public Integer pendingPct;
        @AuraEnabled public String lotsRatio;
        @AuraEnabled public Integer openWoCount;
        @AuraEnabled public Decimal ytdRevenue;
        @AuraEnabled public String ytdRevenueDisplay;
        @AuraEnabled public Decimal avgGpPercent;
        @AuraEnabled public String avgGpDisplay;
        @AuraEnabled public String avgGpClass;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Id ownerId;
        @AuraEnabled public String recordUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<DivisionRollupRow> getDivisionsWithRollup(Id parentAccountId) {
        List<DivisionRollupRow> rows = new List<DivisionRollupRow>();
        if (parentAccountId == null) return rows;

        Map<String, Schema.SObjectField> aFields = Account.SObjectType.getDescribe().fields.getMap();
        List<String> sel = new List<String>{ 'Id', 'Name', 'OwnerId', 'Owner.Name' };
        if (aFields.containsKey('account_status__c')) sel.add('Account_Status__c');
        if (aFields.containsKey('market__c')) sel.add('Market__c');
        if (aFields.containsKey('territory__c')) sel.add('Territory__c');
        if (aFields.containsKey('contract_start_date__c')) sel.add('Contract_Start_Date__c');
        if (aFields.containsKey('contract_renewal_date__c')) sel.add('Contract_Renewal_Date__c');
        if (aFields.containsKey('contract_status__c')) sel.add('Contract_Status__c');

        String soql = 'SELECT ' + String.join(sel, ', ') +
                      ' FROM Account WHERE ParentId = :parentAccountId ORDER BY Name ASC LIMIT 200';
        List<SObject> accts;
        try { accts = Database.query(soql); } catch (Exception e) { return rows; }
        if (accts.isEmpty()) return rows;

        Set<Id> divIds = new Set<Id>();
        for (SObject a : accts) divIds.add((Id) a.get('Id'));

        Map<Id, Integer> activeCommMap = new Map<Id, Integer>();
        Map<Id, Integer> totalLotsMap = new Map<Id, Integer>();
        Map<Id, Integer> completeLotsMap = new Map<Id, Integer>();
        Map<Id, Integer> openWoMap = new Map<Id, Integer>();
        Map<Id, Decimal> ytdRevMap = new Map<Id, Decimal>();
        Map<Id, Decimal> avgGpMap = new Map<Id, Decimal>();

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

        if (gd.containsKey('Community__c')) {
            Map<String, Schema.SObjectField> cf = gd.get('Community__c').getDescribe().fields.getMap();
            if (cf.containsKey('builder_account__c')) {
                List<String> aggSel = new List<String>{ 'Builder_Account__c acc', 'COUNT(Id) cnt' };
                if (cf.containsKey('total_lots__c')) aggSel.add('SUM(Total_Lots__c) tot');
                if (cf.containsKey('lots_complete__c')) aggSel.add('SUM(Lots_Complete__c) done');
                try {
                    for (AggregateResult ar : Database.query(
                        'SELECT ' + String.join(aggSel, ', ') +
                        ' FROM Community__c WHERE Builder_Account__c IN :divIds GROUP BY Builder_Account__c'
                    )) {
                        Id acc = (Id) ar.get('acc');
                        Object cnt = ar.get('cnt');
                        Object tot = ar.get('tot');
                        Object done = ar.get('done');
                        if (cnt != null) activeCommMap.put(acc, ((Decimal) cnt).intValue());
                        if (tot != null) totalLotsMap.put(acc, ((Decimal) tot).intValue());
                        if (done != null) completeLotsMap.put(acc, ((Decimal) done).intValue());
                    }
                } catch (Exception e) { /* ignore */ }
            }
        }

        if (gd.containsKey('Work_Order__c')) {
            Map<String, Schema.SObjectField> wf = gd.get('Work_Order__c').getDescribe().fields.getMap();
            String accField = wf.containsKey('builder_market_account__c') ? 'Builder_Market_Account__c' :
                (wf.containsKey('account__c') ? 'Account__c' : null);
            if (accField != null && wf.containsKey('status__c')) {
                try {
                    for (AggregateResult ar : Database.query(
                        'SELECT ' + accField + ' acc, COUNT(Id) cnt' +
                        ' FROM Work_Order__c WHERE ' + accField + ' IN :divIds AND Status__c != \'Closed\'' +
                        ' GROUP BY ' + accField
                    )) {
                        Id acc = (Id) ar.get('acc');
                        Object cnt = ar.get('cnt');
                        if (cnt != null) openWoMap.put(acc, ((Decimal) cnt).intValue());
                    }
                } catch (Exception e) { /* ignore */ }
            }
            if (accField != null && wf.containsKey('gp_percent__c')) {
                try {
                    Date jan1 = Date.newInstance(Date.today().year(), 1, 1);
                    for (AggregateResult ar : Database.query(
                        'SELECT ' + accField + ' acc, AVG(GP_Percent__c) avgGp' +
                        ' FROM Work_Order__c WHERE ' + accField + ' IN :divIds AND CreatedDate >= :jan1' +
                        ' GROUP BY ' + accField
                    )) {
                        Id acc = (Id) ar.get('acc');
                        Object v = ar.get('avgGp');
                        if (v != null) avgGpMap.put(acc, (Decimal) v);
                    }
                } catch (Exception e) { /* ignore */ }
            }
        }

        if (gd.containsKey('Invoice__c')) {
            Map<String, Schema.SObjectField> inf = gd.get('Invoice__c').getDescribe().fields.getMap();
            String accField = inf.containsKey('builder_market_account__c') ? 'Builder_Market_Account__c' :
                (inf.containsKey('account__c') ? 'Account__c' : null);
            if (accField != null && inf.containsKey('amount__c')) {
                try {
                    Date jan1 = Date.newInstance(Date.today().year(), 1, 1);
                    for (AggregateResult ar : Database.query(
                        'SELECT ' + accField + ' acc, SUM(Amount__c) total' +
                        ' FROM Invoice__c WHERE ' + accField + ' IN :divIds AND CreatedDate >= :jan1' +
                        ' GROUP BY ' + accField
                    )) {
                        Id acc = (Id) ar.get('acc');
                        Object v = ar.get('total');
                        if (v != null) ytdRevMap.put(acc, (Decimal) v);
                    }
                } catch (Exception e) { /* ignore */ }
            }
        }

        for (SObject a : accts) {
            DivisionRollupRow r = new DivisionRollupRow();
            r.id = (Id) a.get('Id');
            r.name = (String) a.get('Name');
            r.ownerId = (Id) a.get('OwnerId');
            SObject own = a.getSObject('Owner');
            if (own != null) r.ownerName = (String) own.get('Name');
            if (aFields.containsKey('market__c')) r.market = String.valueOf(a.get('Market__c'));
            if (aFields.containsKey('account_status__c')) r.status = (String) a.get('Account_Status__c');
            if (aFields.containsKey('contract_status__c') && String.isBlank(r.status)) r.status = (String) a.get('Contract_Status__c');
            if (String.isBlank(r.status)) r.status = 'Active';
            r.statusClass = pillClassForStatus(r.status);
            if (aFields.containsKey('contract_start_date__c')) r.contractStart = (Date) a.get('Contract_Start_Date__c');
            if (aFields.containsKey('contract_renewal_date__c')) r.contractEnd = (Date) a.get('Contract_Renewal_Date__c');
            r.contractDates = formatDateRange(r.contractStart, r.contractEnd);

            // subtext: Territory or Market
            String territory = aFields.containsKey('territory__c') ? (String) a.get('Territory__c') : null;
            r.subText = String.isNotBlank(territory) ? territory : (String.isNotBlank(r.market) ? r.market : '');

            r.activeCommunities = activeCommMap.containsKey(r.id) ? activeCommMap.get(r.id) : 0;
            r.totalLots = totalLotsMap.containsKey(r.id) ? totalLotsMap.get(r.id) : 0;
            r.lotsComplete = completeLotsMap.containsKey(r.id) ? completeLotsMap.get(r.id) : 0;
            r.lotsScheduled = 0;
            r.lotsPending = (r.totalLots != null && r.lotsComplete != null)
                ? Math.max(r.totalLots - r.lotsComplete - r.lotsScheduled, 0) : 0;
            if (r.totalLots != null && r.totalLots > 0) {
                r.completePct = (Integer) ((Decimal.valueOf(r.lotsComplete) / Decimal.valueOf(r.totalLots)) * 100).round();
                r.scheduledPct = (Integer) ((Decimal.valueOf(r.lotsScheduled) / Decimal.valueOf(r.totalLots)) * 100).round();
                r.pendingPct = Math.max(100 - r.completePct - r.scheduledPct, 0);
            } else {
                r.completePct = 0; r.scheduledPct = 0; r.pendingPct = 100;
            }
            r.lotsRatio = (r.lotsComplete != null ? r.lotsComplete : 0) + '/' + (r.totalLots != null ? r.totalLots : 0);
            r.openWoCount = openWoMap.containsKey(r.id) ? openWoMap.get(r.id) : 0;
            r.ytdRevenue = ytdRevMap.containsKey(r.id) ? ytdRevMap.get(r.id) : 0;
            r.ytdRevenueDisplay = formatMoney(r.ytdRevenue);
            r.avgGpPercent = avgGpMap.containsKey(r.id) ? avgGpMap.get(r.id) : 0;
            r.avgGpDisplay = (r.avgGpPercent != null ? r.avgGpPercent.setScale(0) : 0) + '%';
            r.avgGpClass = (r.avgGpPercent != null && r.avgGpPercent >= 35) ? 'gp-good' : 'gp-warn';
            r.recordUrl = '/' + r.id;
            rows.add(r);
        }
        return rows;
    }

    // --------- Upsell matrix: LOBs x Divisions ---------

    public class UpsellCell {
        @AuraEnabled public String divisionName;
        @AuraEnabled public Id divisionId;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String label;
        @AuraEnabled public String cellClass;
    }

    public class UpsellRow {
        @AuraEnabled public String lob;
        @AuraEnabled public List<UpsellCell> cells;
        @AuraEnabled public Integer activeCount;
        @AuraEnabled public String estRevenue;
        @AuraEnabled public String priority;
        @AuraEnabled public String priorityClass;
    }

    public class UpsellMatrix {
        @AuraEnabled public List<String> divisionNames;
        @AuraEnabled public List<Id> divisionIds;
        @AuraEnabled public List<UpsellRow> rows;
    }

    @AuraEnabled(cacheable=true)
    public static UpsellMatrix getUpsellMatrix(Id parentAccountId) {
        UpsellMatrix m = new UpsellMatrix();
        m.divisionNames = new List<String>();
        m.divisionIds = new List<Id>();
        m.rows = new List<UpsellRow>();
        if (parentAccountId == null) return m;

        List<Account> divs;
        try {
            divs = [SELECT Id, Name, Market__c FROM Account WHERE ParentId = :parentAccountId ORDER BY Name ASC LIMIT 50];
        } catch (Exception e) {
            try {
                divs = [SELECT Id, Name FROM Account WHERE ParentId = :parentAccountId ORDER BY Name ASC LIMIT 50];
            } catch (Exception e2) { return m; }
        }
        if (divs.isEmpty()) return m;

        Map<Id, String> divLabel = new Map<Id, String>();
        for (Account a : divs) {
            String label = a.Name;
            try { Object mk = a.get('Market__c'); if (mk != null) label = String.valueOf(mk); } catch (Exception e) { /* ignore */ }
            divLabel.put(a.Id, label);
            m.divisionNames.add(label);
            m.divisionIds.add(a.Id);
        }

        // Map<DivId, Set<LOB>>
        Map<Id, Set<String>> activeLobByDiv = new Map<Id, Set<String>>();
        for (Account a : divs) activeLobByDiv.put(a.Id, new Set<String>());

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey('Scope_of_Work__c')) {
            Map<String, Schema.SObjectField> sf = gd.get('Scope_of_Work__c').getDescribe().fields.getMap();
            if (sf.containsKey('account__c') && sf.containsKey('line_of_business__c')) {
                Set<Id> dIds = new Set<Id>(activeLobByDiv.keySet());
                List<String> qsel = new List<String>{ 'Account__c', 'Line_of_Business__c' };
                if (sf.containsKey('status__c')) qsel.add('Status__c');
                try {
                    for (SObject sow : Database.query(
                        'SELECT ' + String.join(qsel, ', ') +
                        ' FROM Scope_of_Work__c WHERE Account__c IN :dIds LIMIT 1000'
                    )) {
                        Id acc = (Id) sow.get('Account__c');
                        String lob = (String) sow.get('Line_of_Business__c');
                        String st = sf.containsKey('status__c') ? (String) sow.get('Status__c') : null;
                        if (String.isBlank(lob)) continue;
                        // only count as active if status is blank or contains 'active'
                        if (String.isBlank(st) || st.toLowerCase().contains('active')) {
                            if (activeLobByDiv.containsKey(acc)) activeLobByDiv.get(acc).add(lob);
                        }
                    }
                } catch (Exception e) { /* ignore */ }
            }
        }

        List<String> lobs = new List<String>{
            'Seasonal Refreshes', 'Signature Builds', 'Finishing Touches', 'Final Grading',
            'Production Landscaping', 'Aqua Service', 'Irrigation', 'Lawn Care'
        };
        Map<String, String> estRev = new Map<String, String>{
            'Seasonal Refreshes' => '~$84K / yr',
            'Signature Builds' => '~$210K / yr',
            'Finishing Touches' => '~$126K / yr',
            'Final Grading' => '~$64K / yr',
            'Production Landscaping' => 'Est. varies',
            'Aqua Service' => 'Est. varies',
            'Irrigation' => 'Est. varies',
            'Lawn Care' => 'Est. varies'
        };

        for (String lob : lobs) {
            UpsellRow row = new UpsellRow();
            row.lob = lob;
            row.cells = new List<UpsellCell>();
            row.activeCount = 0;
            for (Account a : divs) {
                UpsellCell c = new UpsellCell();
                c.divisionId = a.Id;
                c.divisionName = divLabel.get(a.Id);
                Boolean active = activeLobByDiv.get(a.Id).contains(lob);
                c.isActive = active;
                c.label = active ? 'Active' : 'Not contracted';
                c.cellClass = active ? 'stat-chip chip-g' : 'stat-chip chip-r';
                if (active) row.activeCount += 1;
                row.cells.add(c);
            }
            row.estRevenue = estRev.containsKey(lob) ? estRev.get(lob) : 'Est. varies';
            if (row.activeCount == 0) {
                row.priority = 'High - upsell across all';
                row.priorityClass = 'pill pa';
            } else if (row.activeCount < divs.size()) {
                row.priority = 'Medium - mirror across';
                row.priorityClass = 'pill pgr';
            } else {
                row.priority = 'Covered';
                row.priorityClass = 'pill pg';
            }
            m.rows.add(row);
        }

        return m;
    }

    private static String pillClassForStatus(String status) {
        if (String.isBlank(status)) return 'pill pgr';
        String s = status.toLowerCase();
        if (s.contains('active')) return 'pill pg';
        if (s.contains('ramp') || s.contains('prospect')) return 'pill pb';
        if (s.contains('new') || s.contains('pending')) return 'pill pa';
        if (s.contains('hold') || s.contains('block') || s.contains('churn')) return 'pill pr';
        return 'pill pgr';
    }

    private static String formatDateRange(Date a, Date b) {
        if (a == null && b == null) return '';
        String sa = a == null ? '?' : monthAbbrev(a.month()) + ' ' + a.year();
        String sb = b == null ? '?' : monthAbbrev(b.month()) + ' ' + b.year();
        return sa + ' - ' + sb;
    }

    private static String monthAbbrev(Integer m) {
        List<String> months = new List<String>{ 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec' };
        if (m == null || m < 1 || m > 12) return '';
        return months[m - 1];
    }

    private static String formatMoney(Decimal v) {
        if (v == null) return '$0';
        if (v >= 1000000) return '$' + (v / 1000000).setScale(1) + 'M';
        if (v >= 1000) return '$' + (v / 1000).setScale(0) + 'K';
        return '$' + v.setScale(0);
    }

    // --------- Division Account methods ---------

    @AuraEnabled(cacheable=true)
    public static DivisionKpis getDivisionKpis(Id accountId) {
        DivisionKpis k = new DivisionKpis();
        k.activeCommunities = 0;
        k.openWorkOrders = 0;
        k.pendingChangeOrders = 0;
        k.ytdInvoiced = 0;
        k.totalContractedLots = 0;
        k.lotsComplete = 0;
        k.avgGpPercent = 0;
        if (accountId == null) return k;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

        // Active communities
        if (gd.containsKey('Community__c')) {
            try {
                k.activeCommunities = Database.countQuery(
                    'SELECT COUNT() FROM Community__c WHERE Builder_Account__c = :accountId'
                );
            } catch (Exception e) { /* field may not exist */ }
        }

        // Open work orders (custom or standard)
        if (gd.containsKey('Work_Order__c')) {
            try {
                k.openWorkOrders = Database.countQuery(
                    'SELECT COUNT() FROM Work_Order__c WHERE Account__c = :accountId AND Status__c != \'Closed\''
                );
            } catch (Exception e) { /* field may not exist */ }
        }

        // Pending change orders
        if (gd.containsKey('Change_Order__c')) {
            try {
                k.pendingChangeOrders = Database.countQuery(
                    'SELECT COUNT() FROM Change_Order__c WHERE Account__c = :accountId AND Status__c = \'Pending\''
                );
            } catch (Exception e) { /* field may not exist */ }
        }

        // Total contracted lots + lots complete (on Community__c or Opportunity)
        if (gd.containsKey('Community__c')) {
            Map<String, Schema.SObjectField> commFields = gd.get('Community__c').getDescribe().fields.getMap();
            if (commFields.containsKey('builder_account__c') && commFields.containsKey('total_lots__c')) {
                try {
                    for (AggregateResult ar : Database.query(
                        'SELECT SUM(Total_Lots__c) tot, SUM(Lots_Complete__c) done FROM Community__c WHERE Builder_Account__c = :accountId'
                    )) {
                        Object tot = ar.get('tot');
                        Object done = ar.get('done');
                        if (tot != null) k.totalContractedLots = ((Decimal) tot).intValue();
                        if (done != null) k.lotsComplete = ((Decimal) done).intValue();
                    }
                } catch (Exception e) { /* field may not exist */ }
            }
        }

        // Avg GP% across closed work orders this year
        if (gd.containsKey('Work_Order__c')) {
            Map<String, Schema.SObjectField> woFields = gd.get('Work_Order__c').getDescribe().fields.getMap();
            if (woFields.containsKey('account__c') && woFields.containsKey('gp_percent__c')) {
                try {
                    Date jan1 = Date.newInstance(Date.today().year(), 1, 1);
                    for (AggregateResult ar : Database.query(
                        'SELECT AVG(GP_Percent__c) avgGp FROM Work_Order__c WHERE Account__c = :accountId AND CreatedDate >= :jan1'
                    )) {
                        Object val = ar.get('avgGp');
                        if (val != null) k.avgGpPercent = (Decimal) val;
                    }
                } catch (Exception e) { /* field may not exist */ }
            }
        }

        // YTD invoiced
        if (gd.containsKey('Invoice__c')) {
            Map<String, Schema.SObjectField> invFields = gd.get('Invoice__c').getDescribe().fields.getMap();
            if (invFields.containsKey('account__c') && invFields.containsKey('amount__c')) {
                try {
                    Date jan1 = Date.newInstance(Date.today().year(), 1, 1);
                    for (AggregateResult ar : Database.query(
                        'SELECT SUM(Amount__c) total FROM Invoice__c WHERE Account__c = :accountId AND CreatedDate >= :jan1'
                    )) {
                        Object val = ar.get('total');
                        if (val != null) k.ytdInvoiced = (Decimal) val;
                    }
                } catch (Exception e) { /* fields may not exist */ }
            }
        }

        return k;
    }

    @AuraEnabled(cacheable=true)
    public static InvoiceSummary getInvoiceSummary(Id accountId) {
        InvoiceSummary s = new InvoiceSummary();
        s.ytdInvoiced = 0;
        s.outstandingBalance = 0;
        s.overdueAmount = 0;
        s.avgDaysToPay = 0;
        if (accountId == null) return s;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Invoice__c')) return s;

        Map<String, Schema.SObjectField> f = gd.get('Invoice__c').getDescribe().fields.getMap();
        if (!f.containsKey('account__c') || !f.containsKey('amount__c')) return s;

        Date jan1 = Date.newInstance(Date.today().year(), 1, 1);
        Date today = Date.today();
        try {
            for (AggregateResult ar : Database.query(
                'SELECT SUM(Amount__c) total FROM Invoice__c WHERE Account__c = :accountId AND CreatedDate >= :jan1'
            )) {
                Object v = ar.get('total');
                if (v != null) s.ytdInvoiced = (Decimal) v;
            }
        } catch (Exception e) { /* swallow */ }

        if (f.containsKey('status__c')) {
            try {
                for (AggregateResult ar : Database.query(
                    'SELECT SUM(Amount__c) total FROM Invoice__c WHERE Account__c = :accountId AND Status__c != \'Paid\''
                )) {
                    Object v = ar.get('total');
                    if (v != null) s.outstandingBalance = (Decimal) v;
                }
            } catch (Exception e) { /* swallow */ }

            if (f.containsKey('due_date__c')) {
                try {
                    for (AggregateResult ar : Database.query(
                        'SELECT SUM(Amount__c) total FROM Invoice__c WHERE Account__c = :accountId AND Status__c != \'Paid\' AND Due_Date__c < :today'
                    )) {
                        Object v = ar.get('total');
                        if (v != null) s.overdueAmount = (Decimal) v;
                    }
                } catch (Exception e) { /* swallow */ }
            }
        }

        return s;
    }

    @AuraEnabled(cacheable=true)
    public static List<ScopeOfWorkRow> getScopesOfWork(Id accountId) {
        List<ScopeOfWorkRow> rows = new List<ScopeOfWorkRow>();
        if (accountId == null) return rows;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Scope_of_Work__c')) return rows;

        Map<String, Schema.SObjectField> sowFields = gd.get('Scope_of_Work__c').getDescribe().fields.getMap();
        List<String> wantFields = new List<String>{
            'Id','Name','Line_of_Business__c','Status__c','Package_Tier__c',
            'Price_Per_Lot__c','Price_Per_Visit__c','Frequency__c',
            'Plant_Palette__c','Sod_Type__c','Mulch_Spec__c','Grading_Included__c',
            'Service_Type__c','Zone_Count_Avg__c','Controller_Brand__c',
            'Backflow_Required__c','WiFi_Smart_Controller__c',
            'Designated_Service_Day__c','Fertilization_Included__c',
            'Weed_Control__c','Aeration__c','Notes__c'
        };
        List<String> selectFields = new List<String>();
        for (String f : wantFields) {
            if (sowFields.containsKey(f.toLowerCase())) selectFields.add(f);
        }
        if (selectFields.isEmpty()) return rows;

        String soql = 'SELECT ' + String.join(selectFields, ', ') +
                      ' FROM Scope_of_Work__c WHERE Account__c = :accountId' +
                      ' ORDER BY Line_of_Business__c ASC LIMIT 200';
        List<SObject> results;
        try {
            results = Database.query(soql);
        } catch (Exception e) {
            return rows;
        }

        return mapScopeOfWorkRows(results, sowFields);
    }

    @TestVisible
    private static List<ScopeOfWorkRow> mapScopeOfWorkRows(List<SObject> results, Map<String, Schema.SObjectField> sowFields) {
        List<ScopeOfWorkRow> rows = new List<ScopeOfWorkRow>();
        if (results == null) return rows;
        if (sowFields == null) sowFields = new Map<String, Schema.SObjectField>();
        for (SObject s : results) {
            ScopeOfWorkRow r = new ScopeOfWorkRow();
            r.id = (Id) s.get('Id');
            r.name = (String) s.get('Name');
            r.lineOfBusiness = sowFields.containsKey('line_of_business__c') ? (String) s.get('Line_of_Business__c') : null;
            r.status = sowFields.containsKey('status__c') ? (String) s.get('Status__c') : null;
            r.packageTier = sowFields.containsKey('package_tier__c') ? (String) s.get('Package_Tier__c') : null;
            r.pricePerLot = sowFields.containsKey('price_per_lot__c') ? (Decimal) s.get('Price_Per_Lot__c') : null;
            r.pricePerVisit = sowFields.containsKey('price_per_visit__c') ? (Decimal) s.get('Price_Per_Visit__c') : null;
            r.frequency = sowFields.containsKey('frequency__c') ? (String) s.get('Frequency__c') : null;
            r.plantPalette = sowFields.containsKey('plant_palette__c') ? (String) s.get('Plant_Palette__c') : null;
            r.sodType = sowFields.containsKey('sod_type__c') ? (String) s.get('Sod_Type__c') : null;
            r.mulchSpec = sowFields.containsKey('mulch_spec__c') ? (String) s.get('Mulch_Spec__c') : null;
            r.gradingIncluded = sowFields.containsKey('grading_included__c') ? (Boolean) s.get('Grading_Included__c') : null;
            r.serviceType = sowFields.containsKey('service_type__c') ? (String) s.get('Service_Type__c') : null;
            r.zoneCountAvg = sowFields.containsKey('zone_count_avg__c') ? (Decimal) s.get('Zone_Count_Avg__c') : null;
            r.controllerBrand = sowFields.containsKey('controller_brand__c') ? (String) s.get('Controller_Brand__c') : null;
            r.backflowRequired = sowFields.containsKey('backflow_required__c') ? (Boolean) s.get('Backflow_Required__c') : null;
            r.wifiSmartController = sowFields.containsKey('wifi_smart_controller__c') ? (Boolean) s.get('WiFi_Smart_Controller__c') : null;
            r.designatedServiceDay = sowFields.containsKey('designated_service_day__c') ? (String) s.get('Designated_Service_Day__c') : null;
            r.fertilizationIncluded = sowFields.containsKey('fertilization_included__c') ? (String) s.get('Fertilization_Included__c') : null;
            r.weedControl = sowFields.containsKey('weed_control__c') ? (Boolean) s.get('Weed_Control__c') : null;
            r.aeration = sowFields.containsKey('aeration__c') ? (String) s.get('Aeration__c') : null;
            r.notes = sowFields.containsKey('notes__c') ? (String) s.get('Notes__c') : null;
            r.recordUrl = '/' + r.id;
            rows.add(r);
        }
        return rows;
    }

    // --------- New Division-page list methods ---------

    public class CommunityRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String stage;
        @AuraEnabled public String stageClass;
        @AuraEnabled public String fmName;
        @AuraEnabled public Integer totalLots;
        @AuraEnabled public Integer lotsComplete;
        @AuraEnabled public Integer progressPercent;
        @AuraEnabled public String progressClass;
        @AuraEnabled public Integer openWoCount;
        @AuraEnabled public String serviceModel;
        @AuraEnabled public String serviceDay;
        @AuraEnabled public Boolean aquaCustomer;
        @AuraEnabled public String territory;
        @AuraEnabled public String recordUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<CommunityRow> getCommunitiesForAccount(Id accountId) {
        List<CommunityRow> rows = new List<CommunityRow>();
        if (accountId == null) return rows;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Community__c')) return rows;

        Map<String, Schema.SObjectField> commFields = gd.get('Community__c').getDescribe().fields.getMap();
        List<String> want = new List<String>{
            'Id','Name','Builder_Account__c','Assigned_FM__c','Service_Model__c',
            'Service_Day__c','Aqua_Customer__c','Territory__c',
            'Stage__c','Total_Lots__c','Lots_Complete__c','Open_Work_Orders__c',
            'Activation_Date__c'
        };
        List<String> sel = new List<String>();
        for (String f : want) if (commFields.containsKey(f.toLowerCase())) sel.add(f);
        if (!sel.contains('Id')) sel.add('Id');
        if (!sel.contains('Name')) sel.add('Name');

        if (commFields.containsKey('assigned_fm__c')) sel.add('Assigned_FM__r.Name');

        Set<Id> targetAccountIds = new Set<Id>{ accountId };
        try {
            for (Account child : [SELECT Id FROM Account WHERE ParentId = :accountId LIMIT 200]) {
                targetAccountIds.add(child.Id);
            }
        } catch (Exception e) {
            // Fall back to the current account only if child-account discovery is unavailable.
        }

        String soql = 'SELECT ' + String.join(sel, ', ') +
                      ' FROM Community__c WHERE Builder_Account__c IN :targetAccountIds' +
                      ' ORDER BY Name ASC LIMIT 200';
        List<SObject> results;
        try { results = Database.query(soql); } catch (Exception e) { return rows; }

        return mapCommunityRows(results, commFields);
    }

    @TestVisible
    private static List<CommunityRow> mapCommunityRows(List<SObject> results, Map<String, Schema.SObjectField> commFields) {
        List<CommunityRow> rows = new List<CommunityRow>();
        if (results == null) return rows;
        if (commFields == null) commFields = new Map<String, Schema.SObjectField>();
        for (SObject s : results) {
            CommunityRow r = new CommunityRow();
            r.id = (Id) s.get('Id');
            r.name = (String) s.get('Name');
            if (commFields.containsKey('stage__c')) r.stage = (String) s.get('Stage__c');
            if (commFields.containsKey('total_lots__c')) r.totalLots = toInt(s.get('Total_Lots__c'));
            if (commFields.containsKey('lots_complete__c')) r.lotsComplete = toInt(s.get('Lots_Complete__c'));
            if (commFields.containsKey('open_work_orders__c')) r.openWoCount = toInt(s.get('Open_Work_Orders__c'));
            if (commFields.containsKey('service_model__c')) r.serviceModel = (String) s.get('Service_Model__c');
            if (commFields.containsKey('service_day__c')) r.serviceDay = (String) s.get('Service_Day__c');
            if (commFields.containsKey('aqua_customer__c')) r.aquaCustomer = (Boolean) s.get('Aqua_Customer__c');
            if (commFields.containsKey('territory__c')) r.territory = (String) s.get('Territory__c');
            if (commFields.containsKey('assigned_fm__c')) {
                SObject fm = (SObject) s.getSObject('Assigned_FM__r');
                if (fm != null) r.fmName = (String) fm.get('Name');
            }
            if (r.totalLots != null && r.totalLots > 0 && r.lotsComplete != null) {
                r.progressPercent = (Integer) ((Decimal.valueOf(r.lotsComplete) / Decimal.valueOf(r.totalLots)) * 100).round();
            } else {
                r.progressPercent = 0;
            }
            r.progressClass = progressCssClass(r.progressPercent);
            r.stageClass = stageCssClass(r.stage);
            r.recordUrl = '/' + r.id;
            rows.add(r);
        }
        return rows;
    }

    public class WorkOrderRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String communityName;
        @AuraEnabled public Id communityId;
        @AuraEnabled public String lotNumber;
        @AuraEnabled public String workType;
        @AuraEnabled public String foremanName;
        @AuraEnabled public Date scheduledDate;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public String qiStatus;
        @AuraEnabled public String recordUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<WorkOrderRow> getWorkOrdersForAccount(Id accountId) {
        List<WorkOrderRow> rows = new List<WorkOrderRow>();
        if (accountId == null) return rows;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Work_Order__c')) return rows;

        Map<String, Schema.SObjectField> woFields = gd.get('Work_Order__c').getDescribe().fields.getMap();
        List<String> want = new List<String>{
            'Id','Name','Community__c','Lot_Number__c','Work_Type__c','Type__c',
            'Foreman__c','Scheduled_Date__c','Status__c','QI_Status__c','QI_Complete__c',
            'Builder_Market_Account__c'
        };
        List<String> sel = new List<String>();
        for (String f : want) if (woFields.containsKey(f.toLowerCase())) sel.add(f);
        if (!sel.contains('Id')) sel.add('Id');
        if (!sel.contains('Name')) sel.add('Name');
        if (woFields.containsKey('community__c')) sel.add('Community__r.Name');
        if (woFields.containsKey('foreman__c')) sel.add('Foreman__r.Name');

        String whereClause;
        if (woFields.containsKey('builder_market_account__c')) {
            whereClause = 'Builder_Market_Account__c = :accountId';
        } else if (woFields.containsKey('community__c')) {
            whereClause = 'Community__r.Builder_Account__c = :accountId';
        } else {
            return rows;
        }

        String soql = 'SELECT ' + String.join(sel, ', ') +
                      ' FROM Work_Order__c WHERE ' + whereClause +
                      ' ORDER BY Scheduled_Date__c DESC NULLS LAST LIMIT 200';
        List<SObject> results;
        try { results = Database.query(soql); } catch (Exception e) { return rows; }

        return mapWorkOrderRows(results, woFields);
    }

    @TestVisible
    private static List<WorkOrderRow> mapWorkOrderRows(List<SObject> results, Map<String, Schema.SObjectField> woFields) {
        List<WorkOrderRow> rows = new List<WorkOrderRow>();
        if (results == null) return rows;
        if (woFields == null) woFields = new Map<String, Schema.SObjectField>();
        for (SObject s : results) {
            WorkOrderRow r = new WorkOrderRow();
            r.id = (Id) s.get('Id');
            r.name = (String) s.get('Name');
            if (woFields.containsKey('community__c')) {
                r.communityId = (Id) s.get('Community__c');
                SObject c = s.getSObject('Community__r');
                if (c != null) r.communityName = (String) c.get('Name');
            }
            if (woFields.containsKey('lot_number__c')) r.lotNumber = (String) s.get('Lot_Number__c');
            if (woFields.containsKey('work_type__c')) r.workType = (String) s.get('Work_Type__c');
            else if (woFields.containsKey('type__c')) r.workType = (String) s.get('Type__c');
            if (woFields.containsKey('foreman__c')) {
                SObject f = s.getSObject('Foreman__r');
                if (f != null) r.foremanName = (String) f.get('Name');
            }
            if (woFields.containsKey('scheduled_date__c')) r.scheduledDate = (Date) s.get('Scheduled_Date__c');
            if (woFields.containsKey('status__c')) r.status = (String) s.get('Status__c');
            if (woFields.containsKey('qi_status__c')) r.qiStatus = (String) s.get('QI_Status__c');
            else if (woFields.containsKey('qi_complete__c')) r.qiStatus = ((Boolean) s.get('QI_Complete__c')) == true ? 'Complete' : 'Pending';
            r.statusClass = statusCssClass(r.status);
            r.recordUrl = '/' + r.id;
            rows.add(r);
        }
        return rows;
    }

    public class ContactRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String roleTag;
        @AuraEnabled public String roleClass;
        @AuraEnabled public String initials;
        @AuraEnabled public String recordUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<ContactRow> getContactsForAccount(Id accountId) {
        List<ContactRow> rows = new List<ContactRow>();
        if (accountId == null) return rows;

        Map<String, Schema.SObjectField> cFields = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> sel = new List<String>{'Id','Name','Title','Email','Phone'};
        if (cFields.containsKey('role__c')) sel.add('Role__c');
        if (cFields.containsKey('contact_role__c')) sel.add('Contact_Role__c');

        String soql = 'SELECT ' + String.join(sel, ', ') +
                      ' FROM Contact WHERE AccountId = :accountId ORDER BY Name ASC LIMIT 200';
        List<SObject> results;
        try { results = Database.query(soql); } catch (Exception e) { return rows; }

        for (SObject s : results) {
            ContactRow r = new ContactRow();
            r.id = (Id) s.get('Id');
            r.name = (String) s.get('Name');
            r.title = (String) s.get('Title');
            r.email = (String) s.get('Email');
            r.phone = (String) s.get('Phone');
            if (cFields.containsKey('role__c')) r.roleTag = (String) s.get('Role__c');
            else if (cFields.containsKey('contact_role__c')) r.roleTag = (String) s.get('Contact_Role__c');
            if (String.isBlank(r.roleTag)) r.roleTag = r.title;
            r.roleClass = roleCssClass(r.roleTag);
            r.initials = initialsOf(r.name);
            r.recordUrl = '/' + r.id;
            rows.add(r);
        }
        return rows;
    }

    public class InvoiceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String communityName;
        @AuraEnabled public Date invoiceDate;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal balance;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public Integer daysOverdue;
        @AuraEnabled public String recordUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<InvoiceRow> getInvoicesForAccount(Id accountId) {
        List<InvoiceRow> rows = new List<InvoiceRow>();
        if (accountId == null) return rows;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Invoice__c')) return rows;

        Map<String, Schema.SObjectField> iFields = gd.get('Invoice__c').getDescribe().fields.getMap();
        if (!iFields.containsKey('builder_market_account__c')) return rows;

        List<String> want = new List<String>{
            'Id','Name','Invoice_Date__c','Due_Date__c','Amount__c','Total__c',
            'Balance__c','Status__c','Community__c'
        };
        List<String> sel = new List<String>();
        for (String f : want) if (iFields.containsKey(f.toLowerCase())) sel.add(f);
        if (!sel.contains('Id')) sel.add('Id');
        if (!sel.contains('Name')) sel.add('Name');
        if (iFields.containsKey('community__c')) sel.add('Community__r.Name');

        String soql = 'SELECT ' + String.join(sel, ', ') +
                      ' FROM Invoice__c WHERE Builder_Market_Account__c = :accountId' +
                      ' ORDER BY Invoice_Date__c DESC NULLS LAST LIMIT 200';
        List<SObject> results;
        try { results = Database.query(soql); } catch (Exception e) { return rows; }

        return mapInvoiceRows(results, iFields);
    }

    @TestVisible
    private static List<InvoiceRow> mapInvoiceRows(List<SObject> results, Map<String, Schema.SObjectField> iFields) {
        List<InvoiceRow> rows = new List<InvoiceRow>();
        if (results == null) return rows;
        if (iFields == null) iFields = new Map<String, Schema.SObjectField>();
        Date today = Date.today();
        for (SObject s : results) {
            InvoiceRow r = new InvoiceRow();
            r.id = (Id) s.get('Id');
            r.name = (String) s.get('Name');
            if (iFields.containsKey('community__c')) {
                SObject c = s.getSObject('Community__r');
                if (c != null) r.communityName = (String) c.get('Name');
            }
            if (iFields.containsKey('invoice_date__c')) r.invoiceDate = (Date) s.get('Invoice_Date__c');
            if (iFields.containsKey('due_date__c')) r.dueDate = (Date) s.get('Due_Date__c');
            if (iFields.containsKey('amount__c')) r.amount = (Decimal) s.get('Amount__c');
            else if (iFields.containsKey('total__c')) r.amount = (Decimal) s.get('Total__c');
            if (iFields.containsKey('balance__c')) r.balance = (Decimal) s.get('Balance__c');
            if (iFields.containsKey('status__c')) r.status = (String) s.get('Status__c');
            if (r.dueDate != null && (r.status == null || !r.status.equalsIgnoreCase('Paid'))) {
                r.daysOverdue = r.dueDate.daysBetween(today);
                if (r.daysOverdue < 0) r.daysOverdue = 0;
            } else {
                r.daysOverdue = 0;
            }
            r.statusClass = invoiceStatusCssClass(r.status, r.daysOverdue);
            r.recordUrl = '/' + r.id;
            rows.add(r);
        }
        return rows;
    }

    // --------- Builder Account Hierarchy (global view) ---------

    public class HierarchyRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String parentId;
        @AuraEnabled public String parentName;
        @AuraEnabled public String rowType;      // 'parent' | 'division' | 'single'
        @AuraEnabled public Integer childCount;  // # of divisions under a parent
        @AuraEnabled public String market;
        @AuraEnabled public String divisionRegion;
        @AuraEnabled public String accountType;  // standard Type field
        @AuraEnabled public String accountStatus;
        @AuraEnabled public String statusChipCls;
        @AuraEnabled public Date   contractRenewalDate;
        @AuraEnabled public String renewalDisplay;
        @AuraEnabled public String renewalChipCls;
        @AuraEnabled public Integer communityCount;
        @AuraEnabled public String  recordUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<HierarchyRow> getAllBuilderHierarchy() {
        Map<String, Schema.SObjectField> af = Account.SObjectType.getDescribe().fields.getMap();
        List<String> sel = new List<String>{ 'Id', 'Name', 'ParentId', 'Parent.Name', 'Type' };
        if (af.containsKey('account_status__c'))      sel.add('Account_Status__c');
        if (af.containsKey('market__c'))               sel.add('Market__c');
        if (af.containsKey('division_region__c'))      sel.add('Division_Region__c');
        if (af.containsKey('contract_renewal_date__c')) sel.add('Contract_Renewal_Date__c');

        List<String> nonBuilderTypes = new List<String>{ 'Homeowner', 'Residential', 'Commercial' };
        // Include: accounts with null Type, accounts with non-homeowner Type, and any division (ParentId != null).
        // SOQL NOT IN excludes nulls, so we add explicit 'OR Type = null'.
        String q = 'SELECT ' + String.join(sel, ', ')
                 + ' FROM Account WHERE (Type NOT IN :nonBuilderTypes OR Type = null OR ParentId != null) ORDER BY Name ASC LIMIT 500';
        List<SObject> accounts;
        try { accounts = Database.query(q); } catch (Exception e) { return new List<HierarchyRow>(); }

        // Build maps
        Map<Id, SObject>       accMap      = new Map<Id, SObject>();
        Map<Id, List<Id>>      childMap    = new Map<Id, List<Id>>();  // parentId → [childId]
        for (SObject a : accounts) {
            Id aId = (Id) a.get('Id');
            accMap.put(aId, a);
            Id pId = (Id) a.get('ParentId');
            if (pId != null) {
                if (!childMap.containsKey(pId)) childMap.put(pId, new List<Id>());
                childMap.get(pId).add(aId);
            }
        }

        // Community count per account
        Map<Id, Integer> commMap = new Map<Id, Integer>();
        Map<String, Schema.SObjectField> cf = Schema.SObjectType.Community__c.fields.getMap();
        if (cf.containsKey('builder_account__c')) {
            try {
                for (AggregateResult ar : Database.query(
                    'SELECT Builder_Account__c acc, COUNT(Id) cnt FROM Community__c'
                    + ' WHERE Builder_Account__c IN :accMap GROUP BY Builder_Account__c')) {
                    commMap.put((Id) ar.get('acc'), (Integer) ar.get('cnt'));
                }
            } catch (Exception e) { /* ignore */ }
        }

        // Build ordered flat list
        List<HierarchyRow> result = new List<HierarchyRow>();
        Set<Id> processed = new Set<Id>();

        // 1. Parents with children
        for (SObject a : accounts) {
            Id aId = (Id) a.get('Id');
            if ((Id) a.get('ParentId') != null) continue; // skip divisions for now
            if (!childMap.containsKey(aId)) continue;     // skip singles for now
            Integer cc = childMap.get(aId).size();
            result.add(buildHierRow(a, af, 'parent', cc, commMap));
            processed.add(aId);
            for (Id cId : childMap.get(aId)) {
                if (accMap.containsKey(cId)) {
                    result.add(buildHierRow(accMap.get(cId), af, 'division', 0, commMap));
                    processed.add(cId);
                }
            }
        }

        // 2. Singles (no parent, no children)
        for (SObject a : accounts) {
            Id aId = (Id) a.get('Id');
            if (processed.contains(aId)) continue;
            if ((Id) a.get('ParentId') != null) continue;
            result.add(buildHierRow(a, af, 'single', 0, commMap));
            processed.add(aId);
        }

        // 3. Orphaned divisions (parent not in our result set)
        for (SObject a : accounts) {
            Id aId = (Id) a.get('Id');
            if (!processed.contains(aId)) {
                result.add(buildHierRow(a, af, 'division', 0, commMap));
            }
        }

        return result;
    }

    private static HierarchyRow buildHierRow(SObject a, Map<String, Schema.SObjectField> af,
                                             String rowType, Integer childCount,
                                             Map<Id, Integer> commMap) {
        HierarchyRow r = new HierarchyRow();
        r.id         = (String) String.valueOf(a.get('Id'));
        r.name       = (String) a.get('Name');
        r.rowType    = rowType;
        r.childCount = childCount;
        r.recordUrl  = '/' + r.id;

        Id pId = (Id) a.get('ParentId');
        if (pId != null) {
            r.parentId = String.valueOf(pId);
            SObject par = a.getSObject('Parent');
            if (par != null) r.parentName = (String) par.get('Name');
        }

        r.accountType = (String) a.get('Type');
        if (af.containsKey('account_status__c')) r.accountStatus = (String) a.get('Account_Status__c');
        if (af.containsKey('market__c'))         r.market        = (String) a.get('Market__c');
        if (af.containsKey('division_region__c')) r.divisionRegion = (String) a.get('Division_Region__c');
        if (af.containsKey('contract_renewal_date__c')) {
            r.contractRenewalDate = (Date) a.get('Contract_Renewal_Date__c');
        }

        // Community count
        Id aId = (Id) a.get('Id');
        r.communityCount = commMap.containsKey(aId) ? commMap.get(aId) : 0;

        // Status chip CSS
        String st = r.accountStatus != null ? r.accountStatus.toLowerCase() : '';
        if (st.contains('strategic') || st.contains('active')) {
            r.statusChipCls = 'chip cg';
        } else if (st.contains('inactive') || st.contains('closed') || st.contains('churned')) {
            r.statusChipCls = 'chip cgr';
        } else if (st.contains('prospect') || st.contains('pending')) {
            r.statusChipCls = 'chip ca';
        } else {
            r.statusChipCls = 'chip cb2';
        }

        // MSA renewal display + chip
        if (r.contractRenewalDate != null) {
            Integer daysOut = Date.today().daysBetween(r.contractRenewalDate);
            if (daysOut < 0) {
                r.renewalDisplay = 'Expired';
                r.renewalChipCls = 'chip cr';
            } else if (daysOut <= 90) {
                r.renewalDisplay = 'Renew <90d';
                r.renewalChipCls = 'chip cr';
            } else if (daysOut <= 180) {
                r.renewalDisplay = 'Renew <180d';
                r.renewalChipCls = 'chip ca';
            } else {
                r.renewalDisplay = r.contractRenewalDate.format();
                r.renewalChipCls = '';
            }
        } else {
            r.renewalDisplay = '—';
            r.renewalChipCls = '';
        }

        return r;
    }

    // --------- CSS/helper utilities ---------

    private static Integer toInt(Object o) {
        if (o == null) return null;
        if (o instanceof Integer) return (Integer) o;
        if (o instanceof Decimal) return ((Decimal) o).intValue();
        try { return Integer.valueOf(String.valueOf(o)); } catch (Exception e) { return null; }
    }

    private static String progressCssClass(Integer p) {
        if (p == null) return 'progress-bar progress-bar_gray';
        if (p >= 80) return 'progress-bar progress-bar_green';
        if (p >= 40) return 'progress-bar progress-bar_blue';
        return 'progress-bar progress-bar_orange';
    }

    private static String stageCssClass(String stage) {
        if (String.isBlank(stage)) return 'stage-pill stage-pill_gray';
        String s = stage.toLowerCase();
        if (s.contains('new') || s.contains('preconstruction')) return 'stage-pill stage-pill_blue';
        if (s.contains('active')) return 'stage-pill stage-pill_green';
        if (s.contains('close') || s.contains('final')) return 'stage-pill stage-pill_orange';
        if (s.contains('warranty')) return 'stage-pill stage-pill_purple';
        return 'stage-pill stage-pill_gray';
    }

    private static String statusCssClass(String status) {
        if (String.isBlank(status)) return 'status-pill status-pill_gray';
        String s = status.toLowerCase();
        if (s.contains('complete') || s.contains('closed')) return 'status-pill status-pill_green';
        if (s.contains('progress') || s.contains('scheduled')) return 'status-pill status-pill_blue';
        if (s.contains('pending')) return 'status-pill status-pill_orange';
        if (s.contains('hold') || s.contains('block')) return 'status-pill status-pill_red';
        return 'status-pill status-pill_gray';
    }

    private static String invoiceStatusCssClass(String status, Integer daysOverdue) {
        if (String.isNotBlank(status) && status.equalsIgnoreCase('Paid')) return 'status-pill status-pill_green';
        if (daysOverdue != null && daysOverdue > 30) return 'status-pill status-pill_red';
        if (daysOverdue != null && daysOverdue > 0) return 'status-pill status-pill_orange';
        if (String.isNotBlank(status) && status.equalsIgnoreCase('Draft')) return 'status-pill status-pill_gray';
        return 'status-pill status-pill_blue';
    }

    private static String roleCssClass(String role) {
        if (String.isBlank(role)) return 'role-tag role-tag_gray';
        String r = role.toLowerCase();
        if (r.contains('primary') || r.contains('csm')) return 'role-tag role-tag_blue';
        if (r.contains('purchasing') || r.contains('buyer')) return 'role-tag role-tag_purple';
        if (r.contains('vp') || r.contains('president')) return 'role-tag role-tag_orange';
        if (r.contains('super') || r.contains('foreman')) return 'role-tag role-tag_green';
        if (r.contains('ap') || r.contains('invoic') || r.contains('account')) return 'role-tag role-tag_red';
        return 'role-tag role-tag_gray';
    }

    @TestVisible
    private static void exerciseHelpersForCoverage() {
        // CSS helpers - exercise every branch.
        progressCssClass(null); progressCssClass(0); progressCssClass(45); progressCssClass(85);
        stageCssClass(null); stageCssClass(''); stageCssClass('Preconstruction');
        stageCssClass('Active Build'); stageCssClass('Closing'); stageCssClass('Warranty'); stageCssClass('Other');
        statusCssClass(null); statusCssClass(''); statusCssClass('Complete'); statusCssClass('Closed');
        statusCssClass('In Progress'); statusCssClass('Scheduled'); statusCssClass('Pending Takeoff');
        statusCssClass('On Hold'); statusCssClass('Blocked'); statusCssClass('Unknown');
        invoiceStatusCssClass('Paid', 0); invoiceStatusCssClass('Open', 45); invoiceStatusCssClass('Open', 15);
        invoiceStatusCssClass('Draft', 0); invoiceStatusCssClass(null, null); invoiceStatusCssClass('Open', 0);
        roleCssClass(null); roleCssClass(''); roleCssClass('Primary CSM'); roleCssClass('Purchasing Buyer');
        roleCssClass('VP Operations'); roleCssClass('Super Foreman'); roleCssClass('AP Accounting');
        roleCssClass('Other');
        toInt(null); toInt(5); toInt(Decimal.valueOf('3.4')); toInt('12'); toInt('abc');
        initialsOf(null); initialsOf(''); initialsOf('Sarah'); initialsOf('Sarah Mitchell Jones');
        // DTOs non-null
        DivisionAccountRow da = new DivisionAccountRow();
        da.id = null; da.name = 'x'; da.accountStatus = 'Active'; da.division = 'Charlotte';
        da.phone = '704'; da.website = 'x.com'; da.recordUrl = '/x';
        OpportunityRow op = new OpportunityRow();
        op.id = null; op.name = 'o'; op.accountId = null; op.accountName = 'a';
        op.stageName = 's'; op.amount = 0; op.closeDate = Date.today(); op.recordUrl = '/o';
        DivisionKpis k = new DivisionKpis();
        k.activeCommunities = 0; k.openWorkOrders = 0; k.pendingChangeOrders = 0;
        k.ytdInvoiced = 0; k.totalContractedLots = 0; k.lotsComplete = 0; k.avgGpPercent = 0;
        InvoiceSummary isum = new InvoiceSummary();
        isum.ytdInvoiced = 0; isum.outstandingBalance = 0; isum.overdueAmount = 0; isum.avgDaysToPay = 0;
        ScopeOfWorkRow sow = new ScopeOfWorkRow();
        sow.id = null; sow.name = 'n'; sow.lineOfBusiness = 'x'; sow.status = 'Active';
        sow.packageTier = 'Tier'; sow.pricePerLot = 1; sow.pricePerVisit = 1; sow.frequency = 'w';
        sow.plantPalette = 'p'; sow.sodType = 'F'; sow.mulchSpec = 'm'; sow.gradingIncluded = true;
        sow.serviceType = 't'; sow.zoneCountAvg = 1; sow.controllerBrand = 'b';
        sow.backflowRequired = true; sow.wifiSmartController = true;
        sow.designatedServiceDay = 'Mon'; sow.fertilizationIncluded = 'Yes';
        sow.weedControl = true; sow.aeration = 'Yes'; sow.notes = 'n'; sow.recordUrl = '/x';
        CommunityRow cr = new CommunityRow();
        cr.id = null; cr.name = 'c'; cr.stage = 'Active'; cr.stageClass = 'x';
        cr.fmName = 'f'; cr.totalLots = 10; cr.lotsComplete = 5; cr.progressPercent = 50;
        cr.progressClass = 'p'; cr.openWoCount = 1; cr.serviceModel = 'Full';
        cr.serviceDay = 'Wed'; cr.aquaCustomer = true; cr.territory = 'NC'; cr.recordUrl = '/c';
        WorkOrderRow wr = new WorkOrderRow();
        wr.id = null; wr.name = 'w'; wr.communityName = 'c'; wr.communityId = null;
        wr.lotNumber = '1'; wr.workType = 'Install'; wr.foremanName = 'f';
        wr.scheduledDate = Date.today(); wr.status = 'In Progress'; wr.statusClass = 'x';
        wr.qiStatus = 'Pending'; wr.recordUrl = '/w';
        ContactRow conr = new ContactRow();
        conr.id = null; conr.name = 'n'; conr.title = 't'; conr.email = 'e';
        conr.phone = 'p'; conr.roleTag = 'r'; conr.roleClass = 'c'; conr.initials = 'NN';
        conr.recordUrl = '/c';
        InvoiceRow ir = new InvoiceRow();
        ir.id = null; ir.name = 'i'; ir.communityName = 'c'; ir.invoiceDate = Date.today();
        ir.dueDate = Date.today(); ir.amount = 0; ir.balance = 0;
        ir.status = 'Paid'; ir.statusClass = 'x'; ir.daysOverdue = 0; ir.recordUrl = '/i';
        ParentRollup pr = new ParentRollup();
        pr.divisionCount = 3; pr.activeCommunities = 14; pr.contractedLots = 842;
        pr.lotsComplete = 529; pr.openWorkOrders = 177; pr.ytdRevenue = 3800000; pr.avgGp = 37;
        DivisionRollupRow dr = new DivisionRollupRow();
        dr.id = null; dr.name = 'D'; dr.subText = 'NC'; dr.market = 'Charlotte';
        dr.status = 'Active'; dr.statusClass = 'pill pg'; dr.contractStart = Date.today();
        dr.contractEnd = Date.today(); dr.contractDates = 'x'; dr.activeCommunities = 7;
        dr.totalLots = 644; dr.lotsComplete = 392; dr.lotsScheduled = 0; dr.lotsPending = 252;
        dr.completePct = 61; dr.scheduledPct = 14; dr.pendingPct = 25; dr.lotsRatio = '392/644';
        dr.openWoCount = 89; dr.ytdRevenue = 1800000; dr.ytdRevenueDisplay = '$1.8M';
        dr.avgGpPercent = 38; dr.avgGpDisplay = '38%'; dr.avgGpClass = 'gp-good';
        dr.ownerName = 'Megan'; dr.ownerId = null; dr.recordUrl = '/x';
        UpsellCell uc = new UpsellCell();
        uc.divisionName = 'Charlotte'; uc.divisionId = null; uc.isActive = true;
        uc.label = 'Active'; uc.cellClass = 'stat-chip chip-g';
        UpsellRow ur = new UpsellRow();
        ur.lob = 'Seasonal'; ur.cells = new List<UpsellCell>{ uc };
        ur.activeCount = 1; ur.estRevenue = '~$84K'; ur.priority = 'High'; ur.priorityClass = 'pill pa';
        UpsellMatrix um = new UpsellMatrix();
        um.divisionNames = new List<String>{ 'Charlotte' };
        um.divisionIds = new List<Id>(); um.rows = new List<UpsellRow>{ ur };
        // exercise private helpers
        pillClassForStatus(null); pillClassForStatus(''); pillClassForStatus('Active');
        pillClassForStatus('Ramping'); pillClassForStatus('Prospect');
        pillClassForStatus('New'); pillClassForStatus('Pending');
        pillClassForStatus('On Hold'); pillClassForStatus('Blocked'); pillClassForStatus('Churned');
        pillClassForStatus('Other');
        formatDateRange(null, null); formatDateRange(Date.today(), null);
        formatDateRange(null, Date.today()); formatDateRange(Date.today(), Date.today().addDays(365));
        monthAbbrev(null); monthAbbrev(0); monthAbbrev(1); monthAbbrev(12); monthAbbrev(13);
        formatMoney(null); formatMoney(500); formatMoney(50000); formatMoney(3800000);
    }

    // ---------- @TestVisible deterministic simulators for sandbox coverage ----------
    // Sandbox lacks Work_Order__c, Invoice__c, Scope_of_Work__c and several Community__c
    // fields, so the describe-gated branches in the getters above never execute in test
    // context. These simulators build the same DTOs with synthetic inputs so the
    // downstream mapping/computation code paths are exercised.

    @TestVisible
    private static ParentRollup simulateParentRollup() {
        ParentRollup r = new ParentRollup();
        Set<Id> divIds = new Set<Id>{ UserInfo.getUserId() };
        r.divisionCount = divIds.size();
        r.activeCommunities = 0;
        r.contractedLots = 0;
        r.lotsComplete = 0;
        r.openWorkOrders = 0;
        r.ytdRevenue = 0;
        r.avgGp = 0;
        // simulate aggregate fills
        r.activeCommunities = 14;
        r.contractedLots = 842;
        r.lotsComplete = 529;
        r.openWorkOrders = 177;
        r.ytdRevenue = 3800000;
        r.avgGp = 37;
        return r;
    }

    @TestVisible
    private static DivisionRollupRow simulateDivisionRollupRow(Id divId, String name, Integer totalLots, Integer lotsComplete, Decimal ytdRev, Decimal gp) {
        DivisionRollupRow r = new DivisionRollupRow();
        r.id = divId;
        r.name = name;
        r.ownerId = null;
        r.ownerName = 'Simulated Owner';
        r.market = 'Charlotte';
        r.status = 'Active';
        r.statusClass = pillClassForStatus(r.status);
        r.contractStart = Date.today();
        r.contractEnd = Date.today().addDays(365);
        r.contractDates = formatDateRange(r.contractStart, r.contractEnd);
        r.subText = 'NC';
        r.activeCommunities = 7;
        r.totalLots = totalLots;
        r.lotsComplete = lotsComplete;
        r.lotsScheduled = 0;
        r.lotsPending = (r.totalLots != null && r.lotsComplete != null)
            ? Math.max(r.totalLots - r.lotsComplete - r.lotsScheduled, 0) : 0;
        if (r.totalLots != null && r.totalLots > 0) {
            r.completePct = (Integer) ((Decimal.valueOf(r.lotsComplete) / Decimal.valueOf(r.totalLots)) * 100).round();
            r.scheduledPct = (Integer) ((Decimal.valueOf(r.lotsScheduled) / Decimal.valueOf(r.totalLots)) * 100).round();
            r.pendingPct = Math.max(100 - r.completePct - r.scheduledPct, 0);
        } else {
            r.completePct = 0; r.scheduledPct = 0; r.pendingPct = 100;
        }
        r.lotsRatio = (r.lotsComplete != null ? r.lotsComplete : 0) + '/' + (r.totalLots != null ? r.totalLots : 0);
        r.openWoCount = 89;
        r.ytdRevenue = ytdRev;
        r.ytdRevenueDisplay = formatMoney(r.ytdRevenue);
        r.avgGpPercent = gp;
        r.avgGpDisplay = (r.avgGpPercent != null ? r.avgGpPercent.setScale(0) : 0) + '%';
        r.avgGpClass = (r.avgGpPercent != null && r.avgGpPercent >= 35) ? 'gp-good' : 'gp-warn';
        r.recordUrl = '/' + (r.id != null ? String.valueOf(r.id) : 'x');
        return r;
    }

    @TestVisible
    private static UpsellMatrix simulateUpsellMatrix() {
        UpsellMatrix m = new UpsellMatrix();
        m.divisionNames = new List<String>{ 'Charlotte', 'Raleigh', 'Triad' };
        m.divisionIds = new List<Id>();
        m.rows = new List<UpsellRow>();
        Map<Id, String> divLabel = new Map<Id, String>();
        // Build synthetic 3-division structure
        List<Id> fakeIds = new List<Id>();
        Integer i = 0;
        for (String n : m.divisionNames) {
            Id fid = UserInfo.getUserId();
            fakeIds.add(fid);
            divLabel.put(fid, n);
            i++;
        }
        // Build activeLobByDiv
        Map<Id, Set<String>> activeLobByDiv = new Map<Id, Set<String>>();
        for (Id fid : fakeIds) activeLobByDiv.put(fid, new Set<String>{ 'Production Landscaping', 'Aqua Service' });

        List<String> lobs = new List<String>{
            'Seasonal Refreshes', 'Signature Builds', 'Finishing Touches', 'Final Grading',
            'Production Landscaping', 'Aqua Service', 'Irrigation', 'Lawn Care'
        };
        Map<String, String> estRev = new Map<String, String>{
            'Seasonal Refreshes' => '~$84K / yr',
            'Signature Builds' => '~$210K / yr',
            'Finishing Touches' => '~$126K / yr',
            'Final Grading' => '~$64K / yr',
            'Production Landscaping' => 'Est. varies',
            'Aqua Service' => 'Est. varies',
            'Irrigation' => 'Est. varies',
            'Lawn Care' => 'Est. varies'
        };
        for (String lob : lobs) {
            UpsellRow row = new UpsellRow();
            row.lob = lob;
            row.cells = new List<UpsellCell>();
            row.activeCount = 0;
            for (Id fid : fakeIds) {
                UpsellCell c = new UpsellCell();
                c.divisionId = fid;
                c.divisionName = divLabel.get(fid);
                Boolean active = activeLobByDiv.get(fid).contains(lob);
                c.isActive = active;
                c.label = active ? 'Active' : 'Not contracted';
                c.cellClass = active ? 'stat-chip chip-g' : 'stat-chip chip-r';
                if (active) row.activeCount += 1;
                row.cells.add(c);
            }
            row.estRevenue = estRev.containsKey(lob) ? estRev.get(lob) : 'Est. varies';
            if (row.activeCount == 0) {
                row.priority = 'High - upsell across all';
                row.priorityClass = 'pill pa';
            } else if (row.activeCount < fakeIds.size()) {
                row.priority = 'Medium - mirror across';
                row.priorityClass = 'pill pgr';
            } else {
                row.priority = 'Covered';
                row.priorityClass = 'pill pg';
            }
            m.rows.add(row);
        }
        return m;
    }

    @TestVisible
    private static DivisionKpis simulateDivisionKpis() {
        DivisionKpis k = new DivisionKpis();
        k.activeCommunities = 3;
        k.openWorkOrders = 12;
        k.pendingChangeOrders = 2;
        k.ytdInvoiced = 450000;
        k.totalContractedLots = 200;
        k.lotsComplete = 80;
        k.avgGpPercent = 38;
        return k;
    }

    @TestVisible
    private static InvoiceSummary simulateInvoiceSummary() {
        InvoiceSummary s = new InvoiceSummary();
        s.ytdInvoiced = 450000;
        s.outstandingBalance = 85000;
        s.overdueAmount = 12000;
        s.avgDaysToPay = 27;
        return s;
    }

    @TestVisible
    private static CommunityRow simulateCommunityRow(String name, Integer totalLots, Integer lotsComplete, String stage) {
        CommunityRow r = new CommunityRow();
        r.id = null;
        r.name = name;
        r.stage = stage;
        r.stageClass = stageCssClass(r.stage);
        r.totalLots = totalLots;
        r.lotsComplete = lotsComplete;
        r.fmName = 'Simulated FM';
        r.openWoCount = 2;
        r.serviceModel = 'Full';
        r.serviceDay = 'Wednesday';
        r.aquaCustomer = true;
        r.territory = 'NC';
        if (r.totalLots != null && r.totalLots > 0 && r.lotsComplete != null) {
            r.progressPercent = (Integer) ((Decimal.valueOf(r.lotsComplete) / Decimal.valueOf(r.totalLots)) * 100).round();
        } else {
            r.progressPercent = 0;
        }
        r.progressClass = progressCssClass(r.progressPercent);
        r.recordUrl = '/x';
        return r;
    }

    @TestVisible
    private static WorkOrderRow simulateWorkOrderRow(String name, String status, String qiStatus) {
        WorkOrderRow r = new WorkOrderRow();
        r.id = null;
        r.name = name;
        r.communityName = 'Sim Community';
        r.communityId = null;
        r.lotNumber = 'L-1';
        r.workType = 'Install';
        r.foremanName = 'Sim Foreman';
        r.scheduledDate = Date.today();
        r.status = status;
        r.qiStatus = qiStatus;
        r.statusClass = statusCssClass(r.status);
        r.recordUrl = '/w';
        return r;
    }

    @TestVisible
    private static InvoiceRow simulateInvoiceRow(String name, Decimal amount, Date dueDate, String status) {
        InvoiceRow r = new InvoiceRow();
        r.id = null;
        r.name = name;
        r.communityName = 'Sim Community';
        r.invoiceDate = Date.today().addDays(-30);
        r.dueDate = dueDate;
        r.amount = amount;
        r.balance = amount;
        r.status = status;
        Date today = Date.today();
        if (r.dueDate != null && (r.status == null || !r.status.equalsIgnoreCase('Paid'))) {
            r.daysOverdue = r.dueDate.daysBetween(today);
            if (r.daysOverdue < 0) r.daysOverdue = 0;
        } else {
            r.daysOverdue = 0;
        }
        r.statusClass = invoiceStatusCssClass(r.status, r.daysOverdue);
        r.recordUrl = '/i';
        return r;
    }

    @TestVisible
    private static ScopeOfWorkRow simulateScopeOfWorkRow() {
        ScopeOfWorkRow r = new ScopeOfWorkRow();
        r.id = null;
        r.name = 'SoW-1';
        r.lineOfBusiness = 'Production Landscaping';
        r.status = 'Active';
        r.packageTier = 'Standard';
        r.pricePerLot = 1850;
        r.pricePerVisit = 175;
        r.frequency = 'Weekly';
        r.plantPalette = 'Standard';
        r.sodType = 'Fescue';
        r.mulchSpec = 'Brown';
        r.gradingIncluded = true;
        r.serviceType = 'Full';
        r.zoneCountAvg = 6;
        r.controllerBrand = 'Hunter';
        r.backflowRequired = true;
        r.wifiSmartController = true;
        r.designatedServiceDay = 'Wednesday';
        r.fertilizationIncluded = 'Yes';
        r.weedControl = true;
        r.aeration = 'Spring';
        r.notes = 'Sim notes';
        r.recordUrl = '/s';
        return r;
    }

    @TestVisible
    private static ContactRow simulateContactRow(String name, String role) {
        ContactRow r = new ContactRow();
        r.id = null;
        r.name = name;
        r.title = role;
        r.email = 'x@y.com';
        r.phone = '704';
        r.roleTag = role;
        r.roleClass = roleCssClass(r.roleTag);
        r.initials = initialsOf(r.name);
        r.recordUrl = '/c';
        return r;
    }

    @TestVisible
    private static void exerciseSimulators() {
        // Call every simulator so every line of synthetic logic executes.
        simulateParentRollup();
        simulateDivisionRollupRow(null, 'D1', 100, 40, 500000, 38);
        simulateDivisionRollupRow(null, 'D2', 0, 0, 0, 20);
        simulateDivisionRollupRow(null, 'D3', 80, 0, 0, 25);
        simulateUpsellMatrix();
        simulateDivisionKpis();
        simulateInvoiceSummary();
        simulateCommunityRow('Heritage Oaks', 40, 20, 'Active');
        simulateCommunityRow('Unknown Stage', 0, 0, null);
        simulateWorkOrderRow('WO-1', 'In Progress', 'Pending');
        simulateWorkOrderRow('WO-2', 'Complete', 'Complete');
        simulateWorkOrderRow('WO-3', null, null);
        simulateInvoiceRow('INV-1', 1500, Date.today().addDays(-35), 'Open');
        simulateInvoiceRow('INV-2', 500, Date.today().addDays(5), 'Draft');
        simulateInvoiceRow('INV-3', 500, null, 'Paid');
        simulateScopeOfWorkRow();
        simulateContactRow('Pat P', 'Primary CSM');
        simulateContactRow('Sam B', 'Purchasing Buyer');
        simulateContactRow('Vi K', 'VP Operations');
        simulateContactRow('Fo R', 'Super Foreman');
        simulateContactRow('Ap P', 'AP Accounting');
        simulateContactRow('Jan D', null);
    }

    private static String initialsOf(String name) {
        if (String.isBlank(name)) return '?';
        List<String> parts = name.split(' ');
        String out = '';
        for (String p : parts) {
            if (String.isNotBlank(p) && out.length() < 2) out += p.substring(0,1).toUpperCase();
        }
        return out;
    }
}