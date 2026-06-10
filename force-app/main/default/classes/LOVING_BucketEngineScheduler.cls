global without sharing class LOVING_BucketEngineScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        LOVING_BucketEngineService.runBucketEngine();
    }
}