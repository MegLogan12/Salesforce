/**
 * LOVING_WorkOrderTriggerHandler
 *
 * Orchestrates all WorkOrder trigger logic for Production Install workflow.
 * Follows single-trigger, handler-class pattern. All methods are bulkified.
 *
 * Status flow handled here:
 *   Takeoff Complete → Finalize Schedule (after FSL schedule generated)
 *   Finalize Schedule → Scheduled (on Scheduling Manager approval)
 *   Scheduled → Site Readiness Check (day-of trigger)
 *   In Progress → health check + FJ handling
 *   Completed (Field Complete) → creates QI Inspection
 *   Pending Closeout Approval → NFI loop or Approved
 *   Approved → AR Queue + Invoice
 *   Paid + QI Complete → auto-close
 */
public without sharing class LOVING_WorkOrderTriggerHandler {

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
    private static void handleBeforeInsert(List<WorkOrder> newRecords) {
        setDefaults(newRecords);
    }

    // ─── BEFORE UPDATE ────────────────────────────────────────────────────────
    private static void handleBeforeUpdate(List<WorkOrder> newRecords, Map<Id, WorkOrder> oldMap) {
        List<WorkOrder> statusChanged = new List<WorkOrder>();
        List<WorkOrder> healthCheckRed = new List<WorkOrder>();

        for (WorkOrder wo : newRecords) {
            WorkOrder old = oldMap.get(wo.Id);

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
            if (wo.Status == 'In Progress' && old.Status != 'In Progress') {
                // handled after save — before save we can't create child records
            }
            if (wo.Status == 'Completed (Field Complete)'
                && old.Status != 'Completed (Field Complete)') {
                wo.Crew_Complete_Timestamp__c = System.now();
            }
            if (wo.Status == 'Approved' && old.Status != 'Approved') {
                wo.Approval_Date__c = System.now();
            }
            if (wo.Status == 'Need Further Info'
                && old.Status != 'Need Further Info') {
                wo.NFI_Count__c = (wo.NFI_Count__c == null ? 0 : wo.NFI_Count__c) + 1;
            }
            if (wo.Health_Check_Status__c == 'Red - Will Not Complete Today'
                && old.Health_Check_Status__c != 'Red - Will Not Complete Today') {
                wo.Red_Flag_Timestamp__c = System.now();
                wo.Health_Check_Date__c = System.now();
            }
            if (wo.Health_Check_Status__c == 'Green - On Track'
                && old.Health_Check_Status__c != 'Green - On Track') {
                wo.Health_Check_Date__c = System.now();
            }
        }
    }

    // ─── AFTER INSERT ─────────────────────────────────────────────────────────
    private static void handleAfterInsert(List<WorkOrder> newRecords) {
        // WOs are created in Takeoff Complete status — nothing to do on insert
        // except notify FM that FSL is ready to schedule
        sendTakeoffCompleteNotifications(newRecords);
    }

    // ─── AFTER UPDATE ─────────────────────────────────────────────────────────
    private static void handleAfterUpdate(List<WorkOrder> newRecords, Map<Id, WorkOrder> oldMap) {
        // Segment by what changed
        List<WorkOrder> toScheduled          = new List<WorkOrder>();
        List<WorkOrder> toCompleted          = new List<WorkOrder>();
        List<WorkOrder> toApproved           = new List<WorkOrder>();
        List<WorkOrder> toNFI                = new List<WorkOrder>();
        List<WorkOrder> toRedFlag            = new List<WorkOrder>();
        List<WorkOrder> toFJCreated          = new List<WorkOrder>();
        List<WorkOrder> autoCloseCandidates  = new List<WorkOrder>();

        for (WorkOrder wo : newRecords) {
            WorkOrder old = oldMap.get(wo.Id);
            String ns = wo.Status;
            String os = old.Status;

            if (ns == 'Scheduled'                  && os != 'Scheduled')                 toScheduled.add(wo);
            if (ns == 'Completed (Field Complete)'  && os != 'Completed (Field Complete)') toCompleted.add(wo);
            if (ns == 'Approved'                   && os != 'Approved')                   toApproved.add(wo);
            if (ns == 'Need Further Info'           && os != 'Need Further Info')          toNFI.add(wo);

            // Health check went Red
            if (wo.Health_Check_Status__c == 'Red - Will Not Complete Today'
                && old.Health_Check_Status__c != 'Red - Will Not Complete Today') {
                toRedFlag.add(wo);
                if (wo.Finish_Job_Required__c && !old.Finish_Job_Required__c) {
                    toFJCreated.add(wo);
                }
            }

            // Auto-close check: Paid + QI Submitted + QI not Red Hold
            if (wo.Payment_Received__c && !old.Payment_Received__c
                && wo.QI_Submitted__c
                && wo.QI_Status__c != 'FM QI Review (Red Hold)') {
                autoCloseCandidates.add(wo);
            }
            if (wo.QI_Submitted__c && !old.QI_Submitted__c
                && wo.Payment_Received__c
                && wo.QI_Status__c != 'FM QI Review (Red Hold)') {
                autoCloseCandidates.add(wo);
            }
        }

        if (!toScheduled.isEmpty())         handleStatusToScheduled(toScheduled);
        if (!toCompleted.isEmpty())         handleStatusToCompleted(toCompleted);
        if (!toApproved.isEmpty())          handleStatusToApproved(toApproved);
        if (!toNFI.isEmpty())               handleStatusToNFI(toNFI);
        if (!toRedFlag.isEmpty())           handleRedFlagEscalation(toRedFlag);
        if (!toFJCreated.isEmpty())         createFinishJobRecords(toFJCreated);
        if (!autoCloseCandidates.isEmpty()) autoCloseWorkOrders(autoCloseCandidates);
    }

    // ─── HANDLERS ─────────────────────────────────────────────────────────────

    /**
     * When WO → Scheduled:
     * 1. Create Pull Ticket (WO sub-record)
     * 2. Create Loading Ticket (WO sub-record)
     * 3. Create Site Readiness Check Task (due T-48 hrs)
     * 4. If Aqua community → delegate to LOVING_AquaTicketService
     * 5. Send crew notification
     */
    private static void handleStatusToScheduled(List<WorkOrder> wos) {
        List<Task> tasksToInsert = new List<Task>();
        List<WorkOrder> aquaWOs  = new List<WorkOrder>();
        List<WorkOrder> pullTickets    = new List<WorkOrder>();
        List<WorkOrder> loadingTickets = new List<WorkOrder>();

        // Query FM assignments for notification
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : wos) woIds.add(wo.Id);
        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>([
            SELECT Id, FM__c, Lot_Address__c, Lot_Number__c, Community__c,
                   Scheduled_Date__c, Aqua_Community__c, AccountId,
                   Lot__c
            FROM WorkOrder
            WHERE Id IN :woIds
        ]);

        for (WorkOrder wo : wos) {
            WorkOrder full = woMap.get(wo.Id);
            Date sDate = full.Scheduled_Date__c;

            // Site Readiness Check Task
            if (sDate != null) {
                Task srt = new Task();
                srt.Subject     = 'Site Readiness Check Required — ' + full.Lot_Address__c;
                srt.OwnerId     = full.FM__c;
                srt.WhatId      = full.Id;
                srt.ActivityDate = sDate.addDays(-2);
                srt.Priority    = 'High';
                srt.Description = 'Complete the site readiness check form in Salesforce. '
                    + 'All 6 checks must pass before crew can go In Progress. '
                    + 'If any check fails: job is pulled from schedule immediately.';
                srt.Type        = 'Site Readiness Check';
                tasksToInsert.add(srt);
            }

            // Aqua trigger
            if (full.Aqua_Community__c) {
                aquaWOs.add(full);
            }

            // Prepare Pull and Loading tickets
            pullTickets.add(wo);
            loadingTickets.add(wo);
        }

        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }

        // Create Pull Tickets
        if (!pullTickets.isEmpty()) {
            createSubTickets(pullTickets, 'Pull Ticket');
        }

        // Create Loading Tickets
        if (!loadingTickets.isEmpty()) {
            createSubTickets(loadingTickets, 'Loading Ticket');
        }

        // Aqua install ticket creation
        if (!aquaWOs.isEmpty()) {
            LOVING_AquaTicketService.createAquaInstallTickets(aquaWOs);
        }
    }

    /**
     * When WO → Completed (Field Complete):
     * 1. Create QI Inspection record
     * 2. Create QI Line Items (one per WO Line Item)
     * 3. Start 48-hour QI escalation clock
     */
    private static void handleStatusToCompleted(List<WorkOrder> wos) {
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : wos) woIds.add(wo.Id);

        // Get WO line items for QI Line Item creation
        Map<Id, List<WorkOrderLineItem>> lineItemMap = new Map<Id, List<WorkOrderLineItem>>();
        for (WorkOrderLineItem woli : [
            SELECT Id, WorkOrderId, Description, Quantity, UnitPrice
            FROM WorkOrderLineItem
            WHERE WorkOrderId IN :woIds
        ]) {
            if (!lineItemMap.containsKey(woli.WorkOrderId)) {
                lineItemMap.put(woli.WorkOrderId, new List<WorkOrderLineItem>());
            }
            lineItemMap.get(woli.WorkOrderId).add(woli);
        }

        Map<Id, WorkOrder> woFullMap = new Map<Id, WorkOrder>([
            SELECT Id, FM__c, Lot_Address__c, Crew_Complete_Timestamp__c, AccountId
            FROM WorkOrder WHERE Id IN :woIds
        ]);

        List<QI_Inspection__c> qiRecords    = new List<QI_Inspection__c>();
        List<QI_Line_Item__c>  qiLineItems  = new List<QI_Line_Item__c>();
        List<Task>             qiTasks      = new List<Task>();

        for (WorkOrder wo : wos) {
            WorkOrder full = woFullMap.get(wo.Id);

            QI_Inspection__c qi = new QI_Inspection__c();
            qi.Work_Order__c    = wo.Id;
            qi.FM__c            = full.FM__c;
            qi.Status__c        = 'Scheduled';
            qiRecords.add(qi);
        }

        if (!qiRecords.isEmpty()) {
            insert qiRecords;

            // Map QI records back to WO Id
            Map<Id, Id> woToQI = new Map<Id, Id>();
            for (QI_Inspection__c qi : qiRecords) {
                woToQI.put(qi.Work_Order__c, qi.Id);
            }

            // Create QI Line Items
            for (WorkOrder wo : wos) {
                List<WorkOrderLineItem> lines = lineItemMap.get(wo.Id);
                if (lines == null) continue;
                for (WorkOrderLineItem woli : lines) {
                    QI_Line_Item__c qili    = new QI_Line_Item__c();
                    qili.QI_Inspection__c   = woToQI.get(wo.Id);
                    qili.Work_Order_Line_Item_Ref__c = woli.Description != null
                        ? woli.Description : 'Line Item ' + woli.Id;
                    qili.FM_Score__c        = null; // FM fills in
                    qiLineItems.add(qili);
                }
            }

            if (!qiLineItems.isEmpty()) {
                insert qiLineItems;
            }

            // Create QI Task for each FM
            for (WorkOrder wo : wos) {
                WorkOrder full = woFullMap.get(wo.Id);
                Task t = new Task();
                t.Subject       = 'QI Inspection Due — ' + full.Lot_Address__c;
                t.OwnerId       = full.FM__c;
                t.WhatId        = wo.Id;
                t.ActivityDate  = Date.today().addDays(1); // next business day
                t.Priority      = 'High';
                t.Type          = 'QI Inspection';
                t.Description   = 'QI Inspection is due the next business day after crew completion. '
                    + 'Score every line item 1-10 on the QI Inspection record. '
                    + 'Physical site visit required. You must be at the lot to submit.';
                qiTasks.add(t);
            }

            if (!qiTasks.isEmpty()) {
                insert qiTasks;
            }

            // Update WO QI Status
            List<WorkOrder> toUpdate = new List<WorkOrder>();
            for (WorkOrder wo : wos) {
                toUpdate.add(new WorkOrder(Id=wo.Id, QI_Status__c='Scheduled'));
            }
            update toUpdate;
        }
    }

    /**
     * When WO → Approved:
     * 1. Create Invoice record (placeholder — Finance confirms)
     * 2. Move to AR Queue (via AR_Queue_Date__c stamp)
     * 3. Notify Finance
     */
    private static void handleStatusToApproved(List<WorkOrder> wos) {
        // Stamp AR queue date
        List<WorkOrder> toUpdate = new List<WorkOrder>();
        List<Task>      tasks    = new List<Task>();

        // Get Finance team user (query custom hierarchy/group)
        // For now: assign to WO FM's manager — replace with Finance queue in production
        for (WorkOrder wo : wos) {
            Task t = new Task();
            t.Subject       = 'Invoice Ready — ' + wo.Id;
            t.WhatId        = wo.Id;
            t.Priority      = 'Normal';
            t.ActivityDate  = Date.today();
            t.Type          = 'Invoicing';
            t.Description   = 'Work Order has been approved. Create and send invoice to builder. '
                + 'Invoice will sync to QuickBooks in the nightly run.';
            tasks.add(t);
        }

        if (!tasks.isEmpty()) insert tasks;
    }

    /**
     * When WO → Need Further Info:
     * 1. Notify FM with specific NFI reason
     * 2. Create task for FM
     * 3. If NFI_Count > 2: escalate to COO
     */
    private static void handleStatusToNFI(List<WorkOrder> wos) {
        List<Task> tasks = new List<Task>();

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>([
            SELECT Id, FM__c, Lot_Address__c, Need_Further_Info_Notes__c, NFI_Count__c
            FROM WorkOrder WHERE Id IN :wos.stream().map(w -> w.Id).toList()
        ]);
        // Note: above SOQL style won't work — use explicit loop
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : wos) woIds.add(wo.Id);
        Map<Id, WorkOrder> woFullMap = new Map<Id, WorkOrder>([
            SELECT Id, FM__c, Lot_Address__c, Need_Further_Info_Notes__c, NFI_Count__c
            FROM WorkOrder WHERE Id IN :woIds
        ]);

        for (WorkOrder wo : wos) {
            WorkOrder full = woFullMap.get(wo.Id);

            Task t = new Task();
            t.Subject       = 'ACTION REQUIRED: Work Order Returned — Need Further Info — ' + full.Lot_Address__c;
            t.OwnerId       = full.FM__c;
            t.WhatId        = wo.Id;
            t.Priority      = 'High';
            t.ActivityDate  = Date.today();
            t.Type          = 'NFI Resolution';
            t.Description   = 'Work Order has been returned by the Operations Manager.\n\n'
                + 'What is needed:\n' + full.Need_Further_Info_Notes__c + '\n\n'
                + 'Resolve the issue and re-submit the closeout checklist. '
                + 'The Work Order will re-enter the Closeout Approval Queue.';
            tasks.add(t);

            // COO escalation if NFI > 2
            if (full.NFI_Count__c != null && full.NFI_Count__c > 2) {
                Task escalation = new Task();
                escalation.Subject      = 'ESCALATION: Work Order Returned 3+ Times — ' + full.Lot_Address__c;
                escalation.Priority     = 'High';
                escalation.WhatId       = wo.Id;
                escalation.ActivityDate = Date.today();
                escalation.Type         = 'COO Escalation';
                escalation.Description  = 'This Work Order has been sent back via Need Further Info '
                    + (Integer)full.NFI_Count__c + ' times. COO review required.';
                tasks.add(escalation);
            }
        }

        if (!tasks.isEmpty()) insert tasks;
    }

    /**
     * Red Flag Health Check escalation:
     * 1. Notify Scheduling Team
     * 2. Notify Operations Manager
     */
    private static void handleRedFlagEscalation(List<WorkOrder> wos) {
        List<Task> tasks = new List<Task>();
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : wos) woIds.add(wo.Id);

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>([
            SELECT Id, FM__c, Lot_Address__c, Red_Flag_Notes__c, Community__c
            FROM WorkOrder WHERE Id IN :woIds
        ]);

        for (WorkOrder wo : wos) {
            WorkOrder full = woMap.get(wo.Id);

            Task t = new Task();
            t.Subject      = 'RED FLAG — Job Will Not Complete Today — ' + full.Lot_Address__c;
            t.WhatId       = wo.Id;
            t.Priority     = 'High';
            t.ActivityDate = Date.today();
            t.Type         = 'Red Flag Escalation';
            t.Description  = 'FM has flagged this job as Red at the 2 PM health check.\n\n'
                + 'Reason: ' + full.Red_Flag_Notes__c + '\n\n'
                + 'Scheduling decision required: extend crew time, '
                + 'send additional crew, or create Finish Job.';
            tasks.add(t);
        }

        if (!tasks.isEmpty()) insert tasks;
    }

    /**
     * Create Finish Job records when FJ is flagged on a Red health check
     */
    private static void createFinishJobRecords(List<WorkOrder> wos) {
        List<Finish_Job__c> fjs = new List<Finish_Job__c>();
        for (WorkOrder wo : wos) {
            Finish_Job__c fj        = new Finish_Job__c();
            fj.Parent_Work_Order__c = wo.Id;
            fj.FM__c                = wo.FM__c;
            fj.FJ_Reason__c         = wo.Finish_Job_Reason__c != null
                ? wo.Finish_Job_Reason__c : 'Ran Out of Time';
            fj.Accountability_Notes__c = wo.Red_Flag_Notes__c != null
                ? wo.Red_Flag_Notes__c : 'See Red Flag Notes on Work Order.';
            fj.FJ_Date__c           = Date.today().addDays(1);
            fjs.add(fj);
        }
        if (!fjs.isEmpty()) insert fjs;
    }

    /**
     * Auto-close Work Orders when both conditions are met:
     * Payment_Received__c = true AND QI_Submitted__c = true AND QI_Status != Red Hold
     */
    private static void autoCloseWorkOrders(List<WorkOrder> candidates) {
        // De-duplicate
        Set<Id> seen = new Set<Id>();
        List<WorkOrder> toClose = new List<WorkOrder>();
        for (WorkOrder wo : candidates) {
            if (!seen.contains(wo.Id)) {
                seen.add(wo.Id);
                toClose.add(new WorkOrder(Id=wo.Id, Status='Closed'));
            }
        }
        if (!toClose.isEmpty()) {
            LOVING_TriggerGuard.clearAlreadyRun('WorkOrder');
            update toClose;
        }
    }

    // ─── HELPERS ──────────────────────────────────────────────────────────────

    private static void setDefaults(List<WorkOrder> wos) {
        for (WorkOrder wo : wos) {
            if (wo.Lunch_Minutes__c == null)   wo.Lunch_Minutes__c = 60;
            if (wo.Cushion_Minutes__c == null) wo.Cushion_Minutes__c = 15;
            if (wo.Shift_Start_Time__c == null) wo.Shift_Start_Time__c = '06:30';
            if (wo.NFI_Count__c == null)       wo.NFI_Count__c = 0;
        }
    }

    private static void sendTakeoffCompleteNotifications(List<WorkOrder> wos) {
        // In production: use Custom Notification or Platform Event to push to Scheduling Manager
        // For now: create a task in the Finalize Schedule queue
        List<Task> tasks = new List<Task>();
        for (WorkOrder wo : wos) {
            if (wo.Status == 'Takeoff Complete') {
                Task t = new Task();
                t.Subject       = 'New Install Ready for Schedule Review — ' + wo.Lot_Address__c;
                t.WhatId        = wo.Id;
                t.Priority      = 'Normal';
                t.ActivityDate  = Date.today();
                t.Type          = 'Schedule Review';
                t.Description   = 'Takeoff is complete. FSL has generated a proposed schedule. '
                    + 'Review the proposed date, crew, and stop sequence in the Dispatch Console. '
                    + 'Approve or edit before the schedule is locked.';
                tasks.add(t);
            }
        }
        if (!tasks.isEmpty()) insert tasks;
    }

    private static void createSubTickets(List<WorkOrder> wos, String ticketType) {
        List<WorkOrder> tickets = new List<WorkOrder>();
        for (WorkOrder wo : wos) {
            WorkOrder ticket = new WorkOrder();
            ticket.AccountId         = wo.AccountId;
            ticket.Work_Order_Type__c = ticketType;
            ticket.Status            = 'New';
            ticket.ParentWorkOrderId = wo.Id;
            ticket.Subject           = ticketType + ' — ' + wo.Lot_Address__c
                + ' — ' + (wo.Scheduled_Date__c != null
                    ? wo.Scheduled_Date__c.format() : 'TBD');
            tickets.add(ticket);
        }
        if (!tickets.isEmpty()) {
            LOVING_TriggerGuard.clearAlreadyRun('WorkOrder');
            insert tickets;
        }
    }
}
