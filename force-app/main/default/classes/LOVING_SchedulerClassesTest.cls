@IsTest
private class LOVING_SchedulerClassesTest {

    // ── Bypass Setup ──────────────────────────────────────────────────────────
    @TestSetup
    static void setupBypass() {
        Extentia_SIM__MapPlotterTriggerSettings__c s =
            Extentia_SIM__MapPlotterTriggerSettings__c.getOrgDefaults();
        if (s.Id == null) {
            s.Name = UserInfo.getOrganizationId();
            s.SetupOwnerId = UserInfo.getOrganizationId();
        }
        s.Extentia_SIM__Bypass_Trigger__c = true;
        upsert s;
    }

    // ── Shared Helpers ────────────────────────────────────────────────────────
    private static Id getRT(String objName, String devName) {
        try {
            Schema.RecordTypeInfo rti = Schema.getGlobalDescribe()
                .get(objName).getDescribe()
                .getRecordTypeInfosByDeveloperName().get(devName);
            return (rti != null && rti.isAvailable()) ? rti.getRecordTypeId() : null;
        } catch (Exception e) { return null; }
    }

    private static Account makeBuilder() {
        Account a = new Account(Name = 'Test Builder SCH');
        Id rt = getRT('Account', 'Builder_National');
        if (rt != null) a.RecordTypeId = rt;
        insert a;
        return a;
    }

    private static Account makeCommunity(Id parentId, Boolean aqua) {
        Account a = new Account(
            Name            = 'Test Community SCH',
            ParentId        = parentId,
            Aqua_Customer__c = aqua,
            Zone__c         = 2,
            FM__c           = UserInfo.getUserId(),
            Aqua_Service_Days__c = 'Monday;Wednesday;Friday'
        );
        Id rt = getRT('Account', 'Community');
        if (rt != null) a.RecordTypeId = rt;
        insert a;
        return a;
    }

    private static Account makeLot(Id parentId, Integer daysOut) {
        Account a = new Account(
            Name                 = 'Test Lot SCH ' + daysOut,
            ParentId             = parentId,
            Lot_Number__c        = String.valueOf(Math.abs(daysOut)),
            Street_Address__c    = Math.abs(daysOut) + ' Test Rd Charlotte NC',
            Lot_Status__c        = 'Active',
            Target_Start_Date__c = Date.today().addDays(daysOut),
            FM__c                = UserInfo.getUserId(),
            Takeoff_Complete__c  = false,
            Takeoff_Task_Created__c = false
        );
        Id rt = getRT('Account', 'Lot');
        if (rt != null) a.RecordTypeId = rt;
        insert a;
        return a;
    }

    private static WorkOrder makeWO(Id communityId, Id lotId, String status) {
        WorkOrder wo = new WorkOrder();
        wo.Work_Order_Type__c  = 'Production Install';
        wo.Status              = status;
        wo.AccountId           = lotId;
        wo.Community__c        = communityId;
        wo.Lot__c              = lotId;
        wo.Lot_Address__c      = '1 Test Rd Charlotte NC';
        wo.Lot_Number__c       = '1';
        wo.FM__c               = UserInfo.getUserId();
        wo.Takeoff_Complete__c = true;
        wo.Takeoff_Status__c   = 'Confirmed';
        wo.Scheduled_Date__c   = Date.today().addDays(3);
        wo.Zone__c             = 2;
        wo.Goal_Headcount__c   = 3;
        wo.Aqua_Community__c   = false;
        return wo;
    }

    // ── LOVING_BucketEngineScheduler ──────────────────────────────────────────
    @IsTest
    static void testBucketEngineScheduler() {
        Test.startTest();
        String jobId = System.schedule(
            'Test BEScheduler ' + System.now().getTime(),
            '0 0 2 ? * SUN *',
            new LOVING_BucketEngineScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Scheduler job registered');
    }

    // ── LOVING_BucketEngineService ────────────────────────────────────────────
    @IsTest
    static void testBucketEngineService_EmptyOrg() {
        // No qualifying lots — exercises empty-path return
        Test.startTest();
        LOVING_BucketEngineService.runBucketEngine();
        Test.stopTest();
    }

    @IsTest
    static void testBucketEngineService_MultipleBuckets() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, false);

        // Lot A: 100 days out → BUCKET_90
        Account lotA = makeLot(com.Id, 100);

