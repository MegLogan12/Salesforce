/**
 * LovingVehicleMapController
 * Live vehicle positions for the Field Services Route + GPS map.
 * Reads WEX_GPS_Position__c (latest position per vehicle). No hardcoded data;
 * empty list renders a clean unavailable state. Street addresses require a
 * reverse-geocoding service (not yet configured) — location returns coordinates.
 */
public with sharing class LovingVehicleMapController {
    public class VehiclePosition {
        @AuraEnabled public String id;
        @AuraEnabled public String vehicleName;
        @AuraEnabled public String driverName;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public Decimal speed;
        @AuraEnabled public String ignition;
        @AuraEnabled public String lastSeen;
        @AuraEnabled public String location;
    }

    @AuraEnabled(cacheable=true)
    public static List<VehiclePosition> getLiveVehiclePositions() {
        List<VehiclePosition> out = new List<VehiclePosition>();
        if (!Schema.getGlobalDescribe().containsKey('WEX_GPS_Position__c')) return out;
        Set<Id> seen = new Set<Id>();
        for (WEX_GPS_Position__c p : [
            SELECT Id, Vehicle__c, Vehicle__r.Name, Driver__r.Name,
                   Latitude__c, Longitude__c, Speed_MPH__c, Ignition_Status__c, Last_Seen_DateTime__c
            FROM WEX_GPS_Position__c
            WHERE Latitude__c != null AND Longitude__c != null
            ORDER BY Last_Seen_DateTime__c DESC NULLS LAST
            LIMIT 500
        ]) {
            if (p.Vehicle__c != null && seen.contains(p.Vehicle__c)) continue;
            if (p.Vehicle__c != null) seen.add(p.Vehicle__c);
            VehiclePosition v = new VehiclePosition();
            v.id = p.Id;
            v.vehicleName = (p.Vehicle__r != null) ? p.Vehicle__r.Name : 'Unknown vehicle';
            v.driverName  = (p.Driver__r != null) ? p.Driver__r.Name : 'Unassigned';
            v.latitude  = p.Latitude__c;
            v.longitude = p.Longitude__c;
            v.speed     = p.Speed_MPH__c;
            v.ignition  = p.Ignition_Status__c;
            v.lastSeen  = (p.Last_Seen_DateTime__c != null) ? p.Last_Seen_DateTime__c.format() : '';
            v.location  = p.Latitude__c + ', ' + p.Longitude__c;
            out.add(v);
        }
        return out;
    }

    /**
     * Same vehicle positions, but with `location` reverse-geocoded to a street address via
     * OpenStreetMap Nominatim (free, no key). Used by the trucks list (loaded on demand, not on
     * the 30s map poll, to respect Nominatim usage). Falls back to coordinates on any failure.
     */
    @AuraEnabled
    public static List<VehiclePosition> getVehiclesWithAddresses() {
        List<VehiclePosition> vlist = getLiveVehiclePositions();
        Integer geocoded = 0;
        for (VehiclePosition v : vlist) {
            if (geocoded >= 25) { break; }
            if (v.latitude == null || v.longitude == null) { continue; }
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://nominatim.openstreetmap.org/reverse?format=json&zoom=18&lat='
                    + v.latitude + '&lon=' + v.longitude);
                req.setMethod('GET');
                req.setHeader('User-Agent', 'LOVING-Salesforce-FieldServices/1.0');
                req.setTimeout(10000);
                HttpResponse res = new Http().send(req);
                if (res.getStatusCode() == 200) {
                    Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    Object dn = m.get('display_name');
                    if (dn != null && String.isNotBlank(String.valueOf(dn))) {
                        v.location = String.valueOf(dn);
                    }
                }
                geocoded++;
            } catch (Exception e) {
                // keep coordinates on failure
            }
        }
        return vlist;
    }
}