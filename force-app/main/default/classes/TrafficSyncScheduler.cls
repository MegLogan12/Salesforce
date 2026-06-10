/**
 * Every-5-minute self-rescheduling scheduler for traffic sync (OSRM + HERE incidents).
 *
 * Run once from Anonymous Apex to activate:
 *   TrafficSyncScheduler.startRealtime();
 *
 * To stop:
 *   TrafficSyncScheduler.stopRealtime();
 *
 * scheduleHalfHourly() kept as backward-compatible alias for startRealtime().
 */
global with sharing class TrafficSyncScheduler implements Schedulable {

    @TestVisible static final String  JOB_PREFIX = 'Traffic Sync';
    @TestVisible static final Integer INTERVAL   = 5;

    global void execute(SchedulableContext sc) {
        TrafficSyncService.syncTraffic();
        scheduleNextRun();
    }

    global static void startRealtime() {
        stopRealtime();
        scheduleNextRun();
    }

    global static void stopRealtime() {
        for (CronTrigger ct : [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :JOB_PREFIX + '%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ]) {
            try { System.abortJob(ct.Id); } catch (Exception ignored) {}
        }
    }

    // Backward-compatible alias.
    global static void scheduleHalfHourly() {
        startRealtime();
    }

    // Backward-compatible alias.
    global static void unschedule() {
        stopRealtime();
    }

    private static void scheduleNextRun() {
        DateTime next = DateTime.now().addMinutes(INTERVAL);
        String cron = next.second()  + ' '
                    + next.minute()  + ' '
                    + next.hour()    + ' '
                    + next.day()     + ' '
                    + next.month()   + ' '
                    + '? '
                    + next.year();
        System.schedule(JOB_PREFIX + ' ' + next.getTime(), cron, new TrafficSyncScheduler());
    }
}