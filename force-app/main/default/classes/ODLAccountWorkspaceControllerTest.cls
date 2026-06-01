@IsTest
private class ODLAccountWorkspaceControllerTest {

    private static final Id HOME_OWNER_RT_ID =
        Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Home_Owner')
            .getRecordTypeId();

    // ── Fixtures ─────────────────────────────────────────────────────────────

    private static Account makeAccount(String name, String market) {
        return new Account(
            Name = name,
            RecordTypeId = HOME_OWNER_RT_ID,
            Market__c = market
        );
    }

    private static Opportunity makeOpp(Id accountId, String stage, String type) {
        return new Opportunity(
            Name      = 'Test Opp',
            AccountId = accountId,
            StageName = stage,
            CloseDate = Date.today().addDays(30),
            Type      = type
        );
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void getWorkspaceData_returnsHomeownersOnly() {
        Account ho = makeAccount('Homeowner One', 'Charlotte');
        Account builder = new Account(
            Name = 'Builder Corp',
            RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .get('Builder_Parent')
                .getRecordTypeId()
        );
        insert new List<Account>{ ho, builder };

        Test.startTest();
        ODLAccountWorkspaceController.WorkspaceDataDTO result =
            ODLAccountWorkspaceController.getWorkspaceData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'DTO must not be null');
        System.assertNotEquals(null, result.rows, 'Rows must not be null');

        Set<Id> returnedIds = new Set<Id>();
        for (ODLAccountWorkspaceController.AccountRowDTO r : result.rows) {
            returnedIds.add(r.accountId);
        }
        System.assert(returnedIds.contains(ho.Id), 'Homeowner must appear');
        System.assert(!returnedIds.contains(builder.Id), 'Builder must not appear');
    }

    @IsTest
    static void lifecycle_leadWhenNoOppNoJob() {
        Account ho = makeAccount('Lead House', 'Charlotte');
        insert ho;

        Test.startTest();
        ODLAccountWorkspaceController.WorkspaceDataDTO result =
            ODLAccountWorkspaceController.getWorkspaceData();
        Test.stopTest();

        ODLAccountWorkspaceController.AccountRowDTO row = findRow(result.rows, ho.Id);
        System.assertEquals('Lead', row.lifecycle, 'No opp, no job -> Lead');
    }

    @IsTest
    static void lifecycle_prospectWhenOpenOpp() {
        Account ho = makeAccount('Prospect House', 'Greenville');
        insert ho;
        Opportunity opp = makeOpp(ho.Id, 'Discovery', 'UMB');
        insert opp;

        Test.startTest();
        ODLAccountWorkspaceController.WorkspaceDataDTO result =
            ODLAccountWorkspaceController.getWorkspaceData();
        Test.stopTest();

        ODLAccountWorkspaceController.AccountRowDTO row = findRow(result.rows, ho.Id);
        System.assertEquals('Prospect', row.lifecycle);
        System.assertEquals(opp.Id, row.openOppId);
    }

    @IsTest
    static void lifecycle_repeatCustomerWhenMultipleClosedWon() {
        Account ho = makeAccount('Repeat House', 'Charlotte');
        insert ho;
        Opportunity o1 = makeOpp(ho.Id, 'Closed Won', 'UMB');
        o1.CloseDate = Date.today().addDays(-10);
        Opportunity o2 = makeOpp(ho.Id, 'Closed Won', 'Design and Build');
        o2.CloseDate = Date.today().addDays(-5);
        insert new List<Opportunity>{ o1, o2 };

        Test.startTest();
        ODLAccountWorkspaceController.WorkspaceDataDTO result =
            ODLAccountWorkspaceController.getWorkspaceData();
        Test.stopTest();

        ODLAccountWorkspaceController.AccountRowDTO row = findRow(result.rows, ho.Id);
        System.assertEquals('Repeat Customer', row.lifecycle);
    }

    @IsTest
    static void health_atRiskWhenOpenWarranty() {
        Account ho = makeAccount('Warranty House', 'Asheville');
        insert ho;
        Warranty_Record__c w = new Warranty_Record__c(
            Homeowner_Account__c = ho.Id,
            Status__c = 'Open'
        );
        insert w;

        Test.startTest();
        ODLAccountWorkspaceController.WorkspaceDataDTO result =
            ODLAccountWorkspaceController.getWorkspaceData();
        Test.stopTest();

        ODLAccountWorkspaceController.AccountRowDTO row = findRow(result.rows, ho.Id);
        System.assertEquals('At Risk', row.health);
        System.assertEquals(1, row.openWarrantyCount);
        System.assertEquals('Resolve warranty', row.nextActionText);
    }

    @IsTest
    static void health_watchWhenNoActivityIn30Days() {
        Account ho = makeAccount('Cold House', 'Charlotte');
        insert ho;
        // Create a completed task 45 days in the past — controller picks this up
        Task t = new Task(
            WhatId       = ho.Id,
            Subject      = 'Old call',
            Status       = 'Completed',
            ActivityDate = Date.today().addDays(-45)
        );
        insert t;

        Test.startTest();
        ODLAccountWorkspaceController.WorkspaceDataDTO result =
            ODLAccountWorkspaceController.getWorkspaceData();
        Test.stopTest();

        ODLAccountWorkspaceController.AccountRowDTO row = findRow(result.rows, ho.Id);
        System.assertEquals('Watch', row.health);
        System.assertEquals('Re-engage', row.nextActionText);
    }

    @IsTest
    static void recordTypeIdIsReturned() {
        Account ho = makeAccount('RT Check', 'Charlotte');
        insert ho;

        Test.startTest();
        ODLAccountWorkspaceController.WorkspaceDataDTO result =
            ODLAccountWorkspaceController.getWorkspaceData();
        Test.stopTest();

        System.assertEquals(HOME_OWNER_RT_ID, result.homeOwnerRecordTypeId);
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private static ODLAccountWorkspaceController.AccountRowDTO findRow(
            List<ODLAccountWorkspaceController.AccountRowDTO> rows, Id accountId) {
        for (ODLAccountWorkspaceController.AccountRowDTO r : rows) {
            if (r.accountId == accountId) return r;
        }
        System.assert(false, 'Row not found for accountId: ' + accountId);
        return null;
    }
}
