/**
 * CapacityForecastControllerTest
 * Tests CapacityForecastController using in-memory stubs (no WO DML)
 * and a SeeAllData=true query test for getForecast.
 */
@IsTest
private class CapacityForecastControllerTest {

    // ─── Test 1: getForecast queries real data and returns a non-null view ────
    // SeeAllData=true because we cannot INSERT WorkOrders in this org.

    @IsTest(SeeAllData=true)
    static void getForecast_returnsView() {
        Test.startTest();
        CapacityForecastController.ForecastView v =
            CapacityForecastController.getForecast(null);
        Test.stopTest();

        System.assertNotEquals(null, v,
            'getForecast should return a non-null ForecastView.');
        System.assertNotEquals(null, v.weeks,
            'weeks list should never be null.');
        System.assertEquals(6, v.weeks.size(),
            'Should always return exactly 6 week rows.');
        System.assertNotEquals(null, v.backlog,
            'backlog list should never be null.');
        System.assertNotEquals(null, v.zones,
            'zones list should never be null.');
    }

    // ─── Test 2: over-capacity detection with in-memory stubs ────────────────

    @IsTest(SeeAllData=false)
    static void buildForecast_overCapacity_detected() {
        // One active crew with capacity 1 hour/week
        Crew__c crew = new Crew__c();
        crew.Name                    = 'Test Crew Alpha';
        crew.Active__c               = true;
        crew.Weekly_Capacity_Hours__c = 1;

        // Five WOs all scheduled this coming Monday
        Date monday = Date.today().toStartOfWeek().addDays(1);
        List<WorkOrder> wos = new List<WorkOrder>();
        for (Integer i = 0; i < 5; i++) {
            WorkOrder wo = new WorkOrder();
            wo.WorkOrderNumber   = 'WO-OC-000' + i;
            wo.Status            = 'Scheduled';
            wo.Scheduled_Date__c = monday;
            wos.add(wo);
        }

        List<WorkOrder> backlog = new List<WorkOrder>();

        Test.startTest();
        CapacityForecastController.ForecastView v =
            CapacityForecastController.buildForecast(wos, new List<Crew__c>{ crew }, backlog);
        Test.stopTest();

        System.assertNotEquals(null, v, 'View should not be null.');
        System.assertEquals(6, v.weeks.size(), 'Expect 6 week rows.');

        // The first week should be over capacity (5 booked, capacity = 1)
        Boolean foundOverCapacity = false;
        for (CapacityForecastController.WeekRow wr : v.weeks) {
            if (wr.booked > 0 && wr.overCapacity) {
                foundOverCapacity = true;
            }
        }
        System.assertEquals(true, foundOverCapacity,
            'At least one week should be flagged over capacity.');
        System.assert(v.weeksOverCapacity > 0,
            'weeksOverCapacity should be > 0 when a week is over capacity.');
    }

    // ─── Test 3: empty crews → capacity = 0, overCapacity = false ────────────

    @IsTest(SeeAllData=false)
    static void buildForecast_emptyCrews_allCapacityZero() {
        // No crews — capacity should be zero for all weeks
        List<Crew__c> emptyCrews = new List<Crew__c>();

        // A couple of scheduled WOs
        Date monday = Date.today().toStartOfWeek().addDays(1);
        List<WorkOrder> wos = new List<WorkOrder>();
        WorkOrder wo = new WorkOrder();
        wo.WorkOrderNumber   = 'WO-EC-0001';
        wo.Status            = 'Scheduled';
        wo.Scheduled_Date__c = monday;
        wos.add(wo);

        Test.startTest();
        CapacityForecastController.ForecastView v =
            CapacityForecastController.buildForecast(wos, emptyCrews, new List<WorkOrder>());
        Test.stopTest();

        System.assertNotEquals(null, v, 'View should not be null.');
        for (CapacityForecastController.WeekRow wr : v.weeks) {
            System.assertEquals(0, wr.capacity,
                'Capacity should be zero when no crews provided.');
            System.assertEquals(false, wr.overCapacity,
                'overCapacity should be false when capacity is 0 (division by zero guard).');
        }
        System.assertEquals(0, v.weeksOverCapacity,
            'weeksOverCapacity should be 0 when no crews.');
    }
}
