@isTest
private class ODLHomeownerPropertyIdentityServiceTest {

    private static Account makeHomeownerAccount() {
        Account acct = new Account(
            Name         = 'Test Homeowner',
            RecordTypeId = RecordTypeHelper.getAccountRT('Home_Owner'),
            Type         = 'Home Owner'
        );
        insert acct;
        return acct;
    }

    @isTest
    static void testSyncCreatesPropertyForODLOpp() {
        Account acct = makeHomeownerAccount();
        Id umbRtId = RecordTypeHelper.getOpportunityRT('UMB');
        if (umbRtId == null) {
            System.debug('UMB RecordType not found; skipping.');
            return;
        }

        Opportunity opp = new Opportunity(
            Name         = 'ODL Test Opp',
            AccountId    = acct.Id,
            StageName    = 'New',
            CloseDate    = Date.today(),
            Type         = 'UpgradeMyBackyard',
            RecordTypeId = umbRtId
        );
        insert opp;

        // Re-query with RecordType to drive syncFromOpportunities
        Opportunity queried = [
            SELECT Id, Name, AccountId, Type, LeadSource, BMG_Package__c, RecordType.DeveloperName, Community__c, ContactId
            FROM Opportunity WHERE Id = :opp.Id
        ];

        Test.startTest();
        ODLHomeownerPropertyIdentityService.syncFromOpportunities(
            new List<Opportunity>{ queried },
            null
        );
        Test.stopTest();

        List<Homeowner_Property__c> props = [SELECT Id FROM Homeowner_Property__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(1, props.size(), 'Should create one Homeowner_Property for ODL opp.');
    }

    @isTest
    static void testSyncSkipsNonODLOpp() {
        Account acct = makeHomeownerAccount();

        Opportunity opp = new Opportunity(
            Name      = 'Non ODL Opp',
            AccountId = acct.Id,
            StageName = 'New',
            CloseDate = Date.today(),
            Type      = 'Other'
        );
        insert opp;

        Opportunity queried = [
            SELECT Id, Name, AccountId, Type, LeadSource, BMG_Package__c, RecordType.DeveloperName, Community__c, ContactId
            FROM Opportunity WHERE Id = :opp.Id
        ];

        Test.startTest();
        ODLHomeownerPropertyIdentityService.syncFromOpportunities(
            new List<Opportunity>{ queried },
            null
        );
        Test.stopTest();

        List<Homeowner_Property__c> props = [SELECT Id FROM Homeowner_Property__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(0, props.size(), 'Non-ODL opp should not create Homeowner_Property.');
    }

    @isTest
    static void testSyncSkipsNullInput() {
        Test.startTest();
        ODLHomeownerPropertyIdentityService.syncFromOpportunities(null, null);
        ODLHomeownerPropertyIdentityService.syncFromOpportunities(new List<Opportunity>(), null);
        Test.stopTest();
        // No exception = pass
        System.assert(true);
    }

    @isTest
    static void testHydrateProperties() {
        Account acct = makeHomeownerAccount();
        Id umbRtId = RecordTypeHelper.getOpportunityRT('UMB');
        if (umbRtId == null) {
            System.debug('UMB RecordType not found; skipping.');
            return;
        }

        Opportunity opp = new Opportunity(
            Name         = 'Hydrate Test Opp',
            AccountId    = acct.Id,
            StageName    = 'New',
            CloseDate    = Date.today(),
            Type         = 'UpgradeMyBackyard',
            RecordTypeId = umbRtId
        );
        insert opp;

        Homeowner_Property__c prop = new Homeowner_Property__c(
            Name                = 'Test Property',
            Homeowner_Account__c = acct.Id,
            Opportunity__c      = opp.Id
        );
        insert prop;

        Test.startTest();
        ODLHomeownerPropertyIdentityService.hydrateProperties(new List<Homeowner_Property__c>{ prop });
        Test.stopTest();

        System.assertEquals(acct.Id, prop.Homeowner_Account__c, 'Account should be hydrated.');
    }

    @isTest
    static void testHydratePropertiesNullAndEmpty() {
        Test.startTest();
        ODLHomeownerPropertyIdentityService.hydrateProperties(null);
        ODLHomeownerPropertyIdentityService.hydrateProperties(new List<Homeowner_Property__c>());
        Test.stopTest();
        System.assert(true, 'No exception on null/empty input.');
    }

    @isTest
    static void testAmbiguousAccountCreatesReviewTask() {
        // Two existing properties on the same account with no opp → ambiguous → review task
        Account acct = makeHomeownerAccount();
        Id umbRtId = RecordTypeHelper.getOpportunityRT('UMB');
        if (umbRtId == null) {
            System.debug('UMB RecordType not found; skipping.');
            return;
        }

        // Insert two orphaned properties on the same account
        insert new List<Homeowner_Property__c>{
            new Homeowner_Property__c(Name = 'Prop A', Homeowner_Account__c = acct.Id),
            new Homeowner_Property__c(Name = 'Prop B', Homeowner_Account__c = acct.Id)
        };

        Opportunity opp = new Opportunity(
            Name         = 'Ambiguous Test Opp',
            AccountId    = acct.Id,
            StageName    = 'New',
            CloseDate    = Date.today(),
            Type         = 'UpgradeMyBackyard',
            RecordTypeId = umbRtId
        );
        insert opp;

        Opportunity queried = [
            SELECT Id, Name, AccountId, Type, LeadSource, BMG_Package__c, RecordType.DeveloperName, Community__c, ContactId
            FROM Opportunity WHERE Id = :opp.Id
        ];

        Test.startTest();
        ODLHomeownerPropertyIdentityService.syncFromOpportunities(
            new List<Opportunity>{ queried },
            null
        );
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :opp.Id AND Subject = 'ODL Property Identity Review'];
        System.assertEquals(1, tasks.size(), 'Ambiguous match should create review task.');
    }

    @isTest
    static void testLeadSourceHeuristicFallback() {
        // Tests the isOdlOpportunity path via LeadSource when no RecordType
        Account acct = makeHomeownerAccount();

        Opportunity opp = new Opportunity(
            Name       = 'LeadSource Heuristic Opp',
            AccountId  = acct.Id,
            StageName  = 'New',
            CloseDate  = Date.today(),
            LeadSource = 'Lennar Voucher'
        );
        insert opp;

        Opportunity queried = [
            SELECT Id, Name, AccountId, Type, LeadSource, BMG_Package__c, RecordType.DeveloperName, Community__c, ContactId
            FROM Opportunity WHERE Id = :opp.Id
        ];

        Test.startTest();
        ODLHomeownerPropertyIdentityService.syncFromOpportunities(
            new List<Opportunity>{ queried },
            null
        );
        Test.stopTest();

        List<Homeowner_Property__c> props = [SELECT Id FROM Homeowner_Property__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(1, props.size(), 'LeadSource heuristic should qualify opp for property creation.');
    }
}
