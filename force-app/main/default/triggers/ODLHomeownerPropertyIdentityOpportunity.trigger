trigger ODLHomeownerPropertyIdentityOpportunity on Opportunity (after insert, after update) {
    ODLHomeownerPropertyIdentityService.syncFromOpportunities(Trigger.new, Trigger.oldMap);
}