public with sharing class LOVING_BucketEngineService {

    private static final String BUCKET_90   = '90+ Days';
    private static final String BUCKET_60   = '60+ Days';
    private static final String BUCKET_30   = '30 Days';
    private static final String BUCKET_RTS  = 'Ready to Schedule';
    private static final String BUCKET_DONE = 'Takeoff Complete';
    private static final String BUCKET_HOLD = 'On Hold';

    @InvocableMethod(label='Run Bucket Engine' description='Updates work order pipeline buckets based on target dates')
    public static void runBucketEngine() {
        List<Work_Order__c> wos = [
            SELECT Id, Name, Requested_Install_Date__c,
                   Pipeline_Bucket__c, Status__c,
                   Takeoff_Task_Complete__c, Takeoff_Tasks_Created__c,
                   Field_Manager__c
            FROM Work_Order__c
            WHERE Status__c NOT IN ('Closed', 'Cancelled', 'Field Complete',
                                    'Pending Closeout', 'Closeout Approved',
                                    'Paid', 'Invoiced', 'Ready for Invoice',
                                    'Scheduled', 'In Progress')
            AND Requested_Install_Date__c != null
            AND Pipeline_Bucket__c NOT IN ('Scheduled', 'Clear to Schedule')
        ];

        if (wos.isEmpty()) return;

        List<Work_Order__c> toUpdate = new List<Work_Order__c>();
        List<Task>          newTasks = new List<Task>();
        Date today = Date.today();

        for (Work_Order__c wo : wos) {
            if (wo.Pipeline_Bucket__c == BUCKET_HOLD) continue;

            Boolean takeoffDone = wo.Takeoff_Task_Complete__c == true;
            Integer daysUntil   = today.daysBetween(wo.Requested_Install_Date__c);
            String  newBucket   = calculateBucket(daysUntil, takeoffDone);

            Work_Order__c updated = new Work_Order__c(Id = wo.Id);
            updated.Pipeline_Bucket__c = newBucket;

            Boolean needsTask = !wo.Takeoff_Tasks_Created__c
                && !takeoffDone
                && (newBucket == BUCKET_30 || newBucket == BUCKET_RTS);

            if (needsTask && wo.Field_Manager__c != null) {
                newTasks.add(buildTakeoffTask(wo, newBucket == BUCKET_RTS));
                updated.Takeoff_Tasks_Created__c = true;
            }

            if (daysUntil < 0 && !takeoffDone) {
                updated.Pipeline_Bucket__c = BUCKET_RTS;
            }

            toUpdate.add(updated);
        }

        if (!toUpdate.isEmpty()) update toUpdate;
        if (!newTasks.isEmpty()) insert newTasks;
    }

    private static String calculateBucket(Integer daysUntil, Boolean takeoffDone) {
        if (takeoffDone)     return BUCKET_DONE;
        if (daysUntil > 60)  return BUCKET_90;
        if (daysUntil > 30)  return BUCKET_60;
        if (daysUntil >= 15) return BUCKET_30;
        return BUCKET_RTS;
    }

    @TestVisible private static Task buildTakeoffTask(Work_Order__c wo, Boolean isHighPriority) {
        Task t = new Task();
        t.Subject      = 'Site Takeoff Required — ' + wo.Name;
        t.OwnerId      = wo.Field_Manager__c;
        t.WhatId       = wo.Id;
        t.Priority     = isHighPriority ? 'High' : 'Normal';
        t.ActivityDate = Date.today().addDays(2);
        t.Type         = 'Takeoff';
        t.Description  = 'PHYSICAL SITE VISIT REQUIRED. Complete the takeoff form on mobile. '
            + 'Geotag validation required — must be within 150m of lot address. '
            + 'DEADLINE: 48 hours. Escalates to manager if missed. '
            + 'Target install date: '
            + (wo.Requested_Install_Date__c != null ? wo.Requested_Install_Date__c.format() : 'TBD');
        return t;
    }
}
