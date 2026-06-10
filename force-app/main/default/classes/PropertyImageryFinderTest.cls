@IsTest
private class PropertyImageryFinderTest {

    private class PublicDataMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('geocoder')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"result":{"addressMatches":[{"coordinates":{"x":-80.8431,"y":35.2271}}]}}');
            } else {
                // Esri imagery — return some bytes as the image.
                res.setHeader('Content-Type', 'image/jpeg');
                res.setBodyAsBlob(Blob.valueOf('aerial-image-bytes'));
            }
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Account a = new Account(Name = 'Hartwell Household',
            BillingStreet = '4217 Thornwood Ct', BillingCity = 'Charlotte',
            BillingState = 'NC', BillingPostalCode = '28269');
        insert a;
        insert new Opportunity(Name = 'Aerial Test', AccountId = a.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
    }

    @IsTest
    static void testFindAndAttachAerial() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new PublicDataMock());
        Test.startTest();
        PropertyImageryFinder.findAndAttachAerial(opp.Id);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocument.Title FROM ContentDocumentLink WHERE LinkedEntityId = :opp.Id
        ];
        System.assert(!links.isEmpty(), 'An aerial file should be attached to the opportunity');
        System.assert(links[0].ContentDocument.Title.startsWith('Aerial View'), 'File titled as aerial view');
    }

    @IsTest
    static void testFindFromFlow() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new PublicDataMock());
        Test.startTest();
        PropertyImageryFinder.findFromFlow(new List<Id>{ opp.Id });
        Test.stopTest();
        Integer files = [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];
        System.assert(files >= 1, 'Flow entry should attach an aerial');
    }

    @IsTest
    static void testNoAddressIsSafe() {
        Opportunity noAddr = new Opportunity(Name = 'No Addr', StageName = 'Prospecting', CloseDate = Date.today());
        insert noAddr;
        Test.setMock(HttpCalloutMock.class, new PublicDataMock());
        Test.startTest();
        PropertyImageryFinder.findAndAttachAerial(noAddr.Id);
        Test.stopTest();
        Integer files = [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :noAddr.Id];
        System.assertEquals(0, files, 'No address means no callout and no file, handled gracefully');
    }
}