public with sharing class LOVING_BucketEngineService {

    private static final String BUCKET_90   = '90+ Days';
    private static final String BUCKET_60   = '60+ Days';
    private static final String BUCKET_30   = '30 Days';
    private static final String BUCKET_RTS  = 'Ready to Schedule';
    private static final String BUCKET_DONE = 'Takeoff Complete';
    private static final String BUCKET_HOLD = 'On Hold';

    @TestVisible private static List<WorkOrder> mockWorkOrders;
    @TestVisible private static Set<Id> mockWorkOrdersWithTakeoffTasks;
    @TestVisible private static List<WorkOrder> lastUpdatedWorkOrders;
    @TestVisible private static List<Task> lastCreatedTasks;

    @InvocableMethod(label='Run Bucket Engine' description='Updates work order pipeline buckets based on target dates')
    public static void runBucketEngine() {
        List<WorkOrder> wos = mockWorkOrders != null ? mockWorkOrders : [
            SELECT Id, WorkOrderNumber, Requested_Install_Date__c,
                   Pipeline_Bucket__c, Status,
                   Takeoff_Complete__c,
                   Field_Manager__c
            FROM WorkOrder
            WHERE Status NOT IN ('Closed', 'Canceled', 'Field Complete',
                                    'Pending Closeout', 'Closeout Approved',
                                    'Paid', 'Invoiced', 'Ready for Invoice',
                                    'Scheduled', 'In Progress')
            AND Requested_Install_Date__c != null
            AND Pipeline_Bucket__c NOT IN ('Scheduled', 'Clear to Schedule')
        ];

        if (wos.isEmpty()) return;

        Set<Id> workOrderIds = new Map<Id, WorkOrder>(wos).keySet();
        Set<Id> workOrdersWithTakeoffTasks = new Set<Id>();
        if (mockWorkOrders != null) {
            workOrdersWithTakeoffTasks = mockWorkOrdersWithTakeoffTasks != null
                ? mockWorkOrdersWithTakeoffTasks
                : new Set<Id>();
        } else {
            for (Task task : [
                SELECT WhatId
                FROM Task
                WHERE WhatId IN :workOrderIds
                AND Type = 'Takeoff'
                AND Subject LIKE 'Site Takeoff Required%'
            ]) {
                workOrdersWithTakeoffTasks.add(task.WhatId);
            }
        }

        List<WorkOrder> toUpdate = new List<WorkOrder>();
        List<Task>          newTasks = new List<Task>();
        Date today = Date.today();

        for (WorkOrder wo : wos) {
            if (wo.Pipeline_Bucket__c == BUCKET_HOLD) continue;

            Boolean takeoffDone = wo.Takeoff_Complete__c == true;
            Integer daysUntil   = today.daysBetween(wo.Requested_Install_Date__c);
            String  newBucket   = calculateBucket(daysUntil, takeoffDone);

            WorkOrder updated = new WorkOrder(Id = wo.Id);
            updated.Pipeline_Bucket__c = newBucket;

            Boolean needsTask = !workOrdersWithTakeoffTasks.contains(wo.Id)
                && !takeoffDone
                && (newBucket == BUCKET_30 || newBucket == BUCKET_RTS);

            if (needsTask && wo.Field_Manager__c != null) {
                newTasks.add(buildTakeoffTask(wo, newBucket == BUCKET_RTS));
            }

            if (daysUntil < 0 && !takeoffDone) {
                updated.Pipeline_Bucket__c = BUCKET_RTS;
            }

            toUpdate.add(updated);
        }

        if (mockWorkOrders != null) {
            lastUpdatedWorkOrders = toUpdate;
            lastCreatedTasks = newTasks;
            return;
        }

        if (!toUpdate.isEmpty()) update toUpdate;
        if (!newTasks.isEmpty()) insert newTasks;
    }

    @TestVisible private static String calculateBucket(Integer daysUntil, Boolean takeoffDone) {
        if (takeoffDone)     return BUCKET_DONE;
        if (daysUntil > 60)  return BUCKET_90;
        if (daysUntil > 30)  return BUCKET_60;
        if (daysUntil >= 15) return BUCKET_30;
        return BUCKET_RTS;
    }

    @TestVisible private static Task buildTakeoffTask(WorkOrder wo, Boolean isHighPriority) {
        Task t = new Task();
        String workOrderName = String.isNotBlank(wo.WorkOrderNumber) ? wo.WorkOrderNumber : String.valueOf(wo.Id);
        t.Subject      = 'Site Takeoff Required — ' + workOrderName;
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