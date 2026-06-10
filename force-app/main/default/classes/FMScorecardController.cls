/**
 * FMScorecardController
 * @AuraEnabled methods for the fmScorecardTable LWC.
 *
 * Reads FM_Scorecard__c records (one per Field Manager user) and supplements
 * them with live aggregate counts from standard WorkOrder records completed this month
 * and open high-priority Tasks (proxy for escalations). Returns a flat wrapper
 * list ready for the LWC template.
 */
public with sharing class FMScorecardController {

    // ─────────────────────────────────────────────
    // WRAPPER
    // ─────────────────────────────────────────────
    public class ScorecardRow {
        @AuraEnabled public Id    id;
        @AuraEnabled public Id    fmId;
        @AuraEnabled public String fmName;
        @AuraEnabled public String fmInitials;
        @AuraEnabled public String department;      // User.Department or Title
        @AuraEnabled public Decimal qiAverage;      // FM_Scorecard__c.QI_Average__c
        @AuraEnabled public Decimal lastQiScore;    // FM_Scorecard__c.Last_QI_Score__c
        @AuraEnabled public Date   lastQiDate;      // FM_Scorecard__c.Last_QI_Date__c
        @AuraEnabled public Integer qiCount;        // total QI inspections
        @AuraEnabled public Decimal fjPercent;      // FM_Scorecard__c.FJ_Percent__c
        @AuraEnabled public Integer fjCount;        // FM_Scorecard__c.Finish_Job_Count__c
        @AuraEnabled public Integer wosMtd;         // WOs reaching QI-complete this month
        @AuraEnabled public Integer openEscalations; // open high-priority Tasks
        // Status badge
        @AuraEnabled public String statusLabel;     // Strong / On Track / Watch / At Risk / No Data
        @AuraEnabled public String statusClass;     // chip-green / chip-amber / chip-red / chip-gray
        @AuraEnabled public String rowClass;        // '' / 'row-amber' / 'row-red'
        // Avatar color (consistent per initials)
        @AuraEnabled public String avatarColor;
    }

    // ─────────────────────────────────────────────
    // GET ALL FM SCORECARDS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<ScorecardRow> getScorecards() {
        List<FM_Scorecard__c> cards = new List<FM_Scorecard__c>();
        try {
            cards = [
                SELECT Id, FM__c, FM__r.Name, FM__r.Department, FM__r.Title,
                       QI_Average__c, QI_Total_Count__c,
                       Last_QI_Score__c, Last_QI_Date__c,
                       FJ_Percent__c, Finish_Job_Count__c
                FROM FM_Scorecard__c
                WHERE FM__c != null
                ORDER BY FM__r.Name ASC
                LIMIT 50
            ];
        } catch (Exception e) {
            ErrorLogService.log('FMScorecardController', 'getScorecards', null, e.getMessage());
            return new List<ScorecardRow>();
        }

        if (cards.isEmpty()) return new List<ScorecardRow>();

        Set<Id> fmIds = new Set<Id>();
        for (FM_Scorecard__c c : cards) fmIds.add(c.FM__c);

        // WOs reaching QI-complete stage this month per FM
        Date monthStart = Date.today().toStartOfMonth();
        Map<Id, Integer> wosMtdMap = new Map<Id, Integer>();
        try {
            for (AggregateResult ar : [
                SELECT FM_Assignment__c fm, COUNT(Id) cnt
                FROM WorkOrder
                WHERE FM_Assignment__c IN :fmIds
                  AND QI_Completed_Date__c >= :monthStart
                GROUP BY FM_Assignment__c
            ]) {
                wosMtdMap.put((Id)ar.get('fm'), (Integer)ar.get('cnt'));
            }
        } catch (Exception e) {
            ErrorLogService.log('FMScorecardController', 'getScorecards.wosMtd', null, e.getMessage());
        }

        // Open high-priority Tasks linked to FM Users (proxy for escalations)
        Map<Id, Integer> escalMap = new Map<Id, Integer>();
        try {
            for (AggregateResult ar : [
                SELECT OwnerId fm, COUNT(Id) cnt
                FROM Task
                WHERE OwnerId IN :fmIds
                  AND Status != 'Completed'
                  AND Priority = 'High'
                GROUP BY OwnerId
            ]) {
                escalMap.put((Id)ar.get('fm'), (Integer)ar.get('cnt'));
            }
        } catch (Exception e) {
            ErrorLogService.log('FMScorecardController', 'getScorecards.escalations', null, e.getMessage());
        }

        List<ScorecardRow> rows = new List<ScorecardRow>();
        for (FM_Scorecard__c c : cards) {
            ScorecardRow r = new ScorecardRow();
            r.id           = c.Id;
            r.fmId         = c.FM__c;
            r.fmName       = c.FM__r.Name;
            r.fmInitials   = initials(c.FM__r.Name);
            r.department   = c.FM__r.Department != null
                             ? c.FM__r.Department
                             : (c.FM__r.Title != null ? c.FM__r.Title : '—');
            r.qiAverage    = c.QI_Average__c    != null ? c.QI_Average__c.setScale(1)    : null;
            r.lastQiScore  = c.Last_QI_Score__c != null ? c.Last_QI_Score__c             : null;
            r.lastQiDate   = c.Last_QI_Date__c;
            r.qiCount      = c.QI_Total_Count__c != null ? (Integer)c.QI_Total_Count__c  : 0;
            r.fjPercent    = c.FJ_Percent__c    != null ? c.FJ_Percent__c.setScale(1)    : null;
            r.fjCount      = c.Finish_Job_Count__c != null ? (Integer)c.Finish_Job_Count__c : 0;
            r.wosMtd       = wosMtdMap.containsKey(c.FM__c) ? wosMtdMap.get(c.FM__c) : 0;
            r.openEscalations = escalMap.containsKey(c.FM__c) ? escalMap.get(c.FM__c) : 0;

            // Status thresholds (QI-based)
            Decimal qi = c.QI_Average__c != null ? c.QI_Average__c : 0;
            if (qi >= 9.3) {
                r.statusLabel = 'Strong';
                r.statusClass = 'chip-green';
                r.rowClass    = '';
            } else if (qi >= 9.0) {
                r.statusLabel = 'On Track';
                r.statusClass = 'chip-green';
                r.rowClass    = '';
            } else if (qi >= 8.5) {
                r.statusLabel = 'Watch';
                r.statusClass = 'chip-amber';
                r.rowClass    = 'row-amber';
            } else if (qi > 0) {
                r.statusLabel = 'At Risk';
                r.statusClass = 'chip-red';
                r.rowClass    = 'row-red';
            } else {
                r.statusLabel = 'No Data';
                r.statusClass = 'chip-gray';
                r.rowClass    = '';
            }

            r.avatarColor = avatarColor(r.fmInitials);
            rows.add(r);
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────
    private static String initials(String name) {
        if (String.isBlank(name)) return '?';
        List<String> parts = name.split(' ');
        String init = '';
        for (String p : parts) {
            if (!String.isBlank(p)) init += p.substring(0, 1).toUpperCase();
            if (init.length() >= 2) break;
        }
        return init;
    }

    private static String avatarColor(String initials) {
        // Deterministic color from initials (6-color palette matching LOVING design system)
        List<String> palette = new List<String>{
            '#4f46e5', '#0070d2', '#0f6e56', '#b45309', '#04844b', '#c23934'
        };
        Integer idx = 0;
        if (!String.isBlank(initials)) {
            for (Integer i = 0; i < initials.length(); i++) {
                idx += initials.charAt(i);
            }
            idx = Math.mod(idx, palette.size());
        }
        return palette[idx];
    }
}