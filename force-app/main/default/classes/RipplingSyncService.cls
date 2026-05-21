/**
 * Rippling HR + time tracking sync service.
 *
 * Pulls employees, time entries (clock in/out punches), and time-off requests
 * from the Rippling Platform API via the Rippling Named Credential and upserts
 * them into Employee__c, Rippling_Time_Entry__c, and Rippling_Time_Off__c.
 *
 * Auth: handled by the Rippling Named Credential (user sets API key as a
 * Custom Header after deploy). Endpoints are referenced via callout:Rippling.
 *
 * Degrades gracefully: if Employee__c or any field is missing in the target
 * org, the sync logs and returns instead of throwing.
 */
public with sharing class RipplingSyncService {

    // Rippling V2 REST API (rest.ripplingapis.com).
    public static final String BASE_URL           = 'https://rest.ripplingapis.com';
    public static final String EMPLOYEES_PATH     = '/workers/';
    public static final String DEPARTMENTS_PATH   = '/departments/';
    public static final String USERS_PATH         = '/users/';
    public static final String TIME_ENTRIES_PATH  = '/time-entries/';
    public static final String TIME_OFF_PATH      = '/time-off/';

    public static final Set<String> TARGET_DEPARTMENTS = new Set<String>{
        'Landscape',
        'Production & Landscape',
        'Irrigation',
        'Aqua',
        'Aqua Services',
        'Lawn Care',
        'Scheduling',
        'Inventory',
        'Shop',
        'Design & Build',
        'Customer Success',
        'Fleet',
        'Fleet & Facilities Operations',
        'Sod Farm',
        'Harvest',
        'Mowing',
        'Farm',
        'Land Development',
        'Logisitics'
    };

    // Normalize Rippling department names to the Salesforce picklist values we use.
    private static final Map<String, String> DEPT_NAME_MAP = new Map<String, String>{
        'Aqua Services'          => 'Aqua',
        'Production & Landscape' => 'Landscape'
    };

    // ------------------------------------------------------------------
    // Public sync entry points
    // ------------------------------------------------------------------

    @future(callout=true)
    public static void syncEmployees() {
        syncEmployeesSync();
    }

    public static void syncEmployeesSync() {
        if (!isObjectAccessible('Employee__c')) {
            System.debug(LoggingLevel.WARN, 'RipplingSyncService.syncEmployees: Employee__c not accessible, skipping.');
            return;
        }
        try {
            // V2: department names and user names live in separate endpoints.
            Map<String, String> deptIdToName   = fetchDepartmentMap();
            Map<String, Map<String, Object>> userIdToUser = fetchUserMap();

            List<Map<String, Object>> raw = fetchAllPages(EMPLOYEES_PATH);
            List<Employee__c> toUpsert = new List<Employee__c>();
            for (Map<String, Object> rec : raw) {
                String deptId  = toStr(rec.get('department_id'));
                String deptRaw = deptIdToName.get(deptId);
                // Normalize Rippling dept name → Salesforce picklist value.
                String deptName = DEPT_NAME_MAP.containsKey(deptRaw) ? DEPT_NAME_MAP.get(deptRaw) : deptRaw;

                if (!TARGET_DEPARTMENTS.contains(deptName)) continue;

                String userId  = toStr(rec.get('user_id'));
                Map<String, Object> userRec = userIdToUser.get(userId);

                Employee__c emp = mapEmployeeResponseV2(rec, userRec, deptName);
                if (emp == null) continue;
                toUpsert.add(emp);
            }
            if (!toUpsert.isEmpty()) {
                Database.upsert(toUpsert, Employee__c.Fields.Rippling_Id__c, false);
            }
            backfillEmployeeUserAndCrewLinks();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'RipplingSyncService.syncEmployees failed: ' + e.getMessage());
        }
    }

    @future(callout=true)
    public static void syncTimeEntries(String sinceIso) {
        syncTimeEntriesSync(sinceIso);
    }

    public static void syncTimeEntriesSync(String sinceIso) {
        if (!isObjectAccessible('Rippling_Time_Entry__c') || !isObjectAccessible('Employee__c')) {
            System.debug(LoggingLevel.WARN, 'RipplingSyncService.syncTimeEntries: required objects missing, skipping.');
            return;
        }
        try {
            String since = String.isBlank(sinceIso)
                ? DateTime.now().addHours(-24).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                : sinceIso;
            String path = TIME_ENTRIES_PATH + '?since=' + EncodingUtil.urlEncode(since, 'UTF-8');
            List<Map<String, Object>> raw = fetchAllPages(path);

            Map<String, Id> empByRipplingId = queryEmployeeMapForEntries(raw);
            List<Rippling_Time_Entry__c> toUpsert = new List<Rippling_Time_Entry__c>();
            for (Map<String, Object> rec : raw) {
                Rippling_Time_Entry__c te = mapTimeEntryResponse(rec, empByRipplingId);
                if (te != null) {
                    toUpsert.add(te);
                }
            }
            if (!toUpsert.isEmpty()) {
                Schema.SObjectField extIdField = Rippling_Time_Entry__c.Fields.Rippling_Time_Entry_Id__c;
                Database.upsert(toUpsert, extIdField, false);
            }
            recomputeClockedInFlags(empByRipplingId.values());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'RipplingSyncService.syncTimeEntries failed: ' + e.getMessage());
        }
    }

    @future(callout=true)
    public static void syncTimeOff() {
        syncTimeOffSync();
    }

    public static void syncTimeOffSync() {
        if (!isObjectAccessible('Rippling_Time_Off__c') || !isObjectAccessible('Employee__c')) {
            System.debug(LoggingLevel.WARN, 'RipplingSyncService.syncTimeOff: required objects missing, skipping.');
            return;
        }
        try {
            Date today = Date.today();
            Date windowEnd = today.addDays(30);
            String path = TIME_OFF_PATH
                + '?status=approved'
                + '&start_date_from=' + today.year() + '-' + padTwo(today.month()) + '-' + padTwo(today.day())
                + '&start_date_to=' + windowEnd.year() + '-' + padTwo(windowEnd.month()) + '-' + padTwo(windowEnd.day());
            List<Map<String, Object>> raw = fetchAllPages(path);

            Map<String, Id> empByRipplingId = queryEmployeeMapForTimeOff(raw);
            List<Rippling_Time_Off__c> toUpsert = new List<Rippling_Time_Off__c>();
            for (Map<String, Object> rec : raw) {
                Rippling_Time_Off__c to = mapTimeOffResponse(rec, empByRipplingId);
                if (to != null) {
                    toUpsert.add(to);
                }
            }
            if (!toUpsert.isEmpty()) {
                Schema.SObjectField extIdField = Rippling_Time_Off__c.Fields.Rippling_Time_Off_Id__c;
                Database.upsert(toUpsert, extIdField, false);
            }
            recomputeOnPtoFlags(empByRipplingId.values());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'RipplingSyncService.syncTimeOff failed: ' + e.getMessage());
        }
    }

    // ------------------------------------------------------------------
    // LWC-facing helpers
    // ------------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<Employee__c> getAvailableForemen(Date workDate, Boolean requireDriver) {
        if (!isObjectAccessible('Employee__c')) {
            return new List<Employee__c>();
        }
        Boolean driverFilter = requireDriver == true;
        String soql = 'SELECT Id, Name, First_Name__c, Last_Name__c, Department__c, Role__c, '
            + 'Is_Driver__c, Currently_Clocked_In__c, On_PTO_Today__c, Status__c '
            + 'FROM Employee__c '
            + 'WHERE Department__c = \'Landscape\' '
            + 'AND Status__c = \'Active\' '
            + 'AND On_PTO_Today__c = false';
        if (driverFilter) {
            soql += ' AND Is_Driver__c = true';
        }
        soql += ' ORDER BY Last_Name__c, First_Name__c LIMIT 200';
        return Database.query(soql);
    }

    // ------------------------------------------------------------------
    // Lookup fetchers (V2)
    // ------------------------------------------------------------------

    @TestVisible
    private static Map<String, String> fetchDepartmentMap() {
        Map<String, String> out = new Map<String, String>();
        for (Map<String, Object> rec : fetchAllPages(DEPARTMENTS_PATH)) {
            String id   = toStr(rec.get('id'));
            String name = toStr(rec.get('name'));
            if (!String.isBlank(id) && !String.isBlank(name)) out.put(id, name);
        }
        return out;
    }

    @TestVisible
    private static Map<String, Map<String, Object>> fetchUserMap() {
        Map<String, Map<String, Object>> out = new Map<String, Map<String, Object>>();
        for (Map<String, Object> rec : fetchAllPages(USERS_PATH)) {
            String id = toStr(rec.get('id'));
            if (!String.isBlank(id)) out.put(id, rec);
        }
        return out;
    }

    // ------------------------------------------------------------------
    // Mapping helpers
    // ------------------------------------------------------------------

    // V2 mapper — uses pre-fetched department name and user record.
    @TestVisible
    private static Employee__c mapEmployeeResponseV2(
            Map<String, Object> raw,
            Map<String, Object> userRec,
            String deptName) {
        String ripplingId = toStr(raw.get('id'));
        if (String.isBlank(ripplingId)) return null;

        Employee__c emp = new Employee__c();
        emp.Rippling_Id__c = ripplingId;

        if (userRec != null) {
            Object nameObj = userRec.get('name');
            if (nameObj instanceof Map<String, Object>) {
                Map<String, Object> nm = (Map<String, Object>) nameObj;
                emp.First_Name__c = toStr(nm.get('given_name'));
                emp.Last_Name__c  = toStr(nm.get('family_name'));
            }
            emp.Phone__c = extractWorkPhone(userRec);
        }
        String fn = emp.First_Name__c == null ? '' : emp.First_Name__c;
        String ln = emp.Last_Name__c  == null ? '' : emp.Last_Name__c;
        emp.Name = (fn + ' ' + ln).trim().left(80);

        emp.Work_Email__c     = toStr(raw.get('work_email'));
        emp.Personal_Email__c = toStr(raw.get('personal_email'));
        emp.Title__c          = toStr(raw.get('title'));
        emp.Department__c     = deptName != null ? deptName : 'Other';
        emp.Role__c           = mapRole(emp.First_Name__c, emp.Last_Name__c, emp.Title__c);
        emp.Hire_Date__c      = toDate(raw.get('start_date'));
        emp.Termination_Date__c = toDate(raw.get('end_date'));
        emp.Status__c         = mapStatus(toStr(raw.get('status')));
        emp.Is_Driver__c      = resolveDriverFlag(raw);
        emp.Last_Rippling_Sync__c = DateTime.now();
        return emp;
    }

    // Pulls the first WORK phone, then any phone, from a V2 user record.
    private static String extractWorkPhone(Map<String, Object> userRec) {
        Object phones = userRec.get('phone_numbers');
        if (!(phones instanceof List<Object>)) return null;
        String firstAny = null;
        for (Object p : (List<Object>) phones) {
            if (!(p instanceof Map<String, Object>)) continue;
            Map<String, Object> pm = (Map<String, Object>) p;
            String val = toStr(pm.get('value'));
            if (String.isBlank(val)) continue;
            if (firstAny == null) firstAny = val;
            if (toStr(pm.get('type')) == 'WORK') return val;
        }
        return firstAny;
    }

    @TestVisible
    private static void backfillEmployeeUserAndCrewLinks() {
        List<Employee__c> employees = [
            SELECT Id, Work_Email__c, User__c, Crew__c, Status__c
            FROM Employee__c
            WHERE Status__c = 'Active'
              AND (Work_Email__c != null OR User__c != null)
        ];
        if (employees.isEmpty()) return;

        Set<String> emails = new Set<String>();
        Set<Id> userIds = new Set<Id>();
        for (Employee__c emp : employees) {
            if (String.isNotBlank(emp.Work_Email__c)) {
                emails.add(emp.Work_Email__c.trim().toLowerCase());
            }
            if (emp.User__c != null) {
                userIds.add(emp.User__c);
            }
        }

        Map<String, Id> userByEmail = new Map<String, Id>();
        if (!emails.isEmpty()) {
            for (User u : [
                SELECT Id, Email
                FROM User
                WHERE IsActive = true AND Email IN :emails
            ]) {
                if (String.isNotBlank(u.Email)) {
                    userByEmail.put(u.Email.trim().toLowerCase(), u.Id);
                    userIds.add(u.Id);
                }
            }
        }

        Map<Id, Id> crewByForemanUser = new Map<Id, Id>();
        if (!userIds.isEmpty()) {
            for (Crew__c crew : [
                SELECT Id, Foreman__c
                FROM Crew__c
                WHERE Foreman__c IN :userIds
            ]) {
                if (crew.Foreman__c != null && !crewByForemanUser.containsKey(crew.Foreman__c)) {
                    crewByForemanUser.put(crew.Foreman__c, crew.Id);
                }
            }
        }

        List<Employee__c> updates = new List<Employee__c>();
        for (Employee__c emp : employees) {
            Id resolvedUserId = emp.User__c;
            if (resolvedUserId == null && String.isNotBlank(emp.Work_Email__c)) {
                resolvedUserId = userByEmail.get(emp.Work_Email__c.trim().toLowerCase());
            }

            Boolean changed = false;
            Employee__c updateRow = new Employee__c(Id = emp.Id);
            if (emp.User__c == null && resolvedUserId != null) {
                updateRow.User__c = resolvedUserId;
                changed = true;
            }
            if (emp.Crew__c == null && resolvedUserId != null && crewByForemanUser.containsKey(resolvedUserId)) {
                updateRow.Crew__c = crewByForemanUser.get(resolvedUserId);
                changed = true;
            }
            if (changed) {
                updates.add(updateRow);
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    @TestVisible
    private static Employee__c mapEmployeeResponse(Map<String, Object> raw) {
        if (raw == null) {
            return null;
        }
        String ripplingId = toStr(raw.get('id'));
        if (String.isBlank(ripplingId)) {
            return null;
        }
        Employee__c emp = new Employee__c();
        emp.Rippling_Id__c = ripplingId;
        // V2 uses camelCase (firstName); V1 used snake_case (first_name). Accept both.
        emp.First_Name__c = coalesce(raw, 'firstName', 'first_name');
        emp.Last_Name__c  = coalesce(raw, 'lastName',  'last_name');
        String fullName = (emp.First_Name__c == null ? '' : emp.First_Name__c)
            + ' '
            + (emp.Last_Name__c == null ? '' : emp.Last_Name__c);
        emp.Name = fullName.trim().left(80);
        emp.Work_Email__c     = coalesce(raw, 'workEmail',     'work_email');
        emp.Personal_Email__c = coalesce(raw, 'personalEmail', 'personal_email');
        emp.Phone__c  = toStr(raw.get('phone'));
        emp.Title__c  = toStr(raw.get('title'));
        emp.Role__c   = coalesce(raw, 'roleId', 'role');

        Object deptObj = raw.get('department');
        String deptName = null;
        if (deptObj instanceof Map<String, Object>) {
            deptName = toStr(((Map<String, Object>) deptObj).get('name'));
        } else if (deptObj instanceof String) {
            deptName = (String) deptObj;
        }
        emp.Department__c = TARGET_DEPARTMENTS.contains(deptName) ? deptName : 'Other';

        // V2: startDate / terminationDate. V1: hire_date / termination_date.
        emp.Hire_Date__c         = toDate(raw.get('startDate')       != null ? raw.get('startDate')       : raw.get('hire_date'));
        emp.Termination_Date__c  = toDate(raw.get('terminationDate') != null ? raw.get('terminationDate') : raw.get('termination_date'));
        // V2: employmentType. V1: employment_status.
        String statusRaw = coalesce(raw, 'employmentType', 'employment_status');
        emp.Status__c = mapStatus(statusRaw);
        emp.Driver_License_Expiry__c = toDate(coalesce(raw, 'driverLicenseExpiry', 'driver_license_expiry'));
        emp.Is_Driver__c = resolveDriverFlag(raw);
        emp.Last_Rippling_Sync__c = DateTime.now();
        return emp;
    }

    // Returns the first non-blank string value found across the given keys.
    private static String coalesce(Map<String, Object> m, String key1, String key2) {
        String v = toStr(m.get(key1));
        return String.isBlank(v) ? toStr(m.get(key2)) : v;
    }

    @TestVisible
    private static Rippling_Time_Entry__c mapTimeEntryResponse(Map<String, Object> raw, Map<String, Id> empByRipplingId) {
        if (raw == null) {
            return null;
        }
        String entryId = toStr(raw.get('id'));
        // V2 uses worker_id; V1 used employee_id — accept both.
        String employeeRipplingId = toStr(raw.get('worker_id'));
        if (String.isBlank(employeeRipplingId)) employeeRipplingId = toStr(raw.get('employee_id'));
        if (String.isBlank(entryId) || String.isBlank(employeeRipplingId)) {
            return null;
        }
        Id empId = empByRipplingId.get(employeeRipplingId);
        if (empId == null) {
            return null;
        }
        Rippling_Time_Entry__c te = new Rippling_Time_Entry__c();
        te.Rippling_Time_Entry_Id__c = entryId;
        te.Employee__c = empId;
        te.Clock_In__c = toDateTime(raw.get('clock_in'));
        te.Clock_Out__c = toDateTime(raw.get('clock_out'));
        te.Work_Date__c = te.Clock_In__c != null ? te.Clock_In__c.date() : Date.today();
        te.Department_At_Entry__c = toStr(raw.get('department_name'));
        te.Job_Code__c = toStr(raw.get('job_code'));
        te.Notes__c = toStr(raw.get('notes'));
        te.Last_Rippling_Sync__c = DateTime.now();
        return te;
    }

    @TestVisible
    private static Rippling_Time_Off__c mapTimeOffResponse(Map<String, Object> raw, Map<String, Id> empByRipplingId) {
        if (raw == null) {
            return null;
        }
        String toId = toStr(raw.get('id'));
        // V2 uses worker_id; V1 used employee_id — accept both.
        String employeeRipplingId = toStr(raw.get('worker_id'));
        if (String.isBlank(employeeRipplingId)) employeeRipplingId = toStr(raw.get('employee_id'));
        if (String.isBlank(toId) || String.isBlank(employeeRipplingId)) {
            return null;
        }
        Id empId = empByRipplingId.get(employeeRipplingId);
        if (empId == null) {
            return null;
        }
        Rippling_Time_Off__c to = new Rippling_Time_Off__c();
        to.Rippling_Time_Off_Id__c = toId;
        to.Employee__c = empId;
        to.Start_Date__c = toDate(raw.get('start_date'));
        to.End_Date__c = toDate(raw.get('end_date'));
        to.Start_DateTime__c = toDateTime(raw.get('start_datetime'));
        to.End_DateTime__c = toDateTime(raw.get('end_datetime'));
        to.Type__c = mapTimeOffType(toStr(raw.get('policy_type')));
        to.Status__c = mapTimeOffStatus(toStr(raw.get('status')));
        to.Hours__c = toDecimal(raw.get('hours'));
        to.Notes__c = toStr(raw.get('notes'));
        to.Last_Rippling_Sync__c = DateTime.now();
        return to;
    }

    @TestVisible
    private static Boolean resolveDriverFlag(Map<String, Object> raw) {
        List<Rippling_Field_Mapping__mdt> mappings = getDriverMappings();
        for (Rippling_Field_Mapping__mdt m : mappings) {
            if (m.Salesforce_Field__c != 'Is_Driver__c') {
                continue;
            }
            Object val = resolvePath(raw, m.Rippling_Path__c);
            if (val != null) {
                return toBool(val);
            }
        }
        Object fallback = resolvePath(raw, 'custom_fields.is_driver');
        return fallback == null ? false : toBool(fallback);
    }

    @TestVisible
    private static List<Rippling_Field_Mapping__mdt> getDriverMappings() {
        try {
            return [
                SELECT DeveloperName, Rippling_Path__c, Salesforce_Field__c, Field_Type__c
                FROM Rippling_Field_Mapping__mdt
                WHERE Salesforce_Field__c = 'Is_Driver__c'
                LIMIT 50
            ];
        } catch (Exception e) {
            return new List<Rippling_Field_Mapping__mdt>();
        }
    }

    // ------------------------------------------------------------------
    // Rollup helpers
    // ------------------------------------------------------------------

    @TestVisible
    private static void recomputeClockedInFlags(List<Id> employeeIds) {
        if (employeeIds == null || employeeIds.isEmpty()) {
            return;
        }
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([
            SELECT Id, Currently_Clocked_In__c, Current_Shift_Start__c
            FROM Employee__c
            WHERE Id IN :employeeIds
        ]);
        Map<Id, DateTime> latestOpen = new Map<Id, DateTime>();
        for (Rippling_Time_Entry__c te : [
            SELECT Id, Employee__c, Clock_In__c, Clock_Out__c
            FROM Rippling_Time_Entry__c
            WHERE Employee__c IN :employeeIds
            AND Clock_Out__c = null
        ]) {
            DateTime cur = latestOpen.get(te.Employee__c);
            if (cur == null || te.Clock_In__c > cur) {
                latestOpen.put(te.Employee__c, te.Clock_In__c);
            }
        }
        List<Employee__c> toUpdate = new List<Employee__c>();
        for (Employee__c e : emps.values()) {
            DateTime open = latestOpen.get(e.Id);
            e.Currently_Clocked_In__c = open != null;
            e.Current_Shift_Start__c = open;
            toUpdate.add(e);
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    @TestVisible
    private static void recomputeOnPtoFlags(List<Id> employeeIds) {
        if (employeeIds == null || employeeIds.isEmpty()) {
            return;
        }
        Date today = Date.today();
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([
            SELECT Id, On_PTO_Today__c
            FROM Employee__c
            WHERE Id IN :employeeIds
        ]);
        Set<Id> onPto = new Set<Id>();
        for (Rippling_Time_Off__c to : [
            SELECT Id, Employee__c, Start_Date__c, End_Date__c, Status__c
            FROM Rippling_Time_Off__c
            WHERE Employee__c IN :employeeIds
            AND Status__c = 'Approved'
            AND Start_Date__c <= :today
            AND End_Date__c >= :today
        ]) {
            onPto.add(to.Employee__c);
        }
        List<Employee__c> toUpdate = new List<Employee__c>();
        for (Employee__c e : emps.values()) {
            Boolean flag = onPto.contains(e.Id);
            if (e.On_PTO_Today__c != flag) {
                e.On_PTO_Today__c = flag;
                toUpdate.add(e);
            }
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    @TestVisible
    private static Map<String, Id> queryEmployeeMapForEntries(List<Map<String, Object>> raw) {
        Set<String> ids = new Set<String>();
        for (Map<String, Object> rec : raw) {
            String eid = toStr(rec.get('worker_id'));
            if (String.isBlank(eid)) eid = toStr(rec.get('employee_id'));
            if (!String.isBlank(eid)) {
                ids.add(eid);
            }
        }
        Map<String, Id> out = new Map<String, Id>();
        if (ids.isEmpty()) {
            return out;
        }
        for (Employee__c e : [SELECT Id, Rippling_Id__c FROM Employee__c WHERE Rippling_Id__c IN :ids]) {
            out.put(e.Rippling_Id__c, e.Id);
        }
        return out;
    }

    @TestVisible
    private static Map<String, Id> queryEmployeeMapForTimeOff(List<Map<String, Object>> raw) {
        return queryEmployeeMapForEntries(raw);
    }

    // ------------------------------------------------------------------
    // HTTP + pagination
    // ------------------------------------------------------------------

    @TestVisible
    private static List<Map<String, Object>> fetchAllPages(String path) {
        List<Map<String, Object>> all = new List<Map<String, Object>>();
        String nextPath = path;
        Integer safety = 0;
        while (!String.isBlank(nextPath) && safety < 25) {
            safety++;
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + nextPath);
            req.setMethod('GET');
            req.setHeader('Accept', 'application/json');
            IntegrationSecrets.applyAuth(req, 'Rippling');
            req.setTimeout(60000);
            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                System.debug(LoggingLevel.ERROR, 'RipplingSyncService: HTTP ' + res.getStatusCode() + ' from ' + nextPath);
                break;
            }
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Object results = body.get('results');
            if (results == null) {
                results = body.get('data');
            }
            if (results instanceof List<Object>) {
                for (Object o : (List<Object>) results) {
                    if (o instanceof Map<String, Object>) {
                        all.add((Map<String, Object>) o);
                    }
                }
            }
            // Rippling V2 returns the full next page URL in 'next_link'
            String nextLink = toStr(body.get('next_link'));
            if (String.isBlank(nextLink)) {
                break;
            }
            // Strip the base URL to get a relative path the loop can prepend BASE_URL to
            nextPath = nextLink.startsWith(BASE_URL) ? nextLink.substring(BASE_URL.length()) : nextLink;
        }
        return all;
    }

    @TestVisible
    private static String appendCursor(String path, String cursor) {
        String sep = path.contains('?') ? '&' : '?';
        return path + sep + 'cursor=' + EncodingUtil.urlEncode(cursor, 'UTF-8');
    }

    // ------------------------------------------------------------------
    // Schema + type utilities
    // ------------------------------------------------------------------

    @TestVisible
    private static Boolean isObjectAccessible(String objectApiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objectApiName)) {
            return false;
        }
        return gd.get(objectApiName).getDescribe().isAccessible();
    }

    @TestVisible
    private static Object resolvePath(Map<String, Object> root, String path) {
        if (root == null || String.isBlank(path)) {
            return null;
        }
        Object cur = root;
        for (String part : path.split('\\.')) {
            if (!(cur instanceof Map<String, Object>)) {
                return null;
            }
            cur = ((Map<String, Object>) cur).get(part);
            if (cur == null) {
                return null;
            }
        }
        return cur;
    }

    @TestVisible
    private static String toStr(Object o) {
        return o == null ? null : String.valueOf(o);
    }

    @TestVisible
    private static Boolean toBool(Object o) {
        if (o == null) {
            return false;
        }
        if (o instanceof Boolean) {
            return (Boolean) o;
        }
        String s = String.valueOf(o).toLowerCase();
        return s == 'true' || s == '1' || s == 'yes' || s == 'y';
    }

    @TestVisible
    private static Date toDate(Object o) {
        if (o == null) {
            return null;
        }
        try {
            return Date.valueOf(String.valueOf(o).left(10));
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static DateTime toDateTime(Object o) {
        if (o == null) {
            return null;
        }
        try {
            String s = String.valueOf(o);
            if (s.endsWith('Z')) {
                s = s.replace('Z', '+0000');
            }
            return (DateTime) JSON.deserialize('"' + s + '"', DateTime.class);
        } catch (Exception e) {
            try {
                return DateTime.valueOfGmt(String.valueOf(o).replace('T', ' ').replace('Z', ''));
            } catch (Exception e2) {
                return null;
            }
        }
    }

    @TestVisible
    private static Decimal toDecimal(Object o) {
        if (o == null) {
            return null;
        }
        try {
            return Decimal.valueOf(String.valueOf(o));
        } catch (Exception e) {
            return null;
        }
    }

    // Derives operational Role__c from Rippling title + name overrides.
    // Name-based overrides run first so management staff are never mis-classified.
    public static String mapRole(String firstName, String lastName, String title) {
        // Named overrides — exact name matches take priority over title.
        String fullName = ((firstName == null ? '' : firstName) + ' ' + (lastName == null ? '' : lastName)).trim().toLowerCase();
        if (fullName == 'dan corrigan') return 'Schedule Manager/Dispatch Supervisor';
        if (firstName != null && firstName.toLowerCase() == 'erica' && lastName != null && lastName.toLowerCase() != 'corrigan') return 'CSM';

        if (String.isBlank(title)) return null;
        String t = title.toLowerCase();

        // Scheduling / dispatch — check before generic "manager" so "Scheduling Manager" → Schedule Manager/Dispatch Supervisor.
        // Use 'schedul' root to match 'schedule', 'scheduling', 'scheduler', 'Manager, Scheduling'.
        if (t.contains('schedul') || t.contains('dispatch')) return 'Schedule Manager/Dispatch Supervisor';
        // Customer success.
        if (t.contains('customer success') || t == 'csm') return 'CSM';
        // Lead / foreman — check before plain "tech" so "Lead Tech" → Foreman.
        if (t.contains('lead') || t.contains('foreman')) return 'Foreman';
        // Operations / field supervisor.
        if (t.contains('supervisor')) return 'Foreman';
        // Designer — check before landscap so "Landscape Designer" doesn't match Tech.
        if (t.contains('design')) return 'Designer';
        // Technician / crew.
        if (t.contains('tech') || t.contains('crew') || t.contains('landscap') || t.contains('irrigat')) return 'Tech';
        // Generic manager fallback.
        if (t.contains('manager')) return 'Manager';
        return null;
    }

    @TestVisible
    private static String mapStatus(String raw) {
        if (String.isBlank(raw)) {
            return 'Active';
        }
        String s = raw.toLowerCase();
        if (s.contains('terminat')) {
            return 'Terminated';
        }
        if (s.contains('leave')) {
            return 'On Leave';
        }
        return 'Active';
    }

    @TestVisible
    private static String mapTimeOffType(String raw) {
        if (String.isBlank(raw)) {
            return 'Other';
        }
        String s = raw.toLowerCase();
        if (s.contains('vac')) { return 'Vacation'; }
        if (s.contains('sick')) { return 'Sick'; }
        if (s.contains('personal')) { return 'Personal'; }
        if (s.contains('bereav')) { return 'Bereavement'; }
        if (s.contains('jury')) { return 'Jury Duty'; }
        if (s.contains('unpaid')) { return 'Unpaid'; }
        return 'Other';
    }

    @TestVisible
    private static String mapTimeOffStatus(String raw) {
        if (String.isBlank(raw)) {
            return 'Pending';
        }
        String s = raw.toLowerCase();
        if (s.contains('approv')) { return 'Approved'; }
        if (s.contains('deni') || s.contains('reject')) { return 'Denied'; }
        if (s.contains('cancel')) { return 'Cancelled'; }
        return 'Pending';
    }

    @TestVisible
    private static String padTwo(Integer n) {
        return n < 10 ? '0' + String.valueOf(n) : String.valueOf(n);
    }
}