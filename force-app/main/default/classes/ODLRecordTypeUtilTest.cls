@isTest
private class ODLRecordTypeUtilTest {
    @isTest
    static void testAssignUMBToOpps() {
        Account a = new Account(Name = 'Test Account RT');
        insert a;
        Opportunity o = new Opportunity(
            Name = 'Test Opp RT', AccountId = a.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert o;
        Test.startTest();
        ODLRecordTypeUtil.assignUMBToOpps(new List<Id>{ o.Id });
        Test.stopTest();
        Opportunity updated = [SELECT RecordType.DeveloperName FROM Opportunity WHERE Id = :o.Id];
        System.assertEquals('UMB', updated.RecordType.DeveloperName);
    }
}