@IsTest
private class ODLVoucherIdentityAndWorkspaceListTest {
    @TestSetup
    static void setupData() {
        Account builder = new Account(Name = 'Lennar Workspace Builder');
        insert builder;

        Account homeowner = new Account(Name = 'Workspace Homeowner', Type = 'Homeowner');
        insert homeowner;

        Contact homeownerContact = new Contact(
            FirstName = 'Wendy',
            LastName = 'Homeowner',
            Email = 'wendy.homeowner@example.com',
            AccountId = homeowner.Id
        );
        insert homeownerContact;

        Product2 grill = new Product2(
            Name = 'Standard Grilling Island',
            Family = 'Standard Grilling Island',
            IsActive = true
        );
        insert grill;

        Id standardPricebookId = Test.getStandardPricebookId();
        insert new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = grill.Id,
            UnitPrice = 5000,
            IsActive = true
        );

        Campaign campaignRow = new Campaign(
            Name = 'Lennar Voucher Workspace Campaign',
            Status = 'In Progress',
            Type = 'Website Direct',
            Builder_Account__c = builder.Id,
            Offer_Description__c = 'Standard Grill Offer'
        );
        insert campaignRow;

        Community__c communityRow = new Community__c(Name = 'Workspace Community');
        Map<String, Schema.SObjectField> communityFields = Schema.SObjectType.Community__c.fields.getMap();
        if (communityFields.containsKey('Builder_Account__c')) {
            communityRow.Builder_Account__c = builder.Id;
        }
        if (communityFields.containsKey('Community_Address__c')) {
            communityRow.put('Community_Address__c', '100 Voucher Lane');
        }
        if (communityFields.containsKey('Community_City__c')) {
            communityRow.put('Community_City__c', 'Charlotte');
        }
        if (communityFields.containsKey('Community_State__c')) {
            communityRow.put('Community_State__c', 'NC');
        }
        if (communityFields.containsKey('Community_Zip__c')) {
            communityRow.put('Community_Zip__c', '28202');
        }
        insert communityRow;

        Lot__c lotRow = new Lot__c(
            Name = 'Lot 44',
            Community__c = communityRow.Id
        );
        insert lotRow;

        Opportunity oppRow = new Opportunity(
            Name = 'Workspace Opportunity',
            AccountId = homeowner.Id,
            StageName = 'Contract Signed',
            CloseDate = Date.today().addDays(30),
            Type = 'UpgradeMyBackyard',
            BMG_Package__c = 'Entertainer',
            CampaignId = campaignRow.Id,
            Pricebook2Id = standardPricebookId
        );
        insert oppRow;

        insert new OpportunityContactRole(
            OpportunityId = oppRow.Id,
            ContactId = homeownerContact.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );

        Homeowner_Property__c propertyRow = new Homeowner_Property__c(
            Name = '100 Voucher Lane',
            Homeowner_Account__c = homeowner.Id,
            Opportunity__c = oppRow.Id,
            Community__c = communityRow.Id,
            Lot__c = lotRow.Id
        );
        insert propertyRow;

        Voucher__c voucherRow = new Voucher__c(
            Voucher_Code__c = 'LENNAR-WORK001',
            Status__c = 'Applied to Quote',
            Voucher_Type__c = 'Standard Grilling Island',
            Voucher_Entitlement__c = 'Standard Grilling Island',
            Campaign__c = campaignRow.Id,
            Builder_Account__c = builder.Id,
            Reserved_Opportunity__c = oppRow.Id,
            Contact__c = homeownerContact.Id,
            Homeowner_Property__c = propertyRow.Id,
            Community__c = communityRow.Id,
            Lot__c = lotRow.Id,
            Voucher_Face_Value__c = 5000,
            Builder_Invoice_Status__c = 'Pending',
            Eligible_Product__c = grill.Id
        );
        insert voucherRow;

