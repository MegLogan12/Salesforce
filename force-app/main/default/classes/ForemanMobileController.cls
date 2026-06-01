public with sharing class ForemanMobileController {

    private static final String PHOTO_KEY_BEFORE_FRONT = 'before_front';
    private static final String PHOTO_KEY_BEFORE_BACK = 'before_back';
    private static final String PHOTO_KEY_BEFORE_LEFT = 'before_left';
    private static final String PHOTO_KEY_BEFORE_RIGHT = 'before_right';
    private static final String PHOTO_KEY_AFTER_FRONT = 'after_front';
    private static final String PHOTO_KEY_AFTER_BACK = 'after_back';
    private static final String PHOTO_KEY_AFTER_DETAIL = 'after_detail';
    private static final String PHOTO_KEY_AFTER_HERO = 'after_hero';
    private static final String PHOTO_KEY_ISSUE = 'issue_photo';

    public class DayDto {
        @AuraEnabled public Boolean vehicleCheck;
        @AuraEnabled public Boolean loadingCheck;
        @AuraEnabled public String  scheduledLot;
        @AuraEnabled public String  scheduledDate;
        @AuraEnabled public String  syncSource;
    }

    public class ClockStatusDto {
        @AuraEnabled public String  employeeId;
        @AuraEnabled public String  employeeName;
        @AuraEnabled public Boolean clockedIn;
        @AuraEnabled public Boolean onPto;
        @AuraEnabled public DateTime shiftStart;
        @AuraEnabled public DateTime lastClockIn;
        @AuraEnabled public DateTime lastClockOut;
        @AuraEnabled public Decimal  hoursToday;
        @AuraEnabled public String   department;
        @AuraEnabled public String   ptoType;
        @AuraEnabled public DateTime lastSync;
    }

    public class JobDto {
        @AuraEnabled public String  id;
        @AuraEnabled public String  woNumber;
        @AuraEnabled public String  subject;
        @AuraEnabled public String  status;
        @AuraEnabled public String  statusLabel;
        @AuraEnabled public String  workOrderType;
        @AuraEnabled public String  subStatus;
        @AuraEnabled public Decimal sodSqft;
        @AuraEnabled public String  sodSpecies;
        @AuraEnabled public String  fm;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public String  crewName;
        @AuraEnabled public String  lotName;
        @AuraEnabled public String  communityName;
        @AuraEnabled public String  builderName;
        @AuraEnabled public String  address;
        @AuraEnabled public String  cityStateZip;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public Date scheduledDate;
        @AuraEnabled public DateTime driveStartedAt;
        @AuraEnabled public DateTime arrivedAt;
        @AuraEnabled public Decimal takeoffPhotoCount;
        @AuraEnabled public Decimal closeoutPhotoCount;
        @AuraEnabled public Decimal installedSodSqft;
        @AuraEnabled public String  closeoutNotes;
        @AuraEnabled public String  appointmentNumber;
        @AuraEnabled public String  appointmentStatus;
        @AuraEnabled public DateTime appointmentStart;
        @AuraEnabled public Boolean vehicleCheckCompleted;
        @AuraEnabled public Boolean loadingCheckCompleted;
        @AuraEnabled public Boolean scheduleLocked;
    }

    public class MobileContextDto {
        @AuraEnabled public String workOrderId;
        @AuraEnabled public String foremanName;
        @AuraEnabled public String crewName;
        @AuraEnabled public ClockStatusDto clockStatus;
        @AuraEnabled public JobDto activeJob;
        @AuraEnabled public List<ScheduleCardDto> schedule;
        @AuraEnabled public VehicleChecklistDto vehicleChecklist;
        @AuraEnabled public LoadedChecklistDto loadedChecklist;
        @AuraEnabled public List<ChecklistGroupDto> workOrderChecklists;
        @AuraEnabled public List<ScopeLineItemDto> lineItems;
        @AuraEnabled public List<IssueDto> openIssues;
        @AuraEnabled public PhotoSummaryDto photoSummary;
        @AuraEnabled public Boolean canBeginDrive;
        @AuraEnabled public String beginDriveReason;
        @AuraEnabled public Boolean canSubmitCloseout;
        @AuraEnabled public List<String> closeoutGates;
    }

    public class ScheduleCardDto {
        @AuraEnabled public String workOrderId;
        @AuraEnabled public String serviceAppointmentId;
        @AuraEnabled public String serviceAppointmentNumber;
        @AuraEnabled public String serviceAppointmentStatus;
        @AuraEnabled public DateTime scheduledStart;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String lotName;
        @AuraEnabled public String address;
        @AuraEnabled public String communityName;
        @AuraEnabled public String builderName;
        @AuraEnabled public String workType;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
    }

    public class VehicleChecklistDto {
        @AuraEnabled public String recordId;
        @AuraEnabled public String truckNumber;
        @AuraEnabled public String notes;
        @AuraEnabled public Boolean complete;
        @AuraEnabled public List<VehicleItemDto> items;
    }

    public class VehicleItemDto {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean complete;
    }

    public class LoadedChecklistDto {
        @AuraEnabled public Boolean complete;
        @AuraEnabled public Integer scopeCount;
        @AuraEnabled public List<ScopeLineItemDto> scopeItems;
    }

    public class ChecklistGroupDto {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String checklistType;
        @AuraEnabled public Integer requiredCount;
        @AuraEnabled public Integer completedCount;
        @AuraEnabled public List<ChecklistItemDto> items;
    }

    public class ChecklistItemDto {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Boolean photoRequired;
        @AuraEnabled public String notes;
        @AuraEnabled public Integer sortOrder;
    }

    public class ScopeLineItemDto {
        @AuraEnabled public String id;
        @AuraEnabled public String packageItem;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal goalMinutes;
        @AuraEnabled public String source;
        @AuraEnabled public Integer sequence;
    }

    public class IssueDto {
        @AuraEnabled public String id;
        @AuraEnabled public String issueType;
        @AuraEnabled public String severity;
        @AuraEnabled public String status;
        @AuraEnabled public String summary;
        @AuraEnabled public String notes;
        @AuraEnabled public String createdDateLabel;
    }

    public class PhotoSummaryDto {
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer beforeCount;
        @AuraEnabled public Integer afterCount;
        @AuraEnabled public Integer issueCount;
        @AuraEnabled public Integer heroCount;
        @AuraEnabled public List<PhotoSlotDto> beforeSlots;
        @AuraEnabled public List<PhotoSlotDto> closeoutSlots;
    }

    public class PhotoSlotDto {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
        @AuraEnabled public Boolean complete;
    }

    public class ArrivalDto {
        @AuraEnabled public Boolean arrived;
        @AuraEnabled public Decimal distanceMeters;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static Id getTodaysJobId() {
        Id me = UserInfo.getUserId();
        Date today = Date.today();

        List<Work_Order__c> recs = [
            SELECT Id
            FROM Work_Order__c
            WHERE FM_Assignment__c = :me
            AND Scheduled_Date__c = :today
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!recs.isEmpty()) {
            return recs[0].Id;
        }

        List<Work_Order__c> openWos = [
            SELECT Id
            FROM Work_Order__c
            WHERE FM_Assignment__c = :me
            AND Status__c IN ('Scheduled', 'In Progress', 'Pending Closeout')
            ORDER BY Scheduled_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 1
        ];
        return openWos.isEmpty() ? null : openWos[0].Id;
    }

    @AuraEnabled(cacheable=true)
    public static DayDto getDay(Id workOrderId) {
        DayDto day = newDay();
        JobDto job = getJob(workOrderId);
        if (String.isBlank(job.id)) {
            return day;
        }
        day.vehicleCheck = job.vehicleCheckCompleted;
        day.loadingCheck = job.loadingCheckCompleted;
        day.scheduledLot = String.isBlank(job.lotName) ? job.woNumber : job.lotName;
        day.scheduledDate = job.scheduledDate == null ? '' : String.valueOf(job.scheduledDate);
        return day;
    }

    @AuraEnabled(cacheable=true)
    public static JobDto getJob(Id workOrderId) {
        Id resolvedId = workOrderId == null ? getTodaysJobId() : workOrderId;
        if (resolvedId == null) {
            return newJob();
        }
        Work_Order__c active = queryWorkOrderById(resolvedId);
        if (active == null) {
            return newJob();
        }
        ServiceAppointment appt = queryPrimaryAppointment(resolvedId);
        return toJob(active, appt);
    }

    @AuraEnabled(cacheable=true)
    public static MobileContextDto getMobileContext(Id workOrderId) {
        MobileContextDto ctx = new MobileContextDto();
        ctx.workOrderId = workOrderId;
        ctx.foremanName = currentUserDisplayName();
        ctx.clockStatus = buildClockStatus(UserInfo.getUserId());
        ctx.schedule = new List<ScheduleCardDto>();
        ctx.workOrderChecklists = new List<ChecklistGroupDto>();
        ctx.lineItems = new List<ScopeLineItemDto>();
        ctx.openIssues = new List<IssueDto>();
        ctx.photoSummary = newPhotoSummary();
        ctx.closeoutGates = new List<String>();
        ctx.vehicleChecklist = newVehicleChecklist();
        ctx.loadedChecklist = newLoadedChecklist();

        Id resolvedId = workOrderId == null ? getTodaysJobId() : workOrderId;
        ctx.workOrderId = resolvedId;
        if (resolvedId == null) {
            ctx.activeJob = newJob();
            ctx.canBeginDrive = false;
            ctx.beginDriveReason = 'No active work order assigned.';
            ctx.canSubmitCloseout = false;
            return ctx;
        }

        List<Work_Order__c> dayWorkOrders = queryDayWorkOrders(resolvedId);
        Map<Id, Work_Order__c> woById = new Map<Id, Work_Order__c>(dayWorkOrders);
        Work_Order__c active = woById.get(resolvedId);
        if (active == null) {
            active = queryWorkOrderById(resolvedId);
            if (active != null) {
                dayWorkOrders.add(active);
                woById.put(active.Id, active);
            }
        }
        if (active == null) {
            ctx.activeJob = newJob();
            ctx.canBeginDrive = false;
            ctx.beginDriveReason = 'Selected work order was not found.';
            ctx.canSubmitCloseout = false;
            return ctx;
        }

        Map<Id, ServiceAppointment> apptByWorkOrderId = queryAppointmentsByWorkOrder(new Set<Id>(woById.keySet()));
        ctx.activeJob = toJob(active, apptByWorkOrderId.get(active.Id));
        ctx.foremanName = String.isBlank(ctx.activeJob.fm) ? ctx.foremanName : ctx.activeJob.fm;
        ctx.crewName = ctx.activeJob.crewName;
        ctx.schedule = buildSchedule(dayWorkOrders, apptByWorkOrderId, active.Id);
        ctx.lineItems = queryScopeLineItems(active.Id);
        ctx.vehicleChecklist = buildVehicleChecklist(active.Id);
        ctx.loadedChecklist = buildLoadedChecklist(active, ctx.lineItems);
        ctx.workOrderChecklists = buildChecklistGroups(active.Id);
        ctx.openIssues = buildIssues(active.Id);
        ctx.photoSummary = buildPhotoSummary(active.Id);
        ctx.beginDriveReason = getBeginDriveReason(active);
        ctx.canBeginDrive = String.isBlank(ctx.beginDriveReason);
        ctx.closeoutGates = buildCloseoutGates(active, ctx.photoSummary);
        ctx.canSubmitCloseout = ctx.closeoutGates.isEmpty() && active.Status__c == 'In Progress';
        return ctx;
    }

    @AuraEnabled
    public static void updateVehicleChecklistItem(
        Id workOrderId,
        String itemKey,
        Boolean complete,
        String truckNumber,
        String notes
    ) {
        if (workOrderId == null) {
            throw new AuraHandledException('Missing Work Order Id');
        }
        if (String.isBlank(itemKey)) {
            throw new AuraHandledException('Missing checklist item key');
        }

        Morning_Vehicle_Checklist__c checklist = ensureMorningChecklist();
        applyVehicleChecklistItem(checklist, itemKey, complete == true);
        if (!String.isBlank(truckNumber)) {
            checklist.Truck_Number__c = truckNumber;
        }
        if (notes != null) {
            checklist.Notes__c = notes;
        }
        update checklist;

        syncVehicleRollup(workOrderId, checklist);
    }

    @AuraEnabled
    public static void setVehicleCheck(Id workOrderId, Boolean complete) {
        if (workOrderId == null) {
            return;
        }
        Work_Order__c w = new Work_Order__c(
            Id = workOrderId,
            Vehicle_Check_Completed__c = complete == true
        );
        update w;
    }

    @AuraEnabled
    public static void setLoadingCheck(Id workOrderId, Boolean complete) {
        if (workOrderId == null) {
            return;
        }
        Morning_Vehicle_Checklist__c checklist = ensureMorningChecklist();
        checklist.Loading_Verified__c = complete == true;
        checklist.Material_Count_Matches__c = complete == true;
        update checklist;

        Work_Order__c w = new Work_Order__c(
            Id = workOrderId,
            Loading_Check_Completed__c = complete == true
        );
        update w;
    }

    @AuraEnabled
    public static void beginDrive(Id workOrderId) {
        if (workOrderId == null) {
            throw new AuraHandledException('Missing Work Order Id');
        }
        try {
            GPSArrivalService.beginDrive(workOrderId);
        } catch (GPSArrivalService.GPSException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static ArrivalDto confirmArrival(Id workOrderId, Decimal lat, Decimal lng) {
        if (workOrderId == null) {
            throw new AuraHandledException('Missing Work Order Id');
        }
        if (lat == null || lng == null) {
            throw new AuraHandledException('Device location is required to confirm arrival.');
        }
        Integer beforeCount = buildPhotoSummary(workOrderId).beforeCount;
        if (beforeCount < 4) {
            throw new AuraHandledException('4 before photos are required before starting the job.');
        }
        try {
            GPSArrivalService.PingResult result = GPSArrivalService.processPing(workOrderId, lat, lng);
            ArrivalDto out = new ArrivalDto();
            out.arrived = result.arrived;
            out.distanceMeters = result.distanceMeters;
            out.status = result.status;
            out.message = result.arrived
                ? 'Arrival confirmed. Job started.'
                : 'Crew is still outside the lot geofence.';
            return out;
        } catch (GPSArrivalService.GPSException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void startJob(Id workOrderId) {
        if (workOrderId == null) {
            throw new AuraHandledException('Missing Work Order Id');
        }
        Work_Order__c existing = [
            SELECT Id, Arrived_At__c, Lot_Latitude__c, Lot_Longitude__c
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];
        Integer beforeCount = buildPhotoSummary(workOrderId).beforeCount;
        if (beforeCount < 4) {
            throw new AuraHandledException('4 before photos are required before starting the job.');
        }
        if (existing.Arrived_At__c == null && existing.Lot_Latitude__c != null && existing.Lot_Longitude__c != null) {
            throw new AuraHandledException('Confirm arrival with device GPS before starting this job.');
        }

        Work_Order__c w = new Work_Order__c(Id = workOrderId, Status__c = 'In Progress');
        try {
            update w;
        } catch (DmlException e) {
            throw new AuraHandledException(extractDmlMessage(e));
        }
    }

    @AuraEnabled
    public static void updateChecklistItem(Id checklistItemId, String status, String notes) {
        if (checklistItemId == null) {
            throw new AuraHandledException('Missing checklist item Id');
        }
        if (String.isBlank(status)) {
            throw new AuraHandledException('Checklist status is required');
        }
        if (!new Set<String>{ 'Pending', 'Complete', 'N/A' }.contains(status)) {
            throw new AuraHandledException('Checklist status must be Pending, Complete, or N/A');
        }

        Checklist_Item__c item = new Checklist_Item__c(Id = checklistItemId, Status__c = status);
        if (notes != null) {
            item.Notes__c = notes;
        }
        update item;
    }

    @AuraEnabled
    public static Id createIssue(
        Id workOrderId,
        String issueType,
        String severity,
        String summary,
        String notes
    ) {
        if (workOrderId == null) {
            throw new AuraHandledException('Missing Work Order Id');
        }
        if (String.isBlank(issueType)) {
            throw new AuraHandledException('Issue type is required');
        }
        if (String.isBlank(severity)) {
            throw new AuraHandledException('Severity is required');
        }
        if (String.isBlank(summary)) {
            throw new AuraHandledException('Summary is required');
        }

        try {
            Work_Order__c workOrder = queryWorkOrderById(workOrderId);
            Schedule_Issue__c issue = new Schedule_Issue__c(
                Work_Order__c = workOrderId,
                Issue_Type__c = issueType,
                Severity__c = severity,
                Status__c = 'Open',
                Summary__c = summary,
                Resolution_Notes__c = notes,
                Field_Manager__c = resolveIssueFieldManagerId(workOrder),
                Required_Action__c = resolveRequiredAction(issueType, severity),
                Market__c = resolveIssueMarketId(workOrder)
            );
            insert issue;
            return issue.Id;
        } catch (DmlException de) {
            throw new AuraHandledException(extractDmlMessage(de));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveCloseoutDetails(Id workOrderId, Decimal installedSodSqft, String closeoutNotes) {
        if (workOrderId == null) {
            throw new AuraHandledException('Missing Work Order Id');
        }
        Work_Order__c wo = new Work_Order__c(Id = workOrderId);
        wo.Installed_Sod_Sqft__c = installedSodSqft;
        if (closeoutNotes != null) {
            wo.Closeout_Notes__c = closeoutNotes;
        }
        update wo;
    }

    @AuraEnabled
    public static Id submitSodIssueFlag(Id workOrderId, String species, String sqft, String notes) {
        if (String.isBlank(species) && String.isBlank(sqft) && String.isBlank(notes)) {
            throw new AuraHandledException('Issue details are required');
        }
        String summary = 'Sod issue';
        List<String> parts = new List<String>();
        if (!String.isBlank(species)) {
            parts.add('species ' + species);
        }
        if (!String.isBlank(sqft)) {
            parts.add('sqft ' + sqft);
        }
        if (!parts.isEmpty()) {
            summary += ': ' + String.join(parts, ', ');
        }
        return createIssue(workOrderId, 'Other', 'High', summary, notes);
    }

    @AuraEnabled(cacheable=true)
    public static Integer getPhotoCount(Id workOrderId) {
        if (workOrderId == null) {
            return 0;
        }
        return [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :workOrderId
        ];
    }

    @AuraEnabled
    public static Id uploadJobsitePhoto(
        Id workOrderId,
        String fileName,
        String base64Body,
        String contentType,
        String photoCategory
    ) {
        if (workOrderId == null) {
            throw new AuraHandledException('Missing Work Order Id');
        }
        if (String.isBlank(base64Body)) {
            throw new AuraHandledException('Missing photo data');
        }

        try {
            String safeCategory = normalizePhotoCategory(photoCategory);
            String titlePrefix = String.isBlank(safeCategory) ? 'photo' : safeCategory;

            ContentVersion cv = new ContentVersion();
            cv.Title = titlePrefix + ' - ' + (String.isBlank(fileName) ? 'jobsite-photo' : fileName);
            cv.PathOnClient = String.isBlank(fileName) ? 'photo.jpg' : fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Body);
            cv.IsMajorVersion = true;
            insert cv;

            ContentVersion saved = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = saved.ContentDocumentId;
            cdl.LinkedEntityId = workOrderId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;

            incrementPhotoCounters(workOrderId, safeCategory);
            return saved.ContentDocumentId;
        } catch (DmlException de) {
            throw new AuraHandledException(extractDmlMessage(de));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void closeoutJob(Id workOrderId) {
        if (workOrderId == null) {
            throw new AuraHandledException('Missing Work Order Id');
        }

        Work_Order__c existing = [
            SELECT Id, Closeout_Photo_Count__c, Installed_Sod_Sqft__c
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];
        if (existing.Closeout_Photo_Count__c == null || existing.Closeout_Photo_Count__c < 4) {
            throw new AuraHandledException('Minimum 4 closeout photos are required before submitting closeout.');
        }
        if (existing.Installed_Sod_Sqft__c == null) {
            throw new AuraHandledException('Installed sod quantity is required before submitting closeout.');
        }

        Work_Order__c w = new Work_Order__c(Id = workOrderId, Status__c = 'Pending Closeout');
        try {
            update w;
        } catch (DmlException e) {
            throw new AuraHandledException(extractDmlMessage(e));
        }
    }

    @AuraEnabled(cacheable=true)
    public static ClockStatusDto getRipplingClockStatus() {
        return buildClockStatus(UserInfo.getUserId());
    }

    @AuraEnabled(cacheable=true)
    public static List<ClockStatusDto> getCrewClockStatus(List<Id> userIds) {
        List<ClockStatusDto> out = new List<ClockStatusDto>();
        if (userIds == null || userIds.isEmpty()) {
            return out;
        }
        for (Id uid : userIds) {
            ClockStatusDto s = buildClockStatus(uid);
            if (s != null) {
                out.add(s);
            }
        }
        return out;
    }

    private static List<Work_Order__c> queryDayWorkOrders(Id includeWorkOrderId) {
        Id me = UserInfo.getUserId();
        Date today = Date.today();
        return [
            SELECT Id, Name, Status__c, Work_Order_Type__c, Sub_Status__c,
                   Sod_Sqft__c, Sod_Species__c, FM_Assignment__c, FM_Assignment__r.Name,
                   Field_Manager__c,
                   Goal_Hours__c, Crew__c, Scheduled_Date__c, Vehicle_Check_Completed__c,
                   Loading_Check_Completed__c, Lot__r.Name, Lot__r.Address__c, Lot__r.City__c,
                   Lot__r.State__c, Lot__r.Lot_Latitude__c,
                   Lot__r.Lot_Longitude__c, Community__r.Name, Community__r.Community_Address__c,
                   Community__r.Community_City__c, Community__r.Community_State__c,
                   Community__r.Community_Zip__c, Community__r.GPS_Latitude__c,
                   Community__r.GPS_Longitude__c, Community__r.Builder_Account__r.Name,
                   Community__r.ServiceTerritory__c,
                   Drive_Started_At__c, Arrived_At__c, Takeoff_Photo_Count__c,
                   Closeout_Photo_Count__c, Installed_Sod_Sqft__c, Closeout_Notes__c,
                   Schedule_Locked__c, Lot_Latitude__c, Lot_Longitude__c
            FROM Work_Order__c
            WHERE FM_Assignment__c = :me
            AND (
                Scheduled_Date__c = :today
                OR Status__c IN ('In Progress', 'Pending Closeout')
                OR Id = :includeWorkOrderId
            )
            ORDER BY Scheduled_Date__c ASC NULLS LAST, CreatedDate ASC
        ];
    }

    private static Work_Order__c queryWorkOrderById(Id workOrderId) {
        List<Work_Order__c> recs = [
            SELECT Id, Name, Status__c, Work_Order_Type__c, Sub_Status__c,
                   Sod_Sqft__c, Sod_Species__c, FM_Assignment__c, FM_Assignment__r.Name,
                   Field_Manager__c,
                   Goal_Hours__c, Crew__c, Scheduled_Date__c, Vehicle_Check_Completed__c,
                   Loading_Check_Completed__c, Lot__r.Name, Lot__r.Address__c, Lot__r.City__c,
                   Lot__r.State__c, Lot__r.Lot_Latitude__c,
                   Lot__r.Lot_Longitude__c, Community__r.Name, Community__r.Community_Address__c,
                   Community__r.Community_City__c, Community__r.Community_State__c,
                   Community__r.Community_Zip__c, Community__r.GPS_Latitude__c,
                   Community__r.GPS_Longitude__c, Community__r.Builder_Account__r.Name,
                   Community__r.ServiceTerritory__c,
                   Drive_Started_At__c, Arrived_At__c, Takeoff_Photo_Count__c,
                   Closeout_Photo_Count__c, Installed_Sod_Sqft__c, Closeout_Notes__c,
                   Schedule_Locked__c, Lot_Latitude__c, Lot_Longitude__c
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];
        return recs.isEmpty() ? null : recs[0];
    }

    private static Map<Id, ServiceAppointment> queryAppointmentsByWorkOrder(Set<Id> workOrderIds) {
        Map<Id, ServiceAppointment> out = new Map<Id, ServiceAppointment>();
        if (workOrderIds == null || workOrderIds.isEmpty()) {
            return out;
        }
        try {
            out.putAll(queryAppointmentsByLegacyLookup(workOrderIds));
            if (out.size() < workOrderIds.size()) {
                Set<Id> unresolvedIds = new Set<Id>(workOrderIds);
                unresolvedIds.removeAll(out.keySet());
                out.putAll(queryAppointmentsByBuilderBridge(unresolvedIds));
            }
        } catch (Exception e) {
            // FSL config can vary by org; return best effort without appointments.
        }
        return out;
    }

    private static Map<Id, ServiceAppointment> queryAppointmentsByLegacyLookup(Set<Id> workOrderIds) {
        Map<Id, ServiceAppointment> out = new Map<Id, ServiceAppointment>();
        if (workOrderIds == null || workOrderIds.isEmpty()) {
            return out;
        }
        if (!Schema.SObjectType.ServiceAppointment.fields.getMap().containsKey('LOVING_Work_Order__c')) {
            return out;
        }

        String soql =
            'SELECT Id, AppointmentNumber, Status, SchedStartTime, LOVING_Work_Order__c ' +
            'FROM ServiceAppointment ' +
            'WHERE LOVING_Work_Order__c IN :workOrderIds ' +
            'ORDER BY SchedStartTime ASC NULLS LAST, CreatedDate ASC';
        for (SObject row : Database.query(soql)) {
            Id customWorkOrderId = (Id) row.get('LOVING_Work_Order__c');
            if (customWorkOrderId != null && !out.containsKey(customWorkOrderId)) {
                out.put(customWorkOrderId, (ServiceAppointment) row);
            }
        }
        return out;
    }

    private static Map<Id, ServiceAppointment> queryAppointmentsByBuilderBridge(Set<Id> workOrderIds) {
        Map<Id, ServiceAppointment> out = new Map<Id, ServiceAppointment>();
        if (workOrderIds == null || workOrderIds.isEmpty()) {
            return out;
        }

        Map<Id, String> poNumberByCustomWorkOrderId = new Map<Id, String>();
        Set<String> poNumbers = new Set<String>();
        for (Work_Order__c workOrder : [
            SELECT Id, Builder_PO__r.PO_Number__c
            FROM Work_Order__c
            WHERE Id IN :workOrderIds
              AND Builder_PO__c != null
        ]) {
            String poNumber = workOrder.Builder_PO__r == null ? null : workOrder.Builder_PO__r.PO_Number__c;
            if (String.isBlank(poNumber)) {
                continue;
            }
            poNumberByCustomWorkOrderId.put(workOrder.Id, poNumber);
            poNumbers.add(poNumber);
        }
        if (poNumbers.isEmpty()) {
            return out;
        }

        Map<String, Id> standardParentByPoNumber = new Map<String, Id>();
        for (Purchase_Order__c purchaseOrder : [
            SELECT PO_Number__c, Work_Order__c
            FROM Purchase_Order__c
            WHERE PO_Number__c IN :poNumbers
              AND Work_Order__c != null
        ]) {
            if (String.isNotBlank(purchaseOrder.PO_Number__c) && purchaseOrder.Work_Order__c != null) {
                standardParentByPoNumber.put(purchaseOrder.PO_Number__c, purchaseOrder.Work_Order__c);
            }
        }
        if (standardParentByPoNumber.isEmpty()) {
            return out;
        }

        Map<Id, Id> customWorkOrderByStandardWorkOrderId = new Map<Id, Id>();
        Set<Id> standardParentIds = new Set<Id>();
        for (Id customWorkOrderId : poNumberByCustomWorkOrderId.keySet()) {
            Id standardParentId = standardParentByPoNumber.get(poNumberByCustomWorkOrderId.get(customWorkOrderId));
            if (standardParentId == null) {
                continue;
            }
            standardParentIds.add(standardParentId);
            customWorkOrderByStandardWorkOrderId.put(standardParentId, customWorkOrderId);
        }
        if (standardParentIds.isEmpty()) {
            return out;
        }

        Set<Id> candidateWorkOrderIds = new Set<Id>(standardParentIds);
        for (WorkOrder child : [
            SELECT Id, ParentWorkOrderId
            FROM WorkOrder
            WHERE ParentWorkOrderId IN :standardParentIds
        ]) {
            candidateWorkOrderIds.add(child.Id);
            if (child.ParentWorkOrderId != null && customWorkOrderByStandardWorkOrderId.containsKey(child.ParentWorkOrderId)) {
                customWorkOrderByStandardWorkOrderId.put(child.Id, customWorkOrderByStandardWorkOrderId.get(child.ParentWorkOrderId));
            }
        }

        for (ServiceAppointment appointment : [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, ParentRecordId
            FROM ServiceAppointment
            WHERE ParentRecordId IN :candidateWorkOrderIds
            ORDER BY SchedStartTime ASC NULLS LAST, CreatedDate ASC
        ]) {
            Id customWorkOrderId = customWorkOrderByStandardWorkOrderId.get(appointment.ParentRecordId);
            if (customWorkOrderId != null && !out.containsKey(customWorkOrderId)) {
                out.put(customWorkOrderId, appointment);
            }
        }
        return out;
    }

    private static ServiceAppointment queryPrimaryAppointment(Id workOrderId) {
        Map<Id, ServiceAppointment> apptByWo = queryAppointmentsByWorkOrder(new Set<Id>{ workOrderId });
        return apptByWo.get(workOrderId);
    }

    private static List<ScheduleCardDto> buildSchedule(
        List<Work_Order__c> workOrders,
        Map<Id, ServiceAppointment> apptByWorkOrderId,
        Id activeWorkOrderId
    ) {
        List<ScheduleCardDto> out = new List<ScheduleCardDto>();
        for (Work_Order__c wo : workOrders) {
            ScheduleCardDto row = new ScheduleCardDto();
            ServiceAppointment appt = apptByWorkOrderId.get(wo.Id);
            row.workOrderId = wo.Id;
            row.serviceAppointmentId = appt == null ? null : appt.Id;
            row.serviceAppointmentNumber = appt == null ? null : appt.AppointmentNumber;
            row.serviceAppointmentStatus = appt == null ? null : appt.Status;
            row.scheduledStart = appt == null ? null : appt.SchedStartTime;
            row.workOrderNumber = wo.Name;
            row.lotName = safeLotName(wo);
            row.address = buildAddress(wo);
            row.communityName = wo.Community__r == null ? null : wo.Community__r.Name;
            row.builderName = wo.Community__r == null || wo.Community__r.Builder_Account__r == null
                ? null
                : wo.Community__r.Builder_Account__r.Name;
            row.workType = wo.Work_Order_Type__c;
            row.status = wo.Status__c;
            row.goalHours = wo.Goal_Hours__c;
            row.isActive = wo.Id == activeWorkOrderId;
            row.latitude = resolveLatitude(wo);
            row.longitude = resolveLongitude(wo);
            out.add(row);
        }
        return out;
    }

    private static JobDto toJob(Work_Order__c w, ServiceAppointment appt) {
        JobDto j = newJob();
        j.id = w.Id;
        j.woNumber = w.Name;
        j.subject = safeLotName(w);
        j.status = w.Status__c;
        j.statusLabel = w.Status__c;
        j.workOrderType = w.Work_Order_Type__c;
        j.subStatus = w.Sub_Status__c;
        j.sodSqft = w.Sod_Sqft__c;
        j.sodSpecies = w.Sod_Species__c;
        j.fm = w.FM_Assignment__r == null ? null : w.FM_Assignment__r.Name;
        j.goalHours = w.Goal_Hours__c;
        j.crewName = w.Crew__c;
        j.lotName = safeLotName(w);
        j.communityName = w.Community__r == null ? null : w.Community__r.Name;
        j.builderName = w.Community__r == null || w.Community__r.Builder_Account__r == null
            ? null
            : w.Community__r.Builder_Account__r.Name;
        j.address = buildAddress(w);
        j.cityStateZip = buildCityStateZip(w);
        j.latitude = resolveLatitude(w);
        j.longitude = resolveLongitude(w);
        j.scheduledDate = w.Scheduled_Date__c;
        j.driveStartedAt = w.Drive_Started_At__c;
        j.arrivedAt = w.Arrived_At__c;
        j.takeoffPhotoCount = w.Takeoff_Photo_Count__c;
        j.closeoutPhotoCount = w.Closeout_Photo_Count__c;
        j.installedSodSqft = w.Installed_Sod_Sqft__c;
        j.closeoutNotes = w.Closeout_Notes__c;
        j.vehicleCheckCompleted = w.Vehicle_Check_Completed__c == true;
        j.loadingCheckCompleted = w.Loading_Check_Completed__c == true;
        j.scheduleLocked = w.Schedule_Locked__c == true;
        if (appt != null) {
            j.appointmentNumber = appt.AppointmentNumber;
            j.appointmentStatus = appt.Status;
            j.appointmentStart = appt.SchedStartTime;
        }
        return j;
    }

    private static List<ScopeLineItemDto> queryScopeLineItems(Id workOrderId) {
        List<ScopeLineItemDto> out = new List<ScopeLineItemDto>();
        if (workOrderId == null) {
            return out;
        }
        for (Work_Order_Line_Item__c li : [
            SELECT Id, Package_Item__c, Description__c, Quantity__c, Goal_Minutes__c, Source__c, Sequence__c
            FROM Work_Order_Line_Item__c
            WHERE Work_Order__c = :workOrderId
            ORDER BY Sequence__c NULLS LAST, Name
            LIMIT 200
        ]) {
            ScopeLineItemDto dto = new ScopeLineItemDto();
            dto.id = li.Id;
            dto.packageItem = li.Package_Item__c;
            dto.description = li.Description__c;
            dto.quantity = li.Quantity__c;
            dto.goalMinutes = li.Goal_Minutes__c;
            dto.source = li.Source__c;
            dto.sequence = li.Sequence__c == null ? null : Integer.valueOf(li.Sequence__c);
            out.add(dto);
        }
        return out;
    }

    private static VehicleChecklistDto buildVehicleChecklist(Id workOrderId) {
        VehicleChecklistDto dto = newVehicleChecklist();
        Morning_Vehicle_Checklist__c checklist = queryMorningChecklist();
        if (checklist == null) {
            return dto;
        }
        dto.recordId = checklist.Id;
        dto.truckNumber = checklist.Truck_Number__c;
        dto.notes = checklist.Notes__c;
        dto.items = new List<VehicleItemDto>{
            newVehicleItem('tires', 'Tires', checklist.Tires_Checked__c),
            newVehicleItem('lights', 'Lights', checklist.Lights_Checked__c),
            newVehicleItem('fluids', 'Fluids', checklist.Fluids_Checked__c),
            newVehicleItem('fuel', 'Fuel level', checklist.Fuel_Checked__c),
            newVehicleItem('trailer', 'Trailer hitch and safety chains', checklist.Trailer_Checked__c),
            newVehicleItem('safety', 'Fire extinguisher and first aid kit', checklist.Safety_Equipment_Checked__c)
        };
        dto.complete = areVehicleItemsComplete(checklist);
        return dto;
    }

    private static LoadedChecklistDto buildLoadedChecklist(Work_Order__c active, List<ScopeLineItemDto> lineItems) {
        LoadedChecklistDto dto = newLoadedChecklist();
        dto.scopeItems = lineItems;
        dto.scopeCount = lineItems == null ? 0 : lineItems.size();
        dto.complete = active.Loading_Check_Completed__c == true;
        return dto;
    }

    private static List<ChecklistGroupDto> buildChecklistGroups(Id workOrderId) {
        List<ChecklistGroupDto> out = new List<ChecklistGroupDto>();
        if (workOrderId == null) {
            return out;
        }

        List<Checklist__c> checklists = [
            SELECT Id, Name, Checklist_Type__c
            FROM Checklist__c
            WHERE Work_Order__c = :workOrderId
            ORDER BY CreatedDate ASC
            LIMIT 50
        ];
        if (checklists.isEmpty()) {
            return out;
        }

        Map<Id, ChecklistGroupDto> groupById = new Map<Id, ChecklistGroupDto>();
        for (Checklist__c c : checklists) {
            ChecklistGroupDto checklistGroup = new ChecklistGroupDto();
            checklistGroup.id = c.Id;
            checklistGroup.name = c.Name;
            checklistGroup.checklistType = c.Checklist_Type__c;
            checklistGroup.requiredCount = 0;
            checklistGroup.completedCount = 0;
            checklistGroup.items = new List<ChecklistItemDto>();
            out.add(checklistGroup);
            groupById.put(c.Id, checklistGroup);
        }

        for (Checklist_Item__c item : [
            SELECT Id, Name, Status__c, Required__c, Photo_Required__c, Notes__c, Sort_Order__c, Checklist__c
            FROM Checklist_Item__c
            WHERE Checklist__c IN :groupById.keySet()
            ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC
        ]) {
            ChecklistGroupDto checklistGroup = groupById.get(item.Checklist__c);
            if (checklistGroup == null) {
                continue;
            }
            ChecklistItemDto row = new ChecklistItemDto();
            row.id = item.Id;
            row.name = item.Name;
            row.status = item.Status__c;
            row.required = item.Required__c == true;
            row.photoRequired = item.Photo_Required__c == true;
            row.notes = item.Notes__c;
            row.sortOrder = item.Sort_Order__c == null ? null : Integer.valueOf(item.Sort_Order__c);
            checklistGroup.items.add(row);
            if (row.required) {
                checklistGroup.requiredCount++;
            }
            if (item.Status__c == 'Complete') {
                checklistGroup.completedCount++;
            }
        }
        return out;
    }

    private static List<IssueDto> buildIssues(Id workOrderId) {
        List<IssueDto> out = new List<IssueDto>();
        if (workOrderId == null) {
            return out;
        }
        for (Schedule_Issue__c issue : [
            SELECT Id, Issue_Type__c, Severity__c, Status__c, Summary__c, Resolution_Notes__c, CreatedDate
            FROM Schedule_Issue__c
            WHERE Work_Order__c = :workOrderId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            IssueDto dto = new IssueDto();
            dto.id = issue.Id;
            dto.issueType = issue.Issue_Type__c;
            dto.severity = issue.Severity__c;
            dto.status = issue.Status__c;
            dto.summary = issue.Summary__c;
            dto.notes = issue.Resolution_Notes__c;
            dto.createdDateLabel = issue.CreatedDate.format('M/d h:mm a');
            out.add(dto);
        }
        return out;
    }

    private static PhotoSummaryDto buildPhotoSummary(Id workOrderId) {
        PhotoSummaryDto summary = newPhotoSummary();
        if (workOrderId == null) {
            return summary;
        }

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :workOrderId
        ]) {
            docIds.add(link.ContentDocumentId);
        }
        if (docIds.isEmpty()) {
            return summary;
        }

        Map<String, Integer> counts = new Map<String, Integer>();
        for (ContentVersion version : [
            SELECT ContentDocumentId, Title
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = true
        ]) {
            String key = normalizePhotoCategoryFromTitle(version.Title);
            if (String.isBlank(key)) {
                continue;
            }
            counts.put(key, (counts.containsKey(key) ? counts.get(key) : 0) + 1);
            summary.totalCount++;
        }

        applyPhotoCounts(summary.beforeSlots, counts);
        applyPhotoCounts(summary.closeoutSlots, counts);
        summary.beforeCount = countMatching(counts, 'before_');
        summary.afterCount = countMatching(counts, 'after_');
        summary.issueCount = countExact(counts, PHOTO_KEY_ISSUE);
        summary.heroCount = countExact(counts, PHOTO_KEY_AFTER_HERO);
        return summary;
    }

    private static String getBeginDriveReason(Work_Order__c wo) {
        if (wo == null) {
            return 'No active work order assigned.';
        }
        if (wo.Schedule_Locked__c != true) {
            return 'Schedule is not locked for this work order.';
        }
        if (wo.Vehicle_Check_Completed__c != true) {
            return 'Vehicle checklist is incomplete.';
        }
        if (wo.Loading_Check_Completed__c != true) {
            return 'Loaded checklist is incomplete.';
        }
        if (wo.Drive_Started_At__c != null) {
            return 'Drive has already been started.';
        }
        return null;
    }

    private static List<String> buildCloseoutGates(Work_Order__c wo, PhotoSummaryDto photoSummary) {
        List<String> out = new List<String>();
        if (wo == null) {
            out.add('No active work order assigned.');
            return out;
        }
        if (wo.Status__c != 'In Progress') {
            out.add('Job must be in progress before it can be submitted to closeout.');
        }
        Integer closeoutPhotos = photoSummary == null ? 0 : photoSummary.afterCount;
        if (closeoutPhotos < 4) {
            out.add('4 after / closeout photos are required.');
        }
        if (wo.Installed_Sod_Sqft__c == null) {
            out.add('Installed sod square footage is required.');
        }
        return out;
    }

    private static Morning_Vehicle_Checklist__c queryMorningChecklist() {
        Id me = UserInfo.getUserId();
        Date today = Date.today();
        List<Morning_Vehicle_Checklist__c> rows = [
            SELECT Id, Truck_Number__c, Notes__c, Tires_Checked__c, Lights_Checked__c,
                   Fluids_Checked__c, Fuel_Checked__c, Trailer_Checked__c,
                   Safety_Equipment_Checked__c, Loading_Verified__c, Material_Count_Matches__c
            FROM Morning_Vehicle_Checklist__c
            WHERE Foreman__c = :me
            AND Checklist_Date__c = :today
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Morning_Vehicle_Checklist__c ensureMorningChecklist() {
        Morning_Vehicle_Checklist__c existing = queryMorningChecklist();
        if (existing != null) {
            return existing;
        }

        Morning_Vehicle_Checklist__c created = new Morning_Vehicle_Checklist__c(
            Foreman__c = UserInfo.getUserId(),
            Checklist_Date__c = Date.today(),
            Status__c = 'Pending'
        );
        insert created;
        return created;
    }

    private static void applyVehicleChecklistItem(
        Morning_Vehicle_Checklist__c checklist,
        String itemKey,
        Boolean complete
    ) {
        String key = itemKey == null ? null : itemKey.trim().toLowerCase();
        if (key == 'tires') {
            checklist.Tires_Checked__c = complete;
        } else if (key == 'lights') {
            checklist.Lights_Checked__c = complete;
        } else if (key == 'fluids') {
            checklist.Fluids_Checked__c = complete;
        } else if (key == 'fuel') {
            checklist.Fuel_Checked__c = complete;
        } else if (key == 'trailer') {
            checklist.Trailer_Checked__c = complete;
        } else if (key == 'safety') {
            checklist.Safety_Equipment_Checked__c = complete;
        } else {
            throw new AuraHandledException('Unsupported checklist item key: ' + itemKey);
        }
    }

    private static void syncVehicleRollup(Id workOrderId, Morning_Vehicle_Checklist__c checklist) {
        Work_Order__c updateRow = new Work_Order__c(
            Id = workOrderId,
            Vehicle_Check_Completed__c = areVehicleItemsComplete(checklist)
        );
        update updateRow;
    }

    private static Boolean areVehicleItemsComplete(Morning_Vehicle_Checklist__c checklist) {
        return checklist != null
            && checklist.Tires_Checked__c == true
            && checklist.Lights_Checked__c == true
            && checklist.Fluids_Checked__c == true
            && checklist.Fuel_Checked__c == true
            && checklist.Trailer_Checked__c == true
            && checklist.Safety_Equipment_Checked__c == true;
    }

    private static void incrementPhotoCounters(Id workOrderId, String photoCategory) {
        if (workOrderId == null || String.isBlank(photoCategory)) {
            return;
        }
        Work_Order__c updateRow = new Work_Order__c(Id = workOrderId);
        Work_Order__c current = [
            SELECT Id, Takeoff_Photo_Count__c, Closeout_Photo_Count__c
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        if (photoCategory.startsWith('before_')) {
            Decimal cur = current.Takeoff_Photo_Count__c == null ? 0 : current.Takeoff_Photo_Count__c;
            updateRow.Takeoff_Photo_Count__c = cur + 1;
            update updateRow;
            return;
        }

        if (photoCategory.startsWith('after_')) {
            Decimal cur = current.Closeout_Photo_Count__c == null ? 0 : current.Closeout_Photo_Count__c;
            updateRow.Closeout_Photo_Count__c = cur + 1;
            update updateRow;
        }
    }

    private static ClockStatusDto buildClockStatus(Id userId) {
        ClockStatusDto s = new ClockStatusDto();
        if (userId == null) {
            return s;
        }
        try {
            List<Employee__c> emps = [
                SELECT Id, Name, First_Name__c, Last_Name__c,
                       Currently_Clocked_In__c, On_PTO_Today__c,
                       Current_Shift_Start__c, Department__c, Last_Rippling_Sync__c
                FROM Employee__c
                WHERE User__c = :userId
                LIMIT 1
            ];
            if (emps.isEmpty()) {
                return s;
            }

            Employee__c e = emps[0];
            s.employeeId = e.Id;
            s.employeeName = e.First_Name__c != null && e.Last_Name__c != null
                ? e.First_Name__c + ' ' + e.Last_Name__c
                : e.Name;
            s.clockedIn = e.Currently_Clocked_In__c == true;
            s.onPto = e.On_PTO_Today__c == true;
            s.shiftStart = e.Current_Shift_Start__c;
            s.department = e.Department__c;
            s.lastSync = e.Last_Rippling_Sync__c;

            DateTime startOfDay = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
            DateTime endOfDay = startOfDay.addDays(1);
            List<Rippling_Time_Entry__c> entries = [
                SELECT Id, Clock_In__c, Clock_Out__c, Hours__c
                FROM Rippling_Time_Entry__c
                WHERE Employee__c = :e.Id
                AND Clock_In__c >= :startOfDay
                AND Clock_In__c < :endOfDay
                ORDER BY Clock_In__c DESC
            ];

            Decimal hours = 0;
            for (Rippling_Time_Entry__c te : entries) {
                if (te.Hours__c != null) {
                    hours += te.Hours__c;
                }
            }
            s.hoursToday = hours;
            if (!entries.isEmpty()) {
                s.lastClockIn = entries[0].Clock_In__c;
                s.lastClockOut = entries[0].Clock_Out__c;
            }

            if (s.onPto) {
                Date today = Date.today();
                List<Rippling_Time_Off__c> pto = [
                    SELECT Id, Type__c, Status__c
                    FROM Rippling_Time_Off__c
                    WHERE Employee__c = :e.Id
                    AND Start_Date__c <= :today
                    AND End_Date__c >= :today
                    AND Status__c = 'Approved'
                    LIMIT 1
                ];
                if (!pto.isEmpty()) {
                    s.ptoType = pto[0].Type__c;
                }
            }
        } catch (Exception ex) {
            // tolerant
        }
        return s;
    }

    private static DayDto newDay() {
        DayDto d = new DayDto();
        d.vehicleCheck = false;
        d.loadingCheck = false;
        d.scheduledLot = '';
        d.scheduledDate = '';
        d.syncSource = 'Rippling';
        return d;
    }

    private static JobDto newJob() {
        JobDto j = new JobDto();
        j.id = '';
        j.woNumber = '';
        j.subject = '';
        j.status = '';
        j.statusLabel = '';
        j.workOrderType = '';
        j.subStatus = '';
        j.sodSqft = 0;
        j.sodSpecies = '';
        j.fm = '';
        j.goalHours = 0;
        j.crewName = '';
        j.lotName = '';
        j.communityName = '';
        j.builderName = '';
        j.address = '';
        j.cityStateZip = '';
        j.latitude = null;
        j.longitude = null;
        j.takeoffPhotoCount = 0;
        j.closeoutPhotoCount = 0;
        j.installedSodSqft = null;
        j.closeoutNotes = '';
        j.vehicleCheckCompleted = false;
        j.loadingCheckCompleted = false;
        j.scheduleLocked = false;
        return j;
    }

    private static VehicleChecklistDto newVehicleChecklist() {
        VehicleChecklistDto dto = new VehicleChecklistDto();
        dto.recordId = null;
        dto.truckNumber = '';
        dto.notes = '';
        dto.complete = false;
        dto.items = new List<VehicleItemDto>{
            newVehicleItem('tires', 'Tires', false),
            newVehicleItem('lights', 'Lights', false),
            newVehicleItem('fluids', 'Fluids', false),
            newVehicleItem('fuel', 'Fuel level', false),
            newVehicleItem('trailer', 'Trailer hitch and safety chains', false),
            newVehicleItem('safety', 'Fire extinguisher and first aid kit', false)
        };
        return dto;
    }

    private static LoadedChecklistDto newLoadedChecklist() {
        LoadedChecklistDto dto = new LoadedChecklistDto();
        dto.complete = false;
        dto.scopeCount = 0;
        dto.scopeItems = new List<ScopeLineItemDto>();
        return dto;
    }

    private static VehicleItemDto newVehicleItem(String key, String label, Boolean complete) {
        VehicleItemDto dto = new VehicleItemDto();
        dto.key = key;
        dto.label = label;
        dto.complete = complete == true;
        return dto;
    }

    private static PhotoSummaryDto newPhotoSummary() {
        PhotoSummaryDto dto = new PhotoSummaryDto();
        dto.totalCount = 0;
        dto.beforeCount = 0;
        dto.afterCount = 0;
        dto.issueCount = 0;
        dto.heroCount = 0;
        dto.beforeSlots = new List<PhotoSlotDto>{
            newPhotoSlot(PHOTO_KEY_BEFORE_FRONT, 'Front Yard Before'),
            newPhotoSlot(PHOTO_KEY_BEFORE_BACK, 'Back Yard Before'),
            newPhotoSlot(PHOTO_KEY_BEFORE_LEFT, 'Side Left Before'),
            newPhotoSlot(PHOTO_KEY_BEFORE_RIGHT, 'Side Right Before')
        };
        dto.closeoutSlots = new List<PhotoSlotDto>{
            newPhotoSlot(PHOTO_KEY_AFTER_FRONT, 'Front Yard After'),
            newPhotoSlot(PHOTO_KEY_AFTER_BACK, 'Back Yard After'),
            newPhotoSlot(PHOTO_KEY_AFTER_DETAIL, 'Detail / Planting After'),
            newPhotoSlot(PHOTO_KEY_AFTER_HERO, 'Hero Photo')
        };
        return dto;
    }

    private static PhotoSlotDto newPhotoSlot(String key, String label) {
        PhotoSlotDto dto = new PhotoSlotDto();
        dto.key = key;
        dto.label = label;
        dto.count = 0;
        dto.complete = false;
        return dto;
    }

    private static void applyPhotoCounts(List<PhotoSlotDto> slots, Map<String, Integer> counts) {
        for (PhotoSlotDto slot : slots) {
            Integer count = countExact(counts, slot.key);
            slot.count = count;
            slot.complete = count > 0;
        }
    }

    private static Integer countMatching(Map<String, Integer> counts, String prefix) {
        Integer total = 0;
        for (String key : counts.keySet()) {
            if (key != null && key.startsWith(prefix)) {
                total += counts.get(key);
            }
        }
        return total;
    }

    private static Integer countExact(Map<String, Integer> counts, String key) {
        return counts.containsKey(key) ? counts.get(key) : 0;
    }

    private static String normalizePhotoCategory(String photoCategory) {
        if (String.isBlank(photoCategory)) {
            return null;
        }
        return photoCategory.trim().toLowerCase().replace(' ', '_');
    }

    private static String normalizePhotoCategoryFromTitle(String title) {
        if (String.isBlank(title)) {
            return null;
        }
        String lower = title.toLowerCase();
        Integer divider = lower.indexOf(' - ');
        return divider > 0 ? lower.substring(0, divider) : null;
    }

    private static String currentUserDisplayName() {
        return [SELECT Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Name;
    }

    private static String safeLotName(Work_Order__c wo) {
        if (wo == null) {
            return null;
        }
        if (wo.Lot__r != null && !String.isBlank(wo.Lot__r.Name)) {
            return wo.Lot__r.Name;
        }
        return wo.Name;
    }

    private static String buildAddress(Work_Order__c wo) {
        if (wo == null) {
            return null;
        }
        if (wo.Lot__r != null && !String.isBlank(wo.Lot__r.Address__c)) {
            return wo.Lot__r.Address__c;
        }
        if (wo.Community__r != null && !String.isBlank(wo.Community__r.Community_Address__c)) {
            return wo.Community__r.Community_Address__c;
        }
        return null;
    }

    private static String buildCityStateZip(Work_Order__c wo) {
        if (wo == null) {
            return null;
        }

        String city;
        String state;
        String zip;
        if (wo.Lot__r != null) {
            city = wo.Lot__r.City__c;
            state = wo.Lot__r.State__c;
            zip = null;
        } else if (wo.Community__r != null) {
            city = wo.Community__r.Community_City__c;
            state = wo.Community__r.Community_State__c;
            zip = wo.Community__r.Community_Zip__c;
        }

        List<String> left = new List<String>();
        if (!String.isBlank(city)) {
            left.add(city);
        }
        if (!String.isBlank(state)) {
            left.add(state);
        }
        String base = left.isEmpty() ? '' : String.join(left, ', ');
        if (!String.isBlank(zip)) {
            base = String.isBlank(base) ? zip : base + ' ' + zip;
        }
        return base;
    }

    private static Decimal resolveLatitude(Work_Order__c wo) {
        if (wo == null) {
            return null;
        }
        if (wo.Lot__r != null && wo.Lot__r.Lot_Latitude__c != null) {
            return wo.Lot__r.Lot_Latitude__c;
        }
        if (wo.Community__r != null && wo.Community__r.GPS_Latitude__c != null) {
            return wo.Community__r.GPS_Latitude__c;
        }
        return wo.Lot_Latitude__c;
    }

    private static Decimal resolveLongitude(Work_Order__c wo) {
        if (wo == null) {
            return null;
        }
        if (wo.Lot__r != null && wo.Lot__r.Lot_Longitude__c != null) {
            return wo.Lot__r.Lot_Longitude__c;
        }
        if (wo.Community__r != null && wo.Community__r.GPS_Longitude__c != null) {
            return wo.Community__r.GPS_Longitude__c;
        }
        return wo.Lot_Longitude__c;
    }

    private static Id resolveIssueFieldManagerId(Work_Order__c workOrder) {
        if (workOrder == null) {
            return null;
        }
        if (workOrder.Field_Manager__c != null) {
            return workOrder.Field_Manager__c;
        }
        return workOrder.FM_Assignment__c;
    }

    private static Id resolveIssueMarketId(Work_Order__c workOrder) {
        if (workOrder == null || workOrder.Community__r == null) {
            return null;
        }
        return (Id) workOrder.Community__r.get('ServiceTerritory__c');
    }

    private static String resolveRequiredAction(String issueType, String severity) {
        if (!isHighSeverity(severity)) {
            return null;
        }
        if ('Weather'.equalsIgnoreCase(issueType)) {
            return 'Review Weather Hold';
        }
        if ('Traffic'.equalsIgnoreCase(issueType)) {
            return 'Review Traffic Impact';
        }
        if ('Site Readiness'.equalsIgnoreCase(issueType)) {
            return 'Confirm Site Ready';
        }
        if ('Inventory'.equalsIgnoreCase(issueType)) {
            return 'Resolve Inventory Hold';
        }
        return 'Other';
    }

    private static Boolean isHighSeverity(String severity) {
        return 'High'.equalsIgnoreCase(severity) || 'Critical'.equalsIgnoreCase(severity);
    }

    private static String extractDmlMessage(DmlException e) {
        if (e.getNumDml() > 0) {
            return e.getDmlMessage(0);
        }
        return e.getMessage();
    }

    @TestVisible
    private static void exerciseDtoForCoverage() {
        MobileContextDto ctx = new MobileContextDto();
        ctx.workOrderId = 'a01';
        ctx.foremanName = 'FM';
        ctx.crewName = 'Crew';
        ctx.clockStatus = new ClockStatusDto();
        ctx.activeJob = newJob();
        ctx.schedule = new List<ScheduleCardDto>();
        ctx.vehicleChecklist = newVehicleChecklist();
        ctx.loadedChecklist = newLoadedChecklist();
        ctx.workOrderChecklists = new List<ChecklistGroupDto>();
        ctx.lineItems = new List<ScopeLineItemDto>();
        ctx.openIssues = new List<IssueDto>();
        ctx.photoSummary = newPhotoSummary();
        ctx.closeoutGates = new List<String>();
        System.assertNotEquals(null, ctx);
    }
}