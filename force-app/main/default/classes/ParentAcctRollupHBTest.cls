@IsTest
private class ParentAcctRollupHBTest {
    @IsTest
    static void parentAccountCommunityQueryIncludesChildDivisions() {
        Id parentRtId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Builder_Parent' LIMIT 1].Id;
        Id divisionRtId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Builder_Market' LIMIT 1].Id;

        Account parent = new Account(
            Name = 'HB Parent Test',
            RecordTypeId = parentRtId,
            Type = 'Home Builder'
        );
        insert parent;

        Account division = new Account(
            Name = 'HB Division Test',
            ParentId = parent.Id,
            RecordTypeId = divisionRtId,
            Type = 'Division Builder'
        );
        insert division;

        Community__c community = new Community__c(
            Name = 'HB Community Test',
            Builder_Account__c = division.Id
        );
        insert community;

        Test.startTest();
        List<ParentAccountRollupController.CommunityRow> parentRows =
            ParentAccountRollupController.getCommunitiesForAccount(parent.Id);
        List<ParentAccountRollupController.CommunityRow> divisionRows =
            ParentAccountRollupController.getCommunitiesForAccount(division.Id);
        Test.stopTest();

        System.assertEquals(1, parentRows.size(), 'Parent builder should inherit child division communities.');
        System.assertEquals(community.Id, parentRows[0].id);
        System.assertEquals(1, divisionRows.size(), 'Division builder should still return its direct communities.');
        System.assertEquals(community.Id, divisionRows[0].id);
    }
}