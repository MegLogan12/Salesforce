/**
 * Every-15-minute self-rescheduling scheduler for NWS weather alert sync.
 *
 * Run once from Anonymous Apex to activate:
 *   WeatherSyncScheduler.scheduleHourly();
 *
 * To stop:
 *   WeatherSyncScheduler.unschedule();
 */
global with sharing class WeatherSyncScheduler implements Schedulable {

    @TestVisible static final String  JOB_PREFIX = 'NWS Weather Sync';
    @TestVisible static final Integer INTERVAL   = 15;

    global void execute(SchedulableContext sc) {
        WeatherSyncService.syncWeather();
        scheduleNextRun();
    }

    global static void scheduleHourly() {
        unschedule();
        scheduleNextRun();
    }

    global static void unschedule() {
        for (CronTrigger ct : [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :JOB_PREFIX + '%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ]) {
            try { System.abortJob(ct.Id); } catch (Exception ignored) {}
        }
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
        System.schedule(JOB_PREFIX + ' ' + next.getTime(), cron, new WeatherSyncScheduler());
    }
}