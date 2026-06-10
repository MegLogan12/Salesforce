trigger QIInspectionTrigger on QI_Inspection__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        QIService.handleBefore(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        QIService.handleAfter(Trigger.new, Trigger.oldMap);
    }
}