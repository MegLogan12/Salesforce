@IsTest
private class WEXLocationSyncServiceOfflineCleanupTest {
    @IsTest
    static void backfillDeletesOfflineOrphanPosition() {
        Vehicle__c veh = new Vehicle__c(
            GPS_Insights_Id__c = 'ORPHAN-001',
            GPS_Status__c = 'Offline'
        );
        insert veh;

        WEX_GPS_Position__c pos = new WEX_GPS_Position__c(
            Vehicle__c = veh.Id,
            Latitude__c = 33.66,
            Longitude__c = -111.92,
            Last_Seen_DateTime__c = System.now().addDays(-2),
            Source_System__c = 'WEX GPS'
        );
        insert pos;

        Test.startTest();
        WEXLocationSyncService.backfillExistingPositionAssignments();
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM WEX_GPS_Position__c WHERE Id = :pos.Id],
            'Offline orphan positions should be deleted instead of retained without crew context'
        );
    }
}