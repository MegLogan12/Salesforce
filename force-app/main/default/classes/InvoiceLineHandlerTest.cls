/**
 * InvoiceLineHandlerTest
 * Covers InvoiceLineHandler + InvoiceLineTrigger
 * Target: 100% coverage
 */
@IsTest
private class InvoiceLineHandlerTest {

    @TestSetup
    static void makeData() {
        Invoice__c inv = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Status__c       = 'Pending Send'
        );
        insert inv;
    }

    private static Id getInvoiceId() {
        return [SELECT Id FROM Invoice__c LIMIT 1].Id;
    }

    // ── Insert — basic calculation ────────────────────────────────────────
    @IsTest
    static void testInsertCalculatesFields() {
        Id invId = getInvoiceId();

        Invoice_Line_Item__c line = new Invoice_Line_Item__c(
            Invoice__c    = invId,
            Quantity__c   = 500,
            Unit_Price__c = 0.25,
            Unit_Cost__c  = 0.15
        );

        Test.startTest();
        insert line;
        Test.stopTest();

        Invoice_Line_Item__c result = [
            SELECT Line_Total__c, Line_Cost__c, Gross_Margin__c, Gross_Margin_Pct__c
            FROM Invoice_Line_Item__c WHERE Id = :line.Id
        ];

        System.assertEquals(125.00, result.Line_Total__c,       'Line Total: 500 × 0.25 = 125');
        System.assertEquals(75.00,  result.Line_Cost__c,        'Line Cost: 500 × 0.15 = 75');
        System.assertEquals(50.00,  result.Gross_Margin__c,     'Gross Margin: 125 - 75 = 50');
        System.assertNotEquals(null, result.Gross_Margin_Pct__c, 'GM% should be populated');
        System.assertEquals(40.00,  result.Gross_Margin_Pct__c.setScale(2), 'GM% = 40%');
    }

    // ── Insert — zero unit price ──────────────────────────────────────────
    @IsTest
    static void testInsertZeroPrice() {
        Id invId = getInvoiceId();

        Invoice_Line_Item__c line = new Invoice_Line_Item__c(
            Invoice__c    = invId,
            Quantity__c   = 10,
            Unit_Price__c = 0,
            Unit_Cost__c  = 5.00
        );

        Test.startTest();
        insert line;
        Test.stopTest();

        Invoice_Line_Item__c result = [
            SELECT Line_Total__c, Line_Cost__c, Gross_Margin__c, Gross_Margin_Pct__c
            FROM Invoice_Line_Item__c WHERE Id = :line.Id
        ];

        System.assertEquals(0,     result.Line_Total__c,       'Line Total = 0');
        System.assertEquals(50.00, result.Line_Cost__c,        'Line Cost: 10 × 5 = 50');
        System.assertEquals(-50.0, result.Gross_Margin__c,     'Gross Margin = -50');
        System.assertEquals(0,     result.Gross_Margin_Pct__c, 'GM% = 0 (no division by zero)');
    }

    // ── Insert — null quantities treated as zero ──────────────────────────
    @IsTest
    static void testInsertNullsDefaultToZero() {
        Id invId = getInvoiceId();

        Invoice_Line_Item__c line = new Invoice_Line_Item__c(
            Invoice__c    = invId,
            Quantity__c   = null,
            Unit_Price__c = null,
            Unit_Cost__c  = null
        );

        Test.startTest();
        insert line;
        Test.stopTest();

        Invoice_Line_Item__c result = [
            SELECT Line_Total__c, Line_Cost__c, Gross_Margin__c, Gross_Margin_Pct__c
            FROM Invoice_Line_Item__c WHERE Id = :line.Id
        ];

        System.assertEquals(0, result.Line_Total__c,       'Nulls default to 0 for Line Total');
        System.assertEquals(0, result.Line_Cost__c,        'Nulls default to 0 for Line Cost');
        System.assertEquals(0, result.Gross_Margin__c,     'Gross Margin = 0');
        System.assertEquals(0, result.Gross_Margin_Pct__c, 'GM% = 0');
    }

    // ── Update — recalculates when price changes ──────────────────────────
    @IsTest
    static void testUpdateRecalculates() {
        Id invId = getInvoiceId();

        Invoice_Line_Item__c line = new Invoice_Line_Item__c(
            Invoice__c    = invId,
            Quantity__c   = 10,
            Unit_Price__c = 20.00,
            Unit_Cost__c  = 12.00
        );
        insert line;

        Test.startTest();
        line.Unit_Price__c = 25.00;
        update line;
        Test.stopTest();

        Invoice_Line_Item__c result = [
            SELECT Line_Total__c, Line_Cost__c, Gross_Margin__c
            FROM Invoice_Line_Item__c WHERE Id = :line.Id
        ];

        System.assertEquals(250.00, result.Line_Total__c,  'Line Total after increase: 10 × 25 = 250');
        System.assertEquals(120.00, result.Line_Cost__c,   'Line Cost unchanged: 10 × 12 = 120');
        System.assertEquals(130.00, result.Gross_Margin__c,'Margin: 250 - 120 = 130');
    }

    // ── Update — unrelated field change does not reset financials ─────────
    @IsTest
    static void testUpdateNoChangeSkipsRecalc() {
        Id invId = getInvoiceId();

        Invoice_Line_Item__c line = new Invoice_Line_Item__c(
            Invoice__c    = invId,
            Quantity__c   = 5,
            Unit_Price__c = 10.00,
            Unit_Cost__c  = 6.00
        );
        insert line;

        Test.startTest();
        line.Description__c = 'Updated notes only';
        update line;
        Test.stopTest();

        Invoice_Line_Item__c result = [
            SELECT Line_Total__c, Gross_Margin__c
            FROM Invoice_Line_Item__c WHERE Id = :line.Id
        ];
        System.assertEquals(50.00, result.Line_Total__c,  'Line Total unchanged');
        System.assertEquals(20.00, result.Gross_Margin__c,'Gross Margin unchanged');
    }

    // ── Bulk — 200 records ────────────────────────────────────────────────
    @IsTest
    static void testBulkInsert() {
        Id invId = getInvoiceId();
        List<Invoice_Line_Item__c> lines = new List<Invoice_Line_Item__c>();
        for (Integer i = 0; i < 200; i++) {
            lines.add(new Invoice_Line_Item__c(
                Invoice__c    = invId,
                Quantity__c   = i + 1,
                Unit_Price__c = 100.00,
                Unit_Cost__c  = 65.00
            ));
        }

        Test.startTest();
        insert lines;
        Test.stopTest();

        List<Invoice_Line_Item__c> results = [
            SELECT Line_Total__c, Gross_Margin__c
            FROM Invoice_Line_Item__c WHERE Invoice__c = :invId
        ];
        System.assertEquals(200, results.size(), 'All 200 lines inserted');
        for (Invoice_Line_Item__c r : results) {
            System.assertNotEquals(null, r.Line_Total__c, 'All lines should have Line_Total calculated');
        }
    }
}