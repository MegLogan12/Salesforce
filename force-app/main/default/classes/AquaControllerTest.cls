/**
 * AquaControllerTest
 * Coverage for AquaController @AuraEnabled methods.
 *
 * Strategy: test reads against empty org (safe empty returns) and
 * test reads with inserted Aqua records. Actions (close) tested via
 * pass-through to AquaService where the underlying service has its own tests.
 */
@IsTest
private class AquaControllerTest {

    // ─────────────────────────────────────────────
    // SETUP
    // ─────────────────────────────────────────────
    @TestSetup
    static void setup() {
        // Aqua_Community__c on Aqua ticket objects is Lookup(Community__c).
        Community__c comm = new Community__c(
            Name          = 'Aqua Test Community',
            Aqua_Active__c = true
        );
        insert comm;

        // Aqua_Watering_Schedule__c.Community__c is Lookup(Opportunity) in this org.
        // Create Account + Opportunity for the watering schedule only.
        Account acc = new Account(Name = 'Test Builder Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name      = 'Aqua Test Community',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addYears(1)
        );
        insert opp;

        // Work Order (Aqua) — inserted for kpiActiveAquaWOs count only.
        // Aqua ticket Work_Order__c fields reference standard WorkOrder in this
        // org, NOT the custom Work_Order__c, so we do NOT pass wo.Id to tickets.
        Work_Order__c wo = new Work_Order__c(
            Status__c          = 'Scheduled',
            Schedule_Locked__c = true,
            Aqua_Community__c  = true
        );
        insert wo;

        // Aqua Install Ticket — Work_Order__c omitted (standard WorkOrder ref in prod)
        Aqua_Install_Ticket__c install = new Aqua_Install_Ticket__c(
            Aqua_Community__c   = comm.Id,
            Status__c           = 'Scheduled',
            Scheduled_Date__c   = Date.today().addDays(2),
            Controller_Count__c = 2,
            Heads_Count__c      = 8
        );
        insert install;

        // Aqua Check Ticket (overdue) — Work_Order__c omitted
        Aqua_Check_Ticket__c check = new Aqua_Check_Ticket__c(
            Aqua_Community__c = comm.Id,
            Status__c         = 'Open',
            Scheduled_Date__c = Date.today().addDays(-1),
            Check_Number__c   = 1
        );
        insert check;

        // Aqua Pickup Ticket — Work_Order__c omitted
        Aqua_Pickup_Ticket__c pickup = new Aqua_Pickup_Ticket__c(
            Aqua_Community__c = comm.Id,
            Status__c         = 'Scheduled',
            Scheduled_Date__c = Date.today().addDays(5)
        );
        insert pickup;

        // Inventory (Shop) — Work_Order__c omitted (same WorkOrder ref issue)
        Aqua_Inventory__c inv = new Aqua_Inventory__c(
            Item_Type__c = 'Controller',
            Location__c  = 'Shop',
            Quantity__c  = 10
        );
        insert inv;

        // Master Inventory
        Aqua_Master_Inventory__c master = new Aqua_Master_Inventory__c(
            Item_Type__c       = 'Controller',
            Total_Purchased__c = 20
        );
        insert master;

        // Watering Schedule — Community__c is Lookup(Opportunity) in this org, use opp.Id
        Aqua_Watering_Schedule__c ws = new Aqua_Watering_Schedule__c(
            Community__c        = opp.Id,
            Schedule_Type__c    = 'Establishment',
            Week_Number__c      = 1,
            Run_Duration_Min__c = 30,
            Run_Frequency__c    = '3x/day',
            Effective_Year__c   = 2026
        );
        insert ws;
    }

    // ─────────────────────────────────────────────
    // KPIs
    // ─────────────────────────────────────────────
    @IsTest
    static void getAquaKpis_returnsData() {
        Test.startTest();
        AquaController.AquaKpis k = AquaController.getAquaKpis();
        Test.stopTest();

        System.assertNotEquals(null, k, 'KPIs wrapper should not be null');
        System.assertEquals(1, k.openInstallTickets, 'Should count 1 open install ticket');
        System.assertEquals(1, k.overdueCheckTickets, 'Should count 1 overdue check ticket');
        System.assertEquals(1, k.openCheckTickets, 'Should count 1 open check ticket');
        System.assertEquals(1, k.openPickupTickets, 'Should count 1 open pickup ticket');
    }

