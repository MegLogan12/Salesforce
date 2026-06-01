@IsTest(SeeAllData=true)
private class LovingWOWorkspaceControllerTest {
    @IsTest
    static void returnsWorkspaceForExistingWorkOrder() {
        List<WorkOrder> workOrders = [SELECT Id FROM WorkOrder LIMIT 1];
        System.assert(!workOrders.isEmpty(), 'Expected at least one WorkOrder in the org for workspace smoke coverage.');
        LovingWOWorkspaceController.WorkspaceDto dto =
            LovingWOWorkspaceController.getWorkspace(workOrders[0].Id);
        System.assertNotEquals(null, dto);
        System.assertNotEquals(null, dto.header);
        System.assertNotEquals(null, dto.kpis);
        System.assertNotEquals(null, dto.rollupRows);
        System.assertNotEquals(null, dto.childWorkOrders);
    }

    @IsTest
    static void createExecutionChildrenReturnsResult() {
        List<WorkOrder> productionInstall = [
            SELECT Id
            FROM WorkOrder
            WHERE Work_Order_Type__c = 'Production Install'
            LIMIT 1
        ];
        System.assert(!productionInstall.isEmpty(), 'Expected at least one Production Install WorkOrder in the org.');
        Test.startTest();
        LovingWOWorkspaceController.CreateChildrenResult result =
            LovingWOWorkspaceController.createExecutionChildren(productionInstall[0].Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.message);
        System.assertNotEquals(null, result.childWorkOrderIds);
    }

