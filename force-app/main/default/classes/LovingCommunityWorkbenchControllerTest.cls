@IsTest
private class LovingCommunityWorkbenchControllerTest {

    @TestSetup
    static void setup() {
        // Builder_Parent account
        Account parentBuilder = new Account(
            Name = 'Test Builder Corp',
            RecordTypeId = getRecordTypeId('Account', 'Builder_Parent')
        );
        insert parentBuilder;

        // Builder_Market account (division)
        Account market = new Account(
            Name     = 'Test Builder Charlotte',
            ParentId = parentBuilder.Id,
            Phone    = '704-555-0001',
            RecordTypeId = getRecordTypeId('Account', 'Builder_Market')
        );
        insert market;

        // Community
        Community__c comm = new Community__c(
            Name                  = 'Test Community',
            Builder_Account__c    = market.Id,
            Community_Status__c   = 'Active',
            Number_Of_Lots__c     = 10,
            Active_Lot_Count__c   = 4,
            Closed_Lot_Count__c   = 2,
            Aqua_Customer__c      = true,
            Community_Address__c  = '123 Test Pkwy',
            Community_City__c     = 'Charlotte',
            Community_State__c    = 'NC'
        );
        insert comm;

        // Lot
        Lot__c lot = new Lot__c(
            Lot_Number__c         = '42',
            Community__c          = comm.Id,
            Street_Address__c     = '142 Test St',
            City__c               = 'Charlotte',
            State__c              = 'NC',
            Lot_Status__c         = 'Under Construction',
            Eight11_Task_Status__c = 'Filed',
            Spec_Type__c          = 'Average',
            Phase__c              = 'Phase 1',
            Lot_Latitude__c       = 35.2271,
            Lot_Longitude__c      = -80.8431
        );
        insert lot;
    }

    @IsTest
    static void testGetWorkbenchData() {
        Test.startTest();
        LovingCommunityWorkbenchController.WorkbenchDataDto result =
            LovingCommunityWorkbenchController.getWorkbenchData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result not null');
        System.assertNotEquals(null, result.builders, 'Builders not null');
        System.assertNotEquals(null, result.divisions, 'Divisions not null');
        System.assertNotEquals(null, result.communities, 'Communities not null');
        System.assertNotEquals(null, result.lots, 'Lots not null');

        // Verify community
        Boolean foundComm = false;
        for (LovingCommunityWorkbenchController.CommunityDto c : result.communities) {
            if (c.name == 'Test Community') {
                foundComm = true;
                System.assertEquals('Active Selling', c.stage, 'Active maps to Active Selling');
                System.assertEquals(10, c.totalLots, 'Total lots');
                System.assertEquals(4,  c.activeLots, 'Active lots');
                System.assertEquals(2,  c.closedLots, 'Closed lots');
                System.assertEquals(1,  c.phases,     'Phases defaults to 1');
                System.assertEquals(true, c.aqua, 'Aqua customer');
                System.assert(c.address.contains('Charlotte'), 'Address has city');
            }
        }
        System.assert(foundComm, 'Test community found');

        // Verify lot
        Boolean foundLot = false;
        for (LovingCommunityWorkbenchController.LotDto l : result.lots) {
            if (l.num == '42') {
                foundLot = true;
                System.assertEquals('60+',   l.bucket,  'Under Construction → 60+');
                System.assertEquals('Filed',  l.eighty11, '811 status');
                System.assertEquals('Average',l.specType, 'Spec type');
                System.assertEquals('Phase 1',l.phase,    'Phase');
                System.assert(l.gps.contains('35.2271'), 'GPS latitude present');
                System.assert(l.address.contains('Charlotte'), 'Lot address has city');
            }
        }
        System.assert(foundLot, 'Test lot found');
    }

