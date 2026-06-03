trigger SiteReadinessItemTrigger on Site_Readiness_Item__c (after insert, after update) {
    SiteReadinessHandler.syncItemsToWorkOrder(Trigger.new, Trigger.oldMap);
}
