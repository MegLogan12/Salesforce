/**
 * LOVING_SchedulerTest
 *
 * Test coverage for all LOVING scheduler classes:
 *   - LOVING_BucketEngineScheduler
 *   - LOVING_HealthCheckScheduler
 *   - LOVING_HealthCheckEscalationScheduler
 *   - LOVING_TakeoffEscalationScheduler
 *   - LOVING_QIEscalationScheduler
 *
 * These tests verify schedulable interface compliance and that execute()
 * runs without throwing an exception. Full logic coverage is in the
 * service class tests.
 */
@isTest
private class LOVING_SchedulerTest {

    // ── BucketEngineScheduler ────────────────────────────────────────────────

    @isTest
    static void testBucketEngineScheduler_execute() {
        Test.startTest();
        LOVING_BucketEngineScheduler sched = new LOVING_BucketEngineScheduler();
        String cronExpr = '0 0 5 ? * * *';
        System.schedule('Test Bucket Engine', cronExpr, sched);
        Test.stopTest();
        // No exception = pass
    }

    // ── HealthCheckScheduler ─────────────────────────────────────────────────

    @isTest
    static void testHealthCheckScheduler_noActiveWOs() {
        Test.startTest();
        LOVING_HealthCheckScheduler sched = new LOVING_HealthCheckScheduler();
        sched.execute(null);
        Test.stopTest();
        // With no WOs in test context, should exit cleanly
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE Type = 'Health Check']);
    }

    @isTest
    static void testHealthCheckScheduler_schedulable() {
        Test.startTest();
        String cronExpr = '0 0 14 ? * MON-FRI *';
        System.schedule('Test Health Check 2PM', cronExpr, new LOVING_HealthCheckScheduler());
        Test.stopTest();
    }

    // ── HealthCheckEscalationScheduler ───────────────────────────────────────

    @isTest
    static void testHealthCheckEscalationScheduler_noOverdue() {
        Test.startTest();
        LOVING_HealthCheckEscalationScheduler sched = new LOVING_HealthCheckEscalationScheduler();
        sched.execute(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE Type = 'Escalation'
                                  AND Subject LIKE 'OVERDUE: Health Check%']);
    }

    @isTest
    static void testHealthCheckEscalationScheduler_schedulable() {
        Test.startTest();
        String cronExpr = '0 0 15 ? * MON-FRI *';
        System.schedule('Test HC Escalation 3PM', cronExpr,
            new LOVING_HealthCheckEscalationScheduler());
        Test.stopTest();
    }

    // ── TakeoffEscalationScheduler ───────────────────────────────────────────

    @isTest
    static void testTakeoffEscalationScheduler_noOverdue() {
        Test.startTest();
        LOVING_TakeoffEscalationScheduler sched = new LOVING_TakeoffEscalationScheduler();
        sched.execute(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE Subject LIKE 'OVERDUE TAKEOFF%']);
    }

    @isTest
    static void testTakeoffEscalationScheduler_schedulable() {
        Test.startTest();
        String cronExpr = '0 0 9 ? * MON-FRI *';
        System.schedule('Test Takeoff Escalation 9AM', cronExpr,
            new LOVING_TakeoffEscalationScheduler());
        Test.stopTest();
    }

    // ── QIEscalationScheduler ────────────────────────────────────────────────

    @isTest
    static void testQIEscalationScheduler_noOverdue() {
        Test.startTest();
        LOVING_QIEscalationScheduler sched = new LOVING_QIEscalationScheduler();
        sched.execute(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE Subject LIKE 'OVERDUE QI%']);
    }

    @isTest
    static void testQIEscalationScheduler_schedulable() {
        Test.startTest();
        String cronExpr = '0 0 8 ? * MON-FRI *';
        System.schedule('Test QI Escalation 8AM', cronExpr,
            new LOVING_QIEscalationScheduler());
        Test.stopTest();
    }
}
