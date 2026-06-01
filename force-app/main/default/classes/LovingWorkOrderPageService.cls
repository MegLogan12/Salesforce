/**
 * LovingWorkOrderPageService
 *
 * Main assembler for the Work Order page DTO.  Queries the Work_Order__c
 * record and all related data in a single service invocation, then
 * delegates to specialised services for each card section.
 *
 * Governor-limit strategy:
 *   - One primary SOQL query with relationship traversal for the WO record.
 *   - Separate count queries to avoid large aggregate subqueries.
 *   - Time entries capped at 50 rows.
 *   - Sub-work-order parent name resolved inside LovingSubWorkOrderService
 *     (1 SOQL, only when Parent_Work_Order__c is populated).
 *   - Builder pricing book lookup performed inside LovingBuilderPricingService
 *     (up to 2 SOQL).
 *
 * Dependencies (must be deployed to the org before this class):
 *   - WorkOrderPageDTO
 *   - LovingWorkOrderLifecycleService  (builds LifePathDTO + warnings)
 *   - LovingWorkOrderLineItemService   (builds List<LineItemDTO>)
 *   - LovingRevenueCloudQuoteService   (builds QuoteDTO stub)
 *   - LovingBuilderPricingService      (builds PricingDTO)
 *   - LovingSubWorkOrderService        (builds SubWorkOrderDTO + autoTriggered)
 *
 * @group Work Order Page
 */
