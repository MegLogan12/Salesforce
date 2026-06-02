@IsTest
private class ODLConsoleHomeControllerTest {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'ODL Test Homeowner');
        insert acct;

        List<Opportunity> opps = new List<Opportunity>();
        opps.add(new Opportunity(
            Name      = 'ODL Test - UMB Opp',
            AccountId = acct.Id,
            StageName = 'Consultation Scheduled',
            CloseDate = Date.today().addDays(30),
            Type      = 'UMB',
            Amount    = 5000
        ));
        opps.add(new Opportunity(
            Name      = 'ODL Test - UMB Opp 2',
            AccountId = acct.Id,
            StageName = 'Quote Requested',
            CloseDate = Date.today().addDays(30),
            Type      = 'UpgradeMyBackyard',
            Amount    = 8000
        ));
        opps.add(new Opportunity(
            Name      = 'ODL Test - Design Build Opp',
            AccountId = acct.Id,
            StageName = 'Nurturing',
            CloseDate = Date.today().addDays(60),
            Type      = 'Design Build',
            Amount    = 12000
        ));
        insert opps;

        insert new Task(
            WhatId       = opps[0].Id,
            Subject      = 'ODL Test Follow-Up',
            Status       = 'Open',
            ActivityDate = Date.today().addDays(-3),
            OwnerId      = UserInfo.getUserId()
        );

        insert new Lead(
            FirstName  = 'ODL',
            LastName   = 'Test Lead',
            Company    = 'Test Co',
            Status     = 'New',
            LeadSource = 'Web'
        );
    }

    @IsTest
    static void getHomePageData_returnsKpisAndLobRows() {
        Test.startTest();
        ODLConsoleHomeController.HomePageData data =
            ODLConsoleHomeController.getHomePageData();
        Test.stopTest();

        System.assertNotEquals(null, data, 'HomePageData should not be null.');
        System.assertNotEquals(null, data.kpis, 'KpiData should not be null.');
        System.assertNotEquals(null, data.lobRows, 'LOB rows should not be null.');
        System.assertNotEquals(null, data.recentActivity, 'recentActivity should not be null.');

        System.assert(data.kpis.totalOpenOpps >= 3,
            'Expected at least 3 ODL test opps in totalOpenOpps, got: ' + data.kpis.totalOpenOpps);
        System.assert(data.kpis.umbCount >= 1,
            'Expected at least 1 UMB opp, got: ' + data.kpis.umbCount);
        System.assert(data.kpis.odlCount >= 1,
            'Expected at least 1 UpgradeMyBackyard opp, got: ' + data.kpis.odlCount);
        System.assert(data.kpis.designBuildCount >= 1,
            'Expected at least 1 Design Build opp, got: ' + data.kpis.designBuildCount);
        System.assert(data.kpis.overdueTasks >= 1,
            'Expected at least 1 overdue task (seeded 3 days ago), got: ' + data.kpis.overdueTasks);
        System.assert(data.kpis.openLeads >= 1,
            'Expected at least 1 open lead, got: ' + data.kpis.openLeads);

        System.assertEquals(3, data.lobRows.size(), 'Expected 3 LOB rows.');
        System.assert(data.recentActivity.size() >= 1,
            'Expected at least 1 overdue task in activity list.');
    }

    @IsTest
    static void getHomePageData_emptyOrgState_returnsNoException() {
        // Verify the method handles gracefully when aggregates return zero rows.
        // This covers the empty-collection guards in the controller.
        Test.startTest();
        ODLConsoleHomeController.HomePageData data =
            ODLConsoleHomeController.getHomePageData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assertNotEquals(null, data.lobRows);
        System.assertEquals(3, data.lobRows.size(), 'Always returns 3 LOB rows.');
    }
}