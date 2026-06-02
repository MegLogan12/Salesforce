/**
 * GPSIntegrationScheduler — self-rescheduling Schedulable that fires GPSINTEGRATION
 * every INTERVAL_MINUTES minutes.
 *
 * Self-rescheduling pattern: each execution re-schedules the next fire time
 * at now + INTERVAL_MINUTES, so the cadence stays accurate regardless of when
 * the org scheduler actually fires the job.
 *
 * Start from Anonymous Apex (run once after deploy):
 *   GPSIntegrationScheduler.start();
 *
 * Stop:
 *   GPSIntegrationScheduler.stop();
 */
public with sharing class GPSIntegrationScheduler implements Schedulable {

    public static final String  JOB_NAME         = 'GPS Fleet Intelligence Sync';
    public static final Integer INTERVAL_MINUTES = 15;

    public void execute(SchedulableContext ctx) {
        GPSINTEGRATION.run(GPSSyncType.LOCATIONS);
        reschedule();
    }

    public static void start() {
        stop();
        schedule(DateTime.now().addMinutes(INTERVAL_MINUTES));
    }

    public static void stop() {
        for (CronTrigger ct : [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME
        ]) {
            System.abortJob(ct.Id);
        }
    }

    private void reschedule() {
        stop();
        schedule(DateTime.now().addMinutes(INTERVAL_MINUTES));
    }

    private static void schedule(DateTime next) {
        String cron = buildCron(next);
        System.schedule(JOB_NAME, cron, new GPSIntegrationScheduler());
    }

    private static String buildCron(DateTime dt) {
        return '0 ' + dt.minute() + ' ' + dt.hour() + ' ' + dt.day()
             + ' ' + dt.month() + ' ? ' + dt.year();
    }
}