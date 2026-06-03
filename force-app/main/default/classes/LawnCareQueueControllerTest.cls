/**
 * LawnCareQueueControllerTest
 * Coverage for LawnCareQueueController.
 *
 * Uses SeeAllData=false. Because WorkOrder cannot be INSERTed in a test context
 * (a before-save Flow blocks all inserts), all three tests exercise buildView
 * directly with in-memory WorkOrder stubs — no DML is performed.
 *
 * In-memory stubs are created with Test.createStub / constructor tricks; the
 * simplest safe approach is to create WorkOrder instances without saving them
 * and set the fields Apex allows without hitting the DB.
 */
@IsTest(SeeAllData=false)
private class LawnCareQueueControllerTest {

    // ─── Helper: build an unsaved in-memory WorkOrder stub ───────────────────

    /**
     * Returns an in-memory WorkOrder with the supplied Crew__c value.
     * No INSERT — just uses the SObject constructor with field map.
     */
    private static WorkOrder makeStub(Id crewId, String woNumber, String status) {
        WorkOrder wo = new WorkOrder(
            Subject              = 'Lawn Care Test - ' + woNumber,
            Work_Order_Type__c   = 'Standard Mow',
            Job_Type__c          = 'Lawn Care',
            Status               = status,
            Crew__c              = crewId,
            Scheduled_Date__c    = Date.today()
        );
        return wo;
    }

    // ─── Test 1: empty list returns zero counts ───────────────────────────────

    @IsTest
    static void buildView_empty() {
        Test.startTest();
        LawnCareQueueController.LawnCareView view =
            LawnCareQueueController.buildView(new List<WorkOrder>());
        Test.stopTest();

        System.assertEquals(0, view.totalDueThisWeek, 'totalDueThisWeek should be 0 for empty list');
        System.assertEquals(0, view.unassigned,        'unassigned should be 0 for empty list');
        System.assertEquals(0, view.rows.size(),       'rows should be empty');
    }

    // ─── Test 2: WO with Crew__c = null is flagged as unassigned ─────────────

    @IsTest
    static void buildView_unassignedCrew_flagged() {
        WorkOrder wo = makeStub(null, 'WO-001', 'New');

        Test.startTest();
        LawnCareQueueController.LawnCareView view =
            LawnCareQueueController.buildView(new List<WorkOrder>{ wo });
        Test.stopTest();

        System.assertEquals(1, view.totalDueThisWeek, 'totalDueThisWeek should be 1');
        System.assertEquals(1, view.unassigned,        'unassigned should be 1');
        System.assertEquals(1, view.rows.size(),       'rows should have 1 entry');

        LawnCareQueueController.LcRow row = view.rows[0];
        System.assertEquals(true, row.isUnassigned, 'isUnassigned should be true when Crew__c is null');
        System.assertEquals(null, row.crewName,     'crewName should be null when unassigned');
    }

    // ─── Test 3: WO with a Crew__c Id is NOT flagged as unassigned ───────────

    @IsTest
    static void buildView_assignedCrew_notFlagged() {
        // Use a fake Id in the correct format for a generic SObject (Account used as surrogate)
        Id fakeCrewId = '001000000000001AAA';
        WorkOrder wo  = makeStub(fakeCrewId, 'WO-002', 'Scheduled');

        Test.startTest();
        LawnCareQueueController.LawnCareView view =
            LawnCareQueueController.buildView(new List<WorkOrder>{ wo });
        Test.stopTest();

        System.assertEquals(1, view.totalDueThisWeek, 'totalDueThisWeek should be 1');
        System.assertEquals(0, view.unassigned,        'unassigned should be 0 for assigned crew');
        System.assertEquals(1, view.rows.size(),       'rows should have 1 entry');

        LawnCareQueueController.LcRow row = view.rows[0];
        System.assertEquals(false, row.isUnassigned, 'isUnassigned should be false when Crew__c is set');
        System.assertEquals('Standard Mow', row.serviceType, 'serviceType should come from Work_Order_Type__c');
        System.assertEquals('Lawn Care', wo.Job_Type__c, 'Job_Type__c should be Lawn Care');
    }
}
