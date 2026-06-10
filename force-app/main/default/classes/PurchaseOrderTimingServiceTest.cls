@IsTest
private class PurchaseOrderTimingServiceTest {
    @IsTest
    static void mapsReceivedAndReviewStages() {
        Purchase_Order__c received = poWithDateOffset(120);
        received.Status__c = 'Pending Takeoff';
        System.assertEquals('PO Received', PurchaseOrderTimingService.calculatePipelineStage(received));

        Purchase_Order__c review = poWithDateOffset(75);
        review.Status__c = 'Pending CS Review';
        System.assertEquals('CSM Review', PurchaseOrderTimingService.calculatePipelineStage(review));
    }

    @IsTest
    static void usesRequestedInstallDateWhenEstimatedStartDateIsBlank() {
        Purchase_Order__c po = new Purchase_Order__c(
            Requested_Install_Date__c = Date.today().addDays(75),
            Status__c = 'Pending Takeoff'
        );

        System.assertEquals('PO Received', PurchaseOrderTimingService.calculatePipelineStage(po));
        System.assertEquals(75, PurchaseOrderTimingService.getDaysUntilInstall(po));
    }

    @IsTest
    static void advancesMatchedPackageToTakeoffRequested() {
        Purchase_Order__c po = poWithDateOffset(45);
        po.Status__c = 'Package Match Check';
        po.Package_BMG_Status__c = 'Matched';
        System.assertEquals('Takeoff Requested', PurchaseOrderTimingService.calculatePipelineStage(po));
    }

    @IsTest
    static void mapsTakeoffAndWorkOrderMilestones() {
        Purchase_Order__c takeoffPo = poWithDateOffset(15);
        takeoffPo.Status__c = 'Takeoff In Progress';
        System.assertEquals('Takeoff In Progress', PurchaseOrderTimingService.calculatePipelineStage(takeoffPo));

        Purchase_Order__c approvedPo = poWithDateOffset(15);
        approvedPo.Takeoff_Status__c = 'Approved';
        System.assertEquals('Takeoff Complete', PurchaseOrderTimingService.calculatePipelineStage(approvedPo));

        Purchase_Order__c workOrderPo = poWithDateOffset(10);
        workOrderPo.Status__c = 'Work Order Created';
        workOrderPo.Work_Order__c = '0WO000000000001AAA';
        System.assertEquals('WorkOrder Created', PurchaseOrderTimingService.calculatePipelineStage(workOrderPo));
    }

    @IsTest
    static void mapsLegacyBoardBucketsForDisplayOnly() {
        System.assertEquals('csmReview', PurchaseOrderTimingService.mapStageToBoardColumn('Validate', 'Pending CS Review'));
        System.assertEquals('takeoffRequested', PurchaseOrderTimingService.mapStageToBoardColumn('Forecast', null));
        System.assertEquals('workOrderCreated', PurchaseOrderTimingService.mapStageToBoardColumn('Scheduling', null));
        System.assertEquals('clear', PurchaseOrderTimingService.mapStageToBoardColumn('Clear', null));
    }

    @IsTest
    static void recalculatesAndSchedulerUpdatesPurchaseOrdersOnly() {
        Account division = new Account(Name = 'Phase 1 Test Division');
        insert division;

        Purchase_Order__c po = new Purchase_Order__c(
            Name = 'PO-PHASE1-SCHED',
            Division_Account__c = division.Id,
            Status__c = 'Package Match Check',
            Package_BMG_Status__c = 'Matched',
            Estimated_Start_Date__c = Date.today().addDays(120)
        );
        insert po;

        Test.startTest();
        PurchaseOrderPipelineBucketScheduler.runBatch();
        Test.stopTest();

        Purchase_Order__c updated = [
            SELECT Pipeline_Stage__c,
                   Timing_Status__c,
                   Pipeline_Bucket_Last_Calculated__c
            FROM Purchase_Order__c
            WHERE Id = :po.Id
        ];

        System.assertEquals('Takeoff Requested', updated.Pipeline_Stage__c);
        System.assertEquals('In Expected Window', updated.Timing_Status__c);
        System.assertNotEquals(null, updated.Pipeline_Bucket_Last_Calculated__c);
    }

    private static Purchase_Order__c poWithDateOffset(Integer daysFromToday) {
        return new Purchase_Order__c(
            Estimated_Start_Date__c = Date.today().addDays(daysFromToday),
            Status__c = 'Pending Takeoff'
        );
    }
}