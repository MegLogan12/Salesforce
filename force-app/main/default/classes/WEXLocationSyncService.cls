/**
 * WEXLocationSyncService — syncs GPS Insight /vehicle/location to WEX_GPS_Position__c
 * and mirrors lat/lng/timestamp/status to Vehicle__c.
 *
 * Uses WEXGpsClient for all HTTP and auth — no direct callout logic here.
 *
 * One WEX_GPS_Position__c per vehicle (upserted by Vehicle__c lookup — one current
 * position per vehicle, overwritten on each sync).
 *
 * Called by GPSINTEGRATION.execute() for SyncType.ALL and SyncType.LOCATIONS.
 * Also callable standalone (e.g., from a 3-minute scheduler for live map refresh).
 */
public with sharing class WEXLocationSyncService {

    @TestVisible static final String LOCATION_PATH = 'v2/vehicle/location';

    @future(callout=true)
    public static void syncAsync() {
        sync();
    }

    public static void sync() {
        WEXGpsClient.ApiResponse resp = WEXGpsClient.get(LOCATION_PATH);
        if (!resp.ok) { return; }

        List<Map<String, Object>> rows = resp.rows();
        if (rows.isEmpty()) {
            backfillExistingPositionAssignments();
            return;
        }

        processPositions(rows);
        backfillExistingPositionAssignments();
    }

    // ── Core processing ───────────────────────────────────────────────────────

    @TestVisible
    static void processPositions(List<Map<String, Object>> vehicles) {
        Set<String> gpsIds   = new Set<String>();
        Set<String> gpsNames = new Set<String>();
        for (Map<String, Object> v : vehicles) {
            String id = WEXGpsClient.toStr(v.get('id'));
            if (!String.isBlank(id)) { gpsIds.add(id); }
            String fn = WEXGpsClient.toStr(v.get('first_name'));
            String ln = WEXGpsClient.toStr(v.get('last_name'));
            if (!String.isBlank(fn) && !String.isBlank(ln)) {
                gpsNames.add((fn + ' ' + ln).trim());
            }
        }
        if (gpsIds.isEmpty()) { return; }

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
        for (Vehicle__c v : vehicleByGpsId.values()) { sfVehicleIds.add(v.Id); }

        Map<Id, WEX_GPS_Position__c> existingByVehicle = new Map<Id, WEX_GPS_Position__c>();
        for (WEX_GPS_Position__c pos : [
            SELECT Id, Vehicle__c
            FROM WEX_GPS_Position__c
            WHERE Vehicle__c IN :sfVehicleIds
        ]) {
            existingByVehicle.put(pos.Vehicle__c, pos);
        }

        Map<String, Id> employeeByFullName = new Map<String, Id>();
        if (!gpsNames.isEmpty()) {
            for (Employee__c emp : [
                SELECT Id, Name
                FROM Employee__c
                WHERE Name IN :gpsNames AND Status__c = 'Active'
            ]) {
                employeeByFullName.put(emp.Name, emp.Id);
            }
        }

        Map<Id, Driver_Assignment__c> activeAssignmentByVehicle = new Map<Id, Driver_Assignment__c>();
        for (Driver_Assignment__c assignment : [
            SELECT Id, Vehicle__c, Employee__c, Assigned_At__c
            FROM Driver_Assignment__c
            WHERE Vehicle__c IN :sfVehicleIds
              AND Is_Active__c = true
            ORDER BY Assigned_At__c DESC, CreatedDate DESC
        ]) {
            if (assignment.Vehicle__c != null && !activeAssignmentByVehicle.containsKey(assignment.Vehicle__c)) {
                activeAssignmentByVehicle.put(assignment.Vehicle__c, assignment);
            }
        }

        Map<Id, Id> crewByVehicle = new Map<Id, Id>();
        Map<Id, Id> foremanUserByCrew = new Map<Id, Id>();
        for (Crew__c crew : [
            SELECT Id, Vehicle__c, Foreman__c
            FROM Crew__c
            WHERE Vehicle__c IN :sfVehicleIds
        ]) {
            if (crew.Vehicle__c != null && !crewByVehicle.containsKey(crew.Vehicle__c)) {
                crewByVehicle.put(crew.Vehicle__c, crew.Id);
            }
            if (crew.Id != null && crew.Foreman__c != null) {
                foremanUserByCrew.put(crew.Id, crew.Foreman__c);
            }
        }

        Set<Id> driverIds = new Set<Id>();
        for (Vehicle__c vehicleRow : vehicleByGpsId.values()) {
            if (vehicleRow.Assigned_Driver__c != null) driverIds.add(vehicleRow.Assigned_Driver__c);
        }
        for (Driver_Assignment__c assignment : activeAssignmentByVehicle.values()) {
            if (assignment.Employee__c != null) driverIds.add(assignment.Employee__c);
        }
        for (Id employeeId : employeeByFullName.values()) {
            driverIds.add(employeeId);
        }

        Map<Id, Employee__c> employeeById = new Map<Id, Employee__c>();
        Map<Id, Id> employeeByUserId = new Map<Id, Id>();
        Set<Id> foremanUserIds = new Set<Id>();
        if (!driverIds.isEmpty()) {
            for (Employee__c employee : [
                SELECT Id, Crew__c, User__c
                FROM Employee__c
                WHERE Id IN :driverIds
            ]) {
                employeeById.put(employee.Id, employee);
                if (employee.User__c != null) {
                    foremanUserIds.add(employee.User__c);
                    employeeByUserId.put(employee.User__c, employee.Id);
                }
            }
        }
        if (!foremanUserByCrew.isEmpty()) {
            Set<Id> missingForemanUserIds = new Set<Id>();
            for (Id foremanUserId : foremanUserByCrew.values()) {
                if (foremanUserId != null && !employeeByUserId.containsKey(foremanUserId)) {
                    missingForemanUserIds.add(foremanUserId);
                }
            }
            if (!missingForemanUserIds.isEmpty()) {
                for (Employee__c employee : [
                    SELECT Id, User__c
                    FROM Employee__c
                    WHERE User__c IN :missingForemanUserIds
                      AND Status__c = 'Active'
                ]) {
                    if (employee.User__c != null) {
                        employeeByUserId.put(employee.User__c, employee.Id);
                    }
                }
            }
        }

        Map<Id, Id> crewByForemanUser = new Map<Id, Id>();
        if (!foremanUserIds.isEmpty()) {
            for (Crew__c crew : [
                SELECT Id, Foreman__c
                FROM Crew__c
                WHERE Foreman__c IN :foremanUserIds
            ]) {
                if (crew.Foreman__c != null && !crewByForemanUser.containsKey(crew.Foreman__c)) {
                    crewByForemanUser.put(crew.Foreman__c, crew.Id);
                }
            }
        }

        List<WEX_GPS_Position__c> toInsert      = new List<WEX_GPS_Position__c>();
        List<WEX_GPS_Position__c> toUpdate       = new List<WEX_GPS_Position__c>();
        List<Vehicle__c>          vehicleUpdates = new List<Vehicle__c>();
        DateTime                  now            = DateTime.now();

        for (Map<String, Object> raw : vehicles) {
            String     gpsId = WEXGpsClient.toStr(raw.get('id'));
            Vehicle__c veh   = vehicleByGpsId.get(gpsId);
            if (veh == null) { continue; }

            Id driverId = veh.Assigned_Driver__c;
            if (driverId == null && activeAssignmentByVehicle.containsKey(veh.Id)) {
                driverId = activeAssignmentByVehicle.get(veh.Id).Employee__c;
            }
            if (driverId == null) {
                String fn   = WEXGpsClient.toStr(raw.get('first_name'));
                String ln   = WEXGpsClient.toStr(raw.get('last_name'));
                String full = (!String.isBlank(fn) && !String.isBlank(ln))
                              ? (fn + ' ' + ln).trim() : null;
                if (full != null) { driverId = employeeByFullName.get(full); }
            }

            Id crewId = null;
            Employee__c driver = driverId != null ? employeeById.get(driverId) : null;
            if (driver != null) {
                crewId = driver.Crew__c;
                if (crewId == null && driver.User__c != null) {
                    crewId = crewByForemanUser.get(driver.User__c);
                }
            }
            if (crewId == null) {
                crewId = crewByVehicle.get(veh.Id);
            }
            if (driverId == null && crewId != null) {
                Id foremanUserId = foremanUserByCrew.get(crewId);
                if (foremanUserId != null) {
                    driverId = employeeByUserId.get(foremanUserId);
                    driver = driverId != null ? employeeById.get(driverId) : null;
                }
            }

            WEX_GPS_Position__c pos  = existingByVehicle.get(veh.Id);
            Boolean             isNew = (pos == null);
            if (isNew) { pos = new WEX_GPS_Position__c(Vehicle__c = veh.Id); }

            applyPositionFields(pos, raw);
            pos.Driver__c = driverId;
            pos.Crew__c = crewId;

            if (isNew) { toInsert.add(pos); } else { toUpdate.add(pos); }

            Decimal  lat = WEXGpsClient.toDecimal(raw.get('latitude'));
            Decimal  lng = WEXGpsClient.toDecimal(raw.get('longitude'));
            DateTime ts  = WEXGpsClient.toDateTime(WEXGpsClient.toStr(raw.get('fix_time_gmt')));

            vehicleUpdates.add(new Vehicle__c(
                Id                         = veh.Id,
                GPS_Latitude__c            = lat,
                GPS_Longitude__c           = lng,
                GPS_Last_Seen__c           = ts,
                GPS_Status__c              = deriveGpsStatus(ts, now),
                Last_Location_Lat__c       = lat,
                Last_Location_Lng__c       = lng,
                Last_Location_Timestamp__c = ts,
                Last_GPS_Sync__c           = now,
                Last_Location_Address__c   = WEXGpsClient.toStr(raw.get('address')),
                Assigned_Driver__c         = driverId
            ));
        }

        if (!toInsert.isEmpty())       { insert toInsert; }
        if (!toUpdate.isEmpty())       { update toUpdate; }
        if (!vehicleUpdates.isEmpty()) { update vehicleUpdates; }
    }

    @TestVisible
    static void backfillExistingPositionAssignments() {
        List<WEX_GPS_Position__c> positions = [
            SELECT Id, Vehicle__c, Driver__c, Crew__c, CreatedDate, Last_Seen_DateTime__c
            FROM WEX_GPS_Position__c
            WHERE Vehicle__c != null
              AND (Driver__c = null OR Crew__c = null)
            LIMIT 5000
        ];
        if (positions.isEmpty()) {
            return;
        }

        Set<Id> vehicleIds = new Set<Id>();
        for (WEX_GPS_Position__c pos : positions) {
            vehicleIds.add(pos.Vehicle__c);
        }

        Map<Id, Vehicle__c> vehicleById = new Map<Id, Vehicle__c>([
            SELECT Id, Assigned_Driver__c, GPS_Status__c
            FROM Vehicle__c
            WHERE Id IN :vehicleIds
        ]);

        Map<Id, Crew__c> crewByVehicle = new Map<Id, Crew__c>();
        Set<Id> foremanUserIds = new Set<Id>();
        for (Crew__c crew : [
            SELECT Id, Vehicle__c, Foreman__c
            FROM Crew__c
            WHERE Vehicle__c IN :vehicleIds
        ]) {
            if (crew.Vehicle__c != null && !crewByVehicle.containsKey(crew.Vehicle__c)) {
                crewByVehicle.put(crew.Vehicle__c, crew);
            }
            if (crew.Foreman__c != null) {
                foremanUserIds.add(crew.Foreman__c);
            }
        }

        Map<Id, Id> employeeByUserId = new Map<Id, Id>();
        if (!foremanUserIds.isEmpty()) {
            for (Employee__c employee : [
                SELECT Id, User__c
                FROM Employee__c
                WHERE User__c IN :foremanUserIds
                  AND Status__c = 'Active'
            ]) {
                if (employee.User__c != null) {
                    employeeByUserId.put(employee.User__c, employee.Id);
                }
            }
        }

        List<WEX_GPS_Position__c> positionUpdates = new List<WEX_GPS_Position__c>();
        List<WEX_GPS_Position__c> positionsToDelete = new List<WEX_GPS_Position__c>();
        List<Vehicle__c> vehicleUpdates = new List<Vehicle__c>();
        for (WEX_GPS_Position__c pos : positions) {
            Crew__c crew = crewByVehicle.get(pos.Vehicle__c);
            Vehicle__c vehicle = vehicleById.get(pos.Vehicle__c);
            if (crew == null && vehicle == null) {
                continue;
            }

            Id resolvedCrewId = pos.Crew__c;
            if (resolvedCrewId == null && crew != null) {
                resolvedCrewId = crew.Id;
            }

            Id resolvedDriverId = pos.Driver__c;
            if (resolvedDriverId == null && vehicle != null) {
                resolvedDriverId = vehicle.Assigned_Driver__c;
            }
            if (resolvedDriverId == null && crew != null && crew.Foreman__c != null) {
                resolvedDriverId = employeeByUserId.get(crew.Foreman__c);
            }

            // Do not keep stale current-position rows for offline vehicles that still
            // have no crew context after all known fallbacks are exhausted.
            if (resolvedCrewId == null
                && vehicle != null
                && vehicle.GPS_Status__c == 'Offline') {
                DateTime staleCutoff = System.now().addDays(-1);
                DateTime staleSeenAt = pos.Last_Seen_DateTime__c;
                if (staleSeenAt != null && staleSeenAt <= staleCutoff) {
                    positionsToDelete.add(new WEX_GPS_Position__c(Id = pos.Id));
                    continue;
                }
            }

            if (resolvedCrewId != pos.Crew__c || resolvedDriverId != pos.Driver__c) {
                positionUpdates.add(new WEX_GPS_Position__c(
                    Id = pos.Id,
                    Crew__c = resolvedCrewId,
                    Driver__c = resolvedDriverId
                ));
            }
            if (vehicle != null && vehicle.Assigned_Driver__c == null && resolvedDriverId != null) {
                vehicleUpdates.add(new Vehicle__c(
                    Id = vehicle.Id,
                    Assigned_Driver__c = resolvedDriverId
                ));
            }
        }

        if (!positionUpdates.isEmpty()) {
            update positionUpdates;
        }
        if (!positionsToDelete.isEmpty()) {
            delete positionsToDelete;
        }
        if (!vehicleUpdates.isEmpty()) {
            update vehicleUpdates;
        }
    }

    // ── Field mapping ─────────────────────────────────────────────────────────

    @TestVisible
    static void applyPositionFields(WEX_GPS_Position__c pos, Map<String, Object> raw) {
        pos.Latitude__c           = WEXGpsClient.toDecimal(raw.get('latitude'));
        pos.Longitude__c          = WEXGpsClient.toDecimal(raw.get('longitude'));
        pos.Speed_MPH__c          = WEXGpsClient.toDecimal(raw.get('inst_speed'));
        pos.Heading__c            = WEXGpsClient.toDecimal(raw.get('heading'));
        pos.Last_Seen_DateTime__c = WEXGpsClient.toDateTime(WEXGpsClient.toStr(raw.get('fix_time_gmt')));
        pos.Ignition_Status__c    = mapIgnitionStatus(WEXGpsClient.toStr(raw.get('ignition')));
        pos.Source_System__c      = 'WEX GPS';
        pos.Raw_Payload__c        = JSON.serialize(raw);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

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
}