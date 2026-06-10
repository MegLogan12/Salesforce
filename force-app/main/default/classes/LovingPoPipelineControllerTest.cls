@IsTest
private class LovingPoPipelineControllerTest {

    private static Purchase_Order__c makePurchaseOrder(String poNumber, String status, String packageStatus) {
        Account builderMarket = new Account(Name = 'Builder PO Test Market ' + poNumber);
        insert builderMarket;

        Community__c community = new Community__c(
            Name = 'Builder PO Test Community ' + poNumber,
            Builder_Account__c = builderMarket.Id
        );
        insert community;

        Lot__c lot = new Lot__c(
            Name = 'Lot ' + poNumber,
            Community__c = community.Id,
            Lot_Number__c = poNumber.right(3),
            Lot_Status__c = 'Open'
        );
        insert lot;

        insert new Builder_PO__c(
            PO_Number__c = poNumber,
            Builder_Account__c = builderMarket.Id,
            Division_Account__c = builderMarket.Id,
            Community__c = community.Id,
            Lot__c = lot.Id,
            Builder_Name__c = 'Lennar'
        );

        Purchase_Order__c po = new Purchase_Order__c(
            PO_Number__c = poNumber,
            Builder_Account__c = builderMarket.Id,
            Division_Account__c = builderMarket.Id,
            Community__c = community.Id,
            Lot__c = lot.Id,
            Quantity__c = 150,
            Total_Amount__c = 2500,
            Status__c = status,
            Package_BMG_Status__c = packageStatus
        );
        insert po;
        return po;
    }

    @IsTest
    static void mapToBoardColumnPrefersStatusOverStaleStage() {
        System.assertEquals(
            'workOrderCreated',
            LovingPoPipelineController.mapToBoardColumn('PO Received', 'Work Order Created', null)
        );
        System.assertEquals(
            'clear',
            LovingPoPipelineController.mapToBoardColumn('PO Received', 'Clear for Schedule', null)
        );
        System.assertEquals(
            'takeoffRequested',
            LovingPoPipelineController.mapToBoardColumn('PO Received', 'Ready for Takeoff', null)
        );
    }

    @IsTest
    static void deriveNextActionPrefersLiveExecutionArtifacts() {
        LovingPoPipelineController.DetailDTO detail = new LovingPoPipelineController.DetailDTO();
        detail.workOrder = new LovingPoPipelineController.WorkOrderSummaryDTO();
        detail.serviceAppointment = new LovingPoPipelineController.ServiceAppointmentSummaryDTO();
        System.assertEquals('Open WorkOrder', LovingPoPipelineController.deriveNextAction(detail));

        detail.serviceAppointment = null;
        System.assertEquals('Create Schedule Handoff', LovingPoPipelineController.deriveNextAction(detail));

        detail.workOrder = null;
        System.assertEquals('Create / Open Takeoff', LovingPoPipelineController.deriveNextAction(detail));
    }

    @IsTest
    static void choosePrimaryServiceAppointmentPrefersScheduledRows() {
        ServiceAppointment noneRow = new ServiceAppointment(
            Status = 'None',
            Subject = 'SA-OLD'
        );
        ServiceAppointment scheduledRow = new ServiceAppointment(
            Status = 'Scheduled',
            Subject = 'SA-LIVE',
            SchedStartTime = System.now().addDays(1)
        );
        ServiceAppointment readyRow = new ServiceAppointment(
            Status = 'Ready to Schedule',
            Subject = 'SA-READY',
            SchedStartTime = System.now().addHours(2)
        );

        ServiceAppointment chosen = LovingPoPipelineController.choosePrimaryServiceAppointment(
            new List<ServiceAppointment>{ noneRow, readyRow, scheduledRow }
        );
        System.assertEquals('Scheduled', chosen.Status);
        System.assertEquals('SA-LIVE', chosen.Subject);
    }

