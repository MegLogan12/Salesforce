trigger TakeoffExecutionBridge on Takeoff__c (after update) {
    TakeoffExecutionBridgeService.enqueueApprovedTakeoffs(Trigger.newMap, Trigger.oldMap);
}