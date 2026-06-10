@IsTest
private class ODLLifecycleRecalcTest {
    @IsTest static void recalcWritesLifecycle() {
        Id paRt = [SELECT Id FROM RecordType WHERE SobjectType='Account' AND DeveloperName='PersonAccount' LIMIT 1].Id;
        Account a = new Account(LastName='Recalc HO', RecordTypeId=paRt);
        insert a;
        insert new Opportunity(Name='Open', AccountId=a.Id, StageName='Prospecting', CloseDate=Date.today().addDays(10));
        Test.startTest();
        Database.executeBatch(new ODLLifecycleRecalc(), 200);
        Test.stopTest();
        Account chk = [SELECT Lifecycle_Stage__c FROM Account WHERE Id=:a.Id];
        System.assertEquals('Prospect', chk.Lifecycle_Stage__c, 'open opp, no jobs => Prospect');
    }
    @IsTest static void schedulable() {
        Test.startTest();
        String cron = '0 0 2 * * ?';
        System.schedule('ODLLifecycleRecalcTestJob', cron, new ODLLifecycleRecalc());
        Test.stopTest();
        System.assert(true, 'scheduled without error');
    }
}