    @IsTest
    static void getBuilderPoDetailResolvesMatchedStagedPoByNumber() {
        Account builderMarket = new Account(Name = 'Builder PO Pipeline Market');
        insert builderMarket;

        Community__c community = new Community__c(
            Name = 'Builder PO Pipeline Community',
            Builder_Account__c = builderMarket.Id
        );
        insert community;

        Lot__c lot = new Lot__c(
            Name = 'Lot 303',
            Community__c = community.Id,
            Lot_Number__c = '303',
            Lot_Status__c = 'Open'
        );
        insert lot;

        Builder_PO__c builderPo = new Builder_PO__c(
            PO_Number__c = 'PO-PIPE-303',
            Builder_Account__c = builderMarket.Id,
            Division_Account__c = builderMarket.Id,
            Community__c = community.Id,
            Lot__c = lot.Id,
            Builder_Name__c = 'Lennar'
        );
        insert builderPo;

        Purchase_Order__c stagedPo = new Purchase_Order__c(
            PO_Number__c = 'PO-PIPE-303',
            Builder_Account__c = builderMarket.Id,
            Division_Account__c = builderMarket.Id,
            Community__c = community.Id,
            Lot__c = lot.Id,
            Quantity__c = 150,
            Total_Amount__c = 2500,
            Status__c = 'Work Order Created'
        );
        insert stagedPo;

        Test.startTest();
        LovingPoPipelineController.DetailDTO detail = LovingPoPipelineController.getBuilderPoDetail(builderPo.Id);
        Test.stopTest();
        builderPo = [SELECT Id, Name FROM Builder_PO__c WHERE Id = :builderPo.Id LIMIT 1];

        System.assertNotEquals(null, detail);
        System.assertNotEquals(null, detail.po);
        System.assertEquals(stagedPo.Id, detail.po.id);
        System.assertEquals(builderPo.Id, detail.po.builderPoId);
        System.assertEquals(builderPo.Name, detail.po.name);
        System.assertEquals('PO-PIPE-303', detail.po.purchaseOrderName);
        System.assertEquals('Work Order Created', detail.po.status);
    }

    @IsTest
    static void getTakeoffDetailResolvesBuilderWorkspaceByTakeoffId() {
        Purchase_Order__c po = makePurchaseOrder(
            'PO-PIPE-TAKEOFF-001',
            'Takeoff Scheduled',
            'Matched'
        );
        Builder_PO__c builderPo = [
            SELECT Id
            FROM Builder_PO__c
            WHERE PO_Number__c = 'PO-PIPE-TAKEOFF-001'
            LIMIT 1
        ];
        Takeoff__c takeoff = new Takeoff__c(
            Builder_PO__c = builderPo.Id,
            Status__c = 'Submitted',
            FM_Assignment__c = UserInfo.getUserId()
        );
        insert takeoff;
        takeoff = [
            SELECT Id, Name, Status__c
            FROM Takeoff__c
            WHERE Id = :takeoff.Id
        ];

        Test.startTest();
        LovingPoPipelineController.DetailDTO detail = LovingPoPipelineController.getTakeoffDetail(takeoff.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail);
        System.assertNotEquals(null, detail.po);
        System.assertEquals(po.Id, detail.po.id);
        System.assertNotEquals(null, detail.takeoff);
        System.assertEquals(takeoff.Id, detail.takeoff.id);
        System.assertEquals(takeoff.Name, detail.takeoff.name);
        System.assertEquals('Submitted', detail.takeoff.status);
    }

    @IsTest
    static void getBuilderPoStatusOptionsReturnsActivePicklistValues() {
        List<LovingPoPipelineController.OptionDTO> options =
            LovingPoPipelineController.getBuilderPoStatusOptions();

        System.assert(!options.isEmpty(), 'Expected live Builder PO status options.');
        System.assert(!String.isBlank(options[0].value));
        System.assert(!String.isBlank(options[0].label));
    }

    @IsTest
    static void getPipelineDataReturnsBuilderPoBackedRows() {
        Purchase_Order__c po = makePurchaseOrder(
            'PO-PIPE-LIST-001',
            'Pending CS Review',
            'Matched'
        );

        Test.startTest();
        LovingPoPipelineController.PipelineDTO pipeline = LovingPoPipelineController.getPipelineData();
        Test.stopTest();

        System.assertNotEquals(null, pipeline);
        System.assert(!pipeline.records.isEmpty(), 'Expected Builder PO-backed records.');

        Boolean found = false;
        for (LovingPoPipelineController.PoCardDTO card : pipeline.records) {
            if (card.id == po.Id) {
                found = true;
                System.assertEquals('PO-PIPE-LIST-001', card.name);
                System.assertEquals('Pending CS Review', card.status);
                System.assertNotEquals(null, card.builderPoId);
                break;
            }
        }
        System.assert(found, 'Expected the inserted Builder PO support record to appear in the pipeline.');
    }

