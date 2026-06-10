public with sharing class DesignFileController {

    @AuraEnabled
    public static String generatePublicLink(Id contentDocumentId, Id opportunityId) {

        // Get latest version
        ContentVersion cv = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];

        // Create public distribution
        ContentDistribution cd = new ContentDistribution();
        cd.Name = 'Design Public Link';
        cd.ContentVersionId = cv.Id;
        cd.PreferencesAllowViewInBrowser = true;
        cd.PreferencesAllowOriginalDownload = true;

        insert cd;

        cd = [
            SELECT DistributionPublicUrl
            FROM ContentDistribution
            WHERE Id = :cd.Id
        ];

        // Update Opportunity field
        Opportunity opp = new Opportunity(
            Id = opportunityId,
            Design_Link__c = cd.DistributionPublicUrl
        );

        update opp;

        return cd.DistributionPublicUrl;
    }
}