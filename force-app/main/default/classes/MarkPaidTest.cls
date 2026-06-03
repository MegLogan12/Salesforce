/**
 * MarkPaidTest
 *
 * Unit tests for InvoiceAccountingController.markPaid().
 * Verifies that:
 *   - Invoice__c.Status__c is set to 'Paid'
 *   - Invoice__c.Date_Paid__c is set to today
 *   - Invoice__c.Payment_Status__c is set to 'Paid'
 *   - Linked Work_Order__c.Paid__c is set to true when Closing_Invoice__c matches
 */
@isTest
private class MarkPaidTest {

    @isTest
    static void markPaid_updatesInvoiceStatus() {
        // Arrange
        Invoice__c inv = new Invoice__c(
            Status__c       = 'Pending Send',
            Invoice_Date__c = Date.today(),
            Due_Date__c     = Date.today().addDays(30)
        );
        insert inv;

        // Act
        Test.startTest();
        InvoiceAccountingController.markPaid(inv.Id);
        Test.stopTest();

        // Assert
        Invoice__c updated = [
            SELECT Status__c, Date_Paid__c, Payment_Status__c
            FROM   Invoice__c
            WHERE  Id = :inv.Id
        ];
        System.assertEquals('Paid', updated.Status__c,
            'Status__c should be updated to Paid');
        System.assertEquals(Date.today(), updated.Date_Paid__c,
            'Date_Paid__c should be today');
        System.assertEquals('Paid', updated.Payment_Status__c,
            'Payment_Status__c should be updated to Paid');
    }

    @isTest
    static void markPaid_updatesLinkedWorkOrder() {
        // Arrange — create invoice then link a work order to it
        Invoice__c inv = new Invoice__c(
            Status__c       = 'Sent',
            Invoice_Date__c = Date.today(),
            Due_Date__c     = Date.today().addDays(30)
        );
        insert inv;

        Work_Order__c wo = new Work_Order__c(
            Total_Revenue__c     = 2000,
            Total_Cost__c        = 1200,
            Invoice_Generated__c = true,
            Closing_Invoice__c   = inv.Id,
            Paid__c              = false
        );
        insert wo;

        // Act
        Test.startTest();
        InvoiceAccountingController.markPaid(inv.Id);
        Test.stopTest();

        // Assert Work Order was updated
        Work_Order__c woUpdated = [
            SELECT Paid__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
        ];
        System.assertEquals(true, woUpdated.Paid__c,
            'Linked Work_Order__c.Paid__c should be set to true');
    }

    @isTest
    static void markPaid_noLinkedWorkOrder_doesNotThrow() {
        // Arrange — invoice with no linked work order
        Invoice__c inv = new Invoice__c(
            Status__c       = 'Pending Send',
            Invoice_Date__c = Date.today(),
            Due_Date__c     = Date.today().addDays(30)
        );
        insert inv;

        // Act & Assert — should complete without error
        Test.startTest();
        Boolean threw = false;
        try {
            InvoiceAccountingController.markPaid(inv.Id);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw,
            'markPaid should not throw when no linked Work Order exists');
    }
}
