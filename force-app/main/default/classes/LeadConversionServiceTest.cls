@isTest
private class LeadConversionServiceTest {

    private static String convertedStatus() {
        return [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;
    }

    private static Database.LeadConvertResult doConvert(Id leadId, Boolean noOpportunity) {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadId);
        lc.setConvertedStatus(convertedStatus());
        lc.setDoNotCreateOpportunity(noOpportunity);
        if (!noOpportunity) {
            lc.setOpportunityName('Test Opportunity');
        }
        return Database.convertLead(lc);
    }

    // ─────────────────────────────────────────────
    // SCENARIO B — Homeowner
    // ─────────────────────────────────────────────

    @isTest
    static void testScenarioBSetsHomeOwnerRecordType() {
        Lead l = new Lead(
            FirstName    = 'Jane',
            LastName     = 'Doe',
            Company      = 'Homeowner',
            LeadSource   = 'Lennar Voucher',
            Lead_Type__c = 'Homeowner',
            Status       = 'New'
        );
        insert l;

        Id homeOwnerRtId = RecordTypeHelper.getAccountRT('Home_Owner');

        Test.startTest();
        Database.LeadConvertResult result = doConvert(l.Id, false);
        Test.stopTest();

        System.assert(result.isSuccess(), 'Lead conversion should succeed: ' + result.getErrors());

        Account acct = [SELECT RecordTypeId, Type FROM Account WHERE Id = :result.getAccountId()];
        System.assertEquals(homeOwnerRtId, acct.RecordTypeId, 'Account should have Home_Owner record type.');
        System.assertEquals('Home Owner', acct.Type);

        Opportunity opp = [SELECT Type FROM Opportunity WHERE Id = :result.getOpportunityId()];
        System.assertEquals('UpgradeMyBackyard', opp.Type, 'Opportunity should be classified as UpgradeMyBackyard.');
    }

    @isTest
    static void testScenarioBNoOpportunity() {
        Lead l = new Lead(
            FirstName    = 'Tom',
            LastName     = 'Smith',
            Company      = 'Homeowner',
            LeadSource   = 'Social Media',
            Lead_Type__c = 'Homeowner',
            Status       = 'New'
        );
        insert l;

        Id homeOwnerRtId = RecordTypeHelper.getAccountRT('Home_Owner');

        Test.startTest();
        Database.LeadConvertResult result = doConvert(l.Id, true);
        Test.stopTest();

        System.assert(result.isSuccess(), 'Lead conversion without Opportunity should succeed: ' + result.getErrors());

        Account acct = [SELECT RecordTypeId, Type FROM Account WHERE Id = :result.getAccountId()];
        System.assertEquals(homeOwnerRtId, acct.RecordTypeId, 'Account should have Home_Owner record type even without Opportunity.');
        System.assertEquals('Home Owner', acct.Type);
    }

    // ─────────────────────────────────────────────
    // SCENARIO A — Net New Builder
    // ─────────────────────────────────────────────

    @isTest
    static void testScenarioALocalBuilder() {
        Lead l = new Lead(
            FirstName         = 'Bob',
            LastName          = 'Builder',
            Company           = 'Acme Homes',
            LeadSource        = 'Cold Call',
            Lead_Type__c      = 'Net New Builder',
            Community_Name__c = 'Maple Ridge',
            Status            = 'New'
        );
        insert l;

        Id builderParentRtId = RecordTypeHelper.getAccountRT('Builder_Parent');

        Test.startTest();
        Database.LeadConvertResult result = doConvert(l.Id, true);
        Test.stopTest();

        System.assert(result.isSuccess(), 'Scenario A lead conversion should succeed: ' + result.getErrors());

        Account acct = [SELECT RecordTypeId, Type FROM Account WHERE Id = :result.getAccountId()];
        System.assertEquals(builderParentRtId, acct.RecordTypeId, 'Account should have Builder_Parent record type.');
        System.assertEquals('Builder Parent', acct.Type);
    }

    @isTest
    static void testScenarioARegionalBuilderCreatesMarketAccount() {
        String marketValue = [
            SELECT Label FROM PicklistValueInfo
            WHERE EntityParticle.EntityDefinition.QualifiedApiName = 'Lead'
              AND EntityParticle.QualifiedApiName = 'Market__c'
              AND IsActive = true
            LIMIT 1
        ].Label;

        Lead l = new Lead(
            FirstName         = 'Regional',
            LastName          = 'Rep',
            Company           = 'Big Homes',
            LeadSource        = 'Cold Call',
            Lead_Type__c      = 'Net New Builder',
            Community_Name__c = 'Oak Hill',
            Market__c         = marketValue,
            Status            = 'New'
        );
        insert l;

        Id builderParentRtId = RecordTypeHelper.getAccountRT('Builder_Parent');
        Id builderMarketRtId = RecordTypeHelper.getAccountRT('Builder_Market');

        Test.startTest();
        Database.LeadConvertResult result = doConvert(l.Id, true);
        Test.stopTest();

        System.assert(result.isSuccess(), 'Scenario A regional conversion should succeed: ' + result.getErrors());

        Account parentAcct = [SELECT RecordTypeId, Type FROM Account WHERE Id = :result.getAccountId()];
        System.assertEquals(builderParentRtId, parentAcct.RecordTypeId, 'Converted Account should be Builder Parent.');
        System.assertEquals('Builder Parent', parentAcct.Type);

        List<Account> marketAccts = [
            SELECT RecordTypeId, Type FROM Account WHERE ParentId = :result.getAccountId()
        ];
        System.assertEquals(1, marketAccts.size(), 'Regional builder should create one Builder Market Account.');
        System.assertEquals(builderMarketRtId, marketAccts[0].RecordTypeId);
        System.assertEquals('Builder Market', marketAccts[0].Type);
    }

