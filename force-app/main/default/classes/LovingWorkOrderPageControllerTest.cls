/**
 * LovingWorkOrderPageControllerTest
 *
 * Comprehensive test coverage for the Work Order page service layer:
 *   - WorkOrderPageDTO
 *   - LovingWorkOrderLifecycleService
 *   - LovingWorkOrderLineItemService
 *   - LovingRevenueCloudQuoteService
 *   - LovingBuilderPricingService
 *   - LovingSubWorkOrderService
 *   - LovingWorkOrderPageService
 *   - LovingWorkOrderPageController
 *
 * Each test method is fully standalone — no shared @TestSetup.
 *
 * @group Work Order Page
 */
@IsTest
private class LovingWorkOrderPageControllerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // WorkOrderPageDTO — instantiation smoke test
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void dto_instantiation_allInnerClassesConstructible() {
        WorkOrderPageDTO dto               = new WorkOrderPageDTO();
        WorkOrderPageDTO.HeaderDTO         h  = new WorkOrderPageDTO.HeaderDTO();
        WorkOrderPageDTO.LifePathDTO       lp = new WorkOrderPageDTO.LifePathDTO();
        WorkOrderPageDTO.HighlightsDTO     hi = new WorkOrderPageDTO.HighlightsDTO();
        WorkOrderPageDTO.PropertyDTO       pr = new WorkOrderPageDTO.PropertyDTO();
        WorkOrderPageDTO.PoDTO             po = new WorkOrderPageDTO.PoDTO();
        WorkOrderPageDTO.TakeoffDTO        tk = new WorkOrderPageDTO.TakeoffDTO();
        WorkOrderPageDTO.QuoteDTO          q  = new WorkOrderPageDTO.QuoteDTO();
        WorkOrderPageDTO.PricingDTO        px = new WorkOrderPageDTO.PricingDTO();
        WorkOrderPageDTO.LineItemDTO       li = new WorkOrderPageDTO.LineItemDTO();
        WorkOrderPageDTO.TimeEntryDTO      te = new WorkOrderPageDTO.TimeEntryDTO();
        WorkOrderPageDTO.ScheduleDTO       sc = new WorkOrderPageDTO.ScheduleDTO();
        WorkOrderPageDTO.CloseoutDTO       co = new WorkOrderPageDTO.CloseoutDTO();
        WorkOrderPageDTO.QiDTO             qi = new WorkOrderPageDTO.QiDTO();
        WorkOrderPageDTO.InvoiceDTO        inv = new WorkOrderPageDTO.InvoiceDTO();
        WorkOrderPageDTO.SubWorkOrderDTO   sub = new WorkOrderPageDTO.SubWorkOrderDTO();
        WorkOrderPageDTO.ChildWODTO        cw  = new WorkOrderPageDTO.ChildWODTO();
        WorkOrderPageDTO.RelatedCountsDTO  rc  = new WorkOrderPageDTO.RelatedCountsDTO();
        WorkOrderPageDTO.WarningDTO        w   = new WorkOrderPageDTO.WarningDTO();

        Assert.isNotNull(dto, 'WorkOrderPageDTO must be instantiable');
        Assert.isNotNull(h,   'HeaderDTO must be instantiable');
        Assert.isNotNull(lp,  'LifePathDTO must be instantiable');
        Assert.isNotNull(w,   'WarningDTO must be instantiable');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingWorkOrderLifecycleService — normalizeStage
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void lifecycle_normalizeStage_pipelineStageWins() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'Scheduled',
            Status__c         = 'New'
        );
        insert wo;
        String stage = LovingWorkOrderLifecycleService.normalizeStage('Scheduled', 'New');
        Assert.areEqual('Scheduled', stage);
    }

    @IsTest
    private static void lifecycle_normalizeStage_fallsBackToStatus() {
        String stage = LovingWorkOrderLifecycleService.normalizeStage(null, 'Ready to Schedule');
        Assert.areEqual('Clear for Schedule', stage);
    }

    @IsTest
    private static void lifecycle_normalizeStage_unknownDefaultsTo90Plus() {
        String stage = LovingWorkOrderLifecycleService.normalizeStage(null, 'Unknown Status XYZ');
        Assert.areEqual('90+ Days', stage);
    }

    @IsTest
    private static void lifecycle_normalizeStage_blankPipelineStageFallsBackToStatus() {
        String stage = LovingWorkOrderLifecycleService.normalizeStage('', 'In Progress');
        Assert.areEqual('In Progress', stage);
    }

    @IsTest
    private static void lifecycle_normalizeStage_knownPipelineStageTakesPrecedenceOverStatus() {
        // Even when status maps to something different, Pipeline_Stage__c wins
        String stage = LovingWorkOrderLifecycleService.normalizeStage('Closed', 'New');
        Assert.areEqual('Closed', stage);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingWorkOrderLifecycleService — getStageOrder
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void lifecycle_getStageOrder_knownStage() {
        Integer order = LovingWorkOrderLifecycleService.getStageOrder('Closed');
        Assert.areEqual(17, order);
    }

    @IsTest
    private static void lifecycle_getStageOrder_unknownStageReturnsZero() {
        Integer order = LovingWorkOrderLifecycleService.getStageOrder('Not A Real Stage');
        Assert.areEqual(0, order);
    }

    @IsTest
    private static void lifecycle_getStageOrder_blankStageReturnsZero() {
        Integer order = LovingWorkOrderLifecycleService.getStageOrder('');
        Assert.areEqual(0, order);
    }

    @IsTest
    private static void lifecycle_getStageOrder_nullReturnsZero() {
        Integer order = LovingWorkOrderLifecycleService.getStageOrder(null);
        Assert.areEqual(0, order);
    }

    @IsTest
    private static void lifecycle_getStageOrder_firstStageReturnsOne() {
        Integer order = LovingWorkOrderLifecycleService.getStageOrder('90+ Days');
        Assert.areEqual(1, order);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingWorkOrderLifecycleService — isPaid
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void lifecycle_isPaid_viaPaidField() {
        Work_Order__c wo = new Work_Order__c(Paid__c = true);
        insert wo;
        Assert.isTrue(LovingWorkOrderLifecycleService.isPaid(wo));
    }

    @IsTest
    private static void lifecycle_isPaid_viaCeligo() {
        Work_Order__c wo = new Work_Order__c(Celigo_Payment_Status__c = 'Paid');
        insert wo;
        Assert.isTrue(LovingWorkOrderLifecycleService.isPaid(wo));
    }

    @IsTest
    private static void lifecycle_isPaid_neitherFlagReturnsFalse() {
        Work_Order__c wo = new Work_Order__c(
            Paid__c                  = false,
            Celigo_Payment_Status__c = 'Pending'
        );
        insert wo;
        Assert.isFalse(LovingWorkOrderLifecycleService.isPaid(wo));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingWorkOrderLifecycleService — isClosedBlocked
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void lifecycle_isClosedBlocked_whenClosedAndNotPaid() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'Closed',
            QI_Complete__c    = false,
            Paid__c           = false
        );
        insert wo;
        Assert.isTrue(LovingWorkOrderLifecycleService.isClosedBlocked(wo));
    }

    @IsTest
    private static void lifecycle_isClosedBlocked_false_whenPaidAndQi() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'Closed',
            QI_Complete__c    = true,
            Paid__c           = true
        );
        insert wo;
        Assert.isFalse(LovingWorkOrderLifecycleService.isClosedBlocked(wo));
    }

    @IsTest
    private static void lifecycle_isClosedBlocked_false_whenNotClosedStage() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'Scheduled',
            QI_Complete__c    = false,
            Paid__c           = false
        );
        insert wo;
        Assert.isFalse(LovingWorkOrderLifecycleService.isClosedBlocked(wo));
    }

    @IsTest
    private static void lifecycle_isClosedBlocked_whenClosedQiDoneButNotPaid() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'Closed',
            QI_Complete__c    = true,
            Paid__c           = false
        );
        insert wo;
        Assert.isTrue(LovingWorkOrderLifecycleService.isClosedBlocked(wo));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingWorkOrderLifecycleService — buildLifePath
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void lifecycle_buildLifePath_scheduledStage() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'Scheduled',
            Crew__c           = null,
            Scheduled_Date__c = null
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.LifePathDTO lp = LovingWorkOrderLifecycleService.buildLifePath(wo);
        Assert.areEqual('Scheduled', lp.currentStage);
        Assert.areEqual(7, lp.currentOrder);
        Assert.isNotNull(lp.warnings);
    }

    @IsTest
    private static void lifecycle_buildLifePath_90PlusDays_noWarnings() {
        Work_Order__c wo = new Work_Order__c(Pipeline_Stage__c = '90+ Days');
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.LifePathDTO lp = LovingWorkOrderLifecycleService.buildLifePath(wo);
        Assert.areEqual('90+ Days', lp.currentStage);
        Assert.areEqual(1, lp.currentOrder);
        // Stages 1–5 should generate no warnings
        Assert.areEqual(0, lp.warnings.size());
    }

    @IsTest
    private static void lifecycle_buildLifePath_closedStage_isClosedBlockedTrue() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'Closed',
            QI_Complete__c    = false,
            Paid__c           = false
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.LifePathDTO lp = LovingWorkOrderLifecycleService.buildLifePath(wo);
        Assert.isTrue(lp.isClosedBlocked);
        Assert.isTrue(lp.showClosedWarning);
        Assert.isFalse(lp.isPaid);
        Assert.isFalse(lp.isQiComplete);
    }

    @IsTest
    private static void lifecycle_buildLifePath_closedAndPaid_notBlocked() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'Closed',
            QI_Complete__c    = true,
            Paid__c           = true
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.LifePathDTO lp = LovingWorkOrderLifecycleService.buildLifePath(wo);
        Assert.isFalse(lp.isClosedBlocked);
        Assert.isTrue(lp.isPaid);
        Assert.isTrue(lp.isQiComplete);
    }

    @IsTest
    private static void lifecycle_buildLifePath_nextStageIsPopulated() {
        Work_Order__c wo = new Work_Order__c(Pipeline_Stage__c = 'Scheduled');
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.LifePathDTO lp = LovingWorkOrderLifecycleService.buildLifePath(wo);
        Assert.areEqual('Site Readiness Check', lp.nextStage);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingWorkOrderLifecycleService — buildWarnings
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void lifecycle_buildWarnings_stage17_producesErrors() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'Closed',
            QI_Complete__c    = false,
            Paid__c           = false
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        List<WorkOrderPageDTO.WarningDTO> warns = LovingWorkOrderLifecycleService.buildWarnings(wo);
        Boolean hasError = false;
        for (WorkOrderPageDTO.WarningDTO w : warns) {
            if (w.severity == 'error') {
                hasError = true;
            }
        }
        Assert.isTrue(hasError, 'Expected error-severity warnings for Closed stage without QI/Payment');
    }

    @IsTest
    private static void lifecycle_buildWarnings_stage6_takeoffAndEight11Warnings() {
        // Clear for Schedule = order 6; should generate TAKEOFF_NOT_APPROVED + EIGHT11_NOT_CLEARED
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c    = 'Clear for Schedule',
            Takeoff_Status__c    = 'Draft',        // not Approved or Locked
            Eight11_Task_Status__c = 'Pending'     // not Cleared
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        List<WorkOrderPageDTO.WarningDTO> warns = LovingWorkOrderLifecycleService.buildWarnings(wo);
        Set<String> keys = new Set<String>();
        for (WorkOrderPageDTO.WarningDTO w : warns) {
            keys.add(w.key);
        }
        Assert.isTrue(keys.contains('TAKEOFF_NOT_APPROVED'), 'Expected TAKEOFF_NOT_APPROVED warning');
        Assert.isTrue(keys.contains('EIGHT11_NOT_CLEARED'),  'Expected EIGHT11_NOT_CLEARED warning');
    }

    @IsTest
    private static void lifecycle_buildWarnings_stage7_schedulingFieldsMissing() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c  = 'Scheduled',
            Scheduled_Date__c  = null,
            Stop_Sequence__c   = null
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        List<WorkOrderPageDTO.WarningDTO> warns = LovingWorkOrderLifecycleService.buildWarnings(wo);
        Set<String> keys = new Set<String>();
        for (WorkOrderPageDTO.WarningDTO w : warns) {
            keys.add(w.key);
        }
        Assert.isTrue(keys.contains('SCHEDULED_DATE_MISSING'), 'Expected SCHEDULED_DATE_MISSING');
        Assert.isTrue(keys.contains('CREW_NOT_ASSIGNED'),      'Expected CREW_NOT_ASSIGNED');
        Assert.isTrue(keys.contains('STOP_SEQUENCE_NOT_SET'),  'Expected STOP_SEQUENCE_NOT_SET');
    }

    @IsTest
    private static void lifecycle_buildWarnings_stage11_closeoutPhotoAndNotesMissing() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c     = 'Pending Approval',  // order 11
            Closeout_Photo_Count__c = 0,
            Closeout_Notes__c     = null
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        List<WorkOrderPageDTO.WarningDTO> warns = LovingWorkOrderLifecycleService.buildWarnings(wo);
        Set<String> keys = new Set<String>();
        for (WorkOrderPageDTO.WarningDTO w : warns) {
            keys.add(w.key);
        }
        Assert.isTrue(keys.contains('INSUFFICIENT_CLOSEOUT_PHOTOS'), 'Expected INSUFFICIENT_CLOSEOUT_PHOTOS');
        Assert.isTrue(keys.contains('CLOSEOUT_NOTES_MISSING'),        'Expected CLOSEOUT_NOTES_MISSING');
    }

    @IsTest
    private static void lifecycle_buildWarnings_stage12_approvalProcessIncomplete() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c          = 'Approved',  // order 12
            Approval_Process_Completed__c = false
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        List<WorkOrderPageDTO.WarningDTO> warns = LovingWorkOrderLifecycleService.buildWarnings(wo);
        Set<String> keys = new Set<String>();
        for (WorkOrderPageDTO.WarningDTO w : warns) {
            keys.add(w.key);
        }
        Assert.isTrue(keys.contains('APPROVAL_PROCESS_INCOMPLETE'), 'Expected APPROVAL_PROCESS_INCOMPLETE');
    }

    @IsTest
    private static void lifecycle_buildWarnings_stage14_invoiceNotGenerated() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c   = 'Invoiced',  // order 14
            Invoice_Generated__c = false
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        List<WorkOrderPageDTO.WarningDTO> warns = LovingWorkOrderLifecycleService.buildWarnings(wo);
        Set<String> keys = new Set<String>();
        for (WorkOrderPageDTO.WarningDTO w : warns) {
            keys.add(w.key);
        }
        Assert.isTrue(keys.contains('INVOICE_NOT_GENERATED'), 'Expected INVOICE_NOT_GENERATED');
    }

    @IsTest
    private static void lifecycle_buildWarnings_stage10_crewCompletionNotRecorded() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'Completion Status',  // order 10
            Crew_Completed__c  = false,
            FSL_Crew_Complete__c = false
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        List<WorkOrderPageDTO.WarningDTO> warns = LovingWorkOrderLifecycleService.buildWarnings(wo);
        Set<String> keys = new Set<String>();
        for (WorkOrderPageDTO.WarningDTO w : warns) {
            keys.add(w.key);
        }
        Assert.isTrue(keys.contains('CREW_COMPLETION_NOT_RECORDED'), 'Expected CREW_COMPLETION_NOT_RECORDED');
    }

    @IsTest
    private static void lifecycle_buildWarnings_stage9_siteReadinessNotConfirmed() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c      = 'In Progress',  // order 9
            Site_Readiness_Status__c = 'Not Ready'   // valid value — not 'Ready'
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        List<WorkOrderPageDTO.WarningDTO> warns = LovingWorkOrderLifecycleService.buildWarnings(wo);
        Set<String> keys = new Set<String>();
        for (WorkOrderPageDTO.WarningDTO w : warns) {
            keys.add(w.key);
        }
        Assert.isTrue(keys.contains('SITE_READINESS_NOT_CONFIRMED'), 'Expected SITE_READINESS_NOT_CONFIRMED');
    }

    @IsTest
    private static void lifecycle_buildWarnings_stage16_paymentNotConfirmed() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c        = 'Paid',   // order 16
            Paid__c                  = false,
            Celigo_Payment_Status__c = 'Pending'
        );
        insert wo;
        wo = [
            SELECT Pipeline_Stage__c, Status__c, QI_Complete__c, Paid__c, Celigo_Payment_Status__c,
                   Invoice_Generated__c, Approval_Process_Completed__c, Crew_Completed__c,
                   FSL_Crew_Complete__c, Site_Readiness_Status__c, Takeoff_Status__c,
                   Eight11_Task_Status__c, Scheduled_Date__c, Field_Manager__c, Crew__c,
                   Stop_Sequence__c, Closeout_Photo_Count__c, Closeout_Notes__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        List<WorkOrderPageDTO.WarningDTO> warns = LovingWorkOrderLifecycleService.buildWarnings(wo);
        Set<String> keys = new Set<String>();
        for (WorkOrderPageDTO.WarningDTO w : warns) {
            keys.add(w.key);
        }
        Assert.isTrue(keys.contains('PAYMENT_NOT_CONFIRMED'), 'Expected PAYMENT_NOT_CONFIRMED');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingWorkOrderLineItemService
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void lineItem_buildLineItems_noTakeoff_returnsEmpty() {
        Work_Order__c wo = new Work_Order__c();
        insert wo;
        List<WorkOrderPageDTO.LineItemDTO> items = LovingWorkOrderLineItemService.buildLineItems(wo.Id);
        Assert.areEqual(0, items.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingRevenueCloudQuoteService
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void revenueCloud_buildQuote_returnsStub() {
        Work_Order__c wo = new Work_Order__c();
        insert wo;
        WorkOrderPageDTO.QuoteDTO q = LovingRevenueCloudQuoteService.buildQuote(wo.Id);
        Assert.isFalse(q.isSbqqAvailable);
    }

    @IsTest
    private static void revenueCloud_buildQuote_messageIsSet() {
        Work_Order__c wo = new Work_Order__c();
        insert wo;
        WorkOrderPageDTO.QuoteDTO q = LovingRevenueCloudQuoteService.buildQuote(wo.Id);
        Assert.isNotNull(q.quoteName, 'quoteName should carry stub message');
        Assert.isNull(q.quoteId,    'quoteId should be null on stub');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingBuilderPricingService
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void builderPricing_buildPricing_noPricingBook_returnsStandard() {
        Work_Order__c wo = new Work_Order__c(
            Division_Account__c = null,
            Parent_Account__c   = null
        );
        insert wo;
        wo = [
            SELECT Id, Division_Account__c, Parent_Account__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.PricingDTO p = LovingBuilderPricingService.buildPricing(wo);
        Assert.areEqual('Standard Pricebook', p.pricingSource);
        Assert.isNull(p.builderPricingBookId);
        Assert.isNull(p.pricebookName);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingSubWorkOrderService — buildAutoTriggered
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void subWO_buildAutoTriggered_noChildren_returnsEmpty() {
        Work_Order__c parent = new Work_Order__c();
        insert parent;
        List<WorkOrderPageDTO.ChildWODTO> children =
            LovingSubWorkOrderService.buildAutoTriggered(parent.Id);
        Assert.areEqual(0, children.size());
    }

    @IsTest
    private static void subWO_buildAutoTriggered_withChild_returnsOne() {
        Work_Order__c parent = new Work_Order__c();
        insert parent;
        Work_Order__c child = new Work_Order__c(
            Parent_Work_Order__c = parent.Id,
            Work_Order_Type__c   = 'Finished Job',
            Trigger_Source__c    = 'Closeout'
        );
        insert child;
        List<WorkOrderPageDTO.ChildWODTO> children =
            LovingSubWorkOrderService.buildAutoTriggered(parent.Id);
        Assert.areEqual(1, children.size());
        Assert.areEqual('Finished Job', children[0].workOrderType);
    }

    @IsTest
    private static void subWO_buildAutoTriggered_nullParentId_returnsEmpty() {
        List<WorkOrderPageDTO.ChildWODTO> children =
            LovingSubWorkOrderService.buildAutoTriggered(null);
        Assert.areEqual(0, children.size());
    }

    @IsTest
    private static void subWO_buildAutoTriggered_multipleChildren_allReturned() {
        Work_Order__c parent = new Work_Order__c();
        insert parent;
        List<Work_Order__c> kids = new List<Work_Order__c>{
            new Work_Order__c(Parent_Work_Order__c = parent.Id, Work_Order_Type__c = 'Warranty'),
            new Work_Order__c(Parent_Work_Order__c = parent.Id, Work_Order_Type__c = 'Customer Care')
        };
        insert kids;
        List<WorkOrderPageDTO.ChildWODTO> children =
            LovingSubWorkOrderService.buildAutoTriggered(parent.Id);
        Assert.areEqual(2, children.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingSubWorkOrderService — buildSubWorkOrder
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void subWO_buildSubWorkOrder_fjType() {
        Work_Order__c wo = new Work_Order__c(
            Work_Order_Type__c = 'Finished Job',
            Is_Finished_Job__c = true,
            FJ_Reason_Code__c  = 'Loading Error',
            FJ_Reason_Detail__c = 'Items left on truck'
        );
        insert wo;
        wo = [
            SELECT Id, Work_Order_Type__c, Is_Finished_Job__c, FJ_Reason_Code__c, FJ_Reason_Detail__c,
                   FJ_Original_Foreman__c, FJ_Original_Foreman__r.Name,
                   Is_Warranty__c, Customer_Report__c, Warranty_Determination__c,
                   Warranty_Coverage_Status__c, Warranty_Coverage_Type__c,
                   Warranty_Start_Date__c, Warranty_End_Date__c, Warranty_Voided_Reason__c,
                   Source__c, Request_Received_Date__c, EPO_Status__c, EPO_Sent_Date__c,
                   EPO_Received_Date__c, EPO_Days_Outstanding__c, EPO_SLA_Tier__c, EPO_SLA_Breach__c,
                   Parent_Work_Order__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.SubWorkOrderDTO sub = LovingSubWorkOrderService.buildSubWorkOrder(wo);
        Assert.isTrue(sub.isFinishedJob);
        Assert.areEqual('Loading Error', sub.fjReasonCode);
        Assert.areEqual('Items left on truck', sub.fjReasonDetail);
    }

    @IsTest
    private static void subWO_buildSubWorkOrder_warrantyType() {
        Work_Order__c wo = new Work_Order__c(
            Work_Order_Type__c        = 'Warranty',
            Is_Warranty__c            = true,
            Warranty_Coverage_Type__c = 'Full Coverage',
            Customer_Report__c        = 'Brown patch on front lawn'
        );
        insert wo;
        wo = [
            SELECT Id, Work_Order_Type__c, Is_Finished_Job__c, FJ_Reason_Code__c, FJ_Reason_Detail__c,
                   FJ_Original_Foreman__c, FJ_Original_Foreman__r.Name,
                   Is_Warranty__c, Customer_Report__c, Warranty_Determination__c,
                   Warranty_Coverage_Status__c, Warranty_Coverage_Type__c,
                   Warranty_Start_Date__c, Warranty_End_Date__c, Warranty_Voided_Reason__c,
                   Source__c, Request_Received_Date__c, EPO_Status__c, EPO_Sent_Date__c,
                   EPO_Received_Date__c, EPO_Days_Outstanding__c, EPO_SLA_Tier__c, EPO_SLA_Breach__c,
                   Parent_Work_Order__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.SubWorkOrderDTO sub = LovingSubWorkOrderService.buildSubWorkOrder(wo);
        Assert.isTrue(sub.isWarranty);
        Assert.areEqual('Brown patch on front lawn', sub.customerReport);
        Assert.areEqual('Full Coverage', sub.warrantyCoverageType);
    }

    @IsTest
    private static void subWO_buildSubWorkOrder_ccType() {
        Work_Order__c wo = new Work_Order__c(
            Work_Order_Type__c    = 'Customer Care',
            EPO_Status__c         = 'Sent',
            // Set EPO_Sent_Date__c 5 days ago so formula calculates 5 days outstanding → 'Red'
            EPO_Sent_Date__c      = Date.today().addDays(-5),
            EPO_SLA_Breach__c     = false,
            Source__c             = 'Portal'
        );
        insert wo;
        wo = [
            SELECT Id, Work_Order_Type__c, Is_Finished_Job__c, FJ_Reason_Code__c, FJ_Reason_Detail__c,
                   FJ_Original_Foreman__c, FJ_Original_Foreman__r.Name,
                   Is_Warranty__c, Customer_Report__c, Warranty_Determination__c,
                   Warranty_Coverage_Status__c, Warranty_Coverage_Type__c,
                   Warranty_Start_Date__c, Warranty_End_Date__c, Warranty_Voided_Reason__c,
                   Source__c, Request_Received_Date__c, EPO_Status__c, EPO_Sent_Date__c,
                   EPO_Received_Date__c, EPO_Days_Outstanding__c, EPO_SLA_Tier__c, EPO_SLA_Breach__c,
                   Parent_Work_Order__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.SubWorkOrderDTO sub = LovingSubWorkOrderService.buildSubWorkOrder(wo);
        Assert.areEqual('Sent', sub.epoStatus);
        Assert.isTrue(sub.epoDaysOutstanding >= 5, 'epoDaysOutstanding should be >= 5 (5 days after EPO_Sent_Date)');
        Assert.areEqual('Red', sub.epoSlaTier, 'SLA tier should be Red for >= 5 days outstanding');
        Assert.areEqual('Portal', sub.source);
    }

    @IsTest
    private static void subWO_buildSubWorkOrder_noSpecialType_isFinishedJobFalse() {
        Work_Order__c wo = new Work_Order__c(
            Work_Order_Type__c = 'Production Install',
            Is_Finished_Job__c = false,
            Is_Warranty__c     = false
        );
        insert wo;
        wo = [
            SELECT Id, Work_Order_Type__c, Is_Finished_Job__c, FJ_Reason_Code__c, FJ_Reason_Detail__c,
                   FJ_Original_Foreman__c, FJ_Original_Foreman__r.Name,
                   Is_Warranty__c, Customer_Report__c, Warranty_Determination__c,
                   Warranty_Coverage_Status__c, Warranty_Coverage_Type__c,
                   Warranty_Start_Date__c, Warranty_End_Date__c, Warranty_Voided_Reason__c,
                   Source__c, Request_Received_Date__c, EPO_Status__c, EPO_Sent_Date__c,
                   EPO_Received_Date__c, EPO_Days_Outstanding__c, EPO_SLA_Tier__c, EPO_SLA_Breach__c,
                   Parent_Work_Order__c
            FROM   Work_Order__c
            WHERE  Id = :wo.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.SubWorkOrderDTO sub = LovingSubWorkOrderService.buildSubWorkOrder(wo);
        Assert.isFalse(sub.isFinishedJob);
        Assert.isFalse(sub.isWarranty);
    }

    @IsTest
    private static void subWO_buildSubWorkOrder_withParentWorkOrder_resolvesParentName() {
        Work_Order__c parent = new Work_Order__c();
        insert parent;
        Work_Order__c child = new Work_Order__c(
            Parent_Work_Order__c = parent.Id,
            Work_Order_Type__c   = 'Finished Job',
            Is_Finished_Job__c   = true
        );
        insert child;
        child = [
            SELECT Id, Work_Order_Type__c, Is_Finished_Job__c, FJ_Reason_Code__c, FJ_Reason_Detail__c,
                   FJ_Original_Foreman__c, FJ_Original_Foreman__r.Name,
                   Is_Warranty__c, Customer_Report__c, Warranty_Determination__c,
                   Warranty_Coverage_Status__c, Warranty_Coverage_Type__c,
                   Warranty_Start_Date__c, Warranty_End_Date__c, Warranty_Voided_Reason__c,
                   Source__c, Request_Received_Date__c, EPO_Status__c, EPO_Sent_Date__c,
                   EPO_Received_Date__c, EPO_Days_Outstanding__c, EPO_SLA_Tier__c, EPO_SLA_Breach__c,
                   Parent_Work_Order__c
            FROM   Work_Order__c
            WHERE  Id = :child.Id
            LIMIT  1
        ];
        WorkOrderPageDTO.SubWorkOrderDTO sub = LovingSubWorkOrderService.buildSubWorkOrder(child);
        Assert.areEqual(String.valueOf(parent.Id), sub.parentWorkOrderId,
            'parentWorkOrderId should be populated');
        Assert.isNotNull(sub.parentWorkOrderName, 'parentWorkOrderName should be resolved');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingWorkOrderPageService — build
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void pageService_build_productionInstall_returnsValidDTO() {
        Work_Order__c wo = new Work_Order__c(
            Status__c             = 'Scheduled',
            Pipeline_Stage__c     = 'Scheduled',
            Work_Order_Type__c    = 'Production Install',
            Scheduled_Date__c     = Date.today().addDays(5),
            Job_Health__c         = 'Green',
            Billable_Type__c      = 'Billable (PO)',
            Closeout_Photo_Count__c = 0
        );
        insert wo;
        Test.startTest();
        WorkOrderPageDTO dto = LovingWorkOrderPageService.build(wo.Id);
        Test.stopTest();

        Assert.isNotNull(dto);
        Assert.isNotNull(dto.header);
        Assert.areEqual(wo.Id, dto.header.recordId);
        Assert.areEqual('Production Install', dto.header.workOrderType);
        Assert.areEqual('Scheduled', dto.header.pipelineStage);
        Assert.isNotNull(dto.lifePath);
        Assert.areEqual('Scheduled', dto.lifePath.currentStage);
        Assert.isNotNull(dto.lineItems);
        Assert.isNotNull(dto.warnings);
        Assert.isTrue(dto.errors.isEmpty());
    }

    @IsTest
    private static void pageService_build_nullId_returnsError() {
        Test.startTest();
        WorkOrderPageDTO dto = LovingWorkOrderPageService.build(null);
        Test.stopTest();
        Assert.isFalse(dto.errors.isEmpty());
    }

    @IsTest
    private static void pageService_build_allSectionsPopulated() {
        Work_Order__c wo = new Work_Order__c(
            Status__c          = 'In Progress',
            Pipeline_Stage__c  = 'In Progress',
            Work_Order_Type__c = 'Production Install',
            Division__c        = 'Charlotte',
            Billable_Type__c   = 'Billable (PO)'
        );
        insert wo;
        Test.startTest();
        WorkOrderPageDTO dto = LovingWorkOrderPageService.build(wo.Id);
        Test.stopTest();

        Assert.isNotNull(dto.highlights,     'highlights should not be null');
        Assert.isNotNull(dto.property,       'property should not be null');
        Assert.isNotNull(dto.po,             'po should not be null');
        Assert.isNotNull(dto.takeoff,        'takeoff should not be null');
        Assert.isNotNull(dto.quote,          'quote should not be null');
        Assert.isNotNull(dto.pricing,        'pricing should not be null');
        Assert.isNotNull(dto.schedule,       'schedule should not be null');
        Assert.isNotNull(dto.closeout,       'closeout should not be null');
        Assert.isNotNull(dto.qi,             'qi should not be null');
        Assert.isNotNull(dto.invoice,        'invoice should not be null');
        Assert.isNotNull(dto.subWorkOrder,   'subWorkOrder should not be null');
        Assert.isNotNull(dto.autoTriggered,  'autoTriggered should not be null');
        Assert.isNotNull(dto.relatedCounts,  'relatedCounts should not be null');
        Assert.isNotNull(dto.lastUpdated,    'lastUpdated should be set');
    }

    @IsTest
    private static void pageService_build_headerPipelineSourceContainsWO() {
        Work_Order__c wo = new Work_Order__c(
            Status__c          = 'New',
            Pipeline_Stage__c  = '90+ Days',
            Work_Order_Type__c = 'Production Install'
        );
        insert wo;
        Test.startTest();
        WorkOrderPageDTO dto = LovingWorkOrderPageService.build(wo.Id);
        Test.stopTest();
        Assert.isTrue(dto.header.pipelineSource.contains('WO'),
            'Pipeline source chain should always include WO');
    }

    @IsTest
    private static void pageService_build_closeoutPhotoCountReflected() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c       = 'In Progress',
            Closeout_Photo_Count__c = 7
        );
        insert wo;
        Test.startTest();
        WorkOrderPageDTO dto = LovingWorkOrderPageService.build(wo.Id);
        Test.stopTest();
        Assert.areEqual(7, dto.closeout.photoCount);
    }

    @IsTest
    private static void pageService_build_qiFields_populated() {
        Work_Order__c wo = new Work_Order__c(
            Pipeline_Stage__c = 'QI Complete',
            QI_Complete__c    = true
        );
        insert wo;
        Test.startTest();
        WorkOrderPageDTO dto = LovingWorkOrderPageService.build(wo.Id);
        Test.stopTest();
        Assert.isTrue(dto.qi.qiComplete);
        Assert.isFalse(dto.qi.qiScheduled,
            'qiScheduled is always false — field not deployed');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingWorkOrderPageController
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void controller_getWorkOrderPageData_returnsDTO() {
        Work_Order__c wo = new Work_Order__c(
            Status__c          = 'In Progress',
            Pipeline_Stage__c  = 'In Progress',
            Work_Order_Type__c = 'Production Install'
        );
        insert wo;
        Test.startTest();
        WorkOrderPageDTO dto = LovingWorkOrderPageController.getWorkOrderPageData(wo.Id);
        Test.stopTest();
        Assert.isNotNull(dto);
        Assert.areEqual('In Progress', dto.header.pipelineStage);
    }

    @IsTest
    private static void controller_getWorkOrderPageData_nullId_throwsAura() {
        Boolean threw = false;
        Test.startTest();
        try {
            LovingWorkOrderPageController.getWorkOrderPageData(null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        Assert.isTrue(threw);
    }

    @IsTest
    private static void controller_getWorkOrderPageData_validId_noErrors() {
        Work_Order__c wo = new Work_Order__c(
            Status__c          = 'Scheduled',
            Pipeline_Stage__c  = 'Scheduled',
            Work_Order_Type__c = 'Production Install'
        );
        insert wo;
        Test.startTest();
        WorkOrderPageDTO dto = LovingWorkOrderPageController.getWorkOrderPageData(wo.Id);
        Test.stopTest();
        Assert.isNotNull(dto);
        Assert.isTrue(dto.errors.isEmpty(), 'Expected no errors for a valid Work Order Id');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingWorkOrderLineItemService — coverage tests
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void lineItem_noTakeoff_returnsEmptyList() {
        Work_Order__c wo = new Work_Order__c(
            Status__c = 'New'
        );
        insert wo;
        Test.startTest();
        List<WorkOrderPageDTO.LineItemDTO> items =
            LovingWorkOrderLineItemService.buildLineItems(wo.Id);
        Test.stopTest();
        Assert.areEqual(0, items.size(), 'No line items when WO has no Takeoff');
    }

    @IsTest
    private static void lineItem_withTakeoffAndLines_returnsPopulatedList() {
        // Create Takeoff__c
        Takeoff__c tkf = new Takeoff__c(
            Status__c = 'Draft'
        );
        insert tkf;

        // Create Takeoff_Line__c records on it
        Takeoff_Line__c line1 = new Takeoff_Line__c(
            Takeoff__c            = tkf.Id,
            Item_Description__c   = 'Sod - Bermuda 419',
            Determination__c      = 'Match',
            PO_Quantity__c        = 500,
            Measured_Quantity__c  = 480,
            Verified_Quantity__c  = 480,
            Unit__c               = 'Sq Ft',
            Unit_Price__c         = 0.45,
            Sort_Order__c         = 1
        );
        Takeoff_Line__c line2 = new Takeoff_Line__c(
            Takeoff__c            = tkf.Id,
            Item_Description__c   = 'Irrigation Head',
            Determination__c      = 'Substitution',
            PO_Quantity__c        = 10,
            Material_Substitution__c = true,
            Substitution_Notes__c = 'Hunter head used instead',
            Sort_Order__c         = 2
        );
        insert new List<Takeoff_Line__c>{ line1, line2 };

        // Create WO linked to the Takeoff
        Work_Order__c wo = new Work_Order__c(
            Status__c  = 'New',
            Takeoff__c = tkf.Id
        );
        insert wo;

        Test.startTest();
        List<WorkOrderPageDTO.LineItemDTO> items =
            LovingWorkOrderLineItemService.buildLineItems(wo.Id);
        Test.stopTest();

        Assert.areEqual(2, items.size(), 'Should return 2 line items');
        Assert.areEqual('Sod - Bermuda 419', items[0].productName);
        Assert.areEqual('Match',             items[0].category);
        Assert.areEqual(0.45 * 480,          items[0].extendedPrice, 'Extended price = unit * verified qty');
        Assert.isFalse(items[0].substitutionRequired);
        Assert.isTrue(items[1].substitutionRequired, 'Line 2 should flag substitution');
        Assert.areEqual('Takeoff', items[0].pricingSource);
    }

    @IsTest
    private static void lineItem_nullUnitPrice_extendedPriceIsNull() {
        Takeoff__c tkf = new Takeoff__c(Status__c = 'Draft');
        insert tkf;
        Takeoff_Line__c line = new Takeoff_Line__c(
            Takeoff__c           = tkf.Id,
            Item_Description__c  = 'Test Item',
            PO_Quantity__c       = 10,
            Unit_Price__c        = null
        );
        insert line;
        Work_Order__c wo = new Work_Order__c(Status__c = 'New', Takeoff__c = tkf.Id);
        insert wo;

        Test.startTest();
        List<WorkOrderPageDTO.LineItemDTO> items =
            LovingWorkOrderLineItemService.buildLineItems(wo.Id);
        Test.stopTest();

        Assert.areEqual(1, items.size());
        Assert.isNull(items[0].extendedPrice, 'Extended price must be null when unit price is null');
    }

    @IsTest
    private static void lineItem_allQuantitiesNull_extendedPriceIsNull() {
        Takeoff__c tkf = new Takeoff__c(Status__c = 'Draft');
        insert tkf;
        Takeoff_Line__c line = new Takeoff_Line__c(
            Takeoff__c           = tkf.Id,
            Item_Description__c  = 'No Qty Item',
            Unit_Price__c        = 1.00
            // All three quantity fields intentionally null
        );
        insert line;
        Work_Order__c wo = new Work_Order__c(Status__c = 'New', Takeoff__c = tkf.Id);
        insert wo;

        Test.startTest();
        List<WorkOrderPageDTO.LineItemDTO> items =
            LovingWorkOrderLineItemService.buildLineItems(wo.Id);
        Test.stopTest();

        Assert.areEqual(1, items.size());
        Assert.isNull(items[0].extendedPrice, 'Extended price must be null when all quantities null');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LovingBuilderPricingService — coverage tests
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    private static void pricing_noAccount_returnsStandardPricebook() {
        Work_Order__c wo = new Work_Order__c(
            Status__c = 'New'
            // Division_Account__c and Parent_Account__c both null
        );
        insert wo;
        Test.startTest();
        WorkOrderPageDTO.PricingDTO dto = LovingBuilderPricingService.buildPricing(wo);
        Test.stopTest();
        Assert.areEqual('Standard Pricebook', dto.pricingSource);
        Assert.isNull(dto.builderPricingBookId);
    }

    @IsTest
    private static void pricing_accountWithBook_returnsPricingBook() {
        // Create an Account
        Account acc = new Account(Name = 'Test Builder');
        insert acc;

        // Create an active pricing book for that account
        Builder_Pricing_Book__c book = new Builder_Pricing_Book__c(
            Builder_Account__c  = acc.Id,
            Status__c           = 'Active'
        );
        insert book;

        // Create WO with Division_Account__c = acc
        Work_Order__c wo = new Work_Order__c(
            Status__c          = 'New',
            Division_Account__c = acc.Id
        );
        insert wo;

        // Re-query to populate Division_Account__c Id on the SObject
        wo = [SELECT Id, Division_Account__c, Parent_Account__c FROM Work_Order__c WHERE Id = :wo.Id LIMIT 1];

        Test.startTest();
        WorkOrderPageDTO.PricingDTO dto = LovingBuilderPricingService.buildPricing(wo);
        Test.stopTest();

        Assert.areEqual('Builder Pricing Book', dto.pricingSource);
        Assert.areEqual(book.Id,                dto.builderPricingBookId);
    }

    @IsTest
    private static void pricing_parentBookFallback_returnsPricingBook() {
        // No division-level book, only parent-level
        Account parent = new Account(Name = 'Parent Builder');
        insert parent;

        Builder_Pricing_Book__c book = new Builder_Pricing_Book__c(
            Builder_Account__c  = parent.Id,
            Status__c           = 'Active'
        );
        insert book;

        // WO with Parent_Account__c = parent but no Division_Account__c
        Work_Order__c wo = new Work_Order__c(
            Status__c         = 'New',
            Parent_Account__c = parent.Id
        );
        insert wo;

        wo = [SELECT Id, Division_Account__c, Parent_Account__c FROM Work_Order__c WHERE Id = :wo.Id LIMIT 1];

        Test.startTest();
        WorkOrderPageDTO.PricingDTO dto = LovingBuilderPricingService.buildPricing(wo);
        Test.stopTest();

        Assert.areEqual('Builder Pricing Book', dto.pricingSource);
        Assert.areEqual(book.Id,                dto.builderPricingBookId);
    }

    @IsTest
    private static void pricing_accountWithNoBook_returnsStandardPricebook() {
        Account acc = new Account(Name = 'Builder No Book');
        insert acc;

        Work_Order__c wo = new Work_Order__c(
            Status__c          = 'New',
            Division_Account__c = acc.Id,
            Parent_Account__c  = acc.Id
        );
        insert wo;

        wo = [SELECT Id, Division_Account__c, Parent_Account__c FROM Work_Order__c WHERE Id = :wo.Id LIMIT 1];

        Test.startTest();
        WorkOrderPageDTO.PricingDTO dto = LovingBuilderPricingService.buildPricing(wo);
        Test.stopTest();

        Assert.areEqual('Standard Pricebook', dto.pricingSource);
        Assert.isNull(dto.builderPricingBookId);
    }
}