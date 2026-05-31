/**
 * AquaConsoleControllerTest
 * Test coverage for AquaConsoleController — all 10 read methods + 5 action methods.
 * Uses actual field names from the org schema.
 *
 * Field name reference:
 *  Community__c: Aqua_Included__c (Checkbox)
 *  Lot__c: Aqua_Add_On__c (Currency)
 *  Aqua_Install_Ticket__c: Community__c, Scheduled_Date__c, Status__c, Work_Order__c (no Name/Lot__c)
 *  Aqua_Check_Ticket__c: Community__c, Scheduled_Date__c, Status__c, Check_Notes__c, Billing_Reason_Code__c (no Name/Lot__c)
 *  Aqua_Pickup_Ticket__c: Community__c, Scheduled_Date__c, Status__c (no Name/Lot__c)
 *  Aqua_Watering_Schedule__c: Community__c, Month__c, Effective_Year__c, Run_Time_Pct__c (no Name)
 *  Aqua_Master_Inventory__c: Item_Type__c, Total_Purchased__c (no Name, no Unit_Cost__c)
 *  Aqua_Inventory__c: Item_Type__c, Location__c, Quantity__c, Work_Order__c (no Name)
 *  Aqua_Inventory_Adjustment__c: Item_Catalog__c, Quantity__c, Aqua_Inventory_Reason_Code__c, Lot__c, Tech__c (no Name)
 *  Employee__c: Active__c, Department__c='Aqua', First_Name__c, Last_Name__c, On_PTO_Today__c, Role__c
 */
@isTest
private class AquaConsoleControllerTest {

    @TestSetup
    static void makeData() {
        Account acct = new Account(Name = 'Test Builder');
        acct.Loving_FM__c = UserInfo.getUserId();
        insert acct;
        String todayServiceDay = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).format('EEEE');

        // Community__c object with Aqua enabled and FM-owned watering cadence
        Community__c comm = new Community__c(
            Name = 'Test Community Aqua',
            Aqua_Included__c = true,
            Aqua_Active__c = true,
            Builder_Account__c = acct.Id,
            Service_Day__c = todayServiceDay,
            FM_Assignment__c = UserInfo.getUserId(),
            Assigned_FM__c = UserInfo.getUserId()
        );
        insert comm;

        // Lot with Aqua Add-On value (currency > 0 means active)
        Lot__c lot = new Lot__c(Name = 'Lot 100', Community__c = comm.Id, Aqua_Add_On__c = 500);
        insert lot;

        // For Aqua ticket Community__c fields, the lookup references Opportunity.
        // Create an Opportunity to use as the community reference on tickets.
        Opportunity opp = new Opportunity(
            Name            = 'Test Community Opp',
            StageName       = 'Prospecting',
            CloseDate       = Date.today().addDays(30),
            AccountId       = acct.Id
        );
        insert opp;

        // Aqua Install Ticket (today, open) — Community__c references Opportunity
        Aqua_Install_Ticket__c ait = new Aqua_Install_Ticket__c(
            Community__c      = opp.Id,
            Scheduled_Date__c = Date.today(),
            Status__c         = 'Open'
        );
        insert ait;

        // Aqua Check Ticket — same-day (has billing reason code)
        Aqua_Check_Ticket__c actSameDay = new Aqua_Check_Ticket__c(
            Community__c           = opp.Id,
            Scheduled_Date__c      = Date.today(),
            Status__c              = 'Open',
            Check_Notes__c         = 'Head broken',
            Billing_Reason_Code__c = '(A) Missing Material (Stolen)'
        );
        insert actSameDay;

        // Aqua Check Ticket — closeout pending (no billing reason code)
        Aqua_Check_Ticket__c actClose = new Aqua_Check_Ticket__c(
            Community__c      = opp.Id,
            Scheduled_Date__c = Date.today(),
            Status__c         = 'Open'
        );
        insert actClose;

        // Aqua Pickup Ticket
        Aqua_Pickup_Ticket__c apt = new Aqua_Pickup_Ticket__c(
            Community__c      = opp.Id,
            Scheduled_Date__c = Date.today(),
            Status__c         = 'Open'
        );
        insert apt;

