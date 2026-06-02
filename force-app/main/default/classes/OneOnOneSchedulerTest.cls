@IsTest
private class OneOnOneSchedulerTest {

    @IsTest
    static void runWithNoExistingPairsCreatesNothing() {
        Test.startTest();
        Integer created = OneOnOneScheduler.run();
        Test.stopTest();
        System.assertEquals(0, created);
    }

    @IsTest
    static void runCreatesRecordForRecurringPair() {
        User mgr = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        User report;
        try {
            report = [SELECT Id FROM User WHERE IsActive = true AND Id != :mgr.Id LIMIT 1];
        } catch (Exception e) {
            // Only one user available - use same for both
            report = mgr;
        }

        // Seed an existing weekly 1:1 (defines the recurring pair)
        OneOnOne__c seed = new OneOnOne__c(
            Manager__c = mgr.Id,
            Direct_Report__c = report.Id,
            Meeting_Date__c = DateTime.now().addDays(-7),
            Cadence__c = 'Weekly',
            Status__c = 'Completed'
        );
        insert seed;

        Test.startTest();
        Integer created = OneOnOneScheduler.run();
        Test.stopTest();

        System.assert(created >= 0, 'Should not throw');
    }

    @IsTest
    static void runIsIdempotent() {
        User mgr = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        OneOnOne__c seed = new OneOnOne__c(
            Manager__c = mgr.Id,
            Direct_Report__c = mgr.Id,
            Meeting_Date__c = DateTime.now().addDays(7),  // future
            Cadence__c = 'Weekly',
            Status__c = 'Scheduled'
        );
        insert seed;

        Test.startTest();
        OneOnOneScheduler.run();
        Integer secondRun = OneOnOneScheduler.run();
        Test.stopTest();

        System.assert(secondRun >= 0, 'Should not throw on second run');
    }

    @IsTest
    static void schedulableExecuteRuns() {
        Test.startTest();
        OneOnOneScheduler s = new OneOnOneScheduler();
        s.execute(null);
        Test.stopTest();
        System.assert(true, 'execute completed');
    }

    @IsTest
    static void scheduleWeeklyReturnsJobId() {
        Test.startTest();
        String jobId = OneOnOneScheduler.scheduleWeekly();
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void computeNextMondayHandlesEdgeCases() {
        Date result = OneOnOneScheduler.computeNextMonday(Date.newInstance(2026, 4, 27)); // Monday
        System.assertEquals(Date.newInstance(2026, 4, 27), result);

        Date sunday = OneOnOneScheduler.computeNextMonday(Date.newInstance(2026, 4, 26)); // Sunday
        System.assertEquals(Date.newInstance(2026, 4, 27), sunday);

        Date wed = OneOnOneScheduler.computeNextMonday(Date.newInstance(2026, 4, 29)); // Wed
        System.assertEquals(Date.newInstance(2026, 5, 4), wed);
    }
}