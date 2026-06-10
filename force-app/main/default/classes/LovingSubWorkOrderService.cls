/**
 * LovingSubWorkOrderService
 *
 * Builds sub-work-order context for the Work Order page DTO layer.
 * Handles three specialised work order types:
 *   - Finished Job (FJ)
 *   - Warranty
 *   - Customer Care (CC)
 *
 * Also provides a list of all auto-triggered child Work Orders for the
 * "Triggered Work Orders" card on the page.
 *
 * @group Work Order Page
 */
public with sharing class LovingSubWorkOrderService {

    // ─── Work Order Type labels ───────────────────────────────────────────────
    private static final String TYPE_FJ             = 'Finished Job';
    private static final String TYPE_WARRANTY       = 'Warranty';
    private static final String TYPE_CUSTOMER_CARE  = 'Customer Care';

    // ─── Public API ───────────────────────────────────────────────────────────

    /**
     * Returns a list of all child Work Orders parented to the given WO ID,
     * ordered by creation date ascending.  Used for the "auto-triggered"
     * card that shows FJ, Warranty, Customer Care, Aqua, etc. children.
     *
     * @param parentWoId  Id of the parent Work_Order__c record.
     * @return            List of ChildWODTO (may be empty, never null).
     */
    public static List<WorkOrderPageDTO.ChildWODTO> buildAutoTriggered(Id parentWoId) {
        List<WorkOrderPageDTO.ChildWODTO> results = new List<WorkOrderPageDTO.ChildWODTO>();

        if (parentWoId == null) {
            return results;
        }

        List<Work_Order__c> children = [
            SELECT Id, Name, Work_Order_Type__c, Trigger_Source__c,
                   Status__c, Pipeline_Stage__c, Scheduled_Date__c
            FROM   Work_Order__c
            WHERE  Parent_Work_Order__c = :parentWoId
            ORDER BY CreatedDate ASC
        ];

        for (Work_Order__c child : children) {
            WorkOrderPageDTO.ChildWODTO row = new WorkOrderPageDTO.ChildWODTO();
            row.id             = child.Id;
            row.name           = child.Name;
            row.workOrderType  = child.Work_Order_Type__c;
            row.triggerSource  = child.Trigger_Source__c;
            row.status         = child.Status__c;
            row.scheduledDate  = child.Scheduled_Date__c;
            results.add(row);
        }

        return results;
    }

    /**
     * Builds a SubWorkOrderDTO from a fully-queried Work_Order__c record.
     * Type-specific fields are populated based on Work_Order_Type__c.
     * A lightweight sub-query is performed to resolve the parent WO name
     * when Parent_Work_Order__c is present.
     *
     * @param wo  Work_Order__c with all SubWorkOrder fields selected.
     * @return    SubWorkOrderDTO (never null).
     */
    public static WorkOrderPageDTO.SubWorkOrderDTO buildSubWorkOrder(Work_Order__c wo) {
        WorkOrderPageDTO.SubWorkOrderDTO dto = new WorkOrderPageDTO.SubWorkOrderDTO();

        // ── Parent relationship ──────────────────────────────────────────────
        dto.parentWorkOrderId   = wo.Parent_Work_Order__c;
        dto.parentWorkOrderName = null;
        dto.parentScheduledDate = null;

        if (wo.Parent_Work_Order__c != null) {
            List<Work_Order__c> parents = [
                SELECT Name, Scheduled_Date__c
                FROM   Work_Order__c
                WHERE  Id = :wo.Parent_Work_Order__c
                LIMIT  1
            ];
            if (!parents.isEmpty()) {
                dto.parentWorkOrderName = parents[0].Name;
                dto.parentScheduledDate = parents[0].Scheduled_Date__c;
            }
        }

        String woType = wo.Work_Order_Type__c;

        // ── Finished Job ─────────────────────────────────────────────────────
        if (TYPE_FJ.equalsIgnoreCase(woType) || wo.Is_Finished_Job__c == true) {
            dto.isFinishedJob      = true;
            dto.fjReasonCode       = wo.FJ_Reason_Code__c;
            dto.fjReasonDetail     = wo.FJ_Reason_Detail__c;
            dto.originalForemanName = wo.FJ_Original_Foreman__r != null
                                        ? wo.FJ_Original_Foreman__r.Name : null;  // Lookup User
        } else {
            dto.isFinishedJob = false;
        }

        // ── Warranty ─────────────────────────────────────────────────────────
        if (TYPE_WARRANTY.equalsIgnoreCase(woType) || wo.Is_Warranty__c == true) {
            dto.isWarranty              = true;
            dto.customerReport          = wo.Customer_Report__c;
            dto.warrantyDetermination   = wo.Warranty_Determination__c;
            dto.warrantyStartDate       = wo.Warranty_Start_Date__c;
            dto.warrantyEndDate         = wo.Warranty_End_Date__c;
            dto.warrantyCoverageStatus  = wo.Warranty_Coverage_Status__c;
            dto.warrantyCoverageType    = wo.Warranty_Coverage_Type__c;
            dto.warrantyVoidedReason    = wo.Warranty_Voided_Reason__c;
        } else {
            dto.isWarranty = false;
        }

        // ── Customer Care / EPO ──────────────────────────────────────────────
        if (TYPE_CUSTOMER_CARE.equalsIgnoreCase(woType)) {
            dto.source              = wo.Source__c;
            dto.requestReceivedDate = wo.Request_Received_Date__c;
            dto.epoStatus           = wo.EPO_Status__c;
            dto.epoSentDate         = wo.EPO_Sent_Date__c;
            dto.epoReceivedDate     = wo.EPO_Received_Date__c != null
                                        ? wo.EPO_Received_Date__c.dateGmt() : null;
            dto.epoDaysOutstanding  = wo.EPO_Days_Outstanding__c != null
                                        ? wo.EPO_Days_Outstanding__c.intValue()
                                        : null;
            dto.epoSlaTier          = wo.EPO_SLA_Tier__c;
            dto.epoSlaBreach        = wo.EPO_SLA_Breach__c;
        }

        return dto;
    }
}