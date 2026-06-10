@IsTest
private class ODLHomeDashboardControllerTest {
    @IsTest
    static void returnsDashboardData() {
        Test.startTest();
        ODLHomeDashboardController.DashboardData data = ODLHomeDashboardController.getDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, data, 'Dashboard data should be returned.');
        System.assertNotEquals(null, data.opportunityRows, 'Opportunity rows should always be initialized.');
        System.assertNotEquals(null, data.voucherRows, 'Voucher rows should always be initialized.');
        System.assert(data.accountCount >= 0);
        System.assert(data.leadCount >= 0);
        System.assert(data.opportunityCount >= 0);
        System.assert(data.voucherCount >= 0);
    }

    @IsTest
    static void buildsQuickRows() {
        Opportunity opp = new Opportunity(
            Id = '006000000000001AAA',
            Name = 'Test ODL Opportunity',
            StageName = 'Consultation Scheduled',
            Account = new Account(Name = 'Test Household')
        );
        ODLHomeDashboardController.QuickRow oppRow = ODLHomeDashboardController.buildOpportunityRow(opp);
        System.assertEquals('Test ODL Opportunity', oppRow.label);
        System.assert(oppRow.sublabel.contains('Test Household'));
        System.assert(oppRow.sublabel.contains('Consultation Scheduled'));
        System.assertEquals('/lightning/r/Opportunity/006000000000001AAA/view', oppRow.url);

        Voucher__c voucher = new Voucher__c(
            Id = 'a38000000000001AAA',
            Voucher_Code__c = 'VCH-001',
            Status__c = 'Validated'
        );
        ODLHomeDashboardController.QuickRow voucherRow = ODLHomeDashboardController.buildVoucherRow(voucher);
        System.assertEquals('VCH-001', voucherRow.label);
        System.assertEquals('Validated', voucherRow.sublabel);
        System.assertEquals('/lightning/r/Voucher__c/a38000000000001AAA/view', voucherRow.url);
    }
}