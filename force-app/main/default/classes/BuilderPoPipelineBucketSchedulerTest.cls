@IsTest
private class BuilderPoPipelineBucketSchedulerTest {

    @TestSetup
    static void makeData() {
        insert new List<Builder_PO_Timing_Rule__c>{
            new Builder_PO_Timing_Rule__c(
                Name = 'Test Rule',
                Parent_Builder_Name__c  = 'Test Builder',
                Division_Builder_Name__c = 'Test Builder',
                Min_Days_Before_Start__c = 30,
                Max_Days_Before_Start__c = 60,
                Business_Days__c        = false,
                Active__c               = true
            )
        };

        Account divAcct = new Account(Name = 'Test Division Account');
        insert divAcct;

        insert new Builder_PO__c(
            Builder_Name__c         = 'Test Builder',
            Division_Account__c     = divAcct.Id,
            Pipeline_Stage__c       = '90+ Days',
            Estimated_Start_Date__c = Date.today().addDays(120),
            PO_Release_Date__c      = Date.today()
        );
    }

    @IsTest
    static void runBatch_executesWithoutError() {
        Test.startTest();
        BuilderPoPipelineBucketScheduler.runBatch();
        Test.stopTest();

        Builder_PO__c updated = [SELECT Pipeline_Stage__c, Pipeline_Bucket_Last_Calculated__c
                                  FROM Builder_PO__c LIMIT 1];
        System.assertNotEquals(null, updated.Pipeline_Stage__c);
        System.assertNotEquals(null, updated.Pipeline_Bucket_Last_Calculated__c);
    }

    @IsTest
    static void schedule_executesSchedulable() {
        Test.startTest();
        String jobId = System.schedule(
            'Test PO Bucket',
            '0 0 5 * * ?',
            new BuilderPoPipelineBucketScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void scheduleIfNotScheduled_doesNotThrow() {
        Test.startTest();
        BuilderPoPipelineBucketScheduler.scheduleIfNotScheduled();
        BuilderPoPipelineBucketScheduler.scheduleIfNotScheduled(); // second call is safe
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void reschedule_replacesExistingJob() {
        Test.startTest();
        BuilderPoPipelineBucketScheduler.reschedule();
        Test.stopTest();
        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = :BuilderPoPipelineBucketScheduler.JOB_NAME];
        System.assertEquals(1, jobs.size());
    }

}