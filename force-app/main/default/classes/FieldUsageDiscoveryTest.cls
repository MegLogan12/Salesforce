/**
 * @description Test class for Field Usage Discovery.
 */
@IsTest
public with sharing class FieldUsageDiscoveryTest {
    private class ToolingApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();
            if (endpoint.contains('FieldDefinition')) {
                res.setBody('{"records":[{"DurableId":"01Ixx0000000001AAA"}]}');
                return res;
            }
            if (endpoint.contains('MetadataComponentDependency')) {
                res.setBody('{"records":[{"MetadataComponentName":"Account Layout","MetadataComponentType":"Layout"}]}');
                return res;
            }
            res.setBody('{"records":[]}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Account a1 = new Account(Name = 'Acct 1', Industry = 'Technology');
        Account a2 = new Account(Name = 'Acct 2');
        insert new List<Account>{ a1, a2 };
    }

    @IsTest
    static void testQueueableCreatesContentVersion() {
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(u) {
            Test.setMock(HttpCalloutMock.class, new ToolingApiMock());
            List<FieldUsageDiscoveryService.FieldInput> inputs = new List<FieldUsageDiscoveryService.FieldInput>();
            inputs.add(new FieldUsageDiscoveryService.FieldInput('Account', 'Industry'));
            FieldUsageDiscoveryService.DiscoveryOptions options = new FieldUsageDiscoveryService.DiscoveryOptions();

            Test.startTest();
            System.enqueueJob(new FieldUsageDiscoveryQueueable(inputs, options, 1, 'TEST', false));
            Test.stopTest();

            List<ContentVersion> versions = [
                SELECT Id, Title
                FROM ContentVersion
                WHERE Title LIKE 'FieldUsageDiscovery_TEST%'
                WITH USER_MODE
            ];
            System.assert(versions.size() > 0, 'Expected ContentVersion output');
        }
    }

    @IsTest
    static void testInvocableEnqueuesJobs() {
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(u) {
            Test.setMock(HttpCalloutMock.class, new ToolingApiMock());
            FieldUsageDiscoveryInvocable.Request req = new FieldUsageDiscoveryInvocable.Request();
            req.objectApiName = 'Account';
            req.fieldApiName = 'Industry';
            req.sampleFillRate = true;
            req.includeDependencies = true;
            req.includePermissions = true;

            Test.startTest();
            List<FieldUsageDiscoveryInvocable.Response> resp =
                FieldUsageDiscoveryInvocable.run(new List<FieldUsageDiscoveryInvocable.Request>{ req });
            Test.stopTest();

            System.assertEquals(1, resp.size(), 'Expected one response');
            System.assertNotEquals(null, resp[0].runId, 'Expected run id');
        }
    }
}
