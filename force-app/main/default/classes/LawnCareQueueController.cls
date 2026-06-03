/**
 * LawnCareQueueController
 * Returns WorkOrders where Job_Type__c = 'Lawn Care' (or RecordType = 'Lawn Care')
 * that are scheduled for the current week and not yet Completed or Cancelled.
 *
 * Screen 22 — Lawn Care Queue
 */
public with sharing class LawnCareQueueController {

    // ─── Inner classes ───────────────────────────────────────────────────────

    public class LcRow {
        @AuraEnabled public Id     woId;
        @AuraEnabled public String woNumber;
        @AuraEnabled public String communityName;
        @AuraEnabled public String serviceType;    // Work_Order_Type__c or Subject
        @AuraEnabled public String crewName;
        @AuraEnabled public Date   scheduledDate;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean isUnassigned;  // Crew__c == null
    }

    public class LawnCareView {
        @AuraEnabled public Integer     totalDueThisWeek;
        @AuraEnabled public Integer     unassigned;
        @AuraEnabled public List<LcRow> rows;
    }

    // ─── Public read method ──────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static LawnCareView getQueue() {
        if (!Schema.sObjectType.WorkOrder.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Work Order records.');
        }

        Date weekStart = Date.today().toStartOfWeek();
        Date weekEnd   = weekStart.addDays(6);

        List<WorkOrder> wos = [
            SELECT Id,
                   WorkOrderNumber,
                   Subject,
                   Community__c,
                   Community__r.Name,
                   Work_Order_Type__c,
                   Job_Type__c,
                   Crew__c,
                   Crew__r.Name,
                   Scheduled_Date__c,
                   Status,
                   RecordType.Name
            FROM WorkOrder
            WHERE (Job_Type__c = 'Lawn Care' OR RecordType.Name = 'Lawn Care')
              AND Scheduled_Date__c >= :weekStart
              AND Scheduled_Date__c <= :weekEnd
              AND Status NOT IN ('Completed', 'Cancelled')
            ORDER BY Scheduled_Date__c ASC
            LIMIT 200
        ];

        return buildView(wos);
    }

    // ─── Testable helper ─────────────────────────────────────────────────────

    @TestVisible
    private static LawnCareView buildView(List<WorkOrder> wos) {
        LawnCareView view       = new LawnCareView();
        view.rows               = new List<LcRow>();
        view.totalDueThisWeek   = 0;
        view.unassigned         = 0;

        for (WorkOrder wo : wos) {
            LcRow row          = new LcRow();
            row.woId           = wo.Id;
            row.woNumber       = wo.WorkOrderNumber;
            row.status         = wo.Status;

            // Community name
            row.communityName  = (wo.Community__r != null && String.isNotBlank(wo.Community__r.Name))
                                 ? wo.Community__r.Name
                                 : null;

            // Service type: prefer Work_Order_Type__c, fall back to Subject
            row.serviceType    = String.isNotBlank(wo.Work_Order_Type__c)
                                 ? wo.Work_Order_Type__c
                                 : wo.Subject;

            // Crew
            Boolean noCrewId   = (wo.Crew__c == null);
            row.isUnassigned   = noCrewId;
            row.crewName       = (!noCrewId && wo.Crew__r != null)
                                 ? wo.Crew__r.Name
                                 : null;

            row.scheduledDate  = wo.Scheduled_Date__c;

            view.totalDueThisWeek++;
            if (noCrewId) {
                view.unassigned++;
            }
            view.rows.add(row);
        }

        return view;
    }
}
