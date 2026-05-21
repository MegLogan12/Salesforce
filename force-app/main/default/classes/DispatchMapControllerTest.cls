@IsTest
private class DispatchMapControllerTest {

    @TestSetup
    static void makeData() {
        // Vehicle with fresh GPS data (today, Active status)
        Vehicle__c v = new Vehicle__c(
            GPS_Latitude__c  = 35.154,
            GPS_Longitude__c = -80.852,
            GPS_Last_Seen__c = DateTime.now(),
            GPS_Status__c    = 'Active',
            Status__c        = 'Active'
        );
        insert v;

        // Test user to serve as crew foreman
        Profile pr = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Username          = 'dispatch.' + System.currentTimeMillis() + '@testloving.invalid',
            Email             = 'dispatch@testloving.invalid',
            LastName          = 'DriverZ',
            Alias             = 'drvz',
            ProfileId         = pr.Id,
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        // Crew linked to vehicle
        Crew__c c = new Crew__c(
            Active__c       = true,
            Vehicle__c      = v.Id,
            Foreman__c      = testUser.Id,
            Truck_Number__c = '999'
        );
        insert c;
    }

    @IsTest
    static void testGetTodayDispatch_withData() {
        Test.startTest();
        List<DispatchMapController.TruckPin> pins = DispatchMapController.getTodayDispatch();
        Test.stopTest();

        System.assertNotEquals(null, pins, 'Result must not be null');
        System.assert(pins.size() >= 1, 'Expected at least one pin from test crew+vehicle');

        DispatchMapController.TruckPin first = pins[0];
        System.assertNotEquals(null, first.appointmentNumber, 'Pin must have appointmentNumber set');
        System.assertEquals('Active', first.status, 'Status should reflect GPS_Status__c');
    }

    @IsTest
    static void testGetTodayDispatch_driverAssignment() {
        Test.startTest();
        List<DispatchMapController.TruckPin> pins = DispatchMapController.getTodayDispatch();
        Test.stopTest();

        Boolean foundDriver = false;
        for (DispatchMapController.TruckPin p : pins) {
            if (p.driverName != null && p.driverName.contains('DriverZ')) {
                foundDriver = true;
            }
        }
        System.assert(foundDriver, 'At least one pin should have DriverZ as foreman/driverName');
    }

    @IsTest
    static void testGetTodayDispatch_returnsListNotNull() {
        Test.startTest();
        List<DispatchMapController.TruckPin> pins = DispatchMapController.getTodayDispatch();
        Test.stopTest();

        System.assertNotEquals(null, pins, 'getTodayDispatch must never return null');
    }

    @IsTest
    static void testGetTodayDispatch_gpsFieldsPopulated() {
        Test.startTest();
        List<DispatchMapController.TruckPin> pins = DispatchMapController.getTodayDispatch();
        Test.stopTest();

        System.assert(pins.size() >= 1, 'Need at least one pin');
        DispatchMapController.TruckPin p = pins[0];
        System.assertNotEquals(null, p.lat,      'lat must be set from Vehicle GPS');
        System.assertNotEquals(null, p.lng,      'lng must be set from Vehicle GPS');
        System.assertNotEquals(null, p.lastSeen, 'lastSeen must be set');
        System.assertNotEquals(null, p.truckNumber, 'truckNumber must be set');
    }
}
