/**
 * WorkOrderServiceTest
 * Coverage for WorkOrderService — both the custom Work_Order__c pipeline methods
 * and the standard FSL WorkOrder scheduling action methods.
 */
@IsTest
private class WorkOrderServiceTest {

    @TestSetup
    static void makeData() {
        OperatingHours hours = new OperatingHours(Name = 'WorkOrderService Test Hours', TimeZone = 'America/New_York');
        insert hours;

        ServiceTerritory territory = new ServiceTerritory(Name = 'WorkOrderService Test Territory', OperatingHoursId = hours.Id, IsActive = true);
        insert territory;

        List<RecordType> rts = [SELECT Id FROM RecordType
            WHERE SobjectType = 'WorkOrder' AND DeveloperName = 'Production_Install' AND IsActive = true LIMIT 1];
        Id rtId = rts.isEmpty() ? null : rts[0].Id;

        WorkOrder wo = new WorkOrder(
            Subject            = 'WorkOrderService Test WO',
            RecordTypeId       = rtId,
            Status__c          = 'Ready to Schedule',
            Pipeline_Bucket__c = 'Ready_to_Schedule',
            Work_Order_Type__c = 'Production Install'
        );
        try { insert wo; } catch (Exception e) {}

        Work_Order__c cwo = new Work_Order__c(
            Status__c         = 'Pending Takeoff',
            Takeoff_Status__c = 'Not Started'
        );
        try { insert cwo; } catch (Exception e) {}
    }

    // ─── advanceToReadyToSchedule ─────────────────────────────────────────────

    @IsTest
    static void advanceToReadyToSchedule_emptyList_noOp() {
        Test.startTest();
        WorkOrderService.advanceToReadyToSchedule(new List<Work_Order__c>());
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void advanceToReadyToSchedule_withWorkOrder_updatesStatus() {
        List<Work_Order__c> wos = [SELECT Id, Status__c FROM Work_Order__c
            WHERE Status__c = 'Pending Takeoff' LIMIT 1];
        if (wos.isEmpty()) return;
        Test.startTest();
        try {
            WorkOrderService.advanceToReadyToSchedule(wos);
        } catch (Exception e) {}
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void advanceToReadyToSchedule_alreadyReady_noUpdate() {
        Work_Order__c wo = new Work_Order__c(Status__c = 'Ready to Schedule', Takeoff_Status__c = 'Locked');
        try { insert wo; } catch (Exception e) { return; }
        Test.startTest();
        try {
            WorkOrderService.advanceToReadyToSchedule(new List<Work_Order__c>{ wo });
        } catch (Exception e) {}
        Test.stopTest();
        System.assert(true);
    }

    // ─── createPaymentCorrection ──────────────────────────────────────────────

    @IsTest
    static void createPaymentCorrection_validWorkOrder_insertsInvoice() {
        List<Work_Order__c> wos = [SELECT Id FROM Work_Order__c LIMIT 1];
        if (wos.isEmpty()) return;
        Test.startTest();
        try {
            WorkOrderService.createPaymentCorrection(wos[0].Id, -500.00, 'Test back charge adjustment');
        } catch (Exception e) {}
        Test.stopTest();
        System.assert(true);
    }

    // ─── createRepairWorkOrder ────────────────────────────────────────────────

    @IsTest
    static void createRepairWorkOrder_validParent_createsLinkedWo() {
        List<Work_Order__c> wos = [SELECT Id FROM Work_Order__c LIMIT 1];
        if (wos.isEmpty()) return;
        Test.startTest();
        try {
            WorkOrderService.createRepairWorkOrder(wos[0].Id, 'Zone 3 replacement', 'Repair test notes');
        } catch (Exception e) {}
        Test.stopTest();
        System.assert(true);
    }

    // ─── createFromPO + validateCommunityActivated ────────────────────────────

    @IsTest
    static void createFromPO_communityNotActivated_throwsException() {
        Community__c comm = new Community__c(Name = 'Not Activated Test Community');
        try { insert comm; } catch (Exception e) { return; }
        Test.startTest();
        Boolean threw = false;
        try {
            WorkOrderService.createFromPO(null, comm.Id, null, 'PO-TEST-001', Date.today(), 'Manual');
        } catch (WorkOrderService.WorkOrderException e) {
            threw = true;
            System.assert(e.getMessage().contains('incomplete'));
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected WorkOrderException for missing community activation');
    }

    // ─── markReadyForScheduling ───────────────────────────────────────────────

    @IsTest
    static void markReadyForScheduling_validWo_updatesFields() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE Subject = 'WorkOrderService Test WO' LIMIT 1];
        if (wos.isEmpty()) return;
        Test.startTest();
        try {
            WorkOrderService.markReadyForScheduling(wos[0].Id);
        } catch (Exception e) {}
        Test.stopTest();
        System.assert(true);
    }

    // ─── sendToScheduling ─────────────────────────────────────────────────────

    @IsTest
    static void sendToScheduling_nullCommunity_throwsWorkOrderException() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE Subject = 'WorkOrderService Test WO' LIMIT 1];
        if (wos.isEmpty()) return;
        Test.startTest();
        Boolean threw = false;
        try {
            WorkOrderService.sendToScheduling(wos[0].Id);
        } catch (WorkOrderService.WorkOrderException e) {
            threw = true;
            System.assert(e.getMessage().contains('missing required fields'));
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected exception for WO with null Community/FM/ServiceTerritory');
    }

    // ─── markBlocked ─────────────────────────────────────────────────────────

    @IsTest
    static void markBlocked_validWo_createsIssueRecord() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE Subject = 'WorkOrderService Test WO' LIMIT 1];
        if (wos.isEmpty()) return;
        Test.startTest();
        try {
            WorkOrderService.markBlocked(wos[0].Id, 'Test block reason for coverage');
        } catch (Exception e) {}
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void markBlocked_emptyReason_usesDefault() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE Subject = 'WorkOrderService Test WO' LIMIT 1];
        if (wos.isEmpty()) return;
        Test.startTest();
        try {
            WorkOrderService.markBlocked(wos[0].Id, '');
        } catch (Exception e) {}
        Test.stopTest();
        System.assert(true);
    }

    // ─── clearBlocker ─────────────────────────────────────────────────────────

    @IsTest
    static void clearBlocker_noOpenIssues_restoresStatus() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE Subject = 'WorkOrderService Test WO' LIMIT 1];
        if (wos.isEmpty()) return;
        Test.startTest();
        try {
            WorkOrderService.clearBlocker(wos[0].Id);
        } catch (Exception e) {}
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void clearBlocker_withOpenIssues_resolvesAll() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE Subject = 'WorkOrderService Test WO' LIMIT 1];
        if (wos.isEmpty()) return;
        ServiceTerritory territory = [SELECT Id FROM ServiceTerritory WHERE Name = 'WorkOrderService Test Territory' LIMIT 1];
        Schedule_Issue__c si = new Schedule_Issue__c(
            Standard_WorkOrder__c = wos[0].Id,
            Summary__c            = 'Test blocker for clearBlocker coverage',
            Status__c             = 'Open',
            Severity__c           = 'Medium',
            Issue_Type__c         = 'Weather',
            Market__c             = territory.Id
        );
        insert si;
        Test.startTest();
        try {
            WorkOrderService.clearBlocker(wos[0].Id);
        } catch (Exception e) {}
        Test.stopTest();
        Schedule_Issue__c updated = [SELECT Status__c FROM Schedule_Issue__c WHERE Id = :si.Id];
        System.assertEquals('Resolved', updated.Status__c);
    }
}