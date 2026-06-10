/**
 * LovingRollupScheduler
 *
 * Schedulable wrapper for LovingRollupBatch.
 * Runs nightly at 2 AM to refresh aggregate fields on Community__c and Account.
 *
 * To schedule:
 *   LovingRollupScheduler.scheduleNightly();
 *
 * To run immediately (one-off):
 *   Database.executeBatch(new LovingRollupBatch(), 200);
 */
public with sharing class LovingRollupScheduler implements Schedulable {

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new LovingRollupBatch(), 200);
    }

    /**
     * Schedules the nightly rollup at 2:00 AM.
     * Safe to call multiple times — aborts any existing scheduled job first.
     */
    public static String scheduleNightly() {
        final String JOB_NAME = 'LOVING Nightly Rollup';
        final String CRON     = '0 0 2 * * ?';   // 2:00 AM every day

        // Abort existing schedule if present
        for (CronTrigger ct : [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME LIMIT 1
        ]) {
            System.abortJob(ct.Id);
        }

        return System.schedule(JOB_NAME, CRON, new LovingRollupScheduler());
    }
}