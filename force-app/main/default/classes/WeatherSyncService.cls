/**
 * Pulls active weather alerts for NC + SC from the National Weather Service (NWS) free API.
 * No API key required.
 *
 * County-based matching:
 *   • One Weather_Alert__c is created per county per NWS alert (from NWS areaDesc).
 *   • Each Schedule_Stop__c is matched to county via stop GPS first (Schedule_Stop__c.GPS_Latitude__c/Longitude__c).
 *   • Stops with no resolvable stop GPS are flagged in Error_Log__c and default to Low risk.
 *
 * Division__c is intentionally NOT used — that is the LOVING operating division (Charlotte,
 * Asheville, Triad, etc.), not a geographic county.
 *
 * Scheduled hourly via WeatherSyncScheduler. Run once to start:
 *   WeatherSyncScheduler.scheduleHourly();
 */
public with sharing class WeatherSyncService {

    @TestVisible static final String BASE_URL    = 'https://api.weather.gov';
    @TestVisible static final String ALERT_PATH  = '/alerts/active?area=NC,SC';
    @TestVisible static final String SOURCE      = 'NWS';
    // Safety cap: max unique-lot geocoding calls (each uses 2 callouts: Points + Zones).
    @TestVisible static final Integer MAX_GEO_LOTS = 40;

    // ── public entry point ───────────────────────────────────────────────────

    @future(callout=true)
    public static void syncWeather() {
        try {
            // 1. Find today's Schedule_Day__c record.
            Id sdayId = getTodayScheduleDayId();

            // 2. SOQL: stops with direct GPS only. Legacy custom work order fallback was retired.
            List<Schedule_Stop__c> stops = sdayId == null ? new List<Schedule_Stop__c>() : [
                SELECT Id,
                       GPS_Latitude__c,
                       GPS_Longitude__c
                FROM Schedule_Stop__c
                WHERE Schedule_Day__c = :sdayId
            ];

            // 3. Find stop coordinates that need county geocoding.
            Map<Id, GeoPoint> stopsNeedingGeo = collectStopGeopoints(stops);

            // ── CALLOUTS start here (all DML comes after) ────────────────────

            // 4. Geocode stop coordinates via NWS Points + Zones (2 callouts each).
            Map<Id, LotGeoInfo> geoResults = geocodeStops(stopsNeedingGeo);

            // 5. Fetch NWS alerts.
            String alertsBody = fetchAlerts();
            if (alertsBody == null) return;

            List<Map<String, Object>> features = parseAlerts(alertsBody);

            // ── ALL CALLOUTS DONE — DML is safe now ──────────────────────────

            // 6. Delete today's NWS alerts and re-create from fresh data.
            if (sdayId != null) {
                delete [SELECT Id FROM Weather_Alert__c
                        WHERE Schedule_Day__c = :sdayId AND Source_System__c = :SOURCE];
            }

            // 7. Build county → max-severity map and insert new alerts.
            Map<String, String> maxSevByCounty = new Map<String, String>();
            List<Weather_Alert__c> alertsToInsert = buildAlertRecords(features, sdayId, maxSevByCounty);
            if (!alertsToInsert.isEmpty()) insert alertsToInsert;

            if (sdayId == null) return;

            // 8. Stamp each stop with its county-matched weather risk.
            stampStopRisks(stops, geoResults, maxSevByCounty, sdayId);

        } catch (Exception e) {
            writeErrorLog('syncWeather', e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    // ── NWS alert HTTP callout ────────────────────────────────────────────────

    @TestVisible
    static String fetchAlerts() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + ALERT_PATH);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/geo+json');
        req.setHeader('User-Agent', 'Loving-Companies-Salesforce megan@thelovingcompanies.com');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            writeErrorLog('fetchAlerts', 'NWS HTTP ' + res.getStatusCode() + ' — ' + res.getBody());
            return null;
        }
        return res.getBody();
    }

    // ── NWS Points + Zones geocoding (2 callouts per lot) ────────────────────

    @TestVisible
    static LotGeoInfo geocodeLot(Decimal lat, Decimal lng) {
        if (lat == null || lng == null) return null;
        String latStr = String.valueOf(lat.setScale(4));
        String lngStr = String.valueOf(lng.setScale(4));

        // Callout 1: NWS Points API → county zone URL + grid data for forecast caching.
        HttpRequest req1 = new HttpRequest();
        req1.setEndpoint(BASE_URL + '/points/' + latStr + ',' + lngStr);
        req1.setMethod('GET');
        req1.setHeader('Accept', 'application/json');
        req1.setHeader('User-Agent', 'Loving-Companies-Salesforce megan@thelovingcompanies.com');
        req1.setTimeout(10000);

        String zoneId;
        String gridOffice;
        Integer gridX;
        Integer gridY;
        try {
            HttpResponse res1 = new Http().send(req1);
            if (res1.getStatusCode() != 200) {
                writeErrorLog('geocodeLot', 'Points API HTTP ' + res1.getStatusCode() + ' for ' + latStr + ',' + lngStr);
                return null;
            }
            Map<String, Object> body1 = (Map<String, Object>) JSON.deserializeUntyped(res1.getBody());
            Map<String, Object> props1 = (Map<String, Object>) body1.get('properties');
            String countyUrl = toStr(props1.get('county'));
            if (String.isBlank(countyUrl)) return null;
            zoneId      = countyUrl.substringAfterLast('/');
            gridOffice  = toStr(props1.get('gridId'));
            Object gxObj = props1.get('gridX');
            Object gyObj = props1.get('gridY');
            gridX = (gxObj != null) ? Integer.valueOf(String.valueOf(gxObj)) : null;
            gridY = (gyObj != null) ? Integer.valueOf(String.valueOf(gyObj)) : null;
        } catch (Exception e) {
            writeErrorLog('geocodeLot', 'Points parse error: ' + e.getMessage());
            return null;
        }

        // Callout 2: NWS Zones API → county name + state.
        HttpRequest req2 = new HttpRequest();
        req2.setEndpoint(BASE_URL + '/zones/county/' + zoneId);
        req2.setMethod('GET');
        req2.setHeader('Accept', 'application/json');
        req2.setHeader('User-Agent', 'Loving-Companies-Salesforce megan@thelovingcompanies.com');
        req2.setTimeout(10000);

        try {
            HttpResponse res2 = new Http().send(req2);
            if (res2.getStatusCode() != 200) {
                writeErrorLog('geocodeLot', 'Zones API HTTP ' + res2.getStatusCode() + ' for zone ' + zoneId);
                return null;
            }
            Map<String, Object> body2 = (Map<String, Object>) JSON.deserializeUntyped(res2.getBody());
            Map<String, Object> props2 = (Map<String, Object>) body2.get('properties');
            LotGeoInfo info = new LotGeoInfo();
            info.countyName = toStr(props2.get('name'));
            info.state      = toStr(props2.get('state'));
            info.zoneId     = zoneId;
            info.gridOffice = gridOffice;
            info.gridX      = gridX;
            info.gridY      = gridY;
            return info;
        } catch (Exception e) {
            writeErrorLog('geocodeLot', 'Zones parse error: ' + e.getMessage());
            return null;
        }
    }

    // ── parsing ───────────────────────────────────────────────────────────────

    @TestVisible
    static List<Map<String, Object>> parseAlerts(String body) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (String.isBlank(body)) return result;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
            Object featObj = root.get('features');
            if (!(featObj instanceof List<Object>)) return result;
            for (Object f : (List<Object>) featObj) {
                if (f instanceof Map<String, Object>) {
                    Object propsObj = ((Map<String, Object>) f).get('properties');
                    if (propsObj instanceof Map<String, Object>) {
                        result.add((Map<String, Object>) propsObj);
                    }
                }
            }
        } catch (Exception e) {
            writeErrorLog('parseAlerts', e.getMessage());
        }
        return result;
    }

    // ── NWS areaDesc → county name list ──────────────────────────────────────

    @TestVisible
    static List<String> parseCounties(String areaDesc) {
        List<String> result = new List<String>();
        if (String.isBlank(areaDesc)) return result;
        for (String part : areaDesc.split(';')) {
            String county = part.trim();
            if (county.contains(',')) county = county.substringBefore(',').trim();
            if (county.endsWithIgnoreCase(' County')) {
                county = county.substring(0, county.length() - 7).trim();
            }
            if (!String.isBlank(county)) result.add(county);
        }
        return result;
    }

    // Derive state abbreviation from the alert's first county-type NWS UGC code.
    @TestVisible
    static String extractStateFromUgc(Map<String, Object> props) {
        Object geocodeObj = props.get('geocode');
        if (!(geocodeObj instanceof Map<String, Object>)) return null;
        Object ugcObj = ((Map<String, Object>) geocodeObj).get('UGC');
        if (!(ugcObj instanceof List<Object>)) return null;
        for (Object o : (List<Object>) ugcObj) {
            String code = toStr(o);
            // County UGC codes: NCC119, SCC023 (state+C+FIPS). Take first 2 chars = state.
            if (!String.isBlank(code) && code.length() >= 3 && code.substring(2, 3) == 'C') {
                return code.substring(0, 2);
            }
        }
        return null;
    }

    // ── internal helpers ──────────────────────────────────────────────────────

    @TestVisible
    static Id getTodayScheduleDayId() {
        List<Schedule_Day__c> sdays = [
            SELECT Id FROM Schedule_Day__c WHERE Schedule_Date__c = :Date.today() LIMIT 1
        ];
        return sdays.isEmpty() ? null : sdays[0].Id;
    }

    @TestVisible
    static Map<Id, GeoPoint> collectStopGeopoints(List<Schedule_Stop__c> stops) {
        Map<Id, GeoPoint> result = new Map<Id, GeoPoint>();
        for (Schedule_Stop__c s : stops) {
            if (result.containsKey(s.Id)) continue;
            if (s.GPS_Latitude__c != null && s.GPS_Longitude__c != null) {
                result.put(s.Id, new GeoPoint(s.GPS_Latitude__c, s.GPS_Longitude__c));
            }
        }
        return result;
    }

    @TestVisible
    static Map<Id, LotGeoInfo> geocodeStops(Map<Id, GeoPoint> stopPoints) {
        Map<Id, LotGeoInfo> results = new Map<Id, LotGeoInfo>();
        Integer count = 0;
        for (Id stopId : stopPoints.keySet()) {
            if (count >= MAX_GEO_LOTS) break;
            GeoPoint point = stopPoints.get(stopId);
            LotGeoInfo info = geocodeLot(point.lat, point.lng);
            if (info != null) results.put(stopId, info);
            count++;
        }
        return results;
    }

    @TestVisible
    static List<Weather_Alert__c> buildAlertRecords(
            List<Map<String, Object>> features,
            Id sdayId,
            Map<String, String> maxSevByCounty) {

        List<Weather_Alert__c> result = new List<Weather_Alert__c>();
        for (Map<String, Object> props : features) {
            String sfSev    = mapSeverity(toStr(props.get('severity')));
            String areaDesc = toStr(props.get('areaDesc'));
            String state    = extractStateFromUgc(props);
            List<String> counties = parseCounties(areaDesc);

            for (String county : counties) {
                if (severityRank(sfSev) > severityRank(maxSevByCounty.get(county))) {
                    maxSevByCounty.put(county, sfSev);
                }
                // Classify this county into one of the 7 LOVING markets.
                // Division__c = null means the alert is regional (no county match)
                // and will appear on all market cards as an advisory.
                String division = countyToMarket(county, state);

                Weather_Alert__c a = new Weather_Alert__c(
                    Alert_Type__c           = mapAlertType(toStr(props.get('event'))),
                    Summary__c              = trunc(toStr(props.get('headline')), 255),
                    Details__c              = trunc(toStr(props.get('description')), 32768),
                    Severity__c             = sfSev,
                    Division__c             = division,
                    County__c               = county,
                    State__c                = state,
                    NWS_Area_Description__c = trunc(areaDesc, 4000),
                    Source_System__c        = SOURCE,
                    Source_Location_Type__c = 'Lot GPS',
                    Alert_Date__c           = Date.today(),
                    Last_Refreshed__c       = DateTime.now(),
                    Start_DateTime__c       = toDateTime(toStr(props.get('effective'))),
                    End_DateTime__c         = toDateTime(toStr(props.get('expires')))
                );
                if (sdayId != null) a.Schedule_Day__c = sdayId;
                result.add(a);
            }
        }
        return result;
    }

    @TestVisible
    static void stampStopRisks(
            List<Schedule_Stop__c> stops,
            Map<Id, LotGeoInfo> geoResults,
            Map<String, String> maxSevByCounty,
            Id sdayId) {

        List<Schedule_Stop__c> stopsToUpdate = new List<Schedule_Stop__c>();
        Set<Id> stopsWithNoCounty = new Set<Id>();
        String overallMax = 'Low';

        for (Schedule_Stop__c s : stops) {
            String county = resolveCounty(s, geoResults);
            String risk   = 'Low';

            if (!String.isBlank(county)) {
                String alertSev = maxSevByCounty.get(county);
                if (alertSev != null) risk = alertSev;
                // else no active alert for this county → keep Low (clear weather)
            } else {
                stopsWithNoCounty.add(s.Id);
            }

            stopsToUpdate.add(new Schedule_Stop__c(Id = s.Id, Weather_Risk__c = risk));
            if (severityRank(risk) > severityRank(overallMax)) overallMax = risk;
        }

        if (!stopsToUpdate.isEmpty()) update stopsToUpdate;
        update new Schedule_Day__c(Id = sdayId, Weather_Risk__c = overallMax);

        if (!stopsWithNoCounty.isEmpty()) {
            writeErrorLog('stampStopRisks',
                'WARNING: ' + stopsWithNoCounty.size() + ' stop(s) have no county or lot GPS data.'
              + ' Populate Schedule_Stop__c.GPS_Latitude__c/GPS_Longitude__c'
              + ' for accurate per-county weather risk matching. Defaulted to Low.');
        }
    }

    // Resolve county for a stop from geocode results keyed by Schedule_Stop__c.Id.
    @TestVisible
    static String resolveCounty(Schedule_Stop__c s, Map<Id, LotGeoInfo> geoResults) {
        LotGeoInfo g = geoResults.get(s.Id);
        return (g != null) ? g.countyName : null;
    }

    @TestVisible
    class GeoPoint {
        Decimal lat;
        Decimal lng;
        GeoPoint(Decimal lat, Decimal lng) {
            this.lat = lat;
            this.lng = lng;
        }
    }

    // ── county → LOVING market classification ────────────────────────────────
    // Maps NWS county names to one of the 7 LOVING markets so that
    // Weather_Alert__c.Division__c is auto-populated on every sync.
    // State is used to disambiguate duplicate county names (e.g. "Union" in NC vs SC,
    // "Lee" in NC vs SC, "Lincoln" in NC vs GA).
    // Counties not listed default to null (regional advisory — shown on all 7 cards).

    @TestVisible
    static String countyToMarket(String county, String state) {
        if (String.isBlank(county)) return null;
        String c = county.trim().toLowerCase();
        String s = String.isBlank(state) ? '' : state.trim().toUpperCase();

        // ── Charlotte - North (NC counties north/east of I-485) ─────────────
        // Mecklenburg is the anchor. Iredell (Lake Norman), Cabarrus (Concord),
        // Rowan (Salisbury), Lincoln, Alexander, Catawba are included because
        // LOVING's North crews serve these areas.
        if (c == 'mecklenburg' && (s == 'NC' || s == '')) return 'Charlotte - North';
        if (c == 'iredell')   return 'Charlotte - North';
        if (c == 'cabarrus')  return 'Charlotte - North';
        if (c == 'rowan')     return 'Charlotte - North';
        if (c == 'lincoln'  && (s == 'NC' || s == '')) return 'Charlotte - North';
        if (c == 'alexander') return 'Charlotte - North';
        if (c == 'catawba')   return 'Charlotte - North';

        // ── Charlotte - South (NC/SC border counties south of I-485) ────────
        // Gaston (Gastonia/Belmont), York SC (Fort Mill/Rock Hill),
        // Lancaster SC (Indian Land), Union NC (Monroe), Cleveland NC.
        if (c == 'gaston'  && (s == 'NC' || s == '')) return 'Charlotte - South';
        if (c == 'york'    && (s == 'SC' || s == '')) return 'Charlotte - South';
        if (c == 'lancaster' && (s == 'SC' || s == '')) return 'Charlotte - South';
        if (c == 'union'   && (s == 'NC' || s == '')) return 'Charlotte - South';
        if (c == 'cleveland' && (s == 'NC' || s == '')) return 'Charlotte - South';

        // ── Asheville (Western NC) ────────────────────────────────────────────
        if (c == 'buncombe')     return 'Asheville';
        if (c == 'henderson')    return 'Asheville';
        if (c == 'transylvania') return 'Asheville';
        if (c == 'haywood')      return 'Asheville';
        if (c == 'madison' && (s == 'NC' || s == '')) return 'Asheville';
        if (c == 'rutherford' && (s == 'NC' || s == '')) return 'Asheville';
        if (c == 'mcdowell')     return 'Asheville';
        if (c == 'polk' && (s == 'NC' || s == '')) return 'Asheville';
        if (c == 'mitchell')     return 'Asheville';
        if (c == 'yancey')       return 'Asheville';
        if (c == 'avery')        return 'Asheville';
        if (c == 'watauga')      return 'Asheville';
        if (c == 'burke')        return 'Asheville';
        if (c == 'caldwell')     return 'Asheville';
        if (c == 'wilkes')       return 'Asheville';
        if (c == 'ashe')         return 'Asheville';
        if (c == 'alleghany')    return 'Asheville';

        // ── Triad (Piedmont NC) ───────────────────────────────────────────────
        if (c == 'guilford')   return 'Triad';
        if (c == 'forsyth')    return 'Triad';
        if (c == 'alamance')   return 'Triad';
        if (c == 'randolph')   return 'Triad';
        if (c == 'davie')      return 'Triad';
        if (c == 'davidson')   return 'Triad';
        if (c == 'stokes')     return 'Triad';
        if (c == 'rockingham') return 'Triad';
        if (c == 'caswell')    return 'Triad';
        if (c == 'yadkin')     return 'Triad';
        if (c == 'surry')      return 'Triad';

        // ── Greenville (Upstate SC) ───────────────────────────────────────────
        if (c == 'greenville' && (s == 'SC' || s == '')) return 'Greenville';
        if (c == 'spartanburg') return 'Greenville';
        if (c == 'anderson' && (s == 'SC' || s == '')) return 'Greenville';
        if (c == 'pickens' && (s == 'SC' || s == '')) return 'Greenville';
        if (c == 'oconee')  return 'Greenville';
        if (c == 'cherokee' && (s == 'SC' || s == '')) return 'Greenville';
        if (c == 'union'    && (s == 'SC' || s == '')) return 'Greenville';
        if (c == 'laurens' && (s == 'SC' || s == '')) return 'Greenville';
        if (c == 'abbeville') return 'Greenville';
        if (c == 'chester' && (s == 'SC' || s == '')) return 'Greenville';

        // ── Columbia (Midlands SC) ────────────────────────────────────────────
        if (c == 'richland')   return 'Columbia';
        if (c == 'lexington' && (s == 'SC' || s == '')) return 'Columbia';
        if (c == 'kershaw')    return 'Columbia';
        if (c == 'calhoun' && (s == 'SC' || s == '')) return 'Columbia';
        if (c == 'fairfield' && (s == 'SC' || s == '')) return 'Columbia';
        if (c == 'saluda')     return 'Columbia';
        if (c == 'newberry')   return 'Columbia';
        if (c == 'orangeburg') return 'Columbia';
        if (c == 'sumter')     return 'Columbia';
        if (c == 'lee' && (s == 'SC' || s == '')) return 'Columbia';

        // ── Triangle (Central NC — Raleigh/Durham/Chapel Hill metro) ─────────
        if (c == 'wake')      return 'Triangle';
        if (c == 'durham')    return 'Triangle';
        if (c == 'orange' && (s == 'NC' || s == '')) return 'Triangle';
        if (c == 'chatham')   return 'Triangle';
        if (c == 'johnston')  return 'Triangle';
        if (c == 'harnett')   return 'Triangle';
        if (c == 'lee' && (s == 'NC' || s == '')) return 'Triangle';
        if (c == 'moore' && (s == 'NC' || s == '')) return 'Triangle';
        if (c == 'person')    return 'Triangle';
        if (c == 'granville') return 'Triangle';
        if (c == 'vance')     return 'Triangle';
        if (c == 'franklin' && (s == 'NC' || s == '')) return 'Triangle';
        if (c == 'nash')      return 'Triangle';

        // County not in LOVING's primary service area — return null so alert
        // appears as a regional advisory across all market cards.
        return null;
    }

    // ── mapping helpers ───────────────────────────────────────────────────────

    @TestVisible
    static String mapAlertType(String event) {
        if (String.isBlank(event)) return 'Other';
        String e = event.toLowerCase();
        if (e.contains('severe thunderstorm') || e.contains('tornado')) return 'Severe Thunderstorm';
        if (e.contains('thunderstorm'))                                  return 'Thunderstorm';
        if (e.contains('rain') || e.contains('flood') || e.contains('fog')) return 'Rain';
        if (e.contains('wind'))                                          return 'Wind';
        if (e.contains('heat'))                                          return 'Heat';
        if (e.contains('freeze') || e.contains('frost') || e.contains('ice')
            || e.contains('snow') || e.contains('winter') || e.contains('blizzard')) return 'Freeze';
        return 'Other';
    }

    @TestVisible
    static String mapSeverity(String raw) {
        if (String.isBlank(raw)) return 'Low';
        switch on raw.toLowerCase().trim() {
            when 'extreme'  { return 'Severe'; }
            when 'severe'   { return 'High'; }
            when 'moderate' { return 'Medium'; }
            when 'minor'    { return 'Low'; }
            when else       { return 'Low'; }
        }
    }

    @TestVisible
    static Integer severityRank(String sev) {
        if (sev == 'Severe') return 4;
        if (sev == 'High')   return 3;
        if (sev == 'Medium') return 2;
        return 1; // Low or null
    }

    // ── utilities ─────────────────────────────────────────────────────────────

    @TestVisible static String toStr(Object o) { return o == null ? null : String.valueOf(o); }

    @TestVisible
    static String trunc(String s, Integer maxLen) {
        if (s == null || s.length() <= maxLen) return s;
        return s.substring(0, maxLen);
    }

    @TestVisible
    static DateTime toDateTime(String s) {
        if (String.isBlank(s)) return null;
        try {
            if (s.endsWith('Z')) { s = s.replace('Z', '+0000'); }
            return (DateTime) JSON.deserialize('"' + s + '"', DateTime.class);
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    static void writeErrorLog(String method, String message) {
        System.debug(LoggingLevel.ERROR, 'WeatherSyncService.' + method + ': ' + message);
        try {
            insert new Error_Log__c(
                Class_Name__c  = 'WeatherSyncService',
                Method_Name__c = method,
                Message__c     = message,
                Logged_At__c   = DateTime.now()
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'WeatherSyncService: could not write Error_Log__c: ' + e.getMessage());
        }
    }

    // ── inner classes ─────────────────────────────────────────────────────────

    public class LotGeoInfo {
        public String  countyName;
        public String  state;
        public String  zoneId;
        public String  gridOffice;
        public Integer gridX;
        public Integer gridY;
    }
}