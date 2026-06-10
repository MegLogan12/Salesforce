trigger ODLPaymentMilestoneTrigger on Payment_Milestone__c (after insert, after update) {
    ODLVoucherLifecycleService.syncVoucherFromPaymentMilestones(Trigger.newMap.keySet());
}