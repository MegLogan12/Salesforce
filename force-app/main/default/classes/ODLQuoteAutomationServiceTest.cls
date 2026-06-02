@IsTest
private class ODLQuoteAutomationServiceTest {
    @IsTest
    static void createsDefaultFiftyFiftyMilestones() {
        Id standardPricebookId = Test.getStandardPricebookId();
        Product2 productRow = new Product2(Name = 'ODL Package', Family = 'Outdoor Living', IsActive = true);
        insert productRow;
        insert new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = productRow.Id, UnitPrice = 4000, IsActive = true);

        Account homeowner = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Milestone',
            PersonEmail = 'milestone@example.com',
            Type = 'Home Owner'
        );
        insert homeowner;

        Opportunity oppRow = new Opportunity(
            Name = 'ODL Milestone Opportunity',
            AccountId = homeowner.Id,
            StageName = 'Quote Requested',
            CloseDate = Date.today().addDays(30),
            Type = 'UpgradeMyBackyard',
            Pricebook2Id = standardPricebookId
        );
        insert oppRow;

        Quote quoteRow = new Quote(Name = 'Milestone Quote', OpportunityId = oppRow.Id, Pricebook2Id = standardPricebookId, Status = 'Draft');
        insert quoteRow;
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :productRow.Id LIMIT 1];
        insert new QuoteLineItem(QuoteId = quoteRow.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 4000);
        Test.startTest();
        ODLQuoteAutomationService.afterUpsert(
            new List<Quote>{ [SELECT Id FROM Quote WHERE Id = :quoteRow.Id] },
            new Map<Id, Quote>()
        );
        Test.stopTest();

        List<Payment_Milestone__c> milestones = [
            SELECT Type__c, Status__c, Amount__c
            FROM Payment_Milestone__c
            WHERE Quote__c = :quoteRow.Id
            ORDER BY Type__c
        ];
        System.assertEquals(2, milestones.size());
        System.assertEquals('Deposit', milestones[0].Type__c);
        System.assertEquals('Not Sent', milestones[0].Status__c);
        System.assertEquals(2000, milestones[0].Amount__c);
    }

    @IsTest
    static void appliesAutomationForUmbOpportunityType() {
        Id standardPricebookId = Test.getStandardPricebookId();
        Product2 productRow = new Product2(Name = 'ODL UMB Package', Family = 'Outdoor Living', IsActive = true);
        insert productRow;
        insert new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = productRow.Id, UnitPrice = 4200, IsActive = true);

        Account homeowner = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Umb Milestone',
            PersonEmail = 'umb-milestone@example.com',
            Type = 'Home Owner'
        );
        insert homeowner;

        Opportunity oppRow = new Opportunity(
            Name = 'ODL UMB Opportunity',
            AccountId = homeowner.Id,
            StageName = 'Quote Requested',
            CloseDate = Date.today().addDays(30),
            Type = 'UMB',
            Pricebook2Id = standardPricebookId
        );
        insert oppRow;

        Quote quoteRow = new Quote(Name = 'UMB Quote', OpportunityId = oppRow.Id, Pricebook2Id = standardPricebookId, Status = 'Draft');
        insert quoteRow;
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :productRow.Id LIMIT 1];
        insert new QuoteLineItem(QuoteId = quoteRow.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 4200);
        Test.startTest();
        ODLQuoteAutomationService.afterUpsert(
            new List<Quote>{ [SELECT Id FROM Quote WHERE Id = :quoteRow.Id] },
            new Map<Id, Quote>()
        );
        Test.stopTest();

        List<Payment_Milestone__c> milestones = [
            SELECT Type__c, Status__c, Amount__c
            FROM Payment_Milestone__c
            WHERE Quote__c = :quoteRow.Id
            ORDER BY Type__c
        ];
        System.assertEquals(2, milestones.size());
        System.assertEquals('Deposit', milestones[0].Type__c);
        System.assertEquals('Not Sent', milestones[0].Status__c);
        System.assertEquals(2100, milestones[0].Amount__c);
    }

    @IsTest
    static void appliesZeroDollarVoucherException() {
        Id standardPricebookId = Test.getStandardPricebookId();
        Product2 productRow = new Product2(Name = 'Grilling Island - Standard', ProductCode = 'GI-STD', Family = 'Grilling Island', IsActive = true);
        insert productRow;
        insert new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = productRow.Id, UnitPrice = 5000, IsActive = true);

        Account builder = new Account(Name = 'Voucher Builder');
        insert builder;
        Campaign campaignRow = new Campaign(Name = 'Voucher Campaign', Type = 'Builder-Sponsored Voucher', Status = 'In Progress', Builder_Account__c = builder.Id);
        insert campaignRow;
        Voucher__c voucherRow = new Voucher__c(
            Voucher_Code__c = 'ZERO-001',
            Status__c = 'Active',
            Voucher_Type__c = 'Standard Grilling Island',
            Campaign__c = campaignRow.Id,
            Builder_Account__c = builder.Id,
            Voucher_Face_Value__c = 5000,
            Builder_Invoice_Status__c = 'Pending'
        );
        insert voucherRow;

        Account homeowner = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Zero Household',
            PersonEmail = 'zero@example.com',
            Type = 'Home Owner'
        );
        insert homeowner;
        Account homeownerWithContact = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :homeowner.Id
        ];
        Contact homeownerContact = [
            SELECT Id, Email
            FROM Contact
            WHERE Id = :homeownerWithContact.PersonContactId
        ];

        Opportunity oppRow = new Opportunity(
            Name = 'UAT - DO NOT SEND Zero-Dollar Opportunity',
            AccountId = homeowner.Id,
            ContactId = homeownerContact.Id,
            StageName = 'Contract Signed',
            CloseDate = Date.today().addDays(30),
            Type = 'UpgradeMyBackyard',
            Pricebook2Id = standardPricebookId,
            Suppress_Automation_For_UAT__c = true
        );
        insert oppRow;
        insert new OpportunityContactRole(
            OpportunityId = oppRow.Id,
            ContactId = homeownerContact.Id,
            IsPrimary = true,
            Role = 'Decision Maker'
        );

        Quote quoteRow = new Quote(Name = 'Zero-Dollar Quote', OpportunityId = oppRow.Id, Pricebook2Id = standardPricebookId, Status = 'Draft');
        insert quoteRow;
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :productRow.Id LIMIT 1];
        insert new QuoteLineItem(QuoteId = quoteRow.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 5000);
        Community__c zeroComm = new Community__c(Name = 'Zero Test Community', Builder_Account__c = builder.Id, Community_Status__c = 'Active');
        insert zeroComm;
        Lot__c zeroLot = new Lot__c(Lot_Number__c = 'ZD-LOT-001', Community__c = zeroComm.Id, Lot_Status__c = 'Open');
        insert zeroLot;

        quoteRow.Voucher__c = voucherRow.Id;
        quoteRow.Voucher_Credit_Amount__c = 5000;
        voucherRow.Contact__c = homeownerContact.Id;
        voucherRow.Lot__c = zeroLot.Id;
        update voucherRow;
        update quoteRow;
        Test.startTest();
        ODLQuoteAutomationService.afterUpsert(
            new List<Quote>{ [SELECT Id FROM Quote WHERE Id = :quoteRow.Id] },
            new Map<Id, Quote>()
        );
        Test.stopTest();

        Map<String, Payment_Milestone__c> milestonesByType = new Map<String, Payment_Milestone__c>();
        for (Payment_Milestone__c milestoneRow : [
            SELECT Type__c, Status__c, Amount__c, Exception_Approved__c
            FROM Payment_Milestone__c
            WHERE Quote__c = :quoteRow.Id
        ]) {
            milestonesByType.put(milestoneRow.Type__c, milestoneRow);
        }
        System.assertEquals('Paid', milestonesByType.get('Deposit').Status__c);
        System.assertEquals(0, milestonesByType.get('Deposit').Amount__c);
        System.assertEquals('Paid', milestonesByType.get('Final Payment').Status__c);
        System.assertEquals('Exception Approved', milestonesByType.get('Exception').Status__c);
        System.assertEquals(true, milestonesByType.get('Exception').Exception_Approved__c);

        Voucher__c updatedVoucher = [
            SELECT Status__c, Redeemed_Quote__c, Customer_Invoice_Amount__c, Customer_Paid_Upgrade_Amount__c
            FROM Voucher__c
            WHERE Id = :voucherRow.Id
        ];
        System.assertEquals('Applied to Quote', updatedVoucher.Status__c);
        System.assertEquals(quoteRow.Id, updatedVoucher.Redeemed_Quote__c);
        System.assertEquals(0, updatedVoucher.Customer_Invoice_Amount__c);
        System.assertEquals(0, updatedVoucher.Customer_Paid_Upgrade_Amount__c);
    }

    @IsTest
    static void appliesStandardCreditToDeluxeGrillDelta() {
        Id standardPricebookId = Test.getStandardPricebookId();
        Product2 productRow = new Product2(Name = 'Grilling Island - Deluxe', ProductCode = 'GI-DLX', Family = 'Grilling Island', IsActive = true);
        insert productRow;
        insert new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = productRow.Id, UnitPrice = 7501.01, IsActive = true);

        Account builder = new Account(Name = 'Voucher Builder Deluxe');
        insert builder;
        Campaign campaignRow = new Campaign(Name = 'Voucher Campaign Deluxe', Type = 'Builder-Sponsored Voucher', Status = 'In Progress', Builder_Account__c = builder.Id);
        insert campaignRow;
        Voucher__c voucherRow = new Voucher__c(
            Voucher_Code__c = 'DELUXE-001',
            Status__c = 'Active',
            Voucher_Type__c = 'Standard Grilling Island',
            Campaign__c = campaignRow.Id,
            Builder_Account__c = builder.Id,
            Voucher_Face_Value__c = 5535.44
        );
        insert voucherRow;

        Account homeowner = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Delta Household',
            PersonEmail = 'delta@example.com',
            Type = 'Home Owner'
        );
        insert homeowner;
        Account homeownerWithContact = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :homeowner.Id
        ];
        Contact homeownerContact = [
            SELECT Id
            FROM Contact
            WHERE Id = :homeownerWithContact.PersonContactId
        ];

        Opportunity oppRow = new Opportunity(
            Name = 'UAT - DO NOT SEND Deluxe-Delta Opportunity',
            AccountId = homeowner.Id,
            ContactId = homeownerContact.Id,
            StageName = 'Contract Signed',
            CloseDate = Date.today().addDays(30),
            Type = 'UpgradeMyBackyard',
            Pricebook2Id = standardPricebookId,
            Suppress_Automation_For_UAT__c = true
        );
        insert oppRow;
        insert new OpportunityContactRole(
            OpportunityId = oppRow.Id,
            ContactId = homeownerContact.Id,
            IsPrimary = true,
            Role = 'Decision Maker'
        );

        Quote quoteRow = new Quote(Name = 'Deluxe Delta Quote', OpportunityId = oppRow.Id, Pricebook2Id = standardPricebookId, Status = 'Draft');
        insert quoteRow;
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :productRow.Id LIMIT 1];
        insert new QuoteLineItem(QuoteId = quoteRow.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 7501.01);
        Community__c deluxeComm = new Community__c(Name = 'Deluxe Test Community', Builder_Account__c = builder.Id, Community_Status__c = 'Active');
        insert deluxeComm;
        Lot__c deluxeLot = new Lot__c(Lot_Number__c = 'DX-LOT-001', Community__c = deluxeComm.Id, Lot_Status__c = 'Open');
        insert deluxeLot;

        quoteRow.Voucher__c = voucherRow.Id;
        quoteRow.Voucher_Credit_Amount__c = 5535.44;
        voucherRow.Contact__c = homeownerContact.Id;
        voucherRow.Lot__c = deluxeLot.Id;
        update voucherRow;
        update quoteRow;
        Test.startTest();
        ODLQuoteAutomationService.afterUpsert(
            new List<Quote>{ [SELECT Id FROM Quote WHERE Id = :quoteRow.Id] },
            new Map<Id, Quote>()
        );
        Test.stopTest();

        Map<String, Payment_Milestone__c> milestonesByType = new Map<String, Payment_Milestone__c>();
        for (Payment_Milestone__c milestoneRow : [
            SELECT Type__c, Status__c, Amount__c
            FROM Payment_Milestone__c
            WHERE Quote__c = :quoteRow.Id
        ]) {
            milestonesByType.put(milestoneRow.Type__c, milestoneRow);
        }
        Decimal expectedDelta = 1965.57;
        System.assertEquals('Not Sent', milestonesByType.get('Deposit').Status__c);
        System.assertEquals((expectedDelta / 2).setScale(2), milestonesByType.get('Deposit').Amount__c);
        System.assertEquals((expectedDelta - (expectedDelta / 2).setScale(2)).setScale(2), milestonesByType.get('Final Payment').Amount__c);
        System.assertEquals(null, milestonesByType.get('Exception'));

        Voucher__c updatedVoucher = [
            SELECT Status__c, Redeemed_Quote__c, Customer_Invoice_Amount__c, Customer_Paid_Upgrade_Amount__c
            FROM Voucher__c
            WHERE Id = :voucherRow.Id
        ];
        System.assertEquals('Applied to Quote', updatedVoucher.Status__c);
        System.assertEquals(quoteRow.Id, updatedVoucher.Redeemed_Quote__c);
        System.assertEquals(expectedDelta, updatedVoucher.Customer_Invoice_Amount__c);
        System.assertEquals(expectedDelta, updatedVoucher.Customer_Paid_Upgrade_Amount__c);
    }
}