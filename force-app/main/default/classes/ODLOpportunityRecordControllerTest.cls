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
            StageName = 'Qualifying',
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
        System.assertEquals('Qualifying', result.stagePath[0]);
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
            StageName = 'Design Development',
            CloseDate = Date.today().addDays(45),
            RecordTypeId = rtIds.get('Design_Build'),
            Amount = 80000,
            Quote_Status__c = 'Sent',
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

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Design Build', result.projectPath);
        System.assertEquals(false, result.readiness.woReady);
        System.assert(
            result.nextActionText.toLowerCase().contains('quote') ||
            result.nextActionText.toLowerCase().contains('proposal') ||
            result.nextActionText.toLowerCase().contains('follow'),
            'Should indicate follow up: ' + result.nextActionText
        );
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
            StageName = 'Quote Accepted',
            CloseDate = Date.today().addDays(10),
            RecordTypeId = rtId,
            Amount = 25000,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Signed',
            Deposit_Paid__c = true,
            Voicemail_Left__c = false
        );
        insert opp;

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Deposit confirmed call',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );

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
        System.assert(
            result.nextActionText.toLowerCase().contains('release') ||
            result.nextActionText.toLowerCase().contains('work order'),
            'Should indicate release: ' + result.nextActionText
        );
        System.assertEquals('Release', result.nextActionButton);
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

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Left voicemail',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        // Stage = Consult Scheduled with activity → Rule 9: Prep design for consult / Open
        System.assert(
            result.nextActionText.toLowerCase().contains('consult') ||
            result.nextActionText.toLowerCase().contains('prep'),
            'Should reference consult prep: ' + result.nextActionText
        );
        System.assertEquals('Open', result.nextActionButton);
    }

    @isTest
    static void testGetPageData_stagePathOrdering_UMB() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) return;

        Account acc = new Account(Name = 'Stage Path Homeowner', Type = 'Home Owner');
        insert acc;

        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];
        Opportunity opp = new Opportunity(
            Name = 'Stage Path Opp',
            AccountId = acc.Id,
            StageName = 'Consult Scheduled',
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

        // New UMB Sales Path — spec section 4
        List<String> expectedStages = new List<String>{
            'Qualifying', 'Package Selected', 'Consult Scheduled',
            'Quote Sent', 'Quote Accepted', 'Proposal Presented', 'Closed Won'
        };
        System.assertEquals(expectedStages.size(), result.stagePath.size(),
            'UMB stage path should have ' + expectedStages.size() + ' stages. Got: ' + result.stagePath);
        for (Integer i = 0; i < expectedStages.size(); i++) {
            System.assertEquals(expectedStages[i], result.stagePath[i],
                'Stage at index ' + i + ' mismatch');
        }
    }

    @isTest
    static void testGetPageData_stagePathOrdering_DB() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('Design_Build')) return;

        Account acc = new Account(Name = 'DB Stage Path Homeowner', Type = 'Home Owner');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'DB Stage Path Opp',
            AccountId = acc.Id,
            StageName = 'Consult Scheduled',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = rtIds.get('Design_Build'),
            Amount = 75000,
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

        // New Design Build Sales Path — spec section 4
        List<String> expectedStages = new List<String>{
            'Discovery Consult', 'Design Agreement', 'Consult Scheduled',
            'Design Development', 'Proposal Presented', 'Closed Won'
        };
        System.assertEquals(expectedStages.size(), result.stagePath.size(),
            'Design Build stage path should have ' + expectedStages.size() + ' stages. Got: ' + result.stagePath);
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
            StageName = 'Discovery Consult',
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
    static void testGetPageData_packageSelected_bookConsult() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) return;

        Account acc = new Account(Name = 'Package Selected Homeowner', Type = 'Home Owner');
        insert acc;

        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];
        Opportunity opp = new Opportunity(
            Name = 'Package Selected Opp',
            AccountId = acc.Id,
            StageName = 'Package Selected',
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
            Subject = 'Package confirmation call',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        // UMB Package Selected → Book consult / Schedule
        System.assert(
            result.nextActionText.toLowerCase().contains('book') ||
            result.nextActionText.toLowerCase().contains('consult'),
            'Should indicate book consult: ' + result.nextActionText
        );
        System.assertEquals('Schedule', result.nextActionButton);
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
            StageName = 'Proposal Presented',
            CloseDate = Date.today().addDays(14),
            RecordTypeId = rtId,
            Amount = 55000,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Contract follow-up',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        // quoteAccepted=true, contractSigned=false → Rule 5: Confirm contract signature / Mark Signed
        System.assert(
            result.nextActionText.toLowerCase().contains('contract'),
            'Should mention contract: ' + result.nextActionText
        );
        System.assertEquals('Mark Signed', result.nextActionButton);
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
            StageName = 'Quote Accepted',
            CloseDate = Date.today().addDays(7),
            RecordTypeId = rtId,
            Amount = 28000,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Signed',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert opp;

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Deposit request call',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        // quoteAccepted=true, contractSigned=true, depositPaid=false → Rule 6: Collect deposit / Request
        System.assert(
            result.nextActionText.toLowerCase().contains('deposit'),
            'Should mention deposit: ' + result.nextActionText
        );
        System.assertEquals('Request', result.nextActionButton);
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
            StageName = 'Design Development',
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

    // ─── Engagement health tests ─────────────────────────────────────────────────

    @isTest
    static void testEngagement_activeWhenResponseRecent() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('UMB')) return;

        Account acc = new Account(Name = 'Active Eng Homeowner', Type = 'Home Owner');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Active Engagement Opp', AccountId = acc.Id, StageName = 'Consult Scheduled',
            CloseDate = Date.today().addDays(30), RecordTypeId = rtIds.get('UMB'),
            Quote_Status__c = 'Not Sent', Contract_Status__c = 'Not Sent',
            Last_Customer_Response_Date__c = Date.today().addDays(-3)
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result = ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertEquals('Active', result.engagement.state, 'Should be Active at 3 days');
        System.assertEquals(3, result.engagement.daysSinceResponse, 'Days should be 3');
    }

    @isTest
    static void testEngagement_slowing_UMB_at7Days() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('UMB')) return;

        Account acc = new Account(Name = 'Slowing UMB Homeowner', Type = 'Home Owner');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Slowing UMB Opp', AccountId = acc.Id, StageName = 'Quote Sent',
            CloseDate = Date.today().addDays(30), RecordTypeId = rtIds.get('UMB'),
            Quote_Status__c = 'Sent', Contract_Status__c = 'Not Sent',
            Last_Customer_Response_Date__c = Date.today().addDays(-8)
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result = ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertEquals('Slowing', result.engagement.state, 'UMB should be Slowing at 8 days');
        System.assert(result.nextActionText.toLowerCase().contains('slowing') ||
                      result.nextActionText.toLowerCase().contains('re-engage'),
                      'Next action should mention re-engage: ' + result.nextActionText);
        System.assertEquals('Call', result.nextActionButton);
    }

    @isTest
    static void testEngagement_goingDark_UMB_at14Days() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('UMB')) return;

        Account acc = new Account(Name = 'Dark UMB Homeowner', Type = 'Home Owner');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Going Dark UMB Opp', AccountId = acc.Id, StageName = 'Quote Sent',
            CloseDate = Date.today().addDays(30), RecordTypeId = rtIds.get('UMB'),
            Quote_Status__c = 'Sent', Contract_Status__c = 'Not Sent',
            Last_Customer_Response_Date__c = Date.today().addDays(-15)
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result = ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertEquals('Going Dark', result.engagement.state, 'UMB should be Going Dark at 15 days');
        System.assert(result.nextActionText.toLowerCase().contains('going dark') ||
                      result.nextActionText.toLowerCase().contains('final follow'),
                      'Next action should flag going dark: ' + result.nextActionText);
        System.assertEquals('Follow Up', result.nextActionButton);
        System.assertNotEquals(null, result.engagement.callToAction, 'Going dark should have CTA');
    }

    @isTest
    static void testEngagement_slowing_DB_at14Days() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('Design_Build')) return;

        Account acc = new Account(Name = 'Slowing DB Homeowner', Type = 'Home Owner');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Slowing DB Opp', AccountId = acc.Id, StageName = 'Design Development',
            CloseDate = Date.today().addDays(30), RecordTypeId = rtIds.get('Design_Build'),
            Quote_Status__c = 'Not Sent', Contract_Status__c = 'Not Sent',
            Last_Customer_Response_Date__c = Date.today().addDays(-16)
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result = ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertEquals('Slowing', result.engagement.state, 'Design Build should be Slowing at 16 days');
    }

    @isTest
    static void testEngagement_goingDark_DB_at30Days() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('Design_Build')) return;

        Account acc = new Account(Name = 'Dark DB Homeowner', Type = 'Home Owner');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Going Dark DB Opp', AccountId = acc.Id, StageName = 'Proposal Presented',
            CloseDate = Date.today().addDays(30), RecordTypeId = rtIds.get('Design_Build'),
            Quote_Status__c = 'Sent', Contract_Status__c = 'Not Sent',
            Last_Customer_Response_Date__c = Date.today().addDays(-31)
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result = ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertEquals('Going Dark', result.engagement.state, 'Design Build should be Going Dark at 31 days');
    }

    @isTest
    static void testEngagement_closedWon_isNA() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('UMB')) return;

        Account acc = new Account(Name = 'Won Homeowner', Type = 'Home Owner');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Closed Won Opp', AccountId = acc.Id, StageName = 'Closed Won',
            CloseDate = Date.today(), RecordTypeId = rtIds.get('UMB'),
            Quote_Status__c = 'Accepted', Contract_Status__c = 'Signed'
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result = ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertEquals('N/A', result.engagement.state, 'Closed Won should have N/A engagement');
        System.assertEquals(null, result.nextActionButton, 'Closed Won should have null button');
    }

    @isTest
    static void testEngagement_noResponseNoAttempts_isActive() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('UMB')) return;

        Account acc = new Account(Name = 'No Response Homeowner', Type = 'Home Owner');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'No Response Opp', AccountId = acc.Id, StageName = 'Qualifying',
            CloseDate = Date.today().addDays(30), RecordTypeId = rtIds.get('UMB'),
            Quote_Status__c = 'Not Sent', Contract_Status__c = 'Not Sent'
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result = ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertEquals('Active', result.engagement.state, 'No response + no attempts should be Active');
        System.assertEquals(null, result.engagement.lastResponseDate, 'lastResponseDate should be null when no response');
    }

    @isTest
    static void testEngagement_designFeeStatus_populated() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (!rtIds.containsKey('Design_Build')) return;

        Account acc = new Account(Name = 'Design Fee Homeowner', Type = 'Home Owner');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Design Fee Opp', AccountId = acc.Id, StageName = 'Design Agreement',
            CloseDate = Date.today().addDays(30), RecordTypeId = rtIds.get('Design_Build'),
            Quote_Status__c = 'Not Sent', Contract_Status__c = 'Not Sent',
            Design_Fee_Status__c = 'Paid',
            Design_Fee_Paid_Date__c = Date.today().addDays(-5)
        );
        insert opp;

        Test.startTest();
        ODLOpportunityRecordController.PageData result = ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertEquals('Paid', result.designFeeStatus, 'Design fee status should be Paid');
        System.assertNotEquals(null, result.designFeePaidDate, 'Paid date should be present');
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

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Pre-consult call',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );

        Test.startTest();
        ODLOpportunityRecordController.PageData result =
            ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        // Stage = Consult Scheduled with activity → Rule 9: Prep design for consult / Open
        System.assert(
            result.nextActionText.toLowerCase().contains('consult') ||
            result.nextActionText.toLowerCase().contains('prep'),
            'Should prep consult: ' + result.nextActionText
        );
        System.assertEquals('Open', result.nextActionButton);
    }
}