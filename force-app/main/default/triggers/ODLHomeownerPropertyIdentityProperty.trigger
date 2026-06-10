trigger ODLHomeownerPropertyIdentityProperty on Homeowner_Property__c (before insert, before update) {
    ODLHomeownerPropertyIdentityService.hydrateProperties(Trigger.new);
}