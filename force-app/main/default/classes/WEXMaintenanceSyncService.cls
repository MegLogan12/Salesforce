/**
 * WEXMaintenanceSyncService — syncs GPS Insight /vehicle/diagnostic to Vehicle_Diagnostic__c.
 *
 * Upserts one Vehicle_Diagnostic__c per diagnostic record using WEX_Diagnostic_Id__c
 * as the external ID.  Only diagnostics whose vehicle_id maps to a known Vehicle__c
 * are persisted.
 *
 * Called by GPSINTEGRATION.execute() for GPSSyncType.MAINTENANCE.
 *
 * GPS Insight API: GET /vehicle/diagnostic
 * Response shape: {"data":[{"id":"DIAG001","vehicle_id":"VV001","dtc_code":"P0300",
 *   "description":"Random/Multiple Cylinder Misfire Detected","severity":"critical",
 *   "reported_time":"2024-06-01T14:00:00Z","active":true}]}
 */
public with sharing class WEXMaintenanceSyncService {

    @TestVisible static final String DIAGNOSTIC_PATH = 'vehicle/diagnostic';

    public static void sync() {
        WEXGpsClient.ApiResponse resp = WEXGpsClient.get(DIAGNOSTIC_PATH);
        if (!resp.ok) { return; }

        List<Map<String, Object>> rows = resp.rows();
        if (rows.isEmpty()) { return; }

        // Collect vehicle GPS IDs to resolve Salesforce IDs in one query
        Set<String> vehicleGpsIds = new Set<String>();
        for (Map<String, Object> row : rows) {
            String vid = WEXGpsClient.toStr(row.get('vehicle_id'));
            if (!String.isBlank(vid)) { vehicleGpsIds.add(vid); }
        }

        Map<String, Id> vehicleSfIdByGpsId = new Map<String, Id>();
        for (Vehicle__c v : [
            SELECT Id, GPS_Insights_Id__c
            FROM Vehicle__c
            WHERE GPS_Insights_Id__c IN :vehicleGpsIds
        ]) {
            vehicleSfIdByGpsId.put(v.GPS_Insights_Id__c, v.Id);
        }

        List<Vehicle_Diagnostic__c> toUpsert = new List<Vehicle_Diagnostic__c>();
        for (Map<String, Object> row : rows) {
            String diagId      = WEXGpsClient.toStr(row.get('id'));
            String vehicleGpsId = WEXGpsClient.toStr(row.get('vehicle_id'));
            Id vehicleSfId     = vehicleSfIdByGpsId.get(vehicleGpsId);

            if (String.isBlank(diagId) || vehicleSfId == null) { continue; }

            Vehicle_Diagnostic__c diag = new Vehicle_Diagnostic__c(
                WEX_Diagnostic_Id__c = diagId,
                Vehicle__c           = vehicleSfId
            );
            applyFields(diag, row);
            toUpsert.add(diag);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert WEX_Diagnostic_Id__c;
        }
    }

    @TestVisible
    static void applyFields(Vehicle_Diagnostic__c diag, Map<String, Object> row) {
        diag.DTC_Code__c    = WEXGpsClient.toStr(row.get('dtc_code'));
        diag.Description__c = WEXGpsClient.toStr(row.get('description'));
        diag.Severity__c    = WEXGpsClient.toStr(row.get('severity'));
        diag.Reported_At__c = WEXGpsClient.toDateTime(WEXGpsClient.toStr(row.get('reported_time')));
        String active = WEXGpsClient.toStr(row.get('active'));
        diag.Is_Active__c = !'false'.equalsIgnoreCase(active) && !'0'.equals(active);
        diag.Raw_Payload__c = JSON.serialize(row);
    }
}