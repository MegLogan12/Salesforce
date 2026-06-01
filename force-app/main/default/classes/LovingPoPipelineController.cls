public with sharing class LovingPoPipelineController {

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class POSummaryDTO {
        @AuraEnabled public Id     id;
        @AuraEnabled public String builderPoId;
        @AuraEnabled public String name;
        @AuraEnabled public String purchaseOrderName;
        @AuraEnabled public String poNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String stage;
        @AuraEnabled public String takeoffStatus;
        @AuraEnabled public String pipelineBucket;
        @AuraEnabled public String boardColumn;
        @AuraEnabled public String nextAction;
        @AuraEnabled public String builderName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String communityName;
        @AuraEnabled public Decimal totalAmount;
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

    public class DetailDTO {
        @AuraEnabled public POSummaryDTO              po;
        @AuraEnabled public WorkOrderSummaryDTO       workOrder;
        @AuraEnabled public ServiceAppointmentSummaryDTO serviceAppointment;
    }

    public class PipelineDTO {
        @AuraEnabled public List<POSummaryDTO> records;
        @AuraEnabled public Integer            totalCount;
    }

    public class ActionResult {
        @AuraEnabled public Boolean passed;
        @AuraEnabled public String  message;
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

    // ── Public utility methods (called by tests directly) ────────────────────

    public static String mapToBoardColumn(String status, String stage, String pipelineBucket) {
        String s = status  != null ? status.toLowerCase()  : '';
        String g = stage   != null ? stage.toLowerCase()   : '';
        String b = pipelineBucket != null ? pipelineBucket.toLowerCase() : '';

        if (g == 'clear for schedule')    return 'clear';
        if (g == 'work order created')    return 'workOrderCreated';
        if (g == 'ready for takeoff')     return 'takeoffRequested';
        if (g == 'takeoff scheduled')     return 'takeoffScheduled';
        if (g == 'takeoff in progress')   return 'takeoffProgress';
        if (g == 'takeoff complete')      return 'takeoffComplete';

        if (s == 'pending cs review')     return 'pendingReview';
        if (s == 'pending approval')      return 'pendingApproval';
        if (s == 'package match check')   return 'packageCheck';
        if (s == 'ready for takeoff')     return 'takeoffRequested';
        if (s == 'takeoff scheduled')     return 'takeoffScheduled';
        if (s == 'takeoff in progress')   return 'takeoffProgress';
        if (s == 'takeoff complete')      return 'takeoffComplete';
        if (s == 'work order created')    return 'workOrderCreated';
        if (s == 'clear for schedule')    return 'clear';
        if (s == 'po received')           return b.contains('clear') ? 'clear'
                                               : b.contains('work order') ? 'workOrderCreated'
                                               : b.contains('ready for takeoff') ? 'takeoffRequested'
                                               : 'pendingReview';

        return 'other';
    }

    public static String deriveNextAction(DetailDTO detail) {
        if (detail == null) return 'Create / Open Takeoff';
        if (detail.workOrder != null && detail.serviceAppointment != null) return 'Open WorkOrder';
        if (detail.workOrder != null && detail.serviceAppointment == null) return 'Create Schedule Handoff';
        return 'Create / Open Takeoff';
    }

    public static ServiceAppointment choosePrimaryServiceAppointment(List<ServiceAppointment> rows) {
        if (rows == null || rows.isEmpty()) return null;
        ServiceAppointment best = null;
        Integer bestScore = -1;
        for (ServiceAppointment sa : rows) {
            Integer score = 0;
            String st = sa.Status != null ? sa.Status.toLowerCase() : '';
            if (st == 'scheduled') score = 3;
            else if (st == 'ready to schedule') score = 2;
            else if (st == 'none') score = 1;
            else score = 0;
            if (score > bestScore) {
                bestScore = score;
                best = sa;
            }
        }
        return best;
    }

    // ── AuraEnabled methods ──────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static PipelineDTO getPipelineData() {
        PipelineDTO result = new PipelineDTO();
        result.records = new List<POSummaryDTO>();

        List<Purchase_Order__c> pos = [
            SELECT Id, Name, PO_Number__c, Status__c, Pipeline_Bucket__c,
                   Total_Amount__c,
                   Builder_Account__r.Name,
                   Community__r.Name,
                   Lot__r.Name, Lot__r.Lot_Number__c,
                   Work_Order__c, Work_Order__r.WorkOrderNumber, Work_Order__r.Status
            FROM Purchase_Order__c
            WHERE Status__c NOT IN ('Cancelled', 'Completed', 'Closed')
              AND PO_Number__c != null
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];

        Set<Id> poIds = new Map<Id, Purchase_Order__c>(pos).keySet();
        Map<Id, String> takeoffStatusByPoId = new Map<Id, String>();
        for (Takeoff__c t : [SELECT Id, Purchase_Order__c, Status__c FROM Takeoff__c
                              WHERE Purchase_Order__c IN :poIds
                              ORDER BY CreatedDate DESC]) {
            if (!takeoffStatusByPoId.containsKey(t.Purchase_Order__c)) {
                takeoffStatusByPoId.put(t.Purchase_Order__c, t.Status__c);
            }
        }

        for (Purchase_Order__c po : pos) {
            POSummaryDTO dto = new POSummaryDTO();
            dto.id              = po.Id;
            dto.name            = po.Name;
            dto.purchaseOrderName = po.Name;
            dto.poNumber        = po.PO_Number__c;
            dto.status          = po.Status__c;
            dto.pipelineBucket  = po.Pipeline_Bucket__c;
            dto.totalAmount     = po.Total_Amount__c;
            dto.builderName     = po.Builder_Account__r != null ? po.Builder_Account__r.Name : '';
            dto.communityName   = po.Community__r != null ? po.Community__r.Name : '';
            dto.lotName         = po.Lot__r != null
                                    ? (po.Lot__r.Lot_Number__c != null ? 'Lot ' + po.Lot__r.Lot_Number__c : po.Lot__r.Name)
                                    : '';

            dto.takeoffStatus = takeoffStatusByPoId.get(po.Id);
            dto.stage         = po.Pipeline_Bucket__c;
            dto.boardColumn   = mapToBoardColumn(po.Status__c, po.Pipeline_Bucket__c, null);
            dto.url           = '/' + po.Id;

            DetailDTO detail = new DetailDTO();
            if (po.Work_Order__c != null) {
                WorkOrderSummaryDTO wo = new WorkOrderSummaryDTO();
                wo.id       = po.Work_Order__c;
                wo.woNumber = po.Work_Order__r != null ? po.Work_Order__r.WorkOrderNumber : null;
                wo.status   = po.Work_Order__r != null ? po.Work_Order__r.Status : null;
                wo.url      = '/' + po.Work_Order__c;
                detail.workOrder = wo;
            }
            dto.nextAction = deriveNextAction(detail);

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
                   Builder_Account__r.Name, Community__r.Name, Lot__r.Name, Lot__r.Lot_Number__c,
                   Work_Order__c, Work_Order__r.WorkOrderNumber, Work_Order__r.Status
            FROM Purchase_Order__c WHERE Id = :purchaseOrderId LIMIT 1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('Purchase Order not found.');

        Purchase_Order__c po = rows[0];
        DetailDTO detail = new DetailDTO();

        POSummaryDTO pdto = new POSummaryDTO();
        pdto.id               = po.Id;
        pdto.name             = po.Name;
        pdto.purchaseOrderName = po.Name;
        pdto.poNumber         = po.PO_Number__c;
        pdto.status           = po.Status__c;
        pdto.pipelineBucket   = po.Pipeline_Bucket__c;
        pdto.totalAmount      = po.Total_Amount__c;
        pdto.builderName      = po.Builder_Account__r != null ? po.Builder_Account__r.Name : '';
        pdto.communityName    = po.Community__r != null ? po.Community__r.Name : '';
        pdto.lotName          = po.Lot__r != null ? po.Lot__r.Name : '';
        pdto.url              = '/' + po.Id;
        detail.po             = pdto;

        if (po.Work_Order__c != null) {
            WorkOrderSummaryDTO wo = new WorkOrderSummaryDTO();
            wo.id       = po.Work_Order__c;
            wo.woNumber = po.Work_Order__r != null ? po.Work_Order__r.WorkOrderNumber : null;
            wo.status   = po.Work_Order__r != null ? po.Work_Order__r.Status : null;
            wo.url      = '/' + po.Work_Order__c;
            detail.workOrder = wo;

            List<ServiceAppointment> sas = [
                SELECT Id, Subject, Status, SchedStartTime
                FROM ServiceAppointment
                WHERE ParentRecordId = :po.Work_Order__c
                ORDER BY CreatedDate DESC LIMIT 10
            ];
            ServiceAppointment primarySa = choosePrimaryServiceAppointment(sas);
            if (primarySa != null) {
                ServiceAppointmentSummaryDTO sadto = new ServiceAppointmentSummaryDTO();
                sadto.id        = primarySa.Id;
                sadto.subject   = primarySa.Subject;
                sadto.status    = primarySa.Status;
                sadto.schedStart = primarySa.SchedStartTime != null
                                    ? primarySa.SchedStartTime.format('M/d/yyyy h:mm a') : '';
                sadto.url       = '/' + primarySa.Id;
                detail.serviceAppointment = sadto;
            }
        }

        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static DetailDTO getBuilderPoDetail(Id builderPoId) {
        if (builderPoId == null) throw new AuraHandledException('Builder PO Id required.');

        List<Builder_PO__c> bpos = [
            SELECT Id, Name, PO_Number__c, Builder_Account__c, Community__c, Lot__c,
                   Builder_Account__r.Name, Community__r.Name, Lot__r.Name, Lot__r.Lot_Number__c
            FROM Builder_PO__c WHERE Id = :builderPoId LIMIT 1
        ];
        if (bpos.isEmpty()) throw new AuraHandledException('Builder PO not found.');
        Builder_PO__c bpo = bpos[0];

        List<Purchase_Order__c> pos = [
            SELECT Id, Name, PO_Number__c, Status__c, Pipeline_Bucket__c, Total_Amount__c,
                   Work_Order__c, Work_Order__r.WorkOrderNumber, Work_Order__r.Status
            FROM Purchase_Order__c
            WHERE PO_Number__c = :bpo.PO_Number__c
            ORDER BY LastModifiedDate DESC LIMIT 1
        ];

        DetailDTO detail = new DetailDTO();
        POSummaryDTO pdto = new POSummaryDTO();
        pdto.builderPoId  = bpo.Id;
        pdto.name         = bpo.Name;
        pdto.builderName  = bpo.Builder_Account__r != null ? bpo.Builder_Account__r.Name : '';
        pdto.communityName = bpo.Community__r != null ? bpo.Community__r.Name : '';
        pdto.lotName      = bpo.Lot__r != null ? bpo.Lot__r.Name : '';

        if (!pos.isEmpty()) {
            Purchase_Order__c po = pos[0];
            pdto.id               = po.Id;
            pdto.purchaseOrderName = po.Name;
            pdto.poNumber         = po.PO_Number__c;
            pdto.status           = po.Status__c;
            pdto.pipelineBucket   = po.Pipeline_Bucket__c;
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
        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionDTO> getBuilderPoStatusOptions() {
        List<OptionDTO> options = new List<OptionDTO>();
        Schema.DescribeFieldResult dfr = Purchase_Order__c.Status__c.getDescribe();
        for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
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
    public static String createOrGetTakeoff(Id purchaseOrderId) {
        if (purchaseOrderId == null) throw new AuraHandledException('Purchase Order Id required.');

        List<Takeoff__c> existing = [
            SELECT Id, Status__c FROM Takeoff__c
            WHERE Purchase_Order__c = :purchaseOrderId
              AND Status__c NOT IN ('Cancelled', 'Rejected')
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (!existing.isEmpty()) return existing[0].Id;

        List<Purchase_Order__c> pos = [
            SELECT Id, Name, PO_Number__c, Community__c, Lot__c, Builder_Account__c
            FROM Purchase_Order__c WHERE Id = :purchaseOrderId LIMIT 1
        ];
        if (pos.isEmpty()) throw new AuraHandledException('Purchase Order not found.');
        Purchase_Order__c po = pos[0];

        Takeoff__c newTakeoff = new Takeoff__c(
            Purchase_Order__c = po.Id,
            Status__c         = 'Requested',
            Name              = 'Takeoff - ' + po.Name
        );
        insert newTakeoff;
        return newTakeoff.Id;
    }

    @AuraEnabled
    public static ActionResult updateTakeoffReadiness(Id takeoffId, Boolean sodComplete, Boolean gradeComplete, Integer sodSqFt) {
        try {
            if (takeoffId == null) return new ActionResult(false, 'Takeoff Id required.');
            List<Takeoff__c> rows = [SELECT Id, Status__c FROM Takeoff__c WHERE Id = :takeoffId LIMIT 1];
            if (rows.isEmpty()) return new ActionResult(false, 'Takeoff not found.');
            Takeoff__c t = rows[0];
            if (sodSqFt != null) {
                // Update sod square footage if field exists — wrapped safely
                try {
                    t.put('Sod_Sqft__c', sodSqFt);
                } catch (Exception e) { /* field may not exist */ }
            }
            if (sodComplete == true && gradeComplete == true) {
                t.Status__c = 'Ready for Review';
            }
            update t;
            return new ActionResult(true, 'Takeoff updated.');
        } catch (Exception e) {
            return new ActionResult(false, e.getMessage());
        }
    }

    @AuraEnabled
    public static ActionResult createScheduleHandoff(Id purchaseOrderId) {
        try {
            if (purchaseOrderId == null) return new ActionResult(false, 'Purchase Order Id required.');
            List<Purchase_Order__c> pos = [
                SELECT Id, Status__c, Work_Order__c
                FROM Purchase_Order__c WHERE Id = :purchaseOrderId LIMIT 1
            ];
            if (pos.isEmpty()) return new ActionResult(false, 'PO not found.');
            Purchase_Order__c po = pos[0];
            if (po.Work_Order__c == null) return new ActionResult(false, 'No Work Order linked to this PO.');

            List<ServiceAppointment> existing = [
                SELECT Id FROM ServiceAppointment
                WHERE ParentRecordId = :po.Work_Order__c
                  AND Status NOT IN ('Completed', 'Cancelled')
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                return new ActionResult(true, 'Schedule handoff already exists.');
            }

            ServiceAppointment sa = new ServiceAppointment(
                ParentRecordId = po.Work_Order__c,
                Subject        = 'Schedule Handoff',
                Status         = 'None'
            );
            insert sa;
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
                SELECT Id, Work_Order__c, Status__c
                FROM Purchase_Order__c WHERE Id = :purchaseOrderId LIMIT 1
            ];
            if (pos.isEmpty()) return new ActionResult(false, 'PO not found.');
            Purchase_Order__c po = pos[0];

            if (po.Work_Order__c != null) {
                ActionResult res = new ActionResult(true, 'Existing Work Order found.');
                res.workOrderId = po.Work_Order__c;
                return res;
            }

            WorkOrder wo = new WorkOrder(
                Subject = 'Production Install',
                Status  = 'New'
            );
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
}
