/**
 * Self-rescheduling scheduler for WEX GPS position sync.
 *
 * Salesforce cron minimum is 1 minute. To achieve a 3-minute polling cadence,
 * this scheduler re-schedules itself after each execution rather than relying
 * on a fixed cron expression.
 *
 * Initial kickoff from Anonymous Apex (run once after deploy):
 *   WexGpsSyncScheduler.start();
 *
 * To stop the sync:
 *   WexGpsSyncScheduler.stop();
 */
global with sharing class WexGpsSyncScheduler implements Schedulable {

    @TestVisible static final String JOB_NAME_PREFIX = 'WEX GPS Sync';
    @TestVisible static final Integer INTERVAL_MINUTES = 3;

    global void execute(SchedulableContext sc) {
        WexGpsSyncService.syncPositions();
        if (!Test.isRunningTest()) {
            scheduleNextRun();
        }
    }

    // Kick off the chain from Anonymous Apex.
    global static void start() {
        stop();
        scheduleNextRun();
    }

    // Abort all running WEX GPS sync jobs to halt the chain.
    global static void stop() {
        for (CronTrigger ct : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :JOB_NAME_PREFIX + '%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ]) {
            try { System.abortJob(ct.Id); } catch (Exception e) { /* already gone */ }
        }
    }

    @TestVisible
    static void scheduleNextRun() {
        DateTime next = DateTime.now().addMinutes(INTERVAL_MINUTES);
        String cron =       next.second() + ' '
                          + next.minute() + ' '
                          + next.hour()   + ' '
                          + next.day()    + ' '
                          + next.month()  + ' ? '
                          + next.year();
        System.schedule(JOB_NAME_PREFIX + ' ' + next.getTime(), cron, new WexGpsSyncScheduler());
    }
}