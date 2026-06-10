trigger QuoteLineTrigger on Quote_Line_Item__c (before insert, before update) {
    QuoteLineHandler.handleBefore(Trigger.new, Trigger.oldMap);
}