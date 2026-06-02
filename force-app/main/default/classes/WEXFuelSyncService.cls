/**
 * WEXFuelSyncService — syncs GPS Insight /vehicle/ifta to Vehicle_Fuel_Transaction__c.
 *
 * Fetches a rolling 7-day window of IFTA fuel transaction records and upserts
 * using WEX_Fuel_Id__c as the external ID.  Only transactions whose vehicle_id
 * maps to a known Vehicle__c are persisted.
 *
 * Called by GPSINTEGRATION.execute() for GPSSyncType.FUEL.
 *
 * GPS Insight API: GET /vehicle/ifta
 *   Required params: start_date (YYYY-MM-DD), optional: end_date
 * Response shape: {"data":[{"id":"FUEL001","vehicle_id":"VV001",
 *   "date":"2024-06-01","gallons":12.5,"fuel_type":"Diesel",
 *   "odometer":15500,"state":"AZ"}]}
 */
public with sharing class WEXFuelSyncService {

    @TestVisible static final String IFTA_PATH       = 'vehicle/ifta';
    @TestVisible static final Integer LOOKBACK_DAYS  = 7;

    public static void sync() {
        Date endDate   = Date.today();
        Date startDate = endDate.addDays(-LOOKBACK_DAYS);
        sync(startDate, endDate);
    }

    public static void sync(Date startDate, Date endDate) {
        Map<String, String> params = new Map<String, String>{
            'start_date' => formatDate(startDate),
            'end_date'   => formatDate(endDate)
        };
        WEXGpsClient.ApiResponse resp = WEXGpsClient.get(IFTA_PATH, params);
        if (!resp.ok) { return; }

        List<Map<String, Object>> rows = resp.rows();
        if (rows.isEmpty()) { return; }

        // Collect vehicle GPS IDs for bulk resolution
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

        List<Vehicle_Fuel_Transaction__c> toUpsert = new List<Vehicle_Fuel_Transaction__c>();
        for (Map<String, Object> row : rows) {
            String fuelId       = WEXGpsClient.toStr(row.get('id'));
            String vehicleGpsId = WEXGpsClient.toStr(row.get('vehicle_id'));
            Id vehicleSfId      = vehicleSfIdByGpsId.get(vehicleGpsId);

            if (String.isBlank(fuelId) || vehicleSfId == null) { continue; }

            Vehicle_Fuel_Transaction__c txn = new Vehicle_Fuel_Transaction__c(
                WEX_Fuel_Id__c = fuelId,
                Vehicle__c     = vehicleSfId
            );
            applyFields(txn, row);
            toUpsert.add(txn);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert WEX_Fuel_Id__c;
        }
    }

    @TestVisible
    static void applyFields(Vehicle_Fuel_Transaction__c txn, Map<String, Object> row) {
        String dateStr = WEXGpsClient.toStr(row.get('date'));
        if (!String.isBlank(dateStr)) {
            try { txn.Fuel_Date__c = Date.valueOf(dateStr); } catch (Exception ignored) {}
        }
        txn.Gallons__c        = WEXGpsClient.toDecimal(row.get('gallons'));
        txn.Fuel_Type__c      = WEXGpsClient.toStr(row.get('fuel_type'));
        txn.Odometer_Miles__c = WEXGpsClient.toDecimal(row.get('odometer'));
        String state = WEXGpsClient.toStr(row.get('state'));
        txn.State__c = state != null ? state.left(2) : null;
        txn.Raw_Payload__c = JSON.serialize(row);
    }

    private static String formatDate(Date d) {
        return d.year() + '-'
            + String.valueOf(d.month()).leftPad(2, '0') + '-'
            + String.valueOf(d.day()).leftPad(2, '0');
    }
}