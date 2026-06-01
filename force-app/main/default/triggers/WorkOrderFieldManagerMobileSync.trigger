trigger WorkOrderFieldManagerMobileSync on WorkOrder (after insert, after update) {
    LovingFieldManagerMobileSyncService.syncWorkOrders(Trigger.newMap.keySet());
}