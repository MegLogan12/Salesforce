trigger ODLQuoteTrigger on Quote (after insert, after update) {
    ODLVoucherLifecycleService.syncVoucherFromQuotes(Trigger.newMap.keySet());
}