@isTest
private class ODL_DashboardControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'ODL Dashboard Test Account');
        insert acc;

        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name='Dashboard UMB', AccountId=acc.Id,
                StageName='Intake', CloseDate=Date.today().addDays(30),
                Amount=10000, ODL_Path__c='UMB'),
            new Opportunity(Name='Dashboard CB', AccountId=acc.Id,
                StageName='Discovery', CloseDate=Date.today().addDays(60),
                Amount=50000, ODL_Path__c='Custom Build')
        };
        insert opps;

        Case c = new Case(
            AccountId = acc.Id,
            Subject = 'Warranty Issue',
            Status = 'New',
            Priority = 'Medium'
        );
        insert c;
    }

    @isTest
    static void testGetCooMetrics() {
        Test.startTest();
        Map<String, Object> result = ODL_DashboardController.getCooMetrics();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('totalPipeline'));
        System.assert(result.containsKey('lobMetrics'));
        System.assert(result.containsKey('atRiskOpps'));
    }

    @isTest
    static void testGetCampaignMetrics() {
        Test.startTest();
        Map<String, Object> result = ODL_DashboardController.getCampaignMetrics();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('campaigns'));
        System.assert(result.containsKey('activeCount'));
    }

    @isTest
    static void testGetWarrantyCase() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Warranty Issue' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = ODL_DashboardController.getWarrantyCase(c.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('caseRecord'));
    }
}
