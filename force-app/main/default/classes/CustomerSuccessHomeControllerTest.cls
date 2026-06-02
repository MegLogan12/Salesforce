@isTest
private class CustomerSuccessHomeControllerTest {
    @TestSetup
    static void setup() {
        Case c = new Case(
            Subject     = 'Warranty Test Case',
            Status      = 'New',
            Priority    = 'Medium',
            Type        = 'Warranty',
            IsEscalated = true
        );
        insert c;

        Task t = new Task(
            Subject      = 'Follow-Up Task',
            Status       = 'Not Started',
            ActivityDate = Date.today().addDays(-1)
        );
        insert t;
    }

    @isTest
    static void testGetHomeData() {
        Test.startTest();
        CustomerSuccessHomeController.HomeData result = CustomerSuccessHomeController.getHomeData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'HomeData should not be null');
        System.assertNotEquals(null, result.kpis, 'KPIs should not be null');
        System.assert(result.kpis.openCases >= 1, 'Should have at least 1 open case');
        System.assert(result.kpis.escalatedCases >= 1, 'Should have at least 1 escalated case');
        System.assert(result.kpis.warrantyCases >= 1, 'Should have at least 1 warranty case');
        System.assertNotEquals(null, result.recentCases, 'recentCases should not be null');
        System.assert(result.recentCases.size() >= 1, 'Should have at least 1 recent case');
    }
}