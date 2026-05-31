@isTest
private class AquaPickupServiceTest {

    @TestSetup
    static void makeData() {
        // Community__c for lot lookup
        Community__c comm = new Community__c(Name = 'Pickup Test Community', Aqua_Active__c = true);
        insert comm;

        // Aqua_Pickup_Ticket__c.Community__c is a lookup to Opportunity
        Account acct = new Account(Name = 'Pickup Test Builder');
        insert acct;
        Opportunity opp = new Opportunity(
            Name      = 'Pickup Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acct.Id
        );
        insert opp;

        Lot__c lot = new Lot__c(
            Name              = 'Pickup Test Lot',
            Community__c      = comm.Id,
            Aqua_Installed__c = true
        );
        insert lot;

        Lot__c lot2 = new Lot__c(
            Name              = 'Already Queued Lot',
            Community__c      = comm.Id,
            Aqua_Installed__c = true
        );
        insert lot2;

        // Existing open pickup for lot2 — should not get duplicated
        Aqua_Pickup_Ticket__c existingPt = new Aqua_Pickup_Ticket__c(
            Lot__c            = lot2.Id,
            Aqua_Community__c = comm.Id,
            Status__c         = 'Open',
            Scheduled_Date__c = Date.today()
        );
        insert existingPt;

        Aqua_Master_Inventory__c master = new Aqua_Master_Inventory__c(
            Item_Type__c       = 'Controllers',
            Total_Purchased__c = 50,
            Unit_Cost__c       = 25.00
        );
        insert master;
    }

    @isTest
    static void testBulkRetrieve_SeasonEnded_NoOverride() {
        Date seasonEnd = Date.newInstance(Date.today().year(), 10, 31);
        if (Date.today() < seasonEnd) {
            try {
                Test.startTest();
                AquaPickupService.bulkRetrieve();
                Test.stopTest();
                System.assert(false, 'Expected AuraHandledException before season end');
            } catch (AuraHandledException e) {
                // AuraHandledException.getMessage() returns "Script-thrown exception" in test context
                System.assertNotEquals(null, e, 'Exception should have been thrown');
            }
        } else {
            Test.startTest();
            AquaPickupService.bulkRetrieve();
            Test.stopTest();
            List<Aqua_Pickup_Ticket__c> created = [SELECT Id FROM Aqua_Pickup_Ticket__c WHERE Status__c = 'Open'];
            System.assert(!created.isEmpty(), 'Should have created pickup tickets after season end');
        }
    }

    @isTest
    static void testReassignPickup() {
        Lot__c lot = [SELECT Id, Community__c FROM Lot__c WHERE Name = 'Pickup Test Lot' LIMIT 1];
        Community__c comm = [SELECT Id FROM Community__c WHERE Name = 'Pickup Test Community' LIMIT 1];
        Aqua_Pickup_Ticket__c pt = new Aqua_Pickup_Ticket__c(
            Lot__c            = lot.Id,
            Aqua_Community__c = comm.Id,
            Status__c         = 'Open',
            Scheduled_Date__c = Date.today()
        );
        insert pt;

        // Assigned_To__c is a User lookup
        Id userId = UserInfo.getUserId();

        Test.startTest();
        AquaPickupService.reassignPickup(pt.Id, userId);
        Test.stopTest();

        Aqua_Pickup_Ticket__c updated = [SELECT Assigned_To__c FROM Aqua_Pickup_Ticket__c WHERE Id = :pt.Id];
        System.assertEquals(userId, updated.Assigned_To__c, 'User should be assigned');
    }

    @isTest
    static void testReassignPickup_NullArgs() {
        try {
            Test.startTest();
            AquaPickupService.reassignPickup(null, null);
            Test.stopTest();
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            // AuraHandledException.getMessage() returns "Script-thrown exception" in test context
            System.assertNotEquals(null, e, 'Exception should be thrown');
        }
    }

    @isTest
    static void testCompleteReconciliation_Clean() {
        Lot__c lot = [SELECT Id FROM Lot__c WHERE Name = 'Pickup Test Lot' LIMIT 1];
        Community__c comm = [SELECT Id FROM Community__c WHERE Name = 'Pickup Test Community' LIMIT 1];
        Aqua_Pickup_Ticket__c pt = new Aqua_Pickup_Ticket__c(
            Lot__c            = lot.Id,
            Aqua_Community__c = comm.Id,
            Status__c         = 'Open',
            Scheduled_Date__c = Date.today()
        );
        insert pt;

        Test.startTest();
        AquaPickupService.completeReconciliation(pt.Id, true, 0, 0);
        Test.stopTest();

        Aqua_Pickup_Ticket__c updated = [
            SELECT Status__c, Device_Retrieved__c, Inventory_Reconciled__c,
                   Variance_Controllers__c, Variance_Heads__c
            FROM Aqua_Pickup_Ticket__c WHERE Id = :pt.Id
        ];
        System.assertEquals('Closed', updated.Status__c, 'Should be closed');
        System.assertEquals(true, updated.Device_Retrieved__c, 'Device retrieved should be true');
        System.assertEquals(true, updated.Inventory_Reconciled__c, 'Inventory reconciled should be true');
        System.assertEquals(0, updated.Variance_Controllers__c.intValue(), 'No controller variance');
        System.assertEquals(0, updated.Variance_Heads__c.intValue(), 'No head variance');

        List<Task> tasks = [SELECT Subject FROM Task WHERE Subject LIKE '%Variance%'];
        System.assertEquals(0, tasks.size(), 'No billing task for clean reconciliation');
    }

