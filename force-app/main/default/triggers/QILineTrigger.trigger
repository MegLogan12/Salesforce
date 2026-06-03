trigger QILineTrigger on QI_Line__c (before insert, before update) {
    QIHandler.setResultFromScore(Trigger.new);
}
