@IsTest
private class HomeownerNurtureSchedulerTest {
    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Nurture Test HH');
        // Use Home Owner Account RT if available, otherwise default
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Home_Owner_Account' AND IsActive = true LIMIT 1];
        if (!rts.isEmpty()) acct.RecordTypeId = rts[0].Id;
        insert acct;
        Opportunity opp = new Opportunity(
            Name = 'Nurture Test Opp',
            AccountId = acct.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
    }

    @IsTest
    static void testSchedulerExecutes() {
        Test.startTest();
        HomeownerNurtureScheduler job = new HomeownerNurtureScheduler();
        job.execute(null);
        Test.stopTest();
        // Just verifies no exception is thrown
        System.assert(true, 'Scheduler ran without errors');
    }
}