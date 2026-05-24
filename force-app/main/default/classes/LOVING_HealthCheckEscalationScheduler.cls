/**
 * LOVING_HealthCheckEscalationScheduler
 *
 * Fires at 3:00 PM to escalate any health checks not yet submitted.
 * Schedule: '0 0 15 ? * MON-FRI *'
 *
 * Schedule via: System.schedule('LOVING Health Check Escalation 3PM',
 *     '0 0 15 ? * MON-FRI *', new LOVING_HealthCheckEscalationScheduler());
 */
global without sharing class LOVING_HealthCheckEscalationScheduler implements Schedulable {

    global void execute(SchedulableContext ctx) {
        escalateOverdueHealthChecks();
    }

    private static void escalateOverdueHealthChecks() {
        DateTime cutoff = DateTime.newInstance(Date.today(), Time.newInstance(14, 0, 0, 0));

        List<WorkOrder> overdueWOs = [
            SELECT Id, FM__c, FM__r.ManagerId, Lot_Address__c
            FROM WorkOrder
            WHERE Status = 'In Progress'
            AND Work_Order_Type__c = 'Production Install'
            AND (Health_Check_Date__c = null
                 OR Health_Check_Date__c < :cutoff)
        ];

        if (overdueWOs.isEmpty()) return;

        List<Task> escalations = new List<Task>();
        for (WorkOrder wo : overdueWOs) {
            Task t = new Task();
            t.Subject       = 'OVERDUE: Health Check Not Submitted — ' + wo.Lot_Address__c;
            t.OwnerId       = wo.FM__r.ManagerId != null ? wo.FM__r.ManagerId : wo.FM__c;
            t.WhatId        = wo.Id;
            t.Priority      = 'High';
            t.ActivityDate  = Date.today();
            t.Type          = 'Escalation';
            t.Description   = 'The FM has not submitted the 2 PM health check for this job. '
                + 'Lot: ' + wo.Lot_Address__c + '. '
                + 'Contact FM immediately and determine job status.';
            escalations.add(t);
        }

        if (!escalations.isEmpty()) insert escalations;
    }
}
