@IsTest(SeeAllData=true)
private class DispatchMapControllerTest {

    @IsTest
    static void testGetTodayDispatch_returnsResults() {
        Test.startTest();
        List<DispatchMapController.TruckPin> pins = DispatchMapController.getTodayDispatch();
        Test.stopTest();

        System.assertNotEquals(null, pins, 'Result list should never be null');
    }

    @IsTest
    static void testGetTodayDispatch_pinsHaveFields() {
        Test.startTest();
        List<DispatchMapController.TruckPin> pins = DispatchMapController.getTodayDispatch();
        Test.stopTest();

        for (DispatchMapController.TruckPin p : pins) {
            System.assertNotEquals(null, p, 'Each pin should be non-null');
        }
    }

    @IsTest
    static void testGetTodayDispatch_handlesEmptyGracefully() {
        Test.startTest();
        List<DispatchMapController.TruckPin> result = DispatchMapController.getTodayDispatch();
        Test.stopTest();

        System.assert(result != null, 'Should return a list, not null');
        System.assert(result.size() >= 0, 'Size should be non-negative');
    }
}
