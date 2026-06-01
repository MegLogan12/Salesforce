/**
 * AutoCloseScheduler
 *
 * Nightly Schedulable that triggers the Home Builder auto-close logic.
 * Delegates entirely to HomeBuilderAutoCloseService.runNightlyAutoClose().
 */
public with sharing class AutoCloseScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        HomeBuilderAutoCloseService.runNightlyAutoClose();
    }
}
