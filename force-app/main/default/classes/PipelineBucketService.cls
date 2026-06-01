/**
 * PipelineBucketService
 * Pipeline Bucket Assignment and Daily Recalculation
 *
 * Bucket model (per Loving Group process guide):
 *   90+ Days          → days > 60
 *   60+ Days          → days 31 to 60
 *   30 Days           → days <= 30 (Takeoff Task + 811 Utility Marking auto-created)
 *   Clear to Schedule → days <= 30 AND both Takeoff Task and 811 Task Completed
 *   Scheduled         → Schedule_Locked__c = TRUE (manager-approved schedule)
 *
 * Legacy values (Ready to Schedule, Takeoff In Progress) are retained on the
 * picklist for back-compat with existing data, but are no longer assigned by
 * calculateBucket.
 *
 * On new WO creation: assignBuckets() fires from WorkOrderHandler.handleAfter
 *   and seeds the system note. Takeoff/811 tasks are NOT created on insert;
 *   they are created when the WO enters the 30 Days bucket (one-time gate
 *   via Takeoff_Tasks_Created__c).
 *
 * Nightly (5 AM): PipelineBucketScheduler calls recalculateAllOpenBuckets()
 *   so every open WO advances automatically as its start date approaches.
 */
public with sharing class PipelineBucketService {

    public static final String BUCKET_90_PLUS            = '90+ Days';
    public static final String BUCKET_60_PLUS            = '60+ Days';
    public static final String BUCKET_30_DAYS            = '30 Days';
    public static final String BUCKET_CLEAR_TO_SCHEDULE  = 'Clear to Schedule';
    public static final String BUCKET_SCHEDULED          = 'Scheduled';
    // Legacy (kept for back-compat only)
    public static final String BUCKET_READY              = 'Ready to Schedule';
    public static final String BUCKET_TAKEOFF_PROGRESS   = 'Takeoff In Progress';

    public static final String TASK_TYPE_TAKEOFF         = 'Takeoff';
    public static final String TASK_TYPE_811             = '811 Utility Marking';

    // ─────────────────────────────────────────────
    // ASSIGN BUCKETS — called from trigger on new WO creation
    // ─────────────────────────────────────────────
    public static void assignBuckets(List<Work_Order__c> workOrders) {
        List<Work_Order__c> toUpdate = new List<Work_Order__c>();
        List<Work_Order__c> entered30Days = new List<Work_Order__c>();

        for (Work_Order__c wo : workOrders) {
            String bucket = calculateBucket(wo);
            if (bucket != wo.Pipeline_Bucket__c) {
                toUpdate.add(new Work_Order__c(
                    Id                 = wo.Id,
                    Pipeline_Bucket__c = bucket
                ));
            }
            if (bucket == BUCKET_30_DAYS && wo.Takeoff_Tasks_Created__c != true) {
                entered30Days.add(wo);
            }
        }

        if (!toUpdate.isEmpty()) update toUpdate;

        createPendingTakeoffNotes(workOrders);

        if (!entered30Days.isEmpty()) launchTakeoffAndUtilityTasks(entered30Days);
    }

    // ─────────────────────────────────────────────
    // RECALCULATE ALL OPEN BUCKETS — called nightly by PipelineBucketScheduler
    // Also called from TaskTrigger when a Takeoff/811 task is completed.
    // ─────────────────────────────────────────────
    public static void recalculateAllOpenBuckets() {
        List<Work_Order__c> openWOs = [
            SELECT Id, Requested_Install_Date__c, Days_Until_Start__c,
                   Pipeline_Bucket__c, Status__c, Takeoff_Status__c,
                   FM_Assignment__c, Schedule_Locked__c,
                   Takeoff_Task_Complete__c, Utility_Marking_Complete__c,
                   Takeoff_Tasks_Created__c
            FROM Work_Order__c
            WHERE Status__c NOT IN ('Closed', 'Approved', 'Invoiced', 'Paid')
            AND (Requested_Install_Date__c != null OR Days_Until_Start__c != null)
        ];

        recalculateBuckets(openWOs);
    }

    // ─────────────────────────────────────────────
    // RECALCULATE for a specific set of WOs (used by TaskTrigger)
    // ─────────────────────────────────────────────
    public static void recalculateBuckets(List<Work_Order__c> openWOs) {
        if (openWOs == null || openWOs.isEmpty()) return;

        List<Work_Order__c> toUpdate = new List<Work_Order__c>();
        List<Work_Order__c> entered30Days = new List<Work_Order__c>();

        for (Work_Order__c wo : openWOs) {
            String newBucket = calculateBucket(wo);
            Boolean transitionedTo30Days = newBucket == BUCKET_30_DAYS
                                        && wo.Pipeline_Bucket__c != BUCKET_30_DAYS
                                        && wo.Takeoff_Tasks_Created__c != true;

            if (newBucket != wo.Pipeline_Bucket__c) {
                toUpdate.add(new Work_Order__c(
                    Id                 = wo.Id,
                    Pipeline_Bucket__c = newBucket
                ));
            }
            if (transitionedTo30Days) entered30Days.add(wo);
        }

        if (!toUpdate.isEmpty()) update toUpdate;

        if (!entered30Days.isEmpty()) launchTakeoffAndUtilityTasks(entered30Days);
    }

    // ─────────────────────────────────────────────
    // BUCKET CALCULATION
    // Order matters: Schedule_Locked wins, then date thresholds, then
    // task-completion gate within the 30 Days window.
    // ─────────────────────────────────────────────
    public static String calculateBucket(Work_Order__c wo) {
        if (wo.Schedule_Locked__c == true) return BUCKET_SCHEDULED;

        Integer daysUntil;
        if (wo.Days_Until_Start__c != null) {
            daysUntil = (Integer) wo.Days_Until_Start__c;
        } else if (wo.Requested_Install_Date__c != null) {
            daysUntil = Date.today().daysBetween(wo.Requested_Install_Date__c);
        } else {
            return BUCKET_90_PLUS;
        }

        if (daysUntil > 60) return BUCKET_90_PLUS;
        if (daysUntil > 30) return BUCKET_60_PLUS;

        // Within 30 days: gated by task completion
        if (wo.Takeoff_Task_Complete__c == true && wo.Utility_Marking_Complete__c == true) {
            return BUCKET_CLEAR_TO_SCHEDULE;
        }
        return BUCKET_30_DAYS;
    }

    // ─────────────────────────────────────────────
    // MONDAY–FRIDAY HELPER
    // ─────────────────────────────────────────────
    public static Date nextWeekday(Date d) {
        Integer dow = Math.mod(Date.newInstance(1900, 1, 7).daysBetween(d), 7);
        if (dow == 6) return d.addDays(2);
        if (dow == 0) return d.addDays(1);
        return d;
    }

    // ─────────────────────────────────────────────
    // SYSTEM NOTE — on PO receipt
    // ─────────────────────────────────────────────
    private static void createPendingTakeoffNotes(List<Work_Order__c> wos) {
        List<Work_Order_Note__c> notes = new List<Work_Order_Note__c>();
        for (Work_Order__c wo : wos) {
            notes.add(new Work_Order_Note__c(
                LOVING_Work_Order__c = wo.Id,
                Note__c              = 'Work Order created from PO. Pending physical takeoff and 811 utility marking once WO enters the 30 Days bucket.',
                Note_Type__c         = 'System',
                Created_By_System__c = true
            ));
        }
        if (!notes.isEmpty()) {
            try {
                Database.insert(notes, false); // allOrNone=false: field-mismatch errors are non-fatal
            } catch (Exception e) {
                ErrorLogService.log('PipelineBucketService', 'createPendingTakeoffNotes', null, e.getMessage());
            }
        }
    }

    // ─────────────────────────────────────────────
    // TAKEOFF + 811 TASK LAUNCH — fires when WO enters 30 Days bucket
    // Idempotent: gated by Takeoff_Tasks_Created__c on the WO.
    //
    // Also creates a Salesforce Event for the FM Takeoff Visit. The Event is
    // owned by the assigned FM (`FM_Assignment__c`), so it lands on their
    // calendar; Einstein Activity Capture (admin-enabled, see README) syncs
    // Salesforce Events bidirectionally with the FM's Outlook calendar. No
    // Event is created if FM_Assignment__c is null — the Task still tracks
    // the work, the Event is just deferred until an FM is assigned.
    // ─────────────────────────────────────────────
    @TestVisible
    private static final Integer TAKEOFF_EVENT_START_HOUR = 9;
    @TestVisible
    private static final Integer TAKEOFF_EVENT_DURATION_MIN = 120;

    private static void launchTakeoffAndUtilityTasks(List<Work_Order__c> wos) {
        List<Task> tasks = new List<Task>();
        List<Event> events = new List<Event>();
        List<Work_Order__c> flagUpdates = new List<Work_Order__c>();

        for (Work_Order__c wo : wos) {
            Id ownerId = wo.FM_Assignment__c != null ? wo.FM_Assignment__c : UserInfo.getUserId();
            Date takeoffDue = nextWeekday(Date.today().addDays(2));
            Date utilityDue = nextWeekday(Date.today().addDays(3));

            tasks.add(new Task(
                WhatId       = wo.Id,
                OwnerId      = ownerId,
                Subject      = 'Takeoff Required — ' + wo.Name,
                Type         = TASK_TYPE_TAKEOFF,
                Status       = 'Not Started',
                Priority     = 'High',
                ActivityDate = takeoffDue,
                Description  = 'Physical takeoff required for this lot. Measure sod sq ft, plant counts by species, tree counts. '
                             + 'Attach minimum 3 photos (front, back, side). GPS geotag within 150m of lot address required. '
                             + 'A matching calendar event has been placed on the assigned FM\'s Outlook calendar; '
                             + 'do not move the event without re-checking conflicts.'
            ));

            tasks.add(new Task(
                WhatId       = wo.Id,
                OwnerId      = ownerId,
                Subject      = '811 Utility Marking — ' + wo.Name,
                Type         = TASK_TYPE_811,
                Status       = 'Not Started',
                Priority     = 'High',
                ActivityDate = utilityDue,
                Description  = 'Submit 811 utility marking request and confirm marks completed on lot before scheduling install. '
                             + 'Required to release the schedule console blocker.'
            ));

            if (wo.FM_Assignment__c != null) {
                Datetime startDt = Datetime.newInstance(
                    takeoffDue, Time.newInstance(TAKEOFF_EVENT_START_HOUR, 0, 0, 0)
                );
                events.add(new Event(
                    WhatId             = wo.Id,
                    OwnerId            = wo.FM_Assignment__c,
                    Subject            = 'Takeoff Visit - ' + wo.Name,
                    StartDateTime      = startDt,
                    DurationInMinutes  = TAKEOFF_EVENT_DURATION_MIN,
                    ShowAs             = 'Busy',
                    Description        = 'On-site takeoff for this lot. Sync\'d to your Outlook calendar via Einstein Activity Capture. '
                                       + 'If you must reschedule, re-check this slot against the install Calculated Start Date.'
                ));
            }

            flagUpdates.add(new Work_Order__c(
                Id                       = wo.Id,
                Takeoff_Tasks_Created__c = true
            ));
        }

        if (!tasks.isEmpty())       insert tasks;
        if (!events.isEmpty())      insert events;
        if (!flagUpdates.isEmpty()) update flagUpdates;

        // Dispatch 811 locate requests to the configured state vendor.
        // Idempotent: UtilityMarkingService skips WOs already stamped.
        UtilityMarkingService.dispatch811Requests(wos);
    }

    // ─────────────────────────────────────────────
    // 48-HOUR TAKEOFF ESCALATION — called by nightly scheduler
    // ─────────────────────────────────────────────
    @future
    public static void escalateStaleTakeoffs() {
        Datetime cutoff = Datetime.now().addHours(-48);
        List<Work_Order__c> stale = [
            SELECT Id, Name, FM_Assignment__c, Pipeline_Bucket__c
            FROM Work_Order__c
            WHERE Pipeline_Bucket__c = '30 Days'
            AND Takeoff_Task_Complete__c = false
            AND CreatedDate <= :cutoff
        ];

        if (!stale.isEmpty()) EscalationService.escalateTakeoffOverdue(stale);
    }
}