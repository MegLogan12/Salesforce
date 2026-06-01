public with sharing class PurchaseOrderTimingService {
    public static final String STAGE_PO_RECEIVED = 'PO Received';
    public static final String STAGE_PACKAGE_MATCH_CHECK = 'Package Match Check';
    public static final String STAGE_CSM_REVIEW = 'CSM Review';
    public static final String STAGE_TAKEOFF_REQUESTED = 'Takeoff Requested';
    public static final String STAGE_TAKEOFF_SCHEDULED = 'Takeoff Scheduled';
    public static final String STAGE_TAKEOFF_IN_PROGRESS = 'Takeoff In Progress';
    public static final String STAGE_TAKEOFF_COMPLETE = 'Takeoff Complete';
    public static final String STAGE_WORK_ORDER_CREATED = 'WorkOrder Created';
    public static final String STAGE_CLEAR_TO_SCHEDULE = 'Clear for Schedule';
    public static final String STAGE_CLOSED_CONVERTED = 'Closed / Converted';
    public static final String STAGE_CANCELLED_VOID = 'Cancelled / Void';

    public static final String TIMING_IN_EXPECTED_WINDOW = 'In Expected Window';
    public static final String TIMING_LATE = 'Late';
    public static final String TIMING_MISSING_DATES = 'Missing Dates';

    public class TimingResult {
        public String pipelineStage;
        public String timingStatus;
        public Integer daysUntilInstall;
        public String calculationNotes;
    }

    public static Date getTimingDate(Purchase_Order__c po) {
        if (po == null) return null;
        // Temporary transition fallback: Requested_Install_Date__c may be used only when
        // Estimated_Start_Date__c is blank during migration from Builder PO to Purchase Order.
        // Long-term source of truth should be Estimated_Start_Date__c unless Meg approves otherwise.
        return po.Estimated_Start_Date__c != null
            ? po.Estimated_Start_Date__c
            : po.Requested_Install_Date__c;
    }

    public static Integer getDaysUntilInstall(Purchase_Order__c po) {
        Date timingDate = getTimingDate(po);
        return timingDate == null ? null : Date.today().daysBetween(timingDate);
    }

    public static String calculatePipelineStage(Purchase_Order__c po) {
        if (po == null) return STAGE_PO_RECEIVED;

        if (po.Status__c == 'Cancelled') {
            return STAGE_CANCELLED_VOID;
        }

        if (po.Status__c == 'Closed') {
            return STAGE_CLOSED_CONVERTED;
        }

        if (po.Status__c == 'Clear for Schedule') {
            return STAGE_CLEAR_TO_SCHEDULE;
        }

        if (po.Work_Order__c != null || po.Status__c == 'Work Order Created') {
            return STAGE_WORK_ORDER_CREATED;
        }

        if (po.Status__c == 'Takeoff Complete' || po.Takeoff_Status__c == 'Approved') {
            return STAGE_TAKEOFF_COMPLETE;
        }

        if (po.Status__c == 'Takeoff In Progress' || po.Takeoff_Status__c == 'In Progress') {
            return STAGE_TAKEOFF_IN_PROGRESS;
        }

        if (po.Status__c == 'Takeoff Scheduled') {
            return STAGE_TAKEOFF_SCHEDULED;
        }

        if (po.Status__c == 'Ready for Takeoff' || isPackageReadyForTakeoff(po)) {
            return STAGE_TAKEOFF_REQUESTED;
        }

        if (po.Status__c == 'Pending CS Review' || po.Status__c == 'Exception' || isPackageBlocked(po)) {
            return STAGE_CSM_REVIEW;
        }

        if (po.Status__c == 'Package Match Check') {
            return STAGE_PACKAGE_MATCH_CHECK;
        }

        return STAGE_PO_RECEIVED;
    }

    public static String calculateTimingStatus(Purchase_Order__c po) {
        Integer daysUntilInstall = getDaysUntilInstall(po);
        if (daysUntilInstall == null) return TIMING_MISSING_DATES;
        if (daysUntilInstall < 0) return TIMING_LATE;
        return TIMING_IN_EXPECTED_WINDOW;
    }

    public static TimingResult calculate(Purchase_Order__c po) {
        TimingResult result = new TimingResult();
        result.daysUntilInstall = getDaysUntilInstall(po);
        result.pipelineStage = calculatePipelineStage(po);
        result.timingStatus = calculateTimingStatus(po);
        result.calculationNotes = buildCalculationNotes(po, result);
        return result;
    }

    public static List<Purchase_Order__c> recalculatePurchaseOrders(List<Purchase_Order__c> records) {
        List<Purchase_Order__c> updates = new List<Purchase_Order__c>();
        if (records == null || records.isEmpty()) return updates;

        for (Purchase_Order__c po : records) {
            TimingResult result = calculate(po);
            Purchase_Order__c updatePo = new Purchase_Order__c(
                Id = po.Id,
                Pipeline_Stage__c = result.pipelineStage,
                Timing_Status__c = result.timingStatus,
                Pipeline_Bucket_Last_Calculated__c = System.now(),
                Pipeline_Bucket_Calculation_Notes__c = result.calculationNotes
            );
            updates.add(updatePo);
        }

        return updates;
    }

    private static String buildCalculationNotes(Purchase_Order__c po, TimingResult result) {
        Date timingDate = getTimingDate(po);
        String timingSource = po != null && po.Estimated_Start_Date__c != null
            ? 'Estimated_Start_Date__c'
            : 'Requested_Install_Date__c';

        List<String> parts = new List<String>{
            'Launch Purchase_Order__c pipeline calculation',
            'stage=' + result.pipelineStage,
            'timingStatus=' + result.timingStatus
        };

        if (timingDate == null) {
            parts.add('timingDate=missing');
        } else {
            parts.add('timingDate=' + String.valueOf(timingDate));
            parts.add('timingSource=' + timingSource);
            parts.add('daysUntilInstall=' + String.valueOf(result.daysUntilInstall));
        }

        return String.join(parts, '; ');
    }

    public static String mapStageToBoardColumn(String pipelineStage, String status) {
        // Compatibility for legacy board buckets still present on production PO rows.
        // These values are display-only fallbacks; the corrected launch model uses
        // Pipeline_Stage__c values such as Package Match Check, CSM Review, etc.
        if (pipelineStage == 'Validate') return 'csmReview';
        if (pipelineStage == 'Forecast') return 'takeoffRequested';
        if (pipelineStage == 'Scheduling') return 'workOrderCreated';
        if (pipelineStage == 'Clear') return 'clear';

        if (pipelineStage == STAGE_PO_RECEIVED) return 'received';
        if (pipelineStage == STAGE_PACKAGE_MATCH_CHECK) return 'packageCheck';
        if (pipelineStage == STAGE_CSM_REVIEW) return 'csmReview';
        if (pipelineStage == STAGE_TAKEOFF_REQUESTED) return 'takeoffRequested';
        if (pipelineStage == STAGE_TAKEOFF_SCHEDULED) return 'takeoffScheduled';
        if (pipelineStage == STAGE_TAKEOFF_IN_PROGRESS) return 'takeoffProgress';
        if (pipelineStage == STAGE_TAKEOFF_COMPLETE) return 'takeoffComplete';
        if (pipelineStage == STAGE_WORK_ORDER_CREATED) return 'workOrderCreated';
        if (pipelineStage == STAGE_CLEAR_TO_SCHEDULE) return 'clear';
        if (pipelineStage == STAGE_CLOSED_CONVERTED) return 'closed';
        if (pipelineStage == STAGE_CANCELLED_VOID) return 'cancelled';

        if (status == 'Closed') return 'closed';
        if (status == 'Cancelled') return 'cancelled';
        if (status == 'Pending CS Review' || status == 'Exception' || status == 'NFI') return 'csmReview';
        if (status == 'Package Match Check') return 'packageCheck';
        if (status == 'Ready for Takeoff') return 'takeoffRequested';
        if (status == 'Takeoff Scheduled') return 'takeoffScheduled';
        if (status == 'Takeoff In Progress') return 'takeoffProgress';
        if (status == 'Takeoff Complete') return 'takeoffComplete';
        if (status == 'Work Order Created') return 'workOrderCreated';
        if (status == 'Clear for Schedule') return 'clear';
        return 'received';
    }

    private static Boolean isPackageReadyForTakeoff(Purchase_Order__c po) {
        return po.Package_BMG_Status__c == 'Matched' || po.Package_BMG_Status__c == 'Not Required';
    }

    private static Boolean isPackageBlocked(Purchase_Order__c po) {
        return po.Package_BMG_Status__c == 'Mismatch Review'
            || po.Package_BMG_Status__c == 'Missing Package'
            || po.Status__c == 'NFI';
    }
}