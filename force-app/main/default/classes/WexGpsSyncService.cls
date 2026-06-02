/**
 * GPS Insight (WEX Fleet Intelligence) vehicle position sync — fully automated auth.
 *
 * Pulls latest vehicle locations from the GPS Insight API v2, upserts one
 * WEX_GPS_Position__c record per vehicle, and mirrors lat/lng/timestamp to Vehicle__c.
 *
 * ── Authentication — no manual token management required ─────────────────────
 * Credentials are stored in GPS_Insight_Config__c Custom Setting (org defaults).
 * Set these once via Setup → Custom Settings → GPS Insight Config → Manage:
 *   • Username__c  — your GPS Insight login username
 *   • App_Token__c — your non-expiring app token
 *     (GPS Insight portal: Account → Manage Users → Third-party API V2 access)
 *
 * The service calls userauth/login automatically to get a fresh session_token
 * whenever the cached one is within 1 hour of expiry (token lasts ~1 week).
 * Session_Token__c and Token_Expiry__c in the Custom Setting are managed by Apex.
 *
 * ── Named Credential ─────────────────────────────────────────────────────────
 * WEX GPS API (WEX_GPS_API): URL = https://api.gpsinsight.com
 * No authentication fields needed — all auth is handled in Apex.
 *
 * ── GPS Insight API v2 response shape ────────────────────────────────────────
 *   { "head": {...}, "data": [
 *       { "id": "VVYYY...", "latitude": 33.66, "longitude": -111.92,
 *         "fix_time_gmt": "2015-08-14T14:27:10+00:00",
 *         "inst_speed": 0, "heading": 16, "ignition": "off",
 *         "address": "...", "first_name": "...", "last_name": "..." }
 *   ] }
 *
 * ── Scheduler ────────────────────────────────────────────────────────────────
 * Start from Anonymous Apex (run once after deploy):
 *   WexGpsSyncScheduler.start();
 */
