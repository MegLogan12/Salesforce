/**
 * SiteReadinessService
 * FM 48-hour pre-install site readiness check.
 *
 * When a Production Install WO is scheduled (Status__c = Scheduled),
 * Site_Readiness_Date__c is set to Scheduled_Date__c minus 2 days.
 * FM must confirm site is Ready before install proceeds.
 *
 * Results:
 *   Ready    — install proceeds on schedule
 *   Not Ready — WO placed On Hold; FM must resolve and re-confirm or waive
 *   Waived   — FM/COO overrides with documented reason; install proceeds
 *
 * Automation fires from WorkOrderHandler.onScheduled() for Production Install WOs.
 */
public with sharing class SiteReadinessService {

    // ─────────────────────────────────────────────
    // TEST INJECTION
    // WorkOrder INSERT is blocked in this org's test context.
    // These statics allow test methods to exercise service logic without DML.
    //   injectedWorkOrder       — replaces SOQL for a single-record lookup
    //   skipDmlForTest          — bypasses update DML; captures to capturedUpdates
    //   capturedUpdates         — records what would have been updated (assertions)
    //   injectedOverdueWorkOrders — overrides checkOverdue() SOQL result
    // ─────────────────────────────────────────────
    @TestVisible static WorkOrder        injectedWorkOrder           = null;
    @TestVisible static Boolean          skipDmlForTest              = false;
    @TestVisible static List<WorkOrder>  capturedUpdates             = null;
    @TestVisible static List<WorkOrder>  injectedOverdueWorkOrders   = null;

    // ─────────────────────────────────────────────
    // TRIGGER — called from WorkOrderHandler when WO enters Scheduled status
    // ─────────────────────────────────────────────
    public static void onScheduled(List<WorkOrder> workOrders, Map<Id, WorkOrder> oldMap) {
        List<WorkOrder> toUpdate = new List<WorkOrder>();

        for (WorkOrder wo : workOrders) {
            if (wo.Work_Order_Type__c != 'Production Install') continue;
            if (wo.Scheduled_Date__c == null) continue;

            WorkOrder old = (oldMap != null) ? oldMap.get(wo.Id) : null;
            Boolean justScheduled = (old == null || old.Status__c != 'Scheduled')
                && wo.Status__c == 'Scheduled';

            if (justScheduled && wo.Site_Readiness_Status__c == 'Not Started') {
                toUpdate.add(new WorkOrder(
                    Id                        = wo.Id,
                    Site_Readiness_Date__c    = wo.Scheduled_Date__c.addDays(-2),
                    Site_Readiness_Status__c  = 'Scheduled'
                ));
            }
        }

        if (!toUpdate.isEmpty()) {
            if (skipDmlForTest) {
                capturedUpdates = toUpdate;
            } else {
                update toUpdate;
            }
        }
    }

    // ─────────────────────────────────────────────
    // FM confirms site readiness
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void confirmReady(Id workOrderId) {
        WorkOrder wo = injectedWorkOrder != null ? injectedWorkOrder :
            [SELECT Id, Status__c, Site_Readiness_Status__c
             FROM WorkOrder WHERE Id = :workOrderId];

        if (wo.Site_Readiness_Status__c == 'Complete') {
            throw new SiteReadinessException('Site readiness check already completed for this Work Order.');
        }

        if (!skipDmlForTest) {
            update new WorkOrder(
                Id                                  = workOrderId,
                Site_Readiness_Status__c            = 'Complete',
                Site_Readiness_Result__c            = 'Ready',
                Site_Readiness_Completed_Date__c    = Date.today(),
                Site_Readiness_Completed_By__c      = UserInfo.getUserId()
            );
        }
    }

    // ─────────────────────────────────────────────
    // FM flags site as Not Ready — holds the WO
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void flagNotReady(Id workOrderId, String notes) {
        if (String.isBlank(notes)) {
            throw new SiteReadinessException('Notes are required when flagging a site as Not Ready.');
        }

        if (!skipDmlForTest) {
            update new WorkOrder(
                Id                                  = workOrderId,
                Site_Readiness_Status__c            = 'Not Ready',
                Site_Readiness_Result__c            = 'Not Ready',
                Site_Readiness_Notes__c             = notes,
                Site_Readiness_Completed_Date__c    = Date.today(),
                Site_Readiness_Completed_By__c      = UserInfo.getUserId(),
                Status__c                           = 'On Hold'
            );
        }
    }

    // ─────────────────────────────────────────────
    // FM/COO waives site readiness requirement — install proceeds despite Not Ready
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void waiveReadiness(Id workOrderId, String waiverReason) {
        if (String.isBlank(waiverReason)) {
            throw new SiteReadinessException('Waiver reason is required when overriding site readiness.');
        }

        WorkOrder wo = injectedWorkOrder != null ? injectedWorkOrder :
            [SELECT Id, Status__c FROM WorkOrder WHERE Id = :workOrderId];

        if (!skipDmlForTest) {
            update new WorkOrder(
                Id                                  = workOrderId,
                Site_Readiness_Status__c            = 'Waived',
                Site_Readiness_Result__c            = 'Waived',
                Site_Readiness_Waived__c            = true,
                Site_Readiness_Waiver_Reason__c     = waiverReason,
                Site_Readiness_Completed_Date__c    = Date.today(),
                Site_Readiness_Completed_By__c      = UserInfo.getUserId(),
                Status__c                           = wo.Status__c == 'On Hold' ? 'Scheduled' : wo.Status__c
            );
        }
    }

    // ─────────────────────────────────────────────
    // Scheduled check — alert on WOs past Site_Readiness_Date with no result
    // ─────────────────────────────────────────────
    public static void checkOverdue() {
        List<WorkOrder> overdue = injectedOverdueWorkOrders != null ? injectedOverdueWorkOrders :
            [SELECT Id, WorkOrderNumber, Field_Manager__c, Site_Readiness_Date__c
             FROM WorkOrder
             WHERE Status__c = 'Scheduled'
             AND Work_Order_Type__c = 'Production Install'
             AND Site_Readiness_Status__c = 'Scheduled'
             AND Site_Readiness_Date__c <= :Date.today()
             AND Site_Readiness_Result__c = null];

        for (WorkOrder wo : overdue) {
            EscalationService.alertSiteReadinessOverdue(wo.Id, wo.Field_Manager__c);
        }
    }

    public class SiteReadinessException extends Exception {}
}