        Quote quoteRow = new Quote(
            Name = 'Workspace Quote',
            OpportunityId = oppRow.Id,
            Pricebook2Id = standardPricebookId,
            Voucher__c = voucherRow.Id,
            Voucher_Credit_Amount__c = 5000,
            Status = 'Draft'
        );
        insert quoteRow;

    }

    @IsTest
    static void testHydrateAndValidatePopulatesClaimIdentity() {
        Campaign campaignRow = [SELECT Id FROM Campaign WHERE Name = 'Lennar Voucher Workspace Campaign' LIMIT 1];
        Account homeowner = [SELECT Id FROM Account WHERE Name = 'Workspace Homeowner' LIMIT 1];
        Contact homeownerContact = [SELECT Id FROM Contact WHERE Email = 'wendy.homeowner@example.com' LIMIT 1];
        Community__c communityRow = [SELECT Id FROM Community__c WHERE Name = 'Workspace Community' LIMIT 1];
        Id standardPricebookId = Test.getStandardPricebookId();

        Lot__c lotRow = new Lot__c(
            Name = 'Lot 45',
            Community__c = communityRow.Id
        );
        insert lotRow;

        Opportunity oppRow = new Opportunity(
            Name = 'Workspace Opportunity Two',
            AccountId = homeowner.Id,
            StageName = 'Contract Signed',
            CloseDate = Date.today().addDays(45),
            Type = 'UpgradeMyBackyard',
            BMG_Package__c = 'Signature',
            CampaignId = campaignRow.Id,
            Pricebook2Id = standardPricebookId
        );
        insert oppRow;

        insert new OpportunityContactRole(
            OpportunityId = oppRow.Id,
            ContactId = homeownerContact.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );

        insert new Homeowner_Property__c(
            Name = '101 Voucher Lane',
            Homeowner_Account__c = homeowner.Id,
            Opportunity__c = oppRow.Id,
            Community__c = communityRow.Id,
            Lot__c = lotRow.Id
        );

        Voucher__c candidate = new Voucher__c(
            Voucher_Code__c = 'LENNAR-HYDRATE1',
            Status__c = 'Validated',
            Voucher_Type__c = 'Standard Grilling Island',
            Voucher_Entitlement__c = 'Standard Grilling Island',
            Campaign__c = campaignRow.Id,
            Reserved_Opportunity__c = oppRow.Id
        );

        Test.startTest();
        ODLVoucherIdentityService.hydrateAndValidate(new List<Voucher__c>{ candidate }, null);
        Test.stopTest();

        System.assertEquals(false, candidate.hasErrors(), 'Candidate voucher should hydrate without validation errors.');
        System.assertNotEquals(null, candidate.Contact__c);
        System.assertNotEquals(null, candidate.Homeowner_Property__c);
        System.assertNotEquals(null, candidate.Community__c);
        System.assertNotEquals(null, candidate.Lot__c);
        System.assertNotEquals(null, candidate.Builder_Account__c);
        System.assertEquals(5000, candidate.Voucher_Face_Value__c);
    }

    @IsTest
    static void testDuplicateLotVoucherGetsBlocked() {
        Campaign campaignRow = [SELECT Id FROM Campaign WHERE Name = 'Lennar Voucher Workspace Campaign' LIMIT 1];
        Opportunity oppRow = [SELECT Id FROM Opportunity WHERE Name = 'Workspace Opportunity' LIMIT 1];

        Voucher__c duplicateCandidate = new Voucher__c(
            Voucher_Code__c = 'LENNAR-DUPE001',
            Status__c = 'Validated',
            Voucher_Type__c = 'Standard Grilling Island',
            Voucher_Entitlement__c = 'Standard Grilling Island',
            Campaign__c = campaignRow.Id,
            Reserved_Opportunity__c = oppRow.Id
        );

        Test.startTest();
        ODLVoucherIdentityService.hydrateAndValidate(new List<Voucher__c>{ duplicateCandidate }, null);
        Test.stopTest();

        System.assertEquals('LENNAR-DUPE001', duplicateCandidate.Voucher_Code__c);
    }

    @IsTest
    static void testHydrateForServiceUsesCampaignBuilderAndFallbackValue() {
        Campaign campaignRow = [SELECT Id, Builder_Account__c FROM Campaign WHERE Name = 'Lennar Voucher Workspace Campaign' LIMIT 1];

        Voucher__c candidate = new Voucher__c(
            Voucher_Code__c = 'LENNAR-SERVICE1',
            Status__c = 'Draft',
            Voucher_Type__c = 'Deluxe Grilling Island Upgrade',
            Campaign__c = campaignRow.Id
        );

        Test.startTest();
        ODLVoucherIdentityService.hydrateForService(candidate);
        Test.stopTest();

        System.assertEquals(campaignRow.Builder_Account__c, candidate.Builder_Account__c);
        System.assertEquals(5000, candidate.Voucher_Face_Value__c);
    }

    @IsTest
    static void testWorkspaceDataForAllSurfaces() {
        Test.startTest();
        ODLWorkspaceListController.WorkspaceData voucherData = ODLWorkspaceListController.getWorkspaceData('voucher');
        ODLWorkspaceListController.WorkspaceData campaignData = ODLWorkspaceListController.getWorkspaceData('campaign');
        ODLWorkspaceListController.WorkspaceData quoteData = ODLWorkspaceListController.getWorkspaceData('quote');
        ODLWorkspaceListController.WorkspaceData workOrderData = ODLWorkspaceListController.getWorkspaceData('workorder');
        Test.stopTest();

        System.assertEquals('Voucher Workspace', voucherData.title);
        System.assertEquals(false, voucherData.rows.isEmpty());
        System.assertEquals('Campaign Workspace', campaignData.title);
        System.assertEquals(false, campaignData.rows.isEmpty());
        System.assertEquals('Quote Workspace', quoteData.title);
        System.assertEquals(false, quoteData.rows.isEmpty());
        System.assertEquals('Work Order Workspace', workOrderData.title);
        System.assertNotEquals(null, workOrderData.rows);
    }

    @IsTest
    static void testUnsupportedWorkspaceThrowsHandledException() {
        Boolean caught = false;
        try {
            ODLWorkspaceListController.getWorkspaceData('unknown');
            System.assert(false, 'Expected unsupported workspace exception.');
        } catch (AuraHandledException expected) {
            caught = true;
        }
        System.assertEquals(true, caught);
    }
}