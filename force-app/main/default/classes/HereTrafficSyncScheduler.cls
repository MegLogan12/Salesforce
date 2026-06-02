/**
 * HereTrafficSyncScheduler
 * Schedulable wrapper for HereTrafficSyncService.
 * Schedule 4 jobs (at :00, :15, :30, :45) for every-15-minute refresh.
 *
 * Run this anonymous Apex once to activate all four schedule slots:
 *
 *   System.schedule('HERE Traffic - :00', '0 0  * * * ?', new HereTrafficSyncScheduler());
 *   System.schedule('HERE Traffic - :15', '0 15 * * * ?', new HereTrafficSyncScheduler());
 *   System.schedule('HERE Traffic - :30', '0 30 * * * ?', new HereTrafficSyncScheduler());
 *   System.schedule('HERE Traffic - :45', '0 45 * * * ?', new HereTrafficSyncScheduler());
 */
global class HereTrafficSyncScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        System.enqueueJob(new HereTrafficSyncService());
    }
}