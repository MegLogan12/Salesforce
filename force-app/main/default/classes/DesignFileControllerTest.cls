@isTest
public class DesignFileControllerTest {
    @isTest
    static void testGeneratePublicLink() {
        // Create test Opportunity
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;

        // Create test ContentVersion and ContentDocument
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test file content')
        );
        insert cv;

        // Query ContentDocumentId
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        Id contentDocumentId = cv.ContentDocumentId;

        Test.startTest();
        String publicUrl = DesignFileController.generatePublicLink(contentDocumentId, opp.Id);
        Test.stopTest();

        // Assert public URL is not null and Opportunity is updated
        System.assertNotEquals(null, publicUrl, 'Public URL should not be null');
        Opportunity updatedOpp = [SELECT Id, Design_Link__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(publicUrl, updatedOpp.Design_Link__c, 'Design_Link__c should match public URL');
    }
}