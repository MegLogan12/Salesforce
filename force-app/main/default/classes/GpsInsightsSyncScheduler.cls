/**
 * Scheduler for GPS Insights sync.
 *
 * Vehicle sync  — daily at 02:30 (master record refresh, GPS Insights IDs).
 * Location sync — self-rescheduling every 3 minutes for live scheduling console.
 *
 * To start:
 *   GpsInsightsSyncScheduler.scheduleVehicleDaily();
 *   GpsInsightsSyncScheduler.startLocationRealtime();
 *
 * Or combined (backward-compatible):
 *   GpsInsightsSyncScheduler.scheduleDaily();
 *
 * To stop location realtime:
 *   GpsInsightsSyncScheduler.stopLocationRealtime();
 */
global with sharing class GpsInsightsSyncScheduler implements Schedulable {

    @TestVisible static final String  VEHICLE_JOB       = 'GPS Insights Vehicle Sync';
    @TestVisible static final String  LOCATION_PREFIX   = 'GPS Insights Location Sync';
    @TestVisible static final Integer LOCATION_INTERVAL = 3;

    global String jobType;

    global GpsInsightsSyncScheduler() {
        this.jobType = 'VEHICLES';
    }

    global GpsInsightsSyncScheduler(String jobType) {
        this.jobType = jobType;
    }

    global void execute(SchedulableContext sc) {
        if (jobType == 'VEHICLES') {
            GpsInsightsSyncService.syncVehicles();
        } else if (jobType == 'LOCATIONS') {
            GpsInsightsSyncService.syncLocations();
            scheduleNextLocationRun();
        }
    }

    global static void scheduleVehicleDaily() {
        abortIfScheduled(VEHICLE_JOB);
        System.schedule(VEHICLE_JOB, '0 30 2 * * ?', new GpsInsightsSyncScheduler('VEHICLES'));
    }

    global static void startLocationRealtime() {
        stopLocationRealtime();
        scheduleNextLocationRun();
    }

    global static void stopLocationRealtime() {
        for (CronTrigger ct : [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :LOCATION_PREFIX + '%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ]) {
            try { System.abortJob(ct.Id); } catch (Exception ignored) {}
        }
    }

    global static void scheduleDaily() {
        scheduleVehicleDaily();
        startLocationRealtime();
    }

    private static void scheduleNextLocationRun() {
        DateTime next = DateTime.now().addMinutes(LOCATION_INTERVAL);
        String cron = next.second()  + ' '
                    + next.minute()  + ' '
                    + next.hour()    + ' '
                    + next.day()     + ' '
                    + next.month()   + ' '
                    + '? '
                    + next.year();
        System.schedule(LOCATION_PREFIX + ' ' + next.getTime(), cron, new GpsInsightsSyncScheduler('LOCATIONS'));
    }

    private static void abortIfScheduled(String name) {
        for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :name]) {
            try { System.abortJob(ct.Id); } catch (Exception ignored) {}
        }
    }
}