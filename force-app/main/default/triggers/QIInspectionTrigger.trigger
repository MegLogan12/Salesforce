trigger QIInspectionTrigger on Quality_Inspection__c (after insert, after update) {
    QIHandler.syncResultToWorkOrder(Trigger.new, Trigger.oldMap);
}
