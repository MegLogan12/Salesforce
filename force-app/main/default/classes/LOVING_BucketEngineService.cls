public with sharing class LOVING_BucketEngineService {

    private static final String BUCKET_90   = '90+ Days';
    private static final String BUCKET_60   = '60+ Days';
    private static final String BUCKET_30   = '30 Days';
    private static final String BUCKET_RTS  = 'Ready to Schedule';
    private static final String BUCKET_DONE = 'Takeoff Complete';
    private static final String BUCKET_HOLD = 'On Hold';

    @InvocableMethod(label='Run Bucket Engine' description='Updates lot pipeline buckets based on target dates')
    public static void runBucketEngine() {
        List<Account> lots = [
            SELECT Id, Name, FM__c, Target_Start_Date__c,
                   Pipeline_Bucket__c, Bucket_Changed_Date__c,
                   Takeoff_Task_Created__c, Takeoff_Complete__c,
                   WO_Created__c, Lot_Status__c
            FROM Account
            WHERE RecordType.DeveloperName = 'Lot'
            AND Lot_Status__c = 'Active'
            AND Target_Start_Date__c != null
            AND Pipeline_Bucket__c NOT IN ('Scheduled', 'In Progress', 'Complete', 'Closed', 'Cancelled')
        ];

        if (lots.isEmpty()) return;

        List<Account> toUpdate = new List<Account>();
        List<Task>    newTasks = new List<Task>();
        Date today = Date.today();

        for (Account lot : lots) {
            if (lot.Pipeline_Bucket__c == BUCKET_HOLD) continue;

            Integer daysUntil  = today.daysBetween(lot.Target_Start_Date__c);
            String  newBucket  = calculateBucket(daysUntil, lot.Takeoff_Complete__c);
            Boolean changed    = newBucket != lot.Pipeline_Bucket__c;

            Account updated = new Account(Id = lot.Id);
            updated.Pipeline_Bucket__c = newBucket;
            if (changed) updated.Bucket_Changed_Date__c = System.now();

            Boolean needsTask = !lot.Takeoff_Task_Created__c
                && !lot.Takeoff_Complete__c
                && (newBucket == BUCKET_30 || newBucket == BUCKET_RTS);

            if (needsTask) {
                newTasks.add(buildTakeoffTask(lot, newBucket == BUCKET_RTS));
                updated.Takeoff_Task_Created__c = true;
            }

            if (daysUntil < 0 && !lot.Takeoff_Complete__c && !lot.WO_Created__c) {
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

    private static Task buildTakeoffTask(Account lot, Boolean isHighPriority) {
        Task t = new Task();
        t.Subject      = 'Site Takeoff Required — ' + lot.Name;
        t.OwnerId      = lot.FM__c;
        t.WhatId       = lot.Id;
        t.Priority     = isHighPriority ? 'High' : 'Normal';
        t.ActivityDate = Date.today().addDays(2);
        t.Type         = 'Takeoff';
        t.Description  = 'PHYSICAL SITE VISIT REQUIRED. Complete the takeoff form on mobile. '
            + 'Geotag validation required — must be within 150m of lot address. '
            + 'DEADLINE: 48 hours. Escalates to manager if missed. '
            + 'Target install date: '
            + (lot.Target_Start_Date__c != null ? lot.Target_Start_Date__c.format() : 'TBD');
        return t;
    }
}
