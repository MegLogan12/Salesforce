/**
 * GenerateInvoiceTest
 *
 * Unit tests for InvoiceAccountingController.generateInvoice().
 * Verifies that calling generateInvoice on a qualifying Work_Order__c:
 *   - Creates an Invoice__c with Status__c = 'Pending Send'
 *   - Sets Work_Order__c.Invoice_Generated__c = true
 *   - Sets Work_Order__c.Closing_Invoice__c to the new invoice
 *   - Captures the WO name in Invoice__c.Notes__c
 */
@isTest
private class GenerateInvoiceTest {

    @isTest
    static void generateInvoice_createsInvoiceAndUpdatesWO() {
        // Arrange
        Work_Order__c wo = new Work_Order__c(
            Total_Revenue__c     = 1000,
            Total_Cost__c        = 700,
            Status__c            = 'Closeout Approved',
            Invoice_Generated__c = false
        );
        insert wo;
        wo = [SELECT Id, Name FROM Work_Order__c WHERE Id = :wo.Id]; // refresh to get auto-generated Name

        // Act
        Test.startTest();
        Id invoiceId = InvoiceAccountingController.generateInvoice(wo.Id);
        Test.stopTest();

        // Assert — Invoice created with correct defaults
        Invoice__c inv = [
            SELECT Id, Status__c, Invoice_Date__c, Due_Date__c,
                   Total_Revenue__c, Total_Cost__c, Notes__c
            FROM   Invoice__c
            WHERE  Id = :invoiceId
        ];
        System.assertNotEquals(null, inv, 'Invoice should have been created');
        System.assertEquals('Pending Send', inv.Status__c,
            'New invoice should have Status__c = Pending Send');
        System.assertEquals(Date.today(), inv.Invoice_Date__c,
            'Invoice_Date__c should be today');
        System.assertEquals(Date.today().addDays(30), inv.Due_Date__c,
            'Due_Date__c should be today + 30 days');
        System.assertEquals(1000, inv.Total_Revenue__c,
            'Total_Revenue__c should match work order');
        System.assertEquals(700, inv.Total_Cost__c,
            'Total_Cost__c should match work order');
        System.assert(
            inv.Notes__c != null && inv.Notes__c.contains(wo.Name),
            'Notes__c should contain the source work order name'
        );

        // Assert — Work Order updated
        Work_Order__c woUpdated = [
            SELECT Invoice_Generated__c, Closing_Invoice__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
        ];
        System.assertEquals(true, woUpdated.Invoice_Generated__c,
            'Invoice_Generated__c should be set to true');
        System.assertEquals(invoiceId, woUpdated.Closing_Invoice__c,
            'Closing_Invoice__c should point to the new invoice');
    }

    @isTest
    static void generateInvoice_returnsNewInvoiceId() {
        Work_Order__c wo = new Work_Order__c(
            Total_Revenue__c     = 500,
            Total_Cost__c        = 300,
            Status__c            = 'Closeout Approved',
            Invoice_Generated__c = false
        );
        insert wo;

        Test.startTest();
        Id result = InvoiceAccountingController.generateInvoice(wo.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'generateInvoice should return a non-null Id');
        // Confirm it is a valid Invoice__c Id
        List<Invoice__c> invList = [SELECT Id FROM Invoice__c WHERE Id = :result];
        System.assertEquals(1, invList.size(), 'Returned Id should correspond to an Invoice__c record');
    }
}
