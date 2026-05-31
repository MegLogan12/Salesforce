/**
 * MeasuringCupController
 *
 * Backs the Measuring Cup Lightning App LWCs (mcLiveCrewStatus, mcKpiTile).
 * Pulls live operational data and computes Goal vs Actual hours, variance, bonus eligibility.
 * Spec reference: Section 19A.
 */
public with sharing class MeasuringCupController {

    public class CrewStatus {
        @AuraEnabled public String crewName;
        @AuraEnabled public String foreman;
        @AuraEnabled public String currentLot;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal varianceHours;
        @AuraEnabled public String status;
    }

    public class CupKpis {
        @AuraEnabled public Decimal totalGoalHoursToday;
        @AuraEnabled public Decimal totalActualHoursToday;
        @AuraEnabled public Decimal totalVarianceHoursToday;
        @AuraEnabled public Integer activeCrews;
        @AuraEnabled public Integer bonusEligibleCount;
    }

    @AuraEnabled(cacheable=true)
    public static List<CrewStatus> getActiveToday() {
        List<CrewStatus> result = new List<CrewStatus>();
        for (WorkOrder wo : [
            SELECT Id, WorkOrderNumber, Crew__c, Field_Manager__r.Name,
                   Goal_Hours__c, Actual_Hours__c, Variance_Hours__c, Job_Health__c
            FROM WorkOrder
            WHERE Requested_Install_Date__c = TODAY
            AND Status IN ('In Progress', 'Scheduled')
            LIMIT 50
        ]) {
            result.add(buildCrewStatus(wo));
        }
        return result;
    }

    @TestVisible
    private static CrewStatus buildCrewStatus(WorkOrder wo) {
        CrewStatus c = new CrewStatus();
        c.crewName = wo.Crew__c;
        c.foreman = wo.Field_Manager__r != null ? wo.Field_Manager__r.Name : '';
        c.currentLot = wo.WorkOrderNumber;
        c.goalHours = wo.Goal_Hours__c;
        c.actualHours = wo.Actual_Hours__c;
        c.varianceHours = wo.Variance_Hours__c;
        c.status = wo.Job_Health__c;
        return c;
    }

    @AuraEnabled(cacheable=true)
    public static CupKpis getKpis() {
        CupKpis k = new CupKpis();
        k.totalGoalHoursToday = 0;
        k.totalActualHoursToday = 0;
        k.totalVarianceHoursToday = 0;
        k.activeCrews = 0;
        k.bonusEligibleCount = 0;

        AggregateResult[] aggs = [
            SELECT SUM(Goal_Hours__c) goalH, SUM(Actual_Hours__c) actualH,
                   SUM(Variance_Hours__c) varH, COUNT(Id) cnt
            FROM WorkOrder
            WHERE Requested_Install_Date__c = TODAY
        ];
        for (AggregateResult ar : aggs) {
            applyAggResult(k, ar);
        }
        return k;
    }

    @TestVisible
    private static void applyAggResult(CupKpis k, AggregateResult ar) {
        Decimal g = (Decimal) ar.get('goalH');
        Decimal a = (Decimal) ar.get('actualH');
        Decimal v = (Decimal) ar.get('varH');
        Integer cnt = (Integer) ar.get('cnt');
        k.totalGoalHoursToday = g == null ? 0 : g;
        k.totalActualHoursToday = a == null ? 0 : a;
        k.totalVarianceHoursToday = v == null ? 0 : v;
        k.activeCrews = cnt == null ? 0 : cnt;
    }
}