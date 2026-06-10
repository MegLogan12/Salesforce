/**
 * QuoteServiceTest
 * Covers QuoteHandler and QuoteService without inserting standard WorkOrders,
 * which are blocked in this org's test context by FSL access rules.
 */
@IsTest
private class QuoteServiceTest {

    private static Id getCCRecordTypeId() {
        return Schema.SObjectType.Quote__c.getRecordTypeInfosByDeveloperName()
            .get('Customer_Care').getRecordTypeId();
    }

    private static Id getPIRecordTypeId() {
        return Schema.SObjectType.Quote__c.getRecordTypeInfosByDeveloperName()
            .get('Production_Install').getRecordTypeId();
    }

    @IsTest
    static void sentDateAutoStamped() {
        Quote__c q = new Quote__c(
            RecordTypeId = getCCRecordTypeId(),
            Status__c = 'Draft'
        );

        Test.startTest();
        q.Status__c = 'Sent';
        q.Sent_Date__c = null;
        QuoteService.beforeUpsert(new List<Quote__c>{ q }, null);
        Test.stopTest();

        System.assertNotEquals(null, q.Sent_Date__c, 'Sent_Date__c should be auto-stamped');
    }

    @IsTest
    static void approvedDateAutoStamped() {
        Quote__c q = new Quote__c(
            RecordTypeId = getCCRecordTypeId(),
            Status__c = 'Submitted'
        );
        Test.startTest();
        q.Status__c = 'Approved';
        q.Approved_By__c = UserInfo.getUserId();
        q.Approved_Date__c = null;
        QuoteService.beforeUpsert(new List<Quote__c>{ q }, null);
        Test.stopTest();

        System.assertNotEquals(null, q.Approved_Date__c, 'Approved_Date__c should be auto-stamped');
    }

    @IsTest
    static void cannotUnapprove() {
        Quote__c q = new Quote__c(
            RecordTypeId = getCCRecordTypeId(),
            Status__c = 'Approved',
            Approved_By__c = UserInfo.getUserId(),
            Approved_Date__c = DateTime.now()
        );
        q.Id = 'a1i000000000001AAA';
        Quote__c oldQ = new Quote__c(Id = q.Id, Status__c = 'Approved');

        Test.startTest();
        q.Status__c = 'Draft';
        QuoteService.beforeUpsert(new List<Quote__c>{ q }, new Map<Id, Quote__c>{ q.Id => oldQ });
        Test.stopTest();

        System.assert(q.hasErrors(), 'Un-approve should add an error');
        System.assert(q.getErrors()[0].getMessage().contains('cannot be moved back'), 'Error should block un-approve');
    }

    @IsTest
    static void ccApprovalCreatesInvoiceAndOnlyBillableLines() {
        Quote__c q = new Quote__c(
            RecordTypeId = getCCRecordTypeId(),
            Status__c = 'Submitted'
        );
        insert q;

        insert new List<Quote_Line_Item__c>{
            new Quote_Line_Item__c(
                Quote__c = q.Id,
                Item_Description__c = 'Billable sod repair',
                Quantity__c = 200,
                Unit_Price__c = 0.30,
                Unit_Cost__c = 0.18,
                Determination__c = 'Billable'
            ),
            new Quote_Line_Item__c(
                Quote__c = q.Id,
                Item_Description__c = 'Warranty tree replacement',
                Quantity__c = 1,
                Unit_Price__c = 350,
                Unit_Cost__c = 200,
                Determination__c = 'Warranty'
            )
        };

        Test.startTest();
        QuoteService.onApproved(new List<Quote__c>{ q });
        Test.stopTest();

        List<Invoice__c> invoices = [
            SELECT Id, Status__c, Work_Order__c
            FROM Invoice__c
            WHERE Quote__c = :q.Id
        ];
        System.assertEquals(1, invoices.size(), 'One invoice should be created');
        System.assertEquals('Pending Send', invoices[0].Status__c, 'Invoice status should be Pending Send');
        System.assertEquals(null, invoices[0].Work_Order__c, 'No standard WorkOrder is linked in this test fixture');

        List<Invoice_Line_Item__c> invLines = [
            SELECT Id, Billable__c
            FROM Invoice_Line_Item__c
            WHERE Invoice__c = :invoices[0].Id
        ];
        System.assertEquals(1, invLines.size(), 'Only Billable lines should transfer to invoice');
        System.assertEquals(true, invLines[0].Billable__c, 'Transferred line should be Billable');
    }

    @IsTest
    static void ccApprovalWithNoLinesCreatesEmptyInvoice() {
        Quote__c q = new Quote__c(
            RecordTypeId = getCCRecordTypeId(),
            Status__c = 'Submitted'
        );
        insert q;

        Test.startTest();
        QuoteService.onApproved(new List<Quote__c>{ q });
        Test.stopTest();

        List<Invoice__c> invoices = [SELECT Id FROM Invoice__c WHERE Quote__c = :q.Id];
        System.assertEquals(1, invoices.size(), 'Invoice should be created even with no billable lines');
        System.assertEquals(0, [SELECT COUNT() FROM Invoice_Line_Item__c WHERE Invoice__c = :invoices[0].Id]);
    }

    @IsTest
    static void nonCustomerCareApprovedWithoutWorkOrderDoesNotThrow() {
        Quote__c q = new Quote__c(
            RecordTypeId = getPIRecordTypeId(),
            Status__c = 'Submitted'
        );
        insert q;

        Test.startTest();
        QuoteService.onApproved(new List<Quote__c>{ q });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Invoice__c WHERE Quote__c = :q.Id]);
    }

    @IsTest
    static void rejectedWithoutWorkOrderDoesNotThrow() {
        Quote__c q = new Quote__c(
            RecordTypeId = getCCRecordTypeId(),
            Status__c = 'Sent'
        );
        insert q;

        Test.startTest();
        QuoteService.onRejected(new List<Quote__c>{ q });
        Test.stopTest();

        System.assert(true, 'Rejected quote without linked WorkOrder should not throw');
    }

    @IsTest
    static void bulkCcApprovalCreatesInvoices() {
        Id ccRtId = getCCRecordTypeId();
        List<Quote__c> quotes = new List<Quote__c>();
        for (Integer i = 0; i < 10; i++) {
            quotes.add(new Quote__c(RecordTypeId = ccRtId, Status__c = 'Submitted'));
        }
        insert quotes;

        Test.startTest();
        QuoteService.onApproved(quotes);
        Test.stopTest();

        System.assertEquals(10, [SELECT COUNT() FROM Invoice__c], '10 invoices should be created');
    }
}