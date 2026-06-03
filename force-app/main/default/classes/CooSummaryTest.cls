@isTest
private class CooSummaryTest {

    @isTest
    static void getDivisionSummaryReturnsListWithoutException() {
        Test.startTest();
        List<LovingCooController.DivisionRow> rows = LovingCooController.getDivisionSummary();
        Test.stopTest();
        System.assertNotEquals(null, rows, 'getDivisionSummary should return a list');
    }

    @isTest
    static void getCooKpisReturnsInitializedObject() {
        Test.startTest();
        LovingCooController.CooKpis kpis = LovingCooController.getCooKpis();
        Test.stopTest();
        System.assertNotEquals(null, kpis, 'getCooKpis should return non-null');
        System.assertNotEquals(null, kpis.activeWOs, 'activeWOs initialized');
    }

    @isTest
    static void getWoPipelineReturnsList() {
        Test.startTest();
        List<LovingCooController.WoPipelineRow> rows = LovingCooController.getWoPipeline();
        Test.stopTest();
        System.assertNotEquals(null, rows, 'getWoPipeline returns a list');
    }

    @isTest
    static void getGpSummaryReturnsNonNull() {
        Test.startTest();
        LovingCooController.GpSummary gp = LovingCooController.getGpSummary();
        Test.stopTest();
        System.assertNotEquals(null, gp, 'getGpSummary returns non-null');
        System.assertEquals(0, gp.greenCount, 'green initialized to 0');
    }

    @isTest
    static void escalateGatePostsWithoutException() {
        Test.startTest();
        LovingCooController.escalateGate('G5', 'Test escalation for G5 gate');
        Test.stopTest();
        List<FeedItem> feeds = [SELECT Id, Body FROM FeedItem WHERE ParentId = :UserInfo.getUserId() ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals(1, feeds.size(), 'Chatter post created');
        System.assert(feeds[0].Body.contains('G5'), 'Gate id in body');
    }

    @isTest
    static void chipForStatusCoversAllBranches() {
        System.assertEquals('chip chip-blue',  LovingCooController.chipForStatus('Scheduled'));
        System.assertEquals('chip chip-green', LovingCooController.chipForStatus('Closed'));
        System.assertEquals('chip chip-amber', LovingCooController.chipForStatus('Pending Closeout'));
        System.assertEquals('chip chip-red',   LovingCooController.chipForStatus('FM QI Review'));
        System.assertEquals('chip chip-gray',  LovingCooController.chipForStatus(null));
    }
}
