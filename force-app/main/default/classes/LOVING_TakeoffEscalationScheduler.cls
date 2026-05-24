/**
 * LOVING_TakeoffEscalationScheduler
 *
 * Runs daily. Escalates takeoff tasks that are past the 48-hour deadline.
 * Schedule: '0 0 9 ? * MON-FRI *'
 *
 * Schedule via: System.schedule('LOVING Takeoff Escalation 9AM',
 *     '0 0 9 ? * MON-FRI *', new LOVING_TakeoffEscalationScheduler());
 *
 * Also invocable from the LOVING_Takeoff_Escalation scheduled Flow.
 */
global without sharing class LOVING_TakeoffEscalationScheduler implements Schedulable {

    global void execute(SchedulableContext ctx) {
        escalateOverdueTakeoffs();
    }

    /**
     * Invocable entry point — called by LOVING_Takeoff_Escalation Flow.
     */
    @InvocableMethod(label='Run Takeoff Escalation' description='Escalates overdue takeoff tasks past the 48-hour deadline.')
    public static void runEscalation(List<String> unused) {
        escalateOverdueTakeoffs();
    }

    public static void escalateOverdueTakeoffs() {
        DateTime cutoff = System.now().addHours(-48);

        // Find Lots in 30-day or Ready to Schedule bucket with overdue takeoffs
        List<Account> overdueLoots = [
            SELECT Id, Name, FM__c, FM__r.ManagerId,
                   Target_Start_Date__c, Bucket_Changed_Date__c
            FROM Account
            WHERE RecordType.DeveloperName = 'Lot'
            AND Pipeline_Bucket__c IN ('30 Days', 'Ready to Schedule')
            AND Takeoff_Task_Created__c = true
            AND Takeoff_Complete__c = false
            AND Bucket_Changed_Date__c < :cutoff
        ];

        if (overdueLoots.isEmpty()) return;

        List<Task> escalations = new List<Task>();
        List<Account> toFlag   = new List<Account>();

        for (Account lot : overdueLoots) {
            // Task to FM Manager
            Id ownerId = lot.FM__r.ManagerId != null ? lot.FM__r.ManagerId : lot.FM__c;

            Task t = new Task();
            t.Subject       = 'OVERDUE TAKEOFF — ' + lot.Name + ' — Target: '
                + (lot.Target_Start_Date__c != null ? lot.Target_Start_Date__c.format() : 'TBD');
            t.OwnerId       = ownerId;
            t.WhatId        = lot.Id;
            t.Priority      = 'High';
            t.ActivityDate  = Date.today();
            t.Type          = 'Escalation';
            t.Description   = 'The site takeoff for this lot has not been completed within 48 hours. '
                + 'Target install date: '
                + (lot.Target_Start_Date__c != null ? lot.Target_Start_Date__c.format() : 'TBD') + '. '
                + 'Contact FM immediately.';
            escalations.add(t);

            // Mark lot as overdue
            toFlag.add(new Account(Id=lot.Id, Takeoff_Overdue__c=true));
        }

        if (!escalations.isEmpty()) insert escalations;
        if (!toFlag.isEmpty())      update toFlag;
    }
}
