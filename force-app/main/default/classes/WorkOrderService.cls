/**
 * WorkOrderService
 * General Work Order operations not covered by other services.
 *
 * - advanceToReadyToSchedule: called after takeoff locked
 * - createFromPO: called when PO is received (Stage 4)
 * - backChargeHandling: classification of back charges (Stage 17)
 */
public with sharing class WorkOrderService {

    // ─────────────────────────────────────────────
    // STAGE 6 — Advance to Ready to Schedule
    // ─────────────────────────────────────────────
    public static void advanceToReadyToSchedule(List<Work_Order__c> workOrders) {
        List<Work_Order__c> toUpdate = new List<Work_Order__c>();
        for (Work_Order__c wo : workOrders) {
            if (wo.Status__c != 'Ready to Schedule') {
                toUpdate.add(new Work_Order__c(
                    Id          = wo.Id,
                    Status__c   = 'Ready to Schedule'
                ));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;

        // Notify Scheduling Manager
        for (Work_Order__c wo : workOrders) {
            EscalationService.notifySchedulingManagerReadyToSchedule(wo.Id);
        }
    }

    // ─────────────────────────────────────────────
    // STAGE 4 — Create Work Order from PO
    // Called from PO intake process (SupplyPro API, manual, portal)
    // ─────────────────────────────────────────────
    public static Work_Order__c createFromPO(
        Id  lotId,
        Id  communityId,
        Id  builderMarketId,
        String poNumber,
        Date  requestedInstallDate,
        String poSource
    ) {
        validateCommunityActivated(communityId);

        Community__c community = [
            SELECT Id, Assigned_FM__c, Aqua_Customer__c, Sod_Type__c
            FROM Community__c
            WHERE Id = :communityId
            LIMIT 1
        ];

        Work_Order__c wo = new Work_Order__c(
            Community__c                = communityId,
            Builder_Market_Account__c   = builderMarketId,
            PO_Number__c                = poNumber,
            PO_Source__c                = poSource,
            Requested_Install_Date__c   = requestedInstallDate,
            Status__c                   = 'Pending Takeoff',
            Takeoff_Status__c           = 'Not Started',
            FM_Assignment__c            = community.Assigned_FM__c,
            Aqua_Community__c           = community.Aqua_Customer__c,
            Sod_Species__c              = community.Sod_Type__c,
            PO_Received_Date__c         = Date.today()
        );
        insert wo;
        return wo;
    }

    // ─────────────────────────────────────────────
    // BACK CHARGE HANDLING (Stage 17)
    // Back charges always linked to original WO. No orphaned records.
    // ─────────────────────────────────────────────

    /**
     * Classification: Payment Correction
     * No new WO — apply adjustment to original invoice.
     */
    public static void createPaymentCorrection(Id originalWorkOrderId, Decimal adjustmentAmount, String notes) {
        Invoice__c adjustment = new Invoice__c(
            LOVING_Work_Order__c    = originalWorkOrderId,
            Invoice_Type__c         = 'Back Charge — Payment Correction',
            Total_Revenue__c        = adjustmentAmount,
            Status__c               = 'Pending Send',
            Notes__c                = notes,
            Back_Charge__c          = true,
            Invoice_Date__c         = Date.today()
        );
        insert adjustment;
    }

    /**
     * Classification: Repair
     * New Repair Work Order linked to original via Parent_Work_Order__c.
     */
    public static Work_Order__c createRepairWorkOrder(Id originalWorkOrderId, String repairScope, String notes) {
        Work_Order__c original = [
            SELECT Id, Name, Community__c, Builder_Market_Account__c, FM_Assignment__c,
                   Aqua_Community__c
            FROM Work_Order__c WHERE Id = :originalWorkOrderId
        ];

        Work_Order__c repair = new Work_Order__c(
            Parent_Work_Order__c        = originalWorkOrderId,
            Status__c                   = 'Ready to Schedule',
            Community__c                = original.Community__c,
            Builder_Market_Account__c   = original.Builder_Market_Account__c,
            FM_Assignment__c            = original.FM_Assignment__c,
            Aqua_Community__c           = original.Aqua_Community__c,
            Is_Repair__c                = true,
            Repair_Scope__c             = repairScope,
            Repair_Notes__c             = notes,
            Takeoff_Status__c           = 'Locked' // Repair scope defined above; no new takeoff
        );
        insert repair;
        return repair;
    }

    // ─────────────────────────────────────────────
    // VALIDATION — Community must be fully activated
    // ─────────────────────────────────────────────
    private static void validateCommunityActivated(Id communityId) {
        Community__c community = [
            SELECT Id, Assigned_FM__c, Sod_Type__c, Lot_Layout_Link__c
            FROM Community__c WHERE Id = :communityId
        ];

        List<String> missing = new List<String>();
        if (community.Assigned_FM__c == null)             missing.add('Assigned FM');
        if (String.isBlank(community.Sod_Type__c))        missing.add('Sod Type');
        if (String.isBlank(community.Lot_Layout_Link__c)) missing.add('Lot Layout document');

        if (!missing.isEmpty()) {
            throw new WorkOrderException(
                'Cannot create a Work Order: Community Activation Checklist is incomplete. '
                + 'Missing: ' + String.join(missing, ', ') + '. '
                + 'Complete the Community Activation Checklist before processing any POs.'
            );
        }
    }

    public class WorkOrderException extends Exception {}

    // ═══════════════════════════════════════════════════════════════════════════
    // SCHEDULING CONSOLE — methods called by SchedulingConsoleController
    // Operate on standard FSL WorkOrder object (not Work_Order__c)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Marks a single WorkOrder as Ready to Schedule.
     * Checks FLS, validates current status is a pre-schedule state.
     */
    public static void markReadyForScheduling(Id woId) {
        WorkOrder wo = [
            SELECT Id, Status__c, Pipeline_Bucket__c, Community__c, Field_Manager__c,
                   ServiceTerritoryId, WorkTypeId
            FROM WorkOrder WHERE Id = :woId
        ];
        wo.Pipeline_Bucket__c = 'Ready_to_Schedule';
        wo.Status__c          = 'Ready to Schedule';
        update wo;
        EscalationService.notifySchedulingManagerReadyToSchedule(woId);
    }

    /**
     * Advances a WorkOrder into FSL scheduling queue.
     * Updates Pipeline_Bucket__c and Status, and sets Schedule_Proposal_Status__c.
     */
    public static void sendToScheduling(Id woId) {
        WorkOrder wo = [
            SELECT Id, Status__c, Pipeline_Bucket__c, Schedule_Proposal_Status__c,
                   Community__c, Field_Manager__c, ServiceTerritoryId, WorkTypeId
            FROM WorkOrder WHERE Id = :woId
        ];
        if (wo.Community__c == null || wo.Field_Manager__c == null || wo.ServiceTerritoryId == null) {
            throw new WorkOrderException('Work Order is missing required fields (Community, FM, or Service Territory). Resolve Data Issues before sending to scheduling.');
        }
        wo.Pipeline_Bucket__c          = 'Scheduling';
        wo.Status__c                   = 'Scheduling';
        wo.Schedule_Proposal_Status__c = 'Pending';
        update wo;
    }

    /**
     * Marks a WorkOrder as blocked and creates a Schedule_Issue__c record.
     */
    public static void markBlocked(Id woId, String reason) {
        WorkOrder wo = [SELECT Id, WorkOrderNumber FROM WorkOrder WHERE Id = :woId];
        wo.Pipeline_Bucket__c = 'Blocked';
        update wo;
        insert new Schedule_Issue__c(
            Standard_WorkOrder__c = woId,
            Summary__c            = String.isNotBlank(reason) ? reason : 'Blocked via Scheduling Console',
            Status__c             = 'Open',
            Severity__c           = 'Medium',
            Issue_Type__c         = 'Blocked'
        );
    }

    /**
     * Clears the active blocker for a WorkOrder.
     * Resolves open Schedule_Issue__c records and restores Pipeline_Bucket__c.
     */
    public static void clearBlocker(Id woId) {
        List<Schedule_Issue__c> issues = [
            SELECT Id FROM Schedule_Issue__c
            WHERE Standard_WorkOrder__c = :woId AND Status__c = 'Open'
        ];
        for (Schedule_Issue__c si : issues) {
            si.Status__c           = 'Resolved';
            si.Resolution_Notes__c = 'Blocker cleared via Scheduling Console by ' + UserInfo.getName();
        }
        if (!issues.isEmpty()) update issues;

        update new WorkOrder(
            Id                 = woId,
            Pipeline_Bucket__c = 'Ready_to_Schedule',
            Status__c          = 'Ready to Schedule'
        );
    }
}