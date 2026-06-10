@IsTest
private class ODLVoucherLifecycleServiceTest {

    @TestSetup
    static void setupData() {
        Account builder = new Account(Name = 'Lennar Test Builder');
        insert builder;

        Product2 entitlement = new Product2(Name = 'Standard Grilling Island', Family = 'Standard Grilling Island', IsActive = true);
        Product2 addOn = new Product2(Name = 'Fire Pit Add On', Family = 'Fire Pit', IsActive = true);
        insert new List<Product2>{ entitlement, addOn };

        Id standardPricebookId = Test.getStandardPricebookId();
        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = entitlement.Id, UnitPrice = 5000, IsActive = true),
            new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = addOn.Id, UnitPrice = 1200, IsActive = true)
        };

        Community__c testCommunity = new Community__c(
            Name = 'Voucher Test Community',
            Builder_Account__c = builder.Id,
            Community_Status__c = 'Active'
        );
        insert testCommunity;
        insert new Lot__c(
            Lot_Number__c = 'VT-LOT-001',
            Community__c = testCommunity.Id,
            Lot_Status__c = 'Open'
        );
    }

    @IsTest
    static void testVoucherLifecycleAndUpsellTracking() {
        Account builder = [SELECT Id FROM Account WHERE Name = 'Lennar Test Builder' LIMIT 1];
        Product2 entitlement = [SELECT Id FROM Product2 WHERE Name = 'Standard Grilling Island' LIMIT 1];
        PricebookEntry entitlementPbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :entitlement.Id LIMIT 1];
        Product2 addOn = [SELECT Id FROM Product2 WHERE Name = 'Fire Pit Add On' LIMIT 1];
        PricebookEntry addOnPbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :addOn.Id LIMIT 1];

        Campaign campaignRow = new Campaign(
            Name = 'Lennar Standard Grilling Island Test',
            Builder_Account__c = builder.Id,
            Offer_Description__c = 'Standard Grilling Island'
        );
        insert campaignRow;

        Lead leadRow = new Lead(
            LastName = 'Voucher Test',
            Company = 'Homeowner',
            Email = 'voucher-test@example.com',
            LeadSource = 'Lennar Voucher',
            Status = 'New'
        );
        insert leadRow;

        Contact leadContact = new Contact(
            LastName = 'Voucher Lead Contact',
            Email = 'voucher-test@example.com',
            AccountId = builder.Id
        );
        insert leadContact;

        Voucher__c voucherRow = new Voucher__c(
            Voucher_Code__c = 'LENNAR-TEST-001',
            Status__c = 'Active',
            Voucher_Type__c = 'Standard Grilling Island',
            Voucher_Entitlement__c = 'Standard Grilling Island',
            Builder_Account__c = builder.Id,
            Contact__c = leadContact.Id,
            Eligible_Product__c = entitlement.Id
        );
        insert voucherRow;

        Test.startTest();
        ODLVoucherLifecycleService.ActionResult submitResult =
            ODLVoucherLifecycleService.submitVoucherForLead(leadRow.Id, campaignRow.Id, 'LENNAR-TEST-001');
        System.assertEquals(true, submitResult.success);

        Lot__c testLot = [SELECT Id FROM Lot__c WHERE Lot_Number__c = 'VT-LOT-001' LIMIT 1];
        update new Voucher__c(Id = voucherRow.Id, Lot__c = testLot.Id);

        ODLVoucherLifecycleService.ActionResult validateResult =
            ODLVoucherLifecycleService.validateVoucher(voucherRow.Id);
        System.assertEquals(true, validateResult.success);

        Account homeowner = new Account(Name = 'Homeowner Test');
        insert homeowner;
        Contact homeownerContact = new Contact(
            LastName = 'Voucher Homeowner',
            Email = 'voucher-homeowner@example.com',
            AccountId = homeowner.Id
        );
        insert homeownerContact;

        Opportunity oppRow = new Opportunity(
            Name = 'Voucher UMB Opportunity',
            AccountId = homeowner.Id,
            StageName = 'Consultation Scheduled',
            CloseDate = Date.today().addDays(30),
            Type = 'UMB',
            BMG_Package__c = 'Entertainer',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert oppRow;
        insert new OpportunityContactRole(
            OpportunityId = oppRow.Id,
            ContactId = homeownerContact.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );

        ODLVoucherLifecycleService.ActionResult reserveResult =
            ODLVoucherLifecycleService.reserveVoucher(voucherRow.Id, oppRow.Id);
        System.assertEquals(true, reserveResult.success);

        Quote quoteRow = new Quote(
            Name = 'Voucher Quote',
            OpportunityId = oppRow.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Voucher__c = voucherRow.Id,
            Voucher_Credit_Amount__c = 5000
        );
        insert quoteRow;

        insert new List<QuoteLineItem>{
            new QuoteLineItem(QuoteId = quoteRow.Id, PricebookEntryId = entitlementPbe.Id, Quantity = 1, UnitPrice = 5000),
            new QuoteLineItem(QuoteId = quoteRow.Id, PricebookEntryId = addOnPbe.Id, Quantity = 1, UnitPrice = 1200)
        };
        QuoteLineItem addOnLine = [
            SELECT Id, Quantity
            FROM QuoteLineItem
            WHERE QuoteId = :quoteRow.Id AND PricebookEntryId = :addOnPbe.Id
            LIMIT 1
        ];
        addOnLine.Quantity = 2;
        update addOnLine;
        delete addOnLine;
        undelete addOnLine;

        oppRow.StageName = 'Contract Signed';
        update oppRow;

        Payment_Milestone__c depositRow = new Payment_Milestone__c(
            Voucher__c = voucherRow.Id,
            Type__c = 'Deposit',
            Status__c = 'Sent',
            Amount__c = 5000,
            Paid_Date__c = Date.today()
        );
        insert depositRow;
        depositRow.Status__c = 'Paid';
        update depositRow;

        ODLVoucherLifecycleService.ActionResult invoicedResult =
            ODLVoucherLifecycleService.markBuilderInvoiced(voucherRow.Id, 'INV-1001', Date.today(), 5000);
        System.assertEquals(true, invoicedResult.success);

        ODLVoucherLifecycleService.ActionResult paidResult =
            ODLVoucherLifecycleService.markBuilderPaid(voucherRow.Id, Date.today());
        System.assertEquals(true, paidResult.success);

        ODLVoucherLifecycleService.ActionResult redeemedResult =
            ODLVoucherLifecycleService.markRedeemed(voucherRow.Id);
        System.assertEquals(true, redeemedResult.success);
        Test.stopTest();

        Voucher__c finalVoucher = [
            SELECT Status__c, Builder_Invoice_Status__c, Builder_Invoice_Number__c, Builder_Paid_Date__c,
                   Reserved_Opportunity__c, Redeemed_Quote__c, Voucher_Attach_Rate_Category__c,
                   Upsell_Outcome__c, Upsell_Revenue__c, Recommended_Upsells__c
            FROM Voucher__c
            WHERE Id = :voucherRow.Id
        ];
        System.assertEquals('Redeemed', finalVoucher.Status__c);
        System.assertEquals('Paid', finalVoucher.Builder_Invoice_Status__c);
        System.assertEquals('INV-1001', finalVoucher.Builder_Invoice_Number__c);
        System.assertEquals(oppRow.Id, finalVoucher.Reserved_Opportunity__c);
        System.assertEquals(quoteRow.Id, finalVoucher.Redeemed_Quote__c);
        System.assertEquals('Voucher + Package Upgrade', finalVoucher.Voucher_Attach_Rate_Category__c);
        System.assertEquals('Accepted', finalVoucher.Upsell_Outcome__c);
        System.assertEquals(2400, finalVoucher.Upsell_Revenue__c);
        System.assert(finalVoucher.Recommended_Upsells__c.contains('Retreat'));

        Voucher__c milestoneLinkedVoucher = [
            SELECT Payment_Milestone__c
            FROM Voucher__c
            WHERE Id = :voucherRow.Id
        ];
        System.assertEquals(depositRow.Id, milestoneLinkedVoucher.Payment_Milestone__c);

        CampaignMember memberRow = [
            SELECT Status
            FROM CampaignMember
            WHERE CampaignId = :campaignRow.Id AND LeadId = :leadRow.Id
            LIMIT 1
        ];
        System.assertEquals('Closed Won', memberRow.Status);
    }

    @IsTest
    static void testRedeemBlockedBeforePayment() {
        Account builder = [SELECT Id FROM Account WHERE Name = 'Lennar Test Builder' LIMIT 1];
        Product2 entitlement = [SELECT Id FROM Product2 WHERE Name = 'Standard Grilling Island' LIMIT 1];
        Campaign campaignRow = new Campaign(
            Name = 'Voucher Redeem Guard Campaign',
            Builder_Account__c = builder.Id,
            Offer_Description__c = 'Redeem Guard'
        );
        insert campaignRow;
        Account homeowner = new Account(Name = 'Redeem Guard Homeowner');
        insert homeowner;
        Contact homeownerContact = new Contact(
            LastName = 'Redeem Guard Contact',
            Email = 'redeem-guard@example.com',
            AccountId = homeowner.Id
        );
        insert homeownerContact;
        Opportunity oppRow = new Opportunity(
            Name = 'Redeem Guard Opportunity',
            AccountId = homeowner.Id,
            StageName = 'Contract Signed',
            CloseDate = Date.today().addDays(10),
            Type = 'UMB',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert oppRow;
        Quote quoteRow = new Quote(
            Name = 'Redeem Guard Quote',
            OpportunityId = oppRow.Id,
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert quoteRow;
        Lot__c testLot = [SELECT Id FROM Lot__c WHERE Lot_Number__c = 'VT-LOT-001' LIMIT 1];
        Voucher__c voucherRow = new Voucher__c(
            Voucher_Code__c = 'LENNAR-TEST-002',
            Status__c = 'Applied to Quote',
            Voucher_Type__c = 'Standard Grilling Island',
            Builder_Account__c = builder.Id,
            Campaign__c = campaignRow.Id,
            Reserved_Opportunity__c = oppRow.Id,
            Redeemed_Quote__c = quoteRow.Id,
            Contact__c = homeownerContact.Id,
            Eligible_Product__c = entitlement.Id,
            Lot__c = testLot.Id
        );
        insert voucherRow;

        Test.startTest();
        try {
            update new Voucher__c(Id = voucherRow.Id, Status__c = 'Redeemed');
            System.assert(false, 'Expected validation exception');
        } catch (DmlException expected) {
            System.assert(expected.getMessage().contains('Builder payment must be completed'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testCampaignStatusAndQuoteDeleteResync() {
        Account builder = [SELECT Id FROM Account WHERE Name = 'Lennar Test Builder' LIMIT 1];
        Product2 entitlement = [SELECT Id FROM Product2 WHERE Name = 'Standard Grilling Island' LIMIT 1];
        PricebookEntry entitlementPbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :entitlement.Id LIMIT 1];

        Campaign campaignRow = new Campaign(
            Name = 'Voucher Status Coverage Campaign',
            Builder_Account__c = builder.Id,
            Offer_Description__c = 'Coverage'
        );
        insert campaignRow;

        Lead leadRow = new Lead(
            LastName = 'Coverage Lead',
            Company = 'Homeowner',
            Email = 'coverage-lead@example.com',
            LeadSource = 'Lennar Voucher',
            Status = 'New'
        );
        insert leadRow;

        Contact leadContact = new Contact(
            LastName = 'Coverage Lead Contact',
            Email = 'coverage-lead@example.com',
            AccountId = builder.Id
        );
        insert leadContact;

        Voucher__c voucherRow = new Voucher__c(
            Voucher_Code__c = 'LENNAR-TEST-003',
            Status__c = 'Active',
            Voucher_Type__c = 'Standard Grilling Island',
            Voucher_Entitlement__c = 'Standard Grilling Island',
            Builder_Account__c = builder.Id,
            Contact__c = leadContact.Id,
            Eligible_Product__c = entitlement.Id
        );
        insert voucherRow;

        ODLVoucherLifecycleService.submitVoucherForLead(leadRow.Id, campaignRow.Id, 'LENNAR-TEST-003');
        Lot__c testLot = [SELECT Id FROM Lot__c WHERE Lot_Number__c = 'VT-LOT-001' LIMIT 1];
        update new Voucher__c(Id = voucherRow.Id, Lot__c = testLot.Id);
        ODLVoucherLifecycleService.validateVoucher(voucherRow.Id);

        Account homeowner = new Account(Name = 'Coverage Homeowner');
        insert homeowner;
        Opportunity oppRow = new Opportunity(
            Name = 'Coverage Opportunity',
            AccountId = homeowner.Id,
            StageName = 'Consultation Scheduled',
            CloseDate = Date.today().addDays(15),
            Type = 'UMB',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert oppRow;

        ODLVoucherLifecycleService.reserveVoucher(voucherRow.Id, oppRow.Id);

        Quote quoteRow = new Quote(
            Name = 'Coverage Quote',
            OpportunityId = oppRow.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Voucher__c = voucherRow.Id,
            Voucher_Credit_Amount__c = 5000
        );
        insert quoteRow;

        QuoteLineItem entitlementLine = new QuoteLineItem(
            QuoteId = quoteRow.Id,
            PricebookEntryId = entitlementPbe.Id,
            Quantity = 1,
            UnitPrice = 5000
        );
        insert entitlementLine;
        delete entitlementLine;
        undelete entitlementLine;

        Voucher__c finalVoucher = [
            SELECT Status__c, Voucher_Attach_Rate_Category__c, Upsell_Outcome__c
            FROM Voucher__c
            WHERE Id = :voucherRow.Id
        ];
        System.assertEquals('Applied to Quote', finalVoucher.Status__c);
        System.assertEquals('Voucher Only', finalVoucher.Voucher_Attach_Rate_Category__c);
        System.assertEquals('Presented', finalVoucher.Upsell_Outcome__c);
    }

    @IsTest
    static void testReserveVoucherUsesSecondaryHouseholdContactFallback() {
        Account builder = [SELECT Id FROM Account WHERE Name = 'Lennar Test Builder' LIMIT 1];
        Product2 entitlement = [SELECT Id FROM Product2 WHERE Name = 'Standard Grilling Island' LIMIT 1];
        Campaign campaignRow = new Campaign(
            Name = 'Secondary Household Voucher Campaign',
            Builder_Account__c = builder.Id,
            Offer_Description__c = 'Secondary Contact Coverage'
        );
        insert campaignRow;
        Voucher__c voucherRow = new Voucher__c(
            Voucher_Code__c = 'LENNAR-TEST-SECONDARY',
            Status__c = 'Active',
            Voucher_Type__c = 'Standard Grilling Island',
            Voucher_Entitlement__c = 'Standard Grilling Island',
            Builder_Account__c = builder.Id,
            Campaign__c = campaignRow.Id,
            Eligible_Product__c = entitlement.Id
        );
        insert voucherRow;

        Account homeowner = new Account(Name = 'Smith Household', Type = 'Homeowner');
        insert homeowner;

        Contact spouse = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@example.com',
            AccountId = homeowner.Id
        );
        insert spouse;

        homeowner.ODL_Secondary_Contact__c = spouse.Id;
        update homeowner;

        Opportunity oppRow = new Opportunity(
            Name = 'Smith Household UMB Opportunity',
            AccountId = homeowner.Id,
            StageName = 'Consultation Scheduled',
            CloseDate = Date.today().addDays(15),
            Type = 'UMB',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert oppRow;

        Lot__c testLot = [SELECT Id FROM Lot__c WHERE Lot_Number__c = 'VT-LOT-001' LIMIT 1];
        update new Voucher__c(Id = voucherRow.Id, Lot__c = testLot.Id);

        Test.startTest();
        ODLVoucherLifecycleService.ActionResult reserveResult =
            ODLVoucherLifecycleService.reserveVoucher(voucherRow.Id, oppRow.Id);
        Test.stopTest();

        Voucher__c storedVoucher = [
            SELECT Contact__c
            FROM Voucher__c
            WHERE Id = :voucherRow.Id
        ];
        System.assertEquals(true, reserveResult.success);
        System.assertEquals(spouse.Id, storedVoucher.Contact__c);
    }
}