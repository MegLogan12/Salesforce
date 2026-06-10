@IsTest
private class PullListControllerTest {

    @TestSetup
    static void makeData() {
        Item_Catalog__c item = new Item_Catalog__c(
            Name = 'Test Item',
            Item_Number__c = 'ITM-001',
            Storage_Location__c = 'IWA1',
            Quantity_On_Hand__c = 50
        );
        insert item;

        Account acct = new Account(Name = 'Pull Test Account');
        insert acct;

        Id installRt = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName()
            .get('Production_Install').getRecordTypeId();

        WorkOrder wo = new WorkOrder(
            Subject = 'Pull Test WO',
            AccountId = acct.Id,
            RecordTypeId = installRt,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status__c = 'Scheduled',
            Schedule_Locked__c = true,
            Scheduled_Date__c = Date.today(),
            Work_Order_Type__c = 'Production Install'
        );
        insert wo;

        Pull_Ticket__c pt = new Pull_Ticket__c(
            Work_Order__c = wo.Id,
            Item_Catalog__c = item.Id,
            Quantity_Requested__c = 10,
            Scheduled_Date__c = Date.today(),
            Status__c = 'Pending Pull'
        );
        insert pt;
    }

    // ── getPullList ───────────────────────────────────────────────────────────

    @IsTest
    static void getPullList_returnsScheduledTickets() {
        Test.startTest();
        List<PullListController.PullTicketDTO> dtos =
            PullListController.getPullList(Date.today());
        Test.stopTest();

        System.assertNotEquals(null, dtos);
        System.assertEquals(1, dtos.size(), 'Should return one pending pull ticket for today');
        System.assertEquals('Pending Pull', dtos[0].status);
        System.assertNotEquals(null, dtos[0].storageLocation, 'Storage location should be populated from Item Catalog');
        System.assertNotEquals(null, dtos[0].itemNumber, 'Item number should be populated');
    }

    @IsTest
    static void getPullList_nullDate_defaultsToday() {
        Test.startTest();
        List<PullListController.PullTicketDTO> dtos =
            PullListController.getPullList(null);
        Test.stopTest();
        System.assertNotEquals(null, dtos);
        System.assertEquals(1, dtos.size());
    }

    @IsTest
    static void getPullList_excludesNonLockedWOs() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Pull Test Account' LIMIT 1];
        Id installRt = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName()
            .get('Production_Install').getRecordTypeId();
        WorkOrder unlocked = new WorkOrder(
            Subject = 'Unlocked WO',
            AccountId = acct.Id,
            RecordTypeId = installRt,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status__c = 'Ready to Schedule',
            Schedule_Locked__c = false,
            Scheduled_Date__c = Date.today(),
            Work_Order_Type__c = 'Production Install'
        );
        insert unlocked;
        Item_Catalog__c item = [SELECT Id FROM Item_Catalog__c LIMIT 1];
        insert new Pull_Ticket__c(
            Work_Order__c = unlocked.Id,
            Item_Catalog__c = item.Id,
            Quantity_Requested__c = 5,
            Scheduled_Date__c = Date.today(),
            Status__c = 'Pending Pull'
        );

        Test.startTest();
        List<PullListController.PullTicketDTO> dtos =
            PullListController.getPullList(Date.today());
        Test.stopTest();

