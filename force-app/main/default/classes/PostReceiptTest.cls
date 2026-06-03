@isTest
private class PostReceiptTest {

    @isTest
    static void postUpdatesOnHandAndClosesLine() {
        Account vendor = new Account(Name = 'UAT Post Vendor');
        insert vendor;

        Product2 p = new Product2(Name = 'Post Test Item', IsActive = true, StockKeepingUnit = 'PST-001', On_Hand__c = 0);
        insert p;

        Vendor_PO__c po = new Vendor_PO__c(Vendor__c = vendor.Id, Status__c = 'Submitted');
        insert po;

        Vendor_PO_Line__c pol = new Vendor_PO_Line__c(
            Vendor_PO__c = po.Id, Product__c = p.Id, Expected_Qty__c = 10, Line_Status__c = 'Open'
        );
        insert pol;

        Receipt__c rcpt = new Receipt__c(
            Vendor_PO__c = po.Id, Receipt_Date__c = Date.today(), Status__c = 'Draft'
        );
        insert rcpt;

        Receipt_Line__c rl = new Receipt_Line__c(
            Receipt__c = rcpt.Id, Product__c = p.Id, Qty__c = 10,
            PO_Line__c = pol.Id, Scanned_SKU__c = 'PST-001'
        );
        insert rl;

        Test.startTest();
        ReceivingController.PostResult result = ReceivingController.post(rcpt.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('Posted', result.receiptStatus, 'Clean match → Posted');
        System.assertEquals(1, result.matchedLines);
        System.assertEquals(0, result.varianceLines);

        Product2 updated = [SELECT On_Hand__c FROM Product2 WHERE Id = :p.Id];
        System.assertEquals(10, updated.On_Hand__c, 'On-hand incremented');

        Vendor_PO_Line__c updatedPol = [SELECT Line_Status__c FROM Vendor_PO_Line__c WHERE Id = :pol.Id];
        System.assertEquals('Received', updatedPol.Line_Status__c, 'PO line closed on clean match');
    }
}
