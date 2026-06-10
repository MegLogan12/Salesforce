/**
 * WEXAlertSyncService — syncs GPS Insight /alert endpoint to GPS_Alert__c.
 *
 * Upserts one GPS_Alert__c per alert using WEX_Alert_Id__c as the external ID.
 * Resolves Vehicle__c via vehicle_id and Driver__c (Employee__c lookup) via
 * Driver_Assignment__c.WEX_Driver_Id__c when a driver_id is present.
 *
 * Called by GPSINTEGRATION.execute() for GPSSyncType.ALERTS.
 *
 * GPS Insight API: GET /alert
 * Response shape: {"alerts":[{"id":"ALT001","vehicle_id":"VV001","driver_id":"DR001",
 *   "alert_type":"speeding","severity":"high",
 *   "description":"Vehicle exceeded posted speed limit",
 *   "alert_time":"2024-06-01T14:00:00Z"}]}
 */
public with sharing class WEXAlertSyncService {

    @TestVisible static final String ALERT_PATH = 'alert';

    public static void sync() {
        WEXGpsClient.ApiResponse resp = WEXGpsClient.get(ALERT_PATH);
        if (!resp.ok) { return; }

        List<Map<String, Object>> rows = resp.rows();
        if (rows.isEmpty()) { return; }

        // Collect IDs for bulk resolution
        Set<String> vehicleGpsIds = new Set<String>();
        Set<String> driverWexIds  = new Set<String>();
        for (Map<String, Object> row : rows) {
            String vid = WEXGpsClient.toStr(row.get('vehicle_id'));
            String did = WEXGpsClient.toStr(row.get('driver_id'));
            if (!String.isBlank(vid)) { vehicleGpsIds.add(vid); }
            if (!String.isBlank(did)) { driverWexIds.add(did); }
        }

        Map<String, Id> vehicleSfIdByGpsId = new Map<String, Id>();
        for (Vehicle__c v : [
            SELECT Id, GPS_Insights_Id__c
            FROM Vehicle__c
            WHERE GPS_Insights_Id__c IN :vehicleGpsIds
        ]) {
            vehicleSfIdByGpsId.put(v.GPS_Insights_Id__c, v.Id);
        }

        // Resolve Employee__c via Driver_Assignment__c.WEX_Driver_Id__c
        Map<String, Id> employeeByWexDriverId = new Map<String, Id>();
        if (!driverWexIds.isEmpty()) {
            for (Driver_Assignment__c da : [
                SELECT WEX_Driver_Id__c, Employee__c
                FROM Driver_Assignment__c
                WHERE WEX_Driver_Id__c IN :driverWexIds
                  AND Employee__c != null
            ]) {
                employeeByWexDriverId.put(da.WEX_Driver_Id__c, da.Employee__c);
            }
        }

        List<GPS_Alert__c> toUpsert = new List<GPS_Alert__c>();
        for (Map<String, Object> row : rows) {
            String alertId      = WEXGpsClient.toStr(row.get('id'));
            String vehicleGpsId = WEXGpsClient.toStr(row.get('vehicle_id'));

            if (String.isBlank(alertId)) { continue; }

            GPS_Alert__c alert = new GPS_Alert__c(
                WEX_Alert_Id__c = alertId
            );

            Id vehicleSfId = vehicleSfIdByGpsId.get(vehicleGpsId);
            if (vehicleSfId != null) { alert.Vehicle__c = vehicleSfId; }

            String driverId = WEXGpsClient.toStr(row.get('driver_id'));
            if (!String.isBlank(driverId)) {
                Id empId = employeeByWexDriverId.get(driverId);
                if (empId != null) { alert.Driver__c = empId; }
            }

            applyFields(alert, row);
            toUpsert.add(alert);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert WEX_Alert_Id__c;
        }
    }

    @TestVisible
    static void applyFields(GPS_Alert__c alert, Map<String, Object> row) {
        alert.Alert_Type__c      = WEXGpsClient.toStr(row.get('alert_type'));
        alert.Severity__c        = WEXGpsClient.toStr(row.get('severity'));
        alert.Description__c     = WEXGpsClient.toStr(row.get('description'));
        alert.Alert_Timestamp__c = WEXGpsClient.toDateTime(WEXGpsClient.toStr(row.get('alert_time')));
        String ack = WEXGpsClient.toStr(row.get('acknowledged'));
        alert.Is_Acknowledged__c = 'true'.equalsIgnoreCase(ack) || '1'.equals(ack);
        alert.Raw_Payload__c     = JSON.serialize(row);
    }
}