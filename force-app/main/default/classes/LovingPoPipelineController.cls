public with sharing class LovingPoPipelineController {

    private static final String PROD_INSTALL_RT = 'Production_Install';
    private static final String PROD_INSTALL_TYPE = 'Production Install';
    private static final String PROD_INSTALL_WORKTYPE = 'Production Install';
    private static final String TAKEOFF_REQUESTED = 'Draft';
    private static final String TAKEOFF_SCHEDULED = 'Submitted';
    private static final String TAKEOFF_APPROVED = 'Approved';
    private static final String PO_STATUS_WORK_ORDER_CREATED = 'Work Order Created';
    private static final String PO_STATUS_CLEAR_FOR_SCHEDULE = 'Clear for Schedule';
    private static final String SA_STATUS_READY = 'Ready to Schedule';
    private static final String SA_STATUS_SCHEDULED = 'Scheduled';
    private static final String SA_STATUS_NONE = 'None';

    public class PipelineDTO {
        @AuraEnabled public Integer openCount;
        @AuraEnabled public Integer reviewCount;
        @AuraEnabled public Integer forecastCount;
        @AuraEnabled public Integer clearCount;
        @AuraEnabled public Integer workOrderCount;
        @AuraEnabled public Decimal openPOValue;
        @AuraEnabled public List<PoCardDTO> records;
        @AuraEnabled public List<String> builderNames;
        @AuraEnabled public String debugMessage;
    }

    public class PoCardDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String builderPoId;
        @AuraEnabled public String name;
        @AuraEnabled public String purchaseOrderName;
        @AuraEnabled public String status;
        @AuraEnabled public String boardColumn;
        @AuraEnabled public String communityId;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotId;
        @AuraEnabled public String lotName;
        @AuraEnabled public String builderName;
        @AuraEnabled public String divisionName;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String itemName;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String workOrderId;
        @AuraEnabled public String pipelineBucket;
        @AuraEnabled public String pipelineStage;
        @AuraEnabled public String estimatedStartDate;
        @AuraEnabled public String takeoffStatus;
        @AuraEnabled public String packageMatchStatus;
    }

    public class PoLineDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal orderedQuantity;
        @AuraEnabled public Decimal verifiedQuantity;
        @AuraEnabled public Decimal measuredQuantity;
        @AuraEnabled public String unit;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public String workType;
        @AuraEnabled public String packageMatch;
        @AuraEnabled public String reviewStatus;
        @AuraEnabled public String matchNotes;
    }

    public class FieldManagerOptionDTO {
        @AuraEnabled public String userId;
        @AuraEnabled public String serviceResourceId;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
    }

    public class TakeoffSummaryDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String scheduledDate;
        @AuraEnabled public String fieldManagerId;
        @AuraEnabled public String fieldManagerName;
        @AuraEnabled public Boolean checklistComplete;
        @AuraEnabled public Boolean eight11Confirmed;
        @AuraEnabled public Integer photoCount;
        @AuraEnabled public Boolean canApprove;
        @AuraEnabled public List<PoLineDTO> lines;
    }

    public class WorkOrderLineDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public String status;
    }

    public class WorkOrderSummaryDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String description;
        @AuraEnabled public String status;
        @AuraEnabled public String fieldManagerId;
        @AuraEnabled public String fieldManagerName;
        @AuraEnabled public String workType;
        @AuraEnabled public String serviceTerritoryId;
        @AuraEnabled public String serviceTerritoryName;
        @AuraEnabled public Integer lineItemCount;
        @AuraEnabled public Integer childWorkOrderCount;
        @AuraEnabled public Integer childAppointmentCount;
        @AuraEnabled public String childTypeSummary;
        @AuraEnabled public List<WorkOrderLineDTO> lines;
    }

    public class ServiceAppointmentSummaryDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String appointmentNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String scheduledStart;
    }

    public class GateCheckDTO {
        @AuraEnabled public String label;
        @AuraEnabled public Boolean passed;
        @AuraEnabled public String detail;
    }

    public class ActivityDTO {
        @AuraEnabled public String recordId;
        @AuraEnabled public String label;
        @AuraEnabled public String detail;
        @AuraEnabled public String whenLabel;
        @AuraEnabled public String relatedLabel;
        @AuraEnabled public String tone;
    }

    public class DetailDTO {
        @AuraEnabled public PoCardDTO po;
        @AuraEnabled public List<PoLineDTO> poLines;
        @AuraEnabled public TakeoffSummaryDTO takeoff;
        @AuraEnabled public WorkOrderSummaryDTO workOrder;
        @AuraEnabled public ServiceAppointmentSummaryDTO serviceAppointment;
        @AuraEnabled public List<ActivityDTO> activity;
        @AuraEnabled public List<FieldManagerOptionDTO> fieldManagers;
        @AuraEnabled public List<GateCheckDTO> gateChecks;
        @AuraEnabled public String nextAction;
        @AuraEnabled public Boolean canAssignFieldManager;
        @AuraEnabled public Boolean canCreateWorkOrder;
        @AuraEnabled public Boolean canCreateScheduleHandoff;
    }

    public class ActionResult {
        @AuraEnabled public Boolean passed;
        @AuraEnabled public String message;
        @AuraEnabled public String newStatus;
        @AuraEnabled public String takeoffId;
        @AuraEnabled public String workOrderId;
        @AuraEnabled public String serviceAppointmentId;
    }

    public class OptionDTO {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    @TestVisible
    private static String mapToBoardColumn(String pipelineStage, String status, String bucket) {
        if (status == PO_STATUS_CLEAR_FOR_SCHEDULE) {
            return 'clear';
        }
        if (status == PO_STATUS_WORK_ORDER_CREATED) {
            return 'workOrderCreated';
        }
        if (status == 'Takeoff Complete') {
            return 'takeoffComplete';
        }
        if (status == 'Takeoff In Progress') {
            return 'takeoffProgress';
        }
        if (status == 'Takeoff Scheduled') {
            return 'takeoffScheduled';
        }
        if (status == 'Ready for Takeoff') {
            return 'takeoffRequested';
        }
        if (status == 'Pending CS Review') {
            return 'csmReview';
        }
        if (status == 'Package Match Check') {
            return 'packageCheck';
        }
        return PurchaseOrderTimingService.mapStageToBoardColumn(
            String.isBlank(pipelineStage)
                ? PurchaseOrderTimingService.calculatePipelineStage(
                    new Purchase_Order__c(
                        Status__c = status,
                        Pipeline_Bucket__c = bucket
                    )
                )
                : pipelineStage,
            status
        );
    }

    @AuraEnabled(cacheable=false)
    public static PipelineDTO getPipelineData() {
        PipelineDTO dto = new PipelineDTO();
        dto.records = new List<PoCardDTO>();
        dto.builderNames = new List<String>();

        List<Purchase_Order__c> recs;
        try {
            recs = [
                SELECT Id, Name, PO_Number__c, Status__c,
                    Builder_Account__c, Builder_Account__r.Name,
                    Community__c, Community__r.Name,
                    Community_Name__c,
                    Lot__c, Lot__r.Name,
                    Division_Account__c, Division_Account__r.Name,
                    Item__c, Item__r.Name, Quantity__c, Total_Amount__c, Work_Order__c,
                    Pipeline_Bucket__c, Pipeline_Stage__c, Estimated_Start_Date__c, Takeoff_Status__c,
                    Package_BMG_Status__c
                FROM Purchase_Order__c
                WHERE (Status__c NOT IN ('Cancelled', 'Closed', 'NFI') OR Status__c = null)
                ORDER BY CreatedDate DESC
                LIMIT 500
            ];
        } catch (Exception e) {
            dto.debugMessage = e.getMessage();
            return dto;
        }

        Set<String> builderSet = new Set<String>();
        Decimal totalValue = 0;
        Integer reviewCnt = 0, forecastCnt = 0, clearCnt = 0, woCnt = 0;

        Map<String, Builder_PO__c> builderPoByNumber = loadBuilderPosByNumber(recs);

        for (Purchase_Order__c po : recs) {
            PoCardDTO card = mapPoCard(po, builderPoByNumber);
            if (String.isBlank(card.builderPoId)) {
                continue;
            }
            dto.records.add(card);

            if (card.builderName != null) builderSet.add(card.builderName);
            if (po.Total_Amount__c != null) totalValue += po.Total_Amount__c;

            String col = card.boardColumn;
            if (col == 'packageCheck' || col == 'csmReview') reviewCnt++;
            else if (col == 'takeoffRequested' || col == 'takeoffScheduled' || col == 'takeoffProgress' || col == 'takeoffComplete') forecastCnt++;
            else if (col == 'clear') clearCnt++;
            else if (col == 'workOrderCreated') woCnt++;
        }

        dto.openCount = dto.records.size();
        dto.reviewCount = reviewCnt;
        dto.forecastCount = forecastCnt;
        dto.clearCount = clearCnt;
        dto.workOrderCount = woCnt;
        dto.openPOValue = totalValue;
        dto.builderNames.addAll(builderSet);
        dto.builderNames.sort();
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionDTO> getBuilderPoStatusOptions() {
        List<OptionDTO> options = new List<OptionDTO>();
        for (Schema.PicklistEntry entry : Builder_PO__c.Status__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            OptionDTO option = new OptionDTO();
            option.value = entry.getValue();
            option.label = entry.getLabel();
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=false)
    public static DetailDTO getPoDetail(Id poId) {
        if (poId == null) {
            throw new AuraHandledException('Builder PO support record Id is required.');
        }

        Purchase_Order__c po = [
            SELECT Id, Name, Status__c, PO_Number__c,
                Builder_Account__c, Builder_Account__r.Name,
                Division_Account__c, Division_Account__r.Name,
                Community__c, Community__r.Name, Community__r.ServiceTerritory__c, Community__r.FM_Assignment__c,
                Community_Name__c,
                Lot__c, Lot__r.Name,
                Item__c, Item__r.Name, Quantity__c, Total_Amount__c, Work_Order__c,
                Pipeline_Bucket__c, Pipeline_Stage__c, Estimated_Start_Date__c, Takeoff_Status__c,
                Package_BMG_Status__c, CreatedDate
            FROM Purchase_Order__c
            WHERE Id = :poId
            LIMIT 1
        ];

        DetailDTO detail = new DetailDTO();
        detail.po = mapPoCard(po, loadBuilderPosByNumber(new List<Purchase_Order__c>{ po }));
        detail.poLines = loadPoLines(po.Id);
        detail.takeoff = loadTakeoffSummary(po.Id);
        detail.workOrder = loadWorkOrderSummary(po.Work_Order__c);
        detail.serviceAppointment = loadServiceAppointmentSummary(po.Work_Order__c);
        detail.activity = buildActivity(po, detail.takeoff, detail.workOrder, detail.serviceAppointment);
        detail.fieldManagers = loadFieldManagers();
        detail.gateChecks = buildGateChecks(po, detail.takeoff, detail.workOrder, detail.serviceAppointment);
        detail.canAssignFieldManager = po.Package_BMG_Status__c == 'Matched' || po.Package_BMG_Status__c == 'Not Required';
        detail.canCreateWorkOrder = detail.takeoff != null
            && detail.takeoff.status == TAKEOFF_APPROVED
            && detail.workOrder == null;
        detail.canCreateScheduleHandoff = detail.workOrder != null && detail.serviceAppointment == null;
        detail.nextAction = deriveNextAction(detail);
        return detail;
    }

    @AuraEnabled(cacheable=false)
    public static DetailDTO getBuilderPoDetail(Id builderPoId) {
        if (builderPoId == null) {
            throw new AuraHandledException('Builder PO Id is required.');
        }

        Builder_PO__c builderPo = [
            SELECT Id, Name, PO_Number__c
            FROM Builder_PO__c
            WHERE Id = :builderPoId
            LIMIT 1
        ];

        if (String.isBlank(builderPo.PO_Number__c)) {
            throw new AuraHandledException('Builder PO ' + builderPo.Name + ' is missing its PO number, so the live Builder PO detail cannot be resolved.');
        }

        List<Purchase_Order__c> matchedRows = [
            SELECT Id, LastModifiedDate
            FROM Purchase_Order__c
            WHERE PO_Number__c = :builderPo.PO_Number__c
            ORDER BY LastModifiedDate DESC
            LIMIT 2
        ];

        if (matchedRows.isEmpty()) {
            throw new AuraHandledException('No live Builder PO detail matched Builder PO ' + builderPo.PO_Number__c + '.');
        }
        if (matchedRows.size() > 1) {
            throw new AuraHandledException('Multiple live Builder PO detail rows match Builder PO ' + builderPo.PO_Number__c + '. Resolve the duplicate before using the Builder PO workspace.');
        }

        DetailDTO detail = getPoDetail(matchedRows[0].Id);
        if (detail != null && detail.po != null) {
            detail.po.builderPoId = (String) builderPo.Id;
            detail.po.purchaseOrderName = detail.po.name;
            detail.po.name = String.isBlank(builderPo.Name) ? detail.po.name : builderPo.Name;
        }
        return detail;
    }

    @AuraEnabled(cacheable=false)
    public static DetailDTO getTakeoffDetail(Id takeoffId) {
        if (takeoffId == null) {
            throw new AuraHandledException('Takeoff Id is required.');
        }

        Takeoff__c takeoff = [
            SELECT Id, Name, Builder_PO__c, Work_Order__c
            FROM Takeoff__c
            WHERE Id = :takeoffId
            LIMIT 1
        ];

        if (takeoff.Builder_PO__c == null) {
            throw new AuraHandledException('This takeoff is not linked to a Builder PO, so the live builder takeoff workspace cannot be resolved.');
        }

        DetailDTO detail = getBuilderPoDetail(takeoff.Builder_PO__c);
        if (detail == null) {
            return null;
        }

        detail.takeoff = loadTakeoffSummaryById(takeoffId);
        if (detail.takeoff == null) {
            throw new AuraHandledException('The linked Builder PO was found, but the requested takeoff detail could not be loaded.');
        }

        Id workOrderId = takeoff.Work_Order__c;
        if (workOrderId == null && detail.po != null && detail.po.id != null) {
            List<Purchase_Order__c> poRows = [
                SELECT Work_Order__c
                FROM Purchase_Order__c
                WHERE Id = :detail.po.id
                LIMIT 1
            ];
            workOrderId = poRows.isEmpty() ? null : poRows[0].Work_Order__c;
        }

        detail.workOrder = loadWorkOrderSummary(workOrderId);
        detail.serviceAppointment = loadServiceAppointmentSummary(workOrderId);
        if (detail.po != null) {
            Purchase_Order__c po = [
                SELECT Id, Name, Status__c, PO_Number__c,
                    Builder_Account__c, Builder_Account__r.Name,
                    Division_Account__c, Division_Account__r.Name,
                    Community__c, Community__r.Name, Community__r.ServiceTerritory__c, Community__r.FM_Assignment__c,
                    Community_Name__c,
                    Lot__c, Lot__r.Name,
                    Item__c, Item__r.Name, Quantity__c, Total_Amount__c, Work_Order__c,
                    Pipeline_Bucket__c, Pipeline_Stage__c, Estimated_Start_Date__c, Takeoff_Status__c,
                    Package_BMG_Status__c, CreatedDate
                FROM Purchase_Order__c
                WHERE Id = :detail.po.id
                LIMIT 1
            ];
            detail.activity = buildActivity(po, detail.takeoff, detail.workOrder, detail.serviceAppointment);
            detail.gateChecks = buildGateChecks(po, detail.takeoff, detail.workOrder, detail.serviceAppointment);
            detail.canCreateWorkOrder = detail.takeoff != null
                && detail.takeoff.status == TAKEOFF_APPROVED
                && detail.workOrder == null;
            detail.canCreateScheduleHandoff = detail.workOrder != null && detail.serviceAppointment == null;
            detail.nextAction = deriveNextAction(detail);
        }
        return detail;
    }

    @AuraEnabled
    public static ActionResult updatePoStatus(String poId, String newStatus) {
        ActionResult res = new ActionResult();
        try {
            Purchase_Order__c currentPo = [
                SELECT Id, Status__c, Package_BMG_Status__c, Work_Order__c, Estimated_Start_Date__c, Takeoff_Status__c
                FROM Purchase_Order__c
                WHERE Id = :poId
                LIMIT 1
            ];

            if (newStatus == 'Ready for Takeoff'
                    && currentPo.Package_BMG_Status__c != 'Matched'
                    && currentPo.Package_BMG_Status__c != 'Not Required') {
                res.passed = false;
                res.message = 'Builder PO cannot move to takeoff until the package match is complete.';
                return res;
            }

            if (newStatus == PO_STATUS_WORK_ORDER_CREATED && currentPo.Work_Order__c == null) {
                res.passed = false;
                res.message = 'A standard WorkOrder must be linked before marking WorkOrder Created.';
                return res;
            }

            if (newStatus == PO_STATUS_CLEAR_FOR_SCHEDULE
                    && (currentPo.Work_Order__c == null
                        || (currentPo.Status__c != 'Takeoff Complete' && currentPo.Takeoff_Status__c != TAKEOFF_APPROVED))) {
                res.passed = false;
                res.message = 'Ready for scheduling requires an approved takeoff and a linked standard WorkOrder.';
                return res;
            }

            Purchase_Order__c updatePo = new Purchase_Order__c(
                Id = poId,
                Status__c = newStatus
            );
            updatePo.Pipeline_Stage__c = PurchaseOrderTimingService.calculatePipelineStage(new Purchase_Order__c(
                Status__c = newStatus,
                Package_BMG_Status__c = currentPo.Package_BMG_Status__c,
                Work_Order__c = currentPo.Work_Order__c,
                Takeoff_Status__c = currentPo.Takeoff_Status__c,
                Estimated_Start_Date__c = currentPo.Estimated_Start_Date__c
            ));
            update updatePo;
            res.passed = true;
            res.newStatus = newStatus;
            res.message = 'Builder PO moved to ' + displayStatusLabel(newStatus);
        } catch (Exception e) {
            res.passed = false;
            res.message = 'Save failed: ' + e.getMessage();
        }
        return res;
    }

    @AuraEnabled
    public static String createOrGetTakeoff(String poId) {
        Purchase_Order__c po = [
            SELECT Id, PO_Number__c, Package_BMG_Status__c, Status__c, Work_Order__c, Takeoff_Status__c
            FROM Purchase_Order__c
            WHERE Id = :poId
            LIMIT 1
        ];

        if (po.Package_BMG_Status__c != 'Matched' && po.Package_BMG_Status__c != 'Not Required') {
            throw new AuraHandledException('This Builder PO is not ready for takeoff. Complete the package match first.');
        }

        if (String.isBlank(po.PO_Number__c)) {
            throw new AuraHandledException('A PO number is required before a takeoff can be created or opened.');
        }
        LovingPoBackboneService.BackboneResult backbone = LovingPoBackboneService.ensureBackbone(po.Id);

        if (po.Status__c == null || po.Status__c == 'Pending Takeoff' || po.Status__c == 'Package Match Check' || po.Status__c == 'Pending CS Review') {
            update new Purchase_Order__c(
                Id = po.Id,
                Status__c = 'Ready for Takeoff',
                Pipeline_Stage__c = PurchaseOrderTimingService.STAGE_TAKEOFF_REQUESTED
            );
        }
        return backbone.takeoffId;
    }

    @AuraEnabled
    public static ActionResult assignTakeoffFieldManager(Id poId, Id fieldManagerUserId, Date scheduledDate) {
        ActionResult result = new ActionResult();
        if (poId == null || fieldManagerUserId == null) {
            result.passed = false;
            result.message = 'Builder PO and Field Manager are required.';
            return result;
        }
        try {
            String takeoffId = createOrGetTakeoff(poId);
            Takeoff__c takeoff = [
                SELECT Id, Status__c, FM_Assignment__c, Scheduled_Date__c
                FROM Takeoff__c
                WHERE Id = :takeoffId
                LIMIT 1
            ];
            String nextTakeoffStatus = scheduledDate == null ? TAKEOFF_REQUESTED : TAKEOFF_SCHEDULED;
            update new Takeoff__c(
                Id = takeoff.Id,
                FM_Assignment__c = fieldManagerUserId,
                Scheduled_Date__c = scheduledDate,
                Status__c = nextTakeoffStatus
            );

            Purchase_Order__c poUpdate = new Purchase_Order__c(Id = poId);
            poUpdate.Takeoff_Status__c = nextTakeoffStatus;
            poUpdate.Status__c = scheduledDate == null ? 'Ready for Takeoff' : 'Takeoff Scheduled';
            poUpdate.Pipeline_Stage__c = scheduledDate == null
                ? PurchaseOrderTimingService.STAGE_TAKEOFF_REQUESTED
                : PurchaseOrderTimingService.STAGE_TAKEOFF_SCHEDULED;
            update poUpdate;

            LovingFieldManagerMobileSyncService.syncTakeoffs(new Set<Id>{ takeoff.Id });

            result.passed = true;
            result.message = scheduledDate == null
                ? 'Field Manager assigned and takeoff opened.'
                : 'Field Manager assigned and takeoff scheduled.';
            result.takeoffId = takeoff.Id;
            result.newStatus = poUpdate.Status__c;
        } catch (Exception e) {
            result.passed = false;
            result.message = e.getMessage();
        }
        return result;
    }

    @AuraEnabled
    public static ActionResult createProductionWorkOrder(Id poId) {
        ActionResult result = new ActionResult();
        if (poId == null) {
            result.passed = false;
            result.message = 'Builder PO support record Id is required.';
            return result;
        }
        try {
            Purchase_Order__c po = [
                SELECT Id, Name, PO_Number__c, Status__c, Builder_Account__c,
                    Builder_Account__r.Name,
                    Community__c, Community__r.Name, Community__r.ServiceTerritory__c, Community__r.FM_Assignment__c,
                    Lot__c, Lot__r.Name, Quantity__c, Work_Order__c, Takeoff_Status__c
                FROM Purchase_Order__c
                WHERE Id = :poId
                LIMIT 1
            ];
            Takeoff__c takeoff = latestTakeoff(poId);
            if (takeoff == null) {
                result.passed = false;
                result.message = 'Takeoff is required before a Production Install WorkOrder can be created.';
                return result;
            }
            if (takeoff.Status__c != TAKEOFF_APPROVED) {
                result.passed = false;
                result.message = 'Takeoff must be approved before a Production Install WorkOrder can be created.';
                return result;
            }
            if (po.Work_Order__c != null) {
                Integer createdScopeRows = LovingPoBackboneService.materializeApprovedWorkScope(takeoff.Id);
                update new Purchase_Order__c(
                    Id = po.Id,
                    Status__c = PO_STATUS_WORK_ORDER_CREATED,
                    Pipeline_Stage__c = PurchaseOrderTimingService.STAGE_WORK_ORDER_CREATED,
                    Takeoff_Status__c = 'Locked'
                );
                result.passed = true;
                result.workOrderId = po.Work_Order__c;
                result.takeoffId = takeoff.Id;
                result.newStatus = PO_STATUS_WORK_ORDER_CREATED;
                result.message = createdScopeRows > 0
                    ? 'Production Install WorkOrder already existed. Scope lines were refreshed from the approved takeoff.'
                    : 'Production Install WorkOrder already existed.';
                return result;
            }

            Id recordTypeId = workOrderRecordTypeId();
            Id workTypeId = workTypeIdByName(PROD_INSTALL_WORKTYPE);
            Id fieldManagerId = takeoff.FM_Assignment__c != null ? takeoff.FM_Assignment__c : po.Community__r.FM_Assignment__c;
            String subject = 'Production Install · ' + labelFor(po.Community__r == null ? null : po.Community__r.Name, po.Lot__r == null ? null : po.Lot__r.Name);

            WorkOrder wo = new WorkOrder();
            wo.RecordTypeId = recordTypeId;
            wo.Subject = subject;
            wo.Description = buildWorkOrderDescription(po, takeoff);
            wo.Status = 'Ready to Schedule';
            wo.AccountId = po.Builder_Account__c;
            wo.Lot__c = po.Lot__c;
            wo.Field_Manager__c = fieldManagerId;
            wo.ServiceTerritoryId = po.Community__r == null ? null : (Id) po.Community__r.get('ServiceTerritory__c');
            wo.Work_Order_Type__c = PROD_INSTALL_TYPE;
            wo.Sod_Square_Footage__c = deriveSodSquareFootage(takeoff.Id, po.Quantity__c);
            if (workTypeId != null) {
                wo.WorkTypeId = workTypeId;
            }
            insert wo;

            update new Purchase_Order__c(
                Id = po.Id,
                Work_Order__c = wo.Id,
                Status__c = PO_STATUS_WORK_ORDER_CREATED,
                Pipeline_Stage__c = PurchaseOrderTimingService.STAGE_WORK_ORDER_CREATED,
                Takeoff_Status__c = 'Locked'
            );

            Integer createdLines = LovingPoBackboneService.materializeApprovedWorkScope(takeoff.Id);

            result.passed = true;
            result.takeoffId = takeoff.Id;
            result.workOrderId = wo.Id;
            result.newStatus = PO_STATUS_WORK_ORDER_CREATED;
            result.message = createdLines > 0
                ? 'Production Install WorkOrder created and execution scope was generated.'
                : 'Production Install WorkOrder created.';
        } catch (Exception e) {
            result.passed = false;
            result.message = e.getMessage();
        }
        return result;
    }

    @AuraEnabled
    public static ActionResult updateTakeoffReadiness(Id takeoffId, Boolean checklistComplete, Boolean eight11Confirmed, Integer photoCount) {
        ActionResult result = new ActionResult();
        if (takeoffId == null) {
            result.passed = false;
            result.message = 'Takeoff Id is required.';
            return result;
        }
        try {
            SObject takeoffUpdate = Schema.getGlobalDescribe().get('Takeoff__c').newSObject(takeoffId);
            takeoffUpdate.put('Checklist_Complete__c', checklistComplete == true);
            takeoffUpdate.put('Eight11_Confirmed__c', eight11Confirmed == true);
            takeoffUpdate.put('Photo_Count__c', photoCount == null ? 0 : photoCount);
            update takeoffUpdate;

            result.passed = true;
            result.takeoffId = String.valueOf(takeoffId);
            result.message = 'Takeoff readiness was updated.';
        } catch (Exception e) {
            result.passed = false;
            result.message = e.getMessage();
        }
        return result;
    }

    @AuraEnabled
    public static ActionResult createScheduleHandoff(Id poId) {
        ActionResult result = new ActionResult();
        if (poId == null) {
            result.passed = false;
            result.message = 'Builder PO support record Id is required.';
            return result;
        }
        try {
            Purchase_Order__c po = [
                SELECT Id, Status__c, Estimated_Start_Date__c, Work_Order__c
                FROM Purchase_Order__c
                WHERE Id = :poId
                LIMIT 1
            ];
            if (po.Work_Order__c == null) {
                result.passed = false;
                result.message = 'Create the WorkOrder first before creating a scheduling handoff.';
                return result;
            }

            WorkOrder wo = [
                SELECT Id, Subject, Status, WorkTypeId, ServiceTerritoryId, Description, Field_Manager__c
                FROM WorkOrder
                WHERE Id = :po.Work_Order__c
                LIMIT 1
            ];

            Id workTypeId = wo.WorkTypeId != null ? wo.WorkTypeId : workTypeIdByName(PROD_INSTALL_WORKTYPE);
            Integer duration = workTypeDurationMinutes(workTypeId);
            if (duration == null || duration <= 0) {
                duration = 240;
            }
            Datetime startTime = po.Estimated_Start_Date__c == null
                ? System.now().addDays(1)
                : Datetime.newInstance(po.Estimated_Start_Date__c, Time.newInstance(7, 0, 0, 0));
            List<ServiceAppointment> existing = [
                SELECT Id, AppointmentNumber, Status, Description, WorkTypeId, ServiceTerritoryId,
                       Duration, DurationType, EarliestStartTime, DueDate, SchedStartTime, SchedEndTime
                FROM ServiceAppointment
                WHERE ParentRecordId = :po.Work_Order__c
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                ServiceAppointment existingSa = existing[0];
                Boolean needsUpdate = false;
                ServiceAppointment saUpdate = new ServiceAppointment(Id = existingSa.Id);
                String desiredDescription = buildServiceAppointmentDescription(wo);
                if (existingSa.Status != SA_STATUS_SCHEDULED) {
                    saUpdate.Status = SA_STATUS_SCHEDULED;
                    needsUpdate = true;
                }
                if (existingSa.Description != desiredDescription) {
                    saUpdate.Description = desiredDescription;
                    needsUpdate = true;
                }
                if (existingSa.WorkTypeId != workTypeId) {
                    saUpdate.WorkTypeId = workTypeId;
                    needsUpdate = true;
                }
                if (existingSa.ServiceTerritoryId != wo.ServiceTerritoryId) {
                    saUpdate.ServiceTerritoryId = wo.ServiceTerritoryId;
                    needsUpdate = true;
                }
                if (existingSa.Duration != duration) {
                    saUpdate.Duration = duration;
                    needsUpdate = true;
                }
                if (existingSa.DurationType != 'Minutes') {
                    saUpdate.DurationType = 'Minutes';
                    needsUpdate = true;
                }
                if (existingSa.EarliestStartTime == null) {
                    saUpdate.EarliestStartTime = startTime;
                    needsUpdate = true;
                }
                if (existingSa.DueDate == null) {
                    saUpdate.DueDate = startTime.addMinutes(duration);
                    needsUpdate = true;
                }
                if (existingSa.SchedStartTime == null) {
                    saUpdate.SchedStartTime = startTime;
                    needsUpdate = true;
                }
                Datetime desiredScheduledEnd = startTime.addMinutes(duration);
                if (existingSa.SchedEndTime == null) {
                    saUpdate.SchedEndTime = desiredScheduledEnd;
                    needsUpdate = true;
                }
                if (needsUpdate) {
                    update saUpdate;
                }
                if (po.Status__c != PO_STATUS_CLEAR_FOR_SCHEDULE) {
                    update new Purchase_Order__c(
                        Id = po.Id,
                        Status__c = PO_STATUS_CLEAR_FOR_SCHEDULE,
                        Pipeline_Stage__c = PurchaseOrderTimingService.STAGE_CLEAR_TO_SCHEDULE
                    );
                }
                if (wo.Status != 'Ready to Schedule') {
                    update new WorkOrder(Id = wo.Id, Status = 'Ready to Schedule');
                }
                ensureAssignedResource(existingSa.Id, wo.Field_Manager__c);
                result.passed = true;
                result.serviceAppointmentId = existingSa.Id;
                result.workOrderId = wo.Id;
                result.newStatus = PO_STATUS_CLEAR_FOR_SCHEDULE;
                result.message = needsUpdate
                    ? 'Scheduling handoff existed and was normalized for production use.'
                    : 'Scheduling handoff already exists.';
                return result;
            }
            ServiceAppointment sa = new ServiceAppointment(
                ParentRecordId = wo.Id,
                Subject = wo.Subject,
                Description = buildServiceAppointmentDescription(wo),
                Status = SA_STATUS_SCHEDULED,
                WorkTypeId = workTypeId,
                ServiceTerritoryId = wo.ServiceTerritoryId,
                Duration = duration,
                DurationType = 'Minutes',
                EarliestStartTime = startTime,
                DueDate = startTime.addMinutes(duration),
                SchedStartTime = startTime,
                SchedEndTime = startTime.addMinutes(duration)
            );
            insert sa;
            ensureAssignedResource(sa.Id, wo.Field_Manager__c);

            update new Purchase_Order__c(
                Id = po.Id,
                Status__c = PO_STATUS_CLEAR_FOR_SCHEDULE,
                Pipeline_Stage__c = PurchaseOrderTimingService.STAGE_CLEAR_TO_SCHEDULE
            );
            if (wo.Status != 'Ready to Schedule') {
                update new WorkOrder(Id = wo.Id, Status = 'Ready to Schedule');
            }

            result.passed = true;
            result.workOrderId = wo.Id;
            result.serviceAppointmentId = sa.Id;
            result.newStatus = PO_STATUS_CLEAR_FOR_SCHEDULE;
            result.message = 'Scheduling handoff created on the standard Service Appointment.';
        } catch (Exception e) {
            result.passed = false;
            result.message = e.getMessage();
        }
        return result;
    }

    @TestVisible
    private static void ensureAssignedResource(Id serviceAppointmentId, Id fieldManagerUserId) {
        if (serviceAppointmentId == null || fieldManagerUserId == null) {
            return;
        }
        List<ServiceResource> resources = [
            SELECT Id
            FROM ServiceResource
            WHERE RelatedRecordId = :fieldManagerUserId
              AND IsActive = true
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (resources.isEmpty()) {
            return;
        }
        Id serviceResourceId = resources[0].Id;
        List<AssignedResource> existing = [
            SELECT Id, ServiceResourceId
            FROM AssignedResource
            WHERE ServiceAppointmentId = :serviceAppointmentId
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new AssignedResource(
                ServiceAppointmentId = serviceAppointmentId,
                ServiceResourceId = serviceResourceId
            );
            return;
        }
        if (existing[0].ServiceResourceId != serviceResourceId) {
            update new AssignedResource(
                Id = existing[0].Id,
                ServiceResourceId = serviceResourceId
            );
        }
    }

    private static PoCardDTO mapPoCard(Purchase_Order__c po, Map<String, Builder_PO__c> builderPoByNumber) {
        PoCardDTO card = new PoCardDTO();
        card.id = po.Id;
        card.builderPoId = resolveBuilderPoId(po.PO_Number__c, builderPoByNumber);
        card.name = String.isBlank(po.PO_Number__c) ? po.Name : po.PO_Number__c;
        card.purchaseOrderName = String.isBlank(po.Name) ? card.name : po.Name;
        card.status = po.Status__c;
        card.communityId = po.Community__c;
        card.communityName = po.Community__c != null ? po.Community__r.Name : po.Community_Name__c;
        card.lotId = po.Lot__c;
        card.lotName = po.Lot__c != null ? po.Lot__r.Name : null;
        card.builderName = po.Builder_Account__c != null ? po.Builder_Account__r.Name : null;
        card.divisionName = po.Division_Account__c != null ? po.Division_Account__r.Name : null;
        card.totalAmount = po.Total_Amount__c;
        card.itemName = po.Item__c != null ? po.Item__r.Name : null;
        card.quantity = po.Quantity__c;
        card.workOrderId = po.Work_Order__c;
        card.pipelineBucket = po.Pipeline_Bucket__c;
        card.pipelineStage = po.Pipeline_Stage__c;
        card.takeoffStatus = po.Takeoff_Status__c;
        card.packageMatchStatus = (String) po.get('Package_BMG_Status__c');
        card.estimatedStartDate = po.Estimated_Start_Date__c != null ? po.Estimated_Start_Date__c.format() : null;
        card.boardColumn = mapToBoardColumn(po.Pipeline_Stage__c, po.Status__c, po.Pipeline_Bucket__c);
        return card;
    }

    private static Map<String, Builder_PO__c> loadBuilderPosByNumber(List<Purchase_Order__c> rows) {
        Map<String, Builder_PO__c> byNumber = new Map<String, Builder_PO__c>();
        Set<String> poNumbers = new Set<String>();
        for (Purchase_Order__c row : rows) {
            if (!String.isBlank(row.PO_Number__c)) {
                poNumbers.add(row.PO_Number__c);
            }
        }
        if (poNumbers.isEmpty()) {
            return byNumber;
        }
        for (Builder_PO__c builderPo : [
            SELECT Id, PO_Number__c
            FROM Builder_PO__c
            WHERE PO_Number__c IN :poNumbers
            ORDER BY LastModifiedDate DESC
        ]) {
            if (!byNumber.containsKey(builderPo.PO_Number__c)) {
                byNumber.put(builderPo.PO_Number__c, builderPo);
            }
        }
        return byNumber;
    }

    private static String resolveBuilderPoId(String poNumber, Map<String, Builder_PO__c> builderPoByNumber) {
        if (String.isBlank(poNumber) || builderPoByNumber == null || !builderPoByNumber.containsKey(poNumber)) {
            return null;
        }
        return (String) builderPoByNumber.get(poNumber).Id;
    }

    private static List<PoLineDTO> loadPoLines(Id poId) {
        List<PoLineDTO> rows = new List<PoLineDTO>();
        for (PO_Line_Item__c line : [
            SELECT Id, Line_Description__c, Quantity__c, Unit__c, Unit_Price__c,
                   Work_Type__c, Package_Match__c, Match_Notes__c
            FROM PO_Line_Item__c
            WHERE Purchase_Order__c = :poId
            ORDER BY Source_Line_Number__c ASC NULLS LAST, CreatedDate ASC
        ]) {
            PoLineDTO dto = new PoLineDTO();
            dto.id = line.Id;
            dto.description = line.Line_Description__c;
            dto.quantity = line.Quantity__c;
            dto.orderedQuantity = line.Quantity__c;
            dto.unit = line.Unit__c;
            dto.unitPrice = line.Unit_Price__c;
            dto.workType = line.Work_Type__c;
            dto.packageMatch = line.Package_Match__c;
            dto.matchNotes = line.Match_Notes__c;
            rows.add(dto);
        }
        return rows;
    }

    private static TakeoffSummaryDTO loadTakeoffSummary(Id poId) {
        Takeoff__c takeoff = latestTakeoff(poId);
        if (takeoff == null) {
            return null;
        }
        return mapTakeoffSummary(takeoff);
    }

    private static TakeoffSummaryDTO loadTakeoffSummaryById(Id takeoffId) {
        if (takeoffId == null) {
            return null;
        }
        List<Takeoff__c> rows = [
            SELECT Id, Name, Status__c, FM_Assignment__c, FM_Assignment__r.Name,
                   Scheduled_Date__c, Checklist_Complete__c, Eight11_Confirmed__c, Photo_Count__c,
                   Work_Order__c
            FROM Takeoff__c
            WHERE Id = :takeoffId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }
        return mapTakeoffSummary(rows[0]);
    }

    private static TakeoffSummaryDTO mapTakeoffSummary(Takeoff__c takeoff) {
        TakeoffSummaryDTO dto = new TakeoffSummaryDTO();
        dto.id = takeoff.Id;
        dto.name = takeoff.Name;
        dto.status = takeoff.Status__c;
        dto.scheduledDate = takeoff.get('Scheduled_Date__c') == null ? null : String.valueOf((Date) takeoff.get('Scheduled_Date__c'));
        dto.fieldManagerId = takeoff.FM_Assignment__c;
        dto.fieldManagerName = takeoff.FM_Assignment__r == null ? null : takeoff.FM_Assignment__r.Name;
        dto.checklistComplete = (Boolean) takeoff.get('Checklist_Complete__c') == true;
        dto.eight11Confirmed = (Boolean) takeoff.get('Eight11_Confirmed__c') == true;
        Decimal photoCount = (Decimal) takeoff.get('Photo_Count__c');
        dto.photoCount = photoCount == null ? 0 : Integer.valueOf(photoCount);
        dto.canApprove = dto.checklistComplete && dto.eight11Confirmed && dto.photoCount > 0 && takeoff.Status__c != TAKEOFF_APPROVED;
        dto.lines = new List<PoLineDTO>();
        for (Takeoff_Line__c line : [
            SELECT Id, Item_Description__c, PO_Quantity__c, Verified_Quantity__c, Measured_Quantity__c,
                   Unit__c, Unit_Price__c, Review_Status__c
            FROM Takeoff_Line__c
            WHERE Takeoff__c = :takeoff.Id
            ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC
        ]) {
            PoLineDTO row = new PoLineDTO();
            row.id = line.Id;
            row.description = line.Item_Description__c;
            row.orderedQuantity = line.PO_Quantity__c;
            row.verifiedQuantity = line.Verified_Quantity__c;
            row.measuredQuantity = line.Measured_Quantity__c;
            row.quantity = line.Verified_Quantity__c != null ? line.Verified_Quantity__c : (line.Measured_Quantity__c != null ? line.Measured_Quantity__c : line.PO_Quantity__c);
            row.unit = line.Unit__c;
            row.unitPrice = line.Unit_Price__c;
            row.packageMatch = line.Review_Status__c;
            row.reviewStatus = line.Review_Status__c;
            dto.lines.add(row);
        }
        return dto;
    }

    private static WorkOrderSummaryDTO loadWorkOrderSummary(Id workOrderId) {
        if (workOrderId == null) {
            return null;
        }
        WorkOrder wo = [
            SELECT Id, WorkOrderNumber, Subject, Description, Status, Field_Manager__c, Field_Manager__r.Name,
                   Work_Order_Type__c, ServiceTerritoryId, ServiceTerritory.Name, CreatedDate
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];
        WorkOrderSummaryDTO dto = new WorkOrderSummaryDTO();
        dto.id = wo.Id;
        dto.workOrderNumber = wo.WorkOrderNumber;
        dto.subject = wo.Subject;
        dto.description = wo.Description;
        dto.status = wo.Status;
        dto.fieldManagerId = wo.Field_Manager__c;
        dto.fieldManagerName = wo.Field_Manager__r == null ? null : wo.Field_Manager__r.Name;
        dto.workType = wo.Work_Order_Type__c;
        dto.serviceTerritoryId = wo.ServiceTerritoryId;
        dto.serviceTerritoryName = wo.ServiceTerritory == null ? null : wo.ServiceTerritory.Name;
        dto.lines = new List<WorkOrderLineDTO>();
        Set<Id> childIds = new Set<Id>();
        for (WorkOrderLineItem row : [
            SELECT Id, Description, Quantity, UnitPrice, Status
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :workOrderId
            ORDER BY CreatedDate ASC
            LIMIT 100
        ]) {
            WorkOrderLineDTO item = new WorkOrderLineDTO();
            item.id = row.Id;
            item.description = row.Description;
            item.quantity = row.Quantity;
            item.unitPrice = row.UnitPrice;
            item.status = row.Status;
            dto.lines.add(item);
        }
        dto.lineItemCount = dto.lines.size();
        List<WorkOrder> childRows = [
            SELECT Id, Work_Order_Type__c
            FROM WorkOrder
            WHERE ParentWorkOrderId = :workOrderId
            ORDER BY CreatedDate ASC
            LIMIT 100
        ];
        Set<String> childTypes = new Set<String>();
        for (WorkOrder child : childRows) {
            childIds.add(child.Id);
            if (!String.isBlank(child.Work_Order_Type__c)) {
                childTypes.add(child.Work_Order_Type__c);
            }
        }
        dto.childWorkOrderCount = childRows.size();
        dto.childAppointmentCount = childIds.isEmpty()
            ? 0
            : [SELECT COUNT() FROM ServiceAppointment WHERE ParentRecordId IN :childIds];
        List<String> childTypeList = new List<String>();
        childTypeList.addAll(childTypes);
        childTypeList.sort();
        dto.childTypeSummary = childTypeList.isEmpty() ? null : String.join(childTypeList, ', ');
        return dto;
    }

    private static ServiceAppointmentSummaryDTO loadServiceAppointmentSummary(Id workOrderId) {
        if (workOrderId == null) {
            return null;
        }
        List<ServiceAppointment> rows = [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, CreatedDate
            FROM ServiceAppointment
            WHERE ParentRecordId = :workOrderId
            ORDER BY SchedStartTime DESC NULLS LAST, CreatedDate DESC
            LIMIT 10
        ];
        if (rows.isEmpty()) {
            return null;
        }
        ServiceAppointment row = choosePrimaryServiceAppointment(rows);
        ServiceAppointmentSummaryDTO dto = new ServiceAppointmentSummaryDTO();
        dto.id = row.Id;
        dto.appointmentNumber = row.AppointmentNumber;
        dto.status = row.Status;
        dto.scheduledStart = row.SchedStartTime == null ? null : row.SchedStartTime.format('M/d/yyyy h:mm a');
        return dto;
    }

    private static List<ActivityDTO> buildActivity(
        Purchase_Order__c po,
        TakeoffSummaryDTO takeoff,
        WorkOrderSummaryDTO wo,
        ServiceAppointmentSummaryDTO sa
    ) {
        List<ActivityDTO> rows = new List<ActivityDTO>();
        if (po == null) {
            return rows;
        }

        Set<Id> relatedIds = new Set<Id>{ po.Id };
        Map<Id, String> relatedLabels = new Map<Id, String>{ po.Id => 'Purchase Order' };
        if (takeoff != null && !String.isBlank(takeoff.id)) {
            relatedIds.add((Id) takeoff.id);
            relatedLabels.put((Id) takeoff.id, 'Takeoff');
        }
        if (wo != null && !String.isBlank(wo.id)) {
            relatedIds.add((Id) wo.id);
            relatedLabels.put((Id) wo.id, 'WorkOrder');
        }
        if (sa != null && !String.isBlank(sa.id)) {
            relatedIds.add((Id) sa.id);
            relatedLabels.put((Id) sa.id, 'Service Appointment');
        }

        for (Task taskRow : [
            SELECT Id, Subject, Status, ActivityDate, CreatedDate, WhatId
            FROM Task
            WHERE WhatId IN :relatedIds
            ORDER BY ActivityDate DESC NULLS LAST, CreatedDate DESC
            LIMIT 8
        ]) {
            ActivityDTO row = new ActivityDTO();
            row.recordId = taskRow.Id;
            row.label = String.isBlank(taskRow.Subject) ? 'Task' : taskRow.Subject;
            row.detail = valueOrDefault(taskRow.Status, 'Open task') + ' · ' + valueOrDefault(relatedLabels.get(taskRow.WhatId), 'Related record');
            row.whenLabel = taskRow.ActivityDate != null
                ? String.valueOf(taskRow.ActivityDate)
                : (taskRow.CreatedDate == null ? 'Unknown' : taskRow.CreatedDate.format('M/d/yyyy h:mm a'));
            row.relatedLabel = relatedLabels.get(taskRow.WhatId);
            row.tone = taskRow.Status != null && taskRow.Status.toLowerCase().contains('complete') ? 'green' : 'blue';
            rows.add(row);
        }

        for (Event eventRow : [
            SELECT Id, Subject, Type, ActivityDateTime, CreatedDate, WhatId
            FROM Event
            WHERE WhatId IN :relatedIds
            ORDER BY ActivityDateTime DESC NULLS LAST, CreatedDate DESC
            LIMIT 8
        ]) {
            ActivityDTO row = new ActivityDTO();
            row.recordId = eventRow.Id;
            row.label = String.isBlank(eventRow.Subject) ? 'Calendar Event' : eventRow.Subject;
            row.detail = valueOrDefault(eventRow.Type, 'Event') + ' · ' + valueOrDefault(relatedLabels.get(eventRow.WhatId), 'Related record');
            row.whenLabel = eventRow.ActivityDateTime != null
                ? eventRow.ActivityDateTime.format('M/d/yyyy h:mm a')
                : (eventRow.CreatedDate == null ? 'Unknown' : eventRow.CreatedDate.format('M/d/yyyy h:mm a'));
            row.relatedLabel = relatedLabels.get(eventRow.WhatId);
            row.tone = 'aqua';
            rows.add(row);
        }

        if (rows.isEmpty()) {
            rows.add(activityRow((String) po.Id, 'Purchase Order Created', valueOrDefault(po.Status__c, 'Status not set'), po.CreatedDate == null ? 'Unknown' : po.CreatedDate.format('M/d/yyyy h:mm a'), 'blue'));
            if (takeoff != null) {
                rows.add(activityRow(takeoff.id, 'Takeoff Linked', valueOrDefault(takeoff.status, 'Status not set'), valueOrDefault(takeoff.scheduledDate, 'Not scheduled'), 'amber'));
            }
            if (wo != null) {
                rows.add(activityRow(wo.id, 'WorkOrder Linked', valueOrDefault(wo.status, 'Status not set'), valueOrDefault(wo.workOrderNumber, 'No work order number'), 'purple'));
            }
            if (sa != null) {
                rows.add(activityRow(sa.id, 'Service Appointment Linked', valueOrDefault(sa.status, 'Status not set'), valueOrDefault(sa.scheduledStart, 'Not scheduled'), 'green'));
            }
        }
        return rows;
    }

    private static ActivityDTO activityRow(String recordId, String label, String detail, String whenLabel, String tone) {
        ActivityDTO row = new ActivityDTO();
        row.recordId = recordId;
        row.label = label;
        row.detail = detail;
        row.whenLabel = whenLabel;
        row.tone = tone;
        return row;
    }

    private static String buildWorkOrderDescription(Purchase_Order__c po, Takeoff__c takeoff) {
        List<String> lines = new List<String>();
        lines.add('Builder PO: ' + valueOrDash(po.PO_Number__c));
        lines.add('Builder: ' + valueOrDash(po.Builder_Account__r == null ? null : po.Builder_Account__r.Name));
        lines.add('Community: ' + valueOrDash(po.Community__r == null ? null : po.Community__r.Name));
        lines.add('Lot: ' + valueOrDash(po.Lot__r == null ? null : po.Lot__r.Name));
        if (po.Quantity__c != null) {
            lines.add('Requested Quantity: ' + String.valueOf(po.Quantity__c));
        }
        if (takeoff != null) {
            lines.add('Takeoff: ' + valueOrDash(takeoff.Name) + ' (' + valueOrDash(takeoff.Status__c) + ')');
        }
        return String.join(lines, '\n');
    }

    private static String buildServiceAppointmentDescription(WorkOrder wo) {
        if (wo == null) {
            return null;
        }
        List<String> lines = new List<String>();
        lines.add('Scheduling handoff generated from the LOVING Builder PO workspace.');
        lines.add('WorkOrder: ' + valueOrDash(wo.Subject));
        if (!String.isBlank(wo.Description)) {
            lines.add(wo.Description);
        }
        return String.join(lines, '\n');
    }

    private static String valueOrDash(String input) {
        return String.isBlank(input) ? '—' : input;
    }

    private static List<FieldManagerOptionDTO> loadFieldManagers() {
        List<FieldManagerOptionDTO> results = new List<FieldManagerOptionDTO>();
        List<ServiceResource> resources = [
            SELECT Id, Name, RelatedRecordId, IsActive
            FROM ServiceResource
            WHERE IsActive = true
              AND RelatedRecordId != null
            ORDER BY Name
            LIMIT 200
        ];
        Set<Id> userIds = new Set<Id>();
        for (ServiceResource row : resources) {
            if (row.RelatedRecordId != null && String.valueOf(row.RelatedRecordId).startsWith('005')) {
                userIds.add(row.RelatedRecordId);
            }
        }
        Map<Id, User> usersById = userIds.isEmpty()
            ? new Map<Id, User>()
            : new Map<Id, User>([
                SELECT Id, Name, Title, UserRole.Name, IsActive
                FROM User
                WHERE Id IN :userIds
            ]);

        for (ServiceResource row : resources) {
            User userRow = usersById.get(row.RelatedRecordId);
            if (userRow == null || userRow.IsActive != true) {
                continue;
            }
            String roleName = userRow.UserRole == null ? '' : userRow.UserRole.Name;
            String title = String.isBlank(userRow.Title) ? '' : userRow.Title;
            Boolean isFieldManager = roleName.startsWith('FM') || title.contains('Foreman');
            if (!isFieldManager) {
                continue;
            }
            FieldManagerOptionDTO dto = new FieldManagerOptionDTO();
            dto.userId = userRow.Id;
            dto.serviceResourceId = row.Id;
            dto.name = userRow.Name;
            dto.title = userRow.Title;
            results.add(dto);
        }
        return results;
    }

    private static List<GateCheckDTO> buildGateChecks(Purchase_Order__c po, TakeoffSummaryDTO takeoff, WorkOrderSummaryDTO wo, ServiceAppointmentSummaryDTO sa) {
        List<GateCheckDTO> checks = new List<GateCheckDTO>();
        checks.add(check('Package / BMG matched', po.Package_BMG_Status__c == 'Matched' || po.Package_BMG_Status__c == 'Not Required', po.Package_BMG_Status__c));
        checks.add(check('Takeoff exists', takeoff != null, takeoff == null ? 'Not created' : takeoff.name));
        checks.add(check('Field Manager assigned', takeoff != null && !String.isBlank(takeoff.fieldManagerId), takeoff == null ? 'Assign after takeoff creation' : valueOrDefault(takeoff.fieldManagerName, 'Not assigned')));
        checks.add(check('Takeoff approved', takeoff != null && takeoff.status == TAKEOFF_APPROVED, takeoff == null ? 'Pending' : takeoff.status));
        checks.add(check('Production WorkOrder linked', wo != null, wo == null ? 'Not created' : wo.workOrderNumber));
        checks.add(check('Scheduling handoff created', sa != null, sa == null ? 'Not created' : sa.appointmentNumber + ' · ' + sa.status));
        return checks;
    }

    private static GateCheckDTO check(String label, Boolean passed, String detail) {
        GateCheckDTO dto = new GateCheckDTO();
        dto.label = label;
        dto.passed = passed;
        dto.detail = detail;
        return dto;
    }

    @TestVisible
    private static String deriveNextAction(DetailDTO detail) {
        if (detail.serviceAppointment != null && detail.workOrder != null) return 'Open WorkOrder';
        if (detail.workOrder != null) return 'Create Schedule Handoff';
        if (detail.takeoff == null) return 'Create / Open Takeoff';
        if (String.isBlank(detail.takeoff.fieldManagerId)) return 'Assign Field Manager';
        if (detail.takeoff.status != TAKEOFF_APPROVED) return 'Approve Takeoff';
        if (detail.workOrder == null) return 'Create Production WorkOrder';
        return 'Open WorkOrder';
    }

    @TestVisible
    private static String displayStatusLabel(String status) {
        if (status == 'Ready for Takeoff') return 'Awaiting takeoff';
        if (status == 'Takeoff Complete') return 'Ready for WorkOrder handoff';
        if (status == PO_STATUS_WORK_ORDER_CREATED) return 'WorkOrder handoff';
        if (status == PO_STATUS_CLEAR_FOR_SCHEDULE) return 'Ready for scheduling';
        return status;
    }

    @TestVisible
    private static ServiceAppointment choosePrimaryServiceAppointment(List<ServiceAppointment> rows) {
        if (rows == null || rows.isEmpty()) {
            return null;
        }
        ServiceAppointment best = null;
        Integer bestScore = -1;
        for (ServiceAppointment row : rows) {
            Integer score = serviceAppointmentStatusScore(row == null ? null : row.Status);
            if (best == null || score > bestScore) {
                best = row;
                bestScore = score;
                continue;
            }
            if (score == bestScore) {
                Datetime candidate = row == null ? null : row.SchedStartTime;
                Datetime current = best.SchedStartTime;
                if (candidate != null && (current == null || candidate.getTime() > current.getTime())) {
                    best = row;
                }
            }
        }
        return best == null ? rows[0] : best;
    }

    private static Integer serviceAppointmentStatusScore(String status) {
        if (status == SA_STATUS_SCHEDULED) return 4;
        if (status == SA_STATUS_READY) return 3;
        if (status == 'Dispatched' || status == 'In Progress') return 2;
        if (status == SA_STATUS_NONE) return 0;
        return 1;
    }

    private static Takeoff__c latestTakeoff(Id poId) {
        List<Takeoff__c> rows = [
            SELECT Id, Name, Status__c, FM_Assignment__c, FM_Assignment__r.Name,
                   Scheduled_Date__c, Checklist_Complete__c, Eight11_Confirmed__c, Photo_Count__c,
                   Work_Order__c
            FROM Takeoff__c
            WHERE Purchase_Order__c = :poId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Id workOrderRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> infos = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName();
        if (!infos.containsKey(PROD_INSTALL_RT)) {
            throw new AuraHandledException('Production Install WorkOrder record type is missing.');
        }
        return infos.get(PROD_INSTALL_RT).getRecordTypeId();
    }

    private static Id workTypeIdByName(String workTypeName) {
        if (String.isBlank(workTypeName)) {
            return null;
        }
        List<WorkType> rows = [
            SELECT Id
            FROM WorkType
            WHERE Name = :workTypeName
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Id;
    }

    private static Integer workTypeDurationMinutes(Id workTypeId) {
        if (workTypeId == null) {
            return null;
        }
        List<WorkType> rows = [
            SELECT EstimatedDuration
            FROM WorkType
            WHERE Id = :workTypeId
            LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].EstimatedDuration == null) {
            return null;
        }
        return Integer.valueOf(rows[0].EstimatedDuration);
    }

    private static Boolean serviceAppointmentStatusExists(String targetValue) {
        for (Schema.PicklistEntry pe : ServiceAppointment.Status.getDescribe().getPicklistValues()) {
            if (pe.getValue() == targetValue) {
                return true;
            }
        }
        return false;
    }

    private static String labelFor(String communityName, String lotName) {
        if (!String.isBlank(communityName) && !String.isBlank(lotName)) {
            return communityName + ' · ' + lotName;
        }
        if (!String.isBlank(communityName)) {
            return communityName;
        }
        return String.isBlank(lotName) ? 'Unassigned Lot' : lotName;
    }

    private static String valueOrDefault(String value, String fallback) {
        return String.isBlank(value) ? fallback : value;
    }

    private static Decimal deriveSodSquareFootage(Id takeoffId, Decimal fallbackQuantity) {
        Decimal total = 0;
        Boolean foundLine = false;
        for (Takeoff_Line__c line : [
            SELECT Verified_Quantity__c, Measured_Quantity__c, PO_Quantity__c
            FROM Takeoff_Line__c
            WHERE Takeoff__c = :takeoffId
              AND Review_Status__c = 'Approved'
        ]) {
            Decimal qty = line.Verified_Quantity__c;
            if (qty == null) qty = line.Measured_Quantity__c;
            if (qty == null) qty = line.PO_Quantity__c;
            if (qty != null) {
                total += qty;
                foundLine = true;
            }
        }
        if (foundLine && total > 0) {
            return total;
        }
        return fallbackQuantity;
    }
}