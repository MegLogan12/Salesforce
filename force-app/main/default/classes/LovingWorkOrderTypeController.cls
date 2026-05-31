public with sharing class LovingWorkOrderTypeController {

    public class ActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        public ActionResult(Boolean s, String m) { success = s; message = m; }
    }

    public class StageDTO {
        @AuraEnabled public Integer num;
        @AuraEnabled public String label;
        @AuraEnabled public String sub;
        @AuraEnabled public String state;
    }

    public class GateDTO {
        @AuraEnabled public String label;
        @AuraEnabled public Boolean complete;
        @AuraEnabled public String note;
    }

    public class LineItemDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String lineNumber;
        @AuraEnabled public String description;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal duration;
    }

    public class WoTypeDTO {
        // Standard WorkOrder fields
        @AuraEnabled public String id;
        @AuraEnabled public String woNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public String workTypeName;
        @AuraEnabled public String accountName;
        @AuraEnabled public String contactName;
        @AuraEnabled public String caseId;
        @AuraEnabled public String parentWoId;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Integer lineItemCount;
        @AuraEnabled public String recordTypeName;
        @AuraEnabled public String recordTypeLabel;
        // Standard FSL: ServiceAppointment (first SA on this WO)
        @AuraEnabled public String saId;
        @AuraEnabled public String saNumber;
        @AuraEnabled public String saStatus;
        @AuraEnabled public String saScheduledStart;
        @AuraEnabled public String saScheduledEnd;
        @AuraEnabled public Decimal saDuration;
        @AuraEnabled public String saActualStart;
        @AuraEnabled public String saTerritory;
        // LOVING custom fields (no standard FSL equivalent)
        @AuraEnabled public String woType;
        @AuraEnabled public String division;
        @AuraEnabled public String lotNumber;
        @AuraEnabled public String clientName;
        @AuraEnabled public String communityName;
        @AuraEnabled public String fieldManagerName;
        @AuraEnabled public String foremanName;
        @AuraEnabled public String crewName;
        @AuraEnabled public String poNumber;
        @AuraEnabled public String builderWoNumber;
        @AuraEnabled public Decimal sodSqft;
        @AuraEnabled public Decimal mulchCy;
        @AuraEnabled public Decimal treeQty;
        @AuraEnabled public Decimal plantQty;
        @AuraEnabled public String sodSpecies;
        @AuraEnabled public String scheduledDate;
        @AuraEnabled public Boolean takeoffCompleted;
        @AuraEnabled public Boolean takeoffMismatch;
        @AuraEnabled public String deliveryQcStatus;
        @AuraEnabled public Boolean deliveryQcComplete;
        @AuraEnabled public String jobDescription;
        @AuraEnabled public String redFlagNotes;
        @AuraEnabled public String outsidePoNotes;
        @AuraEnabled public Decimal invoiceAmount;
        @AuraEnabled public String invoiceNotes;
        @AuraEnabled public String jobHealth;
        @AuraEnabled public String scheduleProposalStatus;
        @AuraEnabled public String jobCompleteSubmittedAt;
        @AuraEnabled public Integer photoCount;
        @AuraEnabled public List<LineItemDTO> lineItems;
        // Computed
        @AuraEnabled public List<StageDTO> stages;
        @AuraEnabled public List<GateDTO> gates;
        @AuraEnabled public Boolean canSubmitComplete;
        @AuraEnabled public String submitBlockReason;
    }

    private static String normalizeType(String rawType) {
        String value = String.isBlank(rawType) ? '' : rawType.replace('_', ' ').trim();
        if (value == 'Install') return 'Production Install';
        if (value == 'Plant Sod Install') return 'Production Install';
        if (value == 'Finish Job') return 'Finished Job';
        if (value == 'Finished Job') return 'Finished Job';
        if (value == 'Customer Care' || value == 'Customer Success') return 'Customer Success';
        if (value == 'Aqua New Install') return 'Production Install';
        if (value == 'Aqua Check') return 'Aqua Check';
        if (value == 'Aqua Pickup') return 'Aqua Pickup';
        if (value == 'Aqua Emergency') return 'Aqua Emergency';
        if (value == 'Site Visit') return 'Site Visit';
        if (value == 'Inground Irrigation' || value == 'Temporary Irrigation' || value == 'Irrigation') return 'Irrigation';
        if (value == 'Plant Sod Grading' || value == 'Land Development' || value == 'Grading') return 'Grading';
        if (value == 'Lawn Care') return 'Lawn Care';
        if (value == 'Hardscape') return 'Hardscape';
        if (value == 'Loading Ticket') return 'Loading Ticket';
        if (value == 'QI Closeout') return 'QI Closeout';
        return value;
    }

    @AuraEnabled(cacheable=true)
    public static WoTypeDTO getWorkOrderRecord(String woId) {
        if (String.isBlank(woId)) return null;

        List<WorkOrder> rows = [
            SELECT Id, WorkOrderNumber, Subject, Status, Priority,
                   WorkTypeId, WorkType.Name,
                   AccountId, Account.Name,
                   ContactId, Contact.Name,
                   CaseId, ParentWorkOrderId, Description, TotalPrice,
                   LineItemCount,
                   RecordType.DeveloperName, RecordType.Name,
                   Work_Order_Type__c, Division__c, Lot_Number__c,
                   Client__r.Name, Community__r.Name,
                   Field_Manager__r.Name, Foreman__r.Name,
                   Proposed_Crew__r.Name,
                   PO_Number__c, Builder_WO_Number__c,
                   Sod_Square_Footage__c, Mulch_CY__c,
                   Tree_Quantity__c, Plant_Quantity__c,
                   Scheduled_Date__c,
                   Takeoff_Completed__c, Takeoff_Mismatch__c,
                   Delivery_QC_Status__c, Delivery_QC_Complete__c,
                   Job_Description__c, Red_Flag_Notes__c, Outside_PO_Notes__c,
                   Invoice_Amount__c, Invoice_Notes__c,
                   Job_Health__c, Schedule_Proposal_Status__c,
                   Job_Complete_Submitted_At__c, Sod_Species__c,
                   (SELECT Id, AppointmentNumber, Status,
                           SchedStartTime, SchedEndTime, Duration, ActualStartTime,
                           ServiceTerritoryId, ServiceTerritory.Name
                    FROM ServiceAppointments ORDER BY CreatedDate DESC LIMIT 1),
                   (SELECT Id, LineItemNumber, Description, Status, Duration
                    FROM WorkOrderLineItems LIMIT 10)
            FROM WorkOrder
            WHERE Id = :woId
            LIMIT 1
        ];
        if (rows.isEmpty()) return null;
        WorkOrder wo = rows[0];

        Integer photoCount = [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :wo.Id
        ];

        ServiceAppointment sa = (wo.ServiceAppointments != null && !wo.ServiceAppointments.isEmpty())
            ? wo.ServiceAppointments[0] : null;

        WoTypeDTO dto = new WoTypeDTO();

        // Standard WorkOrder fields first
        dto.id = wo.Id;
        dto.woNumber = wo.WorkOrderNumber;
        dto.subject = wo.Subject;
        dto.status = wo.Status;
        dto.priority = wo.Priority;
        dto.workTypeName = wo.WorkType != null ? wo.WorkType.Name : null;
        dto.accountName = wo.Account != null ? wo.Account.Name : null;
        dto.contactName = wo.Contact != null ? wo.Contact.Name : null;
        dto.caseId = wo.CaseId;
        dto.parentWoId = wo.ParentWorkOrderId;
        dto.description = wo.Description;
        dto.totalPrice = wo.TotalPrice;
        dto.lineItemCount = wo.LineItemCount;
        dto.recordTypeName = wo.RecordType != null ? wo.RecordType.DeveloperName : 'Standard';
        dto.recordTypeLabel = wo.RecordType != null ? wo.RecordType.Name : 'Standard';

        // Standard FSL: ServiceAppointment data
        if (sa != null) {
            dto.saId = sa.Id;
            dto.saNumber = sa.AppointmentNumber;
            dto.saStatus = sa.Status;
            dto.saScheduledStart = sa.SchedStartTime != null ? sa.SchedStartTime.format() : null;
            dto.saScheduledEnd = sa.SchedEndTime != null ? sa.SchedEndTime.format() : null;
            dto.saDuration = sa.Duration;
            dto.saActualStart = sa.ActualStartTime != null ? sa.ActualStartTime.format() : null;
            dto.saTerritory = sa.ServiceTerritory != null ? sa.ServiceTerritory.Name : null;
        }

        // LOVING custom fields (no standard equivalent)
        dto.woType = normalizeType(String.isBlank(wo.Work_Order_Type__c)
            ? (wo.RecordType != null ? wo.RecordType.Name : null)
            : wo.Work_Order_Type__c);
        dto.division = wo.Division__c;
        dto.lotNumber = wo.Lot_Number__c;
        dto.clientName = wo.Client__r != null ? wo.Client__r.Name : null;
        dto.communityName = wo.Community__r != null ? wo.Community__r.Name : null;
        dto.fieldManagerName = wo.Field_Manager__r != null ? wo.Field_Manager__r.Name : null;
        dto.foremanName = wo.Foreman__r != null ? wo.Foreman__r.Name : null;
        dto.crewName = wo.Proposed_Crew__r != null ? wo.Proposed_Crew__r.Name : null;
        dto.poNumber = wo.PO_Number__c;
        dto.builderWoNumber = wo.Builder_WO_Number__c;
        dto.sodSqft = wo.Sod_Square_Footage__c;
        dto.mulchCy = wo.Mulch_CY__c;
        dto.treeQty = wo.Tree_Quantity__c;
        dto.plantQty = wo.Plant_Quantity__c;
        dto.scheduledDate = wo.Scheduled_Date__c != null ? String.valueOf(wo.Scheduled_Date__c) : null;
        dto.takeoffCompleted = wo.Takeoff_Completed__c;
        dto.takeoffMismatch = wo.Takeoff_Mismatch__c == true;
        dto.deliveryQcStatus = wo.Delivery_QC_Status__c;
        dto.deliveryQcComplete = wo.Delivery_QC_Complete__c == true;
        dto.jobDescription = wo.Job_Description__c;
        dto.redFlagNotes = wo.Red_Flag_Notes__c;
        dto.outsidePoNotes = wo.Outside_PO_Notes__c;
        dto.invoiceAmount = wo.Invoice_Amount__c;
        dto.invoiceNotes = wo.Invoice_Notes__c;
        dto.jobHealth = wo.Job_Health__c;
        dto.scheduleProposalStatus = wo.Schedule_Proposal_Status__c;
        dto.jobCompleteSubmittedAt = wo.Job_Complete_Submitted_At__c != null ? wo.Job_Complete_Submitted_At__c.format() : null;
        dto.sodSpecies = wo.Sod_Species__c;
        dto.photoCount = photoCount;
        dto.lineItems = new List<LineItemDTO>();
        if (wo.WorkOrderLineItems != null) {
            for (WorkOrderLineItem woli : wo.WorkOrderLineItems) {
                LineItemDTO li = new LineItemDTO();
                li.id = woli.Id;
                li.lineNumber = woli.LineItemNumber;
                li.description = woli.Description;
                li.status = woli.Status;
                li.duration = woli.Duration;
                dto.lineItems.add(li);
            }
        }

        // FSL fallback: if custom Foreman__c is null, pull first AssignedResource from the SA
        if (sa != null && String.isBlank(dto.foremanName)) {
            List<AssignedResource> arList = [
                SELECT ServiceResource.Name
                FROM AssignedResource
                WHERE ServiceAppointmentId = :sa.Id
                LIMIT 1
            ];
            if (!arList.isEmpty() && arList[0].ServiceResource != null) {
                dto.foremanName = arList[0].ServiceResource.Name;
            }
        }

        dto.stages = buildStages(wo, sa);
        dto.gates = buildGates(wo, photoCount, sa);

        String st = wo.Status;
        Boolean inProgress = (st == 'In Progress');
        dto.canSubmitComplete = inProgress;
        if (!inProgress) {
            dto.submitBlockReason = 'Status must be In Progress to submit job complete. Current: ' + st + '.';
        }

        return dto;
    }

    @AuraEnabled
    public static ActionResult submitJobComplete(String woId) {
        if (String.isBlank(woId)) return new ActionResult(false, 'No record ID provided.');
        WorkOrder wo = [SELECT Id, Status FROM WorkOrder WHERE Id = :woId LIMIT 1];
        if (wo.Status != 'In Progress') {
            return new ActionResult(false, 'Work Order must be In Progress to submit job complete.');
        }
        wo.Status = 'Completed';
        update wo;
        return new ActionResult(true, 'Job complete submitted. Work Order moved to Completed.');
    }

    private static List<GateDTO> buildGates(WorkOrder wo, Integer photoCount, ServiceAppointment sa) {
        List<GateDTO> gates = new List<GateDTO>();
        String rt = normalizeType(String.isBlank(wo.Work_Order_Type__c)
            ? (wo.RecordType != null ? wo.RecordType.Name : null)
            : wo.Work_Order_Type__c);
        Boolean hasSa = (sa != null);
        String saLabel = hasSa ? sa.AppointmentNumber + ' · ' + sa.Status : 'Not yet created';

        if (rt == 'Production Install') {
            gates.add(makeGate('Takeoff complete', wo.Takeoff_Completed__c == true,
                wo.Takeoff_Completed__c == true ? 'Approved' : 'Not yet approved'));
            gates.add(makeGate('Delivery QC', wo.Delivery_QC_Complete__c == true,
                wo.Delivery_QC_Status__c != null ? wo.Delivery_QC_Status__c : 'Not started'));
            gates.add(makeGate('Service Appointment', hasSa, saLabel));
            gates.add(makeGate('Photos uploaded', photoCount > 0, photoCount + ' file(s) attached'));
            gates.add(makeGate('Invoice notes', !String.isBlank(wo.Invoice_Notes__c),
                String.isBlank(wo.Invoice_Notes__c) ? 'No notes yet' : 'Notes present'));
        } else if (rt == 'Finished Job') {
            gates.add(makeGate('Source WO linked', !String.isBlank(wo.ParentWorkOrderId),
                !String.isBlank(wo.ParentWorkOrderId) ? 'Linked' : 'No parent WO'));
            gates.add(makeGate('Service Appointment', hasSa, saLabel));
            gates.add(makeGate('Proof photos', photoCount > 0, photoCount + ' file(s) attached'));
        } else if (rt == 'Warranty') {
            gates.add(makeGate('Case linked', !String.isBlank(wo.CaseId),
                !String.isBlank(wo.CaseId) ? 'Linked' : 'No case linked'));
            gates.add(makeGate('Service Appointment', hasSa, saLabel));
            gates.add(makeGate('Issue photos', photoCount > 0, photoCount + ' file(s) attached'));
        } else if (rt == 'Customer Success') {
            gates.add(makeGate('Case linked', !String.isBlank(wo.CaseId),
                !String.isBlank(wo.CaseId) ? 'Linked' : 'No case linked'));
            gates.add(makeGate('Service Appointment', hasSa, saLabel));
            gates.add(makeGate('Photos', photoCount > 0, photoCount + ' file(s) attached'));
        } else if (rt == 'Aqua Check' || rt == 'Aqua Pickup' || rt == 'Aqua Emergency') {
            gates.add(makeGate('Service Appointment', hasSa, saLabel));
            gates.add(makeGate('Photos uploaded', photoCount > 0, photoCount + ' file(s) attached'));
            gates.add(makeGate('Closeout notes', !String.isBlank(wo.Invoice_Notes__c),
                String.isBlank(wo.Invoice_Notes__c) ? 'No notes yet' : 'Notes present'));
        } else if (rt == 'Lawn Care' || rt == 'Hardscape') {
            gates.add(makeGate('Service Appointment', hasSa, saLabel));
            gates.add(makeGate('Photos uploaded', photoCount > 0, photoCount + ' file(s) attached'));
            gates.add(makeGate('Closeout notes', !String.isBlank(wo.Invoice_Notes__c),
                String.isBlank(wo.Invoice_Notes__c) ? 'No notes yet' : 'Notes present'));
        } else {
            gates.add(makeGate('Service Appointment', hasSa, saLabel));
            gates.add(makeGate('Photos uploaded', photoCount > 0, photoCount + ' file(s) attached'));
        }
        return gates;
    }

    private static GateDTO makeGate(String lbl, Boolean complete, String note) {
        GateDTO g = new GateDTO();
        g.label = lbl;
        g.complete = complete;
        g.note = note;
        return g;
    }

    private static List<StageDTO> buildStages(WorkOrder wo, ServiceAppointment sa) {
        String rt = normalizeType(String.isBlank(wo.Work_Order_Type__c)
            ? (wo.RecordType != null ? wo.RecordType.Name : null)
            : wo.Work_Order_Type__c);
        String st = wo.Status;

        if (rt == 'Production Install') {
            return stagesForIndex(productionInstallIndex(wo, sa),
                new List<String>{'Takeoff Complete','Ready to Schedule','Scheduled','Site Readiness','Released to Field','In Progress','Foreman Closeout Submitted','FM/QI Review','Ready to Invoice','Invoiced','Paid','Closed'},
                new List<String>{'Scope and quantities approved','Scheduling can begin','Crew/date committed','Readiness blockers resolved','Released to the field','Crew is on site','Foreman submitted closeout','FM or QI review is active','Ready for billing handoff','Invoice issued','Payment received','Record closed'});
        }
        if (rt == 'Finished Job') {
            return stagesForStatus(st,
                new List<String>{'Issue Flagged','FM Review','Approved FJ','Scheduled','Completed','Closed'},
                new List<String>{'Foreman flagged','Decision required','Scope confirmed','Return crew assigned','Work finished','Linked to source WO'},
                new List<String>{'New','In Progress','Ready to Schedule','Scheduled','Completed','Closed'});
        }
        if (rt == 'Warranty') {
            return stagesForStatus(st,
                new List<String>{'Case Received','Coverage Review','Approved','Scheduled','Resolved','Closed'},
                new List<String>{'Issue logged','Decision needed','Path selected','FSL appointment','Proof captured','Case updated'},
                new List<String>{'New','In Progress','Ready to Schedule','Scheduled','Completed','Closed'});
        }
        if (rt == 'Customer Success') {
            return stagesForStatus(st,
                new List<String>{'Case Opened','Triaged','Site Visit Scheduled','Site Visit Complete','Outcome Selected','Closed / Converted'},
                new List<String>{'Issue received','Owner + SLA set','Field Manager visit is on the calendar','Visit notes and photos captured','Warranty, Finished Job, Billable, or no-action route chosen','Case path closed or converted'},
                new List<String>{'New','In Progress','Ready to Schedule','Scheduled','Completed','Closed'});
        }
        if (rt == 'Site Visit') {
            return stagesForStatus(st,
                new List<String>{'Requested','Scheduled','In Progress','Report Complete','Closed'},
                new List<String>{'Visit created','Appointment set','Tech on site','Notes + photos','Record closed'},
                new List<String>{'New','Scheduled','Dispatched','Completed','Closed'});
        }
        if (rt == 'Aqua Check') {
            return stagesForStatus(st,
                new List<String>{'Scheduled','On Route','Checked','Notes','Closed'},
                new List<String>{'Daily route assigned','Tech en route','Device verified','Closeout notes','Record closed'},
                new List<String>{'New','Scheduled','In Progress','Completed','Closed'});
        }
        if (rt == 'Aqua Pickup') {
            return stagesForStatus(st,
                new List<String>{'Triggered','Scheduled','Retrieved','Reconciled','Closed'},
                new List<String>{'Lot closed or season end','Tech assigned','Equipment collected','Inventory confirmed','Record closed'},
                new List<String>{'New','Scheduled','In Progress','Completed','Closed'});
        }
        if (rt == 'Aqua Emergency') {
            return stagesForStatus(st,
                new List<String>{'Reported','Dispatched','En Route','Resolved','Closed'},
                new List<String>{'Issue received','Tech assigned','On the way','Issue fixed','Record closed'},
                new List<String>{'New','Scheduled','In Progress','Completed','Closed'});
        }
        if (rt == 'Irrigation') {
            return stagesForIndex(irrigationIndex(wo, sa),
                new List<String>{'Takeoff Complete','Ready to Schedule','Scheduled','Released to Field','In Progress','Tested','Completed','Closed'},
                new List<String>{'Scope approved','Scheduling can begin','Irrigation is on the calendar','Crew released to the field','Work is active','System tested','Install or repair complete','Record closed'});
        }
        if (rt == 'Grading') {
            return stagesForIndex(gradingIndex(wo, sa),
                new List<String>{'Takeoff Complete','Scheduled 24 Hours Before Install','Released to Field','In Progress','Completed','Cleared for Production Install','Closed'},
                new List<String>{'Scope approved','Scheduled one day before the main install','Crew released to the field','Grading is active','Grade complete','Production install can proceed','Record closed'});
        }
        if (rt == 'Lawn Care' || rt == 'Hardscape') {
            return stagesForIndex(generalExecutionIndex(wo, sa),
                new List<String>{'Ready to Schedule','Scheduled','Released to Field','In Progress','Completed','Closed'},
                new List<String>{'Scheduling can begin','Work is on the calendar','Crew released to the field','Work is active','Field work complete','Record closed'});
        }
        return stagesForStatus(st,
            new List<String>{'Takeoff Complete','Ready to Schedule','Scheduled','In Progress','Completed','Closed'},
            new List<String>{'Work order created after takeoff','Prerequisites met','Crew assigned','Active','Work finished','Record closed'},
            new List<String>{'New','Ready to Schedule','Scheduled','In Progress','Completed','Closed'});
    }

    private static Integer productionInstallIndex(WorkOrder wo, ServiceAppointment sa) {
        if (wo.Status == 'Closed') return 11;
        if (wo.Status == 'Paid') return 10;
        if (wo.Status == 'Invoiced') return 9;
        if (wo.Status == 'Approved' || wo.Status == 'Pending Approval' || wo.Status == 'Ready to Invoice') return 8;
        if (wo.Status == 'FM QI Review') return 7;
        if (wo.Status == 'Completed' || wo.Status == 'Pending Closeout') return 6;
        if (wo.Status == 'In Progress') return 5;
        if (sa != null && (sa.Status == 'Dispatched' || sa.Status == 'En Route')) return 4;
        if (wo.Status == 'Scheduled') return 2;
        if (wo.Status == 'Ready to Schedule') return 1;
        return 0;
    }

    private static Integer gradingIndex(WorkOrder wo, ServiceAppointment sa) {
        if (wo.Status == 'Closed') return 6;
        if (wo.Status == 'Approved' || wo.Status == 'Completed' || wo.Status == 'Pending Closeout') return 5;
        if (wo.Status == 'In Progress') return 3;
        if (sa != null && (sa.Status == 'Dispatched' || sa.Status == 'En Route')) return 2;
        if (wo.Status == 'Scheduled') return 1;
        return 0;
    }

    private static Integer irrigationIndex(WorkOrder wo, ServiceAppointment sa) {
        if (wo.Status == 'Closed') return 7;
        if (wo.Status == 'Completed' || wo.Status == 'Pending Closeout') return 6;
        if (wo.Status == 'In Progress') return 4;
        if (sa != null && (sa.Status == 'Dispatched' || sa.Status == 'En Route')) return 3;
        if (wo.Status == 'Scheduled') return 2;
        if (wo.Status == 'Ready to Schedule') return 1;
        return 0;
    }

    private static Integer generalExecutionIndex(WorkOrder wo, ServiceAppointment sa) {
        if (wo.Status == 'Closed') return 5;
        if (wo.Status == 'Completed' || wo.Status == 'Pending Closeout') return 4;
        if (wo.Status == 'In Progress') return 3;
        if (sa != null && (sa.Status == 'Dispatched' || sa.Status == 'En Route')) return 2;
        if (wo.Status == 'Scheduled') return 1;
        return 0;
    }

    private static List<StageDTO> stagesForStatus(String currentStatus,
            List<String> labels, List<String> subs, List<String> statusOrder) {
        Integer currentIdx = statusOrder.indexOf(currentStatus);
        if (currentIdx < 0) currentIdx = 0;
        return stagesForIndex(currentIdx, labels, subs);
    }

    private static List<StageDTO> stagesForIndex(Integer currentIdx,
            List<String> labels, List<String> subs) {
        List<StageDTO> stages = new List<StageDTO>();
        for (Integer i = 0; i < labels.size(); i++) {
            StageDTO s = new StageDTO();
            s.num = i + 1;
            s.label = labels[i];
            s.sub = subs[i];
            if (i < currentIdx) {
                s.state = 'done';
            } else if (i == currentIdx) {
                s.state = 'active';
            } else {
                s.state = 'pending';
            }
            stages.add(s);
        }
        return stages;
    }
}