/**
 * LovingWorkOrderLifecycleService
 *
 * Service class that derives lifecycle / life-path data from a Work_Order__c
 * record.  Builds the LifePathDTO, resolves the canonical pipeline stage,
 * computes gate-warning violations, and answers business questions such as
 * isPaid() and isClosedBlocked().
 *
 * All stage names and order values are driven by the STAGE_ORDER map — no
 * hardcoded numeric literals for stage logic outside of that map.
 *
 * @group Work Order Page
 */
public with sharing class LovingWorkOrderLifecycleService {

    // ─── Stage Ordering Map ───────────────────────────────────────────────────
    // Keys must exactly match Pipeline_Stage__c picklist values.
    @TestVisible
    private static final Map<String, Integer> STAGE_ORDER = new Map<String, Integer>{
        '90+ Days'            => 1,
        '60+ Days'            => 2,
        '31 Days'             => 3,
        'Pending Takeoff'     => 4,
        'Takeoff Scheduled'   => 5,
        'Clear for Schedule'  => 6,
        'Scheduled'           => 7,
        'Site Readiness Check'=> 8,
        'In Progress'         => 9,
        'Completion Status'   => 10,
        'Pending Approval'    => 11,
        'Approved'            => 12,
        'QI Scheduled'        => 13,
        'Invoiced'            => 14,
        'QI Complete'         => 15,
        'Paid'                => 16,
        'Closed'              => 17
    };

    // Ordered list of stage names, used to resolve "next stage".
    @TestVisible
    private static final List<String> STAGE_SEQUENCE = new List<String>{
        '90+ Days',
        '60+ Days',
        '31 Days',
        'Pending Takeoff',
        'Takeoff Scheduled',
        'Clear for Schedule',
        'Scheduled',
        'Site Readiness Check',
        'In Progress',
        'Completion Status',
        'Pending Approval',
        'Approved',
        'QI Scheduled',
        'Invoiced',
        'QI Complete',
        'Paid',
        'Closed'
    };

    // ─── Status Fallback Map ──────────────────────────────────────────────────
    // Maps Work_Order__c.Status__c values → canonical Pipeline_Stage__c name.
    @TestVisible
    private static final Map<String, String> STATUS_TO_STAGE = new Map<String, String>{
        'New'                  => '90+ Days',
        'Draft'                => '90+ Days',
        'Pending Takeoff'      => 'Pending Takeoff',
        'Takeoff In Progress'  => 'Takeoff Scheduled',
        'Ready to Schedule'    => 'Clear for Schedule',
        'Clear for Schedule'   => 'Clear for Schedule',
        'Scheduled'            => 'Scheduled',
        'Site Readiness Check' => 'Site Readiness Check',
        'In Progress'          => 'In Progress',
        'Pending Closeout'     => 'Completion Status',
        'Need Further Info'    => 'Pending Approval',
        'NFI'                  => 'Pending Approval',
        'Pending Approval'     => 'Pending Approval',
        'Approved'             => 'Approved',
        'FM QI Review'         => 'QI Scheduled',
        'Invoiced'             => 'Invoiced',
        'Paid'                 => 'Paid',
        'Closed'               => 'Closed'
    };

    // ─── Minimum photo count threshold ───────────────────────────────────────
    private static final Integer MIN_CLOSEOUT_PHOTOS = 4;

    // ─── Celigo payment status value ─────────────────────────────────────────
    private static final String CELIGO_PAID_VALUE = 'Paid';

    // ─── Takeoff approval statuses that satisfy the gate check ───────────────
    private static final Set<String> TAKEOFF_APPROVED_STATUSES = new Set<String>{
        'Approved', 'Locked'
    };

    // ─── 811 cleared status value ────────────────────────────────────────────
    private static final String EIGHT11_CLEARED_VALUE = 'Cleared';

    // ─── Site readiness ready value ──────────────────────────────────────────
    private static final String SITE_READY_VALUE = 'Ready';

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Build the full LifePathDTO for a given Work_Order__c record.
     *
     * @param wo  A Work_Order__c instance with all required fields populated.
     * @return    Populated LifePathDTO; never null.
     */
    public static WorkOrderPageDTO.LifePathDTO buildLifePath(Work_Order__c wo) {
        WorkOrderPageDTO.LifePathDTO dto = new WorkOrderPageDTO.LifePathDTO();

        String stage        = normalizeStage(wo.Pipeline_Stage__c, wo.Status__c);
        Integer stageOrder  = getStageOrder(stage);
        String nextStage    = resolveNextStage(stage);

        Boolean paid        = isPaid(wo);
        Boolean qiComplete  = (wo.QI_Complete__c == true);
        Boolean closedBlock = isClosedBlocked(wo);

        dto.currentStage      = stage;
        dto.nextStage         = nextStage;
        dto.currentOrder      = stageOrder;
        dto.isPaid            = paid;
        dto.isQiComplete      = qiComplete;
        dto.isClosedBlocked   = closedBlock;
        dto.showClosedWarning = closedBlock;
        dto.warnings          = buildWarnings(wo);

        return dto;
    }

    /**
     * Resolve the canonical stage name.
     * Prefers Pipeline_Stage__c when it is a known stage; falls back to
     * mapping Status__c.
     *
     * @param pipelineStage  Value of Work_Order__c.Pipeline_Stage__c (may be null).
     * @param status         Value of Work_Order__c.Status__c (may be null).
     * @return               Canonical stage name, or '90+ Days' when unknown.
     */
    public static String normalizeStage(String pipelineStage, String status) {
        if (String.isNotBlank(pipelineStage) && STAGE_ORDER.containsKey(pipelineStage)) {
            return pipelineStage;
        }
        if (String.isNotBlank(status) && STATUS_TO_STAGE.containsKey(status)) {
            return STATUS_TO_STAGE.get(status);
        }
        return STAGE_SEQUENCE[0]; // default: earliest stage
    }

    /**
     * Return the integer order for a canonical stage name.
     *
     * @param stageName  Canonical stage name.
     * @return           Stage order (1–17), or 0 if not found.
     */
    public static Integer getStageOrder(String stageName) {
        if (String.isBlank(stageName) || !STAGE_ORDER.containsKey(stageName)) {
            return 0;
        }
        return STAGE_ORDER.get(stageName);
    }

    /**
     * Determine whether the work order is blocked from being closed.
     * Blocked when the stage is "Closed" but QI is incomplete OR payment
     * has not been confirmed.
     *
     * @param wo  Work_Order__c record.
     * @return    True if currently blocked from closure.
     */
    public static Boolean isClosedBlocked(Work_Order__c wo) {
        String stage = normalizeStage(wo.Pipeline_Stage__c, wo.Status__c);
        if (stage != 'Closed') {
            return false;
        }
        Boolean paid       = isPaid(wo);
        Boolean qiComplete = (wo.QI_Complete__c == true);
        return !(qiComplete && paid);
    }

    /**
     * Determine whether the work order has been paid.
     * Considers both the native Paid__c checkbox and the Celigo integration
     * payment status.
     *
     * @param wo  Work_Order__c record.
     * @return    True if paid by either signal.
     */
    public static Boolean isPaid(Work_Order__c wo) {
        if (wo.Paid__c == true) {
            return true;
        }
        if (wo.Celigo_Payment_Status__c == CELIGO_PAID_VALUE) {
            return true;
        }
        return false;
    }

    /**
     * Build the list of gate-warning violations for the current stage.
     * Warnings are additive — all applicable checks are evaluated.
     *
     * @param wo  Work_Order__c record with all gate fields populated.
     * @return    List of WarningDTO; empty list when no violations.
     */
    public static List<WorkOrderPageDTO.WarningDTO> buildWarnings(Work_Order__c wo) {
        List<WorkOrderPageDTO.WarningDTO> warnings = new List<WorkOrderPageDTO.WarningDTO>();

        String  stage      = normalizeStage(wo.Pipeline_Stage__c, wo.Status__c);
        Integer stageOrder = getStageOrder(stage);

        // Stage >= 6 (Clear for Schedule): Takeoff approval
        if (stageOrder >= 6) {
            if (!TAKEOFF_APPROVED_STATUSES.contains(wo.Takeoff_Status__c)) {
                warnings.add(makeWarning(
                    'TAKEOFF_NOT_APPROVED',
                    'Takeoff not approved',
                    'warning'
                ));
            }
        }

        // Stage >= 6: 811 clearance
        if (stageOrder >= 6) {
            if (wo.Eight11_Task_Status__c != EIGHT11_CLEARED_VALUE) {
                warnings.add(makeWarning(
                    'EIGHT11_NOT_CLEARED',
                    '811 not cleared',
                    'warning'
                ));
            }
        }

        // Stage >= 7 (Scheduled): scheduling fields
        if (stageOrder >= 7) {
            if (wo.Scheduled_Date__c == null) {
                warnings.add(makeWarning(
                    'SCHEDULED_DATE_MISSING',
                    'Scheduled Date missing',
                    'warning'
                ));
            }
            if (wo.Crew__c == null) {
                warnings.add(makeWarning(
                    'CREW_NOT_ASSIGNED',
                    'Crew not assigned',
                    'warning'
                ));
            }
            if (wo.Field_Manager__c == null) {
                warnings.add(makeWarning(
                    'FIELD_MANAGER_NOT_ASSIGNED',
                    'Field Manager not assigned',
                    'warning'
                ));
            }
            if (wo.Stop_Sequence__c == null) {
                warnings.add(makeWarning(
                    'STOP_SEQUENCE_NOT_SET',
                    'Stop Sequence not set',
                    'warning'
                ));
            }
        }

        // Stage >= 9 (In Progress): site readiness
        if (stageOrder >= 9) {
            if (wo.Site_Readiness_Status__c != SITE_READY_VALUE) {
                warnings.add(makeWarning(
                    'SITE_READINESS_NOT_CONFIRMED',
                    'Site Readiness not confirmed',
                    'warning'
                ));
            }
        }

        // Stage >= 10 (Completion Status): crew completion
        if (stageOrder >= 10) {
            if (wo.Crew_Completed__c != true && wo.FSL_Crew_Complete__c != true) {
                warnings.add(makeWarning(
                    'CREW_COMPLETION_NOT_RECORDED',
                    'Crew completion not recorded',
                    'warning'
                ));
            }
        }

        // Stage >= 11 (Pending Approval): closeout requirements
        if (stageOrder >= 11) {
            Decimal photoCount = wo.Closeout_Photo_Count__c != null
                ? wo.Closeout_Photo_Count__c
                : 0;
            if (photoCount < MIN_CLOSEOUT_PHOTOS) {
                warnings.add(makeWarning(
                    'INSUFFICIENT_CLOSEOUT_PHOTOS',
                    'Fewer than ' + MIN_CLOSEOUT_PHOTOS + ' closeout photos',
                    'warning'
                ));
            }
            if (String.isBlank(wo.Closeout_Notes__c)) {
                warnings.add(makeWarning(
                    'CLOSEOUT_NOTES_MISSING',
                    'Closeout notes missing',
                    'warning'
                ));
            }
        }

        // Stage >= 12 (Approved): approval process
        if (stageOrder >= 12) {
            if (wo.Approval_Process_Completed__c != true) {
                warnings.add(makeWarning(
                    'APPROVAL_PROCESS_INCOMPLETE',
                    'Approval process not complete',
                    'warning'
                ));
            }
        }

        // Stage >= 14 (Invoiced): invoice generation
        if (stageOrder >= 14) {
            if (wo.Invoice_Generated__c != true) {
                warnings.add(makeWarning(
                    'INVOICE_NOT_GENERATED',
                    'Invoice not generated',
                    'warning'
                ));
            }
        }

        // Stage >= 16 (Paid): payment confirmation
        if (stageOrder >= 16) {
            if (!isPaid(wo)) {
                warnings.add(makeWarning(
                    'PAYMENT_NOT_CONFIRMED',
                    'Payment not confirmed',
                    'warning'
                ));
            }
        }

        // Stage >= 17 (Closed): QI and payment are hard errors
        if (stageOrder >= 17) {
            if (wo.QI_Complete__c != true) {
                warnings.add(makeWarning(
                    'QI_NOT_COMPLETE',
                    'QI not complete',
                    'error'
                ));
            }
            if (!isPaid(wo)) {
                warnings.add(makeWarning(
                    'PAYMENT_NOT_RECEIVED',
                    'Payment not received',
                    'error'
                ));
            }
        }

        return warnings;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Return the next stage name after the provided stage, or null if already
     * at the final stage.
     */
    private static String resolveNextStage(String currentStage) {
        Integer currentOrder = getStageOrder(currentStage);
        for (String s : STAGE_SEQUENCE) {
            if (getStageOrder(s) == currentOrder + 1) {
                return s;
            }
        }
        return null;
    }

    /**
     * Construct a WarningDTO with the given key, message, and severity.
     */
    private static WorkOrderPageDTO.WarningDTO makeWarning(
        String key,
        String message,
        String severity
    ) {
        WorkOrderPageDTO.WarningDTO w = new WorkOrderPageDTO.WarningDTO();
        w.key      = key;
        w.message  = message;
        w.severity = severity;
        return w;
    }
}