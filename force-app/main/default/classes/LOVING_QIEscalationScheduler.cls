/**
 * LOVING_QIEscalationScheduler
 *
 * Runs daily. Escalates QI Inspections not submitted within 48 hours of crew completion.
 * Schedule: '0 0 8 ? * MON-FRI *'
 *
 * Schedule via: System.schedule('LOVING QI Escalation 8AM',
 *     '0 0 8 ? * MON-FRI *', new LOVING_QIEscalationScheduler());
 */
global without sharing class LOVING_QIEscalationScheduler implements Schedulable {

    global void execute(SchedulableContext ctx) {
        escalateOverdueQI();
    }

    private static void escalateOverdueQI() {
        DateTime cutoff = System.now().addHours(-48);

        List<WorkOrder> overdueQI = [
            SELECT Id, FM__c, FM__r.ManagerId, Lot_Address__c, Crew_Complete_Timestamp__c
            FROM WorkOrder
            WHERE Status = 'Completed (Field Complete)'
            AND QI_Submitted__c = false
            AND Crew_Complete_Timestamp__c < :cutoff
        ];

        if (overdueQI.isEmpty()) return;

        List<Task> tasks = new List<Task>();
        for (WorkOrder wo : overdueQI) {
            Id ownerId = wo.FM__r.ManagerId != null ? wo.FM__r.ManagerId : wo.FM__c;
            Task t = new Task();
            t.Subject       = 'OVERDUE QI INSPECTION — ' + wo.Lot_Address__c;
            t.OwnerId       = ownerId;
            t.WhatId        = wo.Id;
            t.Priority      = 'High';
            t.ActivityDate  = Date.today();
            t.Type          = 'Escalation';
            t.Description   = 'QI Inspection has not been submitted within 48 hours of crew completion. '
                + 'Crew completed: '
                + (wo.Crew_Complete_Timestamp__c != null
                    ? wo.Crew_Complete_Timestamp__c.format() : 'Unknown')
                + '. Contact FM immediately.';
            tasks.add(t);
        }

        if (!tasks.isEmpty()) insert tasks;
    }
}
