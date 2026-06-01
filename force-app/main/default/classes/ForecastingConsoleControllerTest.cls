@isTest
private class ForecastingConsoleControllerTest {
    @isTest
    static void testGetHomeData() {
        Test.startTest();
        ForecastingConsoleController.HomeDTO result = ForecastingConsoleController.getHomeData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'HomeDTO should not be null');
    }
}
