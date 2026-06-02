trigger InvoiceLineTrigger on Invoice_Line_Item__c (before insert, before update) {
    InvoiceLineHandler.handleBefore(Trigger.new, Trigger.oldMap);
}