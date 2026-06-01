@isTest
private class CCConsoleHomeControllerTest {
    @TestSetup
    static void setup() {
        Case c = new Case(Subject = 'Test Case', Status = 'New', Priority = 'High');
        insert c;

        Task t = new Task(
            Subject      = 'Test Task',
            Status       = 'Not Started',
            ActivityDate = Date.today().addDays(-1)
        );
        insert t;
    }

    @isTest
    static void testGetHomeData() {
        Test.startTest();
        CCConsoleHomeController.HomeData result = CCConsoleHomeController.getHomeData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'HomeData should not be null');
        System.assertNotEquals(null, result.kpis, 'KPIs should not be null');
        System.assert(result.kpis.openCases >= 1, 'Should have at least 1 open case');
        System.assertNotEquals(null, result.recentCases, 'recentCases should not be null');
        System.assertNotEquals(null, result.overdueTasks, 'overdueTasks should not be null');
        System.assert(result.recentCases.size() >= 1, 'Should have at least 1 recent case');
    }
}
