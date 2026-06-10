/**
 * WorkOrderPageDTO
 *
 * Pure data-transfer object (DTO) for the Work Order page LWC.
 * No logic lives here — only @AuraEnabled properties.
 *
 * @group Work Order Page
 */
public with sharing class WorkOrderPageDTO {

    @AuraEnabled public HeaderDTO         header;
    @AuraEnabled public LifePathDTO       lifePath;
    @AuraEnabled public HighlightsDTO     highlights;
    @AuraEnabled public PropertyDTO       property;
    @AuraEnabled public PoDTO             po;
    @AuraEnabled public TakeoffDTO        takeoff;
    @AuraEnabled public QuoteDTO          quote;
    @AuraEnabled public PricingDTO        pricing;
    @AuraEnabled public List<LineItemDTO> lineItems;
    @AuraEnabled public List<TimeEntryDTO> timeEntries;
    @AuraEnabled public ScheduleDTO       schedule;
    @AuraEnabled public CloseoutDTO       closeout;
    @AuraEnabled public QiDTO             qi;
    @AuraEnabled public InvoiceDTO        invoice;
    @AuraEnabled public SubWorkOrderDTO   subWorkOrder;
    @AuraEnabled public List<ChildWODTO>  autoTriggered;
    @AuraEnabled public RelatedCountsDTO  relatedCounts;
    @AuraEnabled public List<WarningDTO>  warnings;
    @AuraEnabled public List<String>      errors;
    @AuraEnabled public Datetime          lastUpdated;

    // ─── Inner Classes ────────────────────────────────────────────────────────

    public class HeaderDTO {
        /** Work_Order__c.Id */
        @AuraEnabled public String  recordId;
        /** Work_Order__c.Name */
        @AuraEnabled public String  workOrderName;
        /** Work_Order__c.Work_Order_Type__c */
        @AuraEnabled public String  workOrderType;
        /** Work_Order__c.Status__c */
        @AuraEnabled public String  status;
        /** Work_Order__c.Pipeline_Stage__c */
        @AuraEnabled public String  pipelineStage;
        /** Work_Order__c.Sub_Status__c */
        @AuraEnabled public String  subStatus;
        /** Work_Order__c.Job_Health__c */
        @AuraEnabled public String  jobHealth;
        /** Work_Order__c.Division__c */
        @AuraEnabled public String  division;
        /** Work_Order__c.Revenue_Division__c */
        @AuraEnabled public String  revenueDivision;
        /** Work_Order__c.Billable_Type__c */
        @AuraEnabled public String  billableType;
        /** Derived pipeline-source label: "PO → Takeoff → Quote → WO" */
        @AuraEnabled public String  pipelineSource;
    }

    public class LifePathDTO {
        @AuraEnabled public String          currentStage;
        @AuraEnabled public String          nextStage;
        @AuraEnabled public Integer         currentOrder;
        @AuraEnabled public Boolean         isClosedBlocked;
        @AuraEnabled public Boolean         isPaid;
        @AuraEnabled public Boolean         isQiComplete;
        @AuraEnabled public Boolean         showClosedWarning;
        @AuraEnabled public List<WarningDTO> warnings;
    }

    public class HighlightsDTO {
        @AuraEnabled public String  accountName;
        @AuraEnabled public String  accountId;
        @AuraEnabled public String  communityName;
        @AuraEnabled public String  communityId;
        @AuraEnabled public String  fieldManagerName;
        @AuraEnabled public String  fieldManagerId;
        @AuraEnabled public String  crewName;
        @AuraEnabled public String  crewId;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Date    scheduledDate;
    }

    public class PropertyDTO {
        @AuraEnabled public String  accountName;
        @AuraEnabled public String  accountId;
        @AuraEnabled public String  divisionAccountName;
        @AuraEnabled public String  divisionAccountId;
        @AuraEnabled public String  communityName;
        @AuraEnabled public String  communityId;
        @AuraEnabled public String  lotName;
        @AuraEnabled public String  lotId;
        @AuraEnabled public String  streetAddress;
        @AuraEnabled public String  constructionManagerName;
        @AuraEnabled public String  constructionManagerId;
        @AuraEnabled public String  territory;
        @AuraEnabled public Boolean aquaCustomer;
        @AuraEnabled public Boolean lawnCareCustomer;
    }

    public class PoDTO {
        @AuraEnabled public String  builderPoId;
        @AuraEnabled public String  poNumber;
        @AuraEnabled public Decimal poAmount;
        @AuraEnabled public Date    poReleaseDate;
        @AuraEnabled public String  pipelineStage;
        @AuraEnabled public String  timingStatus;
    }

    public class TakeoffDTO {
        @AuraEnabled public String  takeoffId;
        @AuraEnabled public String  takeoffName;
        @AuraEnabled public String  status;
        @AuraEnabled public Date    approvedDate;
    }

    public class QuoteDTO {
        @AuraEnabled public String  quoteId;
        @AuraEnabled public String  quoteName;
        @AuraEnabled public String  quoteStatus;
        @AuraEnabled public Decimal quoteTotal;
        /** False until the work-order page is connected to the live Revenue quote source */
        @AuraEnabled public Boolean isSbqqAvailable;
    }

    public class PricingDTO {
        @AuraEnabled public String pricingSource;
        @AuraEnabled public String pricebookName;
        @AuraEnabled public String builderPricingBookId;
    }

    public class LineItemDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  productName;
        @AuraEnabled public String  category;
        @AuraEnabled public Decimal poQuantity;
        @AuraEnabled public Decimal measuredQuantity;
        @AuraEnabled public Decimal verifiedQuantity;
        @AuraEnabled public Decimal quotedQuantity;
        @AuraEnabled public String  unitOfMeasure;
        @AuraEnabled public Decimal goalMinutes;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal extendedPrice;
        @AuraEnabled public String  pricingSource;
        @AuraEnabled public Boolean materialVerified;
        @AuraEnabled public Boolean substitutionRequired;
        @AuraEnabled public String  substitutionNotes;
        @AuraEnabled public String  notes;
        @AuraEnabled public String  lineStatus;
    }

    public class TimeEntryDTO {
        @AuraEnabled public String   id;
        @AuraEnabled public String   employeeName;
        @AuraEnabled public Datetime clockIn;
        @AuraEnabled public Datetime arriveSite;
        @AuraEnabled public Datetime departSite;
        @AuraEnabled public Datetime clockOut;
        @AuraEnabled public Decimal  hours;
    }

    public class ScheduleDTO {
        @AuraEnabled public Date     scheduledDate;
        @AuraEnabled public Datetime scheduledStartTime;
        @AuraEnabled public Datetime siteReadinessDue;
        @AuraEnabled public String   fieldManagerName;
        @AuraEnabled public String   fieldManagerId;
        @AuraEnabled public String   foremanName;
        @AuraEnabled public String   foremanId;
        @AuraEnabled public String   crewName;
        @AuraEnabled public String   crewId;
        @AuraEnabled public Integer  crewSize;
        @AuraEnabled public String   truckName;
        @AuraEnabled public Integer  stopSequence;
        @AuraEnabled public Integer  estimatedDriveMinutes;
        @AuraEnabled public String   territory;
    }

    public class CloseoutDTO {
        @AuraEnabled public Boolean crewCompleted;
        @AuraEnabled public Boolean fslCrewComplete;
        @AuraEnabled public Integer photoCount;
        @AuraEnabled public String  closeoutNotes;
        @AuraEnabled public Boolean approvalProcessCompleted;
    }

    public class QiDTO {
        @AuraEnabled public Boolean qiComplete;
        @AuraEnabled public Boolean qiScheduled;
        @AuraEnabled public Date    qiCompletedDate;
    }

    public class InvoiceDTO {
        @AuraEnabled public Boolean invoiceGenerated;
        @AuraEnabled public String  invoiceNumber;
        @AuraEnabled public Decimal invoiceTotal;
    }

    public class SubWorkOrderDTO {
        // Parent relationship
        @AuraEnabled public String  parentWorkOrderId;
        @AuraEnabled public String  parentWorkOrderName;
        @AuraEnabled public Date    parentScheduledDate;

        // Finished Job fields
        @AuraEnabled public String  fjReasonCode;
        @AuraEnabled public String  fjReasonDetail;
        @AuraEnabled public String  originalFmName;
        @AuraEnabled public String  originalForemanName;
        @AuraEnabled public Boolean isFinishedJob;

        // Warranty fields
        @AuraEnabled public Boolean  isWarranty;
        @AuraEnabled public String   customerReport;
        @AuraEnabled public String   warrantyDetermination;
        @AuraEnabled public Date     warrantyStartDate;
        @AuraEnabled public Date     warrantyEndDate;
        @AuraEnabled public String   warrantyCoverageStatus;
        @AuraEnabled public String   warrantyCoverageType;
        @AuraEnabled public String   warrantyVoidedReason;

        // Completed-Correction (CC) / EPO fields
        @AuraEnabled public String   source;
        @AuraEnabled public Datetime requestReceivedDate;
        @AuraEnabled public String   epoStatus;
        @AuraEnabled public Date     epoSentDate;
        @AuraEnabled public Date     epoReceivedDate;
        @AuraEnabled public Integer  epoDaysOutstanding;
        @AuraEnabled public String   epoSlaTier;
        @AuraEnabled public Boolean  epoSlaBreach;
    }

    public class ChildWODTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String workOrderType;
        @AuraEnabled public String triggerSource;
        @AuraEnabled public String status;
        @AuraEnabled public Date   scheduledDate;
    }

    public class RelatedCountsDTO {
        @AuraEnabled public Integer photoCount;
        @AuraEnabled public Integer lineItemCount;
        @AuraEnabled public Integer timeEntryCount;
        @AuraEnabled public Integer finishedJobCount;
        @AuraEnabled public Integer fileCount;
    }

    /**
     * @param key      Machine-readable identifier for the warning.
     * @param message  Human-readable text shown in the UI.
     * @param severity 'warning' | 'error' | 'info'
     */
    public class WarningDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String message;
        @AuraEnabled public String severity;
    }
}