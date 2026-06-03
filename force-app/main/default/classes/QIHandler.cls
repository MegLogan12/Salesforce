public class QIHandler {

    // ── QILineTrigger (before insert/update) ─────────────────────────────────
    // Sets Result__c = 'Pass' when Score__c >= 9, 'Fail' when < 9, null when blank.
    // The Quality_Inspection__c.Failed_Lines__c roll-up already filters by Score__c < 9
    // directly, so the overall result formula works even before Result__c is set.
    // This gives the LWC and page layouts a per-line display value.
    public static void setResultFromScore(List<QI_Line__c> lines) {
        for (QI_Line__c line : lines) {
            if (line.Score__c == null) {
                line.Result__c = null;
            } else {
                line.Result__c = (line.Score__c >= 9) ? 'Pass' : 'Fail';
            }
        }
    }

    // ── QIInspectionTrigger (after insert/update) ─────────────────────────────
    // When Quality_Inspection__c.Result__c changes, syncs QI outcome to the parent
    // WorkOrder's QI fields. On any fail result, spawns a Customer Care task.
    // WorkOrder.QI_Complete__c = true only when all lines pass (Acceptable or Excellent).
    public static void syncResultToWorkOrder(
            List<Quality_Inspection__c> newList,
            Map<Id, Quality_Inspection__c> oldMap) {

        List<WorkOrder> woUpdates  = new List<WorkOrder>();
        List<Task>      taskInserts = new List<Task>();

        for (Quality_Inspection__c qi : newList) {
            if (qi.Work_Order__c == null) continue;
            String oldResult = (oldMap != null && oldMap.containsKey(qi.Id))
                               ? oldMap.get(qi.Id).Result__c : null;
            if (qi.Result__c == oldResult) continue;

            WorkOrder wo = new WorkOrder(Id = qi.Work_Order__c);

            if (qi.Result__c != null && qi.Result__c.contains('Rework Required')) {
                wo.QI_Result__c  = 'Red — Rework Required';
                wo.QI_Complete__c = false;
                taskInserts.add(new Task(
                    WhatId      = qi.Work_Order__c,
                    Subject     = 'QI Failed — Rework Required',
                    Status      = 'Not Started',
                    Priority    = 'High',
                    Description = 'Quality Inspection ' + qi.Name +
                                  ' result: ' + qi.Result__c +
                                  '. Assign to Customer Care, arrange rework,' +
                                  ' and schedule re-inspection before close.'
                ));
            } else if (qi.Result__c == 'Acceptable' || qi.Result__c == 'Excellent') {
                wo.QI_Result__c  = qi.Result__c;
                wo.QI_Complete__c = true;
            } else if (qi.Result__c == 'Pending') {
                wo.QI_Complete__c = false;
            }

            woUpdates.add(wo);
        }

        if (!woUpdates.isEmpty())  Database.update(woUpdates, false);
        if (!taskInserts.isEmpty()) insert taskInserts;
    }

    // ── Invocable entry point for Flows / Process Builder ────────────────────
    // Allows a flow to call syncResultToWorkOrder by QI Id.
    @InvocableMethod(label='Sync QI Result to Work Order'
                     description='Re-syncs a Quality_Inspection__c result to its parent WorkOrder.')
    public static void syncByIds(List<Id> qiIds) {
        List<Quality_Inspection__c> qis = [
            SELECT Id, Name, Work_Order__c, Result__c
            FROM Quality_Inspection__c
            WHERE Id IN :qiIds
        ];
        syncResultToWorkOrder(qis, null);
    }
}
