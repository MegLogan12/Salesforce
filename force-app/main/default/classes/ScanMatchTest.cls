@isTest
private class ScanMatchTest {

    @isTest
    static void scanMatchesOpenPOLine() {
        Account vendor = new Account(Name = 'UAT Vendor');
        insert vendor;

        Product2 p = new Product2(Name = 'Test Sod', IsActive = true, StockKeepingUnit = 'SCN-001');
        insert p;

        Vendor_PO__c po = new Vendor_PO__c(Vendor__c = vendor.Id, Status__c = 'Submitted');
        insert po;

        Vendor_PO_Line__c pol = new Vendor_PO_Line__c(
            Vendor_PO__c = po.Id, Product__c = p.Id, Expected_Qty__c = 10, Line_Status__c = 'Open'
        );
        insert pol;

        Test.startTest();
        ReceivingController.ScanResult result = ReceivingController.scan('SCN-001', po.Id);
        Test.stopTest();

        System.assertEquals(true, result.matched, 'Should match open PO line');
        System.assertEquals(p.Id, result.productId);
        System.assertEquals(pol.Id, result.poLineId);
        System.assertEquals(10, result.poExpectedQty);
    }

    @isTest
    static void scanReturnsUnmatchedForUnknownSKU() {
        Account vendor = new Account(Name = 'UAT Vendor 2');
        insert vendor;
        Vendor_PO__c po = new Vendor_PO__c(Vendor__c = vendor.Id, Status__c = 'Submitted');
        insert po;

        Test.startTest();
        ReceivingController.ScanResult result = ReceivingController.scan('UNKNOWN-SKU', po.Id);
        Test.stopTest();

        System.assertEquals(false, result.matched, 'Unknown SKU should not match');
    }

    @isTest
    static void scanReturnsUnmatchedWhenPOLineIsClosed() {
        Account vendor = new Account(Name = 'UAT Vendor 3');
        insert vendor;
        Product2 p = new Product2(Name = 'Closed SKU', IsActive = true, StockKeepingUnit = 'SCN-002');
        insert p;
        Vendor_PO__c po = new Vendor_PO__c(Vendor__c = vendor.Id, Status__c = 'Received');
        insert po;
        Vendor_PO_Line__c pol = new Vendor_PO_Line__c(
            Vendor_PO__c = po.Id, Product__c = p.Id, Expected_Qty__c = 5, Line_Status__c = 'Closed'
        );
        insert pol;

        Test.startTest();
        ReceivingController.ScanResult result = ReceivingController.scan('SCN-002', po.Id);
        Test.stopTest();

        System.assertEquals(false, result.matched, 'Closed PO line should not match');
    }
}
