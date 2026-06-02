/**
 * LovingExternalLinkController
 * Returns active external links from LOVING_External_Link__mdt, ordered for display.
 */
public with sharing class LovingExternalLinkController {

    public class LinkDto {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String subLabel;
        @AuraEnabled public String url;
        @AuraEnabled public String iconEmoji;
        @AuraEnabled public String category;
    }

    @AuraEnabled(cacheable=true)
    public static List<LinkDto> getLinks() {
        List<LinkDto> out = new List<LinkDto>();
        for (LOVING_External_Link__mdt m : [
            SELECT DeveloperName, MasterLabel, URL__c, Sub_Label__c, Icon_Emoji__c, Category__c, Sort_Order__c
            FROM LOVING_External_Link__mdt
            WHERE Is_Active__c = true
            ORDER BY Sort_Order__c ASC, MasterLabel ASC
        ]) {
            LinkDto d = new LinkDto();
            d.key       = m.DeveloperName;
            d.label     = m.MasterLabel;
            d.subLabel  = m.Sub_Label__c;
            d.url       = m.URL__c;
            d.iconEmoji = m.Icon_Emoji__c;
            d.category  = m.Category__c;
            out.add(d);
        }
        return out;
    }
}