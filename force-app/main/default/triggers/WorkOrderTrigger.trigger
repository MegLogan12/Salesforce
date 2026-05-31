trigger WorkOrderTrigger on WorkOrder (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        WorkOrderHandler.handleBefore(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        WorkOrderHandler.handleAfter(Trigger.new, Trigger.oldMap);
    }
}