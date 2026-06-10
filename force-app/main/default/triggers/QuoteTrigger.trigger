trigger QuoteTrigger on Quote__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        QuoteHandler.handleBefore(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        QuoteHandler.handleAfter(Trigger.new, Trigger.oldMap);
    }
}