/**
 * WEXVehicleSyncService — syncs GPS Insight /vehicle endpoint to Vehicle__c.
 *
 * Upserts one Vehicle__c record per GPS Insight vehicle using GPS_Insights_Id__c
 * as the external ID.  Name is an AutoNumber on Vehicle__c — new records get the
 * next auto-number automatically; existing records are updated in place.
 *
 * Fields updated: Make__c, Model__c, Year__c, VIN__c, License_Plate__c, Odometer_Miles__c.
 *
 * Called by GPSINTEGRATION.execute() for SyncType.ALL and SyncType.VEHICLES.
 */
public with sharing class WEXVehicleSyncService {

    @TestVisible static final String VEHICLE_PATH = 'vehicle';

    public static void sync() {
        WEXGpsClient.ApiResponse resp = WEXGpsClient.get(VEHICLE_PATH);
        if (!resp.ok) { return; }

        List<Map<String, Object>> rows = resp.rows();
        if (rows.isEmpty()) { return; }

        Set<String> gpsIds = new Set<String>();
        for (Map<String, Object> row : rows) {
            String id = WEXGpsClient.toStr(row.get('id'));
            if (!String.isBlank(id)) { gpsIds.add(id); }
        }

        Map<String, Vehicle__c> existingByGpsId = new Map<String, Vehicle__c>();
        for (Vehicle__c v : [
            SELECT Id, GPS_Insights_Id__c, Make__c, Model__c, Year__c,
                   VIN__c, License_Plate__c, Odometer_Miles__c
            FROM Vehicle__c
            WHERE GPS_Insights_Id__c IN :gpsIds
        ]) {
            existingByGpsId.put(v.GPS_Insights_Id__c, v);
        }

        List<Vehicle__c> toUpsert = new List<Vehicle__c>();
        for (Map<String, Object> row : rows) {
            String gpsId = WEXGpsClient.toStr(row.get('id'));
            if (String.isBlank(gpsId)) { continue; }

            Vehicle__c veh = existingByGpsId.containsKey(gpsId)
                ? existingByGpsId.get(gpsId)
                : new Vehicle__c(GPS_Insights_Id__c = gpsId);

            applyFields(veh, row);
            toUpsert.add(veh);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert GPS_Insights_Id__c;
        }
    }

    @TestVisible
    static void applyFields(Vehicle__c veh, Map<String, Object> row) {
        veh.Make__c          = WEXGpsClient.toStr(row.get('make'));
        veh.Model__c         = WEXGpsClient.toStr(row.get('model'));
        veh.VIN__c           = WEXGpsClient.toStr(row.get('vin'));
        veh.License_Plate__c = WEXGpsClient.toStr(row.get('license_plate'));

        Decimal odom = WEXGpsClient.toDecimal(row.get('odometer'));
        if (odom != null) { veh.Odometer_Miles__c = odom; }

        Decimal yr = WEXGpsClient.toDecimal(row.get('year'));
        if (yr != null) { veh.Year__c = yr; }
    }
}