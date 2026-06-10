/**
 * ScheduleReleaseGateScheduler
 * Cron entries:
 *   - 'Schedule Release Reminder 3:45 PM ET' -> mode='REMINDER'
 *   - 'Schedule Release Hard Release 4:00 PM ET' -> mode='HARD_RELEASE'
 */
public with sharing class ScheduleReleaseGateScheduler implements Schedulable {

    private String mode;

    public ScheduleReleaseGateScheduler(String modeName) {
        this.mode = modeName;
    }

    public void execute(SchedulableContext sc) {
        if ('HARD_RELEASE'.equals(mode)) {
            ScheduleReleaseGate.runHardRelease();
        } else {
            ScheduleReleaseGate.runReminderPass();
        }
    }
}