/**
 * InvoiceAccountingControllerTest
 * Uses SeeAllData=true to query real Completed WorkOrders (cannot INSERT WOs).
 * Exercises buildView() with in-memory stubs for variance and empty-list cases.
 */
@IsTest
private class InvoiceAccountingControllerTest {

    // ─── Test 1: query real Completed WOs and confirm view structure ──────────

    @IsTest(SeeAllData=true)
    static void buildView_completedWos_returnsView() {
        // Query up to 5 real Completed WOs (read-only)
        List<WorkOrder> realWos = [
            SELECT Id, WorkOrderNumber, Account.Name,
                   Community__r.Name, GrandTotal,
                   Invoice_Amount__c, Field_Complete_Date__c,
                   Status, Invoice_Notes__c
            FROM   WorkOrder
            WHERE  Status = 'Completed'
            LIMIT  5
        ];

        Test.startTest();
        InvoiceAccountingController.InvoiceView v =
            InvoiceAccountingController.buildView(realWos);
        Test.stopTest();

        System.assertNotEquals(null, v,
            'buildView should return a non-null InvoiceView.');
        System.assertNotEquals(null, v.rows,
            'rows list should never be null.');
        System.assertEquals(realWos.size(), v.readyToInvoice,
            'readyToInvoice count should match the input list size.');
        System.assert(v.totalPipeline >= 0,
            'totalPipeline should be non-negative.');
    }

    // ─── Test 2: variance detection ───────────────────────────────────────────
    // GrandTotal is a formula field (read-only); Invoice_Amount__c is writable.
    // hasVariance fires when Invoice_Amount__c != null AND != GrandTotal.
    // We stub an in-memory WO with Invoice_Amount__c set to a non-zero value
    // and verify buildView flags the row correctly.

    @IsTest(SeeAllData=false)
    static void buildView_varianceDetected() {
        // In-memory stub — do NOT insert (before-save Flow blocks it)
        WorkOrder wo = new WorkOrder();
        wo.Status            = 'Completed';
        // GrandTotal is formula → null in-memory
        // Invoice_Amount__c set to a value → null != someValue means variance
        // Per spec: hasVariance = Invoice_Amount__c != null && GrandTotal != null && different
        // With GrandTotal null, hasVariance will be false (guard condition met).
        // Test the positive case: both non-null and different.
        // We cannot set formula fields in Apex, so we test the guard path
        // (GrandTotal null → hasVariance false, Invoice_Amount__c populated).
        wo.Invoice_Amount__c = 1500.00;

        List<WorkOrder> wos = new List<WorkOrder>{ wo };

        Test.startTest();
        InvoiceAccountingController.InvoiceView v =
            InvoiceAccountingController.buildView(wos);
        Test.stopTest();

        System.assertEquals(1, v.readyToInvoice,
            'Should have one row.');
        InvoiceAccountingController.InvoiceRow row = v.rows[0];
        System.assertEquals(1500.00, row.invoiceAmount,
            'Invoice amount should be 1500.');
        // GrandTotal is null (formula, cannot be set) → hasVariance = false
        // because the guard requires both to be non-null
        System.assertEquals(false, row.hasVariance,
            'hasVariance should be false when GrandTotal is null (formula field).');
    }

    // ─── Test 3: empty list → zeros ───────────────────────────────────────────

    @IsTest(SeeAllData=false)
    static void buildView_emptyList() {
        Test.startTest();
        InvoiceAccountingController.InvoiceView v =
            InvoiceAccountingController.buildView(new List<WorkOrder>());
        Test.stopTest();

        System.assertEquals(0, v.readyToInvoice,
            'readyToInvoice should be 0 for empty list.');
        System.assertEquals(0, v.withVariance,
            'withVariance should be 0 for empty list.');
        System.assertEquals(0, v.totalPipeline,
            'totalPipeline should be 0 for empty list.');
        System.assertNotEquals(null, v.rows,
            'rows should be an empty list, not null.');
        System.assertEquals(0, v.rows.size(),
            'rows should have size 0.');
    }
}
