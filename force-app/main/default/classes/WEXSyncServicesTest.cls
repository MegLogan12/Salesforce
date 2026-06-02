@IsTest
private class WEXSyncServicesTest {

    // ── Shared mock infrastructure ────────────────────────────────────────────

    /**
     * Routes callouts by path:
     *   /userauth/login  → token response
     *   /vehicle         → vehicle list (no location fields)
     *   /vehicle/location → vehicle location list
     *   /driver          → driver list
     */
    private class MultiEndpointMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String ep = req.getEndpoint();
            String recentFixTime = DateTime.now().addMinutes(-5).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

            if (ep.contains('userauth/login')) {
                res.setBody('{"data":{"token":"mock-session-token"}}');
            } else if (ep.contains('vehicle/location')) {
                res.setBody('{"data":[{'
                    + '"id":"VV001","latitude":33.66,"longitude":-111.92,'
                    + '"fix_time_gmt":"' + recentFixTime + '","inst_speed":25,'
                    + '"heading":90,"ignition":"on","address":"456 Elm St",'
                    + '"first_name":"Jane","last_name":"Smith"}]}');
            } else if (ep.contains('/vehicle')) {
                res.setBody('{"data":[{'
                    + '"id":"VV001","label":"Truck 1","make":"Ford","model":"F-150",'
                    + '"year":2021,"vin":"1FTFW1E5XMFC00001",'
                    + '"license_plate":"ABC-123","odometer":15000}]}');
            } else if (ep.contains('/driver')) {
                res.setBody('{"data":[{'
                    + '"id":"DR001","first_name":"Jane","last_name":"Smith",'
                    + '"vehicle_id":"VV001","active":true}]}');
            } else {
                res.setBody('{"data":[]}');
            }
            return res;
        }
    }

    private class EmptyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"data":[]}');
            return res;
        }
    }

    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"internal server error"}');
            return res;
        }
    }

    // ── Test setup ────────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        // Config with valid cached token so no login callout is needed in most tests
        GPS_Insight_Config__c cfg = new GPS_Insight_Config__c();
        cfg.Username__c      = 'testuser';
        cfg.App_Token__c     = 'testapp';
        cfg.Session_Token__c = 'valid-cached-token';
        cfg.Token_Expiry__c  = DateTime.now().addDays(3);
        upsert cfg;
    }

    // ── WEXVehicleSyncService ─────────────────────────────────────────────────

    @IsTest
    static void vehicleSync_insertsNewVehicle() {
        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXVehicleSyncService.sync();
        Test.stopTest();

        List<Vehicle__c> vehicles = [
            SELECT Id, GPS_Insights_Id__c, Make__c, Model__c, Year__c, VIN__c, License_Plate__c
            FROM Vehicle__c
            WHERE GPS_Insights_Id__c = 'VV001'
        ];
        System.assertEquals(1, vehicles.size(), 'Should insert one new vehicle');
        System.assertEquals('Ford',         vehicles[0].Make__c);
        System.assertEquals('F-150',        vehicles[0].Model__c);
        System.assertEquals(2021,           vehicles[0].Year__c.intValue());
        System.assertEquals('1FTFW1E5XMFC00001', vehicles[0].VIN__c);
        System.assertEquals('ABC-123',      vehicles[0].License_Plate__c);
    }

    @IsTest
    static void vehicleSync_updatesExistingVehicle() {
        Vehicle__c existing = new Vehicle__c(
            GPS_Insights_Id__c = 'VV001',
            Make__c            = 'Chevy',
            Model__c           = 'Silverado'
        );
        insert existing;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXVehicleSyncService.sync();
        Test.stopTest();

        Vehicle__c updated = [SELECT Make__c, Model__c FROM Vehicle__c WHERE GPS_Insights_Id__c = 'VV001'];
        System.assertEquals('Ford',  updated.Make__c,  'Make should be updated from GPS');
        System.assertEquals('F-150', updated.Model__c, 'Model should be updated from GPS');
    }

    @IsTest
    static void vehicleSync_emptyResponse_noRecords() {
        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        Test.startTest();
        WEXVehicleSyncService.sync();
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Vehicle__c WHERE GPS_Insights_Id__c != null];
        System.assertEquals(0, count, 'No vehicles should be created from empty response');
    }

    @IsTest
    static void vehicleSync_serverError_noRecords() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());
        Test.startTest();
        WEXVehicleSyncService.sync();
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Vehicle__c WHERE GPS_Insights_Id__c != null];
        System.assertEquals(0, count, 'No vehicles should be created on HTTP error');
    }

    @IsTest
    static void vehicleSync_applyFields_setsAllFields() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV999');
        Map<String, Object> row = new Map<String, Object>{
            'make'          => 'Toyota',
            'model'         => 'Tacoma',
            'year'          => '2022',
            'vin'           => 'TEST1234567890123',
            'license_plate' => 'XYZ-789',
            'odometer'      => '22500.5'
        };

        WEXVehicleSyncService.applyFields(veh, row);

        System.assertEquals('Toyota',            veh.Make__c);
        System.assertEquals('Tacoma',            veh.Model__c);
        System.assertEquals(2022,                veh.Year__c.intValue());
        System.assertEquals('TEST1234567890123', veh.VIN__c);
        System.assertEquals('XYZ-789',           veh.License_Plate__c);
        System.assertEquals(Decimal.valueOf('22500.5'), veh.Odometer_Miles__c);
    }

    // ── WEXLocationSyncService ────────────────────────────────────────────────

    @IsTest
    static void locationSync_createsPositionRecord() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXLocationSyncService.sync();
        Test.stopTest();

        List<WEX_GPS_Position__c> positions = [
            SELECT Id, Vehicle__c, Latitude__c, Longitude__c, Speed_MPH__c,
                   Ignition_Status__c, Source_System__c
            FROM WEX_GPS_Position__c
            WHERE Vehicle__c = :veh.Id
        ];
        System.assertEquals(1, positions.size(), 'Should create one position record');
        System.assertEquals(Decimal.valueOf('33.66'),  positions[0].Latitude__c);
        System.assertEquals(Decimal.valueOf('-111.92'), positions[0].Longitude__c);
        System.assertEquals(Decimal.valueOf('25'),     positions[0].Speed_MPH__c);
        System.assertEquals('On',    positions[0].Ignition_Status__c);
        System.assertEquals('WEX GPS', positions[0].Source_System__c);
    }

    @IsTest
    static void locationSync_updatesExistingPosition() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;
        WEX_GPS_Position__c oldPos = new WEX_GPS_Position__c(
            Vehicle__c   = veh.Id,
            Latitude__c  = Decimal.valueOf('30.0'),
            Longitude__c = Decimal.valueOf('-100.0'),
            Source_System__c = 'WEX GPS'
        );
        insert oldPos;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXLocationSyncService.sync();
        Test.stopTest();

        WEX_GPS_Position__c updated = [
            SELECT Latitude__c, Longitude__c FROM WEX_GPS_Position__c WHERE Vehicle__c = :veh.Id
        ];
        System.assertEquals(Decimal.valueOf('33.66'),  updated.Latitude__c,  'Latitude should update');
        System.assertEquals(Decimal.valueOf('-111.92'), updated.Longitude__c, 'Longitude should update');
    }

    @IsTest
    static void locationSync_linksDriverByAssignedDriver() {
        Crew__c crew = new Crew__c(Name = 'GPS Crew');
        insert crew;

        Employee__c emp = new Employee__c(
            Name          = 'Jane Smith',
            First_Name__c = 'Jane',
            Last_Name__c  = 'Smith',
            Status__c     = 'Active',
            Crew__c       = crew.Id
        );
        insert emp;

        Vehicle__c veh = new Vehicle__c(
            GPS_Insights_Id__c = 'VV001',
            Assigned_Driver__c = emp.Id
        );
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXLocationSyncService.sync();
        Test.stopTest();

        WEX_GPS_Position__c pos = [SELECT Driver__c, Crew__c FROM WEX_GPS_Position__c WHERE Vehicle__c = :veh.Id];
        System.assertEquals(emp.Id, pos.Driver__c, 'Should link driver via Assigned_Driver__c');
        System.assertEquals(crew.Id, pos.Crew__c, 'Should backfill crew from the linked employee');
    }

    @IsTest
    static void locationSync_linksCrewByVehicleFallback() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Crew__c crew = new Crew__c(
            Name = 'Vehicle Linked Crew',
            Vehicle__c = veh.Id
        );
        insert crew;

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id' => 'VV001',
                'latitude' => 35.10,
                'longitude' => -80.80,
                'inst_speed' => 0,
                'heading' => 180,
                'ignition' => 'off',
                'fix_time_gmt' => '2026-05-20T12:00:00+00:00'
            }
        };

        Test.startTest();
        WEXLocationSyncService.processPositions(rows);
        Test.stopTest();

        WEX_GPS_Position__c pos = [
            SELECT Driver__c, Crew__c
            FROM WEX_GPS_Position__c
            WHERE Vehicle__c = :veh.Id
        ];
        System.assertEquals(null, pos.Driver__c, 'Driver should remain null when no driver mapping exists');
        System.assertEquals(crew.Id, pos.Crew__c, 'Crew should resolve via Crew__c.Vehicle__c fallback');
    }

    @IsTest
    static void locationSync_linksDriverByNameFallback() {
        Employee__c emp = new Employee__c(
            Name          = 'Jane Smith',
            First_Name__c = 'Jane',
            Last_Name__c  = 'Smith',
            Status__c     = 'Active'
        );
        insert emp;

        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXLocationSyncService.sync();
        Test.stopTest();

        WEX_GPS_Position__c pos = [SELECT Driver__c FROM WEX_GPS_Position__c WHERE Vehicle__c = :veh.Id];
        System.assertEquals(emp.Id, pos.Driver__c, 'Should link driver via GPS name fallback');
    }

    @IsTest
    static void locationSync_backfillsExistingPositionsFromCrewForeman() {
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Crew__c crew = new Crew__c(
            Name = 'Backfill Crew',
            Vehicle__c = veh.Id,
            Foreman__c = currentUser.Id
        );
        insert crew;

        Employee__c foreman = new Employee__c(
            Name = 'Current User Foreman',
            First_Name__c = 'Current',
            Last_Name__c = 'User Foreman',
            Status__c = 'Active',
            User__c = currentUser.Id
        );
        insert foreman;

        WEX_GPS_Position__c pos = new WEX_GPS_Position__c(
            Vehicle__c = veh.Id,
            Latitude__c = 33.66,
            Longitude__c = -111.92,
            Source_System__c = 'WEX GPS'
        );
        insert pos;

        Test.startTest();
        WEXLocationSyncService.backfillExistingPositionAssignments();
        Test.stopTest();

        pos = [
            SELECT Driver__c, Crew__c
            FROM WEX_GPS_Position__c
            WHERE Id = :pos.Id
        ];
        veh = [SELECT Assigned_Driver__c FROM Vehicle__c WHERE Id = :veh.Id];

        System.assertEquals(crew.Id, pos.Crew__c, 'Existing position should inherit crew from vehicle-linked crew');
        System.assertEquals(foreman.Id, pos.Driver__c, 'Existing position should inherit driver from crew foreman');
        System.assertEquals(foreman.Id, veh.Assigned_Driver__c, 'Vehicle should inherit assigned driver during backfill');
    }

    static void locationSync_mirrorsVehicleFields() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXLocationSyncService.sync();
        Test.stopTest();

        Vehicle__c updated = [
            SELECT GPS_Latitude__c, GPS_Longitude__c, GPS_Status__c,
                   Last_Location_Address__c, Last_GPS_Sync__c
            FROM Vehicle__c
            WHERE Id = :veh.Id
        ];
        System.assertEquals(Decimal.valueOf('33.66'),  updated.GPS_Latitude__c);
        System.assertEquals(Decimal.valueOf('-111.92'), updated.GPS_Longitude__c);
        System.assertEquals('456 Elm St', updated.Last_Location_Address__c);
        System.assertNotEquals(null, updated.Last_GPS_Sync__c, 'Last GPS sync should be set');
    }

    @IsTest
    static void locationSync_noMatchingVehicles_noPositionCreated() {
        // GPS response has VV001 but no Vehicle__c with that GPS ID exists
        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXLocationSyncService.sync();
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM WEX_GPS_Position__c];
        System.assertEquals(0, count, 'No position should be created without a matching vehicle');
    }

    @IsTest
    static void locationSync_mapIgnitionStatus() {
        System.assertEquals('On',      WEXLocationSyncService.mapIgnitionStatus('on'));
        System.assertEquals('On',      WEXLocationSyncService.mapIgnitionStatus('true'));
        System.assertEquals('On',      WEXLocationSyncService.mapIgnitionStatus('1'));
        System.assertEquals('Off',     WEXLocationSyncService.mapIgnitionStatus('off'));
        System.assertEquals('Off',     WEXLocationSyncService.mapIgnitionStatus('false'));
        System.assertEquals('Unknown', WEXLocationSyncService.mapIgnitionStatus(null));
        System.assertEquals('Unknown', WEXLocationSyncService.mapIgnitionStatus('maybe'));
    }

    @IsTest
    static void locationSync_deriveGpsStatus() {
        DateTime now = DateTime.now();
        System.assertEquals('Active',  WEXLocationSyncService.deriveGpsStatus(now.addMinutes(-5),  now));
        System.assertEquals('Delayed', WEXLocationSyncService.deriveGpsStatus(now.addMinutes(-60), now));
        System.assertEquals('Offline', WEXLocationSyncService.deriveGpsStatus(now.addMinutes(-180),now));
        System.assertEquals('Unknown', WEXLocationSyncService.deriveGpsStatus(null, now));
    }

    // ── WEXDriverSyncService ──────────────────────────────────────────────────

    @IsTest
    static void driverSync_createsDriverAssignment() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Employee__c emp = new Employee__c(
            Name          = 'Jane Smith',
            First_Name__c = 'Jane',
            Last_Name__c  = 'Smith',
            Status__c     = 'Active'
        );
        insert emp;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXDriverSyncService.sync();
        Test.stopTest();

        List<Driver_Assignment__c> assignments = [
            SELECT Id, WEX_Driver_Id__c, Driver_Name__c, Is_Active__c,
                   Employee__c, Vehicle__c
            FROM Driver_Assignment__c
            WHERE WEX_Driver_Id__c = 'DR001'
        ];
        System.assertEquals(1, assignments.size(), 'Should create one driver assignment');
        System.assertEquals('Jane Smith', assignments[0].Driver_Name__c);
        System.assertEquals(true,         assignments[0].Is_Active__c);
        System.assertEquals(emp.Id,       assignments[0].Employee__c, 'Should resolve employee by name');
        System.assertEquals(veh.Id,       assignments[0].Vehicle__c,  'Should resolve vehicle by GPS ID');

        Vehicle__c updatedVehicle = [SELECT Assigned_Driver__c FROM Vehicle__c WHERE Id = :veh.Id];
        System.assertEquals(emp.Id, updatedVehicle.Assigned_Driver__c, 'Vehicle should inherit the active driver');
    }

    @IsTest
    static void driverSync_updatesExistingAssignment() {
        Driver_Assignment__c existing = new Driver_Assignment__c(
            WEX_Driver_Id__c = 'DR001',
            Driver_Name__c   = 'Old Name',
            Is_Active__c     = false
        );
        insert existing;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXDriverSyncService.sync();
        Test.stopTest();

        Driver_Assignment__c updated = [
            SELECT Driver_Name__c, Is_Active__c
            FROM Driver_Assignment__c
            WHERE WEX_Driver_Id__c = 'DR001'
        ];
        System.assertEquals('Jane Smith', updated.Driver_Name__c, 'Name should update');
        System.assertEquals(true,         updated.Is_Active__c,   'Active should update');
    }

    @IsTest
    static void driverSync_emptyResponse_noRecords() {
        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        Test.startTest();
        WEXDriverSyncService.sync();
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Driver_Assignment__c];
        System.assertEquals(0, count, 'No assignments should be created from empty response');
    }

    @IsTest
    static void driverSync_serverError_noRecords() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());
        Test.startTest();
        WEXDriverSyncService.sync();
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Driver_Assignment__c];
        System.assertEquals(0, count);
    }

    // ── GPSINTEGRATION ────────────────────────────────────────────────────────

    @IsTest
    static void gpsIntegration_locationsSync_createsPosition() {
        // Test that GPSINTEGRATION routes LOCATIONS to WEXLocationSyncService.
        // Each sync type runs as its own Queueable to avoid DML-then-callout restriction.
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        GPSINTEGRATION.run(GPSSyncType.LOCATIONS);
        Test.stopTest();

        Integer posCount = [SELECT COUNT() FROM WEX_GPS_Position__c];
        System.assertEquals(1, posCount, 'Position should be created via GPSINTEGRATION');
    }

    @IsTest
    static void gpsIntegration_locationsOnly_onlyPositionSync() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        GPSINTEGRATION.run(GPSSyncType.LOCATIONS);
        Test.stopTest();

        Integer posCount = [SELECT COUNT() FROM WEX_GPS_Position__c];
        System.assertEquals(1, posCount, 'Position should be created for LOCATIONS sync type');
    }

    @IsTest
    static void gpsIntegration_vehiclesOnly_createsVehicle() {
        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        GPSINTEGRATION.run(GPSSyncType.VEHICLES);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Vehicle__c WHERE GPS_Insights_Id__c = 'VV001'];
        System.assertEquals(1, count);
    }

    @IsTest
    static void gpsIntegration_driversOnly_createsAssignment() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Employee__c emp = new Employee__c(
            Name = 'Jane Smith', First_Name__c = 'Jane',
            Last_Name__c = 'Smith', Status__c = 'Active'
        );
        insert emp;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        GPSINTEGRATION.run(GPSSyncType.DRIVERS);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Driver_Assignment__c WHERE WEX_Driver_Id__c = 'DR001'];
        System.assertEquals(1, count, 'Driver assignment should be created');
    }

    @IsTest
    static void gpsIntegration_run_noArgs_enqueuesWithoutError() {
        // Exercises the run() no-arg factory and ALL branch of run(t)
        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        Test.startTest();
        GPSINTEGRATION.run();
        Test.stopTest();
        System.assert(true, 'run() with no args should not throw');
    }

    @IsTest
    static void gpsIntegration_exceptionLogged() {
        // No mock set and no cached token → doGet returns 401 → rows() is empty → no error
        // Verify it doesn't throw
        GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
        cfg.Username__c      = null;
        cfg.App_Token__c     = null;
        cfg.Session_Token__c = null;
        upsert cfg;

        Test.startTest();
        GPSINTEGRATION.run(GPSSyncType.LOCATIONS);
        Test.stopTest();

        // No exception should escape the execute() method
        System.assert(true, 'Should complete without throwing');
    }

    // ── GPSIntegrationScheduler ───────────────────────────────────────────────

    @IsTest
    static void scheduler_start_schedulesJob() {
        Test.startTest();
        GPSIntegrationScheduler.start();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = :GPSIntegrationScheduler.JOB_NAME
        ];
        System.assertEquals(1, jobs.size(), 'Scheduler should be registered');
    }

    @IsTest
    static void scheduler_stop_abortsJob() {
        GPSIntegrationScheduler.start();
        Test.startTest();
        GPSIntegrationScheduler.stop();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = :GPSIntegrationScheduler.JOB_NAME
        ];
        System.assertEquals(0, jobs.size(), 'Scheduler should be removed after stop()');
    }

    @IsTest
    static void scheduler_startTwice_onlyOneJob() {
        Test.startTest();
        GPSIntegrationScheduler.start();
        GPSIntegrationScheduler.start(); // second call should replace first
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = :GPSIntegrationScheduler.JOB_NAME
        ];
        System.assertEquals(1, jobs.size(), 'Only one scheduler job should exist');
    }
}