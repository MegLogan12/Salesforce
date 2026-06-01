@IsTest
private class LovingLotWorkspaceControllerTest {

    @TestSetup
    static void makeData() {
        try {
            Extentia_SIM__MapPlotterTriggerSettings__c bypass =
                Extentia_SIM__MapPlotterTriggerSettings__c.getOrgDefaults();
            bypass.Extentia_SIM__Bypass_Trigger__c = true;
            upsert bypass;
        } catch (Exception e) {}

        Community__c community = new Community__c(Name = 'Test Community LLW');
        insert community;

        List<Lot__c> lots = new List<Lot__c>();
        // New — far-out install date (>90 days)
        lots.add(new Lot__c(Name = 'LLW-101', Community__c = community.Id,
            Lot_Number__c = '101', Requested_Install_Date__c = Date.today().addDays(120)));
        // Pending Scheduling — close install date (<90 days)
        lots.add(new Lot__c(Name = 'LLW-102', Community__c = community.Id,
            Lot_Number__c = '102', Requested_Install_Date__c = Date.today().addDays(30)));
        // Closed — via Lot_Status__c (valid picklist value)
        lots.add(new Lot__c(Name = 'LLW-103', Community__c = community.Id,
            Lot_Number__c = '103', Lot_Status__c = 'Closed'));
        // Site Ready — Lot_Status__c = 'Clear for Schedule' normalizes to 'Site Ready'
        lots.add(new Lot__c(Name = 'LLW-104', Community__c = community.Id,
            Lot_Number__c = '104', Lot_Status__c = 'Clear for Schedule'));
        // QI — Lot_Status__c = 'Pending Closeout' normalizes to 'QI'
        lots.add(new Lot__c(Name = 'LLW-105', Community__c = community.Id,
            Lot_Number__c = '105', Lot_Status__c = 'Pending Closeout'));
        // Invoiced — Pipeline_Bucket__c (unrestricted picklist, new value)
        lots.add(new Lot__c(Name = 'LLW-106', Community__c = community.Id,
            Lot_Number__c = '106', Pipeline_Bucket__c = 'Invoiced'));
        // Old value normalization: 90+ Days → New
        lots.add(new Lot__c(Name = 'LLW-107', Community__c = community.Id,
            Lot_Number__c = '107', Pipeline_Bucket__c = '90+ Days'));
        // Pending Scheduling — Lot_Status__c 'Pending Takeoff' normalizes to 'Pending Scheduling'
        lots.add(new Lot__c(Name = 'LLW-108', Community__c = community.Id,
            Lot_Number__c = '108', Lot_Status__c = 'Pending Takeoff'));
        // Site Ready — old Pipeline_Bucket__c value normalizes
        lots.add(new Lot__c(Name = 'LLW-109', Community__c = community.Id,
            Lot_Number__c = '109', Pipeline_Bucket__c = 'Clear for Schedule'));
        // Takeoff Complete — Pipeline_Bucket__c set directly (unrestricted)
        lots.add(new Lot__c(Name = 'LLW-110', Community__c = community.Id,
            Lot_Number__c = '110', Pipeline_Bucket__c = 'Takeoff Complete'));
        // In Progress — Lot_Status__c valid value passes through
        lots.add(new Lot__c(Name = 'LLW-111', Community__c = community.Id,
            Lot_Number__c = '111', Lot_Status__c = 'In Progress'));
        // Scheduled — Lot_Status__c valid value passes through
        lots.add(new Lot__c(Name = 'LLW-112', Community__c = community.Id,
            Lot_Number__c = '112', Lot_Status__c = 'Scheduled'));
        // Ready to Invoice — Pipeline_Bucket__c new value
        lots.add(new Lot__c(Name = 'LLW-113', Community__c = community.Id,
            Lot_Number__c = '113', Pipeline_Bucket__c = 'Ready to Invoice'));
        insert lots;
    }

