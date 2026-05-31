public with sharing class LOVING_BucketEngineService {

    private static final String BUCKET_90   = '90+ Days';
    private static final String BUCKET_60   = '60+ Days';
    private static final String BUCKET_30   = '30 Days';
    private static final String BUCKET_RTS  = 'Ready to Schedule';
    private static final String BUCKET_DONE = 'Takeoff Complete';
    private static final String BUCKET_HOLD = 'On Hold';

    @InvocableMethod(label='Run Bucket Engine' description='Updates lot pipeline buckets based on target dates')
    public static void runBucketEngine() {
        List<Lot__c> lots = [
            SELECT Id, Name, Requested_Install_Date__c,
                   Pipeline_Bucket__c, Lot_Status__c,
                   Current_Work_Order__c,
                   Current_Work_Order__r.Takeoff_Complete__c,
                   Community__r.Assigned_FM__c
            FROM Lot__c
            WHERE Lot_Status__c = 'Active'
            AND Requested_Install_Date__c != null
            AND Pipeline_Bucket__c NOT IN ('Scheduled', 'In Progress', 'Complete', 'Closed', 'Cancelled')
        ];

        if (lots.isEmpty()) return;

        Set<Id> lotIds = new Set<Id>();
        for (Lot__c lot : lots) lotIds.add(lot.Id);

        Set<Id> lotsWithTakeoffTask = new Set<Id>();
        for (Task t : [
            SELECT WhatId FROM Task
            WHERE WhatId IN :lotIds AND Type = 'Takeoff' AND IsClosed = false
        ]) {
            lotsWithTakeoffTask.add(t.WhatId);
        }

        List<Lot__c> toUpdate = new List<Lot__c>();
        List<Task>   newTasks = new List<Task>();
        Date today = Date.today();

        for (Lot__c lot : lots) {
            if (lot.Pipeline_Bucket__c == BUCKET_HOLD) continue;

            Boolean takeoffDone = lot.Current_Work_Order__r != null
                && lot.Current_Work_Order__r.Takeoff_Complete__c == true;
            Boolean woCreated = lot.Current_Work_Order__c != null;

            Integer daysUntil = today.daysBetween(lot.Requested_Install_Date__c);
            String  newBucket = calculateBucket(daysUntil, takeoffDone);

            Lot__c updated = new Lot__c(Id = lot.Id);
            updated.Pipeline_Bucket__c = newBucket;

            Boolean needsTask = !lotsWithTakeoffTask.contains(lot.Id)
                && !takeoffDone
                && (newBucket == BUCKET_30 || newBucket == BUCKET_RTS);

            if (needsTask) {
                Id fmId = lot.Community__r != null ? lot.Community__r.Assigned_FM__c : null;
                if (fmId != null) {
                    newTasks.add(buildTakeoffTask(lot, fmId, newBucket == BUCKET_RTS));
                }
            }

            if (daysUntil < 0 && !takeoffDone && !woCreated) {
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

    private static Task buildTakeoffTask(Lot__c lot, Id fmId, Boolean isHighPriority) {
        Task t = new Task();
        t.Subject      = 'Site Takeoff Required — ' + lot.Name;
        t.OwnerId      = fmId;
        t.WhatId       = lot.Id;
        t.Priority     = isHighPriority ? 'High' : 'Normal';
        t.ActivityDate = Date.today().addDays(2);
        t.Type         = 'Takeoff';
        t.Description  = 'PHYSICAL SITE VISIT REQUIRED. Complete the takeoff form on mobile. '
            + 'Geotag validation required — must be within 150m of lot address. '
            + 'DEADLINE: 48 hours. Escalates to manager if missed. '
            + 'Target install date: '
            + (lot.Requested_Install_Date__c != null ? lot.Requested_Install_Date__c.format() : 'TBD');
        return t;
    }
}
