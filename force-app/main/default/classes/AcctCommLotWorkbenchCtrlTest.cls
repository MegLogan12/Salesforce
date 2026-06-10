@IsTest
private class AcctCommLotWorkbenchCtrlTest {

    @TestSetup
    static void makeData() {
        RecordType builderRt = [SELECT Id FROM RecordType WHERE SObjectType='Account' AND Name='Home Builder' LIMIT 1];
        RecordType divisionRt = [SELECT Id FROM RecordType WHERE SObjectType='Account' AND Name='Division Builder' LIMIT 1];

        Account builder = new Account(Name='Test Builder Co', RecordTypeId=builderRt.Id);
        insert builder;

        Account division = new Account(Name='Test Builder Co - Charlotte', RecordTypeId=divisionRt.Id, ParentId=builder.Id);
        insert division;

        Community__c comm = new Community__c(Name='Test Community', Builder_Account__c=division.Id, Active__c=true);
        insert comm;

        Lot__c lot = new Lot__c(Name='Test Community - Lot 001', Community__c=comm.Id, Lot_Number__c='001', Pipeline_Bucket__c='Scheduled');
        insert lot;
    }

    @IsTest
    static void getWorkbenchDataReturnsBuildersAndLots() {
        Test.startTest();
        AccountCommunityLotWorkbenchController.WorkbenchPageDTO dto =
            AccountCommunityLotWorkbenchController.getWorkbenchData();
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should not be null');
        System.assertNotEquals(null, dto.builders, 'builders list should not be null');
        System.assertNotEquals(null, dto.divisions, 'divisions list should not be null');
        System.assertNotEquals(null, dto.communities, 'communities list should not be null');
        System.assertNotEquals(null, dto.lots, 'lots list should not be null');

        Boolean foundBuilder  = false;
        Boolean foundDivision = false;
        Boolean foundComm     = false;
        Boolean foundLot      = false;

        for (AccountCommunityLotWorkbenchController.BuilderDTO b : dto.builders) {
            if (b.name == 'Test Builder Co') { foundBuilder = true; System.assertNotEquals(null, b.id); }
        }
        for (AccountCommunityLotWorkbenchController.DivisionDTO d : dto.divisions) {
            if (d.name == 'Test Builder Co - Charlotte') { foundDivision = true; System.assertNotEquals(null, d.builderId); }
        }
        for (AccountCommunityLotWorkbenchController.CommunityDTO c : dto.communities) {
            if (c.name == 'Test Community') { foundComm = true; System.assertEquals(true, c.stage != null); }
        }
        for (AccountCommunityLotWorkbenchController.LotDTO l : dto.lots) {
            if (l.lotId == 'Test Community - Lot 001') {
                foundLot = true;
                System.assertEquals('scheduled', l.bucket);
                System.assertEquals('001', l.num);
                System.assertEquals('Not Started', l.takeoff);
            }
        }

        System.assert(foundBuilder,  'Should find test builder');
        System.assert(foundDivision, 'Should find test division');
        System.assert(foundComm,     'Should find test community');
        System.assert(foundLot,      'Should find test lot');
    }

    @IsTest
    static void bucketMapCoversAllKnownValues() {
        Test.startTest();
        AccountCommunityLotWorkbenchController.WorkbenchPageDTO dto =
            AccountCommunityLotWorkbenchController.getWorkbenchData();
        Test.stopTest();
        // All lots should have a non-null bucket (default '90+' for unmapped)
        for (AccountCommunityLotWorkbenchController.LotDTO l : dto.lots) {
            System.assertNotEquals(null, l.bucket, 'Every lot should have a bucket');
        }
    }
}