/**
 * EPOCountdownScheduler
 * Schedules EPOCountdownBatch to run daily at 7:00 AM.
 */
public with sharing class EPOCountdownScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new EPOCountdownBatch(), 200);
    }

    public static String scheduleDaily() {
        List<CronTrigger> existing = [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'EPO Countdown Daily 7AM' LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        return System.schedule('EPO Countdown Daily 7AM', '0 0 7 * * ?', new EPOCountdownScheduler());
    }
}