public with sharing class LovingWorkOrderPageService {

    // ─── Entry Point ──────────────────────────────────────────────────────────

    /**
     * Assembles the full WorkOrderPageDTO for the given Work Order Id.
     *
     * @param workOrderId  Id of the Work_Order__c to load.
     * @return             Fully populated WorkOrderPageDTO (never null).
     *                     On error, dto.errors will be non-empty and most
     *                     section DTOs will be null.
     */
    public static WorkOrderPageDTO build(Id workOrderId) {
        WorkOrderPageDTO dto  = new WorkOrderPageDTO();
        dto.errors   = new List<String>();
        dto.warnings = new List<WorkOrderPageDTO.WarningDTO>();

        // ── Primary query ────────────────────────────────────────────────────
        Work_Order__c wo;
        try {
            wo = queryWorkOrder(workOrderId);
        } catch (Exception ex) {
            dto.errors.add('Work order not found: ' + ex.getMessage());
            return dto;
        }

        // ── Section assembly ─────────────────────────────────────────────────
        dto.header       = buildHeader(wo);
        dto.lifePath     = LovingWorkOrderLifecycleService.buildLifePath(wo);
        dto.highlights   = buildHighlights(wo);
        dto.property     = buildProperty(wo);
        dto.po           = buildPo(wo);
        dto.takeoff      = buildTakeoff(wo);
        dto.quote        = LovingRevenueCloudQuoteService.buildQuote(workOrderId);
        dto.pricing      = LovingBuilderPricingService.buildPricing(wo);
        dto.lineItems    = LovingWorkOrderLineItemService.buildLineItems(workOrderId);
        dto.timeEntries  = buildTimeEntries(workOrderId);
        dto.schedule     = buildSchedule(wo);
        dto.closeout     = buildCloseout(wo);
        dto.qi           = buildQi(wo);
        dto.invoice      = buildInvoice(wo);
        dto.subWorkOrder = LovingSubWorkOrderService.buildSubWorkOrder(wo);
        dto.autoTriggered = LovingSubWorkOrderService.buildAutoTriggered(workOrderId);
        dto.relatedCounts = buildRelatedCounts(
            workOrderId,
            dto.lineItems  != null ? dto.lineItems.size()  : 0,
            dto.timeEntries != null ? dto.timeEntries.size() : 0
        );

        // Warnings come from the lifecycle service; default to empty list.
        dto.warnings = dto.lifePath != null && dto.lifePath.warnings != null
            ? dto.lifePath.warnings
            : new List<WorkOrderPageDTO.WarningDTO>();

        dto.lastUpdated = Datetime.now();
        return dto;
    }

    // ─── Primary SOQL ─────────────────────────────────────────────────────────

    private static Work_Order__c queryWorkOrder(Id workOrderId) {
        return [
            SELECT
                Id, Name, Work_Order_Type__c, Status__c, Pipeline_Stage__c, Sub_Status__c,
                Job_Health__c, Division__c, Revenue_Division__c, Billable_Type__c,
                QI_Complete__c, QI_Completed_Date__c,
                Paid__c, Celigo_Payment_Status__c,
                Invoice_Generated__c, Approval_Process_Completed__c,
                Crew_Completed__c, FSL_Crew_Complete__c,
                Site_Readiness_Status__c, Takeoff_Status__c, Eight11_Task_Status__c,
                Scheduled_Date__c, Field_Manager__c, Crew__c, Stop_Sequence__c,
                Closeout_Photo_Count__c, Closeout_Notes__c,
                Parent_Account__c, Division_Account__c, Community__c, Lot__c,
                Builder_PO__c, Takeoff__c, Construction_Manager__c, Territory__c,
                Parent_Work_Order__c, Trigger_Source__c, Source__c, Request_Received_Date__c,
                Is_Finished_Job__c, Is_Warranty__c,
                FJ_Reason_Code__c, FJ_Reason_Detail__c, FJ_Original_Foreman__c,
                FJ_Original_Foreman__r.Name,
                Customer_Report__c, Warranty_Determination__c,
                Warranty_Coverage_Status__c, Warranty_Coverage_Type__c,
                Warranty_Start_Date__c, Warranty_End_Date__c, Warranty_Voided_Reason__c,
                EPO_Status__c, EPO_Sent_Date__c, EPO_Received_Date__c,
                EPO_Days_Outstanding__c, EPO_SLA_Tier__c, EPO_SLA_Breach__c,
                Red_Flag_Notes__c, Notes__c,
                Foreman__c, Site_Readiness_Check_Due__c,
                /* Lookup name traversal */
                Parent_Account__r.Name,
                Division_Account__r.Name,
                Community__r.Name, Community__r.Aqua_Customer__c,
                Lot__r.Name, Lot__r.Address__c,
                Construction_Manager__r.Name,
                Field_Manager__r.Name,
                Foreman__r.Name,
                /* Crew__c is a Text field — Crew__r traversal unavailable */
                Builder_PO__r.PO_Number__c, Builder_PO__r.PO_Amount__c,
                Builder_PO__r.PO_Release_Date__c, Builder_PO__r.Pipeline_Stage__c,
                Builder_PO__r.Timing_Status__c,
                Takeoff__r.Name, Takeoff__r.Status__c, Takeoff__r.Approved_Date__c
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];
    }

    // ─── Section Builders ─────────────────────────────────────────────────────

    private static WorkOrderPageDTO.HeaderDTO buildHeader(Work_Order__c wo) {
        WorkOrderPageDTO.HeaderDTO h = new WorkOrderPageDTO.HeaderDTO();
        h.recordId      = wo.Id;
        h.workOrderName = wo.Name;
        h.workOrderType = wo.Work_Order_Type__c;
        h.status        = wo.Status__c;
        h.pipelineStage = wo.Pipeline_Stage__c;
        h.subStatus     = wo.Sub_Status__c;
        h.jobHealth     = wo.Job_Health__c;
        h.division      = wo.Division__c;
        h.revenueDivision = wo.Revenue_Division__c;
        h.billableType  = wo.Billable_Type__c;

        // Derive pipeline source label from populated lookups
        List<String> sourceChain = new List<String>();
        if (wo.Builder_PO__c != null)  sourceChain.add('PO');
        if (wo.Takeoff__c    != null)  sourceChain.add('Takeoff');
        if (wo.Id            != null)  sourceChain.add('WO');
        h.pipelineSource = String.join(sourceChain, ' → ');

        return h;
    }

    private static WorkOrderPageDTO.HighlightsDTO buildHighlights(Work_Order__c wo) {
        WorkOrderPageDTO.HighlightsDTO h = new WorkOrderPageDTO.HighlightsDTO();
        h.accountId       = wo.Parent_Account__c;
        h.accountName     = wo.Parent_Account__r != null ? wo.Parent_Account__r.Name : null;
        h.communityId     = wo.Community__c;
        h.communityName   = wo.Community__r != null ? wo.Community__r.Name : null;
        h.fieldManagerId  = wo.Field_Manager__c;
        h.fieldManagerName = wo.Field_Manager__r != null ? wo.Field_Manager__r.Name : null;
        h.crewId          = null;             // Crew__c is a Text field (not a Lookup)
        h.crewName        = wo.Crew__c;
        h.scheduledDate   = wo.Scheduled_Date__c;
        h.goalHours       = null;  // WLR not available yet
        return h;
    }

    private static WorkOrderPageDTO.PropertyDTO buildProperty(Work_Order__c wo) {
        WorkOrderPageDTO.PropertyDTO p = new WorkOrderPageDTO.PropertyDTO();
        p.accountId             = wo.Parent_Account__c;
        p.accountName           = wo.Parent_Account__r != null ? wo.Parent_Account__r.Name : null;
        p.divisionAccountId     = wo.Division_Account__c;
        p.divisionAccountName   = wo.Division_Account__r != null ? wo.Division_Account__r.Name : null;
        p.communityId           = wo.Community__c;
        p.communityName         = wo.Community__r != null ? wo.Community__r.Name : null;
        p.lotId                 = wo.Lot__c;
        p.lotName               = wo.Lot__r != null ? wo.Lot__r.Name : null;
        p.streetAddress         = wo.Lot__r != null ? wo.Lot__r.Address__c : null;
        p.constructionManagerId   = wo.Construction_Manager__c;
        p.constructionManagerName = wo.Construction_Manager__r != null
                                        ? wo.Construction_Manager__r.Name : null;
        p.territory             = wo.Territory__c;
        p.aquaCustomer          = wo.Community__r != null ? wo.Community__r.Aqua_Customer__c : null;
        p.lawnCareCustomer      = null;  // Lawn_Care_Customer__c field MISSING on Community__c
        return p;
    }

    private static WorkOrderPageDTO.PoDTO buildPo(Work_Order__c wo) {
        WorkOrderPageDTO.PoDTO p = new WorkOrderPageDTO.PoDTO();
        if (wo.Builder_PO__c == null) {
            return p;
        }
        p.builderPoId   = wo.Builder_PO__c;
        p.poNumber      = wo.Builder_PO__r != null ? wo.Builder_PO__r.PO_Number__c  : null;
        p.poAmount      = wo.Builder_PO__r != null ? wo.Builder_PO__r.PO_Amount__c  : null;
        p.poReleaseDate = wo.Builder_PO__r != null ? wo.Builder_PO__r.PO_Release_Date__c : null;
        p.pipelineStage = wo.Builder_PO__r != null ? wo.Builder_PO__r.Pipeline_Stage__c  : null;
        p.timingStatus  = wo.Builder_PO__r != null ? wo.Builder_PO__r.Timing_Status__c   : null;
        return p;
    }

    private static WorkOrderPageDTO.TakeoffDTO buildTakeoff(Work_Order__c wo) {
        WorkOrderPageDTO.TakeoffDTO t = new WorkOrderPageDTO.TakeoffDTO();
        if (wo.Takeoff__c == null) {
            return t;
        }
        t.takeoffId   = wo.Takeoff__c;
        t.takeoffName = wo.Takeoff__r != null ? wo.Takeoff__r.Name        : null;
        t.status      = wo.Takeoff__r != null ? wo.Takeoff__r.Status__c   : null;
        t.approvedDate = (wo.Takeoff__r != null && wo.Takeoff__r.Approved_Date__c != null)
                             ? wo.Takeoff__r.Approved_Date__c.dateGmt() : null;
        return t;
    }

    private static WorkOrderPageDTO.ScheduleDTO buildSchedule(Work_Order__c wo) {
        WorkOrderPageDTO.ScheduleDTO s = new WorkOrderPageDTO.ScheduleDTO();
        s.scheduledDate      = wo.Scheduled_Date__c;
        s.scheduledStartTime = null;           // Resolved from Schedule_Stop__c (not linked via WO Id)
        s.siteReadinessDue   = wo.Site_Readiness_Check_Due__c;
        s.fieldManagerId     = wo.Field_Manager__c;
        s.fieldManagerName   = wo.Field_Manager__r != null ? wo.Field_Manager__r.Name  : null;
        s.foremanId          = wo.Foreman__c;
        s.foremanName        = wo.Foreman__r    != null ? wo.Foreman__r.Name    : null;
        s.crewId             = null;           // Crew__c is a Text field (not a Lookup)
        s.crewName           = wo.Crew__c;
        s.crewSize           = null;           // Headcount not available — Crew__c is text
        s.stopSequence       = wo.Stop_Sequence__c != null
                                   ? wo.Stop_Sequence__c.intValue() : null;
        s.estimatedDriveMinutes = null;        // From Schedule_Stop__c; no WO lookup available
        s.territory          = wo.Territory__c;
        s.truckName          = null;           // Truck relationship not on Work_Order__c
        return s;
    }

    private static WorkOrderPageDTO.CloseoutDTO buildCloseout(Work_Order__c wo) {
        WorkOrderPageDTO.CloseoutDTO c = new WorkOrderPageDTO.CloseoutDTO();
        c.crewCompleted            = wo.Crew_Completed__c;
        c.fslCrewComplete          = wo.FSL_Crew_Complete__c;
        c.photoCount               = wo.Closeout_Photo_Count__c != null
                                         ? wo.Closeout_Photo_Count__c.intValue() : 0;
        c.closeoutNotes            = wo.Closeout_Notes__c;
        c.approvalProcessCompleted = wo.Approval_Process_Completed__c;
        return c;
    }

    private static WorkOrderPageDTO.QiDTO buildQi(Work_Order__c wo) {
        WorkOrderPageDTO.QiDTO q = new WorkOrderPageDTO.QiDTO();
        q.qiComplete      = wo.QI_Complete__c;
        q.qiScheduled     = false;  // QI_Scheduled__c field MISSING — not yet deployed
        q.qiCompletedDate = wo.QI_Completed_Date__c;
        return q;
    }

    private static WorkOrderPageDTO.InvoiceDTO buildInvoice(Work_Order__c wo) {
        WorkOrderPageDTO.InvoiceDTO inv = new WorkOrderPageDTO.InvoiceDTO();
        inv.invoiceGenerated = wo.Invoice_Generated__c;
        inv.invoiceNumber    = null;   // Invoice number not a direct field on WO
        inv.invoiceTotal     = null;   // Invoice total not a direct field on WO
        return inv;
    }

    /**
     * Queries up to 50 time entry records and maps them to TimeEntryDTO.
     * Employee__c is a text field on Rippling_Time_Entry__c.
     */
    private static List<WorkOrderPageDTO.TimeEntryDTO> buildTimeEntries(Id workOrderId) {
        List<WorkOrderPageDTO.TimeEntryDTO> entries = new List<WorkOrderPageDTO.TimeEntryDTO>();

        List<Rippling_Time_Entry__c> rows = [
            SELECT Id, Employee__c, Clock_In__c, Clock_Out__c, Hours__c
            FROM   Rippling_Time_Entry__c
            WHERE  Work_Order__c = :workOrderId
            ORDER BY Clock_In__c NULLS LAST
            LIMIT 50
        ];

        for (Rippling_Time_Entry__c row : rows) {
            WorkOrderPageDTO.TimeEntryDTO te = new WorkOrderPageDTO.TimeEntryDTO();
            te.id           = row.Id;
            te.employeeName = row.Employee__c;
            te.clockIn      = row.Clock_In__c;
            te.clockOut     = row.Clock_Out__c;
            te.hours        = row.Hours__c;
            te.arriveSite   = null;  // Not captured on Rippling_Time_Entry__c
            te.departSite   = null;
            entries.add(te);
        }

        return entries;
    }

    /**
     * Builds RelatedCountsDTO using lightweight COUNT() queries.
     * lineItemCount and timeEntryCount are passed in from already-computed lists
     * to avoid duplicate SOQL.
     */
    private static WorkOrderPageDTO.RelatedCountsDTO buildRelatedCounts(
        Id workOrderId,
        Integer lineItemCount,
        Integer timeEntryCount
    ) {
        WorkOrderPageDTO.RelatedCountsDTO rc = new WorkOrderPageDTO.RelatedCountsDTO();

        rc.lineItemCount  = lineItemCount  != null ? lineItemCount  : 0;
        rc.timeEntryCount = timeEntryCount != null ? timeEntryCount : 0;

        // File/document count
        rc.fileCount = [
            SELECT COUNT()
            FROM   ContentDocumentLink
            WHERE  LinkedEntityId = :workOrderId
        ];

        // Finished Job child count
        rc.finishedJobCount = [
            SELECT COUNT()
            FROM   Work_Order__c
            WHERE  Parent_Work_Order__c = :workOrderId
            AND    Work_Order_Type__c = 'Finished Job'
        ];

        // Photo count is also on Closeout_Photo_Count__c — kept in sync via CloseoutDTO,
        // but mirror it here for the counts card.
        rc.photoCount = 0;  // Populated from wo.Closeout_Photo_Count__c by the caller if needed

        return rc;
    }
}