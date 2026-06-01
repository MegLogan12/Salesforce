@isTest
private class ForecastingConsoleControllerTest {
    @TestSetup
    static void setup() {
        Hire_Request__c hr = new Hire_Request__c(
            Status__c = 'Submitted'
        );
        insert hr;

        Crew__c crew = new Crew__c(Name = 'Test Crew');
        insert crew;
    }

    @isTest
    static void testGetHomeData() {
        Test.startTest();
        ForecastingConsoleController.HomeDTO result = ForecastingConsoleController.getHomeData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'HomeDTO should not be null');
        System.assert(result.openHireRequests >= 1, 'Should have at least 1 open hire request');
        System.assert(result.activeCrew >= 1, 'Should have at least 1 crew');
        System.assertNotEquals(null, result.recentHireRequests, 'recentHireRequests should not be null');
        System.assert(result.recentHireRequests.size() >= 1, 'Should have at least 1 hire request row');
        System.assertNotEquals(null, result.recentCrews, 'recentCrews should not be null');
        System.assert(result.recentCrews.size() >= 1, 'Should have at least 1 crew row');
    }
}
