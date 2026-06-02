global without sharing class LOVING_TakeoffEscalationScheduler implements Schedulable {

    @TestVisible private static List<WorkOrder> mockWorkOrders;
    @TestVisible private static Set<Id> mockWorkOrdersWithTakeoffTasks;
    @TestVisible private static List<Task> lastCreatedTasks;

    @InvocableMethod(label='Run Takeoff Escalation' description='Escalates overdue takeoff tasks to FM managers')
    public static void runFromFlow(List<String> params) {
        escalate();
    }

    global void execute(SchedulableContext ctx) {
        escalate();
    }

    private static void escalate() {
        List<WorkOrder> wos = mockWorkOrders != null ? mockWorkOrders : [
            SELECT Id, WorkOrderNumber, Field_Manager__c, Field_Manager__r.ManagerId,
                   Requested_Install_Date__c
            FROM WorkOrder
            WHERE Pipeline_Bucket__c IN ('30 Days', 'Ready to Schedule')
            AND Takeoff_Complete__c = false
            AND Status NOT IN ('Closed', 'Canceled', 'Invoiced', 'Paid',
                                  'Ready for Invoice', 'Field Complete')
        ];
        if (wos.isEmpty()) return;

        Set<Id> workOrderIds = new Map<Id, WorkOrder>(wos).keySet();
        Set<Id> workOrdersWithTakeoffTasks = new Set<Id>();
        if (mockWorkOrders != null) {
            workOrdersWithTakeoffTasks = mockWorkOrdersWithTakeoffTasks != null
                ? mockWorkOrdersWithTakeoffTasks
                : new Set<Id>();
        } else {
            for (Task task : [
                SELECT WhatId
                FROM Task
                WHERE WhatId IN :workOrderIds
                AND Type = 'Takeoff'
                AND Subject LIKE 'Site Takeoff Required%'
            ]) {
                workOrdersWithTakeoffTasks.add(task.WhatId);
            }
        }

        List<Task> tasks = new List<Task>();
        for (WorkOrder wo : wos) {
            if (!workOrdersWithTakeoffTasks.contains(wo.Id)) continue;
            Id ownerId = (wo.Field_Manager__r != null && wo.Field_Manager__r.ManagerId != null)
                         ? wo.Field_Manager__r.ManagerId
                         : wo.Field_Manager__c;
            if (ownerId == null) continue;
            tasks.add(buildEscalationTask(wo, ownerId));
        }
        if (mockWorkOrders != null) {
            lastCreatedTasks = tasks;
            return;
        }

        if (!tasks.isEmpty()) insert tasks;
    }

    @TestVisible private static Task buildEscalationTask(WorkOrder wo, Id ownerId) {
        String workOrderName = String.isNotBlank(wo.WorkOrderNumber) ? wo.WorkOrderNumber : String.valueOf(wo.Id);
        Task t       = new Task();
        t.Subject      = 'OVERDUE TAKEOFF — ' + workOrderName;
        t.OwnerId      = ownerId;
        t.WhatId       = wo.Id;
        t.Priority     = 'High';
        t.ActivityDate = Date.today();
        t.Type         = 'Escalation';
        t.Description  = 'Site takeoff not completed. Contact FM immediately. '
                       + 'Target install date: '
                       + (wo.Requested_Install_Date__c != null
                          ? wo.Requested_Install_Date__c.format() : 'TBD');
        return t;
    }
}