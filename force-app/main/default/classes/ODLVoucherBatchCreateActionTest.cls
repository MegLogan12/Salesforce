@IsTest
private class ODLVoucherBatchCreateActionTest {
    @IsTest
    static void createsLennarVoucherBatchFromCampaignContext() {
        Account builder = new Account(Name = 'Lennar Homes');
        insert builder;

        Campaign campaignRow = new Campaign(
            Name = 'Lennar Voucher',
            Status = 'In Progress',
            Type = 'Website Direct',
            IsActive = true,
            Builder_Account__c = builder.Id
        );
        insert campaignRow;

        ODLVoucherBatchCreateAction.Request requestRow = new ODLVoucherBatchCreateAction.Request();
        requestRow.quantity = 3;
        requestRow.campaignId = campaignRow.Id;
        requestRow.voucherStatus = 'Active';
        requestRow.codePrefix = 'LENNAR';

        Test.startTest();
        List<ODLVoucherBatchCreateAction.Result> results = ODLVoucherBatchCreateAction.createVouchers(
            new List<ODLVoucherBatchCreateAction.Request>{ requestRow }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(3, results[0].createdCount);
        System.assert(results[0].message.contains('Created 3 vouchers'));

        List<Voucher__c> vouchers = [
            SELECT Voucher_Code__c, Campaign__c, Builder_Account__c, Voucher_Type__c,
                   Builder_Invoice_Status__c
            FROM Voucher__c
            WHERE Campaign__c = :campaignRow.Id
            ORDER BY CreatedDate DESC
        ];
        System.assertEquals(3, vouchers.size());
        for (Voucher__c voucherRow : vouchers) {
            System.assert(voucherRow.Voucher_Code__c.startsWith('LENNAR-'));
            System.assertEquals(builder.Id, voucherRow.Builder_Account__c);
            System.assertEquals('Standard Grilling Island', voucherRow.Voucher_Type__c);
            System.assertEquals('Pending', voucherRow.Builder_Invoice_Status__c);
        }
    }
}