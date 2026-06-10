@IsTest
private class ODLHomeownerOppListControllerTest {
    @IsTest
    static void testHomeownerOpportunityWorkspaceUsesHomeownerRowsAndLastAction() {
        Account homeowner = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            FirstName = 'Rowan',
            LastName = 'Hart',
            PersonEmail = 'rowan@example.com'
        );
        insert homeowner;

        Account builder = new Account(Name = 'Builder Account');
        insert builder;

        Opportunity homeownerOpp = new Opportunity(
            Name = 'Rowan Hart - UpgradeMyBackyard',
            StageName = 'Quote Requested',
            CloseDate = Date.today().addDays(10),
            AccountId = homeowner.Id,
            Type = 'UMB',
            BMG_Package__c = 'Entertainer',
            Amount = 32000
        );
        insert homeownerOpp;

        Opportunity builderOpp = new Opportunity(
            Name = 'Builder Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = builder.Id,
            Type = 'Home Builder'
        );
        insert builderOpp;

        insert new Task(
            WhatId = homeownerOpp.Id,
            Subject = 'Initial voicemail left',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-2)
        );
        insert new Task(
            WhatId = homeownerOpp.Id,
            Subject = 'Follow-up call complete',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );
        insert new Task(
            WhatId = homeownerOpp.Id,
            Subject = 'Presentation follow-up',
            Status = 'Not Started',
            ActivityDate = Date.today().addDays(2)
        );

        Test.startTest();
        ODLHomeownerOppListController.WorkspaceData data =
            ODLHomeownerOppListController.getWorkspaceData();
        Test.stopTest();

        System.assertEquals('Homeowner Opportunity List', data.title);
        System.assertEquals(1, data.rows.size());

        ODLHomeownerOppListController.WorkspaceRow row = data.rows[0];
        System.assertEquals(homeownerOpp.Id, row.id);
        System.assertEquals('UpgradeMyBackyard', row.projectPath);
        System.assertEquals('Call Complete - Follow-Up', row.lastAction);
        System.assertEquals('Presentation follow-up', row.followUpTask);
        System.assertEquals(String.valueOf(Date.today().addDays(2)), row.followUpDue);
        System.assertEquals('Entertainer', row.packageOrService);
    }
}