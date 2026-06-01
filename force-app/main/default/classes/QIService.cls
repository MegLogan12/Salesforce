/**
 * QIService
 * Stage 15 — QI Inspection Open
 *
 * Quality Inspection scored 1–10 per line item.
 * Overall average drives outcome:
 *
 *   8–10     → Excellent — auto-advance toward Closed
 *   5–7.9    → Acceptable — CSM notified, no rework unless item < 4
 *   < 5      → Red — WO held, CSM + COO notified, rework decision required
 *   ≤ 3 (any single item) → Red flag on that item regardless of average
 *
 * Results feed the FM Scorecard dashboard.
 * QI must be complete within 5 business days of install (SLA).
 */
public with sharing class QIService {

    // QI line item minimum for red flag
    private static final Double RED_FLAG_THRESHOLD      = 3.0;
    // Average thresholds
    private static final Double EXCELLENT_THRESHOLD     = 8.0;
    private static final Double ACCEPTABLE_THRESHOLD    = 5.0;

    // ─────────────────────────────────────────────
    // TRIGGER HANDLER — BEFORE
    // ─────────────────────────────────────────────
    public static void handleBefore(List<QI_Inspection__c> newList, Map<Id, QI_Inspection__c> oldMap) {
        for (QI_Inspection__c qi : newList) {
            // Calculate overall average score when scores are submitted
            if (qi.Submitted__c) {
                qi.Overall_Score__c = calculateAverage(qi);
                qi.Score_Outcome__c = determineOutcome((Double)qi.Overall_Score__c);
            }
            // Flag any single item ≤ 3
            flagLowScoreItems(qi);
        }
    }

    // ─────────────────────────────────────────────
    // TRIGGER HANDLER — AFTER
    // ─────────────────────────────────────────────
    public static void handleAfter(List<QI_Inspection__c> newList, Map<Id, QI_Inspection__c> oldMap) {
        List<QI_Inspection__c> submitted = new List<QI_Inspection__c>();

        for (QI_Inspection__c qi : newList) {
            QI_Inspection__c old = (oldMap != null) ? oldMap.get(qi.Id) : null;
            Boolean justSubmitted = qi.Submitted__c && (old == null || !old.Submitted__c);
            if (justSubmitted) submitted.add(qi);
        }

        if (!submitted.isEmpty()) processQIOutcomes(submitted);
    }

    // ─────────────────────────────────────────────
    // OUTCOME PROCESSING
    // ─────────────────────────────────────────────
    private static void processQIOutcomes(List<QI_Inspection__c> inspections) {
        List<Id> woIds = new List<Id>();
        for (QI_Inspection__c qi : inspections) {
            if (qi.LOVING_Work_Order__c != null) woIds.add(qi.LOVING_Work_Order__c);
        }

        Map<Id, Work_Order__c> woMap = new Map<Id, Work_Order__c>([
            SELECT Id, Name, FM_Assignment__c, Community__c, CSM__c, Status__c
            FROM Work_Order__c WHERE Id IN :woIds
        ]);

        for (QI_Inspection__c qi : inspections) {
            Work_Order__c wo = woMap.get(qi.LOVING_Work_Order__c);
            if (wo == null) continue;

            String outcome = qi.Score_Outcome__c;

            if (outcome == 'Excellent') {
                handleExcellent(wo, qi);
            } else if (outcome == 'Acceptable') {
                handleAcceptable(wo, qi);
            } else if (outcome == 'Red') {
                handleRed(wo, qi);
            }

            // Red flag individual items regardless of average
            handleRedFlagItems(wo, qi);

            // Post scores to FM Scorecard
            FMScorecardService.recordQIScore(wo.FM_Assignment__c, qi.LOVING_Work_Order__c, (Double)qi.Overall_Score__c);
        }
    }

    private static void handleExcellent(Work_Order__c wo, QI_Inspection__c qi) {
        // QI passes — WO eligible for auto-close when invoice paid
        Work_Order__c update_wo = new Work_Order__c(
            Id                      = wo.Id,
            QI_Complete__c          = true,
            QI_Score__c             = qi.Overall_Score__c,
            QI_Completed_Date__c    = Date.today()
        );
        update update_wo;

        // Check if invoice also paid — if so, trigger auto-close
        AutoCloseService.checkAutoCloseConditions(wo.Id);
    }

    private static void handleAcceptable(Work_Order__c wo, QI_Inspection__c qi) {
        // QI passes but CSM notified
        Work_Order__c update_wo = new Work_Order__c(
            Id                      = wo.Id,
            QI_Complete__c          = true,
            QI_Score__c             = qi.Overall_Score__c,
            QI_Completed_Date__c    = Date.today()
        );
        update update_wo;

        EscalationService.notifyCSMAcceptableQI(wo.Id, wo.CSM__c, (Double)qi.Overall_Score__c);
        AutoCloseService.checkAutoCloseConditions(wo.Id);
    }

    private static void handleRed(Work_Order__c wo, QI_Inspection__c qi) {
        // WO held — does NOT auto-advance. CSM + COO notified.
        Work_Order__c update_wo = new Work_Order__c(
            Id                  = wo.Id,
            QI_Complete__c      = false,
            QI_Score__c         = qi.Overall_Score__c,
            QI_Held__c          = true,
            Status__c           = 'FM QI Review'
        );
        update update_wo;

        EscalationService.alertRedQI(wo.Id, wo.CSM__c, wo.FM_Assignment__c, (Double)qi.Overall_Score__c);
    }

    private static void handleRedFlagItems(Work_Order__c wo, QI_Inspection__c qi) {
        List<String> flaggedItems = new List<String>();

        if (qi.Score_Sod_Install__c != null && qi.Score_Sod_Install__c <= RED_FLAG_THRESHOLD)    flaggedItems.add('Sod Install Quality (' + qi.Score_Sod_Install__c + ')');
        if (qi.Score_Sod_Health__c != null && qi.Score_Sod_Health__c <= RED_FLAG_THRESHOLD)      flaggedItems.add('Sod Health (' + qi.Score_Sod_Health__c + ')');
        if (qi.Score_Plant_Install__c != null && qi.Score_Plant_Install__c <= RED_FLAG_THRESHOLD) flaggedItems.add('Plant Installation (' + qi.Score_Plant_Install__c + ')');
        if (qi.Score_Plant_Health__c != null && qi.Score_Plant_Health__c <= RED_FLAG_THRESHOLD)  flaggedItems.add('Plant Health (' + qi.Score_Plant_Health__c + ')');
        if (qi.Score_Tree_Install__c != null && qi.Score_Tree_Install__c <= RED_FLAG_THRESHOLD)  flaggedItems.add('Tree Installation (' + qi.Score_Tree_Install__c + ')');
        if (qi.Score_Aqua__c != null && qi.Score_Aqua__c <= RED_FLAG_THRESHOLD)                 flaggedItems.add('Aqua System (' + qi.Score_Aqua__c + ')');
        if (qi.Score_Cleanup__c != null && qi.Score_Cleanup__c <= RED_FLAG_THRESHOLD)           flaggedItems.add('Cleanup (' + qi.Score_Cleanup__c + ')');
        if (qi.Score_Site_Condition__c != null && qi.Score_Site_Condition__c <= RED_FLAG_THRESHOLD) flaggedItems.add('Site Condition (' + qi.Score_Site_Condition__c + ')');

        if (!flaggedItems.isEmpty()) {
            // Create follow-up tasks for each red-flag item
            List<Task> followUpTasks = new List<Task>();
            for (String item : flaggedItems) {
                followUpTasks.add(new Task(
                    WhatId       = wo.Id,
                    OwnerId      = wo.CSM__c != null ? wo.CSM__c : UserInfo.getUserId(),
                    Subject      = 'QI Red Flag — ' + item + ' — ' + wo.Name,
                    Status       = 'Not Started',
                    Priority     = 'High',
                    ActivityDate = Date.today().addDays(2),
                    Type         = 'QI Red Flag',
                    Description  = 'QI red flag item score of 3 or below. FM must add explanation note. CSM review required.'
                ));
            }
            insert followUpTasks;
        }
    }

    // ─────────────────────────────────────────────
    // SCORE CALCULATION
    // ─────────────────────────────────────────────
    private static Double calculateAverage(QI_Inspection__c qi) {
        List<Double> scores = new List<Double>();
        if (qi.Score_Sod_Install__c != null)    scores.add(qi.Score_Sod_Install__c);
        if (qi.Score_Sod_Health__c != null)     scores.add(qi.Score_Sod_Health__c);
        if (qi.Score_Plant_Install__c != null)  scores.add(qi.Score_Plant_Install__c);
        if (qi.Score_Plant_Health__c != null)   scores.add(qi.Score_Plant_Health__c);
        if (qi.Score_Tree_Install__c != null && qi.Tree_Install_Applicable__c) scores.add(qi.Score_Tree_Install__c);
        if (qi.Score_Aqua__c != null && qi.Aqua_Applicable__c) scores.add(qi.Score_Aqua__c);
        if (qi.Score_Cleanup__c != null)        scores.add(qi.Score_Cleanup__c);
        if (qi.Score_Site_Condition__c != null) scores.add(qi.Score_Site_Condition__c);
        if (qi.Score_Overall__c != null)        scores.add(qi.Score_Overall__c);

        if (scores.isEmpty()) return 0;

        Double total = 0;
        for (Double s : scores) total += s;
        return total / scores.size();
    }

    private static String determineOutcome(Double avg) {
        if (avg >= EXCELLENT_THRESHOLD)    return 'Excellent';
        if (avg >= ACCEPTABLE_THRESHOLD)   return 'Acceptable';
        return 'Red';
    }

    private static void flagLowScoreItems(QI_Inspection__c qi) {
        // Store which items have red flags for downstream processing
        List<String> flags = new List<String>();
        if (qi.Score_Sod_Install__c != null && qi.Score_Sod_Install__c <= RED_FLAG_THRESHOLD)  flags.add('Sod Install');
        if (qi.Score_Sod_Health__c != null && qi.Score_Sod_Health__c <= RED_FLAG_THRESHOLD)    flags.add('Sod Health');
        if (qi.Score_Plant_Install__c != null && qi.Score_Plant_Install__c <= RED_FLAG_THRESHOLD) flags.add('Plant Install');
        if (qi.Score_Plant_Health__c != null && qi.Score_Plant_Health__c <= RED_FLAG_THRESHOLD) flags.add('Plant Health');
        if (qi.Score_Cleanup__c != null && qi.Score_Cleanup__c <= RED_FLAG_THRESHOLD)          flags.add('Cleanup');
        if (!flags.isEmpty()) {
            qi.Red_Flag_Items__c = String.join(flags, '; ');
        }
    }

    // ─────────────────────────────────────────────
    // 5-BUSINESS-DAY SLA CHECK
    // ─────────────────────────────────────────────
    public static void checkQISLA() {
        // Find Approved WOs where QI is not complete after 5 business days
        List<Work_Order__c> overdueQI = [
            SELECT Id, Name, FM_Assignment__c, Approved_Date__c
            FROM Work_Order__c
            WHERE Status__c = 'Approved'
            AND QI_Complete__c = false
            AND Approved_Date__c <= :Date.today().addDays(-7) // ~5 business days
        ];

        for (Work_Order__c wo : overdueQI) {
            EscalationService.escalateQISLABreach(wo.Id, wo.FM_Assignment__c);
        }
    }
}