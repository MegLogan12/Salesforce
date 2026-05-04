trigger LOVING_WorkOrderTrigger on WorkOrder (
    before insert,
    before update,
    after insert,
    after update
) {
    // Guard against recursive execution
    if (LOVING_TriggerGuard.hasAlreadyRun('WorkOrder')) {
        return;
    }
    LOVING_TriggerGuard.setAlreadyRun('WorkOrder');

    LOVING_WorkOrderTriggerHandler.handle(
        Trigger.new,
        Trigger.oldMap,
        Trigger.operationType
    );
}