        System.assertEquals(1, dtos.size(), 'Unlocked WO pull ticket must be excluded from the pull list');
    }

    @IsTest
    static void getPullList_excludesFutureDates() {
        Test.startTest();
        List<PullListController.PullTicketDTO> dtos =
            PullListController.getPullList(Date.today().addDays(7));
        Test.stopTest();
        System.assertEquals(0, dtos.size(), 'No tickets for a future date');
    }

    // ── confirmPull ───────────────────────────────────────────────────────────

    @IsTest
    static void confirmPull_happyPath() {
        Pull_Ticket__c pt = [SELECT Id FROM Pull_Ticket__c LIMIT 1];
        Id userId = UserInfo.getUserId();

        Test.startTest();
        PullListController.ActionResult result =
            PullListController.confirmPull(pt.Id, 10, userId);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        Pull_Ticket__c updated = [
            SELECT Status__c, Quantity_Pulled__c, Pulled_By__c, Pulled_Date__c
            FROM Pull_Ticket__c WHERE Id = :pt.Id
        ];
        System.assertEquals('Pulled', updated.Status__c);
        System.assertEquals(10, updated.Quantity_Pulled__c);
        System.assertEquals(userId, updated.Pulled_By__c);
        System.assertNotEquals(null, updated.Pulled_Date__c);

        Item_Catalog__c item = [SELECT Quantity_On_Hand__c FROM Item_Catalog__c LIMIT 1];
        System.assertEquals(40, item.Quantity_On_Hand__c, 'Quantity on hand should decrement from 50 to 40');
    }

    @IsTest
    static void confirmPull_nullId_returnsError() {
        Test.startTest();
        PullListController.ActionResult result =
            PullListController.confirmPull(null, 5, UserInfo.getUserId());
        Test.stopTest();
        System.assertEquals(false, result.success);
    }

    @IsTest
    static void confirmPull_zeroQty_blocked() {
        Pull_Ticket__c pt = [SELECT Id FROM Pull_Ticket__c LIMIT 1];
        Test.startTest();
        PullListController.ActionResult result =
            PullListController.confirmPull(pt.Id, 0, UserInfo.getUserId());
        Test.stopTest();
        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('quantity'), result.message);
    }

    @IsTest
    static void confirmPull_nullQty_blocked() {
        Pull_Ticket__c pt = [SELECT Id FROM Pull_Ticket__c LIMIT 1];
        Test.startTest();
        PullListController.ActionResult result =
            PullListController.confirmPull(pt.Id, null, UserInfo.getUserId());
        Test.stopTest();
        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('quantity'), result.message);
    }

    @IsTest
    static void confirmPull_nullUser_blocked() {
        Pull_Ticket__c pt = [SELECT Id FROM Pull_Ticket__c LIMIT 1];
        Test.startTest();
        PullListController.ActionResult result =
            PullListController.confirmPull(pt.Id, 5, null);
        Test.stopTest();
        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('user'), result.message);
    }

    @IsTest
    static void confirmPull_noItemCatalog_blocked() {
        WorkOrder wo = [SELECT Id FROM WorkOrder WHERE Schedule_Locked__c = true LIMIT 1];
        Pull_Ticket__c noItem = new Pull_Ticket__c(
            Work_Order__c = wo.Id,
            Quantity_Requested__c = 5,
            Scheduled_Date__c = Date.today(),
            Status__c = 'Pending Pull'
        );
        insert noItem;

        Test.startTest();
        PullListController.ActionResult result =
            PullListController.confirmPull(noItem.Id, 5, UserInfo.getUserId());
        Test.stopTest();
        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('item catalog') || result.message.containsIgnoreCase('item'), result.message);
    }

    @IsTest
    static void confirmPull_noStorageLocation_blocked() {
        Item_Catalog__c noLoc = new Item_Catalog__c(
            Name = 'No Location Item',
            Item_Number__c = 'ITM-002',
            Quantity_On_Hand__c = 10
        );
        insert noLoc;
        WorkOrder wo = [SELECT Id FROM WorkOrder WHERE Schedule_Locked__c = true LIMIT 1];
        Pull_Ticket__c pt = new Pull_Ticket__c(
            Work_Order__c = wo.Id,
            Item_Catalog__c = noLoc.Id,
            Quantity_Requested__c = 5,
            Scheduled_Date__c = Date.today(),
            Status__c = 'Pending Pull'
        );
        insert pt;

        Test.startTest();
        PullListController.ActionResult result =
            PullListController.confirmPull(pt.Id, 5, UserInfo.getUserId());
        Test.stopTest();
        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('storage location') || result.message.containsIgnoreCase('location'), result.message);
    }

    @IsTest
    static void confirmPull_unscheduledWO_blocked() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Pull Test Account' LIMIT 1];
        Id installRt = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName()
            .get('Production_Install').getRecordTypeId();
        WorkOrder unlocked = new WorkOrder(
            Subject = 'Not Scheduled',
            AccountId = acct.Id,
            RecordTypeId = installRt,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status__c = 'Ready to Schedule',
            Schedule_Locked__c = false,
            Work_Order_Type__c = 'Production Install'
        );
        insert unlocked;
        Item_Catalog__c item = [SELECT Id FROM Item_Catalog__c WHERE Storage_Location__c != null LIMIT 1];
        Pull_Ticket__c pt = new Pull_Ticket__c(
            Work_Order__c = unlocked.Id,
            Item_Catalog__c = item.Id,
            Quantity_Requested__c = 5,
            Scheduled_Date__c = Date.today(),
            Status__c = 'Pending Pull'
        );
        insert pt;

        Test.startTest();
        PullListController.ActionResult result =
            PullListController.confirmPull(pt.Id, 5, UserInfo.getUserId());
        Test.stopTest();
        System.assertEquals(false, result.success);
        System.assert(
            result.message.containsIgnoreCase('scheduled') || result.message.containsIgnoreCase('work order'),
            result.message
        );
    }

    @IsTest
    static void confirmPull_alreadyPulled_blocked() {
        Pull_Ticket__c pt = [SELECT Id FROM Pull_Ticket__c LIMIT 1];
        update new Pull_Ticket__c(Id = pt.Id, Status__c = 'Pulled');

        Test.startTest();
        PullListController.ActionResult result =
            PullListController.confirmPull(pt.Id, 5, UserInfo.getUserId());
        Test.stopTest();
        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('already'), result.message);
    }

    @IsTest
    static void confirmPull_cancelledTicket_blocked() {
        Pull_Ticket__c pt = [SELECT Id FROM Pull_Ticket__c LIMIT 1];
        update new Pull_Ticket__c(Id = pt.Id, Status__c = 'Cancelled');

        Test.startTest();
        PullListController.ActionResult result =
            PullListController.confirmPull(pt.Id, 5, UserInfo.getUserId());
        Test.stopTest();
        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('cancelled'), result.message);
    }
}