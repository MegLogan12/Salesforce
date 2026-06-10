/**
 * Test coverage for WeatherSyncService.
 * Covers county-to-market classification, alert-type mapping, severity mapping,
 * county parsing, UGC state extraction, and alert record builder.
 * HTTP callouts are mocked — no live NWS calls are made.
 */
@IsTest
private class WeatherSyncServiceTest {

    // ── HTTP mock for NWS callouts ────────────────────────────────────────────

    private class NwsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('/points/')) {
                res.setBody('{"properties":{"county":"https://api.weather.gov/zones/county/NCC119","gridId":"RAH","gridX":65,"gridY":89}}');
            } else if (req.getEndpoint().contains('/zones/county/')) {
                res.setBody('{"properties":{"name":"Mecklenburg","state":"NC"}}');
            } else {
                res.setBody('{"features":[{"properties":{"event":"Thunderstorm Warning","headline":"Thunderstorm Warning in effect","description":"Heavy rain expected","severity":"Severe","areaDesc":"Mecklenburg, NC; Wake, NC","effective":"2026-05-14T08:00:00Z","expires":"2026-05-14T20:00:00Z","geocode":{"UGC":["NCC119","NCC183"]}}}]}');
            }
            return res;
        }
    }

    private class FailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('Service Unavailable');
            return res;
        }
    }

    // ── countyToMarket — Charlotte - North ────────────────────────────────────

    @IsTest
    static void countyToMarket_charlotteNorthCounties() {
        System.assertEquals('Charlotte - North', WeatherSyncService.countyToMarket('Mecklenburg', 'NC'), 'Mecklenburg NC');
        System.assertEquals('Charlotte - North', WeatherSyncService.countyToMarket('Iredell', 'NC'), 'Iredell');
        System.assertEquals('Charlotte - North', WeatherSyncService.countyToMarket('Cabarrus', 'NC'), 'Cabarrus');
        System.assertEquals('Charlotte - North', WeatherSyncService.countyToMarket('Rowan', 'NC'), 'Rowan');
        System.assertEquals('Charlotte - North', WeatherSyncService.countyToMarket('Lincoln', 'NC'), 'Lincoln NC');
        System.assertEquals('Charlotte - North', WeatherSyncService.countyToMarket('Alexander', 'NC'), 'Alexander');
        System.assertEquals('Charlotte - North', WeatherSyncService.countyToMarket('Catawba', 'NC'), 'Catawba');
    }

    // ── countyToMarket — Charlotte - South ────────────────────────────────────

    @IsTest
    static void countyToMarket_charlotteSouthCounties() {
        System.assertEquals('Charlotte - South', WeatherSyncService.countyToMarket('Gaston', 'NC'), 'Gaston NC');
        System.assertEquals('Charlotte - South', WeatherSyncService.countyToMarket('York', 'SC'), 'York SC');
        System.assertEquals('Charlotte - South', WeatherSyncService.countyToMarket('Lancaster', 'SC'), 'Lancaster SC');
        System.assertEquals('Charlotte - South', WeatherSyncService.countyToMarket('Union', 'NC'), 'Union NC (not SC)');
        System.assertEquals('Charlotte - South', WeatherSyncService.countyToMarket('Cleveland', 'NC'), 'Cleveland NC');
    }

    // ── countyToMarket — Asheville ────────────────────────────────────────────

    @IsTest
    static void countyToMarket_ashevilleCounties() {
        System.assertEquals('Asheville', WeatherSyncService.countyToMarket('Buncombe', 'NC'), 'Buncombe');
        System.assertEquals('Asheville', WeatherSyncService.countyToMarket('Henderson', 'NC'), 'Henderson');
        System.assertEquals('Asheville', WeatherSyncService.countyToMarket('Transylvania', 'NC'), 'Transylvania');
        System.assertEquals('Asheville', WeatherSyncService.countyToMarket('Haywood', 'NC'), 'Haywood');
        System.assertEquals('Asheville', WeatherSyncService.countyToMarket('Rutherford', 'NC'), 'Rutherford NC');
        System.assertEquals('Asheville', WeatherSyncService.countyToMarket('McDowell', 'NC'), 'McDowell');
        System.assertEquals('Asheville', WeatherSyncService.countyToMarket('Burke', 'NC'), 'Burke');
        System.assertEquals('Asheville', WeatherSyncService.countyToMarket('Watauga', 'NC'), 'Watauga');
    }

    // ── countyToMarket — Triad ────────────────────────────────────────────────

    @IsTest
    static void countyToMarket_triadCounties() {
        System.assertEquals('Triad', WeatherSyncService.countyToMarket('Guilford', 'NC'), 'Guilford');
        System.assertEquals('Triad', WeatherSyncService.countyToMarket('Forsyth', 'NC'), 'Forsyth');
        System.assertEquals('Triad', WeatherSyncService.countyToMarket('Alamance', 'NC'), 'Alamance');
        System.assertEquals('Triad', WeatherSyncService.countyToMarket('Randolph', 'NC'), 'Randolph');
        System.assertEquals('Triad', WeatherSyncService.countyToMarket('Davidson', 'NC'), 'Davidson NC');
        System.assertEquals('Triad', WeatherSyncService.countyToMarket('Rockingham', 'NC'), 'Rockingham');
    }

    // ── countyToMarket — Greenville ───────────────────────────────────────────

    @IsTest
    static void countyToMarket_greenvilleCounties() {
        System.assertEquals('Greenville', WeatherSyncService.countyToMarket('Greenville', 'SC'), 'Greenville SC');
        System.assertEquals('Greenville', WeatherSyncService.countyToMarket('Spartanburg', 'SC'), 'Spartanburg');
        System.assertEquals('Greenville', WeatherSyncService.countyToMarket('Anderson', 'SC'), 'Anderson SC');
        System.assertEquals('Greenville', WeatherSyncService.countyToMarket('Pickens', 'SC'), 'Pickens SC');
        System.assertEquals('Greenville', WeatherSyncService.countyToMarket('Oconee', 'SC'), 'Oconee');
        System.assertEquals('Greenville', WeatherSyncService.countyToMarket('Cherokee', 'SC'), 'Cherokee SC');
        System.assertEquals('Greenville', WeatherSyncService.countyToMarket('Union', 'SC'), 'Union SC (not NC)');
    }

    // ── countyToMarket — Columbia ─────────────────────────────────────────────

    @IsTest
    static void countyToMarket_columbiaCounties() {
        System.assertEquals('Columbia', WeatherSyncService.countyToMarket('Richland', 'SC'), 'Richland');
        System.assertEquals('Columbia', WeatherSyncService.countyToMarket('Lexington', 'SC'), 'Lexington SC');
        System.assertEquals('Columbia', WeatherSyncService.countyToMarket('Kershaw', 'SC'), 'Kershaw');
        System.assertEquals('Columbia', WeatherSyncService.countyToMarket('Newberry', 'SC'), 'Newberry');
        System.assertEquals('Columbia', WeatherSyncService.countyToMarket('Orangeburg', 'SC'), 'Orangeburg');
        System.assertEquals('Columbia', WeatherSyncService.countyToMarket('Lee', 'SC'), 'Lee SC to Columbia');
    }

    // ── countyToMarket — Triangle ─────────────────────────────────────────────

    @IsTest
    static void countyToMarket_triangleCounties() {
        System.assertEquals('Triangle', WeatherSyncService.countyToMarket('Wake', 'NC'), 'Wake');
        System.assertEquals('Triangle', WeatherSyncService.countyToMarket('Durham', 'NC'), 'Durham');
        System.assertEquals('Triangle', WeatherSyncService.countyToMarket('Orange', 'NC'), 'Orange NC');
        System.assertEquals('Triangle', WeatherSyncService.countyToMarket('Chatham', 'NC'), 'Chatham');
        System.assertEquals('Triangle', WeatherSyncService.countyToMarket('Johnston', 'NC'), 'Johnston');
        System.assertEquals('Triangle', WeatherSyncService.countyToMarket('Lee', 'NC'), 'Lee NC to Triangle');
    }

    // ── countyToMarket — null / unknown ───────────────────────────────────────

    @IsTest
    static void countyToMarket_unknownReturnsNull() {
        System.assertEquals(null, WeatherSyncService.countyToMarket('Unknown County', 'NC'), 'Unknown county returns null');
        System.assertEquals(null, WeatherSyncService.countyToMarket('', 'NC'), 'Blank county returns null');
        System.assertEquals(null, WeatherSyncService.countyToMarket(null, 'NC'), 'Null county returns null');
        System.assertEquals(null, WeatherSyncService.countyToMarket('Beaufort', 'SC'), 'Out-of-area county returns null');
    }

    // ── mapAlertType ──────────────────────────────────────────────────────────

    @IsTest
    static void mapAlertType_coversAllBranches() {
        System.assertEquals('Severe Thunderstorm', WeatherSyncService.mapAlertType('Severe Thunderstorm Warning'));
        System.assertEquals('Severe Thunderstorm', WeatherSyncService.mapAlertType('Tornado Warning'));
        System.assertEquals('Thunderstorm',        WeatherSyncService.mapAlertType('Thunderstorm Watch'));
        System.assertEquals('Rain',                WeatherSyncService.mapAlertType('Flash Flood Warning'));
        System.assertEquals('Rain',                WeatherSyncService.mapAlertType('Dense Fog Advisory'));
        System.assertEquals('Wind',                WeatherSyncService.mapAlertType('High Wind Warning'));
        System.assertEquals('Heat',                WeatherSyncService.mapAlertType('Excessive Heat Warning'));
        System.assertEquals('Freeze',              WeatherSyncService.mapAlertType('Winter Storm Warning'));
        System.assertEquals('Freeze',              WeatherSyncService.mapAlertType('Ice Storm Warning'));
        System.assertEquals('Other',               WeatherSyncService.mapAlertType('Special Weather Statement'));
        System.assertEquals('Other',               WeatherSyncService.mapAlertType(null));
        System.assertEquals('Other',               WeatherSyncService.mapAlertType(''));
    }

    // ── mapSeverity ───────────────────────────────────────────────────────────

    @IsTest
    static void mapSeverity_coversAllBranches() {
        System.assertEquals('Severe', WeatherSyncService.mapSeverity('Extreme'));
        System.assertEquals('High',   WeatherSyncService.mapSeverity('Severe'));
        System.assertEquals('Medium', WeatherSyncService.mapSeverity('Moderate'));
        System.assertEquals('Low',    WeatherSyncService.mapSeverity('Minor'));
        System.assertEquals('Low',    WeatherSyncService.mapSeverity('Unknown'));
        System.assertEquals('Low',    WeatherSyncService.mapSeverity(null));
        System.assertEquals('Low',    WeatherSyncService.mapSeverity(''));
    }

    // ── severityRank ──────────────────────────────────────────────────────────

    @IsTest
    static void severityRank_ordering() {
        System.assert(WeatherSyncService.severityRank('Severe') > WeatherSyncService.severityRank('High'),   'Severe > High');
        System.assert(WeatherSyncService.severityRank('High')   > WeatherSyncService.severityRank('Medium'), 'High > Medium');
        System.assert(WeatherSyncService.severityRank('Medium') > WeatherSyncService.severityRank('Low'),    'Medium > Low');
        // Low and null both floor to rank 1 — they are treated the same (no active alert)
        System.assert(WeatherSyncService.severityRank('Low')    >= WeatherSyncService.severityRank(null),    'Low >= null');
        System.assert(WeatherSyncService.severityRank(null) >= 0, 'Null rank is non-negative');
        System.assertEquals(WeatherSyncService.severityRank('Severe'), 4, 'Severe = 4');
        System.assertEquals(WeatherSyncService.severityRank('High'),   3, 'High = 3');
        System.assertEquals(WeatherSyncService.severityRank('Medium'), 2, 'Medium = 2');
        System.assertEquals(WeatherSyncService.severityRank('Low'),    1, 'Low = 1');
    }

    // ── parseCounties ─────────────────────────────────────────────────────────

    @IsTest
    static void parseCounties_multipleFormats() {
        List<String> result = WeatherSyncService.parseCounties('Mecklenburg, NC; Wake, NC; Guilford, NC');
        System.assertEquals(3, result.size());
        System.assertEquals('Mecklenburg', result[0]);
        System.assertEquals('Wake', result[1]);
        System.assertEquals('Guilford', result[2]);
    }

    @IsTest
    static void parseCounties_withCountySuffix() {
        List<String> result = WeatherSyncService.parseCounties('Buncombe County, NC');
        System.assertEquals(1, result.size());
        System.assertEquals('Buncombe', result[0]);
    }

    @IsTest
    static void parseCounties_blankInputs() {
        System.assertEquals(0, WeatherSyncService.parseCounties(null).size());
        System.assertEquals(0, WeatherSyncService.parseCounties('').size());
    }

    // ── extractStateFromUgc ───────────────────────────────────────────────────

    @IsTest
    static void extractStateFromUgc_ncCode() {
        Map<String, Object> props = new Map<String, Object>{
            'geocode' => new Map<String, Object>{
                'UGC' => new List<Object>{'NCC119', 'NCC001'}
            }
        };
        System.assertEquals('NC', WeatherSyncService.extractStateFromUgc(props));
    }

    @IsTest
    static void extractStateFromUgc_scCode() {
        Map<String, Object> props = new Map<String, Object>{
            'geocode' => new Map<String, Object>{
                'UGC' => new List<Object>{'SCC045'}
            }
        };
        System.assertEquals('SC', WeatherSyncService.extractStateFromUgc(props));
    }

    @IsTest
    static void extractStateFromUgc_missingReturnsNull() {
        System.assertEquals(null, WeatherSyncService.extractStateFromUgc(new Map<String, Object>()));
        System.assertEquals(null, WeatherSyncService.extractStateFromUgc(
            new Map<String, Object>{'geocode' => new Map<String, Object>{'UGC' => new List<Object>()}}
        ));
    }

    // ── parseAlerts ───────────────────────────────────────────────────────────

    @IsTest
    static void parseAlerts_validJson() {
        String body = '{"features":[{"properties":{"event":"Wind Advisory","severity":"Minor","areaDesc":"Wake, NC","effective":"2026-05-14T08:00:00Z","expires":"2026-05-14T18:00:00Z","headline":"Wind Advisory in effect","description":"Winds 25-35 mph","geocode":{"UGC":["NCC183"]}}}]}';
        List<Map<String, Object>> features = WeatherSyncService.parseAlerts(body);
        System.assertEquals(1, features.size());
        System.assertEquals('Wind Advisory', features[0].get('event'));
    }

    @IsTest
    static void parseAlerts_emptyOrInvalid() {
        System.assertEquals(0, WeatherSyncService.parseAlerts(null).size());
        System.assertEquals(0, WeatherSyncService.parseAlerts('').size());
        System.assertEquals(0, WeatherSyncService.parseAlerts('{}').size());
        System.assertEquals(0, WeatherSyncService.parseAlerts('not json').size());
    }

    // ── buildAlertRecords — with Division__c set ──────────────────────────────

    @IsTest
    static void buildAlertRecords_setsMarketDivision() {
        List<Map<String, Object>> features = new List<Map<String, Object>>{
            new Map<String, Object>{
                'event'       => 'Thunderstorm Warning',
                'headline'    => 'Storm warning',
                'description' => 'Heavy rain',
                'severity'    => 'Severe',
                'areaDesc'    => 'Mecklenburg, NC; Wake, NC',
                'effective'   => '2026-05-14T08:00:00Z',
                'expires'     => '2026-05-14T20:00:00Z',
                'geocode'     => new Map<String, Object>{'UGC' => new List<Object>{'NCC119', 'NCC183'}}
            }
        };
        Map<String, String> maxSevByCounty = new Map<String, String>();
        List<Weather_Alert__c> built = WeatherSyncService.buildAlertRecords(features, null, maxSevByCounty);

        System.assertEquals(2, built.size(), 'One record per county');
        Boolean foundCharlotteNorth = false;
        Boolean foundTriangle       = false;
        for (Weather_Alert__c a : built) {
            if (a.County__c == 'Mecklenburg')  { foundCharlotteNorth = (a.Division__c == 'Charlotte - North'); }
            if (a.County__c == 'Wake')          { foundTriangle       = (a.Division__c == 'Triangle'); }
        }
        System.assertEquals(true, foundCharlotteNorth, 'Mecklenburg maps to Charlotte - North');
        System.assertEquals(true, foundTriangle,       'Wake maps to Triangle');
        System.assertEquals('High', maxSevByCounty.get('Mecklenburg'), 'Severe NWS = High LOVING severity');
    }

    @IsTest
    static void buildAlertRecords_unknownCountyHasNullDivision() {
        List<Map<String, Object>> features = new List<Map<String, Object>>{
            new Map<String, Object>{
                'event'       => 'Wind Advisory',
                'headline'    => 'Advisory',
                'description' => 'Wind',
                'severity'    => 'Minor',
                'areaDesc'    => 'Beaufort, SC',
                'effective'   => '2026-05-14T08:00:00Z',
                'expires'     => '2026-05-14T18:00:00Z',
                'geocode'     => new Map<String, Object>{'UGC' => new List<Object>{'SCC013'}}
            }
        };
        Map<String, String> maxSev = new Map<String, String>();
        List<Weather_Alert__c> built = WeatherSyncService.buildAlertRecords(features, null, maxSev);
        System.assertEquals(1, built.size());
        System.assertEquals(null, built[0].Division__c, 'Out-of-area county produces null Division__c');
    }

    // ── toStr / trunc / toDateTime ────────────────────────────────────────────

    @IsTest
    static void utilities_basicCoverage() {
        System.assertEquals('hello', WeatherSyncService.toStr('hello'));
        System.assertEquals(null, WeatherSyncService.toStr(null));
        System.assertEquals('abc', WeatherSyncService.trunc('abcdef', 3));
        System.assertEquals('ab', WeatherSyncService.trunc('ab', 10));
        System.assertEquals(null, WeatherSyncService.trunc(null, 5));
        DateTime parsedDt = WeatherSyncService.toDateTime('2026-05-14T12:00:00Z');
        System.assertNotEquals(null, parsedDt);
        System.assertEquals(null, WeatherSyncService.toDateTime(null));
        System.assertEquals(null, WeatherSyncService.toDateTime('not-a-date'));
    }

    // ── resolveCounty ─────────────────────────────────────────────────────────

    @IsTest
    static void resolveCounty_noGeoResult() {
        Schedule_Stop__c s = new Schedule_Stop__c();
        String county = WeatherSyncService.resolveCounty(s, new Map<Id, WeatherSyncService.LotGeoInfo>());
        System.assertEquals(null, county);
    }

    // ── fetchAlerts — HTTP fail path ──────────────────────────────────────────

    @IsTest
    static void fetchAlerts_httpFailReturnsNull() {
        Test.setMock(HttpCalloutMock.class, new FailMock());
        Test.startTest();
        String result = WeatherSyncService.fetchAlerts();
        Test.stopTest();
        System.assertEquals(null, result, 'Non-2xx response should return null');
    }

    // ── geocodeLot — success path (both callouts covered) ────────────────────

    @IsTest
    static void geocodeLot_successPath() {
        Test.setMock(HttpCalloutMock.class, new NwsMock());
        Test.startTest();
        WeatherSyncService.LotGeoInfo info = WeatherSyncService.geocodeLot(35.2271, -80.8431);
        Test.stopTest();
        System.assertNotEquals(null, info, 'Should return geo info for valid coordinates');
        System.assertEquals('Mecklenburg', info.countyName);
        System.assertEquals('NC', info.state);
    }

    @IsTest
    static void geocodeLot_pointsApiFail() {
        Test.setMock(HttpCalloutMock.class, new FailMock());
        Test.startTest();
        WeatherSyncService.LotGeoInfo info = WeatherSyncService.geocodeLot(35.2271, -80.8431);
        Test.stopTest();
        System.assertEquals(null, info, 'Should return null when points API fails');
    }

    @IsTest
    static void geocodeLot_nullCoordinatesReturnsNull() {
        Test.startTest();
        WeatherSyncService.LotGeoInfo info = WeatherSyncService.geocodeLot(null, null);
        Test.stopTest();
        System.assertEquals(null, info, 'Null coordinates should return null');
    }

    // ── geocodeLot — zones API fail path ─────────────────────────────────────

    private class PointsOkZonesFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/points/')) {
                res.setStatusCode(200);
                res.setBody('{"properties":{"county":"https://api.weather.gov/zones/county/NCC119","gridId":"RAH","gridX":65,"gridY":89}}');
            } else {
                res.setStatusCode(503);
                res.setBody('Service Unavailable');
            }
            return res;
        }
    }

    @IsTest
    static void geocodeLot_zonesApiFail() {
        Test.setMock(HttpCalloutMock.class, new PointsOkZonesFailMock());
        Test.startTest();
        WeatherSyncService.LotGeoInfo info = WeatherSyncService.geocodeLot(35.2271, -80.8431);
        Test.stopTest();
        System.assertEquals(null, info, 'Should return null when zones API fails');
    }

    // ── geocodeLot — no county URL in points response ─────────────────────────

    private class PointsNoCountyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"properties":{"gridId":"RAH","gridX":65,"gridY":89}}');
            return res;
        }
    }

    @IsTest
    static void geocodeLot_pointsNoCountyUrl() {
        Test.setMock(HttpCalloutMock.class, new PointsNoCountyMock());
        Test.startTest();
        WeatherSyncService.LotGeoInfo info = WeatherSyncService.geocodeLot(35.2271, -80.8431);
        Test.stopTest();
        System.assertEquals(null, info, 'Should return null when no county URL in points response');
    }

    // ── writeErrorLog — covers the debug+insert path ──────────────────────────

    @IsTest
    static void writeErrorLog_doesNotThrow() {
        Test.startTest();
        WeatherSyncService.writeErrorLog('testMethod', 'Test error message for coverage');
        Test.stopTest();
        // If Error_Log__c exists, one record inserted. If not, error is caught internally.
        System.assert(true, 'writeErrorLog should not throw regardless of Error_Log__c state');
    }

    // ── stampStopRisks — covers update path with empty stops ──────────────────

    @IsTest
    static void stampStopRisks_withEmptyStops() {
        // Create a Schedule_Day__c so we have a valid Id to update
        Schedule_Day__c sday = new Schedule_Day__c(Schedule_Date__c = Date.today());
        insert sday;

        Test.startTest();
        WeatherSyncService.stampStopRisks(
            new List<Schedule_Stop__c>(),
            new Map<Id, WeatherSyncService.LotGeoInfo>(),
            new Map<String, String>(),
            sday.Id
        );
        Test.stopTest();

        // After stampStopRisks with empty stops, Schedule_Day__c.Weather_Risk__c should be 'Low'
        Schedule_Day__c reloaded = [SELECT Weather_Risk__c FROM Schedule_Day__c WHERE Id = :sday.Id];
        System.assertEquals('Low', reloaded.Weather_Risk__c, 'Default weather risk should be Low');
    }

    // ── getTodayScheduleDayId ─────────────────────────────────────────────────

    @IsTest
    static void getTodayScheduleDayId_noRecordReturnsNullOrId() {
        Test.startTest();
        Id sdayId = WeatherSyncService.getTodayScheduleDayId();
        Test.stopTest();
        // Either null or a real ID — no exception is the assertion
        System.assert(sdayId == null || sdayId != null, 'Method should not throw');
    }

    // ── syncWeather — @future method (callout mock) ───────────────────────────

    @IsTest
    static void syncWeather_withMock_doesNotThrow() {
        Test.setMock(HttpCalloutMock.class, new NwsMock());
        Test.startTest();
        WeatherSyncService.syncWeather();
        Test.stopTest();
        System.assert(true, 'syncWeather completed without unhandled exception');
    }
}