/**
 * LOVING_TakeoffEscalationScheduler
 *
 * Runs daily at 9:00 AM weekdays. Escalates lot takeoff tasks that are more
 * than 48 hours overdue. Notifies FM manager and stamps Takeoff_Overdue__c = true.
 *
 * Schedule: '0 0 9 ? * MON-FRI *'
 * System.schedule('LOVING Takeoff Escalation 9AM',
 *     '0 0 9 ? * MON-FRI *', new LOVING_TakeoffEscalationScheduler());
 */
global without sharing class LOVING_TakeoffEscalationScheduler implements Schedulable {

    global void execute(SchedulableContext ctx) {
        escalateOverdueTakeoffs();
    }

    private static void escalateOverdueTakeoffs() {
        DateTime cutoff = System.now().addHours(-48);

        List<Account> overdueLots = [
            SELECT Id, Name, FM__c, FM__r.ManagerId,
                   Target_Start_Date__c, Bucket_Changed_Date__c
            FROM Account
            WHERE RecordType.DeveloperName = 'Lot'
            AND Pipeline_Bucket__c IN ('30 Days', 'Ready to Schedule')
            AND Takeoff_Task_Created__c = true
            AND Takeoff_Complete__c = false
            AND Bucket_Changed_Date__c < :cutoff
        ];

        if (overdueLots.isEmpty()) return;

        List<Task>    escalations = new List<Task>();
        List<Account> toFlag      = new List<Account>();

        for (Account lot : overdueLots) {
            Id ownerId = (lot.FM__r.ManagerId != null) ? lot.FM__r.ManagerId : lot.FM__c;

            Task t = new Task();
            t.Subject      = 'OVERDUE TAKEOFF — ' + lot.Name + ' — Target: '
                + (lot.Target_Start_Date__c != null ? lot.Target_Start_Date__c.format() : 'TBD');
            t.OwnerId      = ownerId;
            t.WhatId       = lot.Id;
            t.Priority     = 'High';
            t.ActivityDate = Date.today();
            t.Type         = 'Escalation';
            t.Description  = 'The site takeoff for this lot has not been completed within 48 hours. '
                + 'Target install date: '
                + (lot.Target_Start_Date__c != null ? lot.Target_Start_Date__c.format() : 'TBD') + '. '
                + 'Contact FM immediately.';
            escalations.add(t);

            toFlag.add(new Account(Id = lot.Id, Takeoff_Overdue__c = true));
        }

        if (!escalations.isEmpty()) insert escalations;
        if (!toFlag.isEmpty())      update toFlag;
    }
}