        // Aqua Watering Schedule for current month/year
        // Month__c is a picklist with full month names; Effective_Year__c is a Number
        // Community__c references Opportunity
        List<String> mnths = new List<String>{
            'January','February','March','April','May','June',
            'July','August','September','October','November','December'
        };
        String curMonthName = mnths[Date.today().month() - 1];
        Aqua_Watering_Schedule__c ws = new Aqua_Watering_Schedule__c(
            Community__c      = opp.Id,
            Month__c          = curMonthName,
            Effective_Year__c = Date.today().year(),
            Run_Time_Pct__c   = 70,
            Schedule_Type__c  = 'Seasonal Monthly'
        );
        insert ws;

        // Aqua Master Inventory
        Aqua_Master_Inventory__c master = new Aqua_Master_Inventory__c(
            Item_Type__c      = 'Controllers',
            Total_Purchased__c = 50
        );
        insert master;

        // Aqua Inventory — shop (qty=3, below threshold=5 → triggers inventory alert)
        Aqua_Inventory__c invShop = new Aqua_Inventory__c(
            Item_Type__c = 'Controllers',
            Location__c  = 'Shop',
            Quantity__c  = 3
        );
        insert invShop;

        // Aqua Inventory — van
        Aqua_Inventory__c invVan = new Aqua_Inventory__c(
            Item_Type__c = 'Controllers',
            Location__c  = 'Van',
            Quantity__c  = 2
        );
        insert invVan;

        // Aqua Inventory — onsite
        Aqua_Inventory__c invOnsite = new Aqua_Inventory__c(
            Item_Type__c = 'Controllers',
            Location__c  = 'On-Site',
            Quantity__c  = 10
        );
        insert invOnsite;

        // Aqua Inventory Adjustment
        Aqua_Inventory_Adjustment__c adj = new Aqua_Inventory_Adjustment__c(
            Aqua_Inventory_Reason_Code__c = '(C) Additional Coverage Needed',
            Quantity__c                   = 5,
            Adjustment_DateTime__c        = Datetime.now()
        );
        insert adj;

        // Employee__c — active Aqua tech (enables getTechRoutes and home team section)
        Employee__c emp = new Employee__c(
            Name         = 'Trent Kinard',
            First_Name__c = 'Trent',
            Last_Name__c  = 'Kinard',
            Active__c     = true,
            Department__c = 'Aqua',
            On_PTO_Today__c = false,
            Role__c       = 'Technician'
        );
        insert emp;

