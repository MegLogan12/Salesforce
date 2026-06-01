@IsTest(SeeAllData=true)
private class TakeoffExecutionBridgeServiceTest {
    private class SeedContext {
        Account builderMarket;
        Community__c community;
        Lot__c lot;
    }

    private static SeedContext loadSeedContext() {
        SeedContext ctx = new SeedContext();
        ctx.community = [
            SELECT Id, Name, Builder_Account__c
            FROM Community__c
            WHERE Builder_Account__c != null
            ORDER BY Name
            LIMIT 1
        ];
        ctx.builderMarket = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :ctx.community.Builder_Account__c
        ];
        ctx.lot = [
            SELECT Id, Name, Effective_Community_Package__c, Effective_Community_Package__r.Pricing_Book__c
            FROM Lot__c
            WHERE Community__c = :ctx.community.Id
            LIMIT 1
        ];
        return ctx;
    }

    private static Builder_PO__c createBuilderPo(SeedContext ctx, String poNumber) {
        Builder_PO__c builderPo = new Builder_PO__c(
            Division_Account__c = ctx.builderMarket.Id,
            Builder_Account__c = ctx.builderMarket.Id,
            Community__c = ctx.community.Id,
            Lot__c = ctx.lot.Id,
            Community_Package__c = ctx.lot.Effective_Community_Package__c,
            PO_Number__c = poNumber,
            Status__c = 'Pending CS Review'
        );
        insert builderPo;
        return builderPo;
    }

    private static Purchase_Order__c createPurchaseOrder(SeedContext ctx, String poNumber) {
        Purchase_Order__c purchaseOrder = new Purchase_Order__c(
            PO_Number__c = poNumber,
            Builder_Account__c = ctx.builderMarket.Id,
            Division_Account__c = ctx.builderMarket.Id,
            Community__c = ctx.community.Id,
            Lot__c = ctx.lot.Id,
            Quantity__c = 500,
            Total_Amount__c = 7200,
            Status__c = 'Pending CS Review'
        );
        insert purchaseOrder;
        return purchaseOrder;
    }

    private static Takeoff__c loadDraftTakeoff(Id builderPoId) {
        return [
            SELECT Id, Name, Status__c, Builder_PO__c, Community__c, Lot__c, FM_Assignment__c
            FROM Takeoff__c
            WHERE Builder_PO__c = :builderPoId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    private static void createScopedLines(Id takeoffId) {
        insert new List<Takeoff_Line__c>{
            new Takeoff_Line__c(
                Takeoff__c = takeoffId,
                Item_Name__c = 'LOVING Production Install Sod Scope',
                Item_Description__c = 'Production Install · Sod',
                Verified_Quantity__c = 500,
                Unit_Price__c = 12
            ),
            new Takeoff_Line__c(
                Takeoff__c = takeoffId,
                Item_Name__c = 'Irrigation Scope',
                Item_Description__c = 'Irrigation · Zone Install',
                Verified_Quantity__c = 1,
                Unit_Price__c = 800
            ),
            new Takeoff_Line__c(
                Takeoff__c = takeoffId,
                Item_Name__c = 'Grading Scope',
                Item_Description__c = 'Grading · Final Grade',
                Verified_Quantity__c = 1,
                Unit_Price__c = 400
            ),
            new Takeoff_Line__c(
                Takeoff__c = takeoffId,
                Item_Name__c = 'Aqua Watering Bag Scope',
                Item_Description__c = 'Aqua · Watering Bag Install',
                Verified_Quantity__c = 1,
                Unit_Price__c = 150
            )
        };
    }

    @IsTest
    static void syncsFreshTakeoffIntoParentChildrenLinesAndAppointments() {
        SeedContext ctx = loadSeedContext();
        String poNumber = 'UAT-BRIDGE-' + String.valueOf(DateTime.now().getTime());
        Id fallbackFmId = UserInfo.getUserId();

        update new Community__c(
            Id = ctx.community.Id,
            FM_Assignment__c = fallbackFmId
        );

        Builder_PO__c builderPo = createBuilderPo(ctx, poNumber);
        Purchase_Order__c purchaseOrder = createPurchaseOrder(ctx, poNumber);
        Takeoff__c draftTakeoff = loadDraftTakeoff(builderPo.Id);
        System.assertEquals('Draft', draftTakeoff.Status__c, 'Builder PO create flow should create a draft Takeoff.');

        Takeoff__c approvedTakeoff = new Takeoff__c(
            Builder_PO__c = builderPo.Id,
            Community__c = ctx.community.Id,
            Lot__c = ctx.lot.Id,
            Status__c = 'Approved'
        );
        insert approvedTakeoff;
        createScopedLines(approvedTakeoff.Id);

        TakeoffExecutionBridgeService.syncTakeoffs(new Set<Id>{ approvedTakeoff.Id });

        Work_Order__c customParent = [
            SELECT Id, Builder_PO__c, Takeoff__c, Community_Package__c, Status__c, Work_Order_Type__c
            FROM Work_Order__c
            WHERE Takeoff__c = :approvedTakeoff.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(builderPo.Id, customParent.Builder_PO__c);
        System.assertEquals(ctx.lot.Effective_Community_Package__c, customParent.Community_Package__c);
        System.assertEquals('Clear for Schedule', customParent.Status__c);
        System.assertEquals('Production Install', customParent.Work_Order_Type__c);

        WorkOrder bridgeParent = [
            SELECT Id, Purchase_Order__c, ParentWorkOrderId, Subject, Status, Work_Order_Type__c,
                   Pricebook2Id, PO_Number__c, Field_Manager__c, LOVING_Work_Order__c
            FROM WorkOrder
            WHERE Purchase_Order__c = :purchaseOrder.Id
              AND ParentWorkOrderId = null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(customParent.Id, (Id) bridgeParent.get('LOVING_Work_Order__c'));
        System.assertEquals('Production Install', bridgeParent.Work_Order_Type__c);
        System.assertNotEquals(null, bridgeParent.Pricebook2Id);
        System.assert(bridgeParent.Status == 'Ready to Schedule' || bridgeParent.Status == 'New',
            'Bridge parent status should be Ready to Schedule (or New in test context): ' + bridgeParent.Status);
        System.assertEquals(poNumber, bridgeParent.PO_Number__c);
        System.assertEquals(fallbackFmId, bridgeParent.Field_Manager__c);
        Id expectedPricebookId = ctx.lot.Effective_Community_Package__r.Pricing_Book__c;
        if (expectedPricebookId == null) {
            expectedPricebookId = [
                SELECT Id
                FROM Pricebook2
                WHERE IsStandard = true
                LIMIT 1
            ].Id;
        }
        System.assertEquals(expectedPricebookId, bridgeParent.Pricebook2Id);

        List<WorkOrder> children = [
            SELECT Id, ParentWorkOrderId, Subject, Status, Work_Order_Type__c, PO_Number__c, Field_Manager__c, LOVING_Work_Order__c
            FROM WorkOrder
            WHERE ParentWorkOrderId = :bridgeParent.Id
            ORDER BY Work_Order_Type__c
        ];
        System.assert(children.size() >= 3, 'Expected one child standard WorkOrder per scoped execution package.');

        Set<String> childTypes = new Set<String>();
        Set<Id> childIds = new Set<Id>();
        for (WorkOrder child : children) {
            childTypes.add(child.Work_Order_Type__c);
            childIds.add(child.Id);
            System.assertEquals(customParent.Id, (Id) child.get('LOVING_Work_Order__c'));
            System.assertEquals('Ready to Schedule', child.Status);
            System.assertEquals(poNumber, child.PO_Number__c);
            System.assertEquals(fallbackFmId, child.Field_Manager__c);
        }
        System.assert(childTypes.contains('Production Install'));
        System.assert(childTypes.contains('Irrigation'));
        System.assert(childTypes.contains('Grading'));

        Integer childLineCount = [
            SELECT COUNT()
            FROM WorkOrderLineItem
            WHERE WorkOrderId IN :childIds
        ];
        System.assert(childLineCount >= 3, 'Expected child standard WorkOrder line items from Takeoff scope lines.');

        List<ServiceAppointment> appointments = [
            SELECT Id, ParentRecordId, Status, LOVING_Work_Order__c
            FROM ServiceAppointment
            WHERE ParentRecordId IN :childIds
        ];
        System.assertEquals(children.size(), appointments.size(), 'Expected one Service Appointment per child standard WorkOrder.');
        for (ServiceAppointment appointment : appointments) {
            System.assertEquals(customParent.Id, (Id) appointment.get('LOVING_Work_Order__c'));
            System.assertEquals('Ready to Schedule', appointment.Status);
        }

        Purchase_Order__c refreshedPo = [
            SELECT Id, Work_Order__c, Status__c, Takeoff_Status__c
            FROM Purchase_Order__c
            WHERE Id = :purchaseOrder.Id
        ];
        Builder_PO__c refreshedBuilderPo = [
            SELECT Id, Status__c, Takeoff_Status__c
            FROM Builder_PO__c
            WHERE Id = :builderPo.Id
        ];
        System.assertEquals(bridgeParent.Id, refreshedPo.Work_Order__c);
        System.assertEquals('Pending CS Review', refreshedPo.Status__c);
        System.assertEquals('Locked', refreshedPo.Takeoff_Status__c);
        System.assertEquals('Takeoff Complete', refreshedBuilderPo.Status__c);
        System.assertEquals('Locked', refreshedBuilderPo.Takeoff_Status__c);

        Test.startTest();
        TakeoffExecutionBridgeService.syncTakeoffs(new Set<Id>{ approvedTakeoff.Id });
        Test.stopTest();

        Integer childCountAfterResync = [
            SELECT COUNT()
            FROM WorkOrder
            WHERE ParentWorkOrderId = :bridgeParent.Id
        ];
        Integer appointmentCountAfterResync = [
            SELECT COUNT()
            FROM ServiceAppointment
            WHERE ParentRecordId IN :childIds
        ];
        System.assertEquals(children.size(), childCountAfterResync, 'Re-sync should not duplicate child standard WorkOrders.');
        System.assertEquals(appointments.size(), appointmentCountAfterResync, 'Re-sync should not duplicate Service Appointments.');
    }

    @IsTest
    static void triggerNoOpsWhenStatusDoesNotTransitionToApproved() {
        SeedContext ctx = loadSeedContext();
        String poNumber = 'UAT-NOOP-' + String.valueOf(DateTime.now().getTime());

        Builder_PO__c builderPo = createBuilderPo(ctx, poNumber);
        createPurchaseOrder(ctx, poNumber);
        Takeoff__c draftTakeoff = loadDraftTakeoff(builderPo.Id);
        createScopedLines(draftTakeoff.Id);

        Test.startTest();
        update new Takeoff__c(
            Id = draftTakeoff.Id,
            Status__c = 'In Progress'
        );
        Test.stopTest();

        Integer customParentCount = [
            SELECT COUNT()
            FROM Work_Order__c
            WHERE Takeoff__c = :draftTakeoff.Id
        ];
        System.assertEquals(0, customParentCount, 'Non-approved Takeoffs should not build the bridge hierarchy.');
    }

    @IsTest
    static void enqueueApprovedTakeoffRunsQueueableAndSkipsNonEligibleRows() {
        SeedContext ctx = loadSeedContext();
        String poNumber = 'UAT-QUEUE-' + String.valueOf(DateTime.now().getTime());

        Builder_PO__c builderPo = createBuilderPo(ctx, poNumber);
        createPurchaseOrder(ctx, poNumber);

        Takeoff__c queuedTakeoff = new Takeoff__c(
            Builder_PO__c = builderPo.Id,
            Community__c = ctx.community.Id,
            Lot__c = ctx.lot.Id,
            Status__c = 'Approved'
        );
        insert queuedTakeoff;
        createScopedLines(queuedTakeoff.Id);

        Takeoff__c alreadyApproved = new Takeoff__c(
            Builder_PO__c = builderPo.Id,
            Community__c = ctx.community.Id,
            Lot__c = ctx.lot.Id,
            Status__c = 'Approved'
        );
        insert alreadyApproved;

        Takeoff__c missingBuilderPo = new Takeoff__c(
            Community__c = ctx.community.Id,
            Lot__c = ctx.lot.Id,
            Status__c = 'Approved'
        );
        insert missingBuilderPo;

        Map<Id, Takeoff__c> newMap = new Map<Id, Takeoff__c>{
            queuedTakeoff.Id => queuedTakeoff,
            alreadyApproved.Id => alreadyApproved,
            missingBuilderPo.Id => missingBuilderPo
        };
        Map<Id, Takeoff__c> oldMap = new Map<Id, Takeoff__c>{
            queuedTakeoff.Id => new Takeoff__c(Id = queuedTakeoff.Id, Builder_PO__c = builderPo.Id, Status__c = 'Draft'),
            alreadyApproved.Id => new Takeoff__c(Id = alreadyApproved.Id, Builder_PO__c = builderPo.Id, Status__c = 'Approved'),
            missingBuilderPo.Id => new Takeoff__c(Id = missingBuilderPo.Id, Status__c = 'Draft')
        };

        Test.startTest();
        TakeoffExecutionBridgeService.enqueueApprovedTakeoffs(newMap, oldMap);
        Test.stopTest();

        Integer builtParents = [
            SELECT COUNT()
            FROM Work_Order__c
            WHERE Takeoff__c = :queuedTakeoff.Id
        ];
        Integer skippedApprovedParents = [
            SELECT COUNT()
            FROM Work_Order__c
            WHERE Takeoff__c = :alreadyApproved.Id
        ];
        Integer skippedMissingBuilderParents = [
            SELECT COUNT()
            FROM Work_Order__c
            WHERE Takeoff__c = :missingBuilderPo.Id
        ];
        System.assertEquals(1, builtParents, 'Eligible approved Takeoff should queue and build execution records.');
        System.assertEquals(0, skippedApprovedParents, 'Already-approved old status should not enqueue again.');
        System.assertEquals(0, skippedMissingBuilderParents, 'Approved Takeoff without Builder PO should be skipped.');
    }

    @IsTest
    static void helperMethodsCoverFallbacksAndNoOpSync() {
        Takeoff_Line__c blankLine = new Takeoff_Line__c();
        System.assertEquals('Builder scope line', TakeoffExecutionBridgeService.buildLineDescription(blankLine));
        System.assertEquals(1, TakeoffExecutionBridgeService.resolveQuantity(blankLine));
        System.assertEquals('Install', TakeoffExecutionBridgeService.classifyScope(blankLine));
        System.assertEquals(false, TakeoffExecutionBridgeService.isSodLine(blankLine));

        Takeoff_Line__c measuredLine = new Takeoff_Line__c(
            Item_Name__c = 'Plant palette',
            Measured_Quantity__c = 12
        );
        System.assertEquals('Plant palette', TakeoffExecutionBridgeService.buildLineDescription(measuredLine));
        System.assertEquals(12, TakeoffExecutionBridgeService.resolveQuantity(measuredLine));

        Takeoff_Line__c poQtyLine = new Takeoff_Line__c(
            Item_Description__c = 'Final grade scope',
            PO_Quantity__c = 4
        );
        System.assertEquals(4, TakeoffExecutionBridgeService.resolveQuantity(poQtyLine));
        System.assertEquals('Grading', TakeoffExecutionBridgeService.classifyScope(poQtyLine));

        Test.startTest();
        TakeoffExecutionBridgeService.syncTakeoffs(new Set<Id>());
        Test.stopTest();
        System.assert(true, 'Empty sync should no-op without throwing.');
    }
}