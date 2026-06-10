trigger ODLOpportunityTrigger on Opportunity (before insert, after insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        ODLHouseholdService.enforceScopedOpportunityUniqueness(Trigger.new);
    }

    if (Trigger.isAfter) {
        ODLVoucherLifecycleService.syncVoucherFromOpportunity(Trigger.newMap.keySet());
    }
}