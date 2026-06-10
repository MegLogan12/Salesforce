@IsTest
private class LegacySchedulingKpiControllerTest {
    @IsTest
    static void getSchedulingKpis_returnsDefaultShape() {
        Test.startTest();
        LegacySchedulingKpiController.SchedulingKpis result =
            LegacySchedulingKpiController.getSchedulingKpis();
        Test.stopTest();

        System.assertNotEquals(null, result, 'KPI result should be returned.');
        System.assertNotEquals(null, result.pendingProposals, 'pendingProposals should be initialized.');
        System.assertNotEquals(null, result.ctsQueue, 'ctsQueue should be initialized.');
        System.assertNotEquals(null, result.lockedToday, 'lockedToday should be initialized.');
        System.assertNotEquals(null, result.thirtyDayPipeline, 'thirtyDayPipeline should be initialized.');
        System.assertNotEquals(null, result.activeCrews, 'activeCrews should be initialized.');
    }
}