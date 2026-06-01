/**
 * SubWorkOrderPageDTO
 *
 * Shared DTO shape for Finished Job, Warranty, and Customer Care
 * sub-work-order record pages. Returned by LovingSubWorkOrderController.
 *
 * @group Work Order Page
 */
public class SubWorkOrderPageDTO {

    // ─────────────────────────────────────────────────────────────────────────
    // Top-level page DTO
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled public HeaderDTO              header;
    @AuraEnabled public List<ShortPathStepDTO> shortPath;
    @AuraEnabled public ParentSummaryDTO       parentSummary;
    @AuraEnabled public SourceSummaryDTO       sourceSummary;
    @AuraEnabled public List<ScopeItemDTO>     scopeItems;
    @AuraEnabled public ScheduleSummaryDTO     scheduleSummary;
    @AuraEnabled public CloseoutSummaryDTO     closeoutSummary;
    @AuraEnabled public List<WarningDTO>       warnings;
    @AuraEnabled public List<ActionDTO>        actions;
    @AuraEnabled public List<DocumentDTO>      documents;
    @AuraEnabled public List<ActivityDTO>      activity;

    // ─────────────────────────────────────────────────────────────────────────
    // Header
    // ─────────────────────────────────────────────────────────────────────────

    public class HeaderDTO {
        @AuraEnabled public String  workOrderId;
        @AuraEnabled public String  workOrderName;       // WO Number
        @AuraEnabled public String  workOrderType;       // Finished Job / Warranty / Customer Care
        @AuraEnabled public String  status;
        @AuraEnabled public String  currentPathStep;     // current step label
        @AuraEnabled public Integer currentPathIndex;    // 0-based step index
        @AuraEnabled public String  parentWorkOrderId;
        @AuraEnabled public String  parentWorkOrderName;
        @AuraEnabled public String  billableType;
        @AuraEnabled public String  iconBgColor;         // per-type color
        @AuraEnabled public String  typeLabel;           // FJ / Warranty / CC
        @AuraEnabled public String  breadcrumb;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Short path steps (6 per type)
    // ─────────────────────────────────────────────────────────────────────────

    public class ShortPathStepDTO {
        @AuraEnabled public Integer stepIndex;    // 1-based
        @AuraEnabled public String  label;
        @AuraEnabled public String  description;
        @AuraEnabled public String  stepClass;   // 'step done' | 'step cur' | 'step blocked' | 'step'
        @AuraEnabled public Boolean isDone;
        @AuraEnabled public Boolean isCurrent;
        @AuraEnabled public Boolean isBlocked;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Parent WO summary
    // ─────────────────────────────────────────────────────────────────────────

    public class ParentSummaryDTO {
        @AuraEnabled public String parentWorkOrderId;
        @AuraEnabled public String parentWorkOrderName;
        @AuraEnabled public String parentStatus;
        @AuraEnabled public String parentCommunityName;
        @AuraEnabled public String parentLotName;
        @AuraEnabled public Date   parentScheduledDate;
        @AuraEnabled public String parentFmName;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Source summary (FJ: NFI/incomplete reason; Warranty: Case; CC: Case)
    // ─────────────────────────────────────────────────────────────────────────

    public class SourceSummaryDTO {
        // FJ
        @AuraEnabled public String fjReasonCode;
        @AuraEnabled public String fjReasonDetail;
        @AuraEnabled public String fjCreatedByFmName;
        @AuraEnabled public String fjOriginalForemanName;
        // Warranty
        @AuraEnabled public String warrantyCoverageType;
        @AuraEnabled public String warrantyCoverageStatus;
        @AuraEnabled public Date   warrantyStartDate;
        @AuraEnabled public Date   warrantyEndDate;
        @AuraEnabled public String warrantyVoidedReason;
        // Customer Care
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String caseId;
        @AuraEnabled public String caseCustomerCareType;
        @AuraEnabled public String casePriorityTier;
        @AuraEnabled public String caseResolutionStatus;
        @AuraEnabled public String caseCmName;
        @AuraEnabled public String caseRelatedParentWoId;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Scope items
    // ─────────────────────────────────────────────────────────────────────────

    public class ScopeItemDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  itemName;
        @AuraEnabled public String  category;
        @AuraEnabled public Decimal originalQty;
        @AuraEnabled public Decimal remainingQty;
        @AuraEnabled public String  reason;
        @AuraEnabled public String  charge;         // 'No Charge' / 'Billable'
        @AuraEnabled public String  source;         // 'Takeoff Line' / 'Quote Line' / 'NFI' / etc.
        @AuraEnabled public String  coverageStatus; // Warranty: In / Out / Voided
        @AuraEnabled public Boolean isBillable;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Schedule summary
    // ─────────────────────────────────────────────────────────────────────────

    public class ScheduleSummaryDTO {
        @AuraEnabled public Date   scheduledDate;
        @AuraEnabled public String fmName;
        @AuraEnabled public String foremanName;
        @AuraEnabled public String crewName;
        @AuraEnabled public String stopNumber;
        @AuraEnabled public String scheduledStartTime;
        @AuraEnabled public Boolean isLocked;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Closeout summary
    // ─────────────────────────────────────────────────────────────────────────

    public class CloseoutSummaryDTO {
        @AuraEnabled public Boolean deviceInstalled;
        @AuraEnabled public Boolean timerTested;
        @AuraEnabled public Boolean coverageVerified;
        @AuraEnabled public Boolean photosUploaded;
        @AuraEnabled public Boolean closeoutNotesPresent;
        @AuraEnabled public Boolean inventoryRecorded;
        @AuraEnabled public Boolean fmReviewComplete;
        @AuraEnabled public String  closeoutNotes;
        @AuraEnabled public Integer photoCount;
        @AuraEnabled public Integer photoRequired;    // spec minimum
        @AuraEnabled public Boolean closeoutEligible; // all required gates met
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Warnings
    // ─────────────────────────────────────────────────────────────────────────

    public class WarningDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String message;
        @AuraEnabled public String severity;  // 'error' | 'warning' | 'info'
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Actions (buttons)
    // ─────────────────────────────────────────────────────────────────────────

    public class ActionDTO {
        @AuraEnabled public String  label;
        @AuraEnabled public String  actionType;   // apex | navigate | flow
        @AuraEnabled public String  apexMethod;
        @AuraEnabled public String  buttonClass;  // 'sf-btn primary' etc.
        @AuraEnabled public Boolean disabled;
        @AuraEnabled public String  disabledReason;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Documents / Files
    // ─────────────────────────────────────────────────────────────────────────

    public class DocumentDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  title;
        @AuraEnabled public String  fileType;
        @AuraEnabled public String  uploadedByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String  downloadUrl;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Activity feed
    // ─────────────────────────────────────────────────────────────────────────

    public class ActivityDTO {
        @AuraEnabled public String   id;
        @AuraEnabled public String   actorName;
        @AuraEnabled public String   actorInitials;
        @AuraEnabled public String   actorColor;
        @AuraEnabled public String   body;
        @AuraEnabled public String   timeAgo;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String   activityType;  // 'note' | 'task' | 'chatter' | 'system'
    }
}