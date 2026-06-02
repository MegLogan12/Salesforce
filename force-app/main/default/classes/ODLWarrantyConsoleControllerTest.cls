@IsTest
private class ODLWarrantyConsoleControllerTest {
    @IsTest
    static void returnsRows() {
        Account homeowner = new Account(Name = 'Warranty Homeowner');
        insert homeowner;

        Warranty_Record__c warrantyRow = new Warranty_Record__c(
            Homeowner_Account__c = homeowner.Id
        );
        insert warrantyRow;

        Test.startTest();
        ODLWarrantyConsoleController.PageData data = ODLWarrantyConsoleController.getPageData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assert(data.totalCount >= 1);
    }
}