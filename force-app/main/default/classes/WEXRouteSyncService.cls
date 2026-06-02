/**
 * WEXRouteSyncService — syncs GPS Insight /vehicle/history to Vehicle_Location__c.
 *
 * Fetches a rolling time window of vehicle breadcrumb history (default: last 2 hours)
 * and upserts records using GPS_Insights_Location_Id__c as the external ID.
 *
 * Vehicle_Location__c has a master-detail relationship to Vehicle__c, so only
 * history points whose vehicle_id maps to a known Vehicle__c are persisted.
 *
 * Called by GPSINTEGRATION.execute() for GPSSyncType.ROUTES.
 *
 * GPS Insight API: GET /vehicle/history
 *   Required params: start_time (ISO 8601), optional: end_time, interval_seconds
 * Response shape: {"data":[{"id":"hist-001","vehicle_id":"VV001",
 *   "latitude":33.66,"longitude":-111.92,"heading":90,"speed":25,
 *   "odometer":15000,"ignition":"on","address":"123 Main St",
 *   "fix_time":"2024-06-01T14:00:00Z"}]}
 */
public with sharing class WEXRouteSyncService {

    @TestVisible static final String HISTORY_PATH     = 'vehicle/history';
    @TestVisible static final Integer LOOKBACK_HOURS  = 2;

    public static void sync() {
        DateTime endTime   = DateTime.now();
        DateTime startTime = endTime.addHours(-LOOKBACK_HOURS);
        sync(startTime, endTime);
    }

    public static void sync(DateTime startTime, DateTime endTime) {
        Map<String, String> params = new Map<String, String>{
            'start_time' => formatIso(startTime),
            'end_time'   => formatIso(endTime)
        };
        WEXGpsClient.ApiResponse resp = WEXGpsClient.get(HISTORY_PATH, params);
        if (!resp.ok) { return; }

        List<Map<String, Object>> rows = resp.rows();
        if (rows.isEmpty()) { return; }

        // Build vehicle map to link locations
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

        List<Vehicle_Location__c> toUpsert = new List<Vehicle_Location__c>();
        for (Map<String, Object> row : rows) {
            String locId = WEXGpsClient.toStr(row.get('id'));
            String vehicleGpsId = WEXGpsClient.toStr(row.get('vehicle_id'));
            Id vehicleSfId = vehicleSfIdByGpsId.get(vehicleGpsId);

            if (String.isBlank(locId) || vehicleSfId == null) { continue; }

            Vehicle_Location__c loc = new Vehicle_Location__c(
                GPS_Insights_Location_Id__c = locId,
                Vehicle__c                  = vehicleSfId
            );
            applyFields(loc, row);
            toUpsert.add(loc);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert GPS_Insights_Location_Id__c;
        }
    }

    @TestVisible
    static void applyFields(Vehicle_Location__c loc, Map<String, Object> row) {
        loc.Latitude__c      = WEXGpsClient.toDecimal(row.get('latitude'));
        loc.Longitude__c     = WEXGpsClient.toDecimal(row.get('longitude'));
        loc.Speed_Mph__c     = WEXGpsClient.toDecimal(row.get('speed'));
        loc.Odometer_Miles__c = WEXGpsClient.toDecimal(row.get('odometer'));
        loc.Address__c       = WEXGpsClient.toStr(row.get('address'));
        loc.Timestamp__c     = WEXGpsClient.toDateTime(WEXGpsClient.toStr(row.get('fix_time')));
        String ignition = WEXGpsClient.toStr(row.get('ignition'));
        loc.Ignition_On__c = ('on'.equalsIgnoreCase(ignition)
                              || 'true'.equalsIgnoreCase(ignition)
                              || '1' == ignition);
    }

    private static String formatIso(DateTime dt) {
        return dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}