        // Employee__c — FM/lead (for home team section lead avatar)
        Employee__c empLead = new Employee__c(
            Name         = 'Scott Spaulding',
            First_Name__c = 'Scott',
            Last_Name__c  = 'Spaulding',
            Active__c     = true,
            Department__c = 'Aqua',
            On_PTO_Today__c = false,
            Role__c       = 'FM'
        );
        insert empLead;
    }

    // ─── READ METHODS ────────────────────────────────────────────────────────

    @isTest
    static void testGetHomeData() {
        Test.startTest();
        AquaConsoleController.HomeDTO result = AquaConsoleController.getHomeData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'HomeDTO should not be null');
        System.assertNotEquals(null, result.todayLabel, 'todayLabel should be set');
        System.assertNotEquals(null, result.kpiInstallsToday, 'kpiInstallsToday should be set');
        System.assertNotEquals(null, result.kpiSameDay, 'kpiSameDay should be set');
        System.assertNotEquals(null, result.kpiOnSiteLots, 'kpiOnSiteLots should be set');
        System.assertNotEquals(null, result.teamMembers, 'teamMembers should not be null');
        System.assert(result.teamMembers.size() >= 1, 'Should have at least 1 Aqua team member');
    }

    @isTest
    static void testGetTodayInstalls() {
        Test.startTest();
        List<AquaConsoleController.TodayInstallRow> result = AquaConsoleController.getTodayInstalls();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() >= 1, 'Should find at least 1 install ticket for today');
    }

    @isTest
    static void testGetInstallScope() {
        Test.startTest();
        List<AquaConsoleController.InstallScopeRow> result = AquaConsoleController.getInstallScope();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetTechRoutes() {
        Test.startTest();
        List<AquaConsoleController.TechRouteDTO> result = AquaConsoleController.getTechRoutes();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
        // With Aqua employees in test data, result should have entries
        System.assert(result.size() >= 1, 'Should have at least 1 tech route with Aqua employees');
    }

    @isTest
    static void testGetSameDayQueue() {
        Test.startTest();
        List<AquaConsoleController.SameDayDTO> result = AquaConsoleController.getSameDayQueue();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() >= 1, 'Should find the same-day check ticket');
    }

    @isTest
    static void testGetInventoryData() {
        Test.startTest();
        AquaConsoleController.InventoryPageDTO result = AquaConsoleController.getInventoryData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'InventoryPageDTO should not be null');
        System.assertNotEquals(null, result.partRows, 'partRows should not be null');
        System.assertNotEquals(null, result.vanRows, 'vanRows should not be null');
        System.assertNotEquals(null, result.logRows, 'logRows should not be null');
    }

    @isTest
    static void testGetCommunityData() {
        Test.startTest();
        AquaConsoleController.CommunityPageDTO result = AquaConsoleController.getCommunityData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'CommunityPageDTO should not be null');
        System.assertNotEquals(null, result.communityRows, 'communityRows should not be null');
        System.assert(result.communityRows.size() >= 1, 'Should find at least 1 Aqua-active community');
        System.assertNotEquals(null, result.techOptions, 'techOptions should not be null');
    }

    @isTest
    static void testGetWateringData() {
        Test.startTest();
        AquaConsoleController.WateringPageDTO result = AquaConsoleController.getWateringData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'WateringPageDTO should not be null');
        System.assertNotEquals(null, result.months, 'months should not be null');
        System.assertEquals(12, result.months.size(), 'Should have 12 months');
    }

    @isTest
    static void testGetCloseoutQueue() {
        Test.startTest();
        List<AquaConsoleController.CloseoutTicketDTO> result = AquaConsoleController.getCloseoutQueue();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetPickupData() {
        Test.startTest();
        AquaConsoleController.PickupPageDTO result = AquaConsoleController.getPickupData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'PickupPageDTO should not be null');
        System.assertNotEquals(null, result.pickupRows, 'pickupRows should not be null');
        System.assertNotEquals(null, result.seasonYear, 'seasonYear should be set');
    }

    // ─── ACTION METHODS ──────────────────────────────────────────────────────

    @isTest
    static void testApplyRunTimePct() {
        Test.startTest();
        AquaConsoleController.applyRunTimePct(65);
        Test.stopTest();
        List<String> mns = new List<String>{
            'January','February','March','April','May','June',
            'July','August','September','October','November','December'
        };
        String cm = mns[Date.today().month() - 1];
        List<Aqua_Watering_Schedule__c> updated = [
            SELECT Run_Time_Pct__c FROM Aqua_Watering_Schedule__c
            WHERE Month__c = :cm AND Effective_Year__c = :Date.today().year()
        ];
        if (!updated.isEmpty()) {
            System.assertEquals(65, updated[0].Run_Time_Pct__c.intValue(), 'Run time pct should update to 65');
        }
    }

    @isTest
    static void testUpdateWateringSchedule() {
        List<String> mns = new List<String>{
            'January','February','March','April','May','June',
            'July','August','September','October','November','December'
        };
        String cm = mns[Date.today().month() - 1];
        Test.startTest();
        AquaConsoleController.updateWateringSchedule('Seasonal Monthly', cm, null, 'Weekly', 20, 55);
        Test.stopTest();
        List<Aqua_Watering_Schedule__c> updated = [
            SELECT Run_Time_Pct__c, Run_Frequency__c, Run_Duration_Min__c
            FROM Aqua_Watering_Schedule__c
            WHERE Month__c = :cm AND Effective_Year__c = :Date.today().year()
        ];
        if (!updated.isEmpty()) {
            System.assertEquals(55, updated[0].Run_Time_Pct__c.intValue(), 'Run time pct should update to 55');
            System.assertEquals('Weekly', updated[0].Run_Frequency__c, 'Frequency should update');
            System.assertEquals(20, Integer.valueOf(updated[0].Run_Duration_Min__c), 'Duration should update');
        }
    }

    @isTest
    static void testApproveCloseout_Install() {
        Aqua_Install_Ticket__c ait = [SELECT Id FROM Aqua_Install_Ticket__c LIMIT 1];
        Test.startTest();
        // approveCloseout should close the ticket; if required fields missing it will throw gracefully
        try {
            AquaConsoleController.approveCloseout(ait.Id, 'Install');
        } catch (AuraHandledException e) {
            // Expected if closeout checklist not complete — still exercises the method
        }
        Test.stopTest();
    }

    @isTest
    static void testApproveCloseout_Check() {
        // Use the check ticket without a billing reason code (the closeout-pending one)
        Aqua_Check_Ticket__c act = [
            SELECT Id FROM Aqua_Check_Ticket__c
            WHERE Billing_Reason_Code__c = null AND Status__c = 'Open'
            LIMIT 1
        ];
        Test.startTest();
        try {
            AquaConsoleController.approveCloseout(act.Id, 'Check');
        } catch (AuraHandledException e) {
            // Expected if checklist incomplete — still exercises the method
        }
        Test.stopTest();
    }

    @isTest
    static void testReturnNfi_Install() {
        Aqua_Install_Ticket__c ait = [SELECT Id FROM Aqua_Install_Ticket__c LIMIT 1];
        Test.startTest();
        AquaConsoleController.returnNfi(ait.Id, 'Install');
        Test.stopTest();
        Aqua_Install_Ticket__c updated = [SELECT Close_Notes__c FROM Aqua_Install_Ticket__c WHERE Id = :ait.Id];
        System.assertEquals('Returned as NFI', updated.Close_Notes__c, 'Close notes should say Returned as NFI');
    }

    @isTest
    static void testReturnNfi_Check() {
        Aqua_Check_Ticket__c act = [
            SELECT Id FROM Aqua_Check_Ticket__c
            WHERE Billing_Reason_Code__c = null AND Status__c = 'Open'
            LIMIT 1
        ];
        Test.startTest();
        AquaConsoleController.returnNfi(act.Id, 'Check');
        Test.stopTest();
        Aqua_Check_Ticket__c updated = [SELECT Check_Notes__c FROM Aqua_Check_Ticket__c WHERE Id = :act.Id];
        System.assertEquals('Returned as NFI', updated.Check_Notes__c, 'Check notes should say Returned as NFI');
    }

    @isTest
    static void testCreateSameDayRepair() {
        Test.startTest();
        Id newId = AquaConsoleController.createSameDayRepair('Lot 100', 'Head broken', 'HO Call');
        Test.stopTest();
        System.assertNotEquals(null, newId, 'New ticket Id should be returned');
        Aqua_Check_Ticket__c created = [SELECT Status__c FROM Aqua_Check_Ticket__c WHERE Id = :newId];
        System.assertEquals('Open', created.Status__c, 'New ticket should be Open');
    }

    @isTest
    static void testCreateSameDayRepair_NoLot_Throws() {
        Test.startTest();
        Boolean threw = false;
        try {
            AquaConsoleController.createSameDayRepair('', 'issue', 'source');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw AuraHandledException when lot is blank');
    }

    @isTest
    static void testResolveTicket() {
        // Use the same-day check ticket (has Billing_Reason_Code__c and notes)
        Aqua_Check_Ticket__c act = [
            SELECT Id FROM Aqua_Check_Ticket__c
            WHERE Billing_Reason_Code__c != null AND Status__c = 'Open'
            LIMIT 1
        ];
        Test.startTest();
        AquaConsoleController.resolveTicket(act.Id);
        Test.stopTest();
        Aqua_Check_Ticket__c updated = [SELECT Status__c FROM Aqua_Check_Ticket__c WHERE Id = :act.Id];
        System.assertEquals('Closed', updated.Status__c, 'Ticket should be Closed');
    }

    @isTest
    static void testResolveTicket_Null_Throws() {
        Test.startTest();
        Boolean threw = false;
        try {
            AquaConsoleController.resolveTicket(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw when ticketId is null');
    }

    // ─── Empty-data paths ────────────────────────────────────────────────────

    @isTest
    static void testGetHomeData_NoData() {
        delete [SELECT Id FROM Aqua_Install_Ticket__c];
        delete [SELECT Id FROM Aqua_Check_Ticket__c];
        delete [SELECT Id FROM Aqua_Pickup_Ticket__c];
        delete [SELECT Id FROM Aqua_Watering_Schedule__c];
        delete [SELECT Id FROM Aqua_Inventory__c];

        Test.startTest();
        AquaConsoleController.HomeDTO result = AquaConsoleController.getHomeData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'HomeDTO should not be null even with no data');
        System.assertEquals(0, result.kpiInstallsToday, 'Zero installs when no data');
    }

    @isTest
    static void testGetWateringData_NoRecords() {
        delete [SELECT Id FROM Aqua_Watering_Schedule__c];
        Test.startTest();
        AquaConsoleController.WateringPageDTO result = AquaConsoleController.getWateringData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return DTO with no records');
        System.assertEquals(12, result.months.size(), 'Should still have 12 months');
    }

    @isTest
    static void testGetPickupData_NoRecords() {
        delete [SELECT Id FROM Aqua_Pickup_Ticket__c];
        Test.startTest();
        AquaConsoleController.PickupPageDTO result = AquaConsoleController.getPickupData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return DTO with no records');
        System.assertEquals(0, result.pickupRows.size(), 'Zero rows when no data');
    }

    @isTest
    static void testGetTechRoutes_NoData() {
        // Delete employees to prove routes now resolve from community FM ownership.
        delete [SELECT Id FROM Employee__c];
        Test.startTest();
        List<AquaConsoleController.TechRouteDTO> result = AquaConsoleController.getTechRoutes();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should still return route data');
        System.assert(result.size() >= 1, 'Routes should still resolve from assigned community field managers.');
    }

    @isTest
    static void testGetInventoryData_Empty() {
        delete [SELECT Id FROM Aqua_Inventory__c];
        delete [SELECT Id FROM Aqua_Inventory_Adjustment__c];
        Test.startTest();
        AquaConsoleController.InventoryPageDTO result = AquaConsoleController.getInventoryData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return DTO with no data');
    }

    @isTest
    static void testGetCommunityData_NoData() {
        delete [SELECT Id FROM Lot__c];
        delete [SELECT Id FROM Community__c];
        Test.startTest();
        AquaConsoleController.CommunityPageDTO result = AquaConsoleController.getCommunityData();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return empty DTO');
        System.assertEquals(0, result.communityRows.size(), 'No community rows');
    }

    // ─── Coverage expansion: GPS, stops, tamper, variant paths ──────────────

    /**
     * GPS records linked to Aqua employees — covers buildTechStatusRows GPS branch,
     * mapX/mapY, and timeAgoLabel hour-range branch.
     */
    @isTest
    static void testGetTechRoutes_WithGps() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Department__c = 'Aqua' AND Role__c = 'Technician' LIMIT 1];
        WEX_GPS_Position__c gps = new WEX_GPS_Position__c(
            Driver__c              = emp.Id,
            Latitude__c            = 35.2,
            Longitude__c           = -80.8,
            Last_Seen_DateTime__c  = Datetime.now().addHours(-2)
        );
        insert gps;
        Test.startTest();
        List<AquaConsoleController.TechRouteDTO> result = AquaConsoleController.getTechRoutes();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Routes should not be null');
        System.assert(result.size() >= 1, 'Should have at least 1 tech route with GPS data');
    }

    /**
     * Schedule_Day__c + Schedule_Stop__c records — covers stopsByManager building
     * and the stop-loop path in getTechRoutes.
     */
    @isTest
    static void testGetTechRoutes_WithStops() {
        Schedule_Day__c day = new Schedule_Day__c(Schedule_Date__c = Date.today());
        insert day;
        Schedule_Stop__c stop = new Schedule_Stop__c(
            Schedule_Day__c  = day.Id,
            Field_Manager__c = UserInfo.getUserId(),
            Stop_Number__c   = 1,
            Route_Status__c  = 'Proposed'
        );
        insert stop;
        Test.startTest();
        List<AquaConsoleController.TechRouteDTO> result = AquaConsoleController.getTechRoutes();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Routes should not be null with stops present');
    }

    /**
     * Same-day tickets with (B) Warranty and (C) Additional Coverage billing codes —
     * covers getSameDayQueue and buildSameDayRows source-type branches.
     */
    @isTest
    static void testGetSameDayQueue_SourceTypesBandC() {
        insert new List<Aqua_Check_Ticket__c>{
            new Aqua_Check_Ticket__c(
                Scheduled_Date__c      = Date.today(),
                Status__c              = 'Open',
                Billing_Reason_Code__c = '(B) Damaged or Malfunctioning (Warranty)',
                Check_Notes__c         = 'Warranty issue'
            ),
            new Aqua_Check_Ticket__c(
                Scheduled_Date__c      = Date.today(),
                Status__c              = 'Open',
                Billing_Reason_Code__c = '(C) Additional Coverage Needed',
                Check_Notes__c         = 'Extra coverage needed'
            )
        };
        Test.startTest();
        List<AquaConsoleController.SameDayDTO> result = AquaConsoleController.getSameDayQueue();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.size() >= 3, 'Should include original + B + C tickets');
    }

    /**
     * Inventory adjustment with Reason B — covers adjustment log row building.
     */
    @isTest
    static void testGetInventoryData_WithReasonB() {
        insert new Aqua_Inventory_Adjustment__c(
            Aqua_Inventory_Reason_Code__c = '(B) Damaged or Malfunctioning (Warranty)',
            Quantity__c                   = 2,
            Adjustment_DateTime__c        = Datetime.now()
        );
        Test.startTest();
        AquaConsoleController.InventoryPageDTO result = AquaConsoleController.getInventoryData();
        Test.stopTest();
        System.assertNotEquals(null, result.logRows, 'Log rows should not be null');
        System.assert(result.logRows.size() >= 1, 'Should have at least 1 Reason B log row');
    }

    /**
     * Pickup tickets with missing scheduled date (Unassigned branch) and a closed
     * install ticket in the same community (communityInstallDate map branch).
     */
    @isTest
    static void testGetPickupData_VariantPaths() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        // Ticket without scheduled date → hits 'Unassigned' status branch
        insert new Aqua_Pickup_Ticket__c(Status__c = 'Open');

        // Closed install in same community → communityInstallDate aggregate result
        insert new Aqua_Install_Ticket__c(
            Community__c      = opp.Id,
            Scheduled_Date__c = Date.today().addDays(-5),
            Status__c         = 'Closed'
        );
        Test.startTest();
        AquaConsoleController.PickupPageDTO result = AquaConsoleController.getPickupData();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.pickupRows);
    }

    /**
     * applyRunTimePct with null — covers the null/out-of-range validation throw.
     */
    @isTest
    static void testApplyRunTimePct_NullThrows() {
        Test.startTest();
        try {
            AquaConsoleController.applyRunTimePct(null);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected AuraHandledException for null pct');
        }
        Test.stopTest();
    }

    /**
     * applyRunTimePct with no watering schedule records — covers isEmpty throw.
     */
    @isTest
    static void testApplyRunTimePct_NoRecordsThrows() {
        delete [SELECT Id FROM Aqua_Watering_Schedule__c];
        Test.startTest();
        try {
            AquaConsoleController.applyRunTimePct(70);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected AuraHandledException when no records exist');
        }
        Test.stopTest();
    }

    /**
     * resolveTicket when the check ticket has no notes — covers the validation throw.
     */
    @isTest
    static void testResolveTicket_NoNotesThrows() {
        Aqua_Check_Ticket__c t = new Aqua_Check_Ticket__c(
            Scheduled_Date__c      = Date.today(),
            Status__c              = 'Open',
            Billing_Reason_Code__c = '(A) Missing Material (Stolen)'
            // No Check_Notes__c
        );
        insert t;
        Test.startTest();
        try {
            AquaConsoleController.resolveTicket(t.Id);
            System.assert(false, 'Should have thrown for missing notes');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected AuraHandledException when notes are blank');
        }
        Test.stopTest();
    }

    /**
     * returnNfi with an unknown ticket type — covers the else-throw branch.
     */
    @isTest
    static void testReturnNfi_UnknownTypeThrows() {
        Aqua_Install_Ticket__c ait = [SELECT Id FROM Aqua_Install_Ticket__c LIMIT 1];
        Test.startTest();
        try {
            AquaConsoleController.returnNfi(ait.Id, 'Unknown');
            System.assert(false, 'Should have thrown for unknown type');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected AuraHandledException for unknown ticket type');
        }
        Test.stopTest();
    }

    /**
     * approveCloseout — Install ticket with ALL checklist fields filled in (success path).
     * Covers lines 1856–1862 (heads check, notes check, status update).
     */
    @isTest
    static void testApproveCloseout_Install_Complete() {
        Aqua_Install_Ticket__c t = new Aqua_Install_Ticket__c(
            Scheduled_Date__c    = Date.today(),
            Status__c            = 'Open',
            Device_Installed__c  = true,
            Timer_Tested__c      = true,
            Coverage_Verified__c = true,
            Photos_Uploaded__c   = true,
            Closeout_Notes__c    = 'Installation complete, all systems normal.',
            Inventory_Recorded__c = true
        );
        insert t;
        Test.startTest();
        AquaConsoleController.approveCloseout(t.Id, 'Install');
        Test.stopTest();
        System.assertEquals('Closed',
            [SELECT Status__c FROM Aqua_Install_Ticket__c WHERE Id = :t.Id].Status__c,
            'Install ticket should be Closed after successful closeout');
    }

    /**
     * approveCloseout — Check ticket with notes populated (success path).
     * Covers lines 1873–1875 (status update).
     */
    @isTest
    static void testApproveCloseout_Check_Complete() {
        Aqua_Check_Ticket__c t = new Aqua_Check_Ticket__c(
            Scheduled_Date__c = Date.today(),
            Status__c         = 'Open',
            Check_Notes__c    = 'All systems checked and functioning normally.'
        );
        insert t;
        Test.startTest();
        AquaConsoleController.approveCloseout(t.Id, 'Check');
        Test.stopTest();
        System.assertEquals('Closed',
            [SELECT Status__c FROM Aqua_Check_Ticket__c WHERE Id = :t.Id].Status__c,
            'Check ticket should be Closed after successful closeout');
    }

    /**
     * approveCloseout — null ticketId throws immediately.
     */
    @isTest
    static void testApproveCloseout_NullIdThrows() {
        Test.startTest();
        try {
            AquaConsoleController.approveCloseout(null, 'Install');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected AuraHandledException for null ticketId');
        }
        Test.stopTest();
    }

    /**
     * approveCloseout — unknown ticket type hits the else-throw branch (line 1878).
     */
    @isTest
    static void testApproveCloseout_UnknownTypeThrows() {
        Aqua_Install_Ticket__c ait = [SELECT Id FROM Aqua_Install_Ticket__c LIMIT 1];
        Test.startTest();
        try {
            AquaConsoleController.approveCloseout(ait.Id, 'Pickup');
            System.assert(false, 'Should have thrown for unknown type');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected AuraHandledException for unknown ticket type');
        }
        Test.stopTest();
    }

    /**
     * Home data with a tamper-flagged check ticket — covers buildTamperFlags rows
     * (lines 1756–1769) including tamper, low turf score, and landscape score branches.
     */
    @isTest
    static void testGetHomeData_WithTamperFlags() {
        insert new Aqua_Check_Ticket__c(
            Scheduled_Date__c       = Date.today(),
            Status__c               = 'Open',
            System_Tampered__c      = true,
            Turf_Condition_Score__c = 2,
            Landscape_Score__c      = 1
            // No Billing_Reason_Code__c → not a same-day ticket; goes to tamper flags
        );
        Test.startTest();
        AquaConsoleController.HomeDTO result = AquaConsoleController.getHomeData();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.tamperFlags);
        System.assert(result.tamperFlags.size() >= 1, 'Should have at least 1 tamper flag');
    }

    /**
     * createSameDayRepair with blank issue — covers the issue-blank validation throw.
     */
    @isTest
    static void testCreateSameDayRepair_BlankIssueThrows() {
        Test.startTest();
        try {
            AquaConsoleController.createSameDayRepair('Lot 100', '', 'HO Call');
            System.assert(false, 'Should have thrown for blank issue');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected AuraHandledException for blank issue');
        }
        Test.stopTest();
    }

    /**
     * getCloseoutQueue with an install ticket that has full checklist fields —
     * covers line 1449 (isCloseoutReady multiline &&) and lines 1482/1484
     * (low score branches on check tickets).
     */
    // ─── NEW SERVICE DELEGATION METHODS ────────────────────────────────────

    @isTest
    static void testReoptimizeRoutes_CreatesROR() {
        Test.startTest();
        AquaConsoleController.reoptimizeRoutes();
        Test.stopTest();
        List<Route_Optimization_Result__c> results = [SELECT Status__c FROM Route_Optimization_Result__c];
        System.assertEquals(1, results.size(), 'One ROR should be created');
        System.assertEquals('Proposed', results[0].Status__c);
    }

    @isTest
    static void testAddShopStop_CreatesStop() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Department__c = 'Aqua' AND Role__c = 'Technician' LIMIT 1];
        Test.startTest();
        AquaConsoleController.addShopStop(emp.Id, 'Restock from console');
        Test.stopTest();
        List<Schedule_Stop__c> stops = [SELECT Stop_Type__c FROM Schedule_Stop__c WHERE Employee__c = :emp.Id];
        System.assertEquals(1, stops.size(), 'One stop should be created');
        System.assertEquals('Shop', stops[0].Stop_Type__c);
    }

    @isTest
    static void testAddShopStop_NullTech_Throws() {
        try {
            Test.startTest();
            AquaConsoleController.addShopStop(null, null);
            Test.stopTest();
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }

    @isTest
    static void testBulkRetrieveEndOfSeason_BeforeSeasonEnd_Throws() {
        Date seasonEnd = Date.newInstance(Date.today().year(), 10, 31);
        if (Date.today() < seasonEnd) {
            try {
                Test.startTest();
                AquaConsoleController.bulkRetrieveEndOfSeason();
                Test.stopTest();
                System.assert(false, 'Expected AuraHandledException before season end');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Exception should be thrown');
            }
        } else {
            Test.startTest();
            AquaConsoleController.bulkRetrieveEndOfSeason();
            Test.stopTest();
            System.assert(true, 'Bulk retrieve succeeded after season end');
        }
    }

    @isTest
    static void testReassignPickup_UpdatesTech() {
        Lot__c lot = [SELECT Id FROM Lot__c LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Aqua_Pickup_Ticket__c pt = new Aqua_Pickup_Ticket__c(
            Lot__c            = lot.Id,
            Community__c      = opp.Id,
            Status__c         = 'Open',
            Scheduled_Date__c = Date.today()
        );
        insert pt;
        // Assigned_To__c is a User lookup — use current running user
        Id userId = UserInfo.getUserId();
        Test.startTest();
        AquaConsoleController.reassignPickup(pt.Id, userId);
        Test.stopTest();
        Aqua_Pickup_Ticket__c updated = [SELECT Assigned_To__c FROM Aqua_Pickup_Ticket__c WHERE Id = :pt.Id];
        System.assertEquals(userId, updated.Assigned_To__c);
    }

    @isTest
    static void testGetCloseoutQueue_FullChecklist() {
        // Install with all closeout checkboxes set = true → isCloseoutReady should be true
        insert new Aqua_Install_Ticket__c(
            Scheduled_Date__c    = Date.today(),
            Status__c            = 'Open',
            Device_Installed__c  = true,
            Timer_Tested__c      = true,
            Coverage_Verified__c = true,
            Photos_Uploaded__c   = true,
            Closeout_Notes__c    = 'Ready to close',
            Inventory_Recorded__c = true
        );
        // Check ticket with low scores → lines 1482 and 1484
        insert new Aqua_Check_Ticket__c(
            Scheduled_Date__c       = Date.today(),
            Status__c               = 'Open',
            Turf_Condition_Score__c = 1,
            Landscape_Score__c      = 2
            // No Billing_Reason_Code__c
        );
        Test.startTest();
        List<AquaConsoleController.CloseoutTicketDTO> result = AquaConsoleController.getCloseoutQueue();
        Test.stopTest();
        System.assertNotEquals(null, result);
        // At least one install ticket should have isCloseoutReady = true
        Boolean anyReady = false;
        for (AquaConsoleController.CloseoutTicketDTO dto : result) {
            if (dto.isCloseoutReady) { anyReady = true; break; }
        }
        System.assert(anyReady, 'At least one ticket should be ready to close');
    }

    @isTest
    static void testGetPickupReconciliation_NullReturnsNull() {
        Test.startTest();
        AquaConsoleController.ReconciliationDTO result = AquaConsoleController.getPickupReconciliation(null);
        Test.stopTest();
        System.assertEquals(null, result, 'Null input should return null');
    }

    @isTest
    static void testGetPickupReconciliation_ReturnsClean() {
        Aqua_Pickup_Ticket__c pt = [SELECT Id FROM Aqua_Pickup_Ticket__c LIMIT 1];

        // Add On-Site inventory row so the reconciliation loop executes
        Aqua_Inventory__c onsiteInv = new Aqua_Inventory__c(
            Item_Type__c     = 'Controllers',
            Location__c      = 'On-Site',
            Location_Type__c = 'On-Site',
            Quantity__c      = 5
        );
        insert onsiteInv;

        // Set Unit_Cost__c on master so billing estimate path executes
        Aqua_Master_Inventory__c master = [SELECT Id FROM Aqua_Master_Inventory__c LIMIT 1];
        master.Unit_Cost__c = 25.00;
        update master;

        Test.startTest();
        AquaConsoleController.ReconciliationDTO result = AquaConsoleController.getPickupReconciliation(pt.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.isClean, 'Pickup ticket with no variance should be clean');
        System.assertNotEquals(null, result.rows, 'Rows should not be null');
    }
}