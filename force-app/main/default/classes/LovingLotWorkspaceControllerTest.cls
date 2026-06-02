@IsTest(SeeAllData=true)
private class LovingLotWorkspaceControllerTest {
    @IsTest
    static void loadsWorkspaceAndOptionalDetail() {
        Test.startTest();
        LovingLotWorkspaceController.LotsWorkspaceDTO workspace = LovingLotWorkspaceController.getLotsWorkspace();
        System.assertNotEquals(null, workspace, 'Workspace payload should be returned.');
        System.assertNotEquals(null, workspace.rows, 'Workspace rows collection should always be initialized.');

        Id lotId;
        List<Lot__c> lots = [SELECT Id FROM Lot__c ORDER BY LastModifiedDate DESC LIMIT 1];
        if (!lots.isEmpty()) {
            lotId = lots[0].Id;
        }

        LovingLotWorkspaceController.LotDetailDTO detail = LovingLotWorkspaceController.getLotDetail(lotId);
        System.assertNotEquals(null, detail, 'Detail payload should be returned even when no lot exists.');
        System.assertNotEquals(null, detail.timeline, 'Timeline collection should always be initialized.');
        Test.stopTest();
    }
}