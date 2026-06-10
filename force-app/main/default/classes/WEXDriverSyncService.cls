/**
* WEXDriverSyncService — syncs GPS Insight /driver endpoint to Driver_Assignment__c.
*
* Upserts one Driver_Assignment__c per GPS Insight driver using WEX_Driver_Id__c
* as the external ID.  Resolves Employee__c by full name match (first_name + last_name)
* against active Employee__c records, and Vehicle__c by GPS_Insights_Id__c.
*
* Called by GPSINTEGRATION.execute() for SyncType.ALL and SyncType.DRIVERS.
*/
public with sharing class WEXDriverSyncService {

// driver/ is a deprecated GPS Insights v1 path that returns 301.
// v2/driver/ is the v2 path — if this also fails, the GPS Insights driver endpoint
// may require different parameters. Driver matching still works via vehicle location data
// in WexGpsSyncService.processPositions() which reads first_name/last_name from GPS pings.
@TestVisible static final String DRIVER_PATH = 'v2/driver/';

@future(callout=true)
public static void syncAsync() {
sync();
}

public static void sync() {
WEXGpsClient.ApiResponse resp = WEXGpsClient.get(DRIVER_PATH);
// 301 redirect means the v1 driver endpoint is deprecated and the v2 path is not valid.
// In this case, driver matching still works via WexGpsSyncService which reads
// first_name/last_name from the vehicle/location response without a separate driver call.
if (!resp.ok || resp.statusCode == 301 || resp.statusCode == 404) { return; }

List<Map<String, Object>> rows = resp.rows();
if (rows.isEmpty()) { return; }

Set<String> wexIds       = new Set<String>();
Set<String> fullNames    = new Set<String>();
Set<String> vehicleGpsIds = new Set<String>();

for (Map<String, Object> row : rows) {
String id = WEXGpsClient.toStr(row.get('id'));
if (!String.isBlank(id)) { wexIds.add(id); }
String fn = WEXGpsClient.toStr(row.get('first_name'));
String ln = WEXGpsClient.toStr(row.get('last_name'));
if (!String.isBlank(fn) && !String.isBlank(ln)) {
fullNames.add((fn + ' ' + ln).trim());
}
String vid = WEXGpsClient.toStr(row.get('vehicle_id'));
if (!String.isBlank(vid)) { vehicleGpsIds.add(vid); }
}

Map<String, Driver_Assignment__c> existingByWexId = new Map<String, Driver_Assignment__c>();
for (Driver_Assignment__c da : [
SELECT Id, WEX_Driver_Id__c, Employee__c, Vehicle__c
FROM Driver_Assignment__c
WHERE WEX_Driver_Id__c IN :wexIds
]) {
existingByWexId.put(da.WEX_Driver_Id__c, da);
}

Map<String, Id> employeeByFullName = new Map<String, Id>();
if (!fullNames.isEmpty()) {
for (Employee__c emp : [
SELECT Id, Name
FROM Employee__c
WHERE Name IN :fullNames AND Status__c = 'Active'
]) {
employeeByFullName.put(emp.Name, emp.Id);
}
}

Map<String, Id> vehicleByGpsId = new Map<String, Id>();
if (!vehicleGpsIds.isEmpty()) {
for (Vehicle__c v : [
SELECT Id, GPS_Insights_Id__c
FROM Vehicle__c
WHERE GPS_Insights_Id__c IN :vehicleGpsIds
]) {
vehicleByGpsId.put(v.GPS_Insights_Id__c, v.Id);
}
}

List<Driver_Assignment__c> toUpsert = new List<Driver_Assignment__c>();
Map<Id, Id> assignedDriverByVehicleId = new Map<Id, Id>();
for (Map<String, Object> row : rows) {
String wexId = WEXGpsClient.toStr(row.get('id'));
if (String.isBlank(wexId)) { continue; }

String fn       = WEXGpsClient.toStr(row.get('first_name'));
String ln       = WEXGpsClient.toStr(row.get('last_name'));
String fullName = (!String.isBlank(fn) && !String.isBlank(ln))
? (fn + ' ' + ln).trim() : null;

Driver_Assignment__c da = existingByWexId.containsKey(wexId)
? existingByWexId.get(wexId)
: new Driver_Assignment__c(WEX_Driver_Id__c = wexId);

da.Driver_Name__c = fullName;
da.Is_Active__c   = 'true'.equalsIgnoreCase(WEXGpsClient.toStr(row.get('active')));
da.Assigned_At__c = DateTime.now();

String vehicleGpsId = WEXGpsClient.toStr(row.get('vehicle_id'));
if (!String.isBlank(vehicleGpsId) && vehicleByGpsId.containsKey(vehicleGpsId)) {
da.Vehicle__c = vehicleByGpsId.get(vehicleGpsId);
}

if (fullName != null && employeeByFullName.containsKey(fullName)) {
da.Employee__c = employeeByFullName.get(fullName);
}
if (da.Vehicle__c != null && da.Employee__c != null) {
assignedDriverByVehicleId.put(da.Vehicle__c, da.Employee__c);
}

toUpsert.add(da);
}

if (!toUpsert.isEmpty()) {
upsert toUpsert WEX_Driver_Id__c;
}
if (!assignedDriverByVehicleId.isEmpty()) {
List<Vehicle__c> vehicleUpdates = new List<Vehicle__c>();
for (Id vehicleId : assignedDriverByVehicleId.keySet()) {
vehicleUpdates.add(new Vehicle__c(
Id = vehicleId,
Assigned_Driver__c = assignedDriverByVehicleId.get(vehicleId)
));
}
update vehicleUpdates;
}
}
}