public with sharing class ODLConsoleHomeController {

    private static final Set<String> ODL_TYPES = new Set<String>{
        'UpgradeMyBackyard', 'UMB', 'Design Build'
    };

    public class KpiData {
        @AuraEnabled public Integer totalOpenOpps;
        @AuraEnabled public Integer umbCount;
        @AuraEnabled public Decimal  umbPipeline;
        @AuraEnabled public Integer  odlCount;
        @AuraEnabled public Decimal  odlPipeline;
        @AuraEnabled public Integer  designBuildCount;
        @AuraEnabled public Decimal  designBuildPipeline;
        @AuraEnabled public Integer  overdueTasks;
        @AuraEnabled public Integer  openLeads;
    }

    public class LobRow {
        @AuraEnabled public String  lob;
        @AuraEnabled public String  displayLabel;
        @AuraEnabled public Integer openOpps;
        @AuraEnabled public Decimal pipeline;
        @AuraEnabled public Integer quotesRequested;
        @AuraEnabled public Integer consultations;
    }

    public class ActivityRow {
        @AuraEnabled public String id;
        @AuraEnabled public String subject;
        @AuraEnabled public String relatedName;
        @AuraEnabled public String relatedId;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String dueDate;
        @AuraEnabled public String daysOverdue;
    }

    public class HomePageData {
        @AuraEnabled public KpiData        kpis;
        @AuraEnabled public List<LobRow>   lobRows;
        @AuraEnabled public List<ActivityRow> recentActivity;
    }

    @AuraEnabled(cacheable=true)
    public static HomePageData getHomePageData() {
        HomePageData data = new HomePageData();
        data.kpis         = new KpiData();
        data.lobRows      = new List<LobRow>();
        data.recentActivity = new List<ActivityRow>();

        // --- Aggregate open opportunities by Type ---
        Map<String, Integer> countByType  = new Map<String, Integer>{
            'UpgradeMyBackyard' => 0, 'UMB' => 0, 'Design Build' => 0
        };
        Map<String, Decimal> amountByType = new Map<String, Decimal>{
            'UpgradeMyBackyard' => 0, 'UMB' => 0, 'Design Build' => 0
        };
        for (AggregateResult ar : [
            SELECT Type, COUNT(Id) cnt, SUM(Amount) total
            FROM Opportunity
            WHERE IsClosed = false AND Type IN :ODL_TYPES
            GROUP BY Type
        ]) {
            String t = (String) ar.get('Type');
            if (countByType.containsKey(t)) {
                countByType.put(t, (Integer) ar.get('cnt'));
                amountByType.put(t, ar.get('total') != null ? (Decimal) ar.get('total') : 0);
            }
        }

        data.kpis.umbCount          = countByType.get('UMB');
        data.kpis.umbPipeline       = amountByType.get('UMB');
        data.kpis.odlCount          = countByType.get('UpgradeMyBackyard');
        data.kpis.odlPipeline       = amountByType.get('UpgradeMyBackyard');
        data.kpis.designBuildCount  = countByType.get('Design Build');
        data.kpis.designBuildPipeline = amountByType.get('Design Build');
        data.kpis.totalOpenOpps     = data.kpis.umbCount + data.kpis.odlCount + data.kpis.designBuildCount;

        // --- Overdue tasks (all records, not filtered to ODL to avoid SOQL complexity) ---
        data.kpis.overdueTasks = [
            SELECT COUNT() FROM Task WHERE IsClosed = false AND ActivityDate < TODAY
        ];

        // --- Open leads (unconverted) ---
        data.kpis.openLeads = [
            SELECT COUNT() FROM Lead WHERE IsConverted = false
        ];

        // --- Quote Requested and Consultation Scheduled counts by Type ---
        Map<String, Integer> quoteCntByType = new Map<String, Integer>{
            'UpgradeMyBackyard' => 0, 'UMB' => 0, 'Design Build' => 0
        };
        Map<String, Integer> consultCntByType = new Map<String, Integer>{
            'UpgradeMyBackyard' => 0, 'UMB' => 0, 'Design Build' => 0
        };
        for (AggregateResult ar : [
            SELECT Type, StageName, COUNT(Id) cnt
            FROM Opportunity
            WHERE IsClosed = false AND Type IN :ODL_TYPES
              AND StageName IN ('Quote Requested', 'Consultation Scheduled')
            GROUP BY Type, StageName
        ]) {
            String t = (String) ar.get('Type');
            String s = (String) ar.get('StageName');
            Integer c = (Integer) ar.get('cnt');
            if (quoteCntByType.containsKey(t)) {
                if (s == 'Quote Requested') {
                    quoteCntByType.put(t, c);
                } else if (s == 'Consultation Scheduled') {
                    consultCntByType.put(t, c);
                }
            }
        }

        // --- Build LOB rows ---
        Map<String, String> displayLabels = new Map<String, String>{
            'UpgradeMyBackyard' => 'UpgradeMyBackyard',
            'UMB'               => 'UMB',
            'Design Build'      => 'Design Build'
        };
        for (String lob : new List<String>{'UpgradeMyBackyard', 'UMB', 'Design Build'}) {
            LobRow row = new LobRow();
            row.lob           = lob;
            row.displayLabel  = displayLabels.get(lob);
            row.openOpps      = countByType.get(lob);
            row.pipeline      = amountByType.get(lob);
            row.quotesRequested = quoteCntByType.get(lob);
            row.consultations = consultCntByType.get(lob);
            data.lobRows.add(row);
        }

        // --- Overdue tasks linked to ODL opportunities (activity list) ---
        Set<Id> odlOppIds = new Map<Id, Opportunity>([
            SELECT Id FROM Opportunity
            WHERE IsClosed = false AND Type IN :ODL_TYPES
        ]).keySet();

        if (!odlOppIds.isEmpty()) {
            for (Task t : [
                SELECT Id, Subject, ActivityDate, Owner.Name, What.Name, WhatId
                FROM Task
                WHERE IsClosed = false
                  AND ActivityDate < TODAY
                  AND WhatId IN :odlOppIds
                ORDER BY ActivityDate ASC
                LIMIT 8
            ]) {
                ActivityRow row = new ActivityRow();
                row.id          = t.Id;
                row.subject     = t.Subject;
                row.relatedName = t.What != null ? t.What.Name : null;
                row.relatedId   = t.WhatId;
                row.ownerName   = t.Owner != null ? t.Owner.Name : null;
                if (t.ActivityDate != null) {
                    Integer daysOver = t.ActivityDate.daysBetween(Date.today());
                    row.dueDate    = t.ActivityDate.month() + '/' + t.ActivityDate.day();
                    row.daysOverdue = daysOver <= 0 ? 'Today'
                                    : daysOver == 1 ? '1 day overdue'
                                    : daysOver + ' days overdue';
                }
                data.recentActivity.add(row);
            }
        }

        return data;
    }
}