    @IsTest
    static void getPoDetailBuildsRealActivityRows() {
        Purchase_Order__c po = makePurchaseOrder(
            'PO-PIPE-ACTIVITY-001',
            'Pending CS Review',
            'Matched'
        );

        Test.startTest();
        LovingPoPipelineController.DetailDTO detail = LovingPoPipelineController.getPoDetail(po.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail);
        System.assertNotEquals(null, detail.activity);
        System.assert(detail.activity.size() > 0, 'Expected real activity rows for the PO workspace.');

        Boolean sawPoCreated = false;
        for (LovingPoPipelineController.ActivityDTO row : detail.activity) {
            if (row.label == 'Purchase Order Created') {
                sawPoCreated = true;
                System.assert(row.detail.contains('Pending CS Review'));
            }
        }
        System.assert(sawPoCreated, 'Expected Purchase Order Created fallback activity row.');
    }

    @IsTest
    static void getPoDetailUsesTaskAndEventActivityRows() {
        Purchase_Order__c po = makePurchaseOrder(
            'PO-PIPE-ACTIVITY-002',
            'Pending CS Review',
            'Matched'
        );

        insert new Task(
            Subject = 'PO Follow Up',
            Status = 'Not Started',
            ActivityDate = Date.today(),
            WhatId = po.Id
        );

        insert new Event(
            Subject = 'PO Review Call',
            ActivityDateTime = System.now().addHours(2),
            DurationInMinutes = 30,
            WhatId = po.Id
        );

        Test.startTest();
        LovingPoPipelineController.DetailDTO detail = LovingPoPipelineController.getPoDetail(po.Id);
        Test.stopTest();

        Boolean sawTask = false;
        Boolean sawEvent = false;
        for (LovingPoPipelineController.ActivityDTO row : detail.activity) {
            if (row.label == 'PO Follow Up') {
                sawTask = true;
            }
            if (row.label == 'PO Review Call') {
                sawEvent = true;
            }
        }
        System.assert(sawTask, 'Expected task-backed activity row.');
        System.assert(sawEvent, 'Expected event-backed activity row.');
    }

    @IsTest(SeeAllData=true)
    static void updatePoStatusGuardrailsAndSuccessPaths() {
        Purchase_Order__c unmatchedPo = makePurchaseOrder(
            'PO-PIPE-STATUS-001',
            'Pending CS Review',
            'Not Reviewed'
        );
        LovingPoPipelineController.ActionResult blockedForTakeoff =
            LovingPoPipelineController.updatePoStatus(unmatchedPo.Id, 'Ready for Takeoff');
        System.assertEquals(false, blockedForTakeoff.passed);

        Purchase_Order__c noWorkOrderPo = makePurchaseOrder(
            'PO-PIPE-STATUS-002',
            'Takeoff Complete',
            'Matched'
        );
        LovingPoPipelineController.ActionResult blockedForWo =
            LovingPoPipelineController.updatePoStatus(noWorkOrderPo.Id, 'Work Order Created');
        System.assertEquals(false, blockedForWo.passed);

        WorkOrder linkedWo = [SELECT Id FROM WorkOrder LIMIT 1];
        update new Purchase_Order__c(
            Id = noWorkOrderPo.Id,
            Work_Order__c = linkedWo.Id,
            Status__c = 'Pending Takeoff',
            Takeoff_Status__c = 'Submitted'
        );
        LovingPoPipelineController.ActionResult blockedForSchedule =
            LovingPoPipelineController.updatePoStatus(noWorkOrderPo.Id, 'Clear for Schedule');
        System.assertEquals(false, blockedForSchedule.passed);

        Purchase_Order__c successPo = makePurchaseOrder(
            'PO-PIPE-STATUS-003',
            'Pending CS Review',
            'Matched'
        );
        LovingPoPipelineController.ActionResult moved =
            LovingPoPipelineController.updatePoStatus(successPo.Id, 'Pending Approval');
        System.assertEquals(true, moved.passed);
        System.assertEquals('Pending Approval', moved.newStatus);
    }

