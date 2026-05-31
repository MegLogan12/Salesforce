global without sharing class LOVING_TakeoffEscalationScheduler implements Schedulable {

    @InvocableMethod(label='Run Takeoff Escalation' description='Escalates overdue takeoff tasks to FM managers')
    public static void runFromFlow(List<String> params) {
        escalate();
    }

    global void execute(SchedulableContext ctx) {
        escalate();
    }

    private static void escalate() {
        List<Work_Order__c> wos = [
            SELECT Id, Name, Field_Manager__c, Field_Manager__r.ManagerId,
                   Requested_Install_Date__c
            FROM Work_Order__c
            WHERE Pipeline_Bucket__c IN ('30 Days', 'Ready to Schedule')
            AND Takeoff_Tasks_Created__c = true
            AND Takeoff_Task_Complete__c = false
            AND Status__c NOT IN ('Closed', 'Cancelled', 'Invoiced', 'Paid',
                                  'Ready for Invoice', 'Field Complete')
        ];
        if (wos.isEmpty()) return;
        List<Task> tasks = new List<Task>();
        for (Work_Order__c wo : wos) {
            Id ownerId = (wo.Field_Manager__r != null && wo.Field_Manager__r.ManagerId != null)
                         ? wo.Field_Manager__r.ManagerId
                         : wo.Field_Manager__c;
            if (ownerId == null) continue;
            Task t       = new Task();
            t.Subject      = 'OVERDUE TAKEOFF — ' + wo.Name;
            t.OwnerId      = ownerId;
            t.WhatId       = wo.Id;
            t.Priority     = 'High';
            t.ActivityDate = Date.today();
            t.Type         = 'Escalation';
            t.Description  = 'Site takeoff not completed. Contact FM immediately. '
                           + 'Target install date: '
                           + (wo.Requested_Install_Date__c != null
                              ? wo.Requested_Install_Date__c.format() : 'TBD');
            tasks.add(t);
        }
        if (!tasks.isEmpty()) insert tasks;
    }
}
