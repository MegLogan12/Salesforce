global without sharing class LOVING_QIEscalationScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        DateTime cutoff = System.now().addHours(-48);
        List<WorkOrder> wos = [
            SELECT Id, FM__c, FM__r.ManagerId, Lot_Address__c, Crew_Complete_Timestamp__c
            FROM WorkOrder
            WHERE Status = 'Completed (Field Complete)'
            AND QI_Submitted__c = false
            AND Crew_Complete_Timestamp__c < :cutoff
        ];
        if (wos.isEmpty()) return;
        List<Task> tasks = new List<Task>();
        for (WorkOrder wo : wos) {
            Id ownerId = wo.FM__r.ManagerId != null ? wo.FM__r.ManagerId : wo.FM__c;
            Task t = new Task();
            t.Subject      = 'OVERDUE QI INSPECTION — ' + wo.Lot_Address__c;
            t.OwnerId      = ownerId;
            t.WhatId       = wo.Id;
            t.Priority     = 'High';
            t.ActivityDate = Date.today();
            t.Type         = 'Escalation';
            t.Description  = 'QI Inspection not submitted within 48 hours of crew completion. '
                + 'Crew completed: '
                + (wo.Crew_Complete_Timestamp__c != null ? wo.Crew_Complete_Timestamp__c.format() : 'Unknown');
            tasks.add(t);
        }
        if (!tasks.isEmpty()) insert tasks;
    }
}
