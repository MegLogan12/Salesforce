/**
 * CooCommandCenterControllerTest
 * Tests CooCommandCenterController.buildDashboard() with in-memory stubs.
 * No WorkOrder DML — before-save Flow blocks all test WO inserts.
 */
@IsTest(SeeAllData=false)
private class CooCommandCenterControllerTest {

    // ─── Helper: build an in-memory WorkOrder stub ────────────────────────────

    private static WorkOrder stubWo(String division, String status) {
        WorkOrder wo = new WorkOrder();
        wo.Division__c = division;
        wo.Status      = status;
        return wo;
    }

    // ─── Test 1: empty lists → zero counts, structure intact ─────────────────

    @IsTest
    static void buildDashboard_emptyLists_returnsZeros() {
        Test.startTest();
        CooCommandCenterController.CooView v =
            CooCommandCenterController.buildDashboard(
                new List<WorkOrder>(),
                new List<Builder_PO__c>(),
                new List<WorkOrder>()
            );
        Test.stopTest();

        System.assertNotEquals(null, v,
            'buildDashboard should return a non-null CooView.');
        System.assertEquals(0, v.totalActiveWOs,
            'totalActiveWOs should be 0 when no active WOs provided.');
        System.assertNotEquals(null, v.divisions,
            'divisions list should never be null.');
        System.assertEquals(0, v.divisions.size(),
            'No divisions when no active WOs.');
        System.assertNotEquals(null, v.exceptions,
            'exceptions list should never be null.');
        System.assertNotEquals(null, v.gates,
            'gates list should never be null.');
        // Exception counts should all be 0
        for (CooCommandCenterController.ExceptionRow ex : v.exceptions) {
            System.assertEquals(0, ex.count,
                'Exception count should be 0 for: ' + ex.description);
        }
    }

    // ─── Test 2: open gates are always populated (hardcoded) ─────────────────

    @IsTest
    static void openGatesAlwaysPopulated() {
        Test.startTest();
        CooCommandCenterController.CooView v =
            CooCommandCenterController.buildDashboard(
                new List<WorkOrder>(),
                new List<Builder_PO__c>(),
                new List<WorkOrder>()
            );
        Test.stopTest();

        System.assertNotEquals(null, v.gates,
            'gates list should not be null.');
        System.assert(v.gates.size() > 0,
            'Open gates are hardcoded and should always be present.');
        System.assertEquals(v.gates.size(), v.totalOpenGates,
            'totalOpenGates should match gates list size.');

        // Each gate should have a non-blank gate label and owner
        for (CooCommandCenterController.OpenGate g : v.gates) {
            System.assert(String.isNotBlank(g.gate),
                'Each gate should have a non-blank gate label.');
            System.assert(String.isNotBlank(g.owner),
                'Each gate should have a non-blank owner.');
        }
    }

    // ─── Test 3: exception list is always included in buildDashboard ─────────

    @IsTest
    static void exceptionList_includedOnBuildDashboard() {
        // Provide stubs: 2 active WOs, 1 held PO, 3 pending closeout
        List<WorkOrder> activeWOs = new List<WorkOrder>{
            stubWo('Division A', 'Scheduled'),
            stubWo('Division B', 'In Progress')
        };
        List<Builder_PO__c> heldPOs = new List<Builder_PO__c>{
            new Builder_PO__c()
        };
        List<WorkOrder> pendingCloseout = new List<WorkOrder>{
            stubWo('Division A', 'Completed'),
            stubWo('Division B', 'Completed'),
            stubWo(null,         'Completed')
        };

        Test.startTest();
        CooCommandCenterController.CooView v =
            CooCommandCenterController.buildDashboard(
                activeWOs, heldPOs, pendingCloseout);
        Test.stopTest();

        System.assertNotEquals(null, v.exceptions,
            'exceptions should not be null.');
        System.assert(v.exceptions.size() > 0,
            'exceptions list should always have entries.');

        // Find the held-PO exception and verify count
        Boolean foundHeldPo = false;
        Boolean foundCloseout = false;
        for (CooCommandCenterController.ExceptionRow ex : v.exceptions) {
            if (ex.description != null && ex.description.containsIgnoreCase('Held PO')) {
                System.assertEquals(1, ex.count,
                    'Held PO count should be 1.');
                foundHeldPo = true;
            }
            if (ex.description != null && ex.description.containsIgnoreCase('Closeout')) {
                System.assertEquals(3, ex.count,
                    'Closeout count should be 3.');
                foundCloseout = true;
            }
        }
        System.assertEquals(true, foundHeldPo,   'Should find a Held PO exception row.');
        System.assertEquals(true, foundCloseout, 'Should find a Closeout exception row.');
        System.assertEquals(2, v.totalActiveWOs,  'totalActiveWOs should be 2.');
    }
}
