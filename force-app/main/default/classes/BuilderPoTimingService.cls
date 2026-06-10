/**
 * BuilderPoTimingService
 * Core service for Builder PO pipeline bucket calculation and timing rule evaluation.
 * Called by BuilderPoPipelineBucketScheduler (daily) and can be invoked manually.
 */
public with sharing class BuilderPoTimingService {

    // ── Division mappings ─────────────────────────────────────────────────────

    private static final Map<String, String> CODE_TO_NAME = new Map<String, String>{
        'CLT'  => 'Charlotte',
        'ASH'  => 'Asheville',
        'TRIA' => 'Triad',
        'GRVL' => 'Greenville',
        'COLM' => 'Columbia'
    };

    private static final Map<String, String> NAME_TO_CODE = new Map<String, String>{
        'Charlotte'  => 'CLT',
        'Asheville'  => 'ASH',
        'Triad'      => 'TRIA',
        'Greenville' => 'GRVL',
        'Columbia'   => 'COLM'
    };

    // Stage order map — must match Pipeline_Stage__c picklist values exactly
    private static final Map<String, Integer> STAGE_ORDER = new Map<String, Integer>{
        '90+ Days'           => 1,
        '60+ Days'           => 2,
        '31 Days'            => 3,
        'Pending Takeoff'    => 4,
        'Takeoff Scheduled'  => 5,
        'Clear for Schedule' => 6,
        'Scheduled'          => 7,
        'Site Readiness Check' => 8,
        'In Progress'        => 9,
        'Completion Status'  => 10,
        'Pending Approval'   => 11,
        'Approved'           => 12,
        'QI Scheduled'       => 13,
        'Invoiced'           => 14,
        'QI Complete'        => 15,
        'Paid'               => 16,
        'Closed'             => 17
    };

    // Stages at or beyond which the bucket engine will not move a record backward
    private static final Integer SCHEDULING_LOCK_ORDER = 7; // 'Scheduled'

    // ── Public API ────────────────────────────────────────────────────────────

    /**
     * Convert a division code to its full name. Returns null if unrecognized.
     */
    public static String normalizeDivisionCode(String code) {
        if (String.isBlank(code)) return null;
        return CODE_TO_NAME.get(code.toUpperCase().trim());
    }

    /**
     * Convert a division name to its code. Returns null if unrecognized.
     */
    public static String getDivisionCode(String name) {
        if (String.isBlank(name)) return null;
        return NAME_TO_CODE.get(name.trim());
    }

    /**
     * Alias kept for backward-compat callers.
     */
    public static String getDivisionName(String code) {
        return normalizeDivisionCode(code);
    }

    /**
     * Find the best-matching Builder_PO_Timing_Rule__c for a given PO.
     * Lookup priority:
     *   1. Division_Account__c match
     *   2. Parent_Account__c + Division_Code__c match
     *   3. Parent_Builder_Name__c + Division_Code__c match
     *   4. Parent_Account__c only match
     *   Returns null if none found.
     */
    public static Builder_PO_Timing_Rule__c findTimingRule(
        String parentBuilderName,
        String divisionCode,
        Id     parentAccountId,
        Id     divisionAccountId
    ) {
        List<Builder_PO_Timing_Rule__c> allRules = [
            SELECT Id, Parent_Account__c, Division_Account__c,
                   Parent_Builder_Name__c, Division_Builder_Name__c,
                   Division_Code__c, Division_Name__c,
                   Min_Days_Before_Start__c, Max_Days_Before_Start__c,
                   Business_Days__c, Active__c
            FROM   Builder_PO_Timing_Rule__c
            WHERE  Active__c = true
        ];

        Builder_PO_Timing_Rule__c byDivAccount  = null;
        Builder_PO_Timing_Rule__c byParentAndDiv = null;
        Builder_PO_Timing_Rule__c byNameAndDiv   = null;
        Builder_PO_Timing_Rule__c byParentOnly   = null;

        for (Builder_PO_Timing_Rule__c r : allRules) {
            // Priority 1: Division_Account__c exact match
            if (divisionAccountId != null
                    && r.Division_Account__c != null
                    && r.Division_Account__c == divisionAccountId) {
                byDivAccount = r;
                break;
            }
        }
        if (byDivAccount != null) return byDivAccount;

        for (Builder_PO_Timing_Rule__c r : allRules) {
            // Priority 2: Parent_Account__c + Division_Code__c
            if (parentAccountId != null && !String.isBlank(divisionCode)
                    && r.Parent_Account__c == parentAccountId
                    && r.Division_Code__c == divisionCode) {
                byParentAndDiv = r;
            }
            // Priority 3: Parent_Builder_Name__c + Division_Code__c
            if (!String.isBlank(parentBuilderName) && !String.isBlank(divisionCode)
                    && r.Parent_Builder_Name__c != null
                    && r.Parent_Builder_Name__c.equalsIgnoreCase(parentBuilderName)
                    && r.Division_Code__c == divisionCode) {
                if (byNameAndDiv == null) byNameAndDiv = r;
            }
            // Priority 4: Parent_Account__c only
            if (parentAccountId != null
                    && r.Parent_Account__c == parentAccountId
                    && String.isBlank(r.Division_Code__c)) {
                if (byParentOnly == null) byParentOnly = r;
            }
        }

        if (byParentAndDiv != null) return byParentAndDiv;
        if (byNameAndDiv   != null) return byNameAndDiv;
        return byParentOnly; // may be null
    }

    /**
     * Count calendar days between two dates (inclusive of start, exclusive of end).
     * Returns negative if startDate > endDate.
     */
    public static Integer calculateCalendarDays(Date startDate, Date endDate) {
        if (startDate == null || endDate == null) return null;
        return startDate.daysBetween(endDate);
    }

    /**
     * Count business days (Mon-Fri) between two dates.
     * Returns negative if startDate > endDate.
     */
    public static Integer calculateBusinessDays(Date startDate, Date endDate) {
        if (startDate == null || endDate == null) return null;
        Integer calDays = startDate.daysBetween(endDate);
        if (calDays == 0) return 0;
        Integer direction = calDays > 0 ? 1 : -1;
        Integer bDays = 0;
        Date cursor = startDate;
        while (cursor != endDate) {
            cursor = cursor.addDays(direction);
            // dayOfWeek: 1=Sunday,2=Monday,...,7=Saturday in Apex Date
            Integer dow = Date.newInstance(cursor.year(), cursor.month(), cursor.day())
                             .toStartOfWeek().daysBetween(cursor);
            // toStartOfWeek returns the Sunday of the week
            // dow: 0=Sunday, 1=Monday,...,6=Saturday
            if (dow >= 1 && dow <= 5) bDays += direction;
        }
        return bDays;
    }

    /**
     * Evaluate the Timing_Status__c for a PO given its rule.
     */
    public static String calculateTimingStatus(Builder_PO__c po, Builder_PO_Timing_Rule__c rule) {
        Date releaseDate = po.PO_Release_Date__c;
        Date startDate   = po.Estimated_Start_Date__c != null
                           ? po.Estimated_Start_Date__c
                           : po.Requested_Install_Date__c;

        if (releaseDate == null || startDate == null) return 'Missing Dates';
        if (rule == null) return 'Missing Rule';

        Integer days;
        if (rule.Business_Days__c) {
            days = calculateBusinessDays(releaseDate, startDate);
        } else {
            days = calculateCalendarDays(releaseDate, startDate);
        }
        if (days == null) return 'Missing Dates';

        Integer minDays = rule.Min_Days_Before_Start__c != null ? Integer.valueOf(rule.Min_Days_Before_Start__c) : 0;
        Integer maxDays = rule.Max_Days_Before_Start__c != null ? Integer.valueOf(rule.Max_Days_Before_Start__c) : 999999;

        if (days < minDays) return 'Late';
        if (days > maxDays) return 'Too Early';
        return 'In Expected Window';
    }

    /**
     * Calculate Pipeline_Stage__c for a Builder_PO__c record based on
     * lifecycle fields and days-to-start. Honors the lock rule: records
     * already at Scheduled or later are not moved backward into bucket stages.
     */
    public static String calculatePipelineStage(Builder_PO__c po) {
        Date startDate = po.Estimated_Start_Date__c != null
                         ? po.Estimated_Start_Date__c
                         : po.Requested_Install_Date__c;

        String current = po.Pipeline_Stage__c;
        Integer currentOrder = (current != null && STAGE_ORDER.containsKey(current))
                               ? STAGE_ORDER.get(current)
                               : 0;

        // ── Date-bucket logic (only applies if not yet past scheduling lock) ──
        if (currentOrder < SCHEDULING_LOCK_ORDER) {
            if (startDate != null) {
                Integer daysToStart = Date.today().daysBetween(startDate);

                if (daysToStart > 90)                       return '90+ Days';
                if (daysToStart >= 61 && daysToStart <= 90) return '60+ Days';
                if (daysToStart >= 31 && daysToStart <= 60) return '31 Days';
            }
        }

        // ── Lifecycle-field progression ───────────────────────────────────────

        // Stage 16/17: Closed
        if (po.QI_Complete__c == true
                && (po.Paid__c == true
                    || po.Celigo_Payment_Status__c == 'Paid')) {
            return 'Closed';
        }

        // Stage 16: Paid
        if (po.Paid__c == true || po.Celigo_Payment_Status__c == 'Paid') {
            return 'Paid';
        }

        // Stage 15: QI Complete
        if (po.QI_Complete__c == true) return 'QI Complete';

        // Stage 14: Invoiced
        if (po.Invoice_Generated__c == true) return 'Invoiced';

        // Stage 13: QI Scheduled
        if (po.QI_Scheduled__c == true) return 'QI Scheduled';

        // Stage 12: Approved
        if (po.Approval_Process_Completed__c == true) return 'Approved';

        // Stage 11: Pending Approval
        if (po.Approval_Submitted__c == true) return 'Pending Approval';

        // Stage 10: Completion Status
        if (po.Crew_Completed__c == true || po.FSL_Crew_Complete__c == true) return 'Completion Status';

        // Stage 9: In Progress
        if (po.Status__c == 'In Progress') return 'In Progress';

        // Stage 8: Site Readiness Check
        if (po.Status__c == 'Site Readiness Check') return 'Site Readiness Check';

        // Stage 7: Scheduled — locked by scheduling engine (crew, FM, date, stop set)
        if (po.Schedule_Locked__c == true
                || po.Status__c == 'Scheduled') {
            return 'Scheduled';
        }

        // Stage 6: Clear for Schedule
        if ((po.Takeoff_Status__c == 'Approved' || po.Takeoff_Status__c == 'Locked')
                && po.Eight11_Task_Status__c == 'Cleared') {
            return 'Clear for Schedule';
        }

        // Stage 5: Takeoff Scheduled
        if (po.Takeoff_Status__c == 'Scheduled'
                || po.Takeoff_Status__c == 'In Progress'
                || po.Takeoff_Status__c == 'Submitted') {
            return 'Takeoff Scheduled';
        }

        // Stage 4: Pending Takeoff (daysToStart <= 30 or no start date)
        if (startDate != null) {
            Integer daysToStart = Date.today().daysBetween(startDate);
            if (daysToStart <= 30) return 'Pending Takeoff';
        }

        // Fallback: keep current stage if already set and past lock; otherwise
        // return bucket based on days (already handled above for pre-lock)
        if (current != null && !String.isBlank(current)) return current;
        return '90+ Days';
    }

    /**
     * Recalculate Pipeline_Stage__c, Timing_Rule__c, and timing fields
     * for a batch of Builder_PO__c records. Returns the updated records
     * (caller is responsible for DML).
     */
    public static List<Builder_PO__c> recalculateBuilderPOs(List<Builder_PO__c> records) {
        // Bulk-load all active timing rules once
        List<Builder_PO_Timing_Rule__c> allRules = [
            SELECT Id, Parent_Account__c, Division_Account__c,
                   Parent_Builder_Name__c, Division_Builder_Name__c,
                   Division_Code__c, Division_Name__c,
                   Min_Days_Before_Start__c, Max_Days_Before_Start__c,
                   Business_Days__c, Active__c
            FROM   Builder_PO_Timing_Rule__c
            WHERE  Active__c = true
        ];

        for (Builder_PO__c po : records) {
            // Normalize Division_Code__c -> Division_Name__c
            if (!String.isBlank(po.Division_Code__c)) {
                String name = normalizeDivisionCode(po.Division_Code__c);
                if (name != null) po.Division_Name__c = name;
            }

            // Find matching timing rule
            Builder_PO_Timing_Rule__c rule = findTimingRuleFromList(
                allRules,
                po.Builder_Name__c,
                po.Division_Code__c,
                po.Parent_Account__c,
                po.Division_Account__c
            );

            // Store timing rule reference and snapshot fields
            po.Timing_Rule__c = rule != null ? rule.Id : null;
            if (rule != null) {
                po.Timing_Rule_Min_Days__c            = rule.Min_Days_Before_Start__c;
                po.Timing_Rule_Max_Days__c            = rule.Max_Days_Before_Start__c;
                po.Timing_Rule_Uses_Business_Days__c  = rule.Business_Days__c;
            } else {
                po.Timing_Rule_Min_Days__c           = null;
                po.Timing_Rule_Max_Days__c           = null;
                po.Timing_Rule_Uses_Business_Days__c = false;
            }

            // Calculate days from PO release to start
            Date releaseDate = po.PO_Release_Date__c;
            Date startDate   = po.Estimated_Start_Date__c != null
                               ? po.Estimated_Start_Date__c
                               : po.Requested_Install_Date__c;

            if (releaseDate != null && startDate != null) {
                po.Days_From_PO_To_Start__c          = calculateCalendarDays(releaseDate, startDate);
                po.Business_Days_From_PO_To_Start__c = calculateBusinessDays(releaseDate, startDate);
            }

            // Timing status
            po.Timing_Status__c = calculateTimingStatus(po, rule);

            // Pipeline stage
            po.Pipeline_Stage__c = calculatePipelineStage(po);
            po.Pipeline_Bucket_Last_Calculated__c = DateTime.now();
        }

        return records;
    }

    /**
     * Push the pipeline bucket from Builder_PO__c records to related
     * standard WorkOrder records that are not yet past execution stages.
     */
    public static void syncStageToWorkOrders(List<Builder_PO__c> updatedPOs) {
        // Collect PO Ids that have standard WorkOrder children.
        Set<Id> poIds = new Set<Id>();
        for (Builder_PO__c po : updatedPOs) poIds.add(po.Id);

        // Stages at or beyond which we do NOT overwrite the WO's pipeline bucket.
        Set<String> woCutoffStages = new Set<String>{ 'Scheduled', 'Site Readiness Check',
            'In Progress', 'Completion Status', 'Pending Approval', 'Approved',
            'QI Scheduled', 'Invoiced', 'QI Complete', 'Paid', 'Closed' };

        Map<Id, String> poStageByPoId = new Map<Id, String>();
        for (Builder_PO__c po : updatedPOs) {
            if (po.Pipeline_Bucket__c != null) poStageByPoId.put(po.Id, po.Pipeline_Bucket__c);
        }

        List<WorkOrder> wosToUpdate = new List<WorkOrder>();
        for (WorkOrder wo : [
            SELECT Id, Builder_PO__c, Pipeline_Bucket__c
            FROM   WorkOrder
            WHERE  Builder_PO__c IN :poIds
               AND Status NOT IN ('Closed', 'Canceled')
        ]) {
            String newStage = poStageByPoId.get(wo.Builder_PO__c);
            if (newStage == null) continue;
            if (woCutoffStages.contains(wo.Pipeline_Bucket__c)) continue;
            wo.Pipeline_Bucket__c = newStage;
            wosToUpdate.add(wo);
        }

        if (!wosToUpdate.isEmpty()) {
            update wosToUpdate;
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static Builder_PO_Timing_Rule__c findTimingRuleFromList(
        List<Builder_PO_Timing_Rule__c> allRules,
        String parentBuilderName,
        String divisionCode,
        Id     parentAccountId,
        Id     divisionAccountId
    ) {
        Builder_PO_Timing_Rule__c byDivAccount   = null;
        Builder_PO_Timing_Rule__c byParentAndDiv = null;
        Builder_PO_Timing_Rule__c byNameAndDiv   = null;
        Builder_PO_Timing_Rule__c byParentOnly   = null;

        for (Builder_PO_Timing_Rule__c r : allRules) {
            if (divisionAccountId != null
                    && r.Division_Account__c != null
                    && r.Division_Account__c == divisionAccountId) {
                return r; // Highest priority - return immediately
            }
            if (parentAccountId != null && !String.isBlank(divisionCode)
                    && r.Parent_Account__c == parentAccountId
                    && r.Division_Code__c == divisionCode
                    && byParentAndDiv == null) {
                byParentAndDiv = r;
            }
            if (!String.isBlank(parentBuilderName) && !String.isBlank(divisionCode)
                    && r.Parent_Builder_Name__c != null
                    && r.Parent_Builder_Name__c.equalsIgnoreCase(parentBuilderName)
                    && r.Division_Code__c == divisionCode
                    && byNameAndDiv == null) {
                byNameAndDiv = r;
            }
            if (parentAccountId != null
                    && r.Parent_Account__c == parentAccountId
                    && String.isBlank(r.Division_Code__c)
                    && byParentOnly == null) {
                byParentOnly = r;
            }
        }

        if (byParentAndDiv != null) return byParentAndDiv;
        if (byNameAndDiv   != null) return byNameAndDiv;
        return byParentOnly;
    }
}