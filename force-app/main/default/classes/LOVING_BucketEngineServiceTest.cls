@IsTest
private class LOVING_BucketEngineServiceTest {

    @TestSetup
    static void setup() {
        try {
            Extentia_SIM__MapPlotterTriggerSettings__c bypass =
                Extentia_SIM__MapPlotterTriggerSettings__c.getOrgDefaults();
            bypass.Extentia_SIM__Bypass_Trigger__c = true;
            upsert bypass;
        } catch (Exception e) {}
    }

    @IsTest
    static void testEmptyOrg() {
        // No qualifying WOs — exercises empty-path return
        Test.startTest();
        LOVING_BucketEngineService.runBucketEngine();
        Test.stopTest();
    }

    @IsTest
    static void testBucketCalculation() {
        System.assertEquals('90+ Days', LOVING_BucketEngineService.calculateBucket(100, false), '100d bucket');
        System.assertEquals('60+ Days', LOVING_BucketEngineService.calculateBucket(45, false), '45d bucket');
        System.assertEquals('30 Days', LOVING_BucketEngineService.calculateBucket(20, false), '20d bucket');
        System.assertEquals('Ready to Schedule', LOVING_BucketEngineService.calculateBucket(-5, false), 'Past due bucket');
        System.assertEquals('Takeoff Complete', LOVING_BucketEngineService.calculateBucket(10, true), 'Takeoff complete bucket');
    }

    @IsTest
    static void testBucketEngineWithMockWorkOrders() {
        LOVING_BucketEngineService.mockWorkOrders = new List<WorkOrder>{
            new WorkOrder(
                Id = '0WO000000000001AAA',
                Requested_Install_Date__c = Date.today().addDays(20),
                Field_Manager__c = UserInfo.getUserId(),
                Takeoff_Complete__c = false
            ),
            new WorkOrder(
                Id = '0WO000000000002AAA',
                Requested_Install_Date__c = Date.today().addDays(10),
                Field_Manager__c = UserInfo.getUserId(),
                Takeoff_Complete__c = true
            ),
            new WorkOrder(
                Id = '0WO000000000003AAA',
                Requested_Install_Date__c = Date.today().addDays(18),
                Field_Manager__c = UserInfo.getUserId(),
                Takeoff_Complete__c = false,
                Pipeline_Bucket__c = 'On Hold'
            )
        };
        LOVING_BucketEngineService.mockWorkOrdersWithTakeoffTasks = new Set<Id>{ '0WO000000000002AAA' };

        Test.startTest();
        LOVING_BucketEngineService.runBucketEngine();
        Test.stopTest();

        System.assertEquals(2, LOVING_BucketEngineService.lastUpdatedWorkOrders.size(), 'On-hold work order skipped');
        System.assertEquals('30 Days', LOVING_BucketEngineService.lastUpdatedWorkOrders[0].Pipeline_Bucket__c, 'Open work order bucketed');
        System.assertEquals('Takeoff Complete', LOVING_BucketEngineService.lastUpdatedWorkOrders[1].Pipeline_Bucket__c, 'Completed takeoff bucketed');
        System.assertEquals(1, LOVING_BucketEngineService.lastCreatedTasks.size(), 'Only open 30-day work order receives task');
    }

    @IsTest
    static void testBuildTakeoffTask() {
        WorkOrder wo = new WorkOrder(
            Requested_Install_Date__c = Date.today().addDays(20),
            Field_Manager__c          = UserInfo.getUserId()
        );

        WorkOrder woNoDate = new WorkOrder(
            Field_Manager__c = UserInfo.getUserId()
        );

        Test.startTest();
        Task tNormal   = LOVING_BucketEngineService.buildTakeoffTask(wo, false);
        Task tHigh     = LOVING_BucketEngineService.buildTakeoffTask(wo, true);
        Task tTbd      = LOVING_BucketEngineService.buildTakeoffTask(woNoDate, true);
        Test.stopTest();

        System.assertEquals('Normal',   tNormal.Priority,        'Normal priority task');
        System.assertEquals('High',     tHigh.Priority,          'High priority task');
        System.assertEquals('Takeoff',  tNormal.Type,            'Task type Takeoff');
        System.assertEquals(UserInfo.getUserId(), tNormal.OwnerId, 'Task owned by FM');
        System.assert(tNormal.Subject.startsWith('Site Takeoff Required'), 'Subject prefix');
        System.assert(tNormal.Description.contains('PHYSICAL SITE VISIT'), 'Description present');
        System.assert(tTbd.Description.endsWith('TBD'), 'No-date WO shows TBD');
    }
}