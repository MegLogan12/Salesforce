/**
 * GPS Insights fleet telematics sync.
 *
 * Pulls the vehicle list and the latest location per vehicle from the
 * GPS Insights API via the GPSInsights Named Credential and upserts into
 * Vehicle__c + Vehicle_Location__c.
 */
public with sharing class GpsInsightsSyncService {

    public static final String BASE_URL = 'callout:GPSInsights';
    public static final String VEHICLES_PATH = '/v1/vehicles';
    public static final String LOCATIONS_PATH = '/v1/locations/latest';

    @future(callout=true)
    public static void syncVehicles() {
        if (!isObjectAccessible('Vehicle__c')) {
            System.debug(LoggingLevel.WARN, 'GpsInsightsSyncService.syncVehicles: Vehicle__c not accessible.');
            return;
        }
        try {
            List<Map<String, Object>> raw = fetchJsonList(VEHICLES_PATH);
            List<Vehicle__c> toUpsert = new List<Vehicle__c>();
            for (Map<String, Object> v : raw) {
                Vehicle__c veh = mapVehicleResponse(v);
                if (veh != null) {
                    toUpsert.add(veh);
                }
            }
            if (!toUpsert.isEmpty()) {
                Schema.SObjectField extId = Vehicle__c.Fields.GPS_Insights_Id__c;
                Database.upsert(toUpsert, extId, false);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'GpsInsightsSyncService.syncVehicles failed: ' + e.getMessage());
        }
    }

    @future(callout=true)
    public static void syncLocations() {
        if (!isObjectAccessible('Vehicle__c') || !isObjectAccessible('Vehicle_Location__c')) {
            System.debug(LoggingLevel.WARN, 'GpsInsightsSyncService.syncLocations: required objects missing.');
            return;
        }
        try {
            List<Map<String, Object>> raw = fetchJsonList(LOCATIONS_PATH);
            Map<String, Id> vehiclesById = queryVehicleMap(raw);

            List<Vehicle_Location__c> locs = new List<Vehicle_Location__c>();
            Map<Id, Vehicle__c> vehUpdates = new Map<Id, Vehicle__c>();
            for (Map<String, Object> rec : raw) {
                String extVehId = toStr(rec.get('vehicle_id'));
                Id vehId = vehiclesById.get(extVehId);
                if (vehId == null) {
                    continue;
                }
                Vehicle_Location__c loc = mapLocationResponse(rec, vehId);
                if (loc != null) {
                    locs.add(loc);
                }
                Vehicle__c v = vehUpdates.get(vehId);
                if (v == null) {
                    v = new Vehicle__c(Id = vehId);
                    vehUpdates.put(vehId, v);
                }
                v.Last_Location_Lat__c = toDecimal(rec.get('latitude'));
                v.Last_Location_Lng__c = toDecimal(rec.get('longitude'));
                v.Last_Location_Address__c = toStr(rec.get('address'));
                v.Last_Location_Timestamp__c = toDateTime(rec.get('timestamp'));
                v.Odometer_Miles__c = toDecimal(rec.get('odometer_miles'));
                v.Last_GPS_Sync__c = DateTime.now();
            }
            if (!locs.isEmpty()) {
                insert locs;
            }
            if (!vehUpdates.isEmpty()) {
                update vehUpdates.values();
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'GpsInsightsSyncService.syncLocations failed: ' + e.getMessage());
        }
    }

    @TestVisible
    private static Vehicle__c mapVehicleResponse(Map<String, Object> raw) {
        if (raw == null) { return null; }
        String id = toStr(raw.get('id'));
        if (String.isBlank(id)) { return null; }
        Vehicle__c v = new Vehicle__c();
        v.GPS_Insights_Id__c = id;
        v.VIN__c = toStr(raw.get('vin'));
        v.License_Plate__c = toStr(raw.get('license_plate'));
        v.Make__c = toStr(raw.get('make'));
        v.Model__c = toStr(raw.get('model'));
        Decimal year = toDecimal(raw.get('year'));
        v.Year__c = year == null ? null : year;
        v.Odometer_Miles__c = toDecimal(raw.get('odometer_miles'));
        v.Status__c = mapStatus(toStr(raw.get('status')));
        v.Last_GPS_Sync__c = DateTime.now();
        return v;
    }

    @TestVisible
    private static Vehicle_Location__c mapLocationResponse(Map<String, Object> raw, Id vehicleId) {
        if (raw == null || vehicleId == null) { return null; }
        Vehicle_Location__c loc = new Vehicle_Location__c();
        loc.Vehicle__c = vehicleId;
        loc.GPS_Insights_Location_Id__c = toStr(raw.get('id'));
        loc.Latitude__c = toDecimal(raw.get('latitude'));
        loc.Longitude__c = toDecimal(raw.get('longitude'));
        loc.Address__c = toStr(raw.get('address'));
        loc.Timestamp__c = toDateTime(raw.get('timestamp'));
        if (loc.Timestamp__c == null) {
            loc.Timestamp__c = DateTime.now();
        }
        loc.Speed_Mph__c = toDecimal(raw.get('speed_mph'));
        Object ign = raw.get('ignition_on');
        loc.Ignition_On__c = ign == null ? false : toBool(ign);
        loc.Odometer_Miles__c = toDecimal(raw.get('odometer_miles'));
        return loc;
    }

    @TestVisible
    private static Map<String, Id> queryVehicleMap(List<Map<String, Object>> raw) {
        Set<String> ids = new Set<String>();
        for (Map<String, Object> r : raw) {
            String id = toStr(r.get('vehicle_id'));
            if (!String.isBlank(id)) {
                ids.add(id);
            }
        }
        Map<String, Id> out = new Map<String, Id>();
        if (ids.isEmpty()) { return out; }
        for (Vehicle__c v : [SELECT Id, GPS_Insights_Id__c FROM Vehicle__c WHERE GPS_Insights_Id__c IN :ids]) {
            out.put(v.GPS_Insights_Id__c, v.Id);
        }
        return out;
    }

    @TestVisible
    private static List<Map<String, Object>> fetchJsonList(String path) {
        List<Map<String, Object>> all = new List<Map<String, Object>>();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + path);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        IntegrationSecrets.applyAuth(req, 'GPS_Insights');
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            System.debug(LoggingLevel.ERROR, 'GpsInsights HTTP ' + res.getStatusCode() + ' ' + path);
            return all;
        }
        Object parsed = JSON.deserializeUntyped(res.getBody());
        List<Object> items = null;
        if (parsed instanceof List<Object>) {
            items = (List<Object>) parsed;
        } else if (parsed instanceof Map<String, Object>) {
            Map<String, Object> body = (Map<String, Object>) parsed;
            Object r = body.get('results');
            if (r == null) { r = body.get('data'); }
            if (r instanceof List<Object>) {
                items = (List<Object>) r;
            }
        }
        if (items != null) {
            for (Object o : items) {
                if (o instanceof Map<String, Object>) {
                    all.add((Map<String, Object>) o);
                }
            }
        }
        return all;
    }

    @TestVisible
    private static Boolean isObjectAccessible(String objectApiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objectApiName)) { return false; }
        return gd.get(objectApiName).getDescribe().isAccessible();
    }

    @TestVisible
    private static String mapStatus(String raw) {
        if (String.isBlank(raw)) { return 'Active'; }
        String s = raw.toLowerCase();
        if (s.contains('shop')) { return 'In Shop'; }
        if (s.contains('retir')) { return 'Retired'; }
        return 'Active';
    }

    @TestVisible
    private static String toStr(Object o) { return o == null ? null : String.valueOf(o); }

    @TestVisible
    private static Decimal toDecimal(Object o) {
        if (o == null) { return null; }
        try { return Decimal.valueOf(String.valueOf(o)); } catch (Exception e) { return null; }
    }

    @TestVisible
    private static DateTime toDateTime(Object o) {
        if (o == null) { return null; }
        try {
            String s = String.valueOf(o);
            if (s.endsWith('Z')) { s = s.replace('Z', '+0000'); }
            return (DateTime) JSON.deserialize('"' + s + '"', DateTime.class);
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static Boolean toBool(Object o) {
        if (o == null) { return false; }
        if (o instanceof Boolean) { return (Boolean) o; }
        String s = String.valueOf(o).toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
    }
}