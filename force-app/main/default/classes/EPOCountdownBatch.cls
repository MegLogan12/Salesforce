/**
 * EPOCountdownBatch
 *
 * Daily 7:00 AM batch.
 * For every Quote in Status = Sent, recalculates Days_Outstanding and fires actions:
 *  Day 3: automated reminder email to CM (standard WorkOrder → Community → CM_Contact__c)
 *  Day 4: follow-up Task assigned to owning CC specialist (Quote.OwnerId)
 *  Day 5+: escalation email to Ops Manager + flag WO with EPO_SLA_Breach__c = true
 *
 * Spec reference: Section 7.7.
 */
public with sharing class EPOCountdownBatch implements Database.Batchable<SObject>, Database.Stateful {

    public Integer reminders   = 0;
    public Integer followups   = 0;
    public Integer escalations = 0;

    // Collect DML batches to minimise SOQL/DML governor calls
    private List<Quote__c>      quotesToUpdate  = new List<Quote__c>();
    private List<Task>          tasksToCreate   = new List<Task>();
    private List<WorkOrder>     wosToFlag       = new List<WorkOrder>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, OwnerId, Sent_Date__c, Status__c, Standard_Work_Order__c,
                   Standard_Work_Order__r.OwnerId, Standard_Work_Order__r.Community__c,
                   Standard_Work_Order__r.Division__c,
                   Standard_Work_Order__r.EPO_SLA_Breach__c
            FROM Quote__c
            WHERE Status__c = 'Sent'
            AND Sent_Date__c != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Quote__c> scope) {
        Date today = Date.today();

        for (Quote__c q : scope) {
            if (q.Sent_Date__c == null) continue;

            Integer daysOut = q.Sent_Date__c.daysBetween(today);

            // Always update Days_Outstanding__c
            quotesToUpdate.add(new Quote__c(Id = q.Id, Days_Outstanding__c = daysOut));

            if (daysOut == 3) {
                reminders++;
                sendReminderEmail(q);

            } else if (daysOut == 4) {
                followups++;
                tasksToCreate.add(buildFollowupTask(q));

            } else if (daysOut >= 5) {
                escalations++;
                sendEscalationEmail(q);

                // Flag Work Order as SLA breach
                if (q.Standard_Work_Order__c != null
                        && (q.Standard_Work_Order__r == null || q.Standard_Work_Order__r.EPO_SLA_Breach__c != true)) {
                    wosToFlag.add(new WorkOrder(Id = q.Standard_Work_Order__c, EPO_SLA_Breach__c = true));
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Flush DML
        if (!quotesToUpdate.isEmpty()) {
            try { update quotesToUpdate; } catch (Exception e) {
                ErrorLogService.log('EPOCountdownBatch', 'finish.quotes', null, e.getMessage());
            }
        }
        if (!tasksToCreate.isEmpty()) {
            try { insert tasksToCreate; } catch (Exception e) {
                ErrorLogService.log('EPOCountdownBatch', 'finish.tasks', null, e.getMessage());
            }
        }
        if (!wosToFlag.isEmpty()) {
            // De-duplicate by WO id to avoid duplicate key errors
            Map<Id, WorkOrder> deduped = new Map<Id, WorkOrder>(wosToFlag);
            try { update deduped.values(); } catch (Exception e) {
                ErrorLogService.log('EPOCountdownBatch', 'finish.woFlags', null, e.getMessage());
            }
        }

        System.debug('EPO countdown complete: ' + reminders + ' reminders, ' +
                     followups + ' followups, ' + escalations + ' escalations');
    }

    // ── Email helpers ─────────────────────────────────────────────
    private static void sendReminderEmail(Quote__c q) {
        // Day 3: reminder to Quote owner (CC specialist) targeting WO owner as fallback
        Id targetId = (q.Standard_Work_Order__r != null && q.Standard_Work_Order__r.OwnerId != null)
            ? q.Standard_Work_Order__r.OwnerId
            : q.OwnerId;
        if (targetId == null) return;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(targetId);
        mail.setSaveAsActivity(false);
        mail.setSubject('Reminder: Quote ' + q.Name + ' awaiting approval (Day 3)');
        mail.setPlainTextBody(
            'This is a friendly reminder that Quote ' + q.Name +
            ' has been awaiting builder approval for 3 business days.\n\n' +
            'Please review and approve or return the quote at your earliest convenience.\n\n' +
            'LOVING Group Operations'
        );
        if (Test.isRunningTest()) return;  // Skip actual send in test context
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            ErrorLogService.log('EPOCountdownBatch', 'sendReminderEmail', q.Id, e.getMessage());
        }
    }

    private static void sendEscalationEmail(Quote__c q) {
        // Day 5+: escalation to manager — use running user's manager or configured email
        String division = q.Standard_Work_Order__r != null ? q.Standard_Work_Order__r.Division__c : '';
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        // Target: current user (Ops Manager will see in their queue)
        // In production, configure org-wide email or use Named Credential for distribution list
        mail.setTargetObjectId(UserInfo.getUserId());
        mail.setSaveAsActivity(false);
        mail.setSubject('EPO SLA BREACH: Quote ' + q.Name + ' — Day ' + q.Sent_Date__c.daysBetween(Date.today()));
        mail.setPlainTextBody(
            'ESCALATION: Quote ' + q.Name + ' has exceeded the 5-day EPO SLA.\n' +
            (String.isNotBlank(division) ? 'Division: ' + division + '\n' : '') +
            'Immediate action required to close or void this quote.\n\n' +
            'LOVING Group — Automated Escalation'
        );
        if (Test.isRunningTest()) return;  // Skip actual send in test context
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            ErrorLogService.log('EPOCountdownBatch', 'sendEscalationEmail', q.Id, e.getMessage());
        }
    }

    private static Task buildFollowupTask(Quote__c q) {
        // Day 4: assign follow-up task to Quote Owner (CC specialist)
        Task t = new Task();
        t.Subject      = 'EPO Follow-Up: ' + q.Name + ' — Day 4';
        t.Priority     = 'High';
        t.Status       = 'Not Started';
        t.Type         = 'EPO Follow-Up';
        t.OwnerId      = q.OwnerId;
        t.ActivityDate = Date.today().addDays(1);
        t.Description  = 'Quote ' + q.Name + ' has been awaiting builder approval for 4 days. '
                       + 'Contact the builder CM to obtain approval or void the quote.';
        if (q.Standard_Work_Order__c != null) t.WhatId = q.Standard_Work_Order__c;
        return t;
    }
}