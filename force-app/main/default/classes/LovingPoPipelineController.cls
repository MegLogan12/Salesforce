public with sharing class LovingPoPipelineController {

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class TakeoffSummaryDTO {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Id     fieldManagerId;
        @AuraEnabled public String scheduledDateLabel;
        @AuraEnabled public String url;
    }

    public class WorkOrderSummaryDTO {
        @AuraEnabled public Id     id;
        @AuraEnabled public String woNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String url;
    }

    public class ServiceAppointmentSummaryDTO {
        @AuraEnabled public Id     id;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String schedStart;
        @AuraEnabled public String url;
    }

    public class ActivityDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String detail;
        @AuraEnabled public String dateLabel;
        @AuraEnabled public String activityType;
        @AuraEnabled public String url;
    }

    public class PoCardDTO {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String builderPoId;
        @AuraEnabled public String poNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String stage;
        @AuraEnabled public String takeoffStatus;
        @AuraEnabled public String boardColumn;
        @AuraEnabled public String nextAction;
        @AuraEnabled public String builderName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String communityName;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String url;
    }

    public class DetailDTO {
        @AuraEnabled public PoCardDTO                    po;
        @AuraEnabled public TakeoffSummaryDTO            takeoff;
        @AuraEnabled public WorkOrderSummaryDTO          workOrder;
        @AuraEnabled public ServiceAppointmentSummaryDTO serviceAppointment;
        @AuraEnabled public List<ActivityDTO>            activity;
    }

    public class PipelineDTO {
        @AuraEnabled public List<PoCardDTO> records;
        @AuraEnabled public Integer         totalCount;
    }

    public class ActionResult {
        @AuraEnabled public Boolean passed;
        @AuraEnabled public String  message;
        @AuraEnabled public String  newStatus;
        @AuraEnabled public Id      workOrderId;
        @AuraEnabled public Id      takeoffId;

        public ActionResult(Boolean passed, String message) {
            this.passed  = passed;
            this.message = message;
        }
    }

    public class OptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    // ── Public utility methods ────────────────────────────────────────────────

    public static String mapToBoardColumn(String status, String stage, String pipelineBucket) {
        String s = status  != null ? status.toLowerCase()  : '';
        String g = stage   != null ? stage.toLowerCase()   : '';

        if (g == 'clear for schedule')    return 'clear';
        if (g == 'work order created')    return 'workOrderCreated';
        if (g == 'takeoff complete')      return 'takeoffComplete';
        if (g == 'takeoff in progress')   return 'takeoffProgress';
        if (g == 'takeoff scheduled')     return 'takeoffScheduled';
        if (g == 'ready for takeoff')     return 'takeoffRequested';
        if (g == 'package match check')   return 'packageCheck';
        if (g == 'pending approval')      return 'pendingApproval';
        if (g == 'pending cs review')     return 'pendingReview';

        if (s == 'clear for schedule')    return 'clear';
        if (s == 'work order created')    return 'workOrderCreated';
        if (s == 'takeoff complete')      return 'takeoffComplete';
        if (s == 'takeoff in progress')   return 'takeoffProgress';
        if (s == 'takeoff scheduled')     return 'takeoffScheduled';
        if (s == 'ready for takeoff')     return 'takeoffRequested';
        if (s == 'package match check')   return 'packageCheck';
        if (s == 'pending approval')      return 'pendingApproval';
        if (s == 'pending cs review')     return 'pendingReview';

        return 'other';
    }

    public static String displayStatusLabel(String status) {
        if (status == null) return '';
        if (status == 'Ready for Takeoff')  return 'Awaiting takeoff';
        if (status == 'Takeoff Complete')   return 'Ready for WorkOrder handoff';
        if (status == 'Work Order Created') return 'WorkOrder handoff';
        if (status == 'Clear for Schedule') return 'Ready for scheduling';
        return status;
    }

    public static String deriveNextAction(DetailDTO detail) {
        if (detail == null) return 'Create / Open Takeoff';

        if (detail.workOrder != null) {
            return detail.serviceAppointment != null ? 'Open WorkOrder' : 'Create Schedule Handoff';
        }

        if (detail.takeoff != null) {
            if (detail.takeoff.status == 'Approved') return 'Create Production WorkOrder';
            if (detail.takeoff.fieldManagerId != null) return 'Approve Takeoff';
            return 'Assign Field Manager';
        }

        return 'Create / Open Takeoff';
    }

    public static ServiceAppointment choosePrimaryServiceAppointment(List<ServiceAppointment> rows) {
        if (rows == null || rows.isEmpty()) return null;
        ServiceAppointment best = null;
        Integer bestScore = -1;
        Long bestTime = -1;
        for (ServiceAppointment sa : rows) {
            String st = sa.Status != null ? sa.Status.toLowerCase() : '';
            Integer score;
            if (st == 'scheduled')          score = 3;
            else if (st == 'dispatched')    score = 2;
            else if (st == 'ready to schedule') score = 2;
            else if (st == 'none')          score = 1;
            else                            score = 0;

            Long saTime = sa.SchedStartTime != null ? sa.SchedStartTime.getTime() : 0;
            if (score > bestScore || (score == bestScore && saTime > bestTime)) {
                bestScore = score;
                bestTime  = saTime;
                best      = sa;
            }
        }
        return best;
    }

    // ── AuraEnabled methods ───────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static PipelineDTO getPipelineData() {
        PipelineDTO result = new PipelineDTO();
        result.records = new List<PoCardDTO>();

        List<Purchase_Order__c> pos = [
            SELECT Id, Name, PO_Number__c, Status__c, Pipeline_Bucket__c, Total_Amount__c,
                   Builder_Account__r.Name, Community__r.Name,
                   Lot__r.Name, Lot__r.Lot_Number__c,
                   Work_Order__c, Work_Order__r.WorkOrderNumber, Work_Order__r.Status,
                   Takeoff_Status__c
            FROM Purchase_Order__c
            WHERE Status__c NOT IN ('Cancelled', 'Completed', 'Closed')
              AND PO_Number__c != null
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];

        // Load Builder PO numbers by PO number for builderPoId mapping
        Set<String> poNumbers = new Set<String>();
        for (Purchase_Order__c po : pos) {
            if (po.PO_Number__c != null) poNumbers.add(po.PO_Number__c);
        }
        Map<String, Id> builderPoByNumber = new Map<String, Id>();
        for (Builder_PO__c bpo : [SELECT Id, PO_Number__c FROM Builder_PO__c WHERE PO_Number__c IN :poNumbers]) {
            if (!builderPoByNumber.containsKey(bpo.PO_Number__c)) {
                builderPoByNumber.put(bpo.PO_Number__c, bpo.Id);
            }
        }

        for (Purchase_Order__c po : pos) {
            PoCardDTO dto  = new PoCardDTO();
            dto.id         = po.Id;
            dto.name       = po.PO_Number__c != null ? po.PO_Number__c : po.Name;
            dto.poNumber   = po.PO_Number__c;
            dto.status     = po.Status__c;
            dto.stage      = po.Pipeline_Bucket__c;
            dto.takeoffStatus = po.Takeoff_Status__c;
            dto.totalAmount   = po.Total_Amount__c;
            dto.builderName   = po.Builder_Account__r != null ? po.Builder_Account__r.Name : '';
            dto.communityName = po.Community__r       != null ? po.Community__r.Name       : '';
            dto.lotName       = po.Lot__r             != null
                                  ? (po.Lot__r.Lot_Number__c != null ? 'Lot ' + po.Lot__r.Lot_Number__c : po.Lot__r.Name)
                                  : '';
            dto.builderPoId = po.PO_Number__c != null && builderPoByNumber.containsKey(po.PO_Number__c)
                              ? builderPoByNumber.get(po.PO_Number__c) : null;
            dto.boardColumn = mapToBoardColumn(po.Status__c, po.Pipeline_Bucket__c, null);
            dto.url         = '/' + po.Id;

            DetailDTO det = new DetailDTO();
            if (po.Work_Order__c != null) {
                WorkOrderSummaryDTO wo = new WorkOrderSummaryDTO();
                wo.id       = po.Work_Order__c;
                wo.woNumber = po.Work_Order__r != null ? po.Work_Order__r.WorkOrderNumber : null;
                wo.status   = po.Work_Order__r != null ? po.Work_Order__r.Status : null;
                det.workOrder = wo;
            }
            dto.nextAction = deriveNextAction(det);

            result.records.add(dto);
        }

        result.totalCount = result.records.size();
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static DetailDTO getPoDetail(Id purchaseOrderId) {
        if (purchaseOrderId == null) throw new AuraHandledException('Purchase Order Id required.');

        List<Purchase_Order__c> rows = [
            SELECT Id, Name, PO_Number__c, Status__c, Pipeline_Bucket__c, Total_Amount__c,
                   Takeoff_Status__c, CreatedDate,
                   Builder_Account__r.Name, Community__r.Name,
                   Lot__r.Name, Lot__r.Lot_Number__c,
                   Work_Order__c, Work_Order__r.WorkOrderNumber, Work_Order__r.Status
            FROM Purchase_Order__c WHERE Id = :purchaseOrderId LIMIT 1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('Purchase Order not found.');
        Purchase_Order__c po = rows[0];

        DetailDTO detail = buildPoDetail(po);

        // Activity: Tasks + Events related to this PO
        List<ActivityDTO> activities = new List<ActivityDTO>();

        for (Task t : [SELECT Id, Subject, Status, ActivityDate, CreatedDate FROM Task WHERE WhatId = :purchaseOrderId ORDER BY ActivityDate DESC LIMIT 20]) {
            ActivityDTO a = new ActivityDTO();
            a.label        = t.Subject != null ? t.Subject : '(No subject)';
            a.detail       = t.Status != null ? t.Status : '';
            a.dateLabel    = t.ActivityDate != null ? t.ActivityDate.format() : '';
            a.activityType = 'Task';
            a.url          = '/' + t.Id;
            activities.add(a);
        }

        for (Event e : [SELECT Id, Subject, StartDateTime FROM Event WHERE WhatId = :purchaseOrderId ORDER BY StartDateTime DESC LIMIT 20]) {
            ActivityDTO a = new ActivityDTO();
            a.label        = e.Subject != null ? e.Subject : '(No subject)';
            a.detail       = e.StartDateTime != null ? e.StartDateTime.format('M/d/yyyy') : '';
            a.dateLabel    = a.detail;
            a.activityType = 'Event';
            a.url          = '/' + e.Id;
            activities.add(a);
        }

        // Fallback activity row always present
        ActivityDTO created = new ActivityDTO();
        created.label        = 'Purchase Order Created';
        created.detail       = 'Status: ' + (po.Status__c != null ? po.Status__c : '');
        created.dateLabel    = po.CreatedDate != null ? po.CreatedDate.format('M/d/yyyy') : '';
        created.activityType = 'Milestone';
        activities.add(created);

        detail.activity = activities;
        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static DetailDTO getBuilderPoDetail(Id builderPoId) {
        if (builderPoId == null) throw new AuraHandledException('Builder PO Id required.');

        List<Builder_PO__c> bpos = [
            SELECT Id, Name, PO_Number__c,
                   Builder_Account__r.Name, Community__r.Name,
                   Lot__r.Name, Lot__r.Lot_Number__c
            FROM Builder_PO__c WHERE Id = :builderPoId LIMIT 1
        ];
        if (bpos.isEmpty()) throw new AuraHandledException('Builder PO not found.');
        Builder_PO__c bpo = bpos[0];

        List<Purchase_Order__c> pos = [
            SELECT Id, Name, PO_Number__c, Status__c, Pipeline_Bucket__c, Total_Amount__c,
                   Takeoff_Status__c, CreatedDate,
                   Work_Order__c, Work_Order__r.WorkOrderNumber, Work_Order__r.Status
            FROM Purchase_Order__c
            WHERE PO_Number__c = :bpo.PO_Number__c
            ORDER BY LastModifiedDate DESC LIMIT 1
        ];

        DetailDTO detail = new DetailDTO();
        PoCardDTO pdto = new PoCardDTO();
        pdto.builderPoId  = bpo.Id;
        pdto.name         = bpo.Name;
        pdto.builderName  = bpo.Builder_Account__r != null ? bpo.Builder_Account__r.Name : '';
        pdto.communityName = bpo.Community__r      != null ? bpo.Community__r.Name       : '';
        pdto.lotName      = bpo.Lot__r             != null ? bpo.Lot__r.Name             : '';

        if (!pos.isEmpty()) {
            Purchase_Order__c po = pos[0];
            pdto.id               = po.Id;
            pdto.poNumber         = po.PO_Number__c;
            pdto.status           = po.Status__c;
            pdto.stage            = po.Pipeline_Bucket__c;
            pdto.takeoffStatus    = po.Takeoff_Status__c;
            pdto.totalAmount      = po.Total_Amount__c;
            pdto.url              = '/' + po.Id;

            if (po.Work_Order__c != null) {
                WorkOrderSummaryDTO wo = new WorkOrderSummaryDTO();
                wo.id       = po.Work_Order__c;
                wo.woNumber = po.Work_Order__r != null ? po.Work_Order__r.WorkOrderNumber : null;
                wo.status   = po.Work_Order__r != null ? po.Work_Order__r.Status : null;
                wo.url      = '/' + po.Work_Order__c;
                detail.workOrder = wo;
            }
        }
        detail.po = pdto;
        detail.activity = new List<ActivityDTO>();
        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static DetailDTO getTakeoffDetail(Id takeoffId) {
        if (takeoffId == null) throw new AuraHandledException('Takeoff Id required.');

        List<Takeoff__c> rows = [
            SELECT Id, Name, Status__c, Purchase_Order__c,
                   Purchase_Order__r.Id, Purchase_Order__r.Name,
                   Purchase_Order__r.Status__c, Purchase_Order__r.Pipeline_Bucket__c,
                   Purchase_Order__r.Total_Amount__c
            FROM Takeoff__c WHERE Id = :takeoffId LIMIT 1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('Takeoff not found.');
        Takeoff__c t = rows[0];

        DetailDTO detail = new DetailDTO();

        TakeoffSummaryDTO tDto = new TakeoffSummaryDTO();
        tDto.id     = t.Id;
        tDto.name   = t.Name;
        tDto.status = t.Status__c;
        tDto.url    = '/' + t.Id;
        detail.takeoff = tDto;

        if (t.Purchase_Order__c != null && t.Purchase_Order__r != null) {
            PoCardDTO pdto = new PoCardDTO();
            pdto.id        = t.Purchase_Order__r.Id;
            pdto.name      = t.Purchase_Order__r.Name;
            pdto.status    = t.Purchase_Order__r.Status__c;
            pdto.stage     = t.Purchase_Order__r.Pipeline_Bucket__c;
            pdto.totalAmount = t.Purchase_Order__r.Total_Amount__c;
            pdto.url       = '/' + t.Purchase_Order__r.Id;
            detail.po      = pdto;
        }

        detail.activity = new List<ActivityDTO>();
        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionDTO> getBuilderPoStatusOptions() {
        List<OptionDTO> options = new List<OptionDTO>();
        for (Schema.PicklistEntry e : Purchase_Order__c.Status__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                OptionDTO opt = new OptionDTO();
                opt.label = e.getLabel();
                opt.value = e.getValue();
                options.add(opt);
            }
        }
        return options;
    }

    @AuraEnabled
    public static ActionResult updatePoStatus(Id purchaseOrderId, String newStatus) {
        try {
            if (purchaseOrderId == null) return new ActionResult(false, 'Purchase Order Id required.');
            if (String.isBlank(newStatus)) return new ActionResult(false, 'New status required.');

            List<Purchase_Order__c> pos = [
                SELECT Id, Status__c, Pipeline_Bucket__c, Package_BMG_Status__c,
                       Takeoff_Status__c, Work_Order__c
                FROM Purchase_Order__c WHERE Id = :purchaseOrderId LIMIT 1
            ];
            if (pos.isEmpty()) return new ActionResult(false, 'Purchase Order not found.');
            Purchase_Order__c po = pos[0];

            // Business rule guards
            if (newStatus == 'Ready for Takeoff' && po.Package_BMG_Status__c != 'Matched') {
                return new ActionResult(false, 'Package must be Matched before moving to Ready for Takeoff.');
            }
            if (newStatus == 'Work Order Created' && po.Work_Order__c == null) {
                return new ActionResult(false, 'A Work Order must be linked before setting Work Order Created.');
            }
            if (newStatus == 'Clear for Schedule' && po.Work_Order__c == null) {
                return new ActionResult(false, 'A Work Order must exist before clearing for schedule.');
            }

            po.Status__c = newStatus;
            update po;

            ActionResult res = new ActionResult(true, 'Status updated to ' + newStatus + '.');
            res.newStatus = newStatus;
            return res;
        } catch (Exception e) {
            return new ActionResult(false, e.getMessage());
        }
    }

    @AuraEnabled
    public static ActionResult assignTakeoffFieldManager(Id purchaseOrderId, Id fieldManagerUserId, Date scheduledDate) {
        try {
            if (purchaseOrderId == null || fieldManagerUserId == null) {
                return new ActionResult(false, 'Purchase Order Id and Field Manager are required.');
            }

            List<Takeoff__c> takeoffs = [
                SELECT Id, Status__c
                FROM Takeoff__c
                WHERE Purchase_Order__c = :purchaseOrderId
                  AND Status__c NOT IN ('Cancelled', 'Rejected')
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            if (takeoffs.isEmpty()) return new ActionResult(false, 'No active takeoff found for this PO.');

            Takeoff__c t = takeoffs[0];
            // Set FM and optionally the scheduled date
            try { t.put('Field_Manager__c', fieldManagerUserId); } catch (Exception ex) { /* field may vary */ }
            if (scheduledDate != null) {
                try { t.put('Scheduled_Date__c', scheduledDate); } catch (Exception ex) { /* field may vary */ }
            }
            update t;

            ActionResult res = new ActionResult(true, 'Field Manager assigned.');
            if (scheduledDate == null) {
                res.newStatus = 'Ready for Takeoff';
            }
            return res;
        } catch (Exception e) {
            return new ActionResult(false, e.getMessage());
        }
    }

    @AuraEnabled
    public static ActionResult updateTakeoffReadiness(Id takeoffId, Boolean sodComplete, Boolean gradeComplete, Integer sodSqFt) {
        try {
            if (takeoffId == null) return new ActionResult(false, 'Takeoff Id required.');
            List<Takeoff__c> rows = [SELECT Id, Status__c FROM Takeoff__c WHERE Id = :takeoffId LIMIT 1];
            if (rows.isEmpty()) return new ActionResult(false, 'Takeoff not found.');
            Takeoff__c t = rows[0];
            if (sodSqFt != null) {
                try { t.put('Sod_Sqft__c', sodSqFt); } catch (Exception ex) { /* field may vary */ }
            }
            if (sodComplete == true && gradeComplete == true) {
                t.Status__c = 'Ready for Review';
            }
            update t;
            return new ActionResult(true, 'Takeoff readiness updated.');
        } catch (Exception e) {
            return new ActionResult(false, e.getMessage());
        }
    }

    @AuraEnabled
    public static String createOrGetTakeoff(Id purchaseOrderId) {
        if (purchaseOrderId == null) throw new AuraHandledException('Purchase Order Id required.');

        List<Purchase_Order__c> pos = [
            SELECT Id, Name, PO_Number__c, Package_BMG_Status__c, Community__c, Lot__c, Builder_Account__c
            FROM Purchase_Order__c WHERE Id = :purchaseOrderId LIMIT 1
        ];
        if (pos.isEmpty()) throw new AuraHandledException('Purchase Order not found.');
        Purchase_Order__c po = pos[0];

        if (po.Package_BMG_Status__c != 'Matched') {
            throw new AuraHandledException('Package must be Matched before creating a Takeoff.');
        }
        if (String.isBlank(po.PO_Number__c)) {
            throw new AuraHandledException('Purchase Order must have a PO Number before creating a Takeoff.');
        }

        List<Takeoff__c> existing = [
            SELECT Id FROM Takeoff__c
            WHERE Purchase_Order__c = :purchaseOrderId
              AND Status__c NOT IN ('Cancelled', 'Rejected')
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (!existing.isEmpty()) return existing[0].Id;

        Takeoff__c newTakeoff = new Takeoff__c(
            Purchase_Order__c = po.Id,
            Status__c         = 'Requested',
            Name              = 'Takeoff - ' + po.PO_Number__c
        );
        insert newTakeoff;
        return newTakeoff.Id;
    }

    @AuraEnabled
    public static ActionResult createScheduleHandoff(Id purchaseOrderId) {
        try {
            if (purchaseOrderId == null) return new ActionResult(false, 'Purchase Order Id required.');
            List<Purchase_Order__c> pos = [
                SELECT Id, Work_Order__c FROM Purchase_Order__c WHERE Id = :purchaseOrderId LIMIT 1
            ];
            if (pos.isEmpty()) return new ActionResult(false, 'PO not found.');
            if (pos[0].Work_Order__c == null) return new ActionResult(false, 'No Work Order linked to this PO.');

            List<ServiceAppointment> existing = [
                SELECT Id FROM ServiceAppointment
                WHERE ParentRecordId = :pos[0].Work_Order__c
                  AND Status NOT IN ('Completed', 'Cancelled')
                LIMIT 1
            ];
            if (!existing.isEmpty()) return new ActionResult(true, 'Schedule handoff already exists.');

            insert new ServiceAppointment(
                ParentRecordId = pos[0].Work_Order__c,
                Subject        = 'Schedule Handoff',
                Status         = 'None'
            );
            return new ActionResult(true, 'Schedule handoff created.');
        } catch (Exception e) {
            return new ActionResult(false, e.getMessage());
        }
    }

    @AuraEnabled
    public static ActionResult createProductionWorkOrder(Id purchaseOrderId) {
        try {
            if (purchaseOrderId == null) return new ActionResult(false, 'Purchase Order Id required.');
            List<Purchase_Order__c> pos = [
                SELECT Id, Work_Order__c FROM Purchase_Order__c WHERE Id = :purchaseOrderId LIMIT 1
            ];
            if (pos.isEmpty()) return new ActionResult(false, 'PO not found.');
            Purchase_Order__c po = pos[0];

            if (po.Work_Order__c != null) {
                ActionResult res = new ActionResult(true, 'Existing Work Order found.');
                res.workOrderId = po.Work_Order__c;
                return res;
            }

            // Must have an approved takeoff
            List<Takeoff__c> approved = [
                SELECT Id FROM Takeoff__c
                WHERE Purchase_Order__c = :purchaseOrderId
                  AND Status__c = 'Approved'
                LIMIT 1
            ];
            if (approved.isEmpty()) {
                return new ActionResult(false, 'An approved Takeoff is required before creating a Production Work Order.');
            }

            WorkOrder wo = new WorkOrder(Subject = 'Production Install', Status = 'New');
            insert wo;
            po.Work_Order__c = wo.Id;
            update po;

            ActionResult res = new ActionResult(true, 'Work Order created.');
            res.workOrderId = wo.Id;
            return res;
        } catch (Exception e) {
            return new ActionResult(false, e.getMessage());
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static DetailDTO buildPoDetail(Purchase_Order__c po) {
        DetailDTO detail = new DetailDTO();

        PoCardDTO pdto  = new PoCardDTO();
        pdto.id         = po.Id;
        pdto.name       = po.PO_Number__c != null ? po.PO_Number__c : po.Name;
        pdto.poNumber   = po.PO_Number__c;
        pdto.status     = po.Status__c;
        pdto.stage      = po.Pipeline_Bucket__c;
        pdto.takeoffStatus = po.Takeoff_Status__c;
        pdto.totalAmount = po.Total_Amount__c;
        pdto.builderName  = po.Builder_Account__r != null ? po.Builder_Account__r.Name : '';
        pdto.communityName = po.Community__r      != null ? po.Community__r.Name       : '';
        pdto.lotName      = po.Lot__r             != null ? po.Lot__r.Name             : '';
        pdto.url          = '/' + po.Id;
        detail.po         = pdto;

        // Takeoff
        List<Takeoff__c> takeoffs = [
            SELECT Id, Name, Status__c FROM Takeoff__c
            WHERE Purchase_Order__c = :po.Id AND Status__c NOT IN ('Cancelled','Rejected')
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (!takeoffs.isEmpty()) {
            TakeoffSummaryDTO tDto = new TakeoffSummaryDTO();
            tDto.id     = takeoffs[0].Id;
            tDto.name   = takeoffs[0].Name;
            tDto.status = takeoffs[0].Status__c;
            tDto.url    = '/' + takeoffs[0].Id;
            detail.takeoff = tDto;
        }

        // Work Order + Service Appointment
        if (po.Work_Order__c != null) {
            WorkOrderSummaryDTO wo = new WorkOrderSummaryDTO();
            wo.id       = po.Work_Order__c;
            wo.woNumber = po.Work_Order__r != null ? po.Work_Order__r.WorkOrderNumber : null;
            wo.status   = po.Work_Order__r != null ? po.Work_Order__r.Status : null;
            wo.url      = '/' + po.Work_Order__c;
            detail.workOrder = wo;

            List<ServiceAppointment> sas = [
                SELECT Id, Subject, Status, SchedStartTime
                FROM ServiceAppointment WHERE ParentRecordId = :po.Work_Order__c
                ORDER BY CreatedDate DESC LIMIT 10
            ];
            ServiceAppointment psa = choosePrimaryServiceAppointment(sas);
            if (psa != null) {
                ServiceAppointmentSummaryDTO sadto = new ServiceAppointmentSummaryDTO();
                sadto.id        = psa.Id;
                sadto.subject   = psa.Subject;
                sadto.status    = psa.Status;
                sadto.schedStart = psa.SchedStartTime != null ? psa.SchedStartTime.format('M/d/yyyy h:mm a') : '';
                sadto.url       = '/' + psa.Id;
                detail.serviceAppointment = sadto;
            }
        }

        return detail;
    }
}
