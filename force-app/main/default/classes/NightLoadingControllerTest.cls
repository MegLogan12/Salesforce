@IsTest(SeeAllData=false)
private class NightLoadingControllerTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static List<Loading_Ticket__c> makeTickets() {
        return new List<Loading_Ticket__c>{
            new Loading_Ticket__c(
                Truck_Number__c      = 1,
                Status__c            = 'Not Submitted',
                Scheduled_Date__c    = Date.today().addDays(1)
            ),
            new Loading_Ticket__c(
                Truck_Number__c      = 2,
                Status__c            = 'Loaded',
                Scheduled_Date__c    = Date.today().addDays(1)
            )
        };
    }

    // ── Test 1: buildView counts loaded vs pending correctly ──────────────────

    @IsTest
    static void buildView_countsLoadedVsPending() {
        List<Loading_Ticket__c> tickets = makeTickets();
        insert tickets;

        Test.startTest();
        NightLoadingController.NightLoadingView view =
            NightLoadingController.buildView(tickets);
        Test.stopTest();

        System.assertEquals(2, view.totalTrucks,
            'Total trucks should be 2.');
        System.assertEquals(1, view.loadedCount,
            'Exactly 1 ticket should be marked loaded.');
        System.assertEquals(1, view.pendingCount,
            'Exactly 1 ticket should be pending (Not Submitted).');

        // Verify isLoaded flag on each row
        Boolean foundLoaded  = false;
        Boolean foundPending = false;
        for (NightLoadingController.TruckRow row : view.trucks) {
            if (row.truckNumber == '2') { foundLoaded  = row.isLoaded; }
            if (row.truckNumber == '1') { foundPending = !row.isLoaded; }
        }
        System.assert(foundLoaded,  'TRUCK-02 (Status=Loaded) should have isLoaded=true.');
        System.assert(foundPending, 'TRUCK-01 (Status=Not Submitted) should have isLoaded=false.');
    }

    // ── Test 2: buildView handles an empty ticket list without error ──────────

    @IsTest
    static void buildView_emptyList() {
        Test.startTest();
        NightLoadingController.NightLoadingView view =
            NightLoadingController.buildView(new List<Loading_Ticket__c>());
        Test.stopTest();

        System.assertEquals(0, view.totalTrucks,
            'Total trucks should be 0 for an empty input.');
        System.assertEquals(0, view.loadedCount,
            'Loaded count should be 0 for an empty input.');
        System.assertEquals(0, view.pendingCount,
            'Pending count should be 0 for an empty input.');
        System.assertNotEquals(null, view.trucks,
            'Trucks list should not be null.');
    }

    // ── Test: getLoadingQueue covers SOQL path with real org data ──────────────

    @IsTest(SeeAllData=true)
    static void getLoadingQueue_integration() {
        Test.startTest();
        NightLoadingController.NightLoadingView v = NightLoadingController.getLoadingQueue();
        Test.stopTest();
        System.assertNotEquals(null, v, 'view should not be null');
        System.assertNotEquals(null, v.trucks, 'trucks list should not be null');
    }

    // ── Test 3: markLoaded updates Status__c to Loaded ────────────────────────

    @IsTest
    static void markLoaded_updatesStatus() {
        Loading_Ticket__c ticket = new Loading_Ticket__c(
            Truck_Number__c   = 3,
            Status__c         = 'Not Submitted',
            Scheduled_Date__c = Date.today().addDays(1)
        );
        insert ticket;

        Test.startTest();
        NightLoadingController.markLoaded(ticket.Id);
        Test.stopTest();

        Loading_Ticket__c updated = [
            SELECT Status__c FROM Loading_Ticket__c WHERE Id = :ticket.Id
        ];
        System.assertEquals('Loaded', updated.Status__c,
            'Status__c should be updated to Loaded by markLoaded().');
    }
}
