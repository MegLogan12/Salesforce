/**
 * LOVING_WorkOrderTriggerHandlerTest
 *
 * Test coverage for all Production Install trigger paths.
 * Run with: sf apex run test --class-names LOVING_WorkOrderTriggerHandlerTest
 *
 * Tests:
 *   1. WO insert defaults (Lunch, Cushion, Shift Start, NFI Count)
 *   2. Status → Scheduled: Pull Ticket, Loading Ticket, Site Readiness Task created
 *   3. Status → Scheduled (Aqua): Aqua Install WO created
 *   4. Status → Completed (Field Complete): QI Inspection and Task created
 *   5. Status → NFI: FM task created
 *   6. Status → NFI > 2: COO escalation task created
 *   7. Status → Approved: Invoice task created
 *   8. Health Check → Red: Escalation tasks created
 *   9. FJ Required on Red: Finish_Job__c record created
 *  10. Auto-close: Payment Received + QI Submitted triggers Closed status
 *  11. Validation: Red Flag Notes required on Red health check
 *  12. Validation: NFI Notes required on Need Further Info
 *  13. GP calculations
 *  14. Trigger guard prevents recursion
 */
@IsTest
private class LOVING_WorkOrderTriggerHandlerTest {

    // ── Test Data Factory ─────────────────────────────────────────────────────
    private static Account makeBuilderNational() {
        Account a = new Account(Name='DR Horton National Test',
            RecordTypeId=getRT('Account','Builder_National'));
        insert a;
        return a;
    }

    private static Account makeBuilderRegional(Id parentId) {
        Account a = new Account(Name='DR Horton Charlotte Test',
            ParentId=parentId,
            RecordTypeId=getRT('Account','Builder_Regional'),
            Spec_Type__c='Average (DR Horton)',
            Billing_Method__c='SupplyPro');
        insert a;
        return a;
    }

    private static Account makeCommunity(Id parentId, Boolean aqua) {
        Account a = new Account(Name='Carlton Pointe Test',
            ParentId=parentId,
            RecordTypeId=getRT('Account','Community'),
            Aqua_Customer__c=aqua,
            Zone__c=3,
            FM__c=UserInfo.getUserId());
        insert a;
        return a;
    }

    private static Account makeLot(Id parentId) {
        Account a = new Account(Name='Lot 7 Test',
            ParentId=parentId,
            RecordTypeId=getRT('Account','Lot'),
            Lot_Number__c='7',
            Street_Address__c='123 Test Lane Charlotte NC 28214',
            Lot_Status__c='Active',
            Target_Start_Date__c=Date.today().addDays(45));
        insert a;
        return a;
    }

    private static WorkOrder makeWO(Account community, Account lot, String status) {
        WorkOrder wo = new WorkOrder();
        wo.Work_Order_Type__c    = 'Production Install';
        wo.Status                = status;
        wo.AccountId             = lot.Id;
        wo.Community__c          = community.Id;
        wo.Lot__c                = lot.Id;
        wo.Lot_Address__c        = '123 Test Lane Charlotte NC';
        wo.Lot_Number__c         = '7';
        wo.FM__c                 = UserInfo.getUserId();
        wo.Takeoff_Complete__c   = true;
        wo.Takeoff_Status__c     = 'Confirmed';
        wo.Scheduled_Date__c     = Date.today().addDays(3);
        wo.Zone__c               = 3;
        wo.Goal_Headcount__c     = 4;
        wo.Aqua_Community__c     = community.Aqua_Customer__c;
        return wo;
    }

    private static Id getRT(String objectName, String devName) {
        // Return null-safe RT Id; in test orgs without RT setup, returns null
        try {
            return Schema.getGlobalDescribe().get(objectName)
                .getDescribe().getRecordTypeInfosByDeveloperName()
                .get(devName).getRecordTypeId();
        } catch(Exception e) {
            return null;
        }
    }

    // ── Test 1: Insert Defaults ───────────────────────────────────────────────
    @IsTest
    static void testInsertDefaults() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        Test.startTest();
        WorkOrder wo = makeWO(com, lot, 'New');
        wo.Lunch_Minutes__c   = null;
        wo.Cushion_Minutes__c = null;
        wo.Shift_Start_Time__c = null;
        insert wo;
        Test.stopTest();

