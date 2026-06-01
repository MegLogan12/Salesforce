@IsTest
private class ODLContactRecordControllerTest {

    // ── Shared setup ─────────────────────────────────────────────────────────

    private static Account makeAccount() {
        Account a = new Account(
            Name = 'Test Household',
            BillingCity = 'Charlotte',
            BillingState = 'NC'
        );
        insert a;
        return a;
    }

    private static Contact makeContact(Id accountId, Boolean smsConsent, Boolean emailOptOut) {
        Contact c = new Contact(
            FirstName = 'Robin',
            LastName = 'Vance',
            AccountId = accountId,
            Phone = '7045550188',
            Email = 'robin@test.com',
            SMS_Consent__c = smsConsent,
            HasOptedOutOfEmail = emailOptOut,
            SMS_Opt_In_Date__c = smsConsent ? Date.today() : null,
            SMS_Opt_In_Source__c = smsConsent ? 'Web form' : null
        );
        insert c;
        return c;
    }

    private static Opportunity makeOpp(Id accountId, Id contactId, String stage, String rtName) {
        RecordType rt = [SELECT Id FROM RecordType
            WHERE SObjectType = 'Opportunity' AND DeveloperName = :rtName LIMIT 1];
        Opportunity o = new Opportunity(
            Name = rtName + '-TEST-001',
            AccountId = accountId,
            StageName = stage,
            CloseDate = Date.today().addDays(30),
            RecordTypeId = rt.Id
        );
        insert o;
        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = o.Id,
            ContactId = contactId,
            IsPrimary = true,
            Role = 'Decision Maker'
        );
        insert ocr;
        return o;
    }

    private static Case makeCase(Id contactId, String status) {
        Case c = new Case(
            ContactId = contactId,
            Subject = 'Paver settling near fire feature',
            Status = status,
            Origin = 'Web'
        );
        insert c;
        return c;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void testPageData_smsConsentTrue() {
        Account a = makeAccount();
        Contact c = makeContact(a.Id, true, false);

        Test.startTest();
        ODLContactRecordController.ContactPageData pd =
            ODLContactRecordController.getContactPageData(c.Id);
        Test.stopTest();

        System.assertEquals(true, pd.smsConsent, 'smsConsent should be true');
        System.assertNotEquals(null, pd.smsOptInDate, 'opt-in date should be populated');
        System.assertEquals('Web form', pd.smsOptInSource, 'source should be Web form');
        System.assertEquals('Subscribed', pd.emailStatus, 'email should be Subscribed');
        System.assertEquals('Reachable on all channels', pd.commsChip);
        System.assertEquals('RV', pd.contactInitials);
        System.assertEquals('Charlotte, NC', pd.location);
    }

    @IsTest
    static void testPageData_smsConsentFalse_nextActionIsSmsConsent() {
        Account a = makeAccount();
        Contact c = makeContact(a.Id, false, false);

        Test.startTest();
        ODLContactRecordController.ContactPageData pd =
            ODLContactRecordController.getContactPageData(c.Id);
        Test.stopTest();

        System.assertEquals(false, pd.smsConsent, 'smsConsent should be false');
        System.assert(
            pd.nextActionText.containsIgnoreCase('SMS consent'),
            'next action should flag SMS consent'
        );
        System.assertEquals(null, pd.nextActionPrimaryLabel,
            'no primary action when SMS consent missing');
    }

    @IsTest
    static void testPageData_emailOptedOut_nextActionIsEmailOptOut() {
        Account a = makeAccount();
        Contact c = makeContact(a.Id, true, true);

        Test.startTest();
        ODLContactRecordController.ContactPageData pd =
            ODLContactRecordController.getContactPageData(c.Id);
        Test.stopTest();

        System.assertEquals('Opted Out', pd.emailStatus, 'emailStatus should be Opted Out');
        System.assert(
            pd.nextActionText.containsIgnoreCase('opted out'),
            'next action should flag email opt-out'
        );
    }

    @IsTest
    static void testPageData_openCase_nextActionIsCase() {
        Account a = makeAccount();
        Contact c = makeContact(a.Id, true, false);
        makeCase(c.Id, 'New');

        Test.startTest();
        ODLContactRecordController.ContactPageData pd =
            ODLContactRecordController.getContactPageData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, pd.nextActionCaseId, 'next action case id should be set');
        System.assert(
            pd.nextActionText.containsIgnoreCase('Resolve'),
            'next action should say Resolve'
        );
        System.assertNotEquals(0, pd.dealsAndService.size(), 'deals table should include case');
    }

    @IsTest
    static void testPageData_openOpp_nextActionIsOpp() {
        Account a = makeAccount();
        Contact c = makeContact(a.Id, true, false);
        makeOpp(a.Id, c.Id, 'Qualifying', 'UMB');

        Test.startTest();
        ODLContactRecordController.ContactPageData pd =
            ODLContactRecordController.getContactPageData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, pd.nextActionOppId, 'next action opp id should be set');
        System.assertEquals(true, pd.isPrimary, 'isPrimary should be true');
        System.assertNotEquals(0, pd.dealsAndService.size(), 'deals table should include opp');
    }

    @IsTest
    static void testPageData_closedWonOpp_isRepeatCustomer() {
        Account a = makeAccount();
        Contact c = makeContact(a.Id, true, false);
        makeOpp(a.Id, c.Id, 'Closed Won', 'Design_Build');

        Test.startTest();
        ODLContactRecordController.ContactPageData pd =
            ODLContactRecordController.getContactPageData(c.Id);
        Test.stopTest();

        System.assertEquals(true, pd.isRepeatCustomer, 'isRepeatCustomer should be true');
    }

    @IsTest
    static void testPageData_noRelatedRecords() {
        Account a = makeAccount();
        Contact c = makeContact(a.Id, true, false);

        Test.startTest();
        ODLContactRecordController.ContactPageData pd =
            ODLContactRecordController.getContactPageData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, pd.dealsAndService, 'dealsAndService should not be null');
        System.assertEquals(0, pd.dealsAndService.size(), 'no deals when none linked');
        System.assertEquals(false, pd.isRepeatCustomer, 'not repeat without closed won');
    }

    @IsTest
    static void testPageData_householdMembers() {
        Account a = makeAccount();
        Contact c1 = makeContact(a.Id, true, false);
        Contact c2 = new Contact(
            FirstName = 'Marcus', LastName = 'Vance',
            AccountId = a.Id, Phone = '7045550199',
            SMS_Consent__c = false
        );
        insert c2;

        Test.startTest();
        ODLContactRecordController.ContactPageData pd =
            ODLContactRecordController.getContactPageData(c1.Id);
        Test.stopTest();

        System.assertEquals(1, pd.householdMembers.size(), 'one household member expected');
        System.assertEquals('MV', pd.householdMembers[0].initials);
    }

    @IsTest
    static void testPageData_flsRestriction() {
        Account a = makeAccount();
        Contact c = makeContact(a.Id, true, false);

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        if (p == null) { return; }

        User u = new User(
            Alias = 'odltest', Email = 'odltest_fls@test.com',
            EmailEncodingKey = 'UTF-8', LastName = 'TestFLS',
            LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, TimeZoneSidKey = 'America/New_York',
            UserName = 'odltest_fls_contact@test.com'
        );
        insert u;

        Test.startTest();
        Boolean threw = false;
        try {
            System.runAs(u) {
                ODLContactRecordController.getContactPageData(c.Id);
            }
        } catch (Exception ex) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'FLS-restricted user should cause query failure');
    }
}
