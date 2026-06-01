@isTest
private class ODLOpportunityRecordControllerTest {

    private static Map<String, Id> getRecordTypeIds() {
        Map<String, Id> rtIds = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName FROM RecordType
            WHERE SObjectType = 'Opportunity'
            AND DeveloperName IN ('UMB', 'Design_Build')
        ]) {
            rtIds.put(rt.DeveloperName, rt.Id);
        }
        return rtIds;
    }

    @isTest
    static void testGetPageData_nullId() {
        Boolean threw = false;
        try {
            ODLOpportunityRecordController.getPageData(null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assert(threw, 'Should throw for null Id');
    }

    @isTest
    static void testGetPageData_umbOpportunity() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('UMB')) {
            return;
        }

        Account acc = new Account(Name = 'Test Homeowner', Type = 'Home Owner');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test UMB Record Page Opp',
            AccountId = acc.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = rtIds.get('UMB'),
            Amount = 30000,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Follow-up call',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );
        insert new Task(
            WhatId = opp.Id,
            Subject = 'Send proposal',
            Status = 'Not Started',
            ActivityDate = Date.today().addDays(5)
        );

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.opportunityRecord);
        System.assertEquals(opp.Id, result.opportunityRecord.Id);
        System.assertEquals('UpgradeMyBackyard', result.projectPath);
        System.assertNotEquals(null, result.stagePath);
        System.assert(!result.stagePath.isEmpty());
        System.assertEquals('Discovery', result.stagePath[0]);
        System.assertNotEquals(null, result.readiness);
        System.assertEquals(false, result.readiness.woReady);
        System.assertEquals(false, result.readiness.quoteAccepted);
        System.assertNotEquals(null, result.nextActionText);
        System.assertNotEquals(null, result.nextActionButton);
    }

    @isTest
    static void testGetPageData_designBuildOpportunity() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('Design_Build')) {
            return;
        }

        Account acc = new Account(Name = 'Test DB Homeowner', Type = 'Home Owner');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test DB Record Page Opp',
            AccountId = acc.Id,
            StageName = 'Quote Review',
            CloseDate = Date.today().addDays(45),
            RecordTypeId = rtIds.get('Design_Build'),
            Amount = 80000,
            Quote_Status__c = 'Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Design Build', result.projectPath);
        System.assertEquals(false, result.readiness.woReady);
        System.assert(result.nextActionText.toLowerCase().contains('quote'));
        System.assertEquals('Call', result.nextActionButton);
        System.assert(!result.quotes.isEmpty(), 'Should have quote from Quote_Status__c');
    }

    @isTest
    static void testGetPageData_woReady() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }

        Account acc = new Account(Name = 'WO Ready Homeowner', Type = 'Home Owner');
        insert acc;

        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];
        Opportunity opp = new Opportunity(
            Name = 'WO Ready Record Page Opp',
            AccountId = acc.Id,
            StageName = 'Deposit Pending',
            CloseDate = Date.today().addDays(10),
            RecordTypeId = rtId,
            Amount = 25000,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Signed',
            Deposit_Paid__c = true,
            Voicemail_Left__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.readiness);
        System.assertEquals(true, result.readiness.woReady);
        System.assertEquals(true, result.readiness.quoteAccepted);
        System.assertEquals(true, result.readiness.contractSigned);
        System.assertEquals(true, result.readiness.depositPaid);
        System.assertEquals('WO Ready', result.readiness.readinessBadge);
        System.assert(result.nextActionText.toLowerCase().contains('ready'));
        System.assertEquals('Release WO', result.nextActionButton);
    }

    @isTest
    static void testGetPageData_voicemailLeft() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }

        Account acc = new Account(Name = 'Voicemail Homeowner 07', Type = 'Home Owner');
        insert acc;

        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];
        Opportunity opp = new Opportunity(
            Name = 'Voicemail Record Page Opp',
            AccountId = acc.Id,
            StageName = 'Consult Scheduled',
            CloseDate = Date.today().addDays(20),
            RecordTypeId = rtId,
            Amount = 18000,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = true
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assert(result.nextActionText.toLowerCase().contains('voicemail'));
        System.assertEquals('Schedule', result.nextActionButton);
    }

    @isTest
    static void testGetPageData_stagePathOrdering() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }

        Account acc = new Account(Name = 'Stage Path Homeowner', Type = 'Home Owner');
        insert acc;

        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];
        Opportunity opp = new Opportunity(
            Name = 'Stage Path Opp',
            AccountId = acc.Id,
            StageName = 'Design In Progress',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = rtId,
            Amount = 22000,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        List<String> expectedStages = new List<String>{
            'Discovery', 'Consult Scheduled', 'Design In Progress',
            'Quote Review', 'Contract Sent', 'Deposit Pending', 'Closed Won'
        };
        System.assertEquals(expectedStages.size(), result.stagePath.size(),
            'Stage path should have exactly 7 stages');
        for (Integer i = 0; i < expectedStages.size(); i++) {
            System.assertEquals(expectedStages[i], result.stagePath[i],
                'Stage at index ' + i + ' mismatch');
        }
    }

    @isTest
    static void testGetPageData_noActivityNextAction() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }

        Account acc = new Account(Name = 'No Activity Homeowner', Type = 'Home Owner');
        insert acc;

        Id rtId = rtIds.containsKey('Design_Build') ? rtIds.get('Design_Build') : rtIds.values()[0];
        Opportunity opp = new Opportunity(
            Name = 'No Activity Opp',
            AccountId = acc.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = rtId,
            Amount = 12000,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assert(
            result.nextActionText.toLowerCase().contains('contact') ||
            result.nextActionText.toLowerCase().contains('consult') ||
            result.nextActionText.toLowerCase().contains('follow-up') ||
            result.nextActionText.toLowerCase().contains('schedule'),
            'No-activity opp should have a clear next action: ' + result.nextActionText
        );
    }

    @isTest
    static void testGetPageData_overdueFollowUp() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }

        Account acc = new Account(Name = 'Overdue Homeowner 08', Type = 'Home Owner');
        insert acc;

        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];
        Opportunity opp = new Opportunity(
            Name = 'Overdue Follow Up Opp',
            AccountId = acc.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = rtId,
            Amount = 15000,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Check in call',
            Status = 'Not Started',
            ActivityDate = Date.today().addDays(-3)
        );

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assert(
            result.nextActionText.toLowerCase().contains('overdue'),
            'Should surface overdue action: ' + result.nextActionText
        );
        System.assertEquals('Log Activity', result.nextActionButton);
    }

    @isTest
    static void testGetPageData_contractSentStage() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }

        Account acc = new Account(Name = 'Contract Sent Homeowner', Type = 'Home Owner');
        insert acc;

        Id rtId = rtIds.containsKey('Design_Build') ? rtIds.get('Design_Build') : rtIds.values()[0];
        Opportunity opp = new Opportunity(
            Name = 'Contract Sent Opp',
            AccountId = acc.Id,
            StageName = 'Contract Sent',
            CloseDate = Date.today().addDays(14),
            RecordTypeId = rtId,
            Amount = 55000,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assert(
            result.nextActionText.toLowerCase().contains('contract'),
            'Should mention contract: ' + result.nextActionText
        );
        System.assertEquals('Call', result.nextActionButton);
        System.assertNotEquals(null, result.readiness);
        System.assertEquals(true, result.readiness.quoteAccepted);
        System.assertEquals(false, result.readiness.contractSigned);
        System.assertEquals('Blocked', result.readiness.readinessBadge);
    }

    @isTest
    static void testGetPageData_depositPendingBlockedOnDeposit() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }

        Account acc = new Account(Name = 'Deposit Blocked Homeowner', Type = 'Home Owner');
        insert acc;

        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];
        Opportunity opp = new Opportunity(
            Name = 'Deposit Pending Not Ready Opp',
            AccountId = acc.Id,
            StageName = 'Deposit Pending',
            CloseDate = Date.today().addDays(7),
            RecordTypeId = rtId,
            Amount = 28000,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Signed',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assert(
            result.nextActionText.toLowerCase().contains('deposit'),
            'Should mention deposit: ' + result.nextActionText
        );
        System.assertEquals('Call', result.nextActionButton);
        System.assertNotEquals(null, result.readiness);
        System.assertEquals(true, result.readiness.quoteAccepted);
        System.assertEquals(true, result.readiness.contractSigned);
        System.assertEquals(false, result.readiness.depositPaid);
        System.assertEquals('Blocked', result.readiness.readinessBadge);
        System.assertEquals('badge badge-amber', result.readiness.badgeClass);
    }

    @isTest
    static void testGetPageData_withEventInteraction() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('Design_Build')) {
            return;
        }

        Account acc = new Account(Name = 'Event Interaction Homeowner', Type = 'Home Owner');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Event Interaction Opp',
            AccountId = acc.Id,
            StageName = 'Design In Progress',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = rtIds.get('Design_Build'),
            Amount = 35000,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Initial call',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-5)
        );

        insert new Event(
            WhatId = opp.Id,
            Subject = 'Site visit',
            Type = 'Meeting',
            ActivityDateTime = Datetime.now().addDays(-2),
            DurationInMinutes = 60
        );

        insert new Event(
            WhatId = opp.Id,
            Subject = 'Follow-up consultation',
            Type = 'Call',
            ActivityDateTime = Datetime.now().addDays(3),
            DurationInMinutes = 30
        );

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.interactions);
        System.assert(result.interactions.size() >= 1, 'Should have at least 1 interaction from events/tasks');
    }

    @isTest
    static void testGetPageData_consultScheduledNoVoicemail() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }

        Account acc = new Account(Name = 'Consult Homeowner 09', Type = 'Home Owner');
        insert acc;

        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];
        Opportunity opp = new Opportunity(
            Name = 'Consult Scheduled No VM Opp',
            AccountId = acc.Id,
            StageName = 'Consult Scheduled',
            CloseDate = Date.today().addDays(20),
            RecordTypeId = rtId,
            Amount = 16000,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assert(
            result.nextActionText.toLowerCase().contains('consult') ||
            result.nextActionText.toLowerCase().contains('confirm'),
            'Should confirm consult: ' + result.nextActionText
        );
        System.assertEquals('Confirm', result.nextActionButton);
    }
}
