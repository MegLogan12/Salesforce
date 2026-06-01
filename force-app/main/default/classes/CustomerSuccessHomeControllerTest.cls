@isTest
private class CustomerSuccessHomeControllerTest {
    @isTest
    static void testGetHomeData() {
        Test.startTest();
        CustomerSuccessHomeController.HomeData result = CustomerSuccessHomeController.getHomeData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'HomeData should not be null');
        System.assertNotEquals(null, result.kpis, 'KPIs should not be null');
    }
}