    @isTest
    static void testCompleteReconciliation_WithVariance() {
        Lot__c lot = [SELECT Id FROM Lot__c WHERE Name = 'Pickup Test Lot' LIMIT 1];
        Community__c comm = [SELECT Id FROM Community__c WHERE Name = 'Pickup Test Community' LIMIT 1];
        Aqua_Pickup_Ticket__c pt = new Aqua_Pickup_Ticket__c(
            Lot__c            = lot.Id,
            Aqua_Community__c = comm.Id,
            Status__c         = 'Open',
            Scheduled_Date__c = Date.today()
        );
        insert pt;

        Test.startTest();
        AquaPickupService.completeReconciliation(pt.Id, true, 2, 1);
        Test.stopTest();

        Aqua_Pickup_Ticket__c updated = [
            SELECT Variance_Controllers__c, Variance_Heads__c, Status__c
            FROM Aqua_Pickup_Ticket__c WHERE Id = :pt.Id
        ];
        System.assertEquals(2, updated.Variance_Controllers__c.intValue(), 'Controller variance should be 2');
        System.assertEquals(1, updated.Variance_Heads__c.intValue(), 'Head variance should be 1');

        List<Task> tasks = [SELECT Subject FROM Task WHERE Subject LIKE '%Variance%'];
        System.assertEquals(1, tasks.size(), 'Billing task should be created for variance');
    }

    @isTest
    static void testCompleteReconciliation_DeviceNotRetrieved() {
        Lot__c lot = [SELECT Id FROM Lot__c WHERE Name = 'Pickup Test Lot' LIMIT 1];
        Community__c comm = [SELECT Id FROM Community__c WHERE Name = 'Pickup Test Community' LIMIT 1];
        Aqua_Pickup_Ticket__c pt = new Aqua_Pickup_Ticket__c(
            Lot__c            = lot.Id,
            Aqua_Community__c = comm.Id,
            Status__c         = 'Open',
            Scheduled_Date__c = Date.today()
        );
        insert pt;

        try {
            Test.startTest();
            AquaPickupService.completeReconciliation(pt.Id, false, 0, 0);
            Test.stopTest();
            System.assert(false, 'Expected exception for device not retrieved');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception should be thrown');
        }
    }

    @isTest
    static void testBulkRetrieve_NoDuplicates() {
        Date seasonEnd = Date.newInstance(Date.today().year(), 10, 31);
        if (Date.today() < seasonEnd) {
            System.debug('Skipping bulkRetrieve_NoDuplicates test — season not ended');
            return;
        }
        Integer beforeCount = [SELECT COUNT() FROM Aqua_Pickup_Ticket__c];
        Test.startTest();
        AquaPickupService.bulkRetrieve();
        Test.stopTest();
        Integer afterCount = [SELECT COUNT() FROM Aqua_Pickup_Ticket__c];
        System.assertEquals(1, afterCount - beforeCount, 'Only 1 new pickup ticket expected');
    }

    @isTest
    static void testBulkRetrieve_WithBypass_CreatesTickets() {
        // Uses @TestVisible bypass to exercise bulk retrieve body regardless of season date
        Integer beforeCount = [SELECT COUNT() FROM Aqua_Pickup_Ticket__c];
        AquaPickupService.skipSeasonGateForTest = true;
        Test.startTest();
        AquaPickupService.bulkRetrieve();
        Test.stopTest();
        Integer afterCount = [SELECT COUNT() FROM Aqua_Pickup_Ticket__c];
        // Lot 'Pickup Test Lot' should get a ticket; 'Already Queued Lot' should be skipped
        System.assertEquals(1, afterCount - beforeCount, 'Only 1 new ticket should be created (lot2 already has one)');
    }

    @isTest
    static void testBulkRetrieve_WithBypass_NoActiveLots() {
        // Remove Aqua_Installed__c from all lots so bulkRetrieve returns early
        List<Lot__c> lots = [SELECT Id, Aqua_Installed__c FROM Lot__c];
        for (Lot__c l : lots) l.Aqua_Installed__c = false;
        update lots;

        Integer beforeCount = [SELECT COUNT() FROM Aqua_Pickup_Ticket__c];
        AquaPickupService.skipSeasonGateForTest = true;
        Test.startTest();
        AquaPickupService.bulkRetrieve();
        Test.stopTest();
        Integer afterCount = [SELECT COUNT() FROM Aqua_Pickup_Ticket__c];
        System.assertEquals(0, afterCount - beforeCount, 'No tickets should be created when no active lots');
    }
}