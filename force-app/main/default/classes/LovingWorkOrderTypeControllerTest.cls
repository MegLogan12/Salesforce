@isTest
private class LovingWorkOrderTypeControllerTest {

    @TestSetup
    static void makeData() {
        insert new Account(Name = 'WO Layout Test Account');

        WorkOrder wo = new WorkOrder(
            Subject = 'Primary Production Install Test',
            Status = 'New',
            AccountId = [SELECT Id FROM Account WHERE Name = 'WO Layout Test Account' LIMIT 1].Id,
            RecordTypeId = productionInstallRecordTypeId(),
            Work_Order_Type__c = 'Production Install',
            PO_Number__c = 'TEST-PO-001',
            Sod_Square_Footage__c = 1000,
            Tree_Quantity__c = 3,
            Mulch_CY__c = 2
        );
        insert wo;
    }

    private static Account testAccount() {
        return [SELECT Id, Name FROM Account WHERE Name = 'WO Layout Test Account' LIMIT 1];
    }

    private static Id workOrderRecordTypeId(String developerName) {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'WorkOrder'
            AND DeveloperName = :developerName
            LIMIT 1
        ].Id;
    }

    private static Id productionInstallRecordTypeId() {
        return workOrderRecordTypeId('Production_Install');
    }

    private static Id recordTypeIdForType(String workOrderType) {
        if (workOrderType == 'Finished Job') return workOrderRecordTypeId('Finished_Job');
        if (workOrderType == 'Warranty') return workOrderRecordTypeId('Warranty');
        if (workOrderType == 'Customer Care' || workOrderType == 'Customer Success') return workOrderRecordTypeId('Customer_Care');
        if (workOrderType == 'Aqua Check') return workOrderRecordTypeId('Aqua_Check');
        if (workOrderType == 'Aqua Pickup') return workOrderRecordTypeId('Aqua_Pickup');
        if (workOrderType == 'Aqua Emergency') return workOrderRecordTypeId('Aqua_Emergency');
        if (workOrderType == 'Irrigation') return workOrderRecordTypeId('Inground_Irrigation');
        if (workOrderType == 'Grading') return workOrderRecordTypeId('Plant_Sod_Grading');
        if (workOrderType == 'Lawn Care') return workOrderRecordTypeId('Lawn_Care');
        if (workOrderType == 'Hardscape') return workOrderRecordTypeId('Hardscape');
        return productionInstallRecordTypeId();
    }

    private static WorkOrder makeWorkOrder(String subject, String status, String workOrderType) {
        WorkOrder wo = new WorkOrder(
            Subject = subject,
            Status = status,
            AccountId = testAccount().Id,
            RecordTypeId = recordTypeIdForType(workOrderType),
            Sod_Square_Footage__c = 100
        );
        if (workOrderType != null) {
            wo.Work_Order_Type__c = workOrderType;
        }
        return wo;
    }

    @isTest
    static void testGetWorkOrderRecord_productionInstall() {
        WorkOrder wo = [SELECT Id FROM WorkOrder WHERE Subject = 'Primary Production Install Test' LIMIT 1];

        Test.startTest();
        LovingWorkOrderTypeController.WoTypeDTO dto = LovingWorkOrderTypeController.getWorkOrderRecord(wo.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should not be null');
        System.assertEquals('New', dto.status);
        System.assertEquals('Production Install', dto.woType, 'Type should normalize to the live launch value');
        System.assertEquals('TEST-PO-001', dto.poNumber);
        System.assertEquals(1000, dto.sodSqft);
        System.assertEquals(12, dto.stages.size(), 'Production Install should render the corrected launch stage set');
        System.assertNotEquals(null, dto.gates, 'Gates should not be null');
        System.assertEquals(null, dto.saId, 'No SA in test data - saId should be null');
        System.assertNotEquals(null, dto.photoCount, 'photoCount should not be null');
    }

    @isTest
    static void testGetWorkOrderRecord_blank() {
        Test.startTest();
        LovingWorkOrderTypeController.WoTypeDTO dto = LovingWorkOrderTypeController.getWorkOrderRecord('');
        Test.stopTest();
        System.assertEquals(null, dto, 'Blank ID should return null');
    }

    @isTest
    static void testGetWorkOrderRecord_notFound() {
        Test.startTest();
        LovingWorkOrderTypeController.WoTypeDTO dto = LovingWorkOrderTypeController.getWorkOrderRecord('0WO000000000000AAA');
        Test.stopTest();
        System.assertEquals(null, dto, 'Not-found ID should return null');
    }

    @isTest
    static void testSubmitJobComplete_notInProgress() {
        WorkOrder wo = makeWorkOrder('Submit Complete Negative Test', 'New', 'Lawn Care');
        insert wo;

        Test.startTest();
        LovingWorkOrderTypeController.ActionResult result = LovingWorkOrderTypeController.submitJobComplete(wo.Id);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail when not In Progress');
    }

    @isTest
    static void testSubmitJobComplete_inProgress() {
        WorkOrder wo = makeWorkOrder('Submit Complete Positive Test', 'In Progress', 'Lawn Care');
        insert wo;

        Test.startTest();
        LovingWorkOrderTypeController.ActionResult result = LovingWorkOrderTypeController.submitJobComplete(wo.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed when In Progress');
        WorkOrder updated = [SELECT Status FROM WorkOrder WHERE Id = :wo.Id];
        System.assertEquals('Completed', updated.Status);
    }

    @isTest
    static void testSubmitJobComplete_blankId() {
        Test.startTest();
        LovingWorkOrderTypeController.ActionResult result = LovingWorkOrderTypeController.submitJobComplete('');
        Test.stopTest();
        System.assertEquals(false, result.success);
    }

    @isTest
    static void testGetWorkOrderRecord_recordTypeFallbackWorks() {
        WorkOrder wo = makeWorkOrder('Record Type Fallback Test', 'In Progress', 'Production Install');
        insert wo;

        Test.startTest();
        LovingWorkOrderTypeController.WoTypeDTO dto = LovingWorkOrderTypeController.getWorkOrderRecord(wo.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should not be null for record-type fallback WO');
        System.assertEquals('Production Install', dto.woType, 'Production Install should stay normalized on the live required type field');
        System.assertEquals('Production_Install', dto.recordTypeName, 'Production Install record type should be surfaced');
        System.assertEquals(12, dto.stages.size(), 'Production Install stage path should still render through record-type fallback');
        System.assertEquals(true, dto.canSubmitComplete, 'In Progress WO should allow submit');
    }

    @isTest
    static void testStageModelsRepresentativeWorkOrderTypes() {
        List<WorkOrder> workOrders = new List<WorkOrder>{
            makeWorkOrder('Warranty Test', 'New', 'Warranty'),
            makeWorkOrder('Customer Care Test', 'In Progress', 'Customer Care'),
            makeWorkOrder('Aqua Check Test', 'Completed', 'Aqua Check'),
            makeWorkOrder('Aqua Pickup Test', 'In Progress', 'Aqua Pickup'),
            makeWorkOrder('Grading Test', 'Completed', 'Grading'),
            makeWorkOrder('Lawn Care Test', 'In Progress', 'Lawn Care')
        };
        insert workOrders;

        Map<String, Integer> expectedStageCounts = new Map<String, Integer>{
            'Warranty' => 6,
            'Customer Success' => 6,
            'Aqua Check' => 5,
            'Aqua Pickup' => 5,
            'Grading' => 7,
            'Lawn Care' => 6
        };
        Set<String> stageSubjects = new Set<String>{
            'Warranty Test',
            'Customer Care Test',
            'Aqua Check Test',
            'Aqua Pickup Test',
            'Grading Test',
            'Lawn Care Test'
        };

        Test.startTest();
        for (WorkOrder wo : [SELECT Id, Subject, Work_Order_Type__c FROM WorkOrder WHERE Subject IN :stageSubjects]) {
            LovingWorkOrderTypeController.WoTypeDTO dto = LovingWorkOrderTypeController.getWorkOrderRecord(wo.Id);
            System.assertNotEquals(null, dto, wo.Subject + ' DTO should not be null');
            System.assertEquals(expectedStageCounts.get(dto.woType), dto.stages.size(), dto.woType + ' should render the corrected stage count');
            System.assertNotEquals(null, dto.gates, dto.woType + ' gates should not be null');
        }
        Test.stopTest();
    }

    @isTest
    static void testGateModelsForWarrantyAndCustomerSuccess() {
        Case supportCase = new Case(Subject = 'Warranty Source', Status = 'New', Origin = 'Phone');
        insert supportCase;

        WorkOrder warranty = makeWorkOrder('Warranty Gate Test', 'New', 'Warranty');
        warranty.CaseId = supportCase.Id;

        WorkOrder customerCare = makeWorkOrder('Customer Care Gate Test', 'New', 'Customer Care');
        customerCare.CaseId = supportCase.Id;

        insert new List<WorkOrder>{warranty, customerCare};

        Test.startTest();
        LovingWorkOrderTypeController.WoTypeDTO warrantyDto = LovingWorkOrderTypeController.getWorkOrderRecord(warranty.Id);
        LovingWorkOrderTypeController.WoTypeDTO customerCareDto = LovingWorkOrderTypeController.getWorkOrderRecord(customerCare.Id);
        Test.stopTest();

        System.assertEquals(3, warrantyDto.gates.size(), 'Warranty should render the issue/case/service gates');
        System.assertEquals(3, customerCareDto.gates.size(), 'Customer Success should render the case/service/photo gates');
        System.assertEquals(true, warrantyDto.gates[0].complete, 'Warranty case-linked gate should be complete');
        System.assertEquals(true, customerCareDto.gates[0].complete, 'Customer Success case-linked gate should be complete');
    }
}