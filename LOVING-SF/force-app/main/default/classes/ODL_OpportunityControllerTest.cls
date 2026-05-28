@isTest
private class ODL_OpportunityControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'ODL Opp Test Account');
        insert acc;

        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name='UMB Deal', AccountId=acc.Id, StageName='Intake',
                CloseDate=Date.today().addDays(60), Amount=8000, ODL_Path__c='UMB'),
            new Opportunity(Name='CB Deal', AccountId=acc.Id, StageName='Discovery',
                CloseDate=Date.today().addDays(90), Amount=75000, ODL_Path__c='Custom Build'),
            new Opportunity(Name='LC Deal', AccountId=acc.Id, StageName='Inquiry',
                CloseDate=Date.today().addDays(30), Amount=1200, ODL_Path__c='Lawn Care')
        };
        insert opps;
    }

    @isTest
    static void testGetOpportunityList_noFilter() {
        Test.startTest();
        List<Opportunity> opps = ODL_OpportunityController.getOpportunityList(null);
        Test.stopTest();
        System.assertNotEquals(null, opps);
    }

    @isTest
    static void testGetOpportunityList_umbFilter() {
        Test.startTest();
        List<Opportunity> opps = ODL_OpportunityController.getOpportunityList('UMB');
        Test.stopTest();
        System.assertEquals(1, opps.size());
    }

    @isTest
    static void testGetUmbRecord() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'UMB Deal' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = ODL_OpportunityController.getUmbRecord(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('opp'));
        System.assert(result.containsKey('tasks'));
    }

    @isTest
    static void testGetCustomBuildRecord() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'CB Deal' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = ODL_OpportunityController.getCustomBuildRecord(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('opp'));
    }

    @isTest
    static void testGetLawnCareRecord() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'LC Deal' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = ODL_OpportunityController.getLawnCareRecord(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('opp'));
    }
}