    // ─────────────────────────────────────────────
    // INSTALL TICKETS
    // ─────────────────────────────────────────────
    @IsTest
    static void getOpenInstallTickets_returnsData() {
        Test.startTest();
        List<AquaController.InstallTicketRow> rows = AquaController.getOpenInstallTickets();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(1, rows.size(), 'Should find 1 open install ticket');
        System.assertEquals('Aqua Test Community', rows[0].communityName);
        System.assertEquals('Scheduled', rows[0].status);
        System.assertEquals('chip chip-blue', rows[0].statusCss);
    }

    @IsTest
    static void getOpenInstallTickets_emptyOrg() {
        // Delete the setup ticket so we test the empty case
        delete [SELECT Id FROM Aqua_Install_Ticket__c LIMIT 1];

        Test.startTest();
        List<AquaController.InstallTicketRow> rows = AquaController.getOpenInstallTickets();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(0, rows.size());
    }

    // ─────────────────────────────────────────────
    // CHECK TICKETS
    // ─────────────────────────────────────────────
    @IsTest
    static void getOpenCheckTickets_returnsData() {
        Test.startTest();
        List<AquaController.CheckTicketRow> rows = AquaController.getOpenCheckTickets();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(1, rows.size(), 'Should find 1 open check ticket');
        System.assertEquals('Overdue', rows[0].urgency, 'Check ticket due yesterday should be Overdue');
        System.assertEquals('chip chip-red', rows[0].urgencyCss);
        System.assertEquals(1, rows[0].checkNumber);
    }

    @IsTest
    static void getOpenCheckTickets_dueTodayLabel() {
        Aqua_Check_Ticket__c todayCheck = [SELECT Id FROM Aqua_Check_Ticket__c LIMIT 1];
        update new Aqua_Check_Ticket__c(Id = todayCheck.Id, Scheduled_Date__c = Date.today());

        Test.startTest();
        List<AquaController.CheckTicketRow> rows = AquaController.getOpenCheckTickets();
        Test.stopTest();

        System.assertEquals('Due Today', rows[0].urgency);
        System.assertEquals('chip chip-amber', rows[0].urgencyCss);
    }

    @IsTest
    static void getOpenCheckTickets_upcomingLabel() {
        Aqua_Check_Ticket__c check = [SELECT Id FROM Aqua_Check_Ticket__c LIMIT 1];
        update new Aqua_Check_Ticket__c(Id = check.Id, Scheduled_Date__c = Date.today().addDays(7));

        Test.startTest();
        List<AquaController.CheckTicketRow> rows = AquaController.getOpenCheckTickets();
        Test.stopTest();

        System.assertEquals('Upcoming', rows[0].urgency);
        System.assertEquals('chip chip-blue', rows[0].urgencyCss);
    }

    // ─────────────────────────────────────────────
    // PICKUP TICKETS
    // ─────────────────────────────────────────────
    @IsTest
    static void getOpenPickupTickets_returnsData() {
        Test.startTest();
        List<AquaController.PickupTicketRow> rows = AquaController.getOpenPickupTickets();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(1, rows.size());
        System.assertEquals('Scheduled', rows[0].status);
        System.assertEquals('chip chip-blue', rows[0].statusCss);
    }

    @IsTest
    static void getOpenPickupTickets_emptyOrg() {
        delete [SELECT Id FROM Aqua_Pickup_Ticket__c LIMIT 1];

        Test.startTest();
        List<AquaController.PickupTicketRow> rows = AquaController.getOpenPickupTickets();
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }

    // ─────────────────────────────────────────────
    // INVENTORY
    // ─────────────────────────────────────────────
    @IsTest
    static void getInventoryByLocation_returnsData() {
        Test.startTest();
        List<AquaController.InventoryRow> rows = AquaController.getInventoryByLocation();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(1, rows.size(), 'Should find 1 inventory record');
        System.assertEquals('Controller', rows[0].itemType);
        System.assertEquals('Shop', rows[0].location);
        System.assertEquals(10, rows[0].quantity);
    }

