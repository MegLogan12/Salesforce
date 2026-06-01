@isTest
private class CCConsoleHomeControllerTest {
    @isTest
    static void testGetHomeData() {
        Test.startTest();
        CCConsoleHomeController.HomeData result = CCConsoleHomeController.getHomeData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'HomeData should not be null');
        System.assertNotEquals(null, result.kpis, 'KPIs should not be null');
    }
}
