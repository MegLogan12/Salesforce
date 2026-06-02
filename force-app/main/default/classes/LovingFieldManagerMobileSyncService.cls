public without sharing class LovingFieldManagerMobileSyncService {

    private static final String TAKEOFF_WORKTYPE = 'Field Manager Takeoff';
    private static final String SITE_READINESS_WORKTYPE = 'Field Manager 48-Hour Site Visit';
    private static final String FM_REVIEW_WORKTYPE = 'Field Manager Quality Inspection';
    private static final String SITE_VISIT_WORKTYPE = 'Site Visit';
    private static final String AQUA_CHECK_WORKTYPE = 'Aqua Check';
    private static final String AQUA_PICKUP_WORKTYPE = 'Aqua Pickup';

    private static final String PROD_RT = 'Production_Install';
    private static final String CUSTOMER_SUCCESS_RT = 'Customer_Care';
    private static final String AQUA_CHECK_RT = 'Aqua_Check';
    private static final String AQUA_PICKUP_RT = 'Aqua_Pickup';

    private static final String PROD_TYPE = 'Production Install';
    private static final String CUSTOMER_SUCCESS_TYPE = 'Customer Care';
    private static final String AQUA_CHECK_TYPE = 'Aqua Check';
    private static final String AQUA_PICKUP_TYPE = 'Aqua Pickup';

    private static final Set<String> OPEN_TAKEOFF_STATUSES = new Set<String>{
        'Draft', 'Submitted', 'In Progress', 'Returned'
    };
    private static final Set<String> ACTIVE_AQUA_STATUSES = new Set<String>{
        'Open', 'Scheduled', 'Assigned', 'In Progress'
    };
    private static final Set<String> FM_REVIEW_STATUSES = new Set<String>{
        'Site Readiness', 'FM/QI Review', 'Pending Closeout', 'Site Visit Scheduled'
    };

    private static Boolean inFlight = false;
    private static Map<String, Id> recordTypeIds;
    private static Map<String, WorkType> workTypesByName;
    private static Map<Id, Id> serviceResourceByUser;

    public static void syncTakeoffs(Set<Id> takeoffIds) {
        if (takeoffIds == null || takeoffIds.isEmpty() || inFlight) {
            return;
        }
        inFlight = true;
        try {
            List<Takeoff__c> takeoffs = [
                SELECT Id, Name, Status__c, Scheduled_Date__c, Notes__c,
                       FM_Assignment__c, Community__c, Community__r.Name, Community__r.Builder_Account__c,
                       Community__r.ServiceTerritory__c, Community__r.Territory__c,
                       Lot__c, Lot__r.Name
                FROM Takeoff__c
                WHERE Id IN :takeoffIds
            ];
            ensureTakeoffAppointments(takeoffs);
        } finally {
            inFlight = false;
        }
    }

    public static void syncAquaChecks(Set<Id> ticketIds) {
        if (ticketIds == null || ticketIds.isEmpty() || inFlight) {
            return;
        }
        inFlight = true;
        try {
            List<Aqua_Check_Ticket__c> tickets = [
                SELECT Id, Name, Status__c, Scheduled_Date__c, Assigned_To__c,
                       Community__c, Community__r.Name, Lot__c, Lot__r.Name,
                       Lot__r.Community__r.ServiceTerritory__c, Lot__r.Community__r.Territory__c
                FROM Aqua_Check_Ticket__c
                WHERE Id IN :ticketIds
            ];
            ensureAquaAppointments(tickets, AQUA_CHECK_WORKTYPE, AQUA_CHECK_RT, AQUA_CHECK_TYPE, 'Aqua Check');
        } finally {
            inFlight = false;
        }
    }

    public static void syncAquaPickups(Set<Id> ticketIds) {
        if (ticketIds == null || ticketIds.isEmpty() || inFlight) {
            return;
        }
        inFlight = true;
        try {
            List<Aqua_Pickup_Ticket__c> tickets = [
                SELECT Id, Name, Status__c, Scheduled_Date__c, Assigned_To__c,
                       Community__c, Community__r.Name, Lot__c, Lot__r.Name,
                       Lot__r.Community__r.ServiceTerritory__c, Lot__r.Community__r.Territory__c
                FROM Aqua_Pickup_Ticket__c
                WHERE Id IN :ticketIds
            ];
            ensureAquaAppointments(tickets, AQUA_PICKUP_WORKTYPE, AQUA_PICKUP_RT, AQUA_PICKUP_TYPE, 'Aqua Pickup');
        } finally {
            inFlight = false;
        }
    }

    public static void syncWorkOrders(Set<Id> workOrderIds) {
        if (workOrderIds == null || workOrderIds.isEmpty() || inFlight) {
            return;
        }
        inFlight = true;
        try {
            List<WorkOrder> workOrders = [
                SELECT Id, Subject, Status, AccountId, Field_Manager__c, Community__c, Lot__c,
                       Work_Order_Type__c, WorkTypeId, ServiceTerritoryId, Site_Readiness_Date__c
                FROM WorkOrder
                WHERE Id IN :workOrderIds
            ];
            ensureWorkOrderAppointments(workOrders);
        } finally {
            inFlight = false;
        }
    }

    public static void backfillOpenQueues() {
        if (inFlight) {
            return;
        }
        inFlight = true;
        try {
            ensureTakeoffAppointments([
                SELECT Id, Name, Status__c, Scheduled_Date__c, Notes__c,
                       FM_Assignment__c, Community__c, Community__r.Name, Community__r.Builder_Account__c,
                       Community__r.ServiceTerritory__c, Community__r.Territory__c,
                       Lot__c, Lot__r.Name
                FROM Takeoff__c
                WHERE FM_Assignment__c != null
                  AND Scheduled_Date__c != null
                  AND Status__c IN :OPEN_TAKEOFF_STATUSES
            ]);
            ensureAquaAppointments([
                SELECT Id, Name, Status__c, Scheduled_Date__c, Assigned_To__c,
                       Community__c, Community__r.Name, Lot__c, Lot__r.Name,
                       Lot__r.Community__r.ServiceTerritory__c, Lot__r.Community__r.Territory__c
                FROM Aqua_Check_Ticket__c
                WHERE Assigned_To__c != null
                  AND Scheduled_Date__c != null
                  AND Status__c IN :ACTIVE_AQUA_STATUSES
            ], AQUA_CHECK_WORKTYPE, AQUA_CHECK_RT, AQUA_CHECK_TYPE, 'Aqua Check');
            ensureAquaAppointments([
                SELECT Id, Name, Status__c, Scheduled_Date__c, Assigned_To__c,
                       Community__c, Community__r.Name, Lot__c, Lot__r.Name,
                       Lot__r.Community__r.ServiceTerritory__c, Lot__r.Community__r.Territory__c
                FROM Aqua_Pickup_Ticket__c
                WHERE Assigned_To__c != null
                  AND Scheduled_Date__c != null
                  AND Status__c IN :ACTIVE_AQUA_STATUSES
            ], AQUA_PICKUP_WORKTYPE, AQUA_PICKUP_RT, AQUA_PICKUP_TYPE, 'Aqua Pickup');
            ensureWorkOrderAppointments([
                SELECT Id, Subject, Status, AccountId, Field_Manager__c, Community__c, Lot__c,
                       Work_Order_Type__c, WorkTypeId, ServiceTerritoryId, Site_Readiness_Date__c
                FROM WorkOrder
                WHERE Field_Manager__c != null
                  AND Status IN :FM_REVIEW_STATUSES
            ]);
        } finally {
            inFlight = false;
        }
    }

    private static void ensureTakeoffAppointments(List<Takeoff__c> takeoffs) {
        if (takeoffs.isEmpty()) {
            return;
        }
        ensureWorkTypes(new Set<String>{ TAKEOFF_WORKTYPE });
        Id workTypeId = workTypesByName.get(TAKEOFF_WORKTYPE).Id;
        Id recordTypeId = getRecordTypeId(PROD_RT);

        Map<String, Takeoff__c> activeBySubject = new Map<String, Takeoff__c>();
        Set<Id> userIds = new Set<Id>();
        for (Takeoff__c t : takeoffs) {
            if (t.FM_Assignment__c == null || t.Scheduled_Date__c == null || !OPEN_TAKEOFF_STATUSES.contains(t.Status__c)) {
                continue;
            }
            activeBySubject.put(subjectFor('Takeoff', t.Id, labelFor(t.Community__r != null ? t.Community__r.Name : null, t.Lot__r != null ? t.Lot__r.Name : null)), t);
            userIds.add(t.FM_Assignment__c);
        }
        if (activeBySubject.isEmpty()) {
            return;
        }
        loadServiceResources(userIds);

        Map<String, WorkOrder> existingBySubject = new Map<String, WorkOrder>();
        for (WorkOrder wo : [
            SELECT Id, Subject, Field_Manager__c, WorkTypeId, ServiceTerritoryId
            FROM WorkOrder
            WHERE Subject IN :activeBySubject.keySet()
        ]) {
            existingBySubject.put(wo.Subject, wo);
        }

        List<WorkOrder> inserts = new List<WorkOrder>();
        List<WorkOrder> updates = new List<WorkOrder>();
        for (String subject : activeBySubject.keySet()) {
            Takeoff__c t = activeBySubject.get(subject);
            WorkOrder wo = existingBySubject.get(subject);
            if (wo == null) {
                wo = new WorkOrder();
                wo.Subject = subject;
                wo.RecordTypeId = recordTypeId;
                wo.Work_Order_Type__c = PROD_TYPE;
                wo.WorkTypeId = workTypeId;
                wo.AccountId = t.Community__r != null ? t.Community__r.Builder_Account__c : null;
                wo.Lot__c = t.Lot__c;
                wo.Field_Manager__c = t.FM_Assignment__c;
                wo.ServiceTerritoryId = resolveTerritoryId(t.Community__r);
                wo.Status = 'Pending Takeoff';
                wo.Takeoff_Notes__c = t.Notes__c;
                inserts.add(wo);
                existingBySubject.put(subject, wo);
            } else {
                wo.Field_Manager__c = t.FM_Assignment__c;
                wo.ServiceTerritoryId = resolveTerritoryId(t.Community__r);
                wo.Takeoff_Notes__c = t.Notes__c;
                updates.add(wo);
            }
        }
        if (!inserts.isEmpty()) {
            insert inserts;
        }
        if (!updates.isEmpty()) {
            update updates;
        }

        Map<Id, AppointmentSpec> specs = new Map<Id, AppointmentSpec>();
        for (String subject : activeBySubject.keySet()) {
            Takeoff__c t = activeBySubject.get(subject);
            WorkOrder wo = existingBySubject.get(subject);
            specs.put(wo.Id, new AppointmentSpec(
                wo.Id,
                subject,
                workTypeId,
                t.FM_Assignment__c,
                startOfDay(t.Scheduled_Date__c, 9),
                30,
                resolveTerritoryId(t.Community__r)
            ));
        }
        upsertAppointments(specs);
    }

    private static void ensureAquaAppointments(List<SObject> rows, String workTypeName, String recordTypeDevName, String workOrderType, String label) {
        if (rows.isEmpty()) {
            return;
        }
        ensureWorkTypes(new Set<String>{ workTypeName });
        Id workTypeId = workTypesByName.get(workTypeName).Id;
        Id recordTypeId = getRecordTypeId(recordTypeDevName);

        Map<String, SObject> activeBySubject = new Map<String, SObject>();
        Set<Id> userIds = new Set<Id>();
        for (SObject row : rows) {
            Id assignedTo = (Id) row.get('Assigned_To__c');
            Date scheduledDate = (Date) row.get('Scheduled_Date__c');
            String status = (String) row.get('Status__c');
            if (assignedTo == null || scheduledDate == null || !ACTIVE_AQUA_STATUSES.contains(status)) {
                continue;
            }
            String communityName = null;
            SObject community = row.getSObject('Community__r');
            if (community != null) {
                communityName = (String) community.get('Name');
            }
            String lotName = null;
            SObject lot = row.getSObject('Lot__r');
            if (lot != null) {
                lotName = (String) lot.get('Name');
            }
            String subject = subjectFor(label, (Id) row.get('Id'), labelFor(communityName, lotName));
            activeBySubject.put(subject, row);
            userIds.add(assignedTo);
        }
        if (activeBySubject.isEmpty()) {
            return;
        }
        loadServiceResources(userIds);

        Map<String, WorkOrder> existingBySubject = new Map<String, WorkOrder>();
        for (WorkOrder wo : [
            SELECT Id, Subject, Field_Manager__c, WorkTypeId
            FROM WorkOrder
            WHERE Subject IN :activeBySubject.keySet()
        ]) {
            existingBySubject.put(wo.Subject, wo);
        }

        List<WorkOrder> inserts = new List<WorkOrder>();
        List<WorkOrder> updates = new List<WorkOrder>();
        for (String subject : activeBySubject.keySet()) {
            SObject row = activeBySubject.get(subject);
            WorkOrder wo = existingBySubject.get(subject);
            if (wo == null) {
                wo = new WorkOrder();
                wo.Subject = subject;
                wo.RecordTypeId = recordTypeId;
                wo.Work_Order_Type__c = workOrderType;
                wo.WorkTypeId = workTypeId;
                wo.Lot__c = (Id) row.get('Lot__c');
                wo.Field_Manager__c = (Id) row.get('Assigned_To__c');
                wo.ServiceTerritoryId = resolveAquaTerritoryId(row);
                wo.Status = 'New';
                inserts.add(wo);
                existingBySubject.put(subject, wo);
            } else {
                wo.Field_Manager__c = (Id) row.get('Assigned_To__c');
                wo.ServiceTerritoryId = resolveAquaTerritoryId(row);
                updates.add(wo);
            }
        }
        if (!inserts.isEmpty()) {
            insert inserts;
        }
        if (!updates.isEmpty()) {
            update updates;
        }

        Map<Id, AppointmentSpec> specs = new Map<Id, AppointmentSpec>();
        for (String subject : activeBySubject.keySet()) {
            SObject row = activeBySubject.get(subject);
            WorkOrder wo = existingBySubject.get(subject);
            specs.put(wo.Id, new AppointmentSpec(
                wo.Id,
                subject,
                workTypeId,
                (Id) row.get('Assigned_To__c'),
                startOfDay((Date) row.get('Scheduled_Date__c'), 10),
                Integer.valueOf(workTypesByName.get(workTypeName).EstimatedDuration),
                resolveAquaTerritoryId(row)
            ));
        }
        upsertAppointments(specs);
    }

    private static void ensureWorkOrderAppointments(List<WorkOrder> workOrders) {
        if (workOrders.isEmpty()) {
            return;
        }
        ensureWorkTypes(new Set<String>{ SITE_READINESS_WORKTYPE, FM_REVIEW_WORKTYPE, SITE_VISIT_WORKTYPE });

        Set<Id> userIds = new Set<Id>();
        Map<Id, AppointmentSpec> specs = new Map<Id, AppointmentSpec>();
        for (WorkOrder wo : workOrders) {
            if (wo.Field_Manager__c == null) {
                continue;
            }
            AppointmentSpec spec = buildWorkOrderSpec(wo);
            if (spec == null) {
                continue;
            }
            specs.put(wo.Id, spec);
            userIds.add(wo.Field_Manager__c);
        }
        if (specs.isEmpty()) {
            return;
        }
        loadServiceResources(userIds);
        upsertAppointments(specs);
    }

    private static AppointmentSpec buildWorkOrderSpec(WorkOrder wo) {
        if (wo.Status == 'Site Readiness') {
            Date targetDate = wo.Site_Readiness_Date__c == null ? Date.today() : wo.Site_Readiness_Date__c;
            return new AppointmentSpec(
                wo.Id,
                subjectFor('Site Readiness', wo.Id, wo.Subject),
                workTypesByName.get(SITE_READINESS_WORKTYPE).Id,
                wo.Field_Manager__c,
                startOfDay(targetDate, 8),
                Integer.valueOf(workTypesByName.get(SITE_READINESS_WORKTYPE).EstimatedDuration),
                wo.ServiceTerritoryId
            );
        }
        if (wo.Status == 'FM/QI Review' || wo.Status == 'Pending Closeout') {
            return new AppointmentSpec(
                wo.Id,
                subjectFor('FM Review', wo.Id, wo.Subject),
                workTypesByName.get(FM_REVIEW_WORKTYPE).Id,
                wo.Field_Manager__c,
                startOfDay(Date.today(), 13),
                Integer.valueOf(workTypesByName.get(FM_REVIEW_WORKTYPE).EstimatedDuration),
                wo.ServiceTerritoryId
            );
        }
        if (wo.Status == 'Site Visit Scheduled' || (wo.Work_Order_Type__c == CUSTOMER_SUCCESS_TYPE && wo.WorkTypeId == workTypesByName.get(SITE_VISIT_WORKTYPE).Id)) {
            return new AppointmentSpec(
                wo.Id,
                subjectFor('Site Visit', wo.Id, wo.Subject),
                workTypesByName.get(SITE_VISIT_WORKTYPE).Id,
                wo.Field_Manager__c,
                startOfDay(Date.today(), 11),
                Integer.valueOf(workTypesByName.get(SITE_VISIT_WORKTYPE).EstimatedDuration),
                wo.ServiceTerritoryId
            );
        }
        return null;
    }

    private static void upsertAppointments(Map<Id, AppointmentSpec> specsByWorkOrderId) {
        if (specsByWorkOrderId.isEmpty()) {
            return;
        }

        Set<String> subjects = new Set<String>();
        for (AppointmentSpec spec : specsByWorkOrderId.values()) {
            subjects.add(spec.subject);
        }

        Map<Id, ServiceAppointment> existingByWorkOrderId = new Map<Id, ServiceAppointment>();
        Set<Id> appointmentIds = new Set<Id>();
        for (ServiceAppointment sa : [
            SELECT Id, ParentRecordId, Subject, WorkTypeId, ServiceTerritoryId
            FROM ServiceAppointment
            WHERE ParentRecordId IN :specsByWorkOrderId.keySet()
              AND Subject IN :subjects
        ]) {
            existingByWorkOrderId.put(sa.ParentRecordId, sa);
            appointmentIds.add(sa.Id);
        }

        Map<Id, Set<Id>> existingResourceLinks = new Map<Id, Set<Id>>();
        if (!appointmentIds.isEmpty()) {
            for (AssignedResource ar : [
                SELECT Id, ServiceAppointmentId, ServiceResourceId
                FROM AssignedResource
                WHERE ServiceAppointmentId IN :appointmentIds
            ]) {
                if (!existingResourceLinks.containsKey(ar.ServiceAppointmentId)) {
                    existingResourceLinks.put(ar.ServiceAppointmentId, new Set<Id>());
                }
                existingResourceLinks.get(ar.ServiceAppointmentId).add(ar.ServiceResourceId);
            }
        }

        List<ServiceAppointment> inserts = new List<ServiceAppointment>();
        List<ServiceAppointment> updates = new List<ServiceAppointment>();
        Map<Id, Id> appointmentToServiceResource = new Map<Id, Id>();

        for (Id workOrderId : specsByWorkOrderId.keySet()) {
            AppointmentSpec spec = specsByWorkOrderId.get(workOrderId);
            Id serviceResourceId = serviceResourceByUser.get(spec.userId);
            if (serviceResourceId == null) {
                continue;
            }

            ServiceAppointment existing = existingByWorkOrderId.get(workOrderId);
            if (existing == null) {
                ServiceAppointment sa = new ServiceAppointment(
                    ParentRecordId = workOrderId,
                    Subject = spec.subject,
                    Status = 'None',
                    WorkTypeId = spec.workTypeId,
                    ServiceTerritoryId = spec.serviceTerritoryId,
                    Duration = spec.durationMinutes,
                    DurationType = 'Minutes',
                    SchedStartTime = spec.startTime,
                    SchedEndTime = spec.startTime.addMinutes(spec.durationMinutes),
                    EarliestStartTime = spec.startTime,
                    DueDate = spec.startTime.addMinutes(spec.durationMinutes)
                );
                inserts.add(sa);
            } else {
                existing.WorkTypeId = spec.workTypeId;
                existing.ServiceTerritoryId = spec.serviceTerritoryId;
                existing.Status = 'Scheduled';
                existing.SchedStartTime = spec.startTime;
                existing.SchedEndTime = spec.startTime.addMinutes(spec.durationMinutes);
                existing.EarliestStartTime = spec.startTime;
                existing.DueDate = spec.startTime.addMinutes(spec.durationMinutes);
                updates.add(existing);
                appointmentToServiceResource.put(existing.Id, serviceResourceId);
            }
        }
        if (!inserts.isEmpty()) {
            insert inserts;
            for (ServiceAppointment sa : inserts) {
                AppointmentSpec spec = specsByWorkOrderId.get(sa.ParentRecordId);
                appointmentToServiceResource.put(sa.Id, serviceResourceByUser.get(spec.userId));
                sa.Status = 'Scheduled';
                updates.add(sa);
            }
        }
        if (!updates.isEmpty()) {
            update updates;
        }

        List<AssignedResource> assignmentsToInsert = new List<AssignedResource>();
        for (Id appointmentId : appointmentToServiceResource.keySet()) {
            Id serviceResourceId = appointmentToServiceResource.get(appointmentId);
            Set<Id> linked = existingResourceLinks.get(appointmentId);
            if (linked != null && linked.contains(serviceResourceId)) {
                continue;
            }
            assignmentsToInsert.add(new AssignedResource(
                ServiceAppointmentId = appointmentId,
                ServiceResourceId = serviceResourceId
            ));
        }
        if (!assignmentsToInsert.isEmpty()) {
            insert assignmentsToInsert;
        }
    }

    private static void ensureWorkTypes(Set<String> names) {
        if (workTypesByName == null) {
            workTypesByName = new Map<String, WorkType>();
        }
        Set<String> missing = new Set<String>(names);
        missing.removeAll(workTypesByName.keySet());
        if (!missing.isEmpty()) {
            for (WorkType wt : [
                SELECT Id, Name, EstimatedDuration, DurationType
                FROM WorkType
                WHERE Name IN :missing
            ]) {
                workTypesByName.put(wt.Name, wt);
            }
            missing.removeAll(workTypesByName.keySet());
        }
        if (missing.isEmpty()) {
            return;
        }
        List<WorkType> toInsert = new List<WorkType>();
        for (String missingName : missing) {
            toInsert.add(new WorkType(
                Name = missingName,
                EstimatedDuration = defaultDuration(missingName),
                DurationType = 'Minutes'
            ));
        }
        insert toInsert;
        for (WorkType wt : toInsert) {
            workTypesByName.put(wt.Name, wt);
        }
    }

    private static Decimal defaultDuration(String workTypeName) {
        if (workTypeName == AQUA_CHECK_WORKTYPE) return 10;
        if (workTypeName == AQUA_PICKUP_WORKTYPE) return 20;
        if (workTypeName == TAKEOFF_WORKTYPE) return 30;
        if (workTypeName == SITE_READINESS_WORKTYPE) return 20;
        if (workTypeName == FM_REVIEW_WORKTYPE) return 30;
        if (workTypeName == SITE_VISIT_WORKTYPE) return 30;
        return 30;
    }

    private static void loadServiceResources(Set<Id> userIds) {
        if (serviceResourceByUser == null) {
            serviceResourceByUser = new Map<Id, Id>();
        }
        Set<Id> missing = new Set<Id>(userIds);
        missing.removeAll(serviceResourceByUser.keySet());
        if (missing.isEmpty()) {
            return;
        }
        for (ServiceResource resource : [
            SELECT Id, RelatedRecordId
            FROM ServiceResource
            WHERE IsActive = true
              AND RelatedRecordId IN :missing
        ]) {
            serviceResourceByUser.put(resource.RelatedRecordId, resource.Id);
        }
        for (Id userId : missing) {
            if (!serviceResourceByUser.containsKey(userId)) {
                serviceResourceByUser.put(userId, null);
            }
        }
    }

    private static Id getRecordTypeId(String developerName) {
        if (recordTypeIds == null) {
            recordTypeIds = new Map<String, Id>();
        }
        if (!recordTypeIds.containsKey(developerName)) {
            Schema.RecordTypeInfo info = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get(developerName);
            recordTypeIds.put(developerName, info == null ? null : info.getRecordTypeId());
        }
        return recordTypeIds.get(developerName);
    }

    private static String subjectFor(String label, Id sourceId, String contextLabel) {
        String suffix = String.isBlank(contextLabel) ? String.valueOf(sourceId) : contextLabel + ' | ' + String.valueOf(sourceId);
        return label + ' | ' + suffix;
    }

    private static String labelFor(String communityName, String lotName) {
        if (String.isNotBlank(communityName) && String.isNotBlank(lotName)) {
            return communityName + ' / ' + lotName;
        }
        return String.isNotBlank(lotName) ? lotName : communityName;
    }

    private static Datetime startOfDay(Date targetDate, Integer hourOfDay) {
        Date resolved = targetDate == null ? Date.today() : targetDate;
        return Datetime.newInstance(resolved, Time.newInstance(hourOfDay, 0, 0, 0));
    }

    private static String normalizedTakeoffStatus(String takeoffStatus) {
        if (String.isBlank(takeoffStatus)) return 'Not Started';
        if (takeoffStatus == 'Draft') return 'Not Started';
        if (takeoffStatus == 'Submitted') return 'Confirmed';
        if (takeoffStatus == 'Approved' || takeoffStatus == 'Locked') return 'Locked';
        if (takeoffStatus == 'In Progress') return 'In Progress';
        if (takeoffStatus == 'Returned') return 'Variance Flagged';
        return 'Not Started';
    }

    private static Id resolveTerritoryId(SObject communityRecord) {
        if (communityRecord == null) {
            return null;
        }
        Id serviceTerritoryId = (Id) communityRecord.get('ServiceTerritory__c');
        if (serviceTerritoryId != null) {
            return serviceTerritoryId;
        }
        return (Id) communityRecord.get('Territory__c');
    }

    private static Id resolveAquaTerritoryId(SObject aquaRecord) {
        if (aquaRecord == null) {
            return null;
        }
        SObject lotRecord = aquaRecord.getSObject('Lot__r');
        if (lotRecord == null) {
            return null;
        }
        SObject communityRecord = lotRecord.getSObject('Community__r');
        return resolveTerritoryId(communityRecord);
    }

    private class AppointmentSpec {
        Id workOrderId;
        String subject;
        Id workTypeId;
        Id userId;
        Datetime startTime;
        Integer durationMinutes;
        Id serviceTerritoryId;

        AppointmentSpec(Id workOrderId, String subject, Id workTypeId, Id userId, Datetime startTime, Integer durationMinutes, Id serviceTerritoryId) {
            this.workOrderId = workOrderId;
            this.subject = subject;
            this.workTypeId = workTypeId;
            this.userId = userId;
            this.startTime = startTime;
            this.durationMinutes = durationMinutes;
            this.serviceTerritoryId = serviceTerritoryId;
        }
    }
}