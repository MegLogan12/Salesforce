@isTest
private class MeasuringCupControllerTest {

    // ── getActiveToday ────────────────────────────────────────────────────
    @isTest
    static void testGetActiveTodayEmpty() {
        Test.startTest();
        List<MeasuringCupController.CrewStatus> result = MeasuringCupController.getActiveToday();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ── getKpis ───────────────────────────────────────────────────────────
    @isTest
    static void testGetKpisEmpty() {
        Test.startTest();
        MeasuringCupController.CupKpis kpis = MeasuringCupController.getKpis();
        Test.stopTest();
        System.assertNotEquals(null, kpis, 'KPIs should not be null');
        System.assertEquals(0, kpis.totalGoalHoursToday);
        System.assertEquals(0, kpis.totalActualHoursToday);
        System.assertEquals(0, kpis.totalVarianceHoursToday);
        System.assertEquals(0, kpis.activeCrews);
    }

    // ── buildCrewStatus — null-field path ────────────────────────────────
    // Crew__c is a lookup (ID field); Job_Health__c and Actual_Hours__c are writable.
    // Goal_Hours__c and Variance_Hours__c are formula fields (read-only).
    @isTest
    static void testBuildCrewStatusAllNulls() {
        WorkOrder wo = new WorkOrder();

        MeasuringCupController.CrewStatus cs = MeasuringCupController.buildCrewStatus(wo);

        System.assertEquals(null, cs.crewName,      'crewName should be null when Crew__c not set');
        System.assertEquals('',   cs.foreman,       'foreman should be empty with no FM lookup');
        System.assertEquals(null, cs.goalHours,     'formula fields are null on unsaved WO');
        System.assertEquals(null, cs.actualHours);
        System.assertEquals(null, cs.varianceHours);
        System.assertEquals(null, cs.status,        'status null when Job_Health__c not set');
        System.assertEquals(null, cs.workOrderId,   'workOrderId null for unsaved WO');
    }

    @isTest
    static void testBuildCrewStatusWritableFields() {
        WorkOrder wo = new WorkOrder();
        wo.Actual_Hours__c = 7.5;
        wo.Job_Health__c   = 'Behind';

        MeasuringCupController.CrewStatus cs = MeasuringCupController.buildCrewStatus(wo);

        System.assertEquals(7.5,     cs.actualHours, 'actualHours should match');
        System.assertEquals('Behind', cs.status,      'status should match Job_Health__c');
        System.assertEquals('',       cs.foreman,     'foreman should be empty with no FM lookup');
    }

    // ── applyAggResult ────────────────────────────────────────────────────
    @isTest
    static void testApplyAggResultNullSums() {
        MeasuringCupController.CupKpis k = new MeasuringCupController.CupKpis();
        k.totalGoalHoursToday     = 0;
        k.totalActualHoursToday   = 0;
        k.totalVarianceHoursToday = 0;
        k.activeCrews             = 0;
        k.bonusEligibleCount      = 0;

        // No WOs exist today in test context; SUM() returns null, COUNT() returns 0.
        AggregateResult[] aggs = [
            SELECT SUM(Goal_Hours__c) goalH, SUM(Actual_Hours__c) actualH,
                   SUM(Variance_Hours__c) varH, COUNT(Id) cnt
            FROM WorkOrder
            WHERE Requested_Install_Date__c = TODAY
        ];
        for (AggregateResult ar : aggs) {
            MeasuringCupController.applyAggResult(k, ar);
        }

        System.assertEquals(0, k.totalGoalHoursToday,
            'null SUM should default to 0');
        System.assertEquals(0, k.totalActualHoursToday,
            'null SUM should default to 0');
        System.assertEquals(0, k.totalVarianceHoursToday,
            'null SUM should default to 0');
        System.assertEquals(0, k.activeCrews,
            'zero rows should give activeCrews = 0');
    }

    // ── CupKpis inner class fields ────────────────────────────────────────
    @isTest
    static void testCupKpisFields() {
        MeasuringCupController.CupKpis k = new MeasuringCupController.CupKpis();
        k.totalGoalHoursToday     = 10;
        k.totalActualHoursToday   = 8;
        k.totalVarianceHoursToday = -2;
        k.activeCrews             = 3;
        k.bonusEligibleCount      = 1;

        System.assertEquals(10,  k.totalGoalHoursToday);
        System.assertEquals(8,   k.totalActualHoursToday);
        System.assertEquals(-2,  k.totalVarianceHoursToday);
        System.assertEquals(3,   k.activeCrews);
        System.assertEquals(1,   k.bonusEligibleCount);
    }
}
