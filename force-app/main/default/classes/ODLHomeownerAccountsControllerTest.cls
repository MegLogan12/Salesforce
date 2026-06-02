@IsTest
private class ODLHomeownerAccountsControllerTest {
    @IsTest
    static void returnsHomeownerRows() {
        Account homeowner = new Account(
            Name = 'Taylor Household',
            Type = 'Home Owner',
            ODL_Household_Display_Name__c = 'Taylor Household'
        );
        insert homeowner;

        Opportunity opp = new Opportunity(
            Name = 'Taylor Backyard',
            AccountId = homeowner.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(10),
            Type = 'UpgradeMyBackyard'
        );
        insert opp;

        Test.startTest();
        ODLHomeownerAccountsController.WorkspaceData data = ODLHomeownerAccountsController.getWorkspaceData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assert(data.totalHouseholds > 0);
        System.assert(!data.rows.isEmpty());
        System.assertEquals('Taylor Household', data.rows[0].householdName);
        System.assertEquals('Active Project', data.rows[0].relationshipStatus);
    }
}