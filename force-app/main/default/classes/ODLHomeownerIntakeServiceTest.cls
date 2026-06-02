@IsTest
private class ODLHomeownerIntakeServiceTest {
    @IsTest
    static void createsUmbOpportunityWithVoucherAndDownstreamRecords() {
        Account builder = new Account(Name = 'ODL Sponsor');
        insert builder;
        Product2 grill = new Product2(Name = 'ODL Intake Grill', IsActive = true);
        insert grill;

        Campaign campaignRow = new Campaign(
            Name = 'ODL Intake Campaign',
            Type = 'Builder-Sponsored Voucher',
            Status = 'In Progress',
            Builder_Account__c = builder.Id
        );
        insert campaignRow;

        Voucher__c voucherRow = new Voucher__c(
            Voucher_Code__c = 'INTAKE-001',
            Status__c = 'Active',
            Voucher_Type__c = 'Standard Grilling Island',
            Campaign__c = campaignRow.Id,
            Builder_Account__c = builder.Id,
            Eligible_Product__c = grill.Id
        );
        insert voucherRow;

        Map<String, String> leadData = new Map<String, String>{
            'FirstName' => 'Casey',
            'LastName' => 'Hartwell',
            'Email' => 'casey.hartwell@example.com',
            'Phone' => '555-1212',
            'Street' => '123 Garden Walk',
            'City' => 'Charlotte',
            'State' => 'NC',
            'PostalCode' => '28202',
            'SMSConsent' => 'true'
        };

        String leadId = ODLHomeownerIntakeService.createLead(leadData, 'Web - Design Form', UserInfo.getUserId());
        Map<String, Object> oppData = new Map<String, Object>{
            'timeline' => '30 Days',
            'budget' => '$10,000',
            'description' => 'Outdoor kitchen refresh',
            'couponCode' => 'INTAKE-001'
        };

        Test.startTest();
        String oppId = ODLHomeownerIntakeService.createUpgradeMyBackyardOpportunity(leadId, oppData, UserInfo.getUserId());
        Test.stopTest();

        Opportunity oppRow = [
            SELECT Id, Name, Type, RecordType.DeveloperName, CampaignId, AccountId, ContactId, Source_Lead__c
            FROM Opportunity
            WHERE Id = :oppId
        ];
        System.assertEquals('UpgradeMyBackyard', oppRow.Type);
        System.assertEquals('UMB', oppRow.RecordType.DeveloperName);
        System.assertEquals(campaignRow.Id, oppRow.CampaignId);
        System.assertEquals(leadId, oppRow.Source_Lead__c);
        Lead convertedLead = [SELECT IsConverted, ConvertedOpportunityId FROM Lead WHERE Id = :leadId];
        System.assertEquals(true, convertedLead.IsConverted);
        System.assertEquals(null, convertedLead.ConvertedOpportunityId, 'Native ConvertedOpportunityId remains null because LOVING suppresses native Opportunity creation and links attribution through Opportunity.Source_Lead__c.');

        Account household = [
            SELECT Id, Name, ODL_Household_Display_Name__c, BillingStreet
            FROM Account
            WHERE Id = :oppRow.AccountId
        ];
        System.assertEquals('Hartwell - 123 Garden Walk', household.Name);
        System.assertEquals('Hartwell - 123 Garden Walk', household.ODL_Household_Display_Name__c);

        System.assert(
            [SELECT COUNT() FROM Homeowner_Property__c WHERE Opportunity__c = :oppRow.Id AND Homeowner_Account__c = :oppRow.AccountId] > 0,
            'Expected at least one homeowner property linked to the opportunity and household account.'
        );
        System.assert(
            [SELECT COUNT() FROM Design_Review__c WHERE Opportunity__c = :oppRow.Id AND Status__c = 'Draft'] > 0,
            'Expected at least one draft design review linked to the opportunity.'
        );
        System.assert(
            [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :campaignRow.Id AND (ContactId = :oppRow.ContactId OR LeadId = :leadId)] > 0,
            'Expected at least one campaign member linked to the lead or homeowner contact.'
        );

        Voucher__c refreshedVoucher = [
            SELECT Reserved_Opportunity__c, Homeowner_Lead__c, Contact__c
            FROM Voucher__c
            WHERE Id = :voucherRow.Id
        ];
        System.assertEquals(oppRow.Id, refreshedVoucher.Reserved_Opportunity__c);
        System.assertEquals(leadId, refreshedVoucher.Homeowner_Lead__c);
        System.assertEquals(oppRow.ContactId, refreshedVoucher.Contact__c);
    }

