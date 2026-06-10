@isTest
private class ODL_AccountControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'ODL Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'ODL Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 15000,
            ODL_Path__c = 'UMB'
        );
        insert opp;

        Task t = new Task(
            Subject = 'Follow Up',
            WhatId = acc.Id,
            ActivityDate = Date.today().addDays(1),
            Status = 'Not Started'
        );
        insert t;
    }

    @isTest
    static void testGetAccountData() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'ODL Test Account' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = ODL_AccountController.getAccountData(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('account'), 'Should have account key');
        System.assert(result.containsKey('tasks'), 'Should have tasks key');
        System.assert(result.containsKey('openOppCount'), 'Should have openOppCount key');
    }

    @isTest
    static void testGetAccountOpportunities() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'ODL Test Account' LIMIT 1];
        Test.startTest();
        List<Opportunity> opps = ODL_AccountController.getAccountOpportunities(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, opps, 'Should return list');
        System.assertEquals(1, opps.size(), 'Should have 1 opportunity');
    }
}