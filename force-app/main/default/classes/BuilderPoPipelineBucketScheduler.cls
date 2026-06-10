/**
 * BuilderPoPipelineBucketScheduler
 * Scheduled Apex: runs daily to recalculate Pipeline_Stage__c and timing status
 * on all active Builder_PO__c records, then syncs to related Work_Order__c.
 *
 * Schedule (in sandbox/prod Setup -> Scheduled Jobs):
 *   System.schedule('LOVING PO Bucket Engine', '0 0 5 * * ?', new BuilderPoPipelineBucketScheduler());
 * Runs at 5:00 AM daily. Can also be invoked manually via execute() below.
 */
public with sharing class BuilderPoPipelineBucketScheduler implements Schedulable {

    public static final String JOB_NAME = 'LOVING PO Bucket Engine';
    public static final String CRON_EXP = '0 0 5 * * ?';

    // ── Schedulable interface ────────────────────────────────────────────────

    public void execute(SchedulableContext sc) {
        runBatch();
    }

    // ── Manual / test invocation ─────────────────────────────────────────────

    /**
     * Run synchronously (small orgs or manual trigger from Anonymous Apex).
     * Processes up to 2,000 POs per invocation.
     */
    public static void runBatch() {
        List<Builder_PO__c> pos = [
            SELECT Id, Name,
                   Parent_Account__c, Division_Account__c,
                   Builder_Name__c, Division_Code__c, Division_Name__c,
                   PO_Release_Date__c, Estimated_Start_Date__c,
                   Requested_Install_Date__c,
                   Days_From_PO_To_Start__c, Business_Days_From_PO_To_Start__c,
                   Timing_Rule__c, Timing_Rule_Min_Days__c,
                   Timing_Rule_Max_Days__c, Timing_Rule_Uses_Business_Days__c,
                   Timing_Status__c, Pipeline_Stage__c,
                   Pipeline_Bucket__c,
                   Pipeline_Bucket_Last_Calculated__c,
                   QI_Complete__c, QI_Scheduled__c, Paid__c,
                   Celigo_Payment_Status__c, Invoice_Generated__c,
                   Approval_Process_Completed__c, Approval_Submitted__c,
                   Crew_Completed__c, FSL_Crew_Complete__c,
                   Status__c, Schedule_Locked__c,
                   Takeoff_Status__c, Eight11_Task_Status__c
            FROM   Builder_PO__c
            WHERE  Pipeline_Stage__c != 'Closed'
               AND Status__c        != 'Canceled'
            LIMIT  2000
        ];

        if (pos.isEmpty()) return;

        List<Builder_PO__c> updated = BuilderPoTimingService.recalculateBuilderPOs(pos);

        if (!updated.isEmpty()) {
            update updated;
            BuilderPoTimingService.syncStageToWorkOrders(updated);
        }
    }

    /**
     * Schedule the job if not already scheduled.
     * Safe to call multiple times - checks for existing job first.
     */
    public static void scheduleIfNotScheduled() {
        List<CronTrigger> existing = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ];
        if (existing.isEmpty()) {
            System.schedule(JOB_NAME, CRON_EXP, new BuilderPoPipelineBucketScheduler());
        }
    }

    /**
     * Abort any existing scheduled instance and reschedule fresh.
     */
    public static void reschedule() {
        for (CronTrigger ct : [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
        ]) {
            System.abortJob(ct.Id);
        }
        System.schedule(JOB_NAME, CRON_EXP, new BuilderPoPipelineBucketScheduler());
    }
}