    @IsTest
    static void blocksUnresolvedDuplicatePropertyAndAllowsExplicitReuse() {
        Account existing = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Existing',
            PersonEmail = 'existing@example.com',
            BillingStreet = '999 Shared St',
            BillingCity = 'Charlotte',
            BillingState = 'NC',
            BillingPostalCode = '28277',
            Type = 'Home Owner'
        );
        insert existing;

        Map<String, String> leadData = new Map<String, String>{
            'FirstName' => 'Jamie',
            'LastName' => 'Newowner',
            'Email' => 'jamie.newowner@example.com',
            'Phone' => '555-7777',
            'Street' => '999 Shared St',
            'City' => 'Charlotte',
            'State' => 'NC',
            'PostalCode' => '28277',
            'SMSConsent' => 'false'
        };

        try {
            ODLHomeownerIntakeService.createLead(leadData, 'Web - Design Form', UserInfo.getUserId());
            System.assert(false, 'Expected duplicate-property warning.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex);
        }

        leadData.put('householdDecision', 'SAME_HOUSEHOLD');
        leadData.put('existingAccountId', existing.Id);
        String leadId = ODLHomeownerIntakeService.createLead(leadData, 'Web - Design Form', UserInfo.getUserId());
        System.assertNotEquals(null, leadId);
    }

    @IsTest
    static void appliesVoucherToExistingOpportunityAndBackfillsCampaign() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Account builder = new Account(Name = 'ODL Voucher Apply Builder');
        insert builder;
        Product2 grill = new Product2(Name = 'ODL Apply Grill', IsActive = true);
        insert grill;
        Campaign campaignRow = new Campaign(
            Name = 'ODL Voucher Apply Campaign',
            Type = 'Builder-Sponsored Voucher',
            Status = 'In Progress',
            Builder_Account__c = builder.Id
        );
        insert campaignRow;
        Voucher__c voucherRow = new Voucher__c(
            Voucher_Code__c = 'APPLY-001',
            Status__c = 'Active',
            Voucher_Type__c = 'Standard Grilling Island',
            Campaign__c = campaignRow.Id,
            Builder_Account__c = builder.Id,
            Eligible_Product__c = grill.Id
        );
        insert voucherRow;

