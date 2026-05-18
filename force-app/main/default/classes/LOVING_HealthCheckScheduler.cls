/**
 * LOVING_HealthCheckScheduler
 *
 * Scheduled Apex that fires at 2:00 PM daily.
 * Sends health check prompts to all FMs with active (In Progress) Work Orders.
 *
 * Schedule via: System.schedule('LOVING Health Check 2PM',
 *     '0 0 14 ? * MON-FRI *', new LOVING_HealthCheckScheduler());
 *
 * Also handles 3:00 PM escalation if health check not submitted.
 * That is a separate schedule: LOVING_HealthCheckEscalationScheduler
 */
public without sharing class LOVING_HealthCheckScheduler implements Schedulable {

    public void execute(SchedulableContext ctx) {
        sendHealthCheckPrompts();
    }

    private static void sendHealthCheckPrompts() {
        // Find all In Progress Production Install WOs
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
            // Only create if health check not already submitted today
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

/**
 * LOVING_HealthCheckEscalationScheduler
 *
 * Fires at 3:00 PM to escalate any health checks not yet submitted.
 * Schedule: '0 0 15 ? * MON-FRI *'
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

/**
 * LOVING_TakeoffEscalationScheduler
 *
 * Runs hourly. Escalates takeoff tasks that are past the 48-hour deadline.
 * Schedule: '0 0 * ? * * *' (every hour)
 */
global without sharing class LOVING_TakeoffEscalationScheduler implements Schedulable {

    global void execute(SchedulableContext ctx) {
        escalateOverdueTakeoffs();
    }

    private static void escalateOverdueTakeoffs() {
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

/**
 * LOVING_QIEscalationScheduler
 *
 * Runs hourly. Escalates QI Inspections not submitted within 48 hours.
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
