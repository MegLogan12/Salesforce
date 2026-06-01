@isTest
private class LovingTakeoffGateControllerTest {

    @TestSetup
    static void setup() {
        Account builderAccount = new Account(Name = 'Test Builder Account');
        insert builderAccount;

        Account divAccount = new Account(Name = 'Test Division Account');
        insert divAccount;

        Id standardPricebookId = Test.getStandardPricebookId();
        Product2 product = new Product2(Name = 'Sod Product', IsActive = true);
        insert product;
        insert new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 10,
            IsActive = true
        );

        Purchase_Order__c po = new Purchase_Order__c(
            Builder_Account__c = builderAccount.Id,
            Division_Account__c = divAccount.Id,
            PO_Amount__c = 6000,
            Approval_Process_Completed__c = false,
            PO_Number__c = 'PO-TST-001',
            Item__c = product.Id,
            Quantity__c = 25
        );
        insert po;

        Builder_PO__c builderPo = new Builder_PO__c(
            PO_Number__c = po.PO_Number__c,
            Division_Account__c = divAccount.Id,
            Builder_Account__c = builderAccount.Id,
            Community__c = po.Community__c,
            Lot__c = po.Lot__c
        );
        insert builderPo;

        Takeoff__c t = new Takeoff__c(
            Purchase_Order__c = po.Id,
            Builder_PO__c = builderPo.Id,
            Status__c = 'In Progress',
            Sod_Sqft__c = 3200,
            Sod_Measured_Sqft__c = 3200,
            Plants_Count__c = 3,
            Trees_Count__c = 2,
            Mulch_Measured_CY__c = 3.5,
            Photo_Count__c = 0,
            Checklist_Complete__c = false,
            Eight11_Confirmed__c = false
        );
        insert t;
    }

    @isTest
    static void testGetKpiSummary() {
        Test.startTest();
        LovingTakeoffGateController.KpiDTO kpi =
            LovingTakeoffGateController.getKpiSummary();
        Test.stopTest();

        System.assertNotEquals(null, kpi);
        System.assertEquals(1, kpi.totalTakeoffs);
        System.assertEquals(0, kpi.matched);
        System.assertEquals(0, kpi.returned);
        System.assertEquals(0, kpi.submitted);
    }

    @isTest
    static void testGetTakeoffRecord_validId() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];

        Test.startTest();
        LovingTakeoffGateController.TakeoffDTO dto =
            LovingTakeoffGateController.getTakeoffRecord(t.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals(t.Id, dto.id);
        System.assertEquals('In Progress', dto.status);
        System.assertEquals(5, dto.gates.size());
        System.assertEquals(false, dto.eight11Confirmed);
        System.assertEquals(false, dto.canApprove);
        System.assertEquals(false, dto.canCreateWo);
    }

    @isTest
    static void testGetTakeoffRecord_nullId() {
        Test.startTest();
        LovingTakeoffGateController.TakeoffDTO dto =
            LovingTakeoffGateController.getTakeoffRecord(null);
        Test.stopTest();

        System.assertEquals(null, dto);
    }

    @isTest
    static void testGetTakeoffRecord_lineItems_sodMatch() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];

        Test.startTest();
        LovingTakeoffGateController.TakeoffDTO dto =
            LovingTakeoffGateController.getTakeoffRecord(t.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto.lineItems);
        System.assert(dto.lineItems.size() > 0);
        LovingTakeoffGateController.LineItemDTO sodLine = null;
        for (LovingTakeoffGateController.LineItemDTO li : dto.lineItems) {
            if (li.lineName == 'Sod') { sodLine = li; break; }
        }
        System.assertNotEquals(null, sodLine);
        System.assertEquals('Match', sodLine.decision);
    }

    @isTest
    static void testGetTakeoffRecord_usesPersistedTakeoffLinesWhenAvailable() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];
        insert new Takeoff_Line__c(
            Takeoff__c = t.Id,
            Item_Name__c = 'Custom Sod Scope',
            PO_Quantity__c = 10,
            Verified_Quantity__c = 10,
            Unit__c = 'Sq Ft',
            Determination__c = 'Match'
        );

        Test.startTest();
        LovingTakeoffGateController.TakeoffDTO dto =
            LovingTakeoffGateController.getTakeoffRecord(t.Id);
        Test.stopTest();

        System.assertEquals(1, dto.lineItems.size());
        System.assertEquals('Custom Sod Scope', dto.lineItems[0].lineName);
        System.assertEquals('Match', dto.lineItems[0].decision);
    }

    @isTest
    static void testApproveTakeoff_blockedByChecklist() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];

        Test.startTest();
        LovingTakeoffGateController.ActionResult result =
            LovingTakeoffGateController.approveTakeoff(t.Id);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('checklist'));
    }

    @isTest
    static void testApproveTakeoff_blockedByPhoto() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];
        update new Takeoff__c(Id = t.Id, Checklist_Complete__c = true, Photo_Count__c = 0);

        Test.startTest();
        LovingTakeoffGateController.ActionResult result =
            LovingTakeoffGateController.approveTakeoff(t.Id);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('photo'));
    }

    @isTest
    static void testApproveTakeoff_blockedBy811() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];
        update new Takeoff__c(Id = t.Id, Checklist_Complete__c = true, Photo_Count__c = 2, Eight11_Confirmed__c = false);

        Test.startTest();
        LovingTakeoffGateController.ActionResult result =
            LovingTakeoffGateController.approveTakeoff(t.Id);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('811'));
    }

    @isTest
    static void testApproveTakeoff_passes() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];
        update new Takeoff__c(Id = t.Id, Checklist_Complete__c = true, Photo_Count__c = 2, Eight11_Confirmed__c = true);

        Test.startTest();
        LovingTakeoffGateController.ActionResult result =
            LovingTakeoffGateController.approveTakeoff(t.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        Takeoff__c updated = [SELECT Status__c, Approved_By__c FROM Takeoff__c WHERE Id = :t.Id];
        System.assertEquals('Approved', updated.Status__c);
        System.assertNotEquals(null, updated.Approved_By__c);

        Purchase_Order__c po = [SELECT Takeoff_Status__c, Pipeline_Bucket__c FROM Purchase_Order__c LIMIT 1];
        System.assert(po.Takeoff_Status__c == 'Approved' || po.Takeoff_Status__c == 'Locked',
            'PO Takeoff_Status__c should be Approved or Locked after takeoff approval: ' + po.Takeoff_Status__c);
        System.assertEquals('Clear for Schedule', po.Pipeline_Bucket__c);
    }

    @isTest
    static void testApproveTakeoff_createsStandardWorkScopeWhenLinkedWorkOrderExists() {
        Takeoff__c seededTakeoff = [SELECT Id, Purchase_Order__c FROM Takeoff__c LIMIT 1];
        Purchase_Order__c po = [SELECT Id, Division_Account__c FROM Purchase_Order__c WHERE Id = :seededTakeoff.Purchase_Order__c];

        LovingPoBackboneService.BackboneResult backbone = LovingPoBackboneService.ensureBackbone(po.Id);

        RecordType productionInstallRt = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'WorkOrder' AND DeveloperName = 'Production_Install'
            LIMIT 1
        ];
        WorkOrder wo = new WorkOrder(
            RecordTypeId = productionInstallRt.Id,
            AccountId = po.Division_Account__c,
            Subject = 'Gate Test Work Order',
            Status = 'New',
            Work_Order_Type__c = 'Production Install'
        );
        insert wo;

        update new Purchase_Order__c(
            Id = po.Id,
            Work_Order__c = wo.Id,
            Approval_Process_Completed__c = true
        );
        update new Takeoff__c(
            Id = backbone.takeoffId,
            Checklist_Complete__c = true,
            Photo_Count__c = 2,
            Eight11_Confirmed__c = true
        );
        update new Takeoff_Line__c(
            Id = [SELECT Id FROM Takeoff_Line__c WHERE Takeoff__c = :backbone.takeoffId LIMIT 1].Id,
            Review_Status__c = 'Approved'
        );

        Test.startTest();
        LovingTakeoffGateController.ActionResult result =
            LovingTakeoffGateController.approveTakeoff(backbone.takeoffId);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);
        System.assert(result.message.contains('scope generated'), result.message);
        System.assertEquals(1, [
            SELECT COUNT() FROM WorkOrderLineItem
            WHERE WorkOrderId = :wo.Id
        ], result.message);

        LovingTakeoffGateController.TakeoffDTO dto =
            LovingTakeoffGateController.getTakeoffRecord(backbone.takeoffId);
        System.assertEquals(true, dto.canCreateWo);
    }

    @isTest
    static void testApproveTakeoff_alreadyApproved() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];
        update new Takeoff__c(Id = t.Id, Status__c = 'Approved', Checklist_Complete__c = true, Photo_Count__c = 2, Eight11_Confirmed__c = true);

        Test.startTest();
        LovingTakeoffGateController.ActionResult result =
            LovingTakeoffGateController.approveTakeoff(t.Id);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.message.containsIgnoreCase('already approved'));
    }

    @isTest
    static void testReturnTakeoff_noReason() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];

        Test.startTest();
        LovingTakeoffGateController.ActionResult result =
            LovingTakeoffGateController.returnTakeoff(t.Id, '');
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    @isTest
    static void testReturnTakeoff_withReason() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];

        Test.startTest();
        LovingTakeoffGateController.ActionResult result =
            LovingTakeoffGateController.returnTakeoff(t.Id, 'Missing irrigation zone count');
        Test.stopTest();

        System.assertEquals(true, result.success);
        Takeoff__c updated = [SELECT Status__c, NFI_Count__c, NFI_Reason__c FROM Takeoff__c WHERE Id = :t.Id];
        System.assertEquals('Returned', updated.Status__c);
        System.assertEquals(1, Integer.valueOf(updated.NFI_Count__c));
        System.assertEquals('Missing irrigation zone count', updated.NFI_Reason__c);

        Purchase_Order__c po = [SELECT Takeoff_Status__c FROM Purchase_Order__c LIMIT 1];
        System.assertEquals('In Progress', po.Takeoff_Status__c);
    }

    @isTest
    static void testCanCreateWo_blockedUntilApprovedAndLinked() {
        Takeoff__c t = [SELECT Id FROM Takeoff__c LIMIT 1];
        update new Takeoff__c(Id = t.Id, Checklist_Complete__c = true, Photo_Count__c = 2, Eight11_Confirmed__c = true);
        LovingTakeoffGateController.approveTakeoff(t.Id);

        Purchase_Order__c po = [SELECT Id FROM Purchase_Order__c LIMIT 1];
        update new Purchase_Order__c(Id = po.Id, Approval_Process_Completed__c = false);

        Test.startTest();
        LovingTakeoffGateController.TakeoffDTO dto =
            LovingTakeoffGateController.getTakeoffRecord(t.Id);
        Test.stopTest();

        System.assertEquals(false, dto.canCreateWo);
    }
}