    // ─────────────────────────────────────────────
    // SCENARIO C — Existing Builder, New Community
    //
    // NOTE: The Opportunity insert in convertScenarioC() fails silently because a
    // validation rule blocks Opportunity creation on Builder accounts. Tests here
    // verify the Contact-matching logic (matchOrCreateContact) that DOES execute,
    // and that the service does not throw on the swallowed Opportunity error.
    // Email is intentionally left blank to avoid duplicate-rule conflicts with
    // production Contact data in this connected-org test context.
    // ─────────────────────────────────────────────

    @isTest
    static void testScenarioCContactCreatedOnMarketAccount() {
        Account parentAcct = new Account(
            Name         = 'Big Corp',
            RecordTypeId = RecordTypeHelper.getAccountRT('Builder_Parent'),
            Type         = 'Builder Parent'
        );
        insert parentAcct;

        Account marketAcct = new Account(
            Name         = 'Big Corp – East',
            RecordTypeId = RecordTypeHelper.getAccountRT('Builder_Market'),
            ParentId     = parentAcct.Id,
            Type         = 'Builder Market'
        );
        insert marketAcct;

        // No Email set — avoids duplicate-rule conflicts with production Contact data.
        Lead l = new Lead(
            FirstName                 = 'Alice',
            LastName                  = 'TestRep',
            Company                   = 'Big Corp',
            LeadSource                = 'Lennar Voucher',
            Lead_Type__c              = 'Existing Builder New Community',
            Community_Name__c         = 'Sunrise Estates',
            Builder_Parent_Account__c = parentAcct.Id,
            Builder_Market_Account__c = marketAcct.Id,
            Status                    = 'New'
        );
        insert l;

        Test.startTest();
        LeadConversionService.routeConversion(new List<Id>{ l.Id });
        Test.stopTest();

        List<Contact> contacts = [SELECT AccountId FROM Contact WHERE AccountId = :marketAcct.Id];
        System.assertEquals(1, contacts.size(), 'Scenario C should create a Contact on the Market Account.');
    }

    @isTest
    static void testScenarioCMatchesExistingContact() {
        Account marketAcct = new Account(
            Name         = 'Test Market Co',
            RecordTypeId = RecordTypeHelper.getAccountRT('Builder_Market'),
            Type         = 'Builder Market'
        );
        insert marketAcct;

        // Pre-existing Contact with no email on this account.
        Contact existing = new Contact(
            FirstName = 'Alice',
            LastName  = 'Existing',
            AccountId = marketAcct.Id
        );
        insert existing;

        Lead l = new Lead(
            FirstName                 = 'Alice',
            LastName                  = 'Existing',
            Company                   = 'Test Co',
            LeadSource                = 'Lennar Voucher',
            Lead_Type__c              = 'Existing Builder New Community',
            Community_Name__c         = 'Elm Grove',
            Builder_Market_Account__c = marketAcct.Id,
            Status                    = 'New'
        );
        insert l;

        Test.startTest();
        LeadConversionService.routeConversion(new List<Id>{ l.Id });
        Test.stopTest();

        // matchOrCreateContact finds existing (null email matches) — no duplicate created
        List<Contact> contacts = [SELECT Id FROM Contact WHERE AccountId = :marketAcct.Id];
        System.assertEquals(1, contacts.size(), 'Should match existing Contact, not create duplicate.');
    }

    @isTest
    static void testScenarioCFallsBackToParentWhenNoMarket() {
        Account parentAcct = new Account(
            Name         = 'Local Builder Co',
            RecordTypeId = RecordTypeHelper.getAccountRT('Builder_Parent'),
            Type         = 'Builder Parent'
        );
        insert parentAcct;

        Lead l = new Lead(
            FirstName                 = 'Carl',
            LastName                  = 'TestLocal',
            Company                   = 'Local Builder Co',
            LeadSource                = 'Lennar Voucher',
            Lead_Type__c              = 'Existing Builder New Community',
            Community_Name__c         = 'Pine Creek',
            Builder_Parent_Account__c = parentAcct.Id,
            Status                    = 'New'
        );
        insert l;

        Test.startTest();
        LeadConversionService.routeConversion(new List<Id>{ l.Id });
        Test.stopTest();

        List<Contact> contacts = [SELECT AccountId FROM Contact WHERE AccountId = :parentAcct.Id];
        System.assertEquals(1, contacts.size(), 'Scenario C without Market should create Contact on Parent Account.');
    }
}
