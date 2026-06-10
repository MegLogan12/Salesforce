@IsTest
private class ODLOpportunityListControllerTest {
    @IsTest
    static void returnsOdLRowsAndCounts() {
        Account homeowner = new Account(Name = 'ODL Opportunity List Test', Type = 'Home Owner');
        insert homeowner;

        Opportunity umb = new Opportunity(
            Name = 'UMB List Test',
            AccountId = homeowner.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(14),
            Type = 'UMB',
            Amount = 34000,
            BMG_Package__c = 'Entertainer'
        );
        Opportunity designBuild = new Opportunity(
            Name = 'Design Build List Test',
            AccountId = homeowner.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(21),
            Type = 'Custom Build',
            Amount = 88000
        );
        insert new List<Opportunity>{ umb, designBuild };

        insert new List<Task>{
            new Task(WhatId = umb.Id, Subject = 'Voicemail left', Status = 'Completed', ActivityDate = Date.today().addDays(-1)),
            new Task(WhatId = umb.Id, Subject = 'Call homeowner', Status = 'Not Started', ActivityDate = Date.today()),
            new Task(WhatId = designBuild.Id, Subject = 'Discovery call', Status = 'Not Started', ActivityDate = Date.today().addDays(1))
        };

        Test.startTest();
        ODLOpportunityListController.PageData data = ODLOpportunityListController.getPageData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assert(data.totalCount >= 2);
        System.assert(data.umbCount >= 1);
        System.assert(data.designBuildCount >= 1);
        System.assertNotEquals(null, data.latestUmbUrl);
        System.assertEquals(true, data.voicemailCount >= 1);
        System.assertEquals(true, data.followUpDueCount >= 1);
    }
}