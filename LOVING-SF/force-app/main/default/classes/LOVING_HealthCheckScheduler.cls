/**
 * LOVING_HealthCheckScheduler
 *
 * Fires at 2:00 PM weekdays. Sends health check prompt Tasks to all FMs
 * with active (In Progress) Production Install Work Orders.
 *
 * Schedule: '0 0 14 ? * MON-FRI *'
 * System.schedule('LOVING Health Check 2PM',
 *     '0 0 14 ? * MON-FRI *', new LOVING_HealthCheckScheduler());
 *
 * 3 PM escalation is a separate class: LOVING_HealthCheckEscalationScheduler.
 */
public without sharing class LOVING_HealthCheckScheduler implements Schedulable {

    public void execute(SchedulableContext ctx) {
        sendHealthCheckPrompts();
    }

    private static void sendHealthCheckPrompts() {
        List<WorkOrder> activeWOs = [
            SELECT Id, FM__c, Lot_Address__c, Lot_Number__c,
                   Health_Check_Status__c, Health_Check_Date__c
            FROM WorkOrder
            WHERE Status = 'In Progress'
            AND Work_Order_Type__c = 'Production Install'
        ];

        if (activeWOs.isEmpty()) return;

        List<Task> tasks = new List<Task>();
        for (WorkOrder wo : activeWOs) {
            if (wo.Health_Check_Date__c == null
                || wo.Health_Check_Date__c.date() < Date.today()) {

                Task t = new Task();
                t.Subject       = '2 PM Health Check Required — ' + wo.Lot_Address__c;
                t.OwnerId       = wo.FM__c;
                t.WhatId        = wo.Id;
                t.Priority      = 'High';
                t.ActivityDate  = Date.today();
                t.Type          = 'Health Check';
                t.Description   = 'Mark this job GREEN (on track to complete today) '
                    + 'or RED (will not complete today).\n\n'
                    + 'If RED: Red Flag Notes are required. '
                    + 'Scheduling will be notified immediately.\n\n'
                    + 'DEADLINE: 3:00 PM. If not submitted by 3 PM, '
                    + 'your manager will be notified.';
                tasks.add(t);
            }
        }

        if (!tasks.isEmpty()) insert tasks;
    }
}