        Account homeowner = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Apply Voucher',
            PersonEmail = 'apply-voucher@example.com',
            Type = 'Home Owner'
        );
        insert homeowner;
        Account homeownerWithContact = [SELECT Id, PersonContactId FROM Account WHERE Id = :homeowner.Id];
        update new Contact(
            Id = homeownerWithContact.PersonContactId,
            Phone = '555-200-1000'
        );

        Opportunity oppRow = new Opportunity(
            Name = 'ODL Voucher Apply Opportunity',
            AccountId = homeowner.Id,
            ContactId = homeownerWithContact.PersonContactId,
            StageName = 'Quote Requested',
            CloseDate = Date.today().addDays(30),
            LeadSource = 'Web - Design Form',
            Type = 'UpgradeMyBackyard',
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('UMB').getRecordTypeId(),
            Pricebook2Id = standardPricebookId
        );
        insert oppRow;
        insert new OpportunityContactRole(
            OpportunityId = oppRow.Id,
            ContactId = homeownerWithContact.PersonContactId,
            IsPrimary = true,
            Role = 'Decision Maker'
        );

        Test.startTest();
        ODLHomeownerIntakeService.applyVoucherToOpportunity(oppRow.Id, 'APPLY-001');
        Test.stopTest();

        Voucher__c refreshedVoucher = [
            SELECT Reserved_Opportunity__c, Contact__c
            FROM Voucher__c
            WHERE Id = :voucherRow.Id
        ];
        Opportunity refreshedOpp = [SELECT CampaignId FROM Opportunity WHERE Id = :oppRow.Id];
        System.assertEquals(oppRow.Id, refreshedVoucher.Reserved_Opportunity__c);
        System.assertEquals(homeownerWithContact.PersonContactId, refreshedVoucher.Contact__c);
        System.assertEquals(campaignRow.Id, refreshedOpp.CampaignId);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :campaignRow.Id AND ContactId = :homeownerWithContact.PersonContactId]
        );
    }

    @IsTest
    static void createsDesignBuildOpportunityAndSavesConsultationDates() {
        Map<String, String> leadData = new Map<String, String>{
            'FirstName' => 'Dana',
            'LastName' => 'DesignBuild',
            'Email' => 'dana.designbuild@example.com',
            'Phone' => '555-4455',
            'Street' => '789 Patio Place',
            'City' => 'Charlotte',
            'State' => 'NC',
            'PostalCode' => '28203',
            'SMSConsent' => 'true'
        };

        String leadId = ODLHomeownerIntakeService.createLead(leadData, 'Web - Design Form', UserInfo.getUserId());
        List<Object> consultationDates = new List<Object>{
            new Map<String, Object>{ 'utcDateTime' => '2026-06-01T15:00:00Z' },
            new Map<String, Object>{ 'date' => '2026-06-02', 'time' => '16:30' }
        };
        Map<String, Object> oppData = new Map<String, Object>{
            'timeline' => '60 Days',
            'budget' => '$25,000',
            'description' => 'Full backyard redesign',
            'consultationDates' => consultationDates
        };

        Test.startTest();
        String oppId = ODLHomeownerIntakeService.createDesignBuildOpportunity(leadId, oppData, UserInfo.getUserId());
        Test.stopTest();

        Opportunity oppRow = [
            SELECT Id, Type, RecordType.DeveloperName, Consultation_Date_1__c, Consultation_Date_2__c
            FROM Opportunity
            WHERE Id = :oppId
        ];
        System.assertEquals('Design Build', oppRow.Type);
        System.assertEquals('Design_Build', oppRow.RecordType.DeveloperName);
        System.assertNotEquals(null, oppRow.Consultation_Date_1__c);
        System.assertNotEquals(null, oppRow.Consultation_Date_2__c);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Design_Review__c WHERE Opportunity__c = :oppRow.Id AND Status__c = 'Draft']
        );
    }

    @IsTest
    static void updateLeadPersistsEditsForUnconvertedLead() {
        Map<String, String> leadData = new Map<String, String>{
            'FirstName' => 'Avery',
            'LastName' => 'Editable',
            'Email' => 'avery.editable@example.com',
            'Phone' => '555-8181',
            'Street' => '55 Update Lane',
            'City' => 'Charlotte',
            'State' => 'NC',
            'PostalCode' => '28204',
            'SMSConsent' => 'false'
        };

        String leadId = ODLHomeownerIntakeService.createLead(leadData, 'Web - Design Form', UserInfo.getUserId());
        Map<String, String> updated = new Map<String, String>(leadData);
        updated.put('Phone', '555-9191');
        updated.put('Street', '77 Update Lane');
        updated.put('SMSConsent', 'true');

        Test.startTest();
        String returnedLeadId = ODLHomeownerIntakeService.updateLead(leadId, updated);
        Test.stopTest();

        Lead refreshed = [SELECT Id, Phone, Street, SMS_Consent__c FROM Lead WHERE Id = :leadId];
        System.assertEquals(leadId, returnedLeadId);
        System.assertEquals('555-9191', refreshed.Phone);
        System.assertEquals('77 Update Lane', refreshed.Street);
        System.assertEquals(true, refreshed.SMS_Consent__c);
    }
}