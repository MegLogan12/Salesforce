trigger AquaCheckFieldManagerMobileSync on Aqua_Check_Ticket__c (after insert, after update) {
    LovingFieldManagerMobileSyncService.syncAquaChecks(Trigger.newMap.keySet());
}