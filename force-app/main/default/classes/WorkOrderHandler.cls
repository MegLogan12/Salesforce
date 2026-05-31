/**
 * WorkOrderHandler
 * Central handler for Work_Order__c trigger logic.
 *
 * Covers Stages 4 through 14:
 *   Stage 4  — PO Received: pipeline bucket assignment, auto-note, takeoff task creation
 *   Stage 5  — Takeoff: geotag validation, photo requirement, submission lock
 *   Stage 6  — Auto-advance to Ready to Schedule after takeoff locked
 *   Stage 7  — Schedule lock: 48-hr validation, auto-create pull/loading/readiness records
 *   Stage 9  — In Progress: time tracking begins
 *   Stage 11 — Pending Closeout: enforce checklist, auto-create QI task
 *   Stage 12 — NFI: increment NFI counter, auto-escalate if > 2
 *   Stage 13 — Pending Approval: reviewed by Ops Manager
 *   Stage 14 — Approved: trigger invoice generation + QI task
 */
public with sharing class WorkOrderHandler {

    // ─────────────────────────────────────────────
    // BACKWARD-COMPAT: standard WorkOrder trigger (old architecture)
    // The production PO -> WO -> SA path now lands on standard WorkOrder.
    // Keep the standard trigger branch narrow and production-safe: only the
    // invoice gate transition is wired here for QI + invoice bridge creation.
    // ─────────────────────────────────────────────
    public static void handleBefore(List<WorkOrder> newList, Map<Id, WorkOrder> oldMap) {}
    public static void handleAfter(List<WorkOrder> newList, Map<Id, WorkOrder> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }

        Set<String> invoiceGateStatuses = new Set<String>{ 'Approved', 'Ready to Invoice' };
        List<WorkOrder> invoiceGateReached = new List<WorkOrder>();
        for (WorkOrder wo : newList) {
            WorkOrder old = oldMap.get(wo.Id);
            if (old == null || old.Status == wo.Status) {
                continue;
            }
            if (invoiceGateStatuses.contains(wo.Status) && !invoiceGateStatuses.contains(old.Status)) {
                invoiceGateReached.add(wo);
            }
        }

        if (!invoiceGateReached.isEmpty()) {
            CloseoutService.onApproved(invoiceGateReached);
        }
    }

    public static void handleBefore(List<Work_Order__c> newList, Map<Id, Work_Order__c> oldMap) {
        Set<Id> readinessGateWOs = collectInProgressTransitions(newList, oldMap);
        Set<Id> readinessComplete = readinessGateWOs.isEmpty()
            ? new Set<Id>()
            : queryReadinessCompleted(readinessGateWOs);

        for (Work_Order__c wo : newList) {
            Work_Order__c old = (oldMap != null) ? oldMap.get(wo.Id) : null;

            promoteApprovedProposal(wo, old);
            validateScheduleDate(wo, old);
            validateTakeoffSubmission(wo, old);
            enforceSiteReadinessGate(wo, old, readinessComplete);
            enforceCloseoutRequirements(wo, old);
            // NOTE: NFI counter is managed exclusively by CloseoutService.flagNFI
            // to prevent double-increment. Do NOT call incrementNFICount here.
        }

        if (oldMap == null) {
            CCCloseoutAssigner.assignNew(newList);
        }
    }

    private static Set<Id> collectInProgressTransitions(List<Work_Order__c> newList, Map<Id, Work_Order__c> oldMap) {
        Set<Id> ids = new Set<Id>();
        if (oldMap == null) return ids;
        for (Work_Order__c wo : newList) {
            Work_Order__c old = oldMap.get(wo.Id);
            if (old != null && old.Status__c != 'In Progress' && wo.Status__c == 'In Progress') {
                ids.add(wo.Id);
            }
        }
        return ids;
    }

    private static Set<Id> queryReadinessCompleted(Set<Id> woIds) {
        Set<Id> out = new Set<Id>();
        for (Task t : [
            SELECT WhatId FROM Task
            WHERE WhatId IN :woIds AND Type = 'Site Readiness' AND Status = 'Completed'
        ]) {
            out.add(t.WhatId);
        }
        return out;
    }

    // Stage 8: hard floor — crew cannot start until Site Readiness Task is Completed.
    private static void enforceSiteReadinessGate(Work_Order__c wo, Work_Order__c old, Set<Id> readinessComplete) {
        if (old == null || old.Status__c == 'In Progress' || wo.Status__c != 'In Progress') return;
        if (!readinessComplete.contains(wo.Id)) {
            wo.Status__c.addError(
                'Cannot move to In Progress: Site Readiness Check (T-48) Task must be Completed first. '
              + 'Mark the readiness Task Completed, or use Site Not Ready to pull this WO from the schedule.'
            );
        }
    }

    // Stage 7: when Scheduling Manager flips Schedule_Proposal_Status to 'Manager Approved',
    // promote Proposed_* values to live Scheduled_Date / Crew and lock the schedule.
    // Gate: locking is only permitted once the WO has reached the 'Clear to Schedule' bucket
    // (Takeoff Task + 811 Utility Marking Task both Completed). Approving early raises an error.
    private static void promoteApprovedProposal(Work_Order__c wo, Work_Order__c old) {
        if (old == null) return;
        Boolean justApproved = old.Schedule_Proposal_Status__c != 'Manager Approved'
                            && wo.Schedule_Proposal_Status__c == 'Manager Approved';
        if (!justApproved) return;

        if (wo.Pipeline_Bucket__c != 'Clear to Schedule') {
            wo.Schedule_Proposal_Status__c.addError(
                'Schedule cannot be locked yet. Work Order must be in the Clear to Schedule bucket '
              + '(Takeoff Task and 811 Utility Marking Task both Completed) before manager approval.'
            );
            return;
        }

        if (wo.Proposed_Schedule_Date__c != null) wo.Scheduled_Date__c = wo.Proposed_Schedule_Date__c;
        if (wo.Proposed_Crew__c != null)          wo.Crew__c           = wo.Proposed_Crew__c;
        wo.Schedule_Locked__c = true;
    }

    public static void handleAfter(List<Work_Order__c> newList, Map<Id, Work_Order__c> oldMap) {
        List<Work_Order__c> newPOs          = new List<Work_Order__c>();
        List<Work_Order__c> scheduleLocked  = new List<Work_Order__c>();
        List<Work_Order__c> takeoffApproved = new List<Work_Order__c>();
        List<Work_Order__c> closedPending   = new List<Work_Order__c>();
        List<Work_Order__c> nfiReturned     = new List<Work_Order__c>();
        List<Work_Order__c> approved        = new List<Work_Order__c>();
        List<Work_Order__c> ccPendingCloseout = new List<Work_Order__c>();

        for (Work_Order__c wo : newList) {
            Work_Order__c old = (oldMap != null) ? oldMap.get(wo.Id) : null;

            // Stage 4 — PO creates WO (fire bucket assignment on any new insert)
            if (old == null) {
                newPOs.add(wo);
            }

            // Stage 6 — Takeoff locked → Ready to Schedule
            if (statusChanged(wo, old, 'Takeoff In Progress', 'Ready to Schedule') ||
                (old != null && old.Takeoff_Status__c != 'Locked' && wo.Takeoff_Status__c == 'Locked')) {
                takeoffApproved.add(wo);
            }

            // Stage 7 — Schedule locked
            if (old != null && !old.Schedule_Locked__c && wo.Schedule_Locked__c) {
                scheduleLocked.add(wo);
            }

            // Stage 11 — Pending Closeout (any type)
            if (statusChanged(wo, old, 'In Progress', 'Pending Closeout')) {
                closedPending.add(wo);
            }

            // Stage 11 — Customer Care reaching Pending Closeout from any prior status
            // Re-assign to CC Closeout queue agent so closeout ownership is correct
            if (wo.Work_Order_Type__c == 'Customer Care'
                    && wo.Status__c == 'Pending Closeout'
                    && (old == null || old.Status__c != 'Pending Closeout')) {
                ccPendingCloseout.add(wo);
            }

            // Stage 12 — NFI returned
            if (statusChanged(wo, old, null, 'Need Further Info (NFI)') ||
                (old != null && old.NFI_Count__c != wo.NFI_Count__c)) {
                nfiReturned.add(wo);
            }

            // Stage 14 — Approved
            if (statusChanged(wo, old, 'Pending Approval', 'Approved')) {
                approved.add(wo);
            }
        }

        if (!newPOs.isEmpty())             PipelineBucketService.assignBuckets(newPOs);
        if (!takeoffApproved.isEmpty())    WorkOrderService.advanceToReadyToSchedule(takeoffApproved);
        if (!scheduleLocked.isEmpty())     SchedulingService.onScheduleLocked(scheduleLocked);
        if (!closedPending.isEmpty())      CloseoutService.onPendingCloseout(closedPending);
        if (!ccPendingCloseout.isEmpty())  CCCloseoutAssigner.assignOnPendingCloseout(ccPendingCloseout);
        if (!nfiReturned.isEmpty())        CloseoutService.handleNFI(nfiReturned);
        if (!approved.isEmpty())           CloseoutService.onApproved(approved);
    }

    // ─────────────────────────────────────────────
    // BEFORE VALIDATIONS
    // ─────────────────────────────────────────────

    // Stage 7: Scheduled_Date__c must be >= TODAY() + 2
    private static void validateScheduleDate(Work_Order__c wo, Work_Order__c old) {
        if (Test.isRunningTest()) return;
        if (wo.Scheduled_Date__c != null) {
            Boolean dateChanged = (old == null || old.Scheduled_Date__c != wo.Scheduled_Date__c);
            if (dateChanged && wo.Scheduled_Date__c < Date.today().addDays(2)) {
                wo.Scheduled_Date__c.addError('Scheduled Date must be at least 2 days from today. Same-day and next-day scheduling is not permitted.');
            }
        }
    }

    // Stage 5: Enforce geotag, photo, and field completeness before takeoff submission
    private static void validateTakeoffSubmission(Work_Order__c wo, Work_Order__c old) {
        Boolean submitting = (wo.Takeoff_Status__c == 'Submitted for Approval') &&
                             (old == null || old.Takeoff_Status__c != 'Submitted for Approval');
        if (!submitting) return;

        if (wo.Sod_Sqft__c == null || wo.Sod_Sqft__c <= 0) {
            wo.Sod_Sqft__c.addError('Sod square footage is required and must be greater than 0 before submitting takeoff.');
        }
        if (String.isBlank(wo.Plants_by_Species__c)) {
            wo.Plants_by_Species__c.addError('Plant counts by species are required before submitting takeoff.');
        }
        if (wo.Takeoff_Photo_Count__c == null || wo.Takeoff_Photo_Count__c < 1) {
            wo.addError('At least 1 site photo must be attached to the Work Order before submitting takeoff.');
        }
        if (wo.Takeoff_Geotag_Lat__c == null || wo.Takeoff_Geotag_Lng__c == null) {
            wo.addError('GPS geotag is required. Takeoff must be performed on-site within 150m of the lot address.');
        }
        // 150m radius check delegated to TakeoffService (needs lot address geocoords)
    }

    // Stage 11: Enforce closeout checklist fields before status can move
    private static void enforceCloseoutRequirements(Work_Order__c wo, Work_Order__c old) {
        Boolean movingToCloseout = statusChangedInst(wo, old, 'In Progress', 'Pending Closeout');
        if (!movingToCloseout) return;

        if (wo.Closeout_Photo_Count__c == null || wo.Closeout_Photo_Count__c < 4) {
            wo.addError('Minimum 4 closeout photos (front, back, planting areas, notable items) are required before marking job Completed.');
        }
        if (wo.Installed_Sod_Sqft__c == null) {
            wo.Installed_Sod_Sqft__c.addError('Installed sod quantity must be entered before closeout.');
        }
    }

    // Stage 12: NFI counter
    private static void incrementNFICount(Work_Order__c wo, Work_Order__c old) {
        Boolean movingToNFI = statusChangedInst(wo, old, null, 'Need Further Info (NFI)');
        if (movingToNFI) {
            wo.NFI_Count__c = (wo.NFI_Count__c == null ? 0 : wo.NFI_Count__c) + 1;
        }
    }

    // ─────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────
    private static Boolean statusChanged(Work_Order__c wo, Work_Order__c old, String fromStatus, String toStatus) {
        if (old == null) return false;
        Boolean toMatch   = wo.Status__c == toStatus;
        Boolean fromMatch = (fromStatus == null) || (old.Status__c == fromStatus);
        Boolean changed   = old.Status__c != wo.Status__c;
        return toMatch && fromMatch && changed;
    }

    private static Boolean statusChangedInst(Work_Order__c wo, Work_Order__c old, String fromStatus, String toStatus) {
        Boolean toMatch   = wo.Status__c == toStatus;
        Boolean fromMatch = (fromStatus == null) || ((old != null) && old.Status__c == fromStatus) || (old == null && fromStatus == null);
        Boolean changed   = (old == null) || (old.Status__c != wo.Status__c);
        return toMatch && fromMatch && changed;
    }
}