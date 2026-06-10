/**
 * Test coverage for WexGpsSyncService and WexGpsSyncScheduler.
 * Covers auto-authentication via GPS_Insight_Config__c Custom Setting.
 */
@IsTest(seeAllData=false)
private class WexGpsSyncServiceTest {

    // ── mock ─────────────────────────────────────────────────────────────────

    private class GpsiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String url = req.getEndpoint();

            if (url.contains('userauth/login')) {
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'head' => new Map<String, Object>{ 'status' => 'OK' },
                    'data' => new Map<String, Object>{ 'token' => 'test-session-token-abc123' }
                }));
                return res;
            }

            if (url.contains('vehicle/location')) {
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'head' => new Map<String, Object>{ 'status' => 'OK' },
                    'data' => new List<Object>{
                        new Map<String, Object>{
                            'id'           => 'CA-internal-001',
                            'label'        => 'gpsi-001',
                            'latitude'     => 33.6604276,
                            'longitude'    => -111.924858,
                            'fix_time_gmt' => DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss+00:00'),
                            'inst_speed'   => 42,
                            'heading'      => 270,
                            'ignition'     => 'on',
                            'address'      => '123 Main St, Scottsdale AZ',
                            'driver_id'    => '1',
                            'first_name'   => 'John',
                            'last_name'    => 'Smith'
                        }
                    }
                }));
                return res;
            }

            res.setStatusCode(404);
            res.setBody('{}');
            return res;
        }
    }

    private class LoginErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error":"Unauthorized"}');
            return res;
        }
    }

    // Seeds a GPS_Insight_Config__c org default with credentials.
    private static GPS_Insight_Config__c seedConfig(Boolean withCachedToken) {
        GPS_Insight_Config__c cfg = new GPS_Insight_Config__c(
            Username__c  = 'testuser@example.com',
            App_Token__c = 'non-expiring-app-token-xyz'
        );
        if (withCachedToken) {
            cfg.Session_Token__c = 'cached-session-token-999';
            cfg.Token_Expiry__c  = DateTime.now().addDays(5);
        }
        insert cfg;
        return cfg;
    }

    // ── getSessionToken tests ─────────────────────────────────────────────────

    @IsTest
    static void getSessionToken_returnsCachedTokenWhenFresh() {
        seedConfig(true);
        // No callout mock needed — should use cached token without hitting login.
        Test.startTest();
        String token = WexGpsSyncService.getSessionToken();
        Test.stopTest();

        System.assertEquals('cached-session-token-999', token, 'Should return cached token');
    }

    @IsTest
    static void getSessionToken_refreshesExpiredToken() {
        GPS_Insight_Config__c cfg = seedConfig(false);
        cfg.Session_Token__c = 'expired-token';
        cfg.Token_Expiry__c  = DateTime.now().addMinutes(-30); // already expired
        update cfg;

        Test.setMock(HttpCalloutMock.class, new GpsiMock());
        Test.startTest();
        String token = WexGpsSyncService.getSessionToken();
        Test.stopTest();

        System.assertEquals('test-session-token-abc123', token, 'Should return newly authenticated token');

        GPS_Insight_Config__c updated = GPS_Insight_Config__c.getOrgDefaults();
        System.assertEquals('test-session-token-abc123', updated.Session_Token__c, 'Custom Setting should be updated');
        System.assertNotEquals(null, updated.Token_Expiry__c);
    }

    @IsTest
    static void getSessionToken_missingCredentials_returnsNull() {
        // Insert an empty config — no credentials
        insert new GPS_Insight_Config__c();

        Test.startTest();
        String token = WexGpsSyncService.getSessionToken();
        Test.stopTest();

        System.assertEquals(null, token);
        List<Error_Log__c> logs = [SELECT Id FROM Error_Log__c WHERE Class_Name__c = 'WexGpsSyncService'];
        System.assert(!logs.isEmpty(), 'Should write error log when credentials missing');
    }

    @IsTest
    static void authenticate_httpError_returnsNull() {
        Test.setMock(HttpCalloutMock.class, new LoginErrorMock());
        Test.startTest();
        String token = WexGpsSyncService.authenticate('user', 'badtoken');
        Test.stopTest();

        System.assertEquals(null, token);
    }

    // ── full sync tests ───────────────────────────────────────────────────────

    @IsTest
    static void syncPositions_freshAuth_createsPositionRecord() {
        seedConfig(false); // no cached token — will trigger login callout
        Employee__c emp = new Employee__c(
            Name = 'John Smith', First_Name__c = 'John', Last_Name__c = 'Smith',
            Department__c = 'Landscape', Status__c = 'Active'
        );
        insert emp;
        Vehicle__c v = new Vehicle__c(
            GPS_Insights_Id__c = 'gpsi-001', Status__c = 'Active',
            Assigned_Driver__c = emp.Id
        );
        insert v;

        Test.setMock(HttpCalloutMock.class, new GpsiMock());
        Test.startTest();
        WexGpsSyncService.syncPositions();
        Test.stopTest();

        List<WEX_GPS_Position__c> positions = [
            SELECT Latitude__c, Ignition_Status__c, Source_System__c, Driver__c
            FROM WEX_GPS_Position__c WHERE Vehicle__c = :v.Id
        ];
        System.assertEquals(1, positions.size());
        System.assertEquals('On',      positions[0].Ignition_Status__c);
        System.assertEquals('WEX GPS', positions[0].Source_System__c);
        System.assertEquals(emp.Id,    positions[0].Driver__c, 'Driver should be linked via Assigned_Driver__c');
    }

    @IsTest
    static void syncPositions_nameMatch_linksDriver() {
        // No Assigned_Driver__c on vehicle — fall back to GPS response first/last name
        seedConfig(true);
        Employee__c emp = new Employee__c(
            Name = 'John Smith', First_Name__c = 'John', Last_Name__c = 'Smith',
            Department__c = 'Landscape', Status__c = 'Active'
        );
        insert emp;
        Vehicle__c v = new Vehicle__c(GPS_Insights_Id__c = 'gpsi-001', Status__c = 'Active');
        insert v;

        Test.setMock(HttpCalloutMock.class, new GpsiMock());
        Test.startTest();
        WexGpsSyncService.syncPositions();
        Test.stopTest();

        WEX_GPS_Position__c pos = [SELECT Driver__c FROM WEX_GPS_Position__c WHERE Vehicle__c = :v.Id LIMIT 1];
        System.assertEquals(emp.Id, pos.Driver__c, 'Driver should be linked via name match from GPS response');
    }

    @IsTest
    static void syncPositions_cachedToken_updatesExisting() {
        seedConfig(true);
        Vehicle__c v = new Vehicle__c(GPS_Insights_Id__c = 'gpsi-001', Status__c = 'Active');
        insert v;
        insert new WEX_GPS_Position__c(Vehicle__c = v.Id, Latitude__c = 0, Longitude__c = 0, Source_System__c = 'WEX GPS');

        Test.setMock(HttpCalloutMock.class, new GpsiMock());
        Test.startTest();
        WexGpsSyncService.syncPositions();
        Test.stopTest();

        List<WEX_GPS_Position__c> positions = [SELECT Latitude__c FROM WEX_GPS_Position__c WHERE Vehicle__c = :v.Id];
        System.assertEquals(1, positions.size(), 'Should update, not insert a second record');
        System.assertNotEquals(0, positions[0].Latitude__c, 'Latitude should be updated');
    }

    @IsTest
    static void syncPositions_mirrorsToVehicle() {
        seedConfig(true);
        Vehicle__c v = new Vehicle__c(GPS_Insights_Id__c = 'gpsi-001', Status__c = 'Active');
        insert v;

        Test.setMock(HttpCalloutMock.class, new GpsiMock());
        Test.startTest();
        WexGpsSyncService.syncPositions();
        Test.stopTest();

        Vehicle__c vReloaded = [
            SELECT GPS_Latitude__c, Last_Location_Address__c, Last_GPS_Sync__c, GPS_Status__c
            FROM Vehicle__c WHERE Id = :v.Id
        ];
        System.assertNotEquals(null, vReloaded.GPS_Latitude__c);
        System.assertEquals('123 Main St, Scottsdale AZ', vReloaded.Last_Location_Address__c);
        System.assertNotEquals(null, vReloaded.Last_GPS_Sync__c);
    }

    @IsTest
    static void syncPositions_noMatchingVehicle_noRecords() {
        seedConfig(true);
        // No Vehicle__c with GPS_Insights_Id__c = 'gpsi-001'
        Test.setMock(HttpCalloutMock.class, new GpsiMock());
        Test.startTest();
        WexGpsSyncService.syncPositions();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM WEX_GPS_Position__c]);
    }

    // ── parsing and helper tests ──────────────────────────────────────────────

    @IsTest
    static void parseVehicleList_dataEnvelope() {
        String body = JSON.serialize(new Map<String, Object>{
            'head' => new Map<String, Object>{ 'status' => 'OK' },
            'data' => new List<Object>{ new Map<String, Object>{ 'id' => 'v1' } }
        });
        System.assertEquals(1, WexGpsSyncService.parseVehicleList(body).size());
    }

    @IsTest
    static void parseVehicleList_emptyBody() {
        System.assertEquals(0, WexGpsSyncService.parseVehicleList('').size());
        System.assertEquals(0, WexGpsSyncService.parseVehicleList('{}').size());
    }

    @IsTest
    static void mapIgnitionStatus_allValues() {
        System.assertEquals('On',      WexGpsSyncService.mapIgnitionStatus('on'));
        System.assertEquals('On',      WexGpsSyncService.mapIgnitionStatus('ON'));
        System.assertEquals('Off',     WexGpsSyncService.mapIgnitionStatus('off'));
        System.assertEquals('Off',     WexGpsSyncService.mapIgnitionStatus('false'));
        System.assertEquals('Unknown', WexGpsSyncService.mapIgnitionStatus(null));
        System.assertEquals('Unknown', WexGpsSyncService.mapIgnitionStatus('idle'));
    }

    @IsTest
    static void deriveGpsStatus_buckets() {
        DateTime now = DateTime.now();
        System.assertEquals('Active',  WexGpsSyncService.deriveGpsStatus(now.addMinutes(-5),   now));
        System.assertEquals('Delayed', WexGpsSyncService.deriveGpsStatus(now.addMinutes(-60),  now));
        System.assertEquals('Offline', WexGpsSyncService.deriveGpsStatus(now.addMinutes(-180), now));
        System.assertEquals('Unknown', WexGpsSyncService.deriveGpsStatus(null,                 now));
    }

    @IsTest
    static void toDateTime_iso() {
        System.assertNotEquals(null, WexGpsSyncService.toDateTime('2026-04-30T14:30:00+00:00'));
        System.assertNotEquals(null, WexGpsSyncService.toDateTime('2026-04-30T14:30:00Z'));
        System.assertEquals(null,    WexGpsSyncService.toDateTime(null));
    }

    // ── scheduler tests ───────────────────────────────────────────────────────

    @IsTest
    static void scheduler_execute_noException() {
        seedConfig(true);
        Test.setMock(HttpCalloutMock.class, new GpsiMock());
        Test.startTest();
        new WexGpsSyncScheduler().execute(null);
        Test.stopTest();
    }

    @IsTest
    static void scheduler_start_registersJob() {
        Test.startTest();
        WexGpsSyncScheduler.start();
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE 'WEX GPS Sync%' AND State NOT IN ('DELETED','COMPLETE','ERROR')]);
    }

    @IsTest
    static void scheduler_stop_abortsJobs() {
        Test.startTest();
        WexGpsSyncScheduler.start();
        WexGpsSyncScheduler.stop();
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT() FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'WEX GPS Sync%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ]);
    }
}