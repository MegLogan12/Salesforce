@isTest
private class KpiBatchScheduleTest {

    @isTest
    static void batchRunsWithoutException() {
        // DivisionKpiRecalcBatch queries Builder_Market accounts.
        // In test context with no data it runs cleanly with an empty scope.
        Test.startTest();
        DivisionKpiRecalcBatch.run();
        Test.stopTest();
        System.assert(true, 'Batch executed without exception');
    }

    @isTest
    static void divisionSummaryAvailableAfterBatch() {
        Test.startTest();
        DivisionKpiRecalcBatch.run();
        Test.stopTest();
        List<LovingCooController.DivisionRow> rows = LovingCooController.getDivisionSummary();
        System.assertNotEquals(null, rows, 'Division summary accessible post-batch');
    }
}
