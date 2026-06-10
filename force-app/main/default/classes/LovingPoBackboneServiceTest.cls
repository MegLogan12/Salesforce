@isTest
private class LovingPoBackboneServiceTest {

    @TestSetup
    static void setup() {
        Account builder = new Account(Name = 'Backbone Builder');
        insert builder;

        Account division = new Account(Name = 'Backbone Division');
        insert division;

        Product2 product = new Product2(Name = 'Backbone Sod', ProductCode = 'SOD-100', IsActive = true);
        insert product;

        insert new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            UnitPrice = 12.5,
            IsActive = true
        );

        Purchase_Order__c po = new Purchase_Order__c(
            Builder_Account__c = builder.Id,
            Division_Account__c = division.Id,
            PO_Number__c = 'BB-PO-001',
            Item__c = product.Id,
            Quantity__c = 20,
            Total_Amount__c = 250,
            Status__c = 'Pending Takeoff',
            Package_BMG_Status__c = 'Matched'
        );
        insert po;

        insert new Builder_PO__c(
            PO_Number__c = 'BB-PO-001',
            Status__c = 'Pending Takeoff',
            Builder_Account__c = builder.Id,
            Division_Account__c = division.Id
        );
    }

    @isTest
    static void testEnsureBackboneCreatesStandardChain() {
        Purchase_Order__c po = [SELECT Id FROM Purchase_Order__c WHERE PO_Number__c = 'BB-PO-001' LIMIT 1];

        Test.startTest();
        LovingPoBackboneService.BackboneResult result = LovingPoBackboneService.ensureBackbone(po.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.orderId, 'Standard Order should be created.');
        System.assertNotEquals(null, result.takeoffId, 'Takeoff should be created.');
        System.assertEquals(1, result.orderItemCount, 'One standard OrderItem should be created from header fallback.');
        System.assertEquals(1, [SELECT COUNT() FROM Takeoff_Line__c WHERE Takeoff__c = :result.takeoffId], 'One Takeoff Line should be created.');
        System.assertEquals(true, result.usedHeaderFallback, 'Legacy header fallback should be used when no PO line rows exist.');
        System.assertEquals(1, result.discrepancyLineCount, 'Fallback line should surface as a discrepancy requiring review.');
        System.assertNotEquals(null, result.reviewTaskId, 'Discrepancy review should create a task.');
        Order createdOrder = [SELECT Id, Builder_PO__c, Community__c, Lot__c FROM Order WHERE Id = :result.orderId LIMIT 1];
        System.assertNotEquals(null, createdOrder.Builder_PO__c, 'Order should trace back to the staging Builder PO.');
        Takeoff_Line__c createdLine = [SELECT Review_Status__c FROM Takeoff_Line__c WHERE Takeoff__c = :result.takeoffId LIMIT 1];
        System.assertEquals('Discrepancy', createdLine.Review_Status__c, 'Fallback lines should require review before execution.');
        Task reviewTask = [SELECT Id, Subject, WhatId, Status FROM Task WHERE Id = :result.reviewTaskId LIMIT 1];
        System.assert(reviewTask.Subject.contains('Takeoff discrepancy'), 'Review task should be clearly labeled.');
        System.assertEquals(createdOrder.Id, reviewTask.WhatId, 'Review task should anchor to the generated standard Order.');
        System.assertEquals('Not Started', reviewTask.Status, 'Review task should start open.');
    }

    @isTest
    static void testMaterializeApprovedWorkScopeCreatesWoli() {
        Account division = [SELECT Id FROM Account WHERE Name = 'Backbone Division' LIMIT 1];
        Purchase_Order__c po = [SELECT Id, Division_Account__c FROM Purchase_Order__c WHERE PO_Number__c = 'BB-PO-001' LIMIT 1];
        Id productionInstallRtId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId();

        LovingPoBackboneService.BackboneResult result = LovingPoBackboneService.ensureBackbone(po.Id);

        WorkOrder workOrder = new WorkOrder(
            RecordTypeId = productionInstallRtId,
            Subject = 'Backbone Test WorkOrder',
            Status = 'New',
            AccountId = division.Id,
            Work_Order_Type__c = 'Production Install'
        );
        insert workOrder;

        update new Purchase_Order__c(
            Id = po.Id,
            Work_Order__c = workOrder.Id
        );

        update new Takeoff__c(
            Id = result.takeoffId,
            Status__c = 'Approved'
        );
        update new Takeoff_Line__c(
            Id = [SELECT Id FROM Takeoff_Line__c WHERE Takeoff__c = :result.takeoffId LIMIT 1].Id,
            Review_Status__c = 'Approved'
        );

        Test.startTest();
        Integer createdCount = LovingPoBackboneService.materializeApprovedWorkScope(result.takeoffId);
        Test.stopTest();

        System.assertEquals(1, createdCount, 'Approved takeoff should generate one Work Order Line Item.');

        WorkOrderLineItem created = [
            SELECT Id, WorkOrderId, Source_Takeoff_Line__c, OrderId, Quantity, Status
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :workOrder.Id
            LIMIT 1
        ];
        System.assertEquals(workOrder.Id, created.WorkOrderId, 'WOLI should link to the standard WorkOrder.');
        System.assertNotEquals(null, created.Source_Takeoff_Line__c, 'WOLI should trace back to the approved Takeoff Line.');
        System.assertNotEquals(null, created.OrderId, 'WOLI should trace back to the source standard Order.');
        System.assertEquals('New', created.Status, 'Generated WOLI should start in New status.');
    }

    @isTest
    static void testEnsureBackboneIsIdempotent() {
        Purchase_Order__c po = [SELECT Id FROM Purchase_Order__c WHERE PO_Number__c = 'BB-PO-001' LIMIT 1];

        LovingPoBackboneService.BackboneResult firstRun = LovingPoBackboneService.ensureBackbone(po.Id);
        LovingPoBackboneService.BackboneResult secondRun = LovingPoBackboneService.ensureBackbone(po.Id);

        System.assertEquals(firstRun.orderId, secondRun.orderId, 'Backbone should reuse the same standard Order.');
        System.assertEquals(firstRun.takeoffId, secondRun.takeoffId, 'Backbone should reuse the same Takeoff.');
        System.assertEquals(1, [SELECT COUNT() FROM Order WHERE OrderReferenceNumber = 'BB-PO-001'], 'Only one standard Order should exist.');
        System.assertEquals(1, [SELECT COUNT() FROM Takeoff__c WHERE Purchase_Order__c = :po.Id], 'Only one Takeoff should exist.');
        System.assertEquals(1, [SELECT COUNT() FROM Takeoff_Line__c WHERE Takeoff__c = :firstRun.takeoffId], 'Only one Takeoff Line should exist.');
    }

    @isTest
    static void testMaterializeApprovedWorkScopeRejectsDraftTakeoff() {
        Purchase_Order__c po = [SELECT Id FROM Purchase_Order__c WHERE PO_Number__c = 'BB-PO-001' LIMIT 1];
        LovingPoBackboneService.BackboneResult result = LovingPoBackboneService.ensureBackbone(po.Id);

        try {
            LovingPoBackboneService.materializeApprovedWorkScope(result.takeoffId);
            System.assert(false, 'Draft takeoff should be rejected.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Draft takeoff should fail with an explicit gate message.');
        }
    }

    @isTest
    static void testEnsureBackboneWarnsWhenNoLineSourceExists() {
        Account builder = new Account(Name = 'No Line Builder');
        insert builder;
        Account division = new Account(Name = 'No Line Division');
        insert division;

        Purchase_Order__c po = new Purchase_Order__c(
            Builder_Account__c = builder.Id,
            Division_Account__c = division.Id,
            PO_Number__c = 'BB-PO-EMPTY',
            Status__c = 'Pending Takeoff',
            Package_BMG_Status__c = 'Matched'
        );
        insert po;

        insert new Builder_PO__c(
            PO_Number__c = 'BB-PO-EMPTY',
            Status__c = 'Pending Takeoff',
            Builder_Account__c = builder.Id,
            Division_Account__c = division.Id
        );

        LovingPoBackboneService.BackboneResult result = LovingPoBackboneService.ensureBackbone(po.Id);
        System.assertEquals(0, result.orderItemCount, 'No standard OrderItem should be created when there is no source line data.');
        System.assertEquals(0, result.takeoffLineCount, 'No Takeoff Line should be created when there is no source line data.');
        System.assert(result.warnings[0].contains('No PO line records'), 'Warning should explain why the line pipeline was skipped.');
    }

    @isTest
    static void testMaterializeApprovedWorkScopeCreatesGenericFallbackWhenNoSourceLinesExist() {
        Account division = [SELECT Id FROM Account WHERE Name = 'Backbone Division' LIMIT 1];
        Purchase_Order__c po = new Purchase_Order__c(
            Builder_Account__c = [SELECT Id FROM Account WHERE Name = 'Backbone Builder' LIMIT 1].Id,
            Division_Account__c = division.Id,
            PO_Number__c = 'BB-PO-FALLBACK',
            Quantity__c = 15,
            Total_Amount__c = 300,
            Status__c = 'Pending Takeoff',
            Package_BMG_Status__c = 'Matched'
        );
        insert po;

        Builder_PO__c builderPo = new Builder_PO__c(
            PO_Number__c = 'BB-PO-FALLBACK',
            Status__c = 'Pending Takeoff',
            Builder_Account__c = po.Builder_Account__c,
            Division_Account__c = po.Division_Account__c
        );
        insert builderPo;

        Id productionInstallRtId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId();
        LovingPoBackboneService.BackboneResult backbone = LovingPoBackboneService.ensureBackbone(po.Id);

        WorkOrder workOrder = new WorkOrder(
            RecordTypeId = productionInstallRtId,
            Subject = 'Fallback Scope WorkOrder',
            Status = 'New',
            AccountId = division.Id,
            Work_Order_Type__c = 'Production Install'
        );
        insert workOrder;

        update new Purchase_Order__c(Id = po.Id, Work_Order__c = workOrder.Id);
        update new Takeoff__c(Id = backbone.takeoffId, Status__c = 'Approved');

        Test.startTest();
        Integer createdCount = LovingPoBackboneService.materializeApprovedWorkScope(backbone.takeoffId);
        Test.stopTest();

        System.assertEquals(1, createdCount, 'A generic fallback scope line should be created when the PO lacks product-backed source lines.');
        WorkOrderLineItem created = [
            SELECT Description, Quantity, Status
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :workOrder.Id
            LIMIT 1
        ];
        System.assert(created.Description.contains('BB-PO-FALLBACK'));
        System.assertEquals(15, Integer.valueOf(created.Quantity));
        System.assertEquals('New', created.Status);
    }

    @isTest
    static void testInvocableGenerationWrapperReturnsSuccess() {
        Account division = [SELECT Id FROM Account WHERE Name = 'Backbone Division' LIMIT 1];
        Purchase_Order__c po = [SELECT Id FROM Purchase_Order__c WHERE PO_Number__c = 'BB-PO-001' LIMIT 1];
        Id productionInstallRtId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId();
        LovingPoBackboneService.BackboneResult result = LovingPoBackboneService.ensureBackbone(po.Id);

        WorkOrder workOrder = new WorkOrder(
            RecordTypeId = productionInstallRtId,
            Subject = 'Invocable Wrapper WorkOrder',
            Status = 'New',
            AccountId = division.Id,
            Work_Order_Type__c = 'Production Install'
        );
        insert workOrder;

        update new Purchase_Order__c(Id = po.Id, Work_Order__c = workOrder.Id);
        update new Takeoff__c(Id = result.takeoffId, Status__c = 'Approved');
        update new Takeoff_Line__c(
            Id = [SELECT Id FROM Takeoff_Line__c WHERE Takeoff__c = :result.takeoffId LIMIT 1].Id,
            Review_Status__c = 'Approved'
        );

        LovingPoBackboneService.TakeoffApprovalRequest request = new LovingPoBackboneService.TakeoffApprovalRequest();
        request.takeoffId = result.takeoffId;

        List<LovingPoBackboneService.TakeoffApprovalResult> responses =
            LovingPoBackboneService.generateWorkOrderLineItemsFromApprovedTakeoff(
                new List<LovingPoBackboneService.TakeoffApprovalRequest>{ request }
            );

        System.assertEquals(1, responses.size(), 'Invocable wrapper should return one result.');
        System.assertEquals('OK', responses[0].message, 'Invocable wrapper should surface success.');
        System.assertEquals(1, responses[0].createdWorkOrderLineItemCount, 'Invocable wrapper should report created scope rows.');
    }

    @isTest
    static void testEnsureBackboneFromBuilderPoUsesBuilderBridge() {
        Builder_PO__c builderPo = [SELECT Id, PO_Number__c FROM Builder_PO__c WHERE PO_Number__c = 'BB-PO-001' LIMIT 1];

        Test.startTest();
        LovingPoBackboneService.BackboneResult result = LovingPoBackboneService.ensureBackboneFromBuilderPo(builderPo.Id);
        Test.stopTest();

        System.assertEquals(builderPo.Id, result.builderPoId, 'Builder PO bridge should drive the backbone entry point.');
        System.assertNotEquals(null, result.orderId, 'Builder bridge should still create an Order.');
        System.assertNotEquals(null, result.takeoffId, 'Builder bridge should still create a Takeoff.');
    }

    @isTest
    static void testPilotApprovalHelpers() {
        Purchase_Order__c po = [SELECT Id FROM Purchase_Order__c WHERE PO_Number__c = 'BB-PO-001' LIMIT 1];
        LovingPoBackboneService.BackboneResult result = LovingPoBackboneService.ensureBackbone(po.Id);

        LovingPoBackboneService.approveTakeoffForPilot(result.takeoffId, 'Pilot approval');
        Id approvedLineId = LovingPoBackboneService.approveFirstTakeoffLineForPilot(result.takeoffId, 'Pilot line approval');

        Takeoff__c updatedTakeoff = [SELECT Status__c, Notes__c FROM Takeoff__c WHERE Id = :result.takeoffId LIMIT 1];
        Takeoff_Line__c updatedLine = [SELECT Review_Status__c, Notes__c FROM Takeoff_Line__c WHERE Id = :approvedLineId LIMIT 1];

        System.assertEquals('Approved', updatedTakeoff.Status__c, 'Pilot helper should approve the takeoff.');
        System.assertEquals('Pilot approval', updatedTakeoff.Notes__c, 'Pilot helper should persist approval notes.');
        System.assertEquals('Approved', updatedLine.Review_Status__c, 'Pilot helper should approve the first takeoff line.');
        System.assertEquals('Pilot line approval', updatedLine.Notes__c, 'Pilot helper should persist line approval notes.');
    }
}