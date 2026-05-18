global without sharing class LOVING_TakeoffEscalationScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        DateTime cutoff = System.now().addHours(-48);
        List<Account> lots = [
            SELECT Id, Name, FM__c, FM__r.ManagerId, Target_Start_Date__c, Bucket_Changed_Date__c
            FROM Account
            WHERE RecordType.DeveloperName = 'Lot'
            AND Pipeline_Bucket__c IN ('30 Days', 'Ready to Schedule')
            AND Takeoff_Task_Created__c = true
            AND Takeoff_Complete__c = false
            AND Bucket_Changed_Date__c < :cutoff
        ];
        if (lots.isEmpty()) return;
        List<Task>    tasks  = new List<Task>();
        List<Account> toFlag = new List<Account>();
        for (Account lot : lots) {
            Id ownerId = lot.FM__r.ManagerId != null ? lot.FM__r.ManagerId : lot.FM__c;
            Task t = new Task();
            t.Subject      = 'OVERDUE TAKEOFF — ' + lot.Name;
            t.OwnerId      = ownerId;
            t.WhatId       = lot.Id;
            t.Priority     = 'High';
            t.ActivityDate = Date.today();
            t.Type         = 'Escalation';
            t.Description  = 'Site takeoff not completed within 48 hours. Contact FM immediately.';
            tasks.add(t);
            toFlag.add(new Account(Id = lot.Id, Takeoff_Overdue__c = true));
        }
        if (!tasks.isEmpty())  insert tasks;
        if (!toFlag.isEmpty()) update toFlag;
    }
}
