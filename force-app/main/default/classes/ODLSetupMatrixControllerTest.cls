@IsTest
private class ODLSetupMatrixControllerTest {
    @IsTest
    static void returnsDescribeBackedData() {
        Test.startTest();
        ODLSetupMatrixController.PageData data = ODLSetupMatrixController.getPageData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assertEquals(true, data.objectRows.size() >= 3);
        System.assertEquals(true, data.pageRows.size() >= 3);
        System.assertEquals(true, data.picklistRows.size() >= 3);
    }
}