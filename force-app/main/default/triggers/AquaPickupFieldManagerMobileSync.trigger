trigger AquaPickupFieldManagerMobileSync on Aqua_Pickup_Ticket__c (after insert, after update) {
    LovingFieldManagerMobileSyncService.syncAquaPickups(Trigger.newMap.keySet());
}