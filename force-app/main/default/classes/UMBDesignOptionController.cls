/**
 * UMBDesignOptionController — serves the three rendered design options
 * (Retreat / Entertainer / Signature) for a given Opportunity and records
 * the customer's selection. All data is live from UMB_Design_Option__c.
 * No hardcoded packages, prices, or images.
 */
public with sharing class UMBDesignOptionController {

    @AuraEnabled(cacheable=true)
    public static List<UMB_Design_Option__c> getDesignOptions(Id opportunityId) {
        return [
            SELECT Id, Name, Tier__c, Package_Label__c, Price__c, Description__c,
                   Features__c, Rendered_Image_URL__c, Is_Selected__c, Is_Concept__c, Sort_Order__c,
                   (SELECT Id, Name, Category__c, Placement__c, Is_Hearted__c, Unit_Price__c,
                           Product__c, Product__r.Name
                    FROM Design_Elements__r ORDER BY Category__c, Name)
            FROM UMB_Design_Option__c
            WHERE Opportunity__c = :opportunityId
            WITH SECURITY_ENFORCED
            ORDER BY Sort_Order__c NULLS LAST, Tier__c
        ];
    }

    @AuraEnabled
    public static void selectDesignOption(Id designOptionId, Id opportunityId) {
        // Mark the chosen option, clear the others, and sync Opportunity.Selected_Package__c.
        List<UMB_Design_Option__c> options = [
            SELECT Id, Tier__c, Is_Selected__c
            FROM UMB_Design_Option__c
            WHERE Opportunity__c = :opportunityId
            WITH SECURITY_ENFORCED
        ];
        String chosenTier;
        List<UMB_Design_Option__c> toUpdate = new List<UMB_Design_Option__c>();
        for (UMB_Design_Option__c o : options) {
            Boolean shouldSelect = (o.Id == designOptionId);
            if (o.Is_Selected__c != shouldSelect) {
                o.Is_Selected__c = shouldSelect;
                toUpdate.add(o);
            }
            if (shouldSelect) {
                chosenTier = o.Tier__c;
            }
        }
        if (!toUpdate.isEmpty() && Schema.sObjectType.UMB_Design_Option__c.isUpdateable()) {
            update toUpdate;
        }
        if (chosenTier != null && Schema.sObjectType.Opportunity.fields.Selected_Package__c.isUpdateable()) {
            update new Opportunity(Id = opportunityId, Selected_Package__c = chosenTier);
        }
    }
}