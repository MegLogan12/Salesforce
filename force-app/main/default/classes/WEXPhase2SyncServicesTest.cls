@IsTest
private class WEXPhase2SyncServicesTest {

    // ── Shared mock infrastructure ────────────────────────────────────────────

    /**
     * Routes callouts by path:
     *   /userauth/login    → token response
     *   /landmark          → landmark list
     *   /vehicle/history   → breadcrumb history list
     *   /vehicle/diagnostic → diagnostic list
     *   /alert             → alert list
     *   /vehicle/ifta      → fuel transaction list
     */
    private class MultiEndpointMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String ep = req.getEndpoint();

            if (ep.contains('userauth/login')) {
                res.setBody('{"data":{"token":"mock-session-token"}}');
            } else if (ep.contains('vehicle/history')) {
                res.setBody('{"data":[{'
                    + '"id":"HIST001","vehicle_id":"VV001",'
                    + '"latitude":33.66,"longitude":-111.92,"heading":90,"speed":25,'
                    + '"odometer":15000,"ignition":"on","address":"123 Main St",'
                    + '"fix_time":"2024-06-01T14:00:00Z"}]}');
            } else if (ep.contains('vehicle/diagnostic')) {
                res.setBody('{"data":[{'
                    + '"id":"DIAG001","vehicle_id":"VV001","dtc_code":"P0300",'
                    + '"description":"Random misfire","severity":"critical",'
                    + '"reported_time":"2024-06-01T14:00:00Z","active":true}]}');
            } else if (ep.contains('vehicle/ifta')) {
                res.setBody('{"data":[{'
                    + '"id":"FUEL001","vehicle_id":"VV001","date":"2024-06-01",'
                    + '"gallons":12.5,"fuel_type":"Diesel","odometer":15500,"state":"AZ"}]}');
            } else if (ep.contains('/landmark')) {
                res.setBody('{"data":[{'
                    + '"id":"LM001","label":"Main Depot","latitude":33.5,"longitude":-111.9,'
                    + '"radius":100,"type":"circle","active":true}]}');
            } else if (ep.contains('/alert')) {
                res.setBody('{"alerts":[{'
                    + '"id":"ALT001","vehicle_id":"VV001","driver_id":"DR001",'
                    + '"alert_type":"speeding","severity":"high",'
                    + '"description":"Exceeded posted speed","alert_time":"2024-06-01T14:00:00Z"}]}');
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

    // Returns an alert with no driver_id field
    private class AlertNoDriverMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('/alert')) {
                res.setBody('{"alerts":[{"id":"ALT002","vehicle_id":"VV001",'
                    + '"alert_type":"harsh_brake","severity":"medium"}]}');
            } else {
                res.setBody('{"data":[]}');
            }
            return res;
        }
    }

    // ── Test setup ────────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        GPS_Insight_Config__c cfg = new GPS_Insight_Config__c();
        cfg.Username__c      = 'testuser';
        cfg.App_Token__c     = 'testapp';
        cfg.Session_Token__c = 'valid-cached-token';
        cfg.Token_Expiry__c  = DateTime.now().addDays(3);
        upsert cfg;
    }

    // ── WEXLandmarkSyncService ────────────────────────────────────────────────

    @IsTest
    static void landmarkSync_insertsNewLandmark() {
        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXLandmarkSyncService.sync();
        Test.stopTest();

        List<GPS_Landmark__c> lms = [
            SELECT Name, WEX_Landmark_Id__c, Latitude__c, Longitude__c,
                   Radius_Meters__c, Landmark_Type__c, Is_Active__c
            FROM GPS_Landmark__c
            WHERE WEX_Landmark_Id__c = 'LM001'
        ];
        System.assertEquals(1, lms.size(), 'Should insert one landmark');
        System.assertEquals('Main Depot', lms[0].Name);
        System.assertEquals(Decimal.valueOf('33.5'),   lms[0].Latitude__c);
        System.assertEquals(Decimal.valueOf('-111.9'), lms[0].Longitude__c);
        System.assertEquals(Decimal.valueOf('100'),    lms[0].Radius_Meters__c);
        System.assertEquals('circle', lms[0].Landmark_Type__c);
        System.assertEquals(true,     lms[0].Is_Active__c);
    }

    @IsTest
    static void landmarkSync_updatesExistingLandmark() {
        GPS_Landmark__c existing = new GPS_Landmark__c(
            Name              = 'Old Name',
            WEX_Landmark_Id__c = 'LM001',
            Is_Active__c      = false
        );
        insert existing;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXLandmarkSyncService.sync();
        Test.stopTest();

        GPS_Landmark__c updated = [SELECT Name, Is_Active__c FROM GPS_Landmark__c WHERE WEX_Landmark_Id__c = 'LM001'];
        System.assertEquals('Main Depot', updated.Name,        'Name should update from label');
        System.assertEquals(true,         updated.Is_Active__c,'Active should update');
    }

    @IsTest
    static void landmarkSync_emptyResponse_noRecords() {
        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        Test.startTest();
        WEXLandmarkSyncService.sync();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM GPS_Landmark__c]);
    }

    @IsTest
    static void landmarkSync_serverError_noRecords() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());
        Test.startTest();
        WEXLandmarkSyncService.sync();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM GPS_Landmark__c]);
    }

    @IsTest
    static void landmarkSync_applyFields_activeFalse() {
        GPS_Landmark__c lm = new GPS_Landmark__c(Name = 'X', WEX_Landmark_Id__c = 'X1');
        Map<String, Object> row = new Map<String, Object>{
            'label' => 'Test',
            'latitude' => '10.0', 'longitude' => '-20.0',
            'radius' => '50', 'type' => 'polygon',
            'active' => 'false'
        };
        WEXLandmarkSyncService.applyFields(lm, row);
        System.assertEquals(false, lm.Is_Active__c, 'active=false should set Is_Active__c false');
    }

    @IsTest
    static void landmarkSync_applyFields_activeZero() {
        GPS_Landmark__c lm = new GPS_Landmark__c(Name = 'X', WEX_Landmark_Id__c = 'X1');
        Map<String, Object> row = new Map<String, Object>{ 'active' => '0' };
        WEXLandmarkSyncService.applyFields(lm, row);
        System.assertEquals(false, lm.Is_Active__c, 'active=0 should set Is_Active__c false');
    }

    // ── WEXRouteSyncService ───────────────────────────────────────────────────

    @IsTest
    static void routeSync_createsVehicleLocation() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXRouteSyncService.sync();
        Test.stopTest();

        List<Vehicle_Location__c> locs = [
            SELECT GPS_Insights_Location_Id__c, Vehicle__c, Latitude__c, Longitude__c,
                   Speed_Mph__c, Odometer_Miles__c, Address__c, Ignition_On__c
            FROM Vehicle_Location__c
            WHERE GPS_Insights_Location_Id__c = 'HIST001'
        ];
        System.assertEquals(1, locs.size(), 'Should create one location record');
        System.assertEquals(veh.Id,              locs[0].Vehicle__c);
        System.assertEquals(Decimal.valueOf('33.66'),  locs[0].Latitude__c);
        System.assertEquals(Decimal.valueOf('-111.92'), locs[0].Longitude__c);
        System.assertEquals(Decimal.valueOf('25'),     locs[0].Speed_Mph__c);
        System.assertEquals(Decimal.valueOf('15000'),  locs[0].Odometer_Miles__c);
        System.assertEquals('123 Main St',             locs[0].Address__c);
        System.assertEquals(true,                      locs[0].Ignition_On__c);
    }

    @IsTest
    static void routeSync_skipsUnknownVehicle() {
        // No Vehicle__c with GPS_Insights_Id__c = 'VV001'
        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXRouteSyncService.sync();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Location__c],
            'No location should be created without matching vehicle');
    }

    @IsTest
    static void routeSync_customDateRange() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXRouteSyncService.sync(DateTime.now().addHours(-4), DateTime.now());
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Vehicle_Location__c WHERE GPS_Insights_Location_Id__c = 'HIST001']);
    }

    @IsTest
    static void routeSync_emptyResponse_noRecords() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        Test.startTest();
        WEXRouteSyncService.sync();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Location__c]);
    }

    @IsTest
    static void routeSync_applyFields_ignitionVariants() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VTEST');
        insert veh;

        Vehicle_Location__c loc = new Vehicle_Location__c(
            GPS_Insights_Location_Id__c = 'TEST1', Vehicle__c = veh.Id
        );

        Map<String, Object> rowOn = new Map<String, Object>{ 'ignition' => 'on' };
        WEXRouteSyncService.applyFields(loc, rowOn);
        System.assertEquals(true, loc.Ignition_On__c, 'ignition=on should be true');

        Map<String, Object> rowTrue = new Map<String, Object>{ 'ignition' => 'true' };
        WEXRouteSyncService.applyFields(loc, rowTrue);
        System.assertEquals(true, loc.Ignition_On__c, 'ignition=true should be true');

        Map<String, Object> rowOne = new Map<String, Object>{ 'ignition' => '1' };
        WEXRouteSyncService.applyFields(loc, rowOne);
        System.assertEquals(true, loc.Ignition_On__c, 'ignition=1 should be true');

        Map<String, Object> rowOff = new Map<String, Object>{ 'ignition' => 'off' };
        WEXRouteSyncService.applyFields(loc, rowOff);
        System.assertEquals(false, loc.Ignition_On__c, 'ignition=off should be false');
    }

    // ── WEXMaintenanceSyncService ─────────────────────────────────────────────

    @IsTest
    static void maintenanceSync_createsDiagnostic() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXMaintenanceSyncService.sync();
        Test.stopTest();

        List<Vehicle_Diagnostic__c> diags = [
            SELECT WEX_Diagnostic_Id__c, Vehicle__c, DTC_Code__c, Description__c,
                   Severity__c, Is_Active__c
            FROM Vehicle_Diagnostic__c
            WHERE WEX_Diagnostic_Id__c = 'DIAG001'
        ];
        System.assertEquals(1, diags.size(), 'Should create one diagnostic');
        System.assertEquals(veh.Id,         diags[0].Vehicle__c);
        System.assertEquals('P0300',        diags[0].DTC_Code__c);
        System.assertEquals('Random misfire', diags[0].Description__c);
        System.assertEquals('critical',     diags[0].Severity__c);
        System.assertEquals(true,           diags[0].Is_Active__c);
    }

    @IsTest
    static void maintenanceSync_updatesExistingDiagnostic() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Vehicle_Diagnostic__c existing = new Vehicle_Diagnostic__c(
            WEX_Diagnostic_Id__c = 'DIAG001',
            Vehicle__c           = veh.Id,
            DTC_Code__c          = 'OLD',
            Is_Active__c         = false
        );
        insert existing;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXMaintenanceSyncService.sync();
        Test.stopTest();

        Vehicle_Diagnostic__c updated = [
            SELECT DTC_Code__c, Is_Active__c FROM Vehicle_Diagnostic__c WHERE WEX_Diagnostic_Id__c = 'DIAG001'
        ];
        System.assertEquals('P0300', updated.DTC_Code__c, 'DTC code should update');
        System.assertEquals(true,    updated.Is_Active__c,'Active should update');
    }

    @IsTest
    static void maintenanceSync_skipsUnknownVehicle() {
        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXMaintenanceSyncService.sync();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Diagnostic__c]);
    }

    @IsTest
    static void maintenanceSync_emptyResponse_noRecords() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        Test.startTest();
        WEXMaintenanceSyncService.sync();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Diagnostic__c]);
    }

    @IsTest
    static void maintenanceSync_applyFields_setsAllFields() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VTEST');
        insert veh;

        Vehicle_Diagnostic__c diag = new Vehicle_Diagnostic__c(
            WEX_Diagnostic_Id__c = 'TEST1', Vehicle__c = veh.Id
        );
        Map<String, Object> row = new Map<String, Object>{
            'dtc_code'      => 'U0100',
            'description'   => 'Lost comms with ECM',
            'severity'      => 'high',
            'reported_time' => '2024-06-01T10:00:00Z',
            'active'        => 'false'
        };
        WEXMaintenanceSyncService.applyFields(diag, row);

        System.assertEquals('U0100',             diag.DTC_Code__c);
        System.assertEquals('Lost comms with ECM', diag.Description__c);
        System.assertEquals('high',              diag.Severity__c);
        System.assertNotEquals(null, diag.Reported_At__c, 'Reported_At__c should be parsed');
        System.assertEquals(false,               diag.Is_Active__c);
    }

    // ── WEXAlertSyncService ───────────────────────────────────────────────────

    @IsTest
    static void alertSync_createsAlert() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXAlertSyncService.sync();
        Test.stopTest();

        List<GPS_Alert__c> alerts = [
            SELECT WEX_Alert_Id__c, Vehicle__c, Alert_Type__c, Severity__c,
                   Description__c, Is_Acknowledged__c
            FROM GPS_Alert__c
            WHERE WEX_Alert_Id__c = 'ALT001'
        ];
        System.assertEquals(1, alerts.size(), 'Should create one alert');
        System.assertEquals(veh.Id,                   alerts[0].Vehicle__c);
        System.assertEquals('speeding',               alerts[0].Alert_Type__c);
        System.assertEquals('high',                   alerts[0].Severity__c);
        System.assertEquals('Exceeded posted speed',  alerts[0].Description__c);
        System.assertEquals(false,                    alerts[0].Is_Acknowledged__c);
    }

    @IsTest
    static void alertSync_resolvesDriverViaAssignment() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Employee__c emp = new Employee__c(
            Name = 'Jane Smith', First_Name__c = 'Jane', Last_Name__c = 'Smith', Status__c = 'Active'
        );
        insert emp;

        Driver_Assignment__c da = new Driver_Assignment__c(
            WEX_Driver_Id__c = 'DR001',
            Employee__c      = emp.Id,
            Driver_Name__c   = 'Jane Smith',
            Is_Active__c     = true
        );
        insert da;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXAlertSyncService.sync();
        Test.stopTest();

        GPS_Alert__c alert = [SELECT Driver__c FROM GPS_Alert__c WHERE WEX_Alert_Id__c = 'ALT001'];
        System.assertEquals(emp.Id, alert.Driver__c, 'Driver should resolve via Driver_Assignment__c');
    }

    @IsTest
    static void alertSync_noDriverId_driverNull() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        // Mock returns an alert with no driver_id field
        Test.setMock(HttpCalloutMock.class, new AlertNoDriverMock());
        Test.startTest();
        WEXAlertSyncService.sync();
        Test.stopTest();

        GPS_Alert__c alert = [SELECT Driver__c FROM GPS_Alert__c WHERE WEX_Alert_Id__c = 'ALT002'];
        System.assertEquals(null, alert.Driver__c, 'Driver should be null when no driver_id in response');
    }

    @IsTest
    static void alertSync_emptyResponse_noRecords() {
        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        Test.startTest();
        WEXAlertSyncService.sync();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM GPS_Alert__c]);
    }

    @IsTest
    static void alertSync_applyFields_setsAllFields() {
        GPS_Alert__c alert = new GPS_Alert__c(WEX_Alert_Id__c = 'TEST1');
        Map<String, Object> row = new Map<String, Object>{
            'alert_type'   => 'harsh_brake',
            'severity'     => 'medium',
            'description'  => 'Hard braking event',
            'alert_time'   => '2024-06-01T09:00:00Z',
            'acknowledged' => 'true'
        };
        WEXAlertSyncService.applyFields(alert, row);

        System.assertEquals('harsh_brake',      alert.Alert_Type__c);
        System.assertEquals('medium',           alert.Severity__c);
        System.assertEquals('Hard braking event', alert.Description__c);
        System.assertNotEquals(null, alert.Alert_Timestamp__c, 'Timestamp should be parsed');
        System.assertEquals(true, alert.Is_Acknowledged__c, 'acknowledged=true should be true');
    }

    // ── WEXFuelSyncService ────────────────────────────────────────────────────

    @IsTest
    static void fuelSync_createsFuelTransaction() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXFuelSyncService.sync();
        Test.stopTest();

        List<Vehicle_Fuel_Transaction__c> txns = [
            SELECT WEX_Fuel_Id__c, Vehicle__c, Fuel_Date__c, Gallons__c,
                   Fuel_Type__c, Odometer_Miles__c, State__c
            FROM Vehicle_Fuel_Transaction__c
            WHERE WEX_Fuel_Id__c = 'FUEL001'
        ];
        System.assertEquals(1, txns.size(), 'Should create one fuel transaction');
        System.assertEquals(veh.Id,                      txns[0].Vehicle__c);
        System.assertEquals(Date.valueOf('2024-06-01'),   txns[0].Fuel_Date__c);
        System.assertEquals(Decimal.valueOf('12.5'),      txns[0].Gallons__c);
        System.assertEquals('Diesel',                     txns[0].Fuel_Type__c);
        System.assertEquals(Decimal.valueOf('15500'),     txns[0].Odometer_Miles__c);
        System.assertEquals('AZ',                         txns[0].State__c);
    }

    @IsTest
    static void fuelSync_updatesExistingTransaction() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Vehicle_Fuel_Transaction__c existing = new Vehicle_Fuel_Transaction__c(
            WEX_Fuel_Id__c = 'FUEL001',
            Vehicle__c     = veh.Id,
            Gallons__c     = 5.0
        );
        insert existing;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXFuelSyncService.sync();
        Test.stopTest();

        Vehicle_Fuel_Transaction__c updated = [
            SELECT Gallons__c FROM Vehicle_Fuel_Transaction__c WHERE WEX_Fuel_Id__c = 'FUEL001'
        ];
        System.assertEquals(Decimal.valueOf('12.5'), updated.Gallons__c, 'Gallons should update');
    }

    @IsTest
    static void fuelSync_customDateRange() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXFuelSyncService.sync(Date.today().addDays(-30), Date.today());
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Vehicle_Fuel_Transaction__c WHERE WEX_Fuel_Id__c = 'FUEL001']);
    }

    @IsTest
    static void fuelSync_skipsUnknownVehicle() {
        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        WEXFuelSyncService.sync();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Fuel_Transaction__c]);
    }

    @IsTest
    static void fuelSync_emptyResponse_noRecords() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        Test.startTest();
        WEXFuelSyncService.sync();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Fuel_Transaction__c]);
    }

    @IsTest
    static void fuelSync_applyFields_stateTruncated() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VTEST');
        insert veh;

        Vehicle_Fuel_Transaction__c txn = new Vehicle_Fuel_Transaction__c(
            WEX_Fuel_Id__c = 'TEST1', Vehicle__c = veh.Id
        );
        Map<String, Object> row = new Map<String, Object>{
            'date'      => '2024-06-01',
            'gallons'   => '8.75',
            'fuel_type' => 'Regular',
            'odometer'  => '20000',
            'state'     => 'TX'
        };
        WEXFuelSyncService.applyFields(txn, row);

        System.assertEquals(Date.valueOf('2024-06-01'), txn.Fuel_Date__c);
        System.assertEquals(Decimal.valueOf('8.75'),    txn.Gallons__c);
        System.assertEquals('Regular',                  txn.Fuel_Type__c);
        System.assertEquals(Decimal.valueOf('20000'),   txn.Odometer_Miles__c);
        System.assertEquals('TX',                       txn.State__c);
    }

    // ── GPSINTEGRATION Phase 2 routing ────────────────────────────────────────

    @IsTest
    static void gpsIntegration_landmarksSync_createsLandmark() {
        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        GPSINTEGRATION.run(GPSSyncType.LANDMARKS);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM GPS_Landmark__c WHERE WEX_Landmark_Id__c = 'LM001'],
            'Landmark should be created via GPSINTEGRATION');
    }

    @IsTest
    static void gpsIntegration_routesSync_createsLocation() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        GPSINTEGRATION.run(GPSSyncType.ROUTES);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Vehicle_Location__c WHERE GPS_Insights_Location_Id__c = 'HIST001'],
            'Location should be created via GPSINTEGRATION');
    }

    @IsTest
    static void gpsIntegration_maintenanceSync_createsDiagnostic() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        GPSINTEGRATION.run(GPSSyncType.MAINTENANCE);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Vehicle_Diagnostic__c WHERE WEX_Diagnostic_Id__c = 'DIAG001'],
            'Diagnostic should be created via GPSINTEGRATION');
    }

    @IsTest
    static void gpsIntegration_alertsSync_createsAlert() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        GPSINTEGRATION.run(GPSSyncType.ALERTS);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM GPS_Alert__c WHERE WEX_Alert_Id__c = 'ALT001'],
            'Alert should be created via GPSINTEGRATION');
    }

    @IsTest
    static void gpsIntegration_fuelSync_createsTransaction() {
        Vehicle__c veh = new Vehicle__c(GPS_Insights_Id__c = 'VV001');
        insert veh;

        Test.setMock(HttpCalloutMock.class, new MultiEndpointMock());
        Test.startTest();
        GPSINTEGRATION.run(GPSSyncType.FUEL);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Vehicle_Fuel_Transaction__c WHERE WEX_Fuel_Id__c = 'FUEL001'],
            'Fuel transaction should be created via GPSINTEGRATION');
    }
}