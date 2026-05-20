trigger ODLOpportunityTrigger on Opportunity (after insert, after update) {
    ODLVoucherLifecycleService.syncVoucherFromOpportunity(Trigger.newMap.keySet());
}