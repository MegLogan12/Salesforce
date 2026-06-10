@isTest
private class ReceiptVarianceTest {

    @isTest
    static void shortReceiptCreatesDiscrepancyTask() {
        Account vendor = new Account(Name = 'UAT Variance Vendor');
        insert vendor;

        Product2 p = new Product2(Name = 'Short Item', IsActive = true, StockKeepingUnit = 'VAR-001', On_Hand__c = 0);
        insert p;

        Vendor_PO__c po = new Vendor_PO__c(Vendor__c = vendor.Id, Status__c = 'Submitted');
        insert po;

        Vendor_PO_Line__c pol = new Vendor_PO_Line__c(
            Vendor_PO__c = po.Id, Product__c = p.Id, Expected_Qty__c = 10, Line_Status__c = 'Open'
        );
        insert pol;

        Receipt__c rcpt = new Receipt__c(Vendor_PO__c = po.Id, Receipt_Date__c = Date.today(), Status__c = 'Draft');
        insert rcpt;

        Receipt_Line__c rl = new Receipt_Line__c(
            Receipt__c = rcpt.Id, Product__c = p.Id, Qty__c = 7,
            PO_Line__c = pol.Id
        );
        insert rl;

        Test.startTest();
        ReceivingController.PostResult result = ReceivingController.post(rcpt.Id);
        Test.stopTest();

        System.assertEquals('Variance', result.receiptStatus, 'Short delivery → Variance status');
        System.assertEquals(1, result.varianceLines);

        List<Task> tasks = [SELECT Subject FROM Task WHERE Subject LIKE 'Receipt Variance%'];
        System.assertEquals(1, tasks.size(), 'Discrepancy task created');
    }

    @isTest
    static void overReceiptSetsVarianceStatus() {
        Account vendor = new Account(Name = 'UAT Over Vendor');
        insert vendor;

        Product2 p = new Product2(Name = 'Over Item', IsActive = true, StockKeepingUnit = 'VAR-002', On_Hand__c = 0);
        insert p;

        Vendor_PO__c po = new Vendor_PO__c(Vendor__c = vendor.Id, Status__c = 'Submitted');
        insert po;

        Vendor_PO_Line__c pol = new Vendor_PO_Line__c(
            Vendor_PO__c = po.Id, Product__c = p.Id, Expected_Qty__c = 5, Line_Status__c = 'Open'
        );
        insert pol;

        Receipt__c rcpt = new Receipt__c(Vendor_PO__c = po.Id, Receipt_Date__c = Date.today(), Status__c = 'Draft');
        insert rcpt;

        Receipt_Line__c rl = new Receipt_Line__c(
            Receipt__c = rcpt.Id, Product__c = p.Id, Qty__c = 8,
            PO_Line__c = pol.Id
        );
        insert rl;

        Test.startTest();
        ReceivingController.PostResult result = ReceivingController.post(rcpt.Id);
        Test.stopTest();

        System.assertEquals('Variance', result.receiptStatus);

        Vendor_PO_Line__c updatedPol = [SELECT Line_Status__c FROM Vendor_PO_Line__c WHERE Id = :pol.Id];
        System.assertEquals('Over-Received', updatedPol.Line_Status__c);
    }
}
