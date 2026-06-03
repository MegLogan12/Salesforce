@isTest
private class DivisionKpiSchedulerTest {

    @isTest
    static void execute_runsWithoutException() {
        Test.startTest();
        DivisionKpiScheduler s = new DivisionKpiScheduler();
        s.execute(null);
        Test.stopTest();
        // DivisionKpiRecalcBatch is enqueued; verify no uncaught exception
        System.assert(true, 'DivisionKpiScheduler.execute completed without error');
    }

    @isTest
    static void schedule_registersJob() {
        Test.startTest();
        String jobId = System.schedule(
            'DivisionKpiScheduler_UnitTest',
            '0 0 2 * * ?',
            new DivisionKpiScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Job should be scheduled');
    }
}
