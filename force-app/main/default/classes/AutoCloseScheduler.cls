/**
 * AutoCloseScheduler
 * Nightly job — checks auto-close conditions and closes eligible Work Orders.
 * Also enforces payment SLA (30-day) and QI SLA (5-business-day).
 * Runs daily at 2:00 AM.
 *
 * Schedule:
 *   System.schedule('Nightly Auto-Close', '0 0 2 * * ?', new AutoCloseScheduler());
 */
global class AutoCloseScheduler implements Schedulable {

    global void execute(SchedulableContext ctx) {
        AutoCloseService.runNightlyAutoClose();
        HomeBuilderAutoCloseService.runNightlyAutoClose();
    }
}