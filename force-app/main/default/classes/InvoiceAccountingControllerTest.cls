/**
 * InvoiceAccountingControllerTest
 *
 * Replaces the old test that exercised buildView()/getQueue()/InvoiceView.
 * Those methods were removed when the controller was rewritten (Build 26).
 *
 * Coverage for the current interface is split across:
 *   - InvoiceReadMethodsTest   (getReadyToInvoice, getInvoiced, getPaid, sendReminder)
 *   - GenerateInvoiceTest      (generateInvoice)
 *   - MarkPaidTest             (markPaid)
 *
 * This class provides an additional round-trip smoke test that chains
 * generateInvoice → getInvoiced → markPaid → getPaid in a single transaction.
 */
@IsTest
private class InvoiceAccountingControllerTest {

    @IsTest
    static void fullLifecycle_generateThenMarkPaid() {
        // Arrange
        Work_Order__c wo = new Work_Order__c(
            Total_Revenue__c     = 3000,
            Total_Cost__c        = 1800,
            Status__c            = 'Closeout Approved',
            Invoice_Generated__c = false
        );
        insert wo;

        Test.startTest();

        // Generate an invoice
        Id invId = InvoiceAccountingController.generateInvoice(wo.Id);
        System.assertNotEquals(null, invId, 'generateInvoice should return a non-null Id');

        // It should appear in getInvoiced (status = Pending Send, not Paid)
        List<InvoiceAccountingController.InvoiceRow> open =
            InvoiceAccountingController.getInvoiced();
        System.assertEquals(1, open.size(), 'One open invoice expected');
        System.assertEquals('Pending Send', open[0].status);
        System.assertEquals(3000, open[0].totalRevenue);

        // Mark it paid
        InvoiceAccountingController.markPaid(invId);

        // Should move to getPaid
        List<InvoiceAccountingController.InvoiceRow> paid =
            InvoiceAccountingController.getPaid();
        System.assertEquals(1, paid.size(), 'One paid invoice expected');
        System.assertEquals('Paid', paid[0].status);
        System.assertEquals(Date.today(), paid[0].datePaid);

        // getReadyToInvoice — WO is now invoiced, should not appear
        List<InvoiceAccountingController.WoRow> ready =
            InvoiceAccountingController.getReadyToInvoice();
        System.assertEquals(0, ready.size(), 'WO should no longer appear in ready list');

        Test.stopTest();
    }
}