        WorkOrder result = [SELECT Lunch_Minutes__c, Cushion_Minutes__c,
            Shift_Start_Time__c, NFI_Count__c FROM WorkOrder WHERE Id = :wo.Id];
        System.assertEquals(60,    result.Lunch_Minutes__c,   'Lunch default');
        System.assertEquals(15,    result.Cushion_Minutes__c, 'Cushion default');
        System.assertEquals('06:30', result.Shift_Start_Time__c, 'Shift start default');
        System.assertEquals(0,     result.NFI_Count__c,       'NFI count default');
    }

    // ── Test 2: Status → Scheduled (Pull + Loading + SRC Task) ───────────────
    @IsTest
    static void testStatusToScheduled_NonAqua() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'Takeoff Complete');
        insert wo;

        LOVING_TriggerGuard.reset();

        Test.startTest();
        wo.Status = 'Scheduled';
        update wo;
        Test.stopTest();

        // Pull Ticket
        List<WorkOrder> pullTickets = [SELECT Id FROM WorkOrder
            WHERE ParentWorkOrderId = :wo.Id AND Work_Order_Type__c = 'Pull Ticket'];
        System.assertEquals(1, pullTickets.size(), 'Pull Ticket created');

        // Loading Ticket
        List<WorkOrder> loadTickets = [SELECT Id FROM WorkOrder
            WHERE ParentWorkOrderId = :wo.Id AND Work_Order_Type__c = 'Loading Ticket'];
        System.assertEquals(1, loadTickets.size(), 'Loading Ticket created');

        // Site Readiness Task
        List<Task> srcTasks = [SELECT Id FROM Task
            WHERE WhatId = :wo.Id AND Type = 'Site Readiness Check'];
        System.assertEquals(1, srcTasks.size(), 'Site Readiness Task created');

        // No Aqua ticket
        List<WorkOrder> aquaWOs = [SELECT Id FROM WorkOrder
            WHERE ParentWorkOrderId = :wo.Id AND Work_Order_Type__c = 'Aqua Install'];
        System.assertEquals(0, aquaWOs.size(), 'No Aqua ticket on non-Aqua community');
    }

    // ── Test 3: Status → Scheduled (Aqua community) ───────────────────────────
    @IsTest
    static void testStatusToScheduled_Aqua() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, true); // Aqua
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'Takeoff Complete');
        wo.Aqua_Community__c = true;
        insert wo;

        LOVING_TriggerGuard.reset();
        Test.startTest();
        wo.Status = 'Scheduled';
        update wo;
        Test.stopTest();

        List<WorkOrder> aquaWOs = [SELECT Id FROM WorkOrder
            WHERE ParentWorkOrderId = :wo.Id AND Work_Order_Type__c = 'Aqua Install'];
        System.assertEquals(1, aquaWOs.size(), 'Aqua Install ticket created for Aqua community');
    }

    // ── Test 4: Status → Completed (QI Inspection + Task) ────────────────────
    @IsTest
    static void testStatusToCompleted_QICreated() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'In Progress');
        insert wo;

        LOVING_TriggerGuard.reset();
        Test.startTest();
        wo.Status = 'Completed (Field Complete)';
        wo.Crew_Complete_Timestamp__c = System.now();
        update wo;
        Test.stopTest();

        List<QI_Inspection__c> qis = [SELECT Id, Status__c FROM QI_Inspection__c
            WHERE Work_Order__c = :wo.Id];
        System.assertEquals(1, qis.size(), 'QI Inspection created');
        System.assertEquals('Scheduled', qis[0].Status__c, 'QI status is Scheduled');

        List<Task> qiTasks = [SELECT Id FROM Task
            WHERE WhatId = :wo.Id AND Type = 'QI Inspection'];
        System.assertEquals(1, qiTasks.size(), 'QI Task created');

        WorkOrder updated = [SELECT QI_Status__c FROM WorkOrder WHERE Id = :wo.Id];
        System.assertEquals('Scheduled', updated.QI_Status__c, 'WO QI_Status updated');
    }

    // ── Test 5: Status → NFI (FM task) ────────────────────────────────────────
    @IsTest
    static void testStatusToNFI_TaskCreated() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'Pending Closeout Approval');
        wo.Closeout_Photos_Attached__c     = true;
        wo.Closeout_Quantities_Confirmed__c = true;
        insert wo;

        LOVING_TriggerGuard.reset();
        Test.startTest();
        wo.Status = 'Need Further Info';
        wo.Need_Further_Info_Notes__c = 'Missing quantity confirmation on tree line items.';
        update wo;
        Test.stopTest();

        List<Task> nfiTasks = [SELECT Id FROM Task
            WHERE WhatId = :wo.Id AND Type = 'NFI Resolution'];
        System.assertEquals(1, nfiTasks.size(), 'NFI Task created for FM');

        WorkOrder updated = [SELECT NFI_Count__c FROM WorkOrder WHERE Id = :wo.Id];
        System.assertEquals(1, updated.NFI_Count__c, 'NFI Count incremented');
    }

    // ── Test 6: NFI > 2 escalation ───────────────────────────────────────────
    @IsTest
    static void testNFI_Escalation() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'Pending Closeout Approval');
        wo.Closeout_Photos_Attached__c     = true;
        wo.Closeout_Quantities_Confirmed__c = true;
        wo.NFI_Count__c = 2; // Already been returned twice
        insert wo;

        LOVING_TriggerGuard.reset();
        Test.startTest();
        wo.Status = 'Need Further Info';
        wo.Need_Further_Info_Notes__c = 'Third return — COO review needed.';
        update wo;
        Test.stopTest();

        List<Task> escalations = [SELECT Id FROM Task
            WHERE WhatId = :wo.Id AND Type = 'COO Escalation'];
        System.assertEquals(1, escalations.size(), 'COO escalation task created at NFI > 2');
    }

    // ── Test 7: Status → Approved (Invoice Task) ──────────────────────────────
    @IsTest
    static void testStatusToApproved_InvoiceTask() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'Pending Closeout Approval');
        wo.Closeout_Photos_Attached__c     = true;
        wo.Closeout_Quantities_Confirmed__c = true;
        insert wo;

        LOVING_TriggerGuard.reset();
        Test.startTest();
        wo.Status = 'Approved';
        wo.Approved_By__c = UserInfo.getUserId();
        wo.Approval_Date__c = System.now();
        update wo;
        Test.stopTest();

        List<Task> invoiceTasks = [SELECT Id FROM Task
            WHERE WhatId = :wo.Id AND Type = 'Invoicing'];
        System.assertEquals(1, invoiceTasks.size(), 'Invoice task created on Approved');
    }

    // ── Test 8: Red Flag health check → escalation tasks ────────────────────
    @IsTest
    static void testRedFlagEscalation() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'In Progress');
        insert wo;

        LOVING_TriggerGuard.reset();
        Test.startTest();
        wo.Health_Check_Status__c = 'Red - Will Not Complete Today';
        wo.Red_Flag_Notes__c = 'Material short on 3G shrubs. Approximately 2 hours of work remaining.';
        update wo;
        Test.stopTest();

        List<Task> redTasks = [SELECT Id FROM Task
            WHERE WhatId = :wo.Id AND Type = 'Red Flag Escalation'];
        System.assertNotEquals(0, redTasks.size(), 'Red flag escalation tasks created');

        WorkOrder updated = [SELECT Red_Flag_Timestamp__c, Health_Check_Date__c
            FROM WorkOrder WHERE Id = :wo.Id];
        System.assertNotEquals(null, updated.Red_Flag_Timestamp__c, 'Red flag timestamp stamped');
    }

    // ── Test 9: FJ Required on Red → Finish_Job__c created ───────────────────
    @IsTest
    static void testFinishJobCreatedOnRedFlag() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'In Progress');
        insert wo;

        LOVING_TriggerGuard.reset();
        Test.startTest();
        wo.Health_Check_Status__c  = 'Red - Will Not Complete Today';
        wo.Red_Flag_Notes__c       = 'Ran out of time. 1 hour of planting remaining.';
        wo.Finish_Job_Required__c  = true;
        wo.Finish_Job_Reason__c    = 'Ran Out of Time';
        update wo;
        Test.stopTest();

        List<Finish_Job__c> fjs = [SELECT Id, FJ_Reason__c FROM Finish_Job__c
            WHERE Parent_Work_Order__c = :wo.Id];
        System.assertEquals(1, fjs.size(), 'Finish Job record created');
        System.assertEquals('Ran Out of Time', fjs[0].FJ_Reason__c, 'FJ reason populated');
    }

    // ── Test 10: Auto-close (Payment + QI) ────────────────────────────────────
    @IsTest
    static void testAutoClose() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'Invoiced');
        wo.QI_Submitted__c = true;
        wo.QI_Status__c    = 'Approved';
        insert wo;

        LOVING_TriggerGuard.reset();
        Test.startTest();
        wo.Payment_Received__c = true;
        wo.Payment_Date__c     = Date.today();
        update wo;
        Test.stopTest();

        WorkOrder result = [SELECT Status FROM WorkOrder WHERE Id = :wo.Id];
        System.assertEquals('Closed', result.Status, 'WO auto-closed when Paid + QI Submitted');
    }

    // ── Test 11: Validation — Red Notes Required ──────────────────────────────
    @IsTest
    static void testValidation_RedFlagNotesRequired() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'In Progress');
        insert wo;

        LOVING_TriggerGuard.reset();
        Test.startTest();
        try {
            wo.Health_Check_Status__c = 'Red - Will Not Complete Today';
            wo.Red_Flag_Notes__c      = null; // Missing — should error
            update wo;
            System.assert(false, 'Should have thrown validation error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Red Flag Notes'),
                'Expected Red Flag Notes validation message');
        }
        Test.stopTest();
    }

    // ── Test 12: Validation — NFI Notes Required ──────────────────────────────
    @IsTest
    static void testValidation_NFINotesRequired() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'Pending Closeout Approval');
        wo.Closeout_Photos_Attached__c     = true;
        wo.Closeout_Quantities_Confirmed__c = true;
        insert wo;

        LOVING_TriggerGuard.reset();
        Test.startTest();
        try {
            wo.Status = 'Need Further Info';
            wo.Need_Further_Info_Notes__c = null; // Missing
            update wo;
            System.assert(false, 'Should have thrown validation error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Need Further Info Notes'),
                'Expected NFI Notes validation message');
        }
        Test.stopTest();
    }

    // ── Test 13: Trigger Guard prevents recursion ─────────────────────────────
    @IsTest
    static void testTriggerGuardPreventsRecursion() {
        LOVING_TriggerGuard.reset();
        System.assert(!LOVING_TriggerGuard.hasAlreadyRun('WorkOrder'), 'Guard clear');
        LOVING_TriggerGuard.setAlreadyRun('WorkOrder');
        System.assert(LOVING_TriggerGuard.hasAlreadyRun('WorkOrder'), 'Guard set');
        LOVING_TriggerGuard.clearAlreadyRun('WorkOrder');
        System.assert(!LOVING_TriggerGuard.hasAlreadyRun('WorkOrder'), 'Guard cleared');
    }

    // ── Test 14: Measuring Cup Service ────────────────────────────────────────
    @IsTest
    static void testMeasuringCupRTNCalculation() {
        Account bn  = makeBuilderNational();
        Account br  = makeBuilderRegional(bn.Id);
        Account com = makeCommunity(br.Id, false);
        Account lot = makeLot(com.Id);

        WorkOrder wo = makeWO(com, lot, 'Scheduled');
        wo.Goal_Hours__c          = 6;    // 360 goal minutes
        wo.Travel_Minutes_Planned__c = 30;
        wo.Lunch_Minutes__c       = 60;
        wo.Cushion_Minutes__c     = 15;
        wo.Shift_Start_Time__c    = '06:30';
        insert wo;

        Test.startTest();
        Map<Id, String> rtnMap = LOVING_MeasuringCupService.calculateRTN(
            new List<WorkOrder>{wo});
        Test.stopTest();

        // Expected: 6:30 + (360 + 30 + 60 + 15) min = 6:30 + 7h45m = 14:15
        System.assertEquals('14:15', rtnMap.get(wo.Id),
            'RTN = 06:30 + 360 + 30 + 60 + 15 min = 14:15');
    }
}
