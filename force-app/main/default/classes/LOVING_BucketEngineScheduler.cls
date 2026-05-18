/**
 * LOVING_BucketEngineScheduler
 *
 * Runs daily at 5:00 AM. Updates Pipeline_Bucket__c on all active Lot records
 * based on Days_Until_Target__c. Creates Takeoff Tasks when lots enter
 * the 30-day window for the first time.
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

/**
 * LOVING_BucketEngineService
 * Business logic for the bucket engine, separated for testability and
 * for invocation from both the scheduler and Flow (via @InvocableMethod).
 */
public without sharing class LOVING_BucketEngineService {

    // Bucket values must match Pipeline_Bucket__c picklist exactly
    private static final String BUCKET_90   = '90+ Days';
    private static final String BUCKET_60   = '60+ Days';
    private static final String BUCKET_30   = '30 Days';
    private static final String BUCKET_RTS  = 'Ready to Schedule';
    private static final String BUCKET_TIP  = 'Takeoff In Progress';
    private static final String BUCKET_DONE = 'Takeoff Complete';
    private static final String BUCKET_SCHED= 'Scheduled';
    private static final String BUCKET_HOLD = 'On Hold';

    @InvocableMethod(label='Run Bucket Engine' description='Updates lot pipeline buckets based on target dates')
    public static void runBucketEngine() {
        // Query all active lots with a PO received date
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

        List<Account>   toUpdate = new List<Account>();
        List<Task>      newTasks = new List<Task>();
        Date today = Date.today();

        for (Account lot : lots) {
            if (lot.Pipeline_Bucket__c == BUCKET_HOLD) continue; // Skip on-hold lots

            Integer daysUntil = today.daysBetween(lot.Target_Start_Date__c);
            String newBucket  = calculateBucket(daysUntil, lot.Takeoff_Complete__c);
            Boolean bucketChanged = newBucket != lot.Pipeline_Bucket__c;

            Account updated = new Account(Id=lot.Id);
            updated.Pipeline_Bucket__c = newBucket;

            if (bucketChanged) {
                updated.Bucket_Changed_Date__c = System.now();
            }

            // Create Takeoff Task when entering 30-day or RTS bucket for first time
            Boolean needsTakeoffTask = !lot.Takeoff_Task_Created__c
                && !lot.Takeoff_Complete__c
                && (newBucket == BUCKET_30 || newBucket == BUCKET_RTS);

            if (needsTakeoffTask) {
                Task t = buildTakeoffTask(lot, newBucket == BUCKET_RTS);
                newTasks.add(t);
                updated.Takeoff_Task_Created__c = true;
            }

            // Overdue target date check
            if (daysUntil < 0 && !lot.Takeoff_Complete__c && !lot.WO_Created__c) {
                // Ensure bucket is Ready to Schedule
                updated.Pipeline_Bucket__c = BUCKET_RTS;
            }

            toUpdate.add(updated);
        }

        if (!toUpdate.isEmpty()) update toUpdate;
        if (!newTasks.isEmpty()) insert newTasks;
    }

    private static String calculateBucket(Integer daysUntil, Boolean takeoffDone) {
        if (takeoffDone) return BUCKET_DONE;
        if (daysUntil > 60)  return BUCKET_90;
        if (daysUntil > 30)  return BUCKET_60;
        if (daysUntil >= 15) return BUCKET_30;
        return BUCKET_RTS;
    }

    private static Task buildTakeoffTask(Account lot, Boolean isHighPriority) {
        Task t = new Task();
        t.Subject       = 'Site Takeoff Required — ' + lot.Name;
        t.OwnerId       = lot.FM__c;
        t.WhatId        = lot.Id;
        t.Priority      = isHighPriority ? 'High' : 'Normal';
        t.ActivityDate  = Date.today().addDays(2); // 48-hour window
        t.Type          = 'Takeoff';
        t.Description   = 'PHYSICAL SITE VISIT REQUIRED. You must be at the lot to complete this form.\n\n'
            + 'Before visiting:\n'
            + '  1. Review the community BMG package in Salesforce.\n'
            + '  2. Download the plot plan for this lot.\n\n'
            + 'At the lot:\n'
            + '  1. Open the Takeoff form on your mobile device.\n'
            + '  2. Capture 3 photos: front property line, rear, side.\n'
            + '  3. Confirm or adjust quantities for each line item.\n'
            + '  4. Note any scope outside PO, MPO status, or site issues.\n'
            + '  5. Submit. Geotag validation required — must be within 150m of lot address.\n\n'
            + 'DEADLINE: 48 hours from task creation. Escalates to your manager if missed.\n'
            + 'Target install date: ' + (lot.Target_Start_Date__c != null
                ? lot.Target_Start_Date__c.format() : 'TBD');
        return t;
    }
}
