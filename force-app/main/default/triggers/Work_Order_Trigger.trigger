trigger Work_Order_Trigger on Work_Order__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        WorkOrderHandler.handleBefore(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        WorkOrderHandler.handleAfter(Trigger.new, Trigger.oldMap);
    }
}