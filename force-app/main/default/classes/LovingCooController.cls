/**
 * LovingCooController
 * @AuraEnabled methods for lovingCooConsole LWC — COO Unified App (8-tab dashboard).
 *
 * Provides COO-specific aggregate data that isn't covered by other controllers:
 *   • getCooKpis()     — combined KPIs across all LOBs
 *   • getWoPipeline()  — Work Order counts grouped by Status
 *   • getGpSummary()   — Invoice GP tier breakdown (Green / Yellow / Red / Blocked)
 *   • getAquaSummary() — Aqua service ticket counts
 *
 * The LWC also wires directly to:
 *   • HomeDashboardController.getOpenHireRequests()  — People tab
 *   • HomeDashboardController.getThisWeekOneOnOnes() — People tab
 *   • SchedulingController.getSchedulingKpis()       — Scheduling tab
 *   • FMScorecardController.getScorecards()          — Quality tab
 */
public with sharing class LovingCooController {

    // ─────────────────────────────────────────────
    // WRAPPERS
    // ─────────────────────────────────────────────
    public class CooKpis {
        @AuraEnabled public Integer activeWOs;
        @AuraEnabled public Integer scheduledToday;
        @AuraEnabled public Integer pendingProposals;
        @AuraEnabled public Integer pendingCloseout;
        @AuraEnabled public Integer paidThisMonth;
        @AuraEnabled public Integer openEscalations;
        @AuraEnabled public Integer openHireRequests;
        @AuraEnabled public Integer siteReadinessOverdue;
    }

    public class WoPipelineRow {
        @AuraEnabled public String  status;
        @AuraEnabled public Integer count;
        @AuraEnabled public String  chipCss;
    }

    public class GpSummary {
        @AuraEnabled public Integer greenCount;
        @AuraEnabled public Integer yellowCount;
        @AuraEnabled public Integer redCount;
        @AuraEnabled public Integer blockedCount;
        @AuraEnabled public Decimal totalRevenuePending;
    }

    public class AquaSummary {
        @AuraEnabled public Integer upcomingInstalls;
        @AuraEnabled public Integer upcomingChecks;
        @AuraEnabled public Integer openPickupTickets;
    }

    public class LobPipelineRow {
        @AuraEnabled public String lob;
        @AuraEnabled public Integer openOpps;
        @AuraEnabled public Decimal pipeline;
        @AuraEnabled public Decimal weighted;
        @AuraEnabled public Integer followUpsDue;
        @AuraEnabled public Integer atRisk;
    }

    public class ActivityRiskRow {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String opportunityUrl;
        @AuraEnabled public String lob;
        @AuraEnabled public String lastActivity;
        @AuraEnabled public String followUpDue;
        @AuraEnabled public String risk;
    }

    // ─────────────────────────────────────────────
    // COO OVERVIEW KPIs — all LOBs rolled up
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static CooKpis getCooKpis() {
        CooKpis k = new CooKpis();
        k.activeWOs            = 0;
        k.scheduledToday       = 0;
        k.pendingProposals     = 0;
        k.pendingCloseout      = 0;
        k.paidThisMonth        = 0;
        k.openEscalations      = 0;
        k.openHireRequests     = 0;
        k.siteReadinessOverdue = 0;
        try {
            k.activeWOs = [
                SELECT COUNT() FROM Work_Order__c
                WHERE Status__c NOT IN ('Closed', 'Cancelled')
            ];
            k.scheduledToday = [
                SELECT COUNT() FROM Work_Order__c
                WHERE Schedule_Locked__c = true
                  AND Scheduled_Date__c = TODAY
            ];
            k.pendingProposals = [
                SELECT COUNT() FROM Work_Order__c
                WHERE Schedule_Proposal_Status__c = 'Pending Review'
                  AND Schedule_Locked__c = false
            ];
            k.pendingCloseout = [
                SELECT COUNT() FROM Work_Order__c
                WHERE Status__c = 'Pending Closeout'
            ];
            Date firstOfMonth = Date.today().toStartOfMonth();
            k.paidThisMonth = [
                SELECT COUNT() FROM Invoice__c
                WHERE Status__c = 'Paid' AND Date_Paid__c >= :firstOfMonth
            ];
            k.openEscalations = [
                SELECT COUNT() FROM Task
                WHERE Type = 'Escalation' AND Status != 'Completed'
            ];
            k.openHireRequests = [
                SELECT COUNT() FROM Hire_Request__c
                WHERE Status__c IN ('Submitted', 'Under VP Review', 'Under COO Review')
            ];
            k.siteReadinessOverdue = [
                SELECT COUNT() FROM Task
                WHERE Type = 'Site Readiness'
                  AND Status != 'Completed'
                  AND ActivityDate < TODAY
            ];
        } catch (Exception e) {
            ErrorLogService.log('LovingCooController', 'getCooKpis', null, e.getMessage());
        }
        return k;
    }

    // ─────────────────────────────────────────────
    // WO PIPELINE BY STATUS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<WoPipelineRow> getWoPipeline() {
        List<WoPipelineRow> rows = new List<WoPipelineRow>();
        try {
            for (AggregateResult ar : [
                SELECT Status__c s, COUNT(Id) cnt
                FROM Work_Order__c
                WHERE Status__c != null
                GROUP BY Status__c
                ORDER BY COUNT(Id) DESC
                LIMIT 20
            ]) {
                WoPipelineRow r = new WoPipelineRow();
                r.status  = (String)  ar.get('s');
                r.count   = (Integer) ar.get('cnt');
                r.chipCss = chipForStatus(r.status);
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('LovingCooController', 'getWoPipeline', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // GP SUMMARY — invoice tier breakdown
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static GpSummary getGpSummary() {
        GpSummary g = new GpSummary();
        g.greenCount = 0; g.yellowCount = 0; g.redCount = 0;
        g.blockedCount = 0; g.totalRevenuePending = 0;
        try {
            for (AggregateResult ar : [
                SELECT GP_Status__c gp, COUNT(Id) cnt, SUM(Total_Revenue__c) rev
                FROM Invoice__c
                WHERE Status__c IN ('Pending Send', 'Sent')
                GROUP BY GP_Status__c
            ]) {
                String  tier = (String)  ar.get('gp');
                Integer cnt  = (Integer) ar.get('cnt');
                Decimal rev  = (Decimal) ar.get('rev');
                if (rev == null) rev = 0;
                if (tier == 'Green')  { g.greenCount  = cnt; g.totalRevenuePending += rev; }
                if (tier == 'Yellow') { g.yellowCount = cnt; g.totalRevenuePending += rev; }
                if (tier == 'Red')    { g.redCount    = cnt; }
            }
            g.blockedCount = [
                SELECT COUNT() FROM Invoice__c
                WHERE Status__c = 'Blocked — COO Review'
            ];
        } catch (Exception e) {
            ErrorLogService.log('LovingCooController', 'getGpSummary', null, e.getMessage());
        }
        return g;
    }

    // ─────────────────────────────────────────────
    // AQUA SUMMARY
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static AquaSummary getAquaSummary() {
        AquaSummary a = new AquaSummary();
        a.upcomingInstalls = 0; a.upcomingChecks = 0; a.openPickupTickets = 0;
        try {
            a.upcomingInstalls = [
                SELECT COUNT() FROM Aqua_Install_Ticket__c
                WHERE Scheduled_Date__c >= TODAY AND Status__c != 'Complete'
            ];
            a.upcomingChecks = [
                SELECT COUNT() FROM Aqua_Check_Ticket__c
                WHERE Scheduled_Date__c >= TODAY AND Status__c != 'Complete'
            ];
            a.openPickupTickets = [
                SELECT COUNT() FROM Aqua_Pickup_Ticket__c
                WHERE Status__c != 'Complete'
            ];
        } catch (Exception e) {
            ErrorLogService.log('LovingCooController', 'getAquaSummary', null, e.getMessage());
        }
        return a;
    }

    @AuraEnabled(cacheable=true)
    public static List<LobPipelineRow> getPipelineByLob() {
        List<LobPipelineRow> rows = new List<LobPipelineRow>();
        List<Opportunity> opportunities = [
            SELECT Id, Type, Amount, Probability
            FROM Opportunity
            WHERE IsClosed = false
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];
        Set<Id> oppIds = new Set<Id>();
        Map<Id, String> laneByOpp = new Map<Id, String>();
        for (Opportunity row : opportunities) {
            String lane = laneForOpportunity(row.Type);
            if (String.isBlank(lane)) {
                continue;
            }
            oppIds.add(row.Id);
            laneByOpp.put(row.Id, lane);
        }

        Map<Id, Date> nextFollowUpByOpp = new Map<Id, Date>();
        for (Task taskRow : [
            SELECT WhatId, ActivityDate, Status
            FROM Task
            WHERE WhatId IN :oppIds
            ORDER BY ActivityDate ASC NULLS LAST, CreatedDate ASC
        ]) {
            if (isClosedTaskStatus(taskRow.Status) || nextFollowUpByOpp.containsKey(taskRow.WhatId)) {
                continue;
            }
            nextFollowUpByOpp.put(taskRow.WhatId, taskRow.ActivityDate);
        }

        Map<String, LobPipelineRow> byLane = new Map<String, LobPipelineRow>();
        for (Opportunity row : opportunities) {
            String lane = laneByOpp.get(row.Id);
            if (String.isBlank(lane)) {
                continue;
            }
            if (!byLane.containsKey(lane)) {
                LobPipelineRow bucket = new LobPipelineRow();
                bucket.lob = lane;
                bucket.openOpps = 0;
                bucket.pipeline = 0;
                bucket.weighted = 0;
                bucket.followUpsDue = 0;
                bucket.atRisk = 0;
                byLane.put(lane, bucket);
            }
            LobPipelineRow bucket = byLane.get(lane);
            bucket.openOpps++;
            Decimal amount = row.Amount == null ? 0 : row.Amount;
            Decimal probability = row.Probability == null ? 0 : row.Probability;
            bucket.pipeline += amount;
            bucket.weighted += (amount * probability) / 100;
            if (nextFollowUpByOpp.containsKey(row.Id) && nextFollowUpByOpp.get(row.Id) != null && nextFollowUpByOpp.get(row.Id) <= Date.today()) {
                bucket.followUpsDue++;
            }
            if (row.Amount == null || (nextFollowUpByOpp.containsKey(row.Id) && nextFollowUpByOpp.get(row.Id) != null && nextFollowUpByOpp.get(row.Id) <= Date.today().addDays(-2))) {
                bucket.atRisk++;
            }
        }

        List<String> orderedLanes = new List<String>{ 'UMB', 'Custom Build', 'Lawn Care' };
        for (String lane : orderedLanes) {
            if (byLane.containsKey(lane)) {
                rows.add(byLane.get(lane));
            }
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<ActivityRiskRow> getActivityRisks() {
        List<ActivityRiskRow> rows = new List<ActivityRiskRow>();
        List<Opportunity> opportunities = [
            SELECT Id, Name, Type, LastActivityDate
            FROM Opportunity
            WHERE IsClosed = false
            ORDER BY LastModifiedDate DESC
            LIMIT 120
        ];

        Set<Id> oppIds = new Set<Id>();
        Map<Id, Opportunity> byId = new Map<Id, Opportunity>();
        for (Opportunity row : opportunities) {
            String lane = laneForOpportunity(row.Type);
            if (String.isBlank(lane)) {
                continue;
            }
            oppIds.add(row.Id);
            byId.put(row.Id, row);
        }

        Map<Id, Date> nextFollowUpByOpp = new Map<Id, Date>();
        for (Task taskRow : [
            SELECT WhatId, ActivityDate, Status
            FROM Task
            WHERE WhatId IN :oppIds
            ORDER BY ActivityDate ASC NULLS LAST, CreatedDate ASC
        ]) {
            if (isClosedTaskStatus(taskRow.Status) || nextFollowUpByOpp.containsKey(taskRow.WhatId)) {
                continue;
            }
            nextFollowUpByOpp.put(taskRow.WhatId, taskRow.ActivityDate);
        }

        for (Opportunity row : opportunities) {
            if (!byId.containsKey(row.Id)) {
                continue;
            }
            Date nextFollowUp = nextFollowUpByOpp.get(row.Id);
            Boolean stale = row.LastActivityDate == null || row.LastActivityDate <= Date.today().addDays(-5);
            Boolean overdue = nextFollowUp != null && nextFollowUp <= Date.today();
            if (!stale && !overdue) {
                continue;
            }
            ActivityRiskRow risk = new ActivityRiskRow();
            risk.opportunityId = row.Id;
            risk.opportunityName = row.Name;
            risk.opportunityUrl = '/' + row.Id;
            risk.lob = laneForOpportunity(row.Type);
            risk.lastActivity = row.LastActivityDate == null ? 'No recent activity' : String.valueOf(row.LastActivityDate);
            risk.followUpDue = nextFollowUp == null ? '—' : String.valueOf(nextFollowUp);
            risk.risk = overdue ? 'Needs touch' : 'Monitor';
            rows.add(risk);
            if (rows.size() == 10) {
                break;
            }
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // HELPER
    // ─────────────────────────────────────────────
    private static String chipForStatus(String s) {
        if (s == null) return 'chip chip-gray';
        if (s == 'Scheduled'     || s == 'In Progress')          return 'chip chip-blue';
        if (s == 'Approved'      || s == 'Closed')               return 'chip chip-green';
        if (s == 'Pending Closeout' || s == 'Pending Approval')  return 'chip chip-amber';
        if (s == 'FM QI Review')                                  return 'chip chip-red';
        return 'chip chip-gray';
    }

    private static String laneForOpportunity(String rawType) {
        if (rawType == 'UMB' || rawType == 'UpgradeMyBackyard') return 'UMB';
        if (rawType == 'Custom Build' || rawType == 'Design Build') return 'Custom Build';
        if (rawType == 'Lawn Care') return 'Lawn Care';
        return null;
    }

    private static Boolean isClosedTaskStatus(String status) {
        if (String.isBlank(status)) return false;
        String normalized = status.trim().toLowerCase();
        return normalized == 'completed' || normalized == 'done';
    }
}