    @IsTest
    static void testEmptyOrg() {
        // Run against an org with no matching data (different community status)
        delete [SELECT Id FROM Lot__c];
        delete [SELECT Id FROM Community__c];
        delete [SELECT Id FROM Account WHERE RecordType.DeveloperName IN ('Builder_Parent','Builder_Market')];

        Test.startTest();
        LovingCommunityWorkbenchController.WorkbenchDataDto result =
            LovingCommunityWorkbenchController.getWorkbenchData();
        Test.stopTest();

        System.assertEquals(0, result.builders.size(),    'No builders');
        System.assertEquals(0, result.divisions.size(),   'No divisions');
        System.assertEquals(0, result.communities.size(), 'No communities');
        System.assertEquals(0, result.lots.size(),        'No lots');
    }

    @IsTest
    static void testStageMapping() {
        Community__c built = new Community__c(
            Name                 = 'Built Out Community',
            Community_Status__c  = 'Built Out',
            Number_Of_Lots__c    = 5
        );
        Community__c onHold = new Community__c(
            Name                 = 'On Hold Community',
            Community_Status__c  = 'On Hold',
            Number_Of_Lots__c    = 5
        );
        insert new List<Community__c>{ built, onHold };

        Test.startTest();
        LovingCommunityWorkbenchController.WorkbenchDataDto result =
            LovingCommunityWorkbenchController.getWorkbenchData();
        Test.stopTest();

        for (LovingCommunityWorkbenchController.CommunityDto c : result.communities) {
            if (c.name == 'Built Out Community') {
                System.assertEquals('Fully Sold', c.stage, 'Built Out → Fully Sold');
            }
            if (c.name == 'On Hold Community') {
                System.assertEquals('On Hold', c.stage, 'On Hold → On Hold');
            }
        }
    }

    @IsTest
    static void testLotBucketMapping() {
        Community__c comm = new Community__c(
            Name                = 'Bucket Test Comm',
            Community_Status__c = 'Active',
            Number_Of_Lots__c   = 10
        );
        insert comm;

        List<Lot__c> lots = new List<Lot__c>{
            new Lot__c(Lot_Number__c = '1', Community__c = comm.Id, Lot_Status__c = 'Open'),
            new Lot__c(Lot_Number__c = '2', Community__c = comm.Id, Lot_Status__c = 'PO Received'),
            new Lot__c(Lot_Number__c = '3', Community__c = comm.Id, Lot_Status__c = 'Pending Takeoff'),
            new Lot__c(Lot_Number__c = '4', Community__c = comm.Id, Lot_Status__c = 'Clear for Schedule'),
            new Lot__c(Lot_Number__c = '5', Community__c = comm.Id, Lot_Status__c = 'Scheduled'),
            new Lot__c(Lot_Number__c = '6', Community__c = comm.Id, Lot_Status__c = 'In Progress'),
            new Lot__c(Lot_Number__c = '7', Community__c = comm.Id, Lot_Status__c = 'Installed')
        };
        insert lots;

        Test.startTest();
        LovingCommunityWorkbenchController.WorkbenchDataDto result =
            LovingCommunityWorkbenchController.getWorkbenchData();
        Test.stopTest();

        Map<String, String> bucketByNum = new Map<String, String>();
        for (LovingCommunityWorkbenchController.LotDto l : result.lots) {
            bucketByNum.put(l.num, l.bucket);
        }

        System.assertEquals('90+',       bucketByNum.get('1'), 'Open → 90+');
        System.assertEquals('30',        bucketByNum.get('2'), 'PO Received → 30');
        System.assertEquals('takeoff',   bucketByNum.get('3'), 'Pending Takeoff → takeoff');
        System.assertEquals('clear',     bucketByNum.get('4'), 'Clear for Schedule → clear');
        System.assertEquals('scheduled', bucketByNum.get('5'), 'Scheduled → scheduled');
        System.assertEquals('active',    bucketByNum.get('6'), 'In Progress → active');
        System.assertEquals('closed',    bucketByNum.get('7'), 'Installed → closed');
    }

    private static Id getRecordTypeId(String sObjectName, String devName) {
        return [SELECT Id FROM RecordType
                WHERE SObjectType = :sObjectName
                AND DeveloperName = :devName
                LIMIT 1].Id;
    }
}