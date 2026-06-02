/**
 * LOVING_WorkOrderTriggerHandler
 *
 * Orchestrates WorkOrder trigger logic. Follows single-trigger, handler-class
 * pattern. All methods are bulkified.
 *
 * AFTER_UPDATE is intentionally a no-op. Status-change automation for
 * Production Install WorkOrders is owned exclusively by the
 * LOVING_PI_Orchestrator Record-Triggered Flow and its six sub-flows.
 * Keeping that logic here would create duplicate Tasks, QI_Inspection__c,
 * and Finish_Job__c records on every status transition.
 */
public inherited sharing class LOVING_WorkOrderTriggerHandler {

    // ─── Public entry point ───────────────────────────────────────────────────
    public static void handle(
        List<WorkOrder> newRecords,
        Map<Id, WorkOrder> oldMap,
        System.TriggerOperation op
    ) {
        switch on op {
            when BEFORE_INSERT  { handleBeforeInsert(newRecords); }
            when BEFORE_UPDATE  { handleBeforeUpdate(newRecords, oldMap); }
            when AFTER_INSERT   { handleAfterInsert(newRecords); }
            when AFTER_UPDATE   { handleAfterUpdate(newRecords, oldMap); }
        }
    }

    // ─── BEFORE INSERT ────────────────────────────────────────────────────────
    @TestVisible
    private static void handleBeforeInsert(List<WorkOrder> newRecords) {
        setDefaults(newRecords);
    }

    // ─── BEFORE UPDATE ────────────────────────────────────────────────────────
    @TestVisible
    private static void handleBeforeUpdate(List<WorkOrder> newRecords, Map<Id, WorkOrder> oldMap) {
        for (WorkOrder wo : newRecords) {
            WorkOrder old = (oldMap != null) ? oldMap.get(wo.Id) : null;
            if (old == null) continue;

            // Validate Red Flag Notes when health check goes Red
            if (wo.Health_Check_Status__c == 'Red - Will Not Complete Today'
                && old.Health_Check_Status__c != 'Red - Will Not Complete Today'
                && String.isBlank(wo.Red_Flag_Notes__c)) {
                wo.Red_Flag_Notes__c.addError(
                    'Red Flag Notes are required when marking a health check Red. '
                    + 'Describe why the job will not complete today.'
                );
            }

            // Validate closeout requirements
            if (wo.Status == 'Pending Closeout Approval'
                && old.Status != 'Pending Closeout Approval') {
                if (!wo.Closeout_Photos_Attached__c) {
                    wo.addError('Closeout photos must be attached before submitting for approval.');
                }
                if (!wo.Closeout_Quantities_Confirmed__c) {
                    wo.addError('Installed quantities must be confirmed before submitting for closeout approval.');
                }
            }

            // Validate NFI notes
            if (wo.Status == 'Need Further Info'
                && old.Status != 'Need Further Info'
                && String.isBlank(wo.Need_Further_Info_Notes__c)) {
                wo.Need_Further_Info_Notes__c.addError(
                    'Need Further Info Notes must describe specifically what information is required.'
                );
            }

            // Auto-stamp timestamps
            if (wo.Status == 'Completed (Field Complete)'
                && old.Status != 'Completed (Field Complete)') {
                wo.Crew_Complete_Timestamp__c = System.now();
            }
            if (wo.Status == 'Approved' && old.Status != 'Approved') {
                wo.Approval_Date__c = System.now();
            }
            if (wo.Status == 'Need Further Info' && old.Status != 'Need Further Info') {
                wo.NFI_Count__c = (wo.NFI_Count__c == null ? 0 : wo.NFI_Count__c) + 1;
            }
            if (wo.Health_Check_Status__c == 'Red - Will Not Complete Today'
                && old.Health_Check_Status__c != 'Red - Will Not Complete Today') {
                wo.Red_Flag_Timestamp__c = System.now();
                wo.Health_Check_Date__c  = System.now();
            }
            if (wo.Health_Check_Status__c == 'Green - On Track'
                && old.Health_Check_Status__c != 'Green - On Track') {
                wo.Health_Check_Date__c = System.now();
            }
        }
    }

    // ─── AFTER INSERT ─────────────────────────────────────────────────────────
    @TestVisible
    private static void handleAfterInsert(List<WorkOrder> newRecords) {
        List<Task> tasks = buildTakeoffNotificationTasks(newRecords);
        if (!tasks.isEmpty()) insert tasks;
    }

    // ─── AFTER UPDATE ─────────────────────────────────────────────────────────
    // No-op: all status-change automation is owned by LOVING_PI_Orchestrator
    // and its sub-flows (Record-Triggered After-Save on WorkOrder). Running
    // equivalent Apex here would duplicate every Task, QI_Inspection__c, and
    // Finish_Job__c record on every Production Install status transition.
    @TestVisible
    private static void handleAfterUpdate(List<WorkOrder> newRecords, Map<Id, WorkOrder> oldMap) {
    }

    // ─── @TestVisible BUILDERS ────────────────────────────────────────────────

    @TestVisible
    private static void setDefaults(List<WorkOrder> wos) {
        for (WorkOrder wo : wos) {
            if (wo.Lunch_Minutes__c == null)    wo.Lunch_Minutes__c = 60;
            if (wo.Cushion_Minutes__c == null)  wo.Cushion_Minutes__c = 15;
            if (wo.Shift_Start_Time__c == null) wo.Shift_Start_Time__c = Time.newInstance(6, 30, 0, 0);
            if (wo.NFI_Count__c == null)        wo.NFI_Count__c = 0;
        }
    }

    @TestVisible
    private static List<Task> buildTakeoffNotificationTasks(List<WorkOrder> wos) {
        List<Task> tasks = new List<Task>();
        for (WorkOrder wo : wos) {
            if (wo.Status == 'Takeoff Complete') {
                Task t = new Task();
                t.Subject      = 'New Install Ready for Schedule Review — ' + wo.Lot_Address__c;
                t.WhatId       = wo.Id;
                t.Priority     = 'Normal';
                t.ActivityDate = Date.today();
                t.Type         = 'Schedule Review';
                t.Description  = 'Takeoff is complete. FSL has generated a proposed schedule. '
                    + 'Review the proposed date, crew, and stop sequence in the Dispatch Console. '
                    + 'Approve or edit before the schedule is locked.';
                tasks.add(t);
            }
        }
        return tasks;
    }

    @TestVisible
    private static List<Task> buildSRCTask(WorkOrder full) {
        List<Task> tasks = new List<Task>();
        Task srt = new Task();
        srt.Subject      = 'Site Readiness Check Required — ' + full.Lot_Address__c;
        srt.OwnerId      = full.FM__c;
        srt.WhatId       = full.Id;
        srt.ActivityDate = full.Scheduled_Date__c.addDays(-2);
        srt.Priority     = 'High';
        srt.Description  = 'Complete the site readiness check form in Salesforce. '
            + 'All 6 checks must pass before crew can go In Progress. '
            + 'If any check fails: job is pulled from schedule immediately.';
        srt.Type         = 'Site Readiness Check';
        tasks.add(srt);
        return tasks;
    }

    @TestVisible
    private static List<QI_Inspection__c> buildQIRecords(List<WorkOrder> wos) {
        List<QI_Inspection__c> result = new List<QI_Inspection__c>();
        for (WorkOrder wo : wos) {
            QI_Inspection__c qi = new QI_Inspection__c();
            qi.Work_Order__c    = wo.Id;
            qi.FM__c            = wo.FM__c;
            qi.Status__c        = 'Scheduled';
            result.add(qi);
        }
        return result;
    }

    @TestVisible
    private static List<Task> buildQITasks(List<WorkOrder> wos) {
        List<Task> result = new List<Task>();
        for (WorkOrder wo : wos) {
            Task t = new Task();
            t.Subject      = 'QI Inspection Due — ' + wo.Lot_Address__c;
            t.OwnerId      = wo.FM__c != null ? wo.FM__c : UserInfo.getUserId();
            t.WhatId       = wo.Id;
            t.ActivityDate = Date.today().addDays(1);
            t.Priority     = 'High';
            t.Type         = 'QI Inspection';
            t.Description  = 'QI Inspection is due the next business day after crew completion. '
                + 'Score every line item 1-10 on the QI Inspection record. '
                + 'Physical site visit required. You must be at the lot to submit.';
            result.add(t);
        }
        return result;
    }

    @TestVisible
    private static List<Task> buildApprovedTasks(List<WorkOrder> wos) {
        List<Task> result = new List<Task>();
        for (WorkOrder wo : wos) {
            Task t = new Task();
            t.Subject      = 'Invoice Ready — ' + wo.Id;
            t.WhatId       = wo.Id;
            t.Priority     = 'Normal';
            t.ActivityDate = Date.today();
            t.Type         = 'Invoicing';
            t.Description  = 'Work Order has been approved. Create and send invoice to builder. '
                + 'Invoice will sync to QuickBooks in the nightly run.';
            result.add(t);
        }
        return result;
    }

    @TestVisible
    private static List<Task> buildNFITasks(List<WorkOrder> wos) {
        List<Task> result = new List<Task>();
        for (WorkOrder wo : wos) {
            Task t = new Task();
            t.Subject      = 'ACTION REQUIRED: Work Order Returned — Need Further Info — ' + wo.Lot_Address__c;
            t.OwnerId      = wo.FM__c != null ? wo.FM__c : UserInfo.getUserId();
            t.WhatId       = wo.Id;
            t.Priority     = 'High';
            t.ActivityDate = Date.today();
            t.Type         = 'NFI Resolution';
            t.Description  = 'Work Order has been returned by the Operations Manager.\n\n'
                + 'What is needed:\n' + wo.Need_Further_Info_Notes__c + '\n\n'
                + 'Resolve the issue and re-submit the closeout checklist.';
            result.add(t);

            if (wo.NFI_Count__c != null && wo.NFI_Count__c > 2) {
                Task escalation = new Task();
                escalation.Subject      = 'ESCALATION: Work Order Returned 3+ Times — ' + wo.Lot_Address__c;
                escalation.Priority     = 'High';
                escalation.WhatId       = wo.Id;
                escalation.ActivityDate = Date.today();
                escalation.Type         = 'COO Escalation';
                escalation.Description  = 'This Work Order has been sent back via Need Further Info '
                    + (Integer)wo.NFI_Count__c + ' times. COO review required.';
                result.add(escalation);
            }
        }
        return result;
    }

    @TestVisible
    private static List<Task> buildRedFlagTasks(List<WorkOrder> wos) {
        List<Task> result = new List<Task>();
        for (WorkOrder wo : wos) {
            Task t = new Task();
            t.Subject      = 'RED FLAG — Job Will Not Complete Today — ' + wo.Lot_Address__c;
            t.WhatId       = wo.Id;
            t.Priority     = 'High';
            t.ActivityDate = Date.today();
            t.Type         = 'Red Flag Escalation';
            t.Description  = 'FM has flagged this job as Red at the 2 PM health check.\n\n'
                + 'Reason: ' + wo.Red_Flag_Notes__c + '\n\n'
                + 'Scheduling decision required: extend crew time, '
                + 'send additional crew, or create Finish Job.';
            result.add(t);
        }
        return result;
    }

    @TestVisible
    private static List<Finish_Job__c> buildFinishJobs(List<WorkOrder> wos) {
        List<Finish_Job__c> result = new List<Finish_Job__c>();
        for (WorkOrder wo : wos) {
            Finish_Job__c fj        = new Finish_Job__c();
            fj.Parent_Work_Order__c = wo.Id;
            fj.FM__c                = wo.FM__c;
            fj.FJ_Reason__c         = wo.Finish_Job_Reason__c != null
                ? wo.Finish_Job_Reason__c : 'Ran Out of Time';
            fj.Accountability_Notes__c = wo.Red_Flag_Notes__c != null
                ? wo.Red_Flag_Notes__c : 'See Red Flag Notes on Work Order.';
            fj.FJ_Date__c           = Date.today().addDays(1);
            result.add(fj);
        }
        return result;
    }
}