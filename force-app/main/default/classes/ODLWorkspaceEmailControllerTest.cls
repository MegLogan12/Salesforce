@IsTest
private class ODLWorkspaceEmailControllerTest {
    @IsTest
    static void testWorkspaceResponses() {
        Account accountRow = new Account(Name = 'ODL Workspace Account');
        insert accountRow;

        Opportunity opp = new Opportunity(
            Name = 'Backyard Design Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            AccountId = accountRow.Id,
            Type = 'UMB'
        );
        insert opp;

        Lead leadRow = new Lead(
            LastName = 'Backyard Lead',
            Company = 'ODL',
            Status = 'New',
            LeadSource = 'Lennar Voucher',
            Community_Name__c = 'Test Community'
        );
        insert leadRow;

        Test.startTest();
        ODLWorkspaceEmailController.WorkspaceData sales = ODLWorkspaceEmailController.getWorkspaceData('sales');
        ODLWorkspaceEmailController.WorkspaceData leads = ODLWorkspaceEmailController.getWorkspaceData('lead');
        ODLWorkspaceEmailController.WorkspaceData opportunities = ODLWorkspaceEmailController.getWorkspaceData('opportunity');
        ODLWorkspaceEmailController.WorkspaceData quotes = ODLWorkspaceEmailController.getWorkspaceData('quote');
        ODLWorkspaceEmailController.WorkspaceData workOrders = ODLWorkspaceEmailController.getWorkspaceData('workorder');
        ODLWorkspaceEmailController.WorkspaceData vouchers = ODLWorkspaceEmailController.getWorkspaceData('voucher');
        ODLWorkspaceEmailController.WorkspaceData unsupported = ODLWorkspaceEmailController.getWorkspaceData('unsupported');
        Test.stopTest();

        System.assertEquals('Outdoor Living Sales', sales.title);
        System.assert(sales.rows.size() > 0);
        System.assertEquals('Outdoor Living Leads', leads.title);
        System.assert(leads.rows.size() > 0);
        System.assertEquals('Outdoor Living Opportunities', opportunities.title);
        System.assert(opportunities.rows.size() > 0);
        System.assertEquals('Outdoor Living Quotes', quotes.title);
        System.assertNotEquals(null, quotes.rows);
        System.assertEquals('Outdoor Living Work Orders', workOrders.title);
        System.assertNotEquals(null, workOrders.rows);
        System.assertEquals(true, vouchers.backendMissing);
        System.assertEquals('Outdoor Living Workspace', unsupported.title);
    }
}