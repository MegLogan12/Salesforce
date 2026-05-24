/**
 * LOVING_BucketEngineScheduler
 *
 * Runs daily at 5:00 AM. Delegates bucket engine logic to LOVING_BucketEngineService.
 *
 * Schedule: '0 0 5 ? * * *'
 * System.schedule('LOVING Bucket Engine 5AM',
 *     '0 0 5 ? * * *', new LOVING_BucketEngineScheduler());
 */
global without sharing class LOVING_BucketEngineScheduler implements Schedulable {

    global void execute(SchedulableContext ctx) {
        LOVING_BucketEngineService.runBucketEngine();
    }
}
