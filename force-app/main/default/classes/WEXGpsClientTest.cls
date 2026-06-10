@IsTest
private class WEXGpsClientTest {

    // ── Mocks ─────────────────────────────────────────────────────────────────

    /** Returns a valid session token on /userauth/login, vehicle data on everything else. */
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('userauth/login')) {
                res.setBody('{"head":{"status":"success"},"data":{"token":"test-token-123"}}');
            } else {
                res.setBody('{"data":[{"id":"VV001","latitude":33.66,"longitude":-111.92,'
                    + '"fix_time_gmt":"2024-06-01T14:00:00Z","inst_speed":25,'
                    + '"heading":90,"ignition":"on","address":"123 Main St"}]}');
            }
            return res;
        }
    }

    /** Always returns 401. */
    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error":"unauthorized"}');
            return res;
        }
    }

    /** Simulates a network exception. */
    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Network timeout');
        }
    }

    // ── Test setup ────────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        GPS_Insight_Config__c cfg = new GPS_Insight_Config__c();
        cfg.Username__c  = 'testuser';
        cfg.App_Token__c = 'testapptoken';
        upsert cfg;
    }

    // ── resolveToken ──────────────────────────────────────────────────────────

    @IsTest
    static void resolveToken_freshCachedToken_noCalls() {
        GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
        cfg.Session_Token__c = 'cached-token-xyz';
        cfg.Token_Expiry__c  = DateTime.now().addDays(3);
        upsert cfg;

        // No mock needed — should not make callout
        Test.startTest();
        String token = WEXGpsClient.resolveToken();
        Test.stopTest();

        System.assertEquals('cached-token-xyz', token, 'Should return cached token');
    }

    @IsTest
    static void resolveToken_expiredToken_callsLogin() {
        GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
        cfg.Session_Token__c = 'stale-token';
        cfg.Token_Expiry__c  = DateTime.now().addMinutes(30); // inside 1-hour refresh buffer
        upsert cfg;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        String token = WEXGpsClient.resolveToken();
        Test.stopTest();

        System.assertEquals('test-token-123', token, 'Should return new token from login');

        // resolveToken now avoids DML before the follow-on callout; persistence happens after a successful data request.
        GPS_Insight_Config__c saved = GPS_Insight_Config__c.getOrgDefaults();
        System.assertEquals('stale-token', saved.Session_Token__c);
    }

    @IsTest
    static void resolveToken_noCredentials_returnsNull() {
        GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
        cfg.Username__c      = null;
        cfg.App_Token__c     = null;
        cfg.Session_Token__c = null;
        upsert cfg;

        Test.startTest();
        String token = WEXGpsClient.resolveToken();
        Test.stopTest();

        System.assertEquals(null, token, 'Should return null when credentials missing');
    }

    // ── login ─────────────────────────────────────────────────────────────────

    @IsTest
    static void login_success_returnsToken() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        String token = WEXGpsClient.login('testuser', 'testapptoken');
        Test.stopTest();
        System.assertEquals('test-token-123', token);
    }

    @IsTest
    static void login_httpError_returnsNull() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        String token = WEXGpsClient.login('testuser', 'testapptoken');
        Test.stopTest();
        System.assertEquals(null, token, 'Should return null on HTTP error');
    }

    @IsTest
    static void login_tokenInList_returnsToken() {
        // Some API versions return data as array: [{"token":"..."}]
        Test.setMock(HttpCalloutMock.class, new ListTokenMock());
        Test.startTest();
        String token = WEXGpsClient.login('user', 'app');
        Test.stopTest();
        System.assertEquals('list-token-abc', token);
    }

    private class ListTokenMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"data":[{"token":"list-token-abc"}]}');
            return res;
        }
    }

    // ── doGet ─────────────────────────────────────────────────────────────────

    @IsTest
    static void doGet_noToken_returns401WithoutCallout() {
        GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
        cfg.Username__c      = null;
        cfg.App_Token__c     = null;
        cfg.Session_Token__c = null;
        upsert cfg;

        Test.startTest();
        WEXGpsClient.ApiResponse resp = WEXGpsClient.doGet('vehicle/location', new Map<String,String>());
        Test.stopTest();

        System.assertEquals(401, resp.statusCode);
        System.assertEquals(false, resp.ok);
    }

    @IsTest
    static void doGet_success_returnsOkResponse() {
        GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
        cfg.Session_Token__c = 'valid-token';
        cfg.Token_Expiry__c  = DateTime.now().addDays(3);
        upsert cfg;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        WEXGpsClient.ApiResponse resp = WEXGpsClient.doGet('vehicle/location', new Map<String,String>());
        Test.stopTest();

        System.assertEquals(200, resp.statusCode);
        System.assertEquals(true, resp.ok);
        System.assert(resp.rawBody.contains('VV001'));
    }

    @IsTest
    static void doGet_withParams_includesParamsInUrl() {
        GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
        cfg.Session_Token__c = 'valid-token';
        cfg.Token_Expiry__c  = DateTime.now().addDays(3);
        upsert cfg;

        CaptureMock captureMock = new CaptureMock();
        Test.setMock(HttpCalloutMock.class, captureMock);
        Test.startTest();
        WEXGpsClient.doGet('vehicle', new Map<String,String>{'vehicle_id' => 'VV001'});
        Test.stopTest();

        System.assert(captureMock.capturedUrl.contains('vehicle_id=VV001'),
            'URL should contain encoded param: ' + captureMock.capturedUrl);
        System.assert(captureMock.capturedUrl.contains('session_token='),
            'URL should contain session_token');
    }

    private class CaptureMock implements HttpCalloutMock {
        public String capturedUrl;
        public HttpResponse respond(HttpRequest req) {
            capturedUrl = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"data":[]}');
            return res;
        }
    }

    private class RetryOnInvalidTokenMock implements HttpCalloutMock {
        public Integer dataCalls = 0;
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            if (endpoint.contains('userauth/login')) {
                res.setStatusCode(200);
                res.setBody('{"data":{"token":"fresh-token-456"}}');
                return res;
            }
            dataCalls++;
            if (dataCalls == 1) {
                res.setStatusCode(401);
                res.setBody('{"error":"Invalid session_token provided"}');
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{"data":[{"id":"VV001"}]}');
            return res;
        }
    }

    @IsTest
    static void doGet_networkException_returnsCode0() {
        GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
        cfg.Session_Token__c = 'valid-token';
        cfg.Token_Expiry__c  = DateTime.now().addDays(3);
        upsert cfg;

        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        Test.startTest();
        WEXGpsClient.ApiResponse resp = WEXGpsClient.doGet('vehicle/location', new Map<String,String>());
        Test.stopTest();

        System.assertEquals(0, resp.statusCode);
        System.assertEquals(false, resp.ok);
    }

    @IsTest
    static void doGet_invalidCachedToken_retriesWithFreshLogin() {
        GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
        cfg.Session_Token__c = 'stale-invalid-token';
        cfg.Token_Expiry__c = DateTime.now().addDays(3);
        upsert cfg;

        RetryOnInvalidTokenMock mock = new RetryOnInvalidTokenMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        WEXGpsClient.ApiResponse resp = WEXGpsClient.doGet('driver/', new Map<String, String>());
        Test.stopTest();

        System.assertEquals(200, resp.statusCode);
        System.assertEquals(true, resp.ok);
        System.assertEquals(2, mock.dataCalls, 'Client should retry once after invalid cached token');

        GPS_Insight_Config__c saved = GPS_Insight_Config__c.getOrgDefaults();
        System.assertEquals('fresh-token-456', saved.Session_Token__c, 'Client should persist the fresh session token');
    }

    // ── ApiResponse.rows() ────────────────────────────────────────────────────

    @IsTest
    static void rows_dataEnvelope_returnsItems() {
        WEXGpsClient.ApiResponse resp = new WEXGpsClient.ApiResponse(200,
            '{"data":[{"id":"VV001"},{"id":"VV002"}]}');
        List<Map<String,Object>> rows = resp.rows();
        System.assertEquals(2, rows.size());
        System.assertEquals('VV001', rows[0].get('id'));
    }

    @IsTest
    static void rows_vehiclesEnvelope_returnsItems() {
        WEXGpsClient.ApiResponse resp = new WEXGpsClient.ApiResponse(200,
            '{"vehicles":[{"id":"VV003"}]}');
        System.assertEquals(1, resp.rows().size());
    }

    @IsTest
    static void rows_topLevelArray_returnsItems() {
        WEXGpsClient.ApiResponse resp = new WEXGpsClient.ApiResponse(200,
            '[{"id":"VV001"},{"id":"VV002"},{"id":"VV003"}]');
        System.assertEquals(3, resp.rows().size());
    }

    @IsTest
    static void rows_singleObjectInData_returnsOneItem() {
        WEXGpsClient.ApiResponse resp = new WEXGpsClient.ApiResponse(200,
            '{"data":{"id":"VV001","lat":33.5}}');
        List<Map<String,Object>> rows = resp.rows();
        System.assertEquals(1, rows.size());
        System.assertEquals('VV001', rows[0].get('id'));
    }

    @IsTest
    static void rows_nonOkStatus_returnsEmpty() {
        WEXGpsClient.ApiResponse resp = new WEXGpsClient.ApiResponse(500,
            '{"data":[{"id":"VV001"}]}');
        System.assertEquals(0, resp.rows().size());
    }

    @IsTest
    static void rows_blankBody_returnsEmpty() {
        WEXGpsClient.ApiResponse resp = new WEXGpsClient.ApiResponse(200, '');
        System.assertEquals(0, resp.rows().size());
    }

    @IsTest
    static void rows_malformedJson_returnsEmpty() {
        WEXGpsClient.ApiResponse resp = new WEXGpsClient.ApiResponse(200, 'not-json');
        System.assertEquals(0, resp.rows().size());
    }

    // ── Type helpers ──────────────────────────────────────────────────────────

    @IsTest
    static void toStr_nullReturnsNull() {
        System.assertEquals(null, WEXGpsClient.toStr(null));
    }

    @IsTest
    static void toDecimal_handlesVariousTypes() {
        System.assertEquals(null, WEXGpsClient.toDecimal(null));
        System.assertEquals(Decimal.valueOf('33.66'), WEXGpsClient.toDecimal('33.66'));
        System.assertEquals(Decimal.valueOf('0'), WEXGpsClient.toDecimal(0));
        System.assertEquals(null, WEXGpsClient.toDecimal('not-a-number'));
    }

    @IsTest
    static void toDateTime_parsesISOWithZ() {
        DateTime dt = WEXGpsClient.toDateTime('2024-06-01T14:00:00Z');
        System.assertNotEquals(null, dt, 'Should parse ISO datetime with Z suffix');
    }

    @IsTest
    static void toDateTime_parsesISOWithOffset() {
        DateTime dt = WEXGpsClient.toDateTime('2024-06-01T14:00:00+00:00');
        System.assertNotEquals(null, dt, 'Should parse ISO datetime with offset');
    }

    @IsTest
    static void toDateTime_returnsNullForBlank() {
        System.assertEquals(null, WEXGpsClient.toDateTime(null));
        System.assertEquals(null, WEXGpsClient.toDateTime(''));
        System.assertEquals(null, WEXGpsClient.toDateTime('   '));
    }

    // ── logError ──────────────────────────────────────────────────────────────

    @IsTest
    static void logError_insertsErrorLogRecord() {
        Test.startTest();
        WEXGpsClient.logError('testMethod', 503, 'Service unavailable');
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Id, Class_Name__c, Method_Name__c, Message__c
            FROM Error_Log__c
            WHERE Class_Name__c = 'WEXGpsClient' AND Method_Name__c = 'testMethod'
        ];
        System.assertEquals(1, logs.size());
        System.assert(logs[0].Message__c.contains('Service unavailable'));
    }
}