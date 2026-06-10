global without sharing class LOVING_HealthCheckEscalationScheduler implements Schedulable {

    global void execute(SchedulableContext ctx) {
        DateTime cutoff = DateTime.newInstance(Date.today(), Time.newInstance(14, 0, 0, 0));
        escalateOverdue([
            SELECT Id, FM__c, FM__r.ManagerId, Lot_Address__c
            FROM WorkOrder
            WHERE Status = 'In Progress'
            AND Work_Order_Type__c = 'Production Install'
            AND (Health_Check_Date__c = null OR Health_Check_Date__c < :cutoff)
        ]);
    }

    @TestVisible
    private static void escalateOverdue(List<WorkOrder> overdueWOs) {
        if (overdueWOs.isEmpty()) return;
        List<Task> tasks = new List<Task>();
        for (WorkOrder wo : overdueWOs) {
            Task t       = new Task();
            t.Subject    = 'OVERDUE: Health Check Not Submitted — ' + wo.Lot_Address__c;
            t.OwnerId    = (wo.FM__r != null && wo.FM__r.ManagerId != null)
                           ? wo.FM__r.ManagerId
                           : (wo.FM__c != null ? wo.FM__c : UserInfo.getUserId());
            t.WhatId     = wo.Id;
            t.Priority   = 'High';
            t.ActivityDate = Date.today();
            t.Type       = 'Escalation';
            t.Description = 'FM has not submitted the 2 PM health check. Contact FM immediately.';
            tasks.add(t);
        }
        if (!tasks.isEmpty()) insert tasks;
    }
}