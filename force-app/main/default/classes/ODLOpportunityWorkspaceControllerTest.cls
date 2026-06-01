@isTest
private class ODLOpportunityWorkspaceControllerTest {

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

    @TestSetup
    static void setupTestData() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }

        // Separate accounts to respect one-active-UMB-per-account validation rule
        Account umbAccount = new Account(Name = 'Test UMB Homeowner', Type = 'Home Owner');
        Account dbAccount = new Account(Name = 'Test DB Homeowner', Type = 'Home Owner');
        Account nonHomeownerAccount = new Account(Name = 'Other Account', Type = 'Customer');
        insert new List<Account>{ umbAccount, dbAccount, nonHomeownerAccount };

        List<Opportunity> opps = new List<Opportunity>();

        if (rtIds.containsKey('UMB')) {
            opps.add(new Opportunity(
                Name = 'Test UMB Opp',
                AccountId = umbAccount.Id,
                StageName = 'Discovery',
                CloseDate = Date.today().addDays(30),
                RecordTypeId = rtIds.get('UMB'),
                Amount = 25000,
                Quote_Status__c = 'Not Sent',
                Contract_Status__c = 'Not Sent',
                Deposit_Paid__c = false,
                Voicemail_Left__c = false
            ));
        }

        if (rtIds.containsKey('Design_Build')) {
            opps.add(new Opportunity(
                Name = 'Test Design Build Opp',
                AccountId = dbAccount.Id,
                StageName = 'Quote Review',
                CloseDate = Date.today().addDays(45),
                RecordTypeId = rtIds.get('Design_Build'),
                Amount = 75000,
                Quote_Status__c = 'Sent',
                Contract_Status__c = 'Not Sent',
                Deposit_Paid__c = false,
                Voicemail_Left__c = false
            ));
        }

        if (opps.isEmpty()) {
            return;
        }
        insert opps;

        List<Task> tasks = new List<Task>();
        tasks.add(new Task(
            WhatId = opps[0].Id,
            Subject = 'Follow up call',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        ));
        tasks.add(new Task(
            WhatId = opps[0].Id,
            Subject = 'Send quote',
            Status = 'Not Started',
            ActivityDate = Date.today().addDays(3)
        ));
        if (opps.size() > 1) {
            tasks.add(new Task(
                WhatId = opps[1].Id,
                Subject = 'Left voicemail',
                Status = 'Completed',
                ActivityDate = Date.today()
            ));
        }
        insert tasks;
    }

    @isTest
    static void testGetWorkspaceData_returnsStructure() {
        Test.startTest();
        ODLOpportunityWorkspaceController.WorkspaceData result =
            ODLOpportunityWorkspaceController.getWorkspaceData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.kpis);
        System.assertNotEquals(null, result.rows);
        System.assertNotEquals(null, result.ownerNames);
        System.assertEquals(6, result.kpis.size(), 'Must have exactly 6 KPI cards');
    }

    @isTest
    static void testGetWorkspaceData_kpiKeys() {
        Test.startTest();
        ODLOpportunityWorkspaceController.WorkspaceData result =
            ODLOpportunityWorkspaceController.getWorkspaceData();
        Test.stopTest();

        Set<String> keys = new Set<String>();
        for (ODLOpportunityWorkspaceController.KpiCard kpi : result.kpis) {
            keys.add(kpi.key);
            System.assertNotEquals(null, kpi.label);
            System.assertNotEquals(null, kpi.count);
        }
        System.assert(keys.contains('all'));
        System.assert(keys.contains('umb'));
        System.assert(keys.contains('design'));
        System.assert(keys.contains('woReady'));
        System.assert(keys.contains('voicemail'));
        System.assert(keys.contains('followUp'));
    }

    @isTest
    static void testGetWorkspaceData_rowFields() {
        Test.startTest();
        ODLOpportunityWorkspaceController.WorkspaceData result =
            ODLOpportunityWorkspaceController.getWorkspaceData();
        Test.stopTest();

        System.assert(!result.rows.isEmpty(), 'Should have rows from test data');
        ODLOpportunityWorkspaceController.OppRow row = result.rows[0];
        System.assertNotEquals(null, row.id);
        System.assertNotEquals(null, row.oppHref);
        System.assertNotEquals(null, row.lob);
        System.assertNotEquals(null, row.stageName);
        System.assertNotEquals(null, row.nextActionText);
        System.assertNotEquals(null, row.nextActionButton);
        System.assertNotEquals(null, row.lastActivityResult);
    }

    @isTest
    static void testGetWorkspaceData_lobValues() {
        Test.startTest();
        ODLOpportunityWorkspaceController.WorkspaceData result =
            ODLOpportunityWorkspaceController.getWorkspaceData();
        Test.stopTest();

        for (ODLOpportunityWorkspaceController.OppRow row : result.rows) {
            System.assert(
                row.lob == 'UpgradeMyBackyard' || row.lob == 'Design Build',
                'LOB must be UpgradeMyBackyard or Design Build, got: ' + row.lob
            );
        }
    }

    @isTest
    static void testGetWorkspaceData_voicemailNextAction() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }
        // Use a fresh account to avoid the one-active-UMB-per-account validation rule
        Account vmAccount = new Account(Name = 'Voicemail Homeowner', Type = 'Home Owner');
        insert vmAccount;
        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];

        Opportunity vmOpp = new Opportunity(
            Name = 'Voicemail Test Opp',
            AccountId = vmAccount.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = rtId,
            Amount = 20000,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = true
        );
        insert vmOpp;

        insert new Task(
            WhatId = vmOpp.Id,
            Subject = 'Left voicemail',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );

        Test.startTest();
        ODLOpportunityWorkspaceController.WorkspaceData result =
            ODLOpportunityWorkspaceController.getWorkspaceData();
        Test.stopTest();

        ODLOpportunityWorkspaceController.OppRow found = null;
        for (ODLOpportunityWorkspaceController.OppRow row : result.rows) {
            if (row.id == vmOpp.Id) {
                found = row;
            }
        }
        System.assertNotEquals(null, found, 'Voicemail opp should appear in results');
        System.assert(found.voicemailLeft == true);
        // Stage = Discovery with activity → Rule 10: Book consult / Schedule
        System.assert(
            found.nextActionText.toLowerCase().contains('book') ||
            found.nextActionText.toLowerCase().contains('consult'),
            'Should indicate book consult: ' + found.nextActionText
        );
        System.assertEquals('Schedule', found.nextActionButton);
    }

    @isTest
    static void testGetWorkspaceData_woReady() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }
        Account woAccount = new Account(Name = 'WO Ready Homeowner', Type = 'Home Owner');
        insert woAccount;
        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];

        Opportunity woOpp = new Opportunity(
            Name = 'WO Ready Opp',
            AccountId = woAccount.Id,
            StageName = 'Deposit Pending',
            CloseDate = Date.today().addDays(10),
            RecordTypeId = rtId,
            Amount = 30000,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Signed',
            Deposit_Paid__c = true,
            Voicemail_Left__c = false
        );
        insert woOpp;

        insert new Task(
            WhatId = woOpp.Id,
            Subject = 'Deposit confirmed call',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );

        Test.startTest();
        ODLOpportunityWorkspaceController.WorkspaceData result =
            ODLOpportunityWorkspaceController.getWorkspaceData();
        Test.stopTest();

        ODLOpportunityWorkspaceController.OppRow found = null;
        for (ODLOpportunityWorkspaceController.OppRow row : result.rows) {
            if (row.id == woOpp.Id) {
                found = row;
            }
        }
        System.assertNotEquals(null, found, 'WO Ready opp should appear in results');
        System.assertEquals(true, found.woReady);
        // woReady with activity → Rule 4: Release work order / Release
        System.assert(
            found.nextActionText.toLowerCase().contains('release') ||
            found.nextActionText.toLowerCase().contains('work order'),
            'Should indicate release: ' + found.nextActionText
        );
        System.assertEquals('Release', found.nextActionButton);

        Boolean woReadyKpiPositive = false;
        for (ODLOpportunityWorkspaceController.KpiCard kpi : result.kpis) {
            if (kpi.key == 'woReady' && kpi.count > 0) {
                woReadyKpiPositive = true;
            }
        }
        System.assert(woReadyKpiPositive, 'WO Ready KPI should have count > 0');
    }

    @isTest
    static void testGetWorkspaceData_noMatchingOpps() {
        // Delete all test opps to test empty path
        delete [SELECT Id FROM Opportunity WHERE Name LIKE 'Test%'];

        Test.startTest();
        ODLOpportunityWorkspaceController.WorkspaceData result =
            ODLOpportunityWorkspaceController.getWorkspaceData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(6, result.kpis.size());
        for (ODLOpportunityWorkspaceController.KpiCard kpi : result.kpis) {
            System.assertEquals(0, kpi.count, 'All KPIs should be 0 with no data');
        }
    }

    @isTest
    static void testGetWorkspaceData_excludesNonHomeowner() {
        Map<String, Id> rtIds = getRecordTypeIds();
        if (rtIds.isEmpty()) {
            return;
        }
        Account nonHO = [SELECT Id FROM Account WHERE Name = 'Other Account' LIMIT 1];
        Id rtId = rtIds.containsKey('UMB') ? rtIds.get('UMB') : rtIds.values()[0];

        Opportunity excludedOpp = new Opportunity(
            Name = 'Should Be Excluded',
            AccountId = nonHO.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = rtId,
            Amount = 10000,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false,
            Voicemail_Left__c = false
        );
        insert excludedOpp;

        Test.startTest();
        ODLOpportunityWorkspaceController.WorkspaceData result =
            ODLOpportunityWorkspaceController.getWorkspaceData();
        Test.stopTest();

        for (ODLOpportunityWorkspaceController.OppRow row : result.rows) {
            System.assertNotEquals(excludedOpp.Id, row.id, 'Non-homeowner opp should be excluded');
        }
    }
}
