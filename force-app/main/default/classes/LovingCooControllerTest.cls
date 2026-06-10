@IsTest
private class LovingCooControllerTest {

    @TestSetup
    static void seed() {
        // Green-GP invoice (30% GP -> no block)
        Invoice__c inv = new Invoice__c(
            Status__c        = 'Pending Send',
            Total_Revenue__c = 1000,
            Total_Cost__c    = 700,
            Invoice_Date__c  = Date.today()
        );
        insert inv;
    }

    @IsTest
    static void getCooKpis_returnsWrapper() {
        Test.startTest();
        LovingCooController.CooKpis k = LovingCooController.getCooKpis();
        Test.stopTest();

        System.assertNotEquals(null, k, 'CooKpis should not be null');
        System.assert(k.activeWOs >= 0, 'activeWOs should be a non-negative count');
    }

    @IsTest
    static void getWoPipeline_returnsRows() {
        Test.startTest();
        List<LovingCooController.WoPipelineRow> rows = LovingCooController.getWoPipeline();
        Test.stopTest();

        System.assertNotEquals(null, rows, 'Pipeline rows should not be null');
        for (LovingCooController.WoPipelineRow row : rows) {
            System.assertNotEquals(null, row.chipCss, 'chipCss should not be null');
        }
    }

    @IsTest
    static void getGpSummary_returnsWrapper() {
        Test.startTest();
        LovingCooController.GpSummary g = LovingCooController.getGpSummary();
        Test.stopTest();

        System.assertNotEquals(null, g, 'GpSummary should not be null');
        // The invoice inserted in seed has GP_Status = Green (trigger sets it)
        System.assertEquals(1, g.greenCount, 'greenCount should be 1');
        System.assert(g.totalRevenuePending >= 1000, 'totalRevenuePending should include Green invoice revenue');
    }

    @IsTest
    static void getAquaSummary_returnsWrapper() {
        Test.startTest();
        LovingCooController.AquaSummary a = LovingCooController.getAquaSummary();
        Test.stopTest();

        System.assertNotEquals(null, a, 'AquaSummary should not be null');
        System.assertEquals(0, a.upcomingInstalls,  'No install tickets in test org');
        System.assertEquals(0, a.upcomingChecks,    'No check tickets in test org');
        System.assertEquals(0, a.openPickupTickets, 'No pickup tickets in test org');
    }

    @IsTest
    static void getWoPipeline_chipCssLogic() {
        List<String> statuses = new List<String>{
            'In Progress',
            'Approved',
            'Pending Closeout',
            'FM QI Review',
            'Closed',
            'Canceled'
        };

        for (String status : statuses) {
            LovingCooController.WoPipelineRow r = new LovingCooController.WoPipelineRow();
            r.status = status;
            r.chipCss = LovingCooController.chipForStatus(status);
            System.assertNotEquals(null, r.chipCss, 'chipCss non-null for status: ' + r.status);
            if (r.status == 'Scheduled' || r.status == 'In Progress') {
                System.assertEquals('chip chip-blue',  r.chipCss);
            } else if (r.status == 'Approved' || r.status == 'Closed') {
                System.assertEquals('chip chip-green', r.chipCss);
            } else if (r.status == 'Pending Closeout' || r.status == 'Pending Approval') {
                System.assertEquals('chip chip-amber', r.chipCss);
            } else if (r.status == 'FM QI Review') {
                System.assertEquals('chip chip-red',   r.chipCss);
            } else {
                System.assertEquals('chip chip-gray',  r.chipCss);
            }
        }
    }

    @IsTest
    static void getCooKpis_noDataReturnsZeros() {
        delete [SELECT Id FROM Invoice__c];

        Test.startTest();
        LovingCooController.CooKpis k = LovingCooController.getCooKpis();
        Test.stopTest();

        System.assertNotEquals(null, k);
        System.assertEquals(0, k.activeWOs);
        System.assertEquals(0, k.pendingCloseout);
    }

    @IsTest
    static void getPipelineByLob_and_getActivityRisks_returnRows() {
        Account homeowner = new Account(Name = 'COO Test Homeowner');
        insert homeowner;

        Opportunity opp = new Opportunity(
            Name = 'COO UMB Test',
            AccountId = homeowner.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(14),
            Type = 'UMB',
            Amount = 12000,
            Probability = 50
        );
        insert opp;

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Call homeowner',
            Status = 'Not Started',
            ActivityDate = Date.today()
        );

        Test.startTest();
        List<LovingCooController.LobPipelineRow> pipeline = LovingCooController.getPipelineByLob();
        List<LovingCooController.ActivityRiskRow> risks = LovingCooController.getActivityRisks();
        Test.stopTest();

        System.assertNotEquals(null, pipeline);
        System.assertNotEquals(null, risks);
        System.assertEquals(true, pipeline.size() >= 1);
        System.assertEquals(true, risks.size() >= 1);
    }
}