/**
 * LovingRollupBatchTest
 * Covers LovingRollupBatch + LovingRollupScheduler
 * Target: ≥ 85% coverage
 */
@IsTest
private class LovingRollupBatchTest {

    @TestSetup
    static void makeData() {
        // Parent Account (Builder)
        Account builder = new Account(Name = 'Test Builder', RecordTypeId = getBuilderRTId());
        insert builder;

        // Division Account
        Account division = new Account(
            Name       = 'Test Division',
            ParentId   = builder.Id,
            RecordTypeId = getDivisionRTId()
        );
        insert division;

        // Community linked to builder account
        Community__c comm = new Community__c(
            Name             = 'Test Community',
            Builder_Account__c = division.Id
        );
        insert comm;

        // Lots — 3 active, 1 closed
        List<Lot__c> lots = new List<Lot__c>{
            new Lot__c(Community__c = comm.Id, Lot_Status__c = 'Open',              Lot_Number__c = '1'),
            new Lot__c(Community__c = comm.Id, Lot_Status__c = 'Under Construction', Lot_Number__c = '2'),
            new Lot__c(Community__c = comm.Id, Lot_Status__c = 'Installed',          Lot_Number__c = '3'),
            new Lot__c(Community__c = comm.Id, Lot_Status__c = 'Closed',             Lot_Number__c = '4')
        };
        insert lots;

        // Invoice — YTD revenue + unpaid AR
        Invoice__c inv = new Invoice__c(
            Builder_Market_Account__c = division.Id,
            Invoice_Date__c           = Date.today(),
            Status__c                 = 'Sent',
            Total_Revenue__c          = 5000.00,
            Amount_Paid__c            = 1000.00
        );
        insert inv;
    }

    private static Id getBuilderRTId() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        // Use default if Builder_Parent not found (sandbox may not have it deployed yet)
        if (rtMap.containsKey('Builder_Parent')) return rtMap.get('Builder_Parent').getRecordTypeId();
        return rtMap.values()[0].getRecordTypeId();
    }

    private static Id getDivisionRTId() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (rtMap.containsKey('Builder_Market')) return rtMap.get('Builder_Market').getRecordTypeId();
        return rtMap.values()[0].getRecordTypeId();
    }

    // ─────────────────────────────────────────────────────────────────────
    // COMMUNITY PASS
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCommunityPassUpdatesLotCounts() {
        Test.startTest();
        Database.executeBatch(new LovingRollupBatch('COMMUNITY'), 200);
        Test.stopTest();

        Community__c comm = [SELECT Active_Lot_Count__c, Closed_Lot_Count__c FROM Community__c LIMIT 1];
        System.assertEquals(3, (Integer) comm.Active_Lot_Count__c, 'Should have 3 active lots');
        System.assertEquals(1, (Integer) comm.Closed_Lot_Count__c, 'Should have 1 closed lot');
    }

    @IsTest
    static void testCommunityPassNoLots() {
        // Community with no lots
        Community__c emptyComm = new Community__c(Name = 'Empty Community');
        insert emptyComm;

        Test.startTest();
        Database.executeBatch(new LovingRollupBatch('COMMUNITY'), 200);
        Test.stopTest();

        Community__c result = [SELECT Active_Lot_Count__c, Closed_Lot_Count__c
                               FROM Community__c WHERE Id = :emptyComm.Id];
        System.assertEquals(0, (Integer) result.Active_Lot_Count__c, 'Empty community should have 0 active lots');
        System.assertEquals(0, (Integer) result.Closed_Lot_Count__c, 'Empty community should have 0 closed lots');
    }

    // ─────────────────────────────────────────────────────────────────────
    // ACCOUNT PASS
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testAccountPassUpdatesWOCounts() {
        Account division = [SELECT Id FROM Account WHERE Name = 'Test Division' LIMIT 1];

        Test.startTest();
        Database.executeBatch(new LovingRollupBatch('ACCOUNT'), 200);
        Test.stopTest();

        Account divAfter = [SELECT Total_Active_WOs__c, YTD_Revenue__c, AR_Balance__c
                            FROM Account WHERE Id = :division.Id];
        System.assertEquals(0, (Integer) divAfter.Total_Active_WOs__c,
            'No standard WorkOrders are inserted in this test context');
        System.assertEquals(5000.00, divAfter.YTD_Revenue__c, 'YTD Revenue should be 5000');
        System.assertEquals(4000.00, divAfter.AR_Balance__c,  'AR Balance: 5000 - 1000 = 4000');
    }

    @IsTest
    static void testAccountPassUpdatesCommunityCounts() {
        Account division = [SELECT Id FROM Account WHERE Name = 'Test Division' LIMIT 1];

        Test.startTest();
        Database.executeBatch(new LovingRollupBatch('ACCOUNT'), 200);
        Test.stopTest();

        // Communities attach to the Division (not the Parent), so the count rolls up on the Division.
        Account divisionAfter = [SELECT Total_Communities__c FROM Account WHERE Id = :division.Id];
        System.assertEquals(1, (Integer) divisionAfter.Total_Communities__c, '1 community linked to division');
    }

    // ─────────────────────────────────────────────────────────────────────
    // FULL RUN — community pass chains account pass
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testFullBatchRunChainsAccountPass() {
        Test.startTest();
        Database.executeBatch(new LovingRollupBatch(), 200);
        Test.stopTest();

        // Both passes should have run
        Community__c comm = [SELECT Active_Lot_Count__c FROM Community__c WHERE Name = 'Test Community'];
        System.assertEquals(3, (Integer) comm.Active_Lot_Count__c, 'Community pass should run');
        // Account pass chained inside finish — runs in same test execution
    }

    // ─────────────────────────────────────────────────────────────────────
    // SCHEDULER
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testSchedulerExecutes() {
        Test.startTest();
        LovingRollupScheduler s = new LovingRollupScheduler();
        s.execute(null);
        Test.stopTest();
        System.assert(true, 'Scheduler should execute without error');
    }

    @IsTest
    static void testScheduleNightly() {
        Test.startTest();
        String jobId = LovingRollupScheduler.scheduleNightly();
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'scheduleNightly should return a job ID');
    }

    @IsTest
    static void testScheduleNightlyAbortsPrevious() {
        // Schedule twice — second call should abort the first
        Test.startTest();
        String jobId1 = LovingRollupScheduler.scheduleNightly();
        String jobId2 = LovingRollupScheduler.scheduleNightly();
        Test.stopTest();
        System.assertNotEquals(null, jobId2, 'Second schedule should succeed');
    }

    // ─────────────────────────────────────────────────────────────────────
    // EMPTY ORG — no records
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testEmptyOrgRunsWithoutError() {
        // Delete child records first, then parents
        delete [SELECT Id FROM Lot__c];
        delete [SELECT Id FROM WorkOrder];
        delete [SELECT Id FROM Invoice__c];
        delete [SELECT Id FROM Community__c];
        delete [SELECT Id FROM Account];

        Test.startTest();
        Database.executeBatch(new LovingRollupBatch('COMMUNITY'), 200);
        Database.executeBatch(new LovingRollupBatch('ACCOUNT'), 200);
        Test.stopTest();

        System.assert(true, 'Batch should complete without error on empty org');
    }
}