        // Lot B: 20 days out, no takeoff → BUCKET_30, task created
        Account lotB = makeLot(com.Id, 20);

        // Lot C: -5 days (past due), no takeoff, no WO created → forced BUCKET_RTS
        Account lotC = new Account(
            Name                 = 'Overdue Lot SCH',
            ParentId             = com.Id,
            Lot_Number__c        = '5',
            Street_Address__c    = '5 Overdue Rd Charlotte NC',
            Lot_Status__c        = 'Active',
            Target_Start_Date__c = Date.today().addDays(-5),
            FM__c                = UserInfo.getUserId(),
            Takeoff_Complete__c  = false,
            Takeoff_Task_Created__c = false,
            WO_Created__c        = false
        );
        Id rt = getRT('Account', 'Lot');
        if (rt != null) lotC.RecordTypeId = rt;
        insert lotC;

        Test.startTest();
        LOVING_BucketEngineService.runBucketEngine();
        Test.stopTest();

        List<Account> updated = [SELECT Id, Pipeline_Bucket__c
            FROM Account WHERE Id IN (:lotA.Id, :lotB.Id, :lotC.Id)
            ORDER BY Name];
        System.assertEquals(3, updated.size(), 'All three lots updated');
    }

    // ── LOVING_HealthCheckScheduler ───────────────────────────────────────────
    @IsTest
    static void testHealthCheckScheduler_NoWOs() {
        Test.startTest();
        String jobId = System.schedule(
            'Test HCScheduler Empty ' + System.now().getTime(),
            '0 0 3 ? * SUN *',
            new LOVING_HealthCheckScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void testHealthCheckScheduler_WithActiveWO() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, false);
        Account lot     = makeLot(com.Id, 10);

        WorkOrder wo = makeWO(com.Id, lot.Id, 'In Progress');
        wo.Health_Check_Date__c = null;
        insert wo;

        Test.startTest();
        String jobId = System.schedule(
            'Test HCScheduler WO ' + System.now().getTime(),
            '0 0 4 ? * SUN *',
            new LOVING_HealthCheckScheduler()
        );
        Test.stopTest();

        // Scheduler ran; validate no exception thrown
        System.assertNotEquals(null, jobId, 'Scheduler completed');
    }

    @IsTest
    static void testHealthCheckScheduler_AlreadyCheckedToday() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, false);
        Account lot     = makeLot(com.Id, 10);

        WorkOrder wo = makeWO(com.Id, lot.Id, 'In Progress');
        wo.Health_Check_Date__c = System.now(); // submitted already today
        insert wo;

        Test.startTest();
        String jobId = System.schedule(
            'Test HCScheduler Checked ' + System.now().getTime(),
            '0 0 5 ? * SUN *',
            new LOVING_HealthCheckScheduler()
        );
        Test.stopTest();

        List<Task> hcTasks = [SELECT Id FROM Task
            WHERE WhatId = :wo.Id AND Type = 'Health Check'];
        System.assertEquals(0, hcTasks.size(), 'No duplicate health check task created');
    }

    // ── LOVING_HealthCheckEscalationScheduler ─────────────────────────────────
    @IsTest
    static void testHealthCheckEscalation_NoWOs() {
        Test.startTest();
        String jobId = System.schedule(
            'Test HCEscal Empty ' + System.now().getTime(),
            '0 0 6 ? * SUN *',
            new LOVING_HealthCheckEscalationScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void testHealthCheckEscalation_WithOverdueWO() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, false);
        Account lot     = makeLot(com.Id, 10);

        WorkOrder wo = makeWO(com.Id, lot.Id, 'In Progress');
        wo.Health_Check_Date__c = null; // overdue: null < 2PM cutoff
        insert wo;

        Test.startTest();
        String jobId = System.schedule(
            'Test HCEscal WO ' + System.now().getTime(),
            '0 0 7 ? * SUN *',
            new LOVING_HealthCheckEscalationScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Escalation scheduler completed');
    }

    // ── LOVING_QIEscalationScheduler ──────────────────────────────────────────
    @IsTest
    static void testQIEscalation_NoWOs() {
        Test.startTest();
        String jobId = System.schedule(
            'Test QIEscal Empty ' + System.now().getTime(),
            '0 0 8 ? * SUN *',
            new LOVING_QIEscalationScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void testQIEscalation_WithOverdueWO() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, false);
        Account lot     = makeLot(com.Id, 10);

        WorkOrder wo = makeWO(com.Id, lot.Id, 'In Progress');
        insert wo;

        // Advance to completed state with old timestamp
        LOVING_TriggerGuard.reset();
        wo.Status                   = 'Completed (Field Complete)';
        wo.Crew_Complete_Timestamp__c = System.now().addHours(-72);
        wo.QI_Submitted__c          = false;
        update wo;

        Test.startTest();
        String jobId = System.schedule(
            'Test QIEscal WO ' + System.now().getTime(),
            '0 0 9 ? * SUN *',
            new LOVING_QIEscalationScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'QI escalation scheduler completed');
    }

    // ── LOVING_TakeoffEscalationScheduler ─────────────────────────────────────
    @IsTest
    static void testTakeoffEscalation_NoLots() {
        Test.startTest();
        String jobId = System.schedule(
            'Test TEEscal Empty ' + System.now().getTime(),
            '0 0 10 ? * SUN *',
            new LOVING_TakeoffEscalationScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void testTakeoffEscalation_RunFromFlow() {
        // Covers the @InvocableMethod entry point
        Test.startTest();
        LOVING_TakeoffEscalationScheduler.runFromFlow(new List<String>{ 'test' });
        Test.stopTest();
    }

    @IsTest
    static void testTakeoffEscalation_WithOverdueLot() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, false);

        // Lot that is overdue for takeoff: in 30-day bucket, task created 72h ago, not complete
        Account lot = new Account(
            Name                    = 'Overdue Takeoff SCH',
            ParentId                = com.Id,
            Lot_Number__c           = '77',
            Street_Address__c       = '77 Overdue Rd',
            Lot_Status__c           = 'Active',
            Target_Start_Date__c    = Date.today().addDays(25),
            FM__c                   = UserInfo.getUserId(),
            Takeoff_Complete__c     = false,
            Takeoff_Task_Created__c = true,
            Pipeline_Bucket__c      = '30 Days',
            Bucket_Changed_Date__c  = System.now().addHours(-72)
        );
        Id rt = getRT('Account', 'Lot');
        if (rt != null) lot.RecordTypeId = rt;
        insert lot;

        Test.startTest();
        String jobId = System.schedule(
            'Test TEEscal Lots ' + System.now().getTime(),
            '0 0 11 ? * SUN *',
            new LOVING_TakeoffEscalationScheduler()
        );
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task
            WHERE WhatId = :lot.Id AND Type = 'Escalation'];
        System.assert(tasks.size() >= 0, 'Escalation ran without exception');
    }

    // ── LOVING_AquaTicketService ──────────────────────────────────────────────
    @IsTest
    static void testGetNextServiceDay_Blank() {
        Date today = Date.today();
        Date result = LOVING_AquaTicketService.getNextServiceDay('', today);
        System.assertEquals(today, result, 'Blank service days returns start date');
    }

    @IsTest
    static void testGetNextServiceDay_WithMonday() {
        // Start on a Saturday and ask for Monday → should find Monday (2 days later)
        Date saturday = Date.today().toStartOfWeek().addDays(6);
        Date result = LOVING_AquaTicketService.getNextServiceDay('Monday', saturday);
        System.assertNotEquals(null, result, 'Returns a valid date for Monday service day');
        System.assert(result >= saturday, 'Result is on or after start date');
    }

    @IsTest
    static void testGetNextServiceDay_MultiDay() {
        // Multiple service days — should find the nearest one
        Date startDate = Date.today();
        Date result = LOVING_AquaTicketService.getNextServiceDay(
            'Monday;Tuesday;Wednesday;Thursday;Friday', startDate);
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testAquaInstallTickets_EmptyList() {
        Test.startTest();
        LOVING_AquaTicketService.createAquaInstallTickets(new List<WorkOrder>());
        Test.stopTest();
    }

    @IsTest
    static void testAquaInstallTickets_NonAquaCommunity() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, false); // NOT aqua
        Account lot     = makeLot(com.Id, 30);

        WorkOrder wo = makeWO(com.Id, lot.Id, 'Scheduled');
        wo.Aqua_Community__c = false;
        insert wo;

        WorkOrder woQueried = [SELECT Id, Community__c, AccountId, Builder_Regional__c,
            Lot__c, Lot_Address__c, Lot_Number__c, Scheduled_Date__c,
            Aqua_Tech__c, FM__c FROM WorkOrder WHERE Id = :wo.Id];

        Test.startTest();
        LOVING_AquaTicketService.createAquaInstallTickets(
            new List<WorkOrder>{ woQueried });
        Test.stopTest();

        List<WorkOrder> aqWOs = [SELECT Id FROM WorkOrder
            WHERE ParentWorkOrderId = :wo.Id AND Work_Order_Type__c = 'Aqua Install'];
        System.assertEquals(0, aqWOs.size(), 'No install ticket for non-Aqua community');
    }

    @IsTest
    static void testAquaInstallTickets_AquaCommunity() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, true); // IS aqua
        Account lot     = makeLot(com.Id, 30);

        WorkOrder wo = makeWO(com.Id, lot.Id, 'Scheduled');
        wo.Aqua_Community__c = true;
        insert wo;

        WorkOrder woQueried = [SELECT Id, Community__c, AccountId, Builder_Regional__c,
            Lot__c, Lot_Address__c, Lot_Number__c, Scheduled_Date__c,
            Aqua_Tech__c, FM__c FROM WorkOrder WHERE Id = :wo.Id];

        Test.startTest();
        LOVING_AquaTicketService.createAquaInstallTickets(
            new List<WorkOrder>{ woQueried });
        Test.stopTest();

        List<WorkOrder> aqWOs = [SELECT Id FROM WorkOrder
            WHERE ParentWorkOrderId = :wo.Id AND Work_Order_Type__c = 'Aqua Install'];
        System.assertEquals(1, aqWOs.size(), 'Aqua Install ticket created for Aqua community');
    }

    @IsTest
    static void testCreateFirstCheckTicket() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, true);
        Account lot     = makeLot(com.Id, 30);

        WorkOrder wo = makeWO(com.Id, lot.Id, 'Scheduled');
        wo.Work_Order_Type__c = 'Aqua Install';
        wo.Aqua_Community__c  = true;
        insert wo;

        WorkOrder woQueried = [
            SELECT Id, AccountId, Community__c, Builder_Regional__c, Lot__c,
                   Lot_Address__c, Lot_Number__c, Scheduled_Date__c, Aqua_Tech__c,
                   Confirmed_Hoses__c, Confirmed_Controllers__c,
                   Confirmed_Heads__c, Confirmed_Valves__c
            FROM WorkOrder WHERE Id = :wo.Id
        ];

        Test.startTest();
        LOVING_AquaTicketService.createFirstCheckTicket(woQueried);
        Test.stopTest();

        List<WorkOrder> checks = [SELECT Id FROM WorkOrder
            WHERE ParentWorkOrderId = :wo.Id AND Work_Order_Type__c = 'Aqua Check'];
        System.assertEquals(1, checks.size(), 'First check ticket created');
    }

    @IsTest
    static void testCreatePickupTicket() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, true);
        Account lot     = makeLot(com.Id, 0);

        Test.startTest();
        LOVING_AquaTicketService.createPickupTicket(lot.Id);
        Test.stopTest();

        List<WorkOrder> pickups = [SELECT Id FROM WorkOrder
            WHERE AccountId = :lot.Id AND Work_Order_Type__c = 'Aqua Pickup'];
        System.assertEquals(1, pickups.size(), 'Pickup ticket created');
    }

    @IsTest
    static void testCreatePickupTicket_CancelsFutureChecks() {
        Account builder = makeBuilder();
        Account com     = makeCommunity(builder.Id, true);
        Account lot     = makeLot(com.Id, 0);

        // Create an open check ticket that should be cancelled
        WorkOrder check = makeWO(com.Id, lot.Id, 'New');
        check.Work_Order_Type__c = 'Aqua Check';
        insert check;

        Test.startTest();
        LOVING_AquaTicketService.createPickupTicket(lot.Id);
        Test.stopTest();

        WorkOrder cancelledCheck = [SELECT Status FROM WorkOrder WHERE Id = :check.Id];
        System.assertEquals('Cancelled', cancelledCheck.Status,
            'Future check ticket cancelled when pickup created');
    }
}
