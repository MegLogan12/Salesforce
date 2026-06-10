/**
 * ScheduleReleaseGate
 *
 * Called by ScheduleReleaseGateScheduler (currently not scheduled).
 * The original schedule-release gate logic was removed from the org; this
 * class restores the type so the scheduler compiles. The scheduler is not
 * active — re-enable it via Setup → Scheduled Jobs only when the release gate
 * rules are re-implemented here.
 */
public with sharing class ScheduleReleaseGate {

    public static void runHardRelease() {
        Boolean ran = true; // stub — re-implement before scheduling
    }

    public static void runReminderPass() {
        Boolean ran = true; // stub — re-implement before scheduling
    }
}