    @IsTest
    static void createExecutionChildrenUsesTakeoffScopeClassification() {
        WorkOrder targetParent = null;
        LovingWOWorkspaceController.WorkspaceDto targetWorkspace = null;
        for (WorkOrder candidate : [
            SELECT Id
            FROM WorkOrder
            WHERE ParentWorkOrderId = null
              AND Work_Order_Type__c = 'Production Install'
              AND Id IN (SELECT WorkOrderId FROM WorkOrderLineItem)
            ORDER BY CreatedDate DESC
            LIMIT 25
        ]) {
            LovingWOWorkspaceController.WorkspaceDto dto = LovingWOWorkspaceController.getWorkspace(candidate.Id);
            if (!dto.takeoffLines.isEmpty() && dto.childWorkOrders.isEmpty()) {
                targetParent = candidate;
                targetWorkspace = dto;
                break;
            }
        }

        System.assertNotEquals(null, targetParent, 'Expected a parent Production Install WorkOrder with takeoff lines and no existing children.');
        System.assertNotEquals(null, targetWorkspace, 'Expected workspace data for the chosen parent.');

        String scopeMessage = LovingWOWorkspaceController.updateTakeoffLineScope(targetWorkspace.takeoffLines[0].takeoffLineId, 'Install');
        System.assertNotEquals(null, scopeMessage);
        if (targetWorkspace.takeoffLines.size() > 1) {
            System.assertNotEquals(null, LovingWOWorkspaceController.updateTakeoffLineScope(targetWorkspace.takeoffLines[1].takeoffLineId, 'Other / Review'));
        }

        Test.startTest();
        LovingWOWorkspaceController.CreateChildrenResult result =
            LovingWOWorkspaceController.createExecutionChildren(targetParent.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected classifier-driven child creation to succeed.');
        System.assertNotEquals(null, result.childWorkOrderIds, 'Expected the result to return the child id collection even when no source-linked lines can route.');
        System.assertNotEquals(-1, result.message.indexOf('Review lines not routed'), 'Expected review routing detail in the result message.');
    }

    @IsTest
    static void createExecutionChildrenSupportsIrrigationScopeWhenActive() {
        assertScopeCreatesChild('Irrigation', 'Irrigation');
    }

    @IsTest
    static void createExecutionChildrenSupportsGradingScopeWhenActive() {
        assertScopeCreatesChild('Grading', 'Grading');
    }

    @IsTest
    static void createExecutionChildrenSupportsAquaScopeWhenActive() {
        assertScopeCreatesChild('Aqua', 'Aqua Install');
    }

    @IsTest
    static void returnsWorkspaceForParentWithChildAppointments() {
        List<WorkOrder> childRows = [
            SELECT Id, ParentWorkOrderId
            FROM WorkOrder
            WHERE ParentWorkOrderId != null
            LIMIT 1
        ];
        System.assert(!childRows.isEmpty(), 'Expected at least one child standard WorkOrder in the org.');
        Test.startTest();
        LovingWOWorkspaceController.WorkspaceDto dto =
            LovingWOWorkspaceController.getWorkspace(childRows[0].ParentWorkOrderId);
        Test.stopTest();
        System.assertNotEquals(null, dto);
        System.assertNotEquals(null, dto.childWorkOrders);
        System.assert(!dto.childWorkOrders.isEmpty(), 'Expected child WorkOrder rows on the parent workspace.');
        System.assertNotEquals(null, dto.childAppointments);
    }

    @IsTest
    static void ensuresTakeoffChecklistAndUpdatesItem() {
        List<Takeoff__c> takeoffs = [
            SELECT Id, Purchase_Order__c
            FROM Takeoff__c
            WHERE Purchase_Order__c != null
            LIMIT 1
        ];
        System.assert(!takeoffs.isEmpty(), 'Expected at least one Takeoff linked to a Purchase Order in the org.');

        Purchase_Order__c po = [
            SELECT Id, Work_Order__c
            FROM Purchase_Order__c
            WHERE Id = :takeoffs[0].Purchase_Order__c
            LIMIT 1
        ];
        System.assertNotEquals(null, po.Work_Order__c, 'Expected the linked Purchase Order to point at a WorkOrder.');

        Test.startTest();
        String ensureMessage = LovingWOWorkspaceController.ensureTakeoffChecklist(po.Work_Order__c);
        LovingWOWorkspaceController.WorkspaceDto dto = LovingWOWorkspaceController.getWorkspace(po.Work_Order__c);
        if (!dto.checklistItems.isEmpty()) {
            for (LovingWOWorkspaceController.ChecklistItemDto item : dto.checklistItems) {
                String updateMessage = LovingWOWorkspaceController.updateChecklistItem(item.checklistItemId, 'Complete', 'Verified in test');
                System.assertNotEquals(null, updateMessage);
            }
        }
        if (!dto.takeoffLines.isEmpty()) {
            String scopeMessage = LovingWOWorkspaceController.updateTakeoffLineScope(dto.takeoffLines[0].takeoffLineId, 'Install');
            System.assertNotEquals(null, scopeMessage);
        }
        String reviewMessage = LovingWOWorkspaceController.updateTakeoffReview(
            dto.takeoffId,
            'Submitted',
            true,
            'Mismatch noted in test',
            true,
            'Test takeoff note',
            'Return path validated in test'
        );
        Test.stopTest();

        System.assertNotEquals(null, ensureMessage);
        System.assertNotEquals(null, reviewMessage);
        System.assertNotEquals(null, dto.takeoffRows);
        System.assertNotEquals(null, dto.checklistItems);

        LovingWOWorkspaceController.WorkspaceDto refreshed = LovingWOWorkspaceController.getWorkspace(po.Work_Order__c);
        System.assertNotEquals(null, refreshed.takeoffChecklist);
        System.assert(!refreshed.takeoffRows.isEmpty(), 'Expected takeoff rows after update.');
    }

    private static void assertScopeCreatesChild(String executionScope, String expectedWorkType) {
        Boolean workTypeActive = false;
        for (Schema.PicklistEntry entry : WorkOrder.Work_Order_Type__c.getDescribe().getPicklistValues()) {
            if (entry.getValue() == expectedWorkType && entry.isActive()) {
                workTypeActive = true;
                break;
            }
        }
        System.assertEquals(true, workTypeActive, 'Expected the standard WorkOrder type to be active for ' + executionScope + '.');

        WorkOrder targetParent = null;
        Id routableTakeoffLineId = null;
        for (WorkOrder candidate : [
            SELECT Id
            FROM WorkOrder
            WHERE ParentWorkOrderId = null
              AND Work_Order_Type__c = 'Production Install'
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            if ([SELECT COUNT()
                 FROM WorkOrder
                 WHERE ParentWorkOrderId = :candidate.Id
                   AND Work_Order_Type__c = :expectedWorkType] > 0) {
                continue;
            }

            Set<Id> sourceTakeoffLineIds = new Set<Id>();
            for (WorkOrderLineItem line : [
                SELECT Source_Takeoff_Line__c
                FROM WorkOrderLineItem
                WHERE WorkOrderId = :candidate.Id
                  AND Source_Takeoff_Line__c != null
                LIMIT 20
            ]) {
                sourceTakeoffLineIds.add((Id) line.get('Source_Takeoff_Line__c'));
            }
            if (sourceTakeoffLineIds.isEmpty()) {
                continue;
            }

            LovingWOWorkspaceController.WorkspaceDto dto = LovingWOWorkspaceController.getWorkspace(candidate.Id);
            if (!dto.childWorkOrders.isEmpty()) {
                continue;
            }
            for (LovingWOWorkspaceController.TakeoffLineDto takeoffLine : dto.takeoffLines) {
                if (sourceTakeoffLineIds.contains(takeoffLine.takeoffLineId)) {
                    routableTakeoffLineId = takeoffLine.takeoffLineId;
                    targetParent = candidate;
                    break;
                }
            }
            if (targetParent != null) {
                break;
            }
        }

        System.assertNotEquals(null, targetParent, 'Expected a routable parent WorkOrder for ' + executionScope + ' coverage.');
        System.assertNotEquals(null, routableTakeoffLineId, 'Expected a Takeoff line that is source-linked to a parent WorkOrderLineItem for ' + executionScope + '.');

        System.assertNotEquals(null, LovingWOWorkspaceController.updateTakeoffLineScope(routableTakeoffLineId, executionScope));

        Test.startTest();
        LovingWOWorkspaceController.CreateChildrenResult result =
            LovingWOWorkspaceController.createExecutionChildren(targetParent.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected ' + executionScope + '-scope child creation to succeed.');
        List<WorkOrder> children = [
            SELECT Id, Work_Order_Type__c, ParentWorkOrderId
            FROM WorkOrder
            WHERE ParentWorkOrderId = :targetParent.Id
              AND Work_Order_Type__c = :expectedWorkType
            LIMIT 1
        ];
        System.assert(!children.isEmpty(), 'Expected a ' + expectedWorkType + ' child WorkOrder after enabling real scope routing.');
    }
}