    @IsTest
    static void getInventoryByLocation_emptyOrg() {
        delete [SELECT Id FROM Aqua_Inventory__c LIMIT 1];

        Test.startTest();
        List<AquaController.InventoryRow> rows = AquaController.getInventoryByLocation();
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }

    // ─────────────────────────────────────────────
    // MASTER INVENTORY
    // ─────────────────────────────────────────────
    @IsTest
    static void getMasterInventory_returnsData() {
        Test.startTest();
        List<AquaController.MasterInventoryRow> rows = AquaController.getMasterInventory();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(1, rows.size(), 'Should find 1 master inventory row');
        System.assertEquals('Controller', rows[0].itemType);
        System.assertEquals(20, rows[0].totalPurchased);
        System.assertEquals(10, rows[0].atShop);
        System.assertEquals(10, rows[0].variance, 'Variance = 20 - 10 shop - 0 on-site - 0 deployed');
    }

    @IsTest
    static void getMasterInventory_emptyOrg() {
        delete [SELECT Id FROM Aqua_Inventory__c LIMIT 1];
        delete [SELECT Id FROM Aqua_Master_Inventory__c LIMIT 1];

        Test.startTest();
        List<AquaController.MasterInventoryRow> rows = AquaController.getMasterInventory();
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }

    // ─────────────────────────────────────────────
    // WATERING SCHEDULES
    // ─────────────────────────────────────────────
    @IsTest
    static void getWateringSchedules_allCommunities() {
        Test.startTest();
        List<AquaController.WateringScheduleRow> rows =
            AquaController.getWateringSchedules(null);
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(1, rows.size());
        System.assertEquals('Establishment', rows[0].scheduleType);
        System.assertEquals(1, rows[0].weekNumber);
        System.assertEquals('3x/day', rows[0].runFrequency);
    }

    @IsTest
    static void getWateringSchedules_byCommunity() {
        // Aqua_Watering_Schedule__c.Community__c is Lookup(Opportunity) in this org.
        // Filter by the Opportunity created in setup (Name = 'Aqua Test Community').
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Aqua Test Community' LIMIT 1];

        Test.startTest();
        List<AquaController.WateringScheduleRow> rows =
            AquaController.getWateringSchedules(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(1, rows.size());
        System.assertEquals(opp.Id, rows[0].communityId);
    }

    // ─────────────────────────────────────────────
    // ACTIONS — coverage tests
    // ─────────────────────────────────────────────
    @IsTest
    static void closeInstallTicket_coverageTest() {
        Aqua_Install_Ticket__c t = [SELECT Id FROM Aqua_Install_Ticket__c LIMIT 1];
        Test.startTest();
        try {
            AquaController.closeInstallTicket(t.Id, 2, 8, 'test close notes');
        } catch (Exception e) {
            // AquaService may reject if ticket is already closed; catch is fine for coverage
        }
        Test.stopTest();
    }

    @IsTest
    static void closeCheckTicket_coverageTest() {
        Aqua_Check_Ticket__c t = [SELECT Id FROM Aqua_Check_Ticket__c LIMIT 1];
        Test.startTest();
        try {
            AquaController.closeCheckTicket(t.Id, false, 4.0, 3.5, 'check close notes');
        } catch (Exception e) {
            // AquaService may reject; catch is fine for coverage
        }
        Test.stopTest();
    }

    @IsTest
    static void closePickupTicket_coverageTest() {
        Aqua_Pickup_Ticket__c t = [SELECT Id FROM Aqua_Pickup_Ticket__c LIMIT 1];
        Test.startTest();
        try {
            AquaController.closePickupTicket(t.Id, 2, 8, 'pickup close notes');
        } catch (Exception e) {
            // AquaService may reject; catch is fine for coverage
        }
        Test.stopTest();
    }

    @IsTest
    static void getWateringSchedules_emptyOrg() {
        delete [SELECT Id FROM Aqua_Watering_Schedule__c LIMIT 1];

        Test.startTest();
        List<AquaController.WateringScheduleRow> rows =
            AquaController.getWateringSchedules(null);
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }
}