    @IsTest
    static void testGetLotsWorkspace() {
        Test.startTest();
        LovingLotWorkspaceController.LotsWorkspaceDTO result =
            LovingLotWorkspaceController.getLotsWorkspace();
        Test.stopTest();

        System.assertNotEquals(null, result, 'DTO should not be null');
        System.assertNotEquals(null, result.rows, 'rows should not be null');
        System.assert(result.lotCount > 0, 'should have lots');
        System.assertNotEquals(null, result.columns, 'columns should not be null');
        System.assertNotEquals(null, result.pipelineOptions, 'pipelineOptions should not be null');

        Map<String, String> bucketByNumber = new Map<String, String>();
        Map<String, String> classByNumber  = new Map<String, String>();
        for (LovingLotWorkspaceController.LotListRowDTO row : result.rows) {
            bucketByNumber.put(row.lotNumber, row.pipelineBucket);
            classByNumber.put(row.lotNumber,  row.pipelineClass);
        }

        System.assertEquals('New',               bucketByNumber.get('101'), 'Far-out lot should be New');
        System.assertEquals('Pending Scheduling', bucketByNumber.get('102'), '30-day lot should be Pending Scheduling');
        System.assertEquals('Closed',             bucketByNumber.get('103'), 'Closed lot should be Closed');
        System.assertEquals('Site Ready',         bucketByNumber.get('104'), 'Clear for Schedule status → Site Ready');
        System.assertEquals('QI',                 bucketByNumber.get('105'), 'Pending Closeout status → QI');
        System.assertEquals('Invoiced',           bucketByNumber.get('106'), 'Invoiced bucket should pass through');
        System.assertEquals('New',                bucketByNumber.get('107'), '90+ Days bucket → New');
        System.assertEquals('Pending Scheduling', bucketByNumber.get('108'), 'Pending Takeoff status → Pending Scheduling');
        System.assertEquals('Site Ready',         bucketByNumber.get('109'), 'Clear for Schedule bucket → Site Ready');
        System.assertEquals('Takeoff Complete',   bucketByNumber.get('110'), 'Takeoff Complete bucket passes through');
        System.assertEquals('In Progress',        bucketByNumber.get('111'), 'In Progress status passes through');
        System.assertEquals('Scheduled',          bucketByNumber.get('112'), 'Scheduled status passes through');
        System.assertEquals('Ready to Invoice',   bucketByNumber.get('113'), 'Ready to Invoice bucket passes through');

        System.assertEquals('pb-new',      classByNumber.get('101'), 'New → pb-new');
        System.assertEquals('pb-pending',  classByNumber.get('102'), 'Pending Scheduling → pb-pending');
        System.assertEquals('pb-closed',   classByNumber.get('103'), 'Closed → pb-closed');
        System.assertEquals('pb-clear',    classByNumber.get('104'), 'Site Ready → pb-clear');
        System.assertEquals('pb-qi',       classByNumber.get('105'), 'QI → pb-qi');
        System.assertEquals('pb-invoiced', classByNumber.get('106'), 'Invoiced → pb-invoiced');
        System.assertEquals('pb-takeoff',  classByNumber.get('110'), 'Takeoff Complete → pb-takeoff');
        System.assertEquals('pb-active',   classByNumber.get('111'), 'In Progress → pb-active');
        System.assertEquals('pb-sched',    classByNumber.get('112'), 'Scheduled → pb-sched');
        System.assertEquals('pb-invoice',  classByNumber.get('113'), 'Ready to Invoice → pb-invoice');
    }

    @IsTest
    static void testGetLotDetail() {
        Lot__c lot = [SELECT Id FROM Lot__c WHERE Lot_Number__c = '101' LIMIT 1];
        Test.startTest();
        LovingLotWorkspaceController.LotDetailDTO result =
            LovingLotWorkspaceController.getLotDetail(lot.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Detail DTO should not be null');
        System.assertEquals(lot.Id, result.lotId, 'Lot ID should match');
        System.assertNotEquals(null, result.timeline, 'timeline should not be null');
        System.assertNotEquals(null, result.workOrders, 'workOrders list should not be null');
        System.assertEquals('New', result.pipelineBucket, 'Far-out lot detail should have New pipeline bucket');
    }

    @IsTest
    static void testGetLotDetailNull() {
        Test.startTest();
        LovingLotWorkspaceController.LotDetailDTO result =
            LovingLotWorkspaceController.getLotDetail(null);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return empty DTO for null input');
        System.assertEquals(null, result.lotId, 'lotId should be null for null input');
    }

    @IsTest
    static void testGetLotDetailMissingId() {
        Test.startTest();
        // Pass a non-Lot ID — controller should return empty detail (query returns empty)
        LovingLotWorkspaceController.LotDetailDTO result =
            LovingLotWorkspaceController.getLotDetail(UserInfo.getUserId());
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return empty DTO for non-lot id');
    }
}
