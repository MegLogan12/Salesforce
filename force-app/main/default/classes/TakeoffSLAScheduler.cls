/**
 * TakeoffSLAScheduler
 * Checks takeoff SLA: flag if In Progress > 48 hours without submission.
 * Runs every 6 hours.
 *
 * Schedule:
 *   System.schedule('Takeoff SLA Check', '0 0 0/6 * * ?', new TakeoffSLAScheduler());
 */
global class TakeoffSLAScheduler implements Schedulable {

    global void execute(SchedulableContext ctx) {
        TakeoffService.checkTakeoffSLA();
    }
}