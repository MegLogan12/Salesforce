@IsTest
private class UMBDesignGenerationServiceTest {

    // 1x1 PNG, valid base64 so EncodingUtil.base64Decode succeeds.
    private static final String PNG_B64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

    private class GeminiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"candidates":[{"content":{"parts":[' +
                '{"inlineData":{"mimeType":"image/png","data":"' + PNG_B64 + '"}}]}}]}');
            return res;
        }
    }

    private static User currentUser() {
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    }

    @TestSetup
    static void setup() {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'LOVING_UMB_Design_Options' LIMIT 1];
        List<PermissionSetAssignment> already = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :ps.Id
        ];
        if (already.isEmpty()) {
            insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = ps.Id);
        }

        Opportunity opp = new Opportunity(
            Name = 'Gen Test Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;

        // Attach a backyard photo File to the Opportunity.
        ContentVersion cv = new ContentVersion(
            Title = 'Backyard', PathOnClient = 'backyard.jpg',
            VersionData = Blob.valueOf('fake-image-bytes'),
            FirstPublishLocationId = opp.Id
        );
        insert cv;
    }

    @IsTest
    static void testGenerateWithPhoto() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new GeminiMock());
        Test.startTest();
        System.runAs(currentUser()) {
            UMBDesignGenerationService.requestDesignGeneration(opp.Id);
        }
        Test.stopTest();

        List<UMB_Design_Option__c> options = [
            SELECT Tier__c, Rendered_Image_URL__c, Sort_Order__c
            FROM UMB_Design_Option__c WHERE Opportunity__c = :opp.Id
        ];
        System.assertEquals(3, options.size(), 'Three tiers should be generated');
    }

    @IsTest
    static void testSaveRenderingCreatesFileAndUrl() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        String url = UMBDesignGenerationService.saveRendering(opp.Id, 'Retreat', PNG_B64);
        Test.stopTest();
        System.assertNotEquals(null, url, 'saveRendering should return a displayable URL');
        Integer files = [SELECT COUNT() FROM ContentVersion WHERE Title = 'UMB Retreat Rendering'];
        System.assert(files >= 1, 'A rendering file should be saved on the opportunity');
    }

    @IsTest
    static void testInvokeGeminiHttpPath() {
        Test.setMock(HttpCalloutMock.class, new GeminiMock());
        Test.startTest();
        String img = UMBDesignGenerationService.invokeGemini('gemini-2.5-flash-image', 'dummy-key',
            'Add a paver patio and fire pit.', 'ZmFrZS1ieXRlcw==');
        Test.stopTest();
        System.assertEquals(PNG_B64, img, 'invokeGemini should return the base64 image from the response');
    }

    @IsTest
    static void testExtractImageSucceeds() {
        String body = '{"candidates":[{"content":{"parts":[{"inlineData":{"data":"' + PNG_B64 + '"}}]}}]}';
        System.assertEquals(PNG_B64, UMBDesignGenerationService.extractImage(body),
            'extractImage should pull the base64 image from a valid response');
    }

    @IsTest
    static void testGenerateFromFlow() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new GeminiMock());
        Test.startTest();
        UMBDesignGenerationService.generateFromFlow(new List<Id>{ opp.Id });
        Test.stopTest();
        Integer count = [SELECT COUNT() FROM UMB_Design_Option__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(3, count, 'Flow entry point should generate three tiers');
    }

    @IsTest
    static void testNoPhotoStillCreatesOptions() {
        Opportunity opp = new Opportunity(Name = 'No Photo', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;
        Test.setMock(HttpCalloutMock.class, new GeminiMock());
        Test.startTest();
        UMBDesignGenerationService.requestDesignGeneration(opp.Id);
        Test.stopTest();
        // Even with no photo, option records are created (text-only generation), never fabricated.
        Integer count = [SELECT COUNT() FROM UMB_Design_Option__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(3, count, 'Options created even without a photo');
    }

    @IsTest
    static void testExtractImageHandlesEmpty() {
        System.assertEquals(null, UMBDesignGenerationService.extractImage('{"candidates":[]}'),
            'Empty candidates returns null');
        System.assertEquals(null, UMBDesignGenerationService.extractImage('not json'),
            'Bad JSON returns null safely');
    }
}