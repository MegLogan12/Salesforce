@IsTest
private class ODLCampaignListControllerTest {
    @IsTest
    static void returnsCampaignRows() {
        Account builder = new Account(Name = 'Campaign Builder');
        insert builder;
        Product2 grill = new Product2(Name = 'Campaign Test Grill', IsActive = true);
        insert grill;

        Campaign campaignRow = new Campaign(
            Name = 'ODL Campaign Smoke',
            IsActive = true,
            Type = 'Builder-Sponsored Voucher',
            Status = 'In Progress',
            Builder_Account__c = builder.Id
        );
        insert campaignRow;

        Lead leadRow = new Lead(
            LastName = 'Campaign Lead',
            Company = 'ODL',
            Status = 'Open - Not Contacted',
            Community_Name__c = 'ODL Test Community',
            LeadSource = 'Other'
        );
        insert leadRow;
        insert new CampaignMember(CampaignId = campaignRow.Id, LeadId = leadRow.Id);

        insert new List<Voucher__c>{
            new Voucher__c(Voucher_Code__c = 'CAMP-001', Status__c = 'Submitted', Voucher_Type__c = 'Standard Grilling Island', Campaign__c = campaignRow.Id, Builder_Account__c = builder.Id, Eligible_Product__c = grill.Id),
            new Voucher__c(Voucher_Code__c = 'CAMP-002', Status__c = 'Validated', Voucher_Type__c = 'Standard Grilling Island', Campaign__c = campaignRow.Id, Builder_Account__c = builder.Id, Eligible_Product__c = grill.Id),
            new Voucher__c(Voucher_Code__c = 'CAMP-003', Status__c = 'Reserved', Voucher_Type__c = 'Standard Grilling Island', Campaign__c = campaignRow.Id, Builder_Account__c = builder.Id, Eligible_Product__c = grill.Id),
            new Voucher__c(Voucher_Code__c = 'CAMP-004', Status__c = 'Applied to Quote', Voucher_Type__c = 'Standard Grilling Island', Campaign__c = campaignRow.Id, Builder_Account__c = builder.Id, Eligible_Product__c = grill.Id),
            new Voucher__c(
                Voucher_Code__c = 'CAMP-005',
                Status__c = 'Builder Invoice Pending',
                Voucher_Type__c = 'Standard Grilling Island',
                Campaign__c = campaignRow.Id,
                Builder_Account__c = builder.Id,
                Voucher_Face_Value__c = 5000,
                Eligible_Product__c = grill.Id
            ),
            new Voucher__c(
                Voucher_Code__c = 'CAMP-006',
                Status__c = 'Builder Invoiced',
                Voucher_Type__c = 'Standard Grilling Island',
                Campaign__c = campaignRow.Id,
                Builder_Account__c = builder.Id,
                Voucher_Face_Value__c = 5000,
                Eligible_Product__c = grill.Id,
                Builder_Invoice_Number__c = 'INV-1006',
                Builder_Invoice_Date__c = Date.today(),
                Builder_Invoice_Status__c = 'Pending'
            ),
            new Voucher__c(
                Voucher_Code__c = 'CAMP-007',
                Status__c = 'Paid by Builder',
                Voucher_Type__c = 'Standard Grilling Island',
                Campaign__c = campaignRow.Id,
                Builder_Account__c = builder.Id,
                Voucher_Face_Value__c = 5000,
                Eligible_Product__c = grill.Id,
                Builder_Invoice_Number__c = 'INV-1007',
                Builder_Invoice_Date__c = Date.today(),
                Builder_Invoice_Status__c = 'Paid',
                Builder_Paid_Date__c = Date.today()
            ),
            new Voucher__c(
                Voucher_Code__c = 'CAMP-008',
                Status__c = 'Rejected',
                Voucher_Type__c = 'Standard Grilling Island',
                Campaign__c = campaignRow.Id,
                Builder_Account__c = builder.Id,
                Eligible_Product__c = grill.Id,
                Rejection_Reason__c = 'Other'
            )
        };

        Test.startTest();
        ODLCampaignListController.PageData data = ODLCampaignListController.getPageData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assertNotEquals(null, data.rows);
        System.assert(data.rows.size() >= 1);
        System.assertEquals(1, data.submittedCount);
        System.assertEquals(1, data.validatedCount);
        System.assertEquals(1, data.reservedCount);
        System.assertEquals(1, data.appliedCount);
        System.assertEquals(1, data.builderInvoicePendingCount);
        System.assertEquals(1, data.builderInvoicedCount);
        System.assertEquals(1, data.paidByBuilderCount);
        System.assertEquals(1, data.rejectedOrExpiredCount);
    }
}