public with sharing class WexGpsSyncService {

    @TestVisible static final String NAMED_CRED    = 'callout:WEX_GPS_API';
    @TestVisible static final String LOGIN_PATH    = '/v2/userauth/login';
    @TestVisible static final String LOCATION_PATH = '/v2/vehicle/location';

    // Refresh the cached session token when it has less than this much time left.
    @TestVisible static final Integer REFRESH_BUFFER_HOURS = 1;

    // ── public entry point ───────────────────────────────────────────────────

    @future(callout=true)
    public static void syncPositions() {
        if (!isObjectAccessible('WEX_GPS_Position__c') || !isObjectAccessible('Vehicle__c')) {
            writeErrorLog('syncPositions', 'Required objects (WEX_GPS_Position__c, Vehicle__c) not accessible');
            return;
        }
        try {
            GPS_Insight_Config__c config = GPS_Insight_Config__c.getOrgDefaults();
            String  token          = null;
            Boolean tokenRefreshed = false;

            // Use cached token if still fresh — no callout needed.
            if (!String.isBlank(config.Session_Token__c)
                    && config.Token_Expiry__c != null
                    && config.Token_Expiry__c > DateTime.now().addHours(REFRESH_BUFFER_HOURS)) {
                token = config.Session_Token__c;
            } else {
                // Must authenticate before any DML, so validate credentials first.
                if (String.isBlank(config.Username__c) || String.isBlank(config.App_Token__c)) {
                    writeErrorLog('syncPositions', 'Could not obtain GPS Insight session token — check GPS_Insight_Config__c credentials');
                    return;
                }
                token = authenticate(config.Username__c, config.App_Token__c); // callout #1
                if (String.isBlank(token)) {
                    writeErrorLog('syncPositions', 'Could not obtain GPS Insight session token — check GPS_Insight_Config__c credentials');
                    return;
                }
                tokenRefreshed = true;
            }

            // All callouts must complete before any DML.
            List<Map<String, Object>> vehicles = fetchPositions(token); // callout #2 (or only callout)

            // Safe to DML now — all callouts are done.
            if (tokenRefreshed) {
                config.Session_Token__c = token;
                config.Token_Expiry__c  = DateTime.now().addDays(6);
                upsert config;
            }
            if (!vehicles.isEmpty()) {
                processPositions(vehicles);
            }
        } catch (Exception e) {
            writeErrorLog('syncPositions', e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    // ── session token management ─────────────────────────────────────────────

    @TestVisible
    static String getSessionToken() {
        GPS_Insight_Config__c config = GPS_Insight_Config__c.getOrgDefaults();

        // Use cached token if it's still fresh (more than REFRESH_BUFFER_HOURS remaining).
        if (!String.isBlank(config.Session_Token__c)
                && config.Token_Expiry__c != null
                && config.Token_Expiry__c > DateTime.now().addHours(REFRESH_BUFFER_HOURS)) {
            return config.Session_Token__c;
        }

        // Token is missing, expired, or about to expire — re-authenticate.
        if (String.isBlank(config.Username__c) || String.isBlank(config.App_Token__c)) {
            writeErrorLog('getSessionToken', 'GPS_Insight_Config__c.Username__c or App_Token__c is blank — set via Setup → Custom Settings');
            return null;
        }

        String newToken = authenticate(config.Username__c, config.App_Token__c);
        if (!String.isBlank(newToken)) {
            config.Session_Token__c = newToken;
            config.Token_Expiry__c  = DateTime.now().addDays(6); // conservative — token lasts ~1 week
            upsert config;
        }
        return newToken;
    }

    @TestVisible
    static String authenticate(String username, String appToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CRED + LOGIN_PATH
            + '?username=' + EncodingUtil.urlEncode(username, 'UTF-8')
            + '&app_token=' + EncodingUtil.urlEncode(appToken, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(15000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            writeErrorLog('authenticate', 'Login HTTP ' + res.getStatusCode() + ' — ' + res.getBody());
            return null;
        }

        try {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Object dataObj = body.get('data');
            // Real API returns data as an object: {"token":"..."}
            if (dataObj instanceof Map<String, Object>) {
                return toStr(((Map<String, Object>) dataObj).get('token'));
            }
            // Fallback: some API versions return data as an array: [{"token":"..."}]
            if (dataObj instanceof List<Object>) {
                List<Object> dataList = (List<Object>) dataObj;
                if (!dataList.isEmpty() && dataList[0] instanceof Map<String, Object>) {
                    return toStr(((Map<String, Object>) dataList[0]).get('token'));
                }
            }
        } catch (Exception e) {
            writeErrorLog('authenticate', 'Could not parse login response: ' + e.getMessage());
        }
        return null;
    }

    // ── core processing ──────────────────────────────────────────────────────

    @TestVisible
    static void processPositions(List<Map<String, Object>> vehicles) {
        // GPS Insight returns vehicles with an internal "id" (e.g. "CA3271286655") and a
        // human "label" (e.g. "105"). Vehicle__c.GPS_Insights_Id__c stores the fleet label
        // (105, 107, ...) NOT the internal CA-prefixed serial. Match on label.
        Set<String> gpsIds   = new Set<String>(); // fleet labels
        Set<String> gpsNames = new Set<String>(); // "FirstName LastName" from GPS response
        for (Map<String, Object> v : vehicles) {
            String lbl = toStr(v.get('label'));
            if (!String.isBlank(lbl)) { gpsIds.add(lbl); }
            String fn = toStr(v.get('first_name'));
            String ln = toStr(v.get('last_name'));
            if (!String.isBlank(fn) && !String.isBlank(ln)) {
                gpsNames.add((fn + ' ' + ln).trim());
            }
        }
        if (gpsIds.isEmpty()) { return; }

        // Vehicle lookup: pull Assigned_Driver__c so we can link Employee without extra queries.
        Map<String, Vehicle__c> vehicleByGpsId = new Map<String, Vehicle__c>();
        for (Vehicle__c v : [
            SELECT Id, GPS_Insights_Id__c, Assigned_Driver__c
            FROM Vehicle__c
            WHERE GPS_Insights_Id__c IN :gpsIds
        ]) {
            vehicleByGpsId.put(v.GPS_Insights_Id__c, v);
        }
        if (vehicleByGpsId.isEmpty()) { return; }

        Set<Id> sfVehicleIds = new Set<Id>();
        Set<Id> assignedDriverIds = new Set<Id>();
        for (Vehicle__c v : vehicleByGpsId.values()) { sfVehicleIds.add(v.Id); }
        for (Vehicle__c v : vehicleByGpsId.values()) {
            if (v.Assigned_Driver__c != null) assignedDriverIds.add(v.Assigned_Driver__c);
        }

        Map<Id, WEX_GPS_Position__c> existingByVehicle = new Map<Id, WEX_GPS_Position__c>();
        for (WEX_GPS_Position__c pos : [
            SELECT Id, Vehicle__c
            FROM WEX_GPS_Position__c
            WHERE Vehicle__c IN :sfVehicleIds
        ]) {
            existingByVehicle.put(pos.Vehicle__c, pos);
        }

        // Build a name→Employee__c.Id map for driver name fallback resolution.
        Map<String, Id> employeeByFullName = new Map<String, Id>();
        Map<Id, Id> employeeToCrew = new Map<Id, Id>();
        if (!gpsNames.isEmpty() || !assignedDriverIds.isEmpty()) {
            for (Employee__c emp : [
                SELECT Id, Name, Crew__c
                FROM Employee__c
                WHERE (Name IN :gpsNames OR Id IN :assignedDriverIds)
                  AND Status__c = 'Active'
            ]) {
                employeeByFullName.put(emp.Name, emp.Id);
                employeeToCrew.put(emp.Id, emp.Crew__c);
            }
        }

        List<WEX_GPS_Position__c> toInsert       = new List<WEX_GPS_Position__c>();
        List<WEX_GPS_Position__c> toUpdate        = new List<WEX_GPS_Position__c>();
        List<Vehicle__c>          vehicleUpdates  = new List<Vehicle__c>();
        DateTime                  now             = DateTime.now();

        for (Map<String, Object> raw : vehicles) {
            String   gpsId   = toStr(raw.get('label')); // match on fleet label, not internal CA-id
            Vehicle__c veh   = vehicleByGpsId.get(gpsId);
            if (veh == null) { continue; }
            Id sfId = veh.Id;

            // Resolve driver: prefer Vehicle.Assigned_Driver__c, fall back to GPS name match.
            Id driverId = veh.Assigned_Driver__c;
            if (driverId == null) {
                String fn   = toStr(raw.get('first_name'));
                String ln   = toStr(raw.get('last_name'));
                String full = (!String.isBlank(fn) && !String.isBlank(ln))
                              ? (fn + ' ' + ln).trim() : null;
                if (full != null) { driverId = employeeByFullName.get(full); }
            }
            Id crewId = driverId != null ? employeeToCrew.get(driverId) : null;

            WEX_GPS_Position__c pos  = existingByVehicle.get(sfId);
            Boolean             isNew = (pos == null);
            if (isNew) { pos = new WEX_GPS_Position__c(Vehicle__c = sfId); }
            applyPositionFields(pos, raw);
            pos.Driver__c = driverId;
            pos.Crew__c = crewId;

            if (isNew) { toInsert.add(pos); } else { toUpdate.add(pos); }

            Decimal  lat = toDecimal(raw.get('latitude'));
            Decimal  lng = toDecimal(raw.get('longitude'));
            DateTime ts  = toDateTime(toStr(raw.get('fix_time_gmt')));

            vehicleUpdates.add(new Vehicle__c(
                Id                         = sfId,
                GPS_Latitude__c            = lat,
                GPS_Longitude__c           = lng,
                GPS_Last_Seen__c           = ts,
                GPS_Status__c              = deriveGpsStatus(ts, now),
                Last_Location_Lat__c       = lat,
                Last_Location_Lng__c       = lng,
                Last_Location_Timestamp__c = ts,
                Last_GPS_Sync__c           = now,
                Last_Location_Address__c   = toStr(raw.get('address'))
            ));
        }

        if (!toInsert.isEmpty())       { insert toInsert; }
        if (!toUpdate.isEmpty())       { update toUpdate; }
        if (!vehicleUpdates.isEmpty()) { update vehicleUpdates; }
    }

    // ── field mapping ────────────────────────────────────────────────────────

    @TestVisible
    static void applyPositionFields(WEX_GPS_Position__c pos, Map<String, Object> raw) {
        pos.Latitude__c           = toDecimal(raw.get('latitude'));
        pos.Longitude__c          = toDecimal(raw.get('longitude'));
        pos.Speed_MPH__c          = toDecimal(raw.get('inst_speed'));
        pos.Heading__c            = toDecimal(raw.get('heading'));
        pos.Last_Seen_DateTime__c = toDateTime(toStr(raw.get('fix_time_gmt')));
        pos.Ignition_Status__c    = mapIgnitionStatus(toStr(raw.get('ignition')));
        pos.Source_System__c      = 'WEX GPS';
        pos.Raw_Payload__c        = JSON.serialize(raw);
    }

    // ── HTTP callout ─────────────────────────────────────────────────────────

    @TestVisible
    static List<Map<String, Object>> fetchPositions(String sessionToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CRED + LOCATION_PATH + '?session_token=' + sessionToken);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            writeErrorLog('fetchPositions', 'HTTP ' + res.getStatusCode() + ' — ' + res.getBody());
            return new List<Map<String, Object>>();
        }
        return parseVehicleList(res.getBody());
    }

    @TestVisible
    static List<Map<String, Object>> parseVehicleList(String body) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (String.isBlank(body)) { return result; }
        Object parsed = JSON.deserializeUntyped(body);
        List<Object> items = null;

        if (parsed instanceof List<Object>) {
            items = (List<Object>) parsed;
        } else if (parsed instanceof Map<String, Object>) {
            Map<String, Object> root = (Map<String, Object>) parsed;
            Object r = root.get('data');
            if (r == null) { r = root.get('vehicles'); }
            if (r == null) { r = root.get('results'); }
            if (r instanceof List<Object>) { items = (List<Object>) r; }
        }

        if (items != null) {
            for (Object o : items) {
                if (o instanceof Map<String, Object>) {
                    result.add((Map<String, Object>) o);
                }
            }
        }
        return result;
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    @TestVisible
    static String mapIgnitionStatus(String raw) {
        if (String.isBlank(raw)) { return 'Unknown'; }
        String s = raw.toLowerCase().trim();
        if (s == 'on'  || s == 'true'  || s == '1') { return 'On'; }
        if (s == 'off' || s == 'false' || s == '0') { return 'Off'; }
        return 'Unknown';
    }

    @TestVisible
    static String deriveGpsStatus(DateTime lastSeen, DateTime now) {
        if (lastSeen == null) { return 'Unknown'; }
        Long minutesAgo = (now.getTime() - lastSeen.getTime()) / 60000;
        if (minutesAgo <= 10)  { return 'Active'; }
        if (minutesAgo <= 120) { return 'Delayed'; }
        return 'Offline';
    }

    @TestVisible
    static Boolean isObjectAccessible(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(apiName)) { return false; }
        return gd.get(apiName).getDescribe().isAccessible();
    }

    @TestVisible
    static void writeErrorLog(String methodName, String message) {
        System.debug(LoggingLevel.ERROR, 'WexGpsSyncService.' + methodName + ': ' + message);
        try {
            insert new Error_Log__c(
                Class_Name__c  = 'WexGpsSyncService',
                Method_Name__c = methodName,
                Message__c     = message,
                Logged_At__c   = DateTime.now()
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'WexGpsSyncService: could not write Error_Log__c: ' + e.getMessage());
        }
    }

    @TestVisible
    static String toStr(Object o) { return o == null ? null : String.valueOf(o); }

    @TestVisible
    static Decimal toDecimal(Object o) {
        if (o == null) { return null; }
        try { return Decimal.valueOf(String.valueOf(o)); } catch (Exception e) { return null; }
    }

    @TestVisible
    static DateTime toDateTime(String s) {
        if (String.isBlank(s)) { return null; }
        try {
            if (s.endsWith('Z')) { s = s.replace('Z', '+0000'); }
            return (DateTime) JSON.deserialize('"' + s + '"', DateTime.class);
        } catch (Exception e) {
            return null;
        }
    }
}