trigger TakeoffFieldManagerMobileSync on Takeoff__c (after insert, after update) {
    LovingFieldManagerMobileSyncService.syncTakeoffs(Trigger.newMap.keySet());
}