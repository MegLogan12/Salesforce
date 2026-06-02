/**
 * WEXLandmarkSyncService — syncs GPS Insight /landmark endpoint to GPS_Landmark__c.
 *
 * Upserts one GPS_Landmark__c per GPS Insight landmark using WEX_Landmark_Id__c
 * as the external ID.  The Name field is populated from the label returned by the API.
 *
 * Called by GPSINTEGRATION.execute() for GPSSyncType.LANDMARKS.
 *
 * GPS Insight API: GET /landmark
 * Response shape: {"data":[{"id":"LM001","label":"Shop Depot","latitude":33.5,
 *   "longitude":-111.9,"radius":100,"type":"circle","active":true}]}
 */
public with sharing class WEXLandmarkSyncService {

    @TestVisible static final String LANDMARK_PATH = 'landmark';

    public static void sync() {
        WEXGpsClient.ApiResponse resp = WEXGpsClient.get(LANDMARK_PATH);
        if (!resp.ok) { return; }

        List<Map<String, Object>> rows = resp.rows();
        if (rows.isEmpty()) { return; }

        Set<String> wexIds = new Set<String>();
        for (Map<String, Object> row : rows) {
            String id = WEXGpsClient.toStr(row.get('id'));
            if (!String.isBlank(id)) { wexIds.add(id); }
        }

        Map<String, GPS_Landmark__c> existingById = new Map<String, GPS_Landmark__c>();
        for (GPS_Landmark__c lm : [
            SELECT Id, WEX_Landmark_Id__c
            FROM GPS_Landmark__c
            WHERE WEX_Landmark_Id__c IN :wexIds
        ]) {
            existingById.put(lm.WEX_Landmark_Id__c, lm);
        }

        List<GPS_Landmark__c> toUpsert = new List<GPS_Landmark__c>();
        for (Map<String, Object> row : rows) {
            String wexId = WEXGpsClient.toStr(row.get('id'));
            if (String.isBlank(wexId)) { continue; }

            GPS_Landmark__c lm = existingById.containsKey(wexId)
                ? existingById.get(wexId)
                : new GPS_Landmark__c(WEX_Landmark_Id__c = wexId);

            applyFields(lm, row);
            toUpsert.add(lm);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert WEX_Landmark_Id__c;
        }
    }

    @TestVisible
    static void applyFields(GPS_Landmark__c lm, Map<String, Object> row) {
        String label = WEXGpsClient.toStr(row.get('label'));
        if (!String.isBlank(label)) { lm.Name = label; }
        lm.Latitude__c      = WEXGpsClient.toDecimal(row.get('latitude'));
        lm.Longitude__c     = WEXGpsClient.toDecimal(row.get('longitude'));
        lm.Radius_Meters__c = WEXGpsClient.toDecimal(row.get('radius'));
        lm.Landmark_Type__c = WEXGpsClient.toStr(row.get('type'));
        String active = WEXGpsClient.toStr(row.get('active'));
        lm.Is_Active__c = !'false'.equalsIgnoreCase(active) && !'0'.equals(active);
        lm.Raw_Payload__c   = JSON.serialize(row);
    }
}