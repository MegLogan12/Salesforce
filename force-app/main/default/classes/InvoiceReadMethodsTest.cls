@isTest
private class InvoiceReadMethodsTest {

    @TestSetup
    static void makeData() {
        Work_Order__c wo = new Work_Order__c(
            Total_Revenue__c     = 1500,
            Total_Cost__c        = 900,
            Status__c            = 'Closeout Approved',
            Invoice_Generated__c = false
        );
        insert wo;

        Invoice__c openInv = new Invoice__c(
            Status__c       = 'Pending Send',
            Invoice_Date__c = Date.today(),
            Due_Date__c     = Date.today().addDays(30),
            Total_Revenue__c = 1500
        );
        insert openInv;

        Invoice__c paidInv = new Invoice__c(
            Status__c        = 'Paid',
            Invoice_Date__c  = Date.today().addDays(-30),
            Due_Date__c      = Date.today(),
            Date_Paid__c     = Date.today(),
            Total_Revenue__c = 2000
        );
        insert paidInv;
    }

    @isTest
    static void getReadyToInvoice_returnsPendingWOs() {
        Test.startTest();
        List<InvoiceAccountingController.WoRow> rows = InvoiceAccountingController.getReadyToInvoice();
        Test.stopTest();
        System.assertNotEquals(null, rows, 'getReadyToInvoice should return a list');
        System.assertEquals(1, rows.size(), 'One WO ready to invoice');
        System.assertEquals('Closeout Approved', rows[0].status);
        System.assertEquals(1500, rows[0].totalRevenue);
    }

    @isTest
    static void getInvoiced_returnsOpenInvoices() {
        Test.startTest();
        List<InvoiceAccountingController.InvoiceRow> rows = InvoiceAccountingController.getInvoiced();
        Test.stopTest();
        System.assertNotEquals(null, rows, 'getInvoiced should return a list');
        System.assertEquals(1, rows.size(), 'One open invoice');
        System.assertEquals('Pending Send', rows[0].status);
    }

    @isTest
    static void getPaid_returnsPaidInvoices() {
        Test.startTest();
        List<InvoiceAccountingController.InvoiceRow> rows = InvoiceAccountingController.getPaid();
        Test.stopTest();
        System.assertNotEquals(null, rows, 'getPaid should return a list');
        System.assertEquals(1, rows.size(), 'One paid invoice');
        System.assertEquals('Paid', rows[0].status);
        System.assertEquals(Date.today(), rows[0].datePaid);
    }

    @isTest
    static void sendReminder_createsFollowUpTask() {
        Invoice__c inv = [SELECT Id, Name FROM Invoice__c WHERE Status__c = 'Pending Send' LIMIT 1];
        Test.startTest();
        InvoiceAccountingController.sendReminder(inv.Id);
        Test.stopTest();
        List<Task> tasks = [SELECT Id, Subject, Status, ActivityDate, Description
                            FROM Task WHERE Subject LIKE 'Invoice Reminder:%' LIMIT 1];
        System.assertEquals(1, tasks.size(), 'One reminder task should be created');
        System.assert(tasks[0].Subject.contains(inv.Name), 'Subject should contain invoice name');
        System.assertEquals('Open', tasks[0].Status);
        System.assertEquals(Date.today().addDays(3), tasks[0].ActivityDate);
        System.assert(tasks[0].Description.contains(inv.Id), 'Description should reference invoice Id');
    }
}
