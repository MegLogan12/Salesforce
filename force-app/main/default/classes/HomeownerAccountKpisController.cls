/**
 * HomeownerAccountKpisController
 * Returns KPI data for the homeownerAccountHeaderKpis LWC component displayed
 * on the LOVING_Account_Homeowner_Record_Page.
 */
public with sharing class HomeownerAccountKpisController {

    public class KpisResult {
        @AuraEnabled public Integer openOpps        { get; set; }
        @AuraEnabled public Decimal totalPipeline   { get; set; }
        @AuraEnabled public Integer wonOpps         { get; set; }
        @AuraEnabled public Decimal totalClosed     { get; set; }
        @AuraEnabled public Integer openLeads       { get; set; }
        @AuraEnabled public Integer openTasks       { get; set; }
        @AuraEnabled public Integer openCases       { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static KpisResult getKpis(Id accountId) {
        KpisResult result = new KpisResult();

        // ── Open Opportunities ───────────────────────────────────────────────
        AggregateResult[] openOppAgg = [
            SELECT COUNT(Id) cnt, SUM(Amount) pipeline
            FROM Opportunity
            WHERE AccountId = :accountId
              AND IsClosed   = false
        ];
        result.openOpps      = (Integer)  openOppAgg[0].get('cnt');
        result.totalPipeline = (Decimal)  openOppAgg[0].get('pipeline');
        if (result.totalPipeline == null) result.totalPipeline = 0;

        // ── Won Opportunities ────────────────────────────────────────────────
        AggregateResult[] wonOppAgg = [
            SELECT COUNT(Id) cnt, SUM(Amount) closedAmt
            FROM Opportunity
            WHERE AccountId = :accountId
              AND IsWon       = true
        ];
        result.wonOpps     = (Integer) wonOppAgg[0].get('cnt');
        result.totalClosed = (Decimal) wonOppAgg[0].get('closedAmt');
        if (result.totalClosed == null) result.totalClosed = 0;

        // ── Open Leads ───────────────────────────────────────────────────────
        result.openLeads = [
            SELECT COUNT()
            FROM Lead
            WHERE ConvertedAccountId = :accountId
              AND IsConverted         = false
        ];

        // ── Open Tasks (via Opportunity WhatId) ──────────────────────────────
        List<Id> oppIds = new List<Id>();
        for (Opportunity opp : [
            SELECT Id FROM Opportunity WHERE AccountId = :accountId
        ]) {
            oppIds.add(opp.Id);
        }

        Integer taskCount = 0;
        if (!oppIds.isEmpty()) {
            taskCount = [
                SELECT COUNT()
                FROM Task
                WHERE WhatId IN :oppIds
                  AND IsClosed = false
            ];
        }
        // Also count tasks directly on the Account
        taskCount += [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :accountId
              AND IsClosed = false
        ];
        result.openTasks = taskCount;

        // ── Open Cases ───────────────────────────────────────────────────────
        result.openCases = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId = :accountId
              AND Status     != 'Closed'
        ];

        return result;
    }
}