    @IsTest
    static void actionGuardsReturnTruthfulFailures() {
        Purchase_Order__c po = makePurchaseOrder(
            'PO-PIPE-GUARD-001',
            'Pending CS Review',
            'Not Reviewed'
        );

        try {
            LovingPoPipelineController.createOrGetTakeoff(po.Id);
            System.assert(false, 'Expected package guard to block takeoff creation.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        Purchase_Order__c missingNumberPo = makePurchaseOrder(
            'PO-PIPE-GUARD-002',
            'Pending CS Review',
            'Matched'
        );
        update new Purchase_Order__c(
            Id = missingNumberPo.Id,
            PO_Number__c = null
        );
        try {
            LovingPoPipelineController.createOrGetTakeoff(missingNumberPo.Id);
            System.assert(false, 'Expected blank PO number to block takeoff creation.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        LovingPoPipelineController.ActionResult assignResult =
            LovingPoPipelineController.assignTakeoffFieldManager(null, null, null);
        System.assertEquals(false, assignResult.passed);

        LovingPoPipelineController.ActionResult readinessResult =
            LovingPoPipelineController.updateTakeoffReadiness(null, true, true, 2);
        System.assertEquals(false, readinessResult.passed);

        LovingPoPipelineController.ActionResult workOrderResult =
            LovingPoPipelineController.createProductionWorkOrder(null);
        System.assertEquals(false, workOrderResult.passed);

        Purchase_Order__c noTakeoffPo = makePurchaseOrder(
            'PO-PIPE-GUARD-003',
            'Pending CS Review',
            'Matched'
        );
        LovingPoPipelineController.ActionResult missingTakeoffResult =
            LovingPoPipelineController.createProductionWorkOrder(noTakeoffPo.Id);
        System.assertEquals(false, missingTakeoffResult.passed);

        LovingPoPipelineController.ActionResult handoffResult =
            LovingPoPipelineController.createScheduleHandoff(null);
        System.assertEquals(false, handoffResult.passed);
    }

    @IsTest
    static void helperBranchesAndErrorGuardsStayTruthful() {
        System.assertEquals(
            'takeoffComplete',
            LovingPoPipelineController.mapToBoardColumn('PO Received', 'Takeoff Complete', null)
        );
        System.assertEquals(
            'takeoffProgress',
            LovingPoPipelineController.mapToBoardColumn('PO Received', 'Takeoff In Progress', null)
        );
        System.assertEquals(
            'takeoffScheduled',
            LovingPoPipelineController.mapToBoardColumn('PO Received', 'Takeoff Scheduled', null)
        );
        System.assertEquals(
            'packageCheck',
            LovingPoPipelineController.mapToBoardColumn('PO Received', 'Package Match Check', null)
        );
        System.assertNotEquals(
            null,
            LovingPoPipelineController.mapToBoardColumn(null, 'Pending Approval', null)
        );

        LovingPoPipelineController.DetailDTO detail = new LovingPoPipelineController.DetailDTO();
        detail.takeoff = new LovingPoPipelineController.TakeoffSummaryDTO();
        detail.takeoff.fieldManagerId = null;
        detail.takeoff.status = 'Draft';
        System.assertEquals('Assign Field Manager', LovingPoPipelineController.deriveNextAction(detail));

        detail.takeoff.fieldManagerId = UserInfo.getUserId();
        System.assertEquals('Approve Takeoff', LovingPoPipelineController.deriveNextAction(detail));

        detail.takeoff.status = 'Approved';
        System.assertEquals('Create Production WorkOrder', LovingPoPipelineController.deriveNextAction(detail));

        System.assertEquals('Awaiting takeoff', LovingPoPipelineController.displayStatusLabel('Ready for Takeoff'));
        System.assertEquals('Ready for WorkOrder handoff', LovingPoPipelineController.displayStatusLabel('Takeoff Complete'));
        System.assertEquals('WorkOrder handoff', LovingPoPipelineController.displayStatusLabel('Work Order Created'));
        System.assertEquals('Ready for scheduling', LovingPoPipelineController.displayStatusLabel('Clear for Schedule'));
        System.assertEquals('Pending Approval', LovingPoPipelineController.displayStatusLabel('Pending Approval'));

        System.assertEquals(null, LovingPoPipelineController.choosePrimaryServiceAppointment(null));

        ServiceAppointment tieA = new ServiceAppointment(
            Status = 'Dispatched',
            Subject = 'Tie A',
            SchedStartTime = System.now().addHours(1)
        );
        ServiceAppointment tieB = new ServiceAppointment(
            Status = 'Dispatched',
            Subject = 'Tie B',
            SchedStartTime = System.now().addHours(4)
        );
        System.assertEquals(
            'Tie B',
            LovingPoPipelineController.choosePrimaryServiceAppointment(
                new List<ServiceAppointment>{ tieA, tieB }
            ).Subject
        );
        System.assertEquals(
            'Other',
            LovingPoPipelineController.choosePrimaryServiceAppointment(
                new List<ServiceAppointment>{
                    new ServiceAppointment(Status = 'Other', Subject = 'Other')
                }
            ).Subject
        );

        try {
            LovingPoPipelineController.getPoDetail(null);
            System.assert(false, 'Expected null Builder PO support record Id to be rejected.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            LovingPoPipelineController.getBuilderPoDetail(null);
            System.assert(false, 'Expected null Builder PO Id to be rejected.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void takeoffActionSuccessAndTruthfulDownstreamBlocks() {
        Purchase_Order__c po = makePurchaseOrder(
            'PO-PIPE-ACTION-001',
            'Pending CS Review',
            'Matched'
        );

        String takeoffId = LovingPoPipelineController.createOrGetTakeoff(po.Id);
        System.assertNotEquals(null, takeoffId, 'Expected takeoff creation/open on the standard backbone.');

        LovingPoPipelineController.ActionResult assignResult =
            LovingPoPipelineController.assignTakeoffFieldManager(po.Id, UserInfo.getUserId(), Date.today().addDays(1));
        System.assertEquals(true, assignResult.passed);

        Purchase_Order__c unscheduledPo = makePurchaseOrder(
            'PO-PIPE-ACTION-002',
            'Pending CS Review',
            'Matched'
        );
        String unscheduledTakeoffId = LovingPoPipelineController.createOrGetTakeoff(unscheduledPo.Id);
        System.assertNotEquals(null, unscheduledTakeoffId);
        LovingPoPipelineController.ActionResult unscheduledAssignResult =
            LovingPoPipelineController.assignTakeoffFieldManager(unscheduledPo.Id, UserInfo.getUserId(), null);
        System.assertEquals(true, unscheduledAssignResult.passed);
        System.assertEquals('Ready for Takeoff', unscheduledAssignResult.newStatus);

        LovingPoPipelineController.ActionResult readinessResult =
            LovingPoPipelineController.updateTakeoffReadiness((Id) takeoffId, true, true, 3);
        System.assertEquals(true, readinessResult.passed);
        LovingPoPipelineController.ActionResult readinessResetResult =
            LovingPoPipelineController.updateTakeoffReadiness((Id) takeoffId, false, false, null);
        System.assertEquals(true, readinessResetResult.passed);

        LovingPoPipelineController.ActionResult workOrderResult =
            LovingPoPipelineController.createProductionWorkOrder(po.Id);
        System.assertEquals(false, workOrderResult.passed, 'Unapproved takeoff should block WorkOrder creation.');

        LovingPoPipelineController.ActionResult handoffResult =
            LovingPoPipelineController.createScheduleHandoff(po.Id);
        System.assertEquals(false, handoffResult.passed, 'Missing WorkOrder should block scheduling handoff.');
    }

    @IsTest
    static void builderPoDetailErrorStatesAreTruthful() {
        Account missingNumberAcct = new Account(Name = 'Builder PO Missing Number Account');
        insert missingNumberAcct;
        Builder_PO__c missingNumber = new Builder_PO__c(
            Builder_Account__c = missingNumberAcct.Id,
            Division_Account__c = missingNumberAcct.Id
        );
        insert missingNumber;
        try {
            LovingPoPipelineController.getBuilderPoDetail(missingNumber.Id);
            System.assert(false, 'Expected missing PO number to be rejected.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        Account acct = new Account(Name = 'Builder PO Detail Error Account');
        insert acct;
        Builder_PO__c noMatch = new Builder_PO__c(
            PO_Number__c = 'PO-NO-MATCH-001',
            Builder_Account__c = acct.Id,
            Division_Account__c = acct.Id
        );
        insert noMatch;
        try {
            LovingPoPipelineController.getBuilderPoDetail(noMatch.Id);
            System.assert(false, 'Expected unmatched Builder PO to be rejected.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest(SeeAllData=true)
    static void successfulTakeoffAndWorkOrderActionsCoverStandardBackboneBranches() {
        Purchase_Order__c takeoffPo = [
            SELECT Id, PO_Number__c, Package_BMG_Status__c, Work_Order__c
            FROM Purchase_Order__c
            WHERE PO_Number__c != null
              AND Package_BMG_Status__c = 'Matched'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        String takeoffId = LovingPoPipelineController.createOrGetTakeoff(takeoffPo.Id);
        System.assertNotEquals(null, takeoffId, 'Expected takeoff creation/open on the standard backbone.');

        LovingPoPipelineController.ActionResult readinessResult =
            LovingPoPipelineController.updateTakeoffReadiness((Id) takeoffId, true, true, 3);
        System.assertEquals(true, readinessResult.passed, 'Expected takeoff readiness update to succeed.');

        List<Purchase_Order__c> approvedTakeoffRows = [
            SELECT Id, Work_Order__c
            FROM Purchase_Order__c
            WHERE Work_Order__c != null
              AND Id IN (
                  SELECT Purchase_Order__c
                  FROM Takeoff__c
                  WHERE Status__c = 'Approved'
              )
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!approvedTakeoffRows.isEmpty()) {
            LovingPoPipelineController.ActionResult woResult =
                LovingPoPipelineController.createProductionWorkOrder(approvedTakeoffRows[0].Id);
            System.assertEquals(true, woResult.passed, 'Expected existing parent WorkOrder refresh branch to succeed.');
            System.assertEquals(approvedTakeoffRows[0].Work_Order__c, woResult.workOrderId);
        }
    }

    @IsTest(SeeAllData=true)
    static void liveStandardPathSmokeCoversRealWorkspaceBackbone() {
        List<LovingPoPipelineController.OptionDTO> options =
            LovingPoPipelineController.getBuilderPoStatusOptions();
        System.assert(!options.isEmpty(), 'Expected Builder PO statuses from live metadata.');

        LovingPoPipelineController.PipelineDTO pipeline = LovingPoPipelineController.getPipelineData();
        System.assertNotEquals(null, pipeline);
        System.assertNotEquals(null, pipeline.records);

        List<Purchase_Order__c> livePoRows = [
            SELECT Id, PO_Number__c, Status__c, Work_Order__c, Package_BMG_Status__c
            FROM Purchase_Order__c
            WHERE PO_Number__c != null
              AND Work_Order__c != null
              AND Package_BMG_Status__c = 'Matched'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (livePoRows.isEmpty()) {
            return; // no matched PO with linked WO exists in org at query time
        }
        Purchase_Order__c livePo = livePoRows[0];

        Test.startTest();
        LovingPoPipelineController.DetailDTO poDetail =
            LovingPoPipelineController.getPoDetail(livePo.Id);
        Test.stopTest();

        System.assertNotEquals(null, poDetail);
        System.assertNotEquals(null, poDetail.po);
        System.assertEquals(livePo.Id, poDetail.po.id);
        System.assertNotEquals(null, poDetail.workOrder, 'Expected linked standard WorkOrder summary.');

        List<Builder_PO__c> builderPos = [
            SELECT Id
            FROM Builder_PO__c
            WHERE PO_Number__c = :livePo.PO_Number__c
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!builderPos.isEmpty()) {
            LovingPoPipelineController.DetailDTO builderDetail =
                LovingPoPipelineController.getBuilderPoDetail(builderPos[0].Id);
            System.assertNotEquals(null, builderDetail);
            System.assertEquals((String) builderPos[0].Id, builderDetail.po.builderPoId);
        }

        LovingPoPipelineController.ActionResult handoff =
            LovingPoPipelineController.createScheduleHandoff(livePo.Id);
        System.assertEquals(true, handoff.passed, 'Expected live scheduling handoff normalization to succeed.');

        List<Purchase_Order__c> workOrderReadyRows = [
            SELECT Id
            FROM Purchase_Order__c
            WHERE Work_Order__c != null
              AND Id IN (
                  SELECT Purchase_Order__c
                  FROM Takeoff__c
                  WHERE Status__c = 'Approved'
              )
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!workOrderReadyRows.isEmpty()) {
            LovingPoPipelineController.ActionResult woRefresh =
                LovingPoPipelineController.createProductionWorkOrder(workOrderReadyRows[0].Id);
            System.assertEquals(true, woRefresh.passed, 'Expected existing parent WorkOrder branch to succeed.');
        }
    }
}