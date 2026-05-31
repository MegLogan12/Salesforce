/**
 * LovingForemanMobileController
 *
 * Apex controller for the lovingForemanMobile LWC.
 * Returns today's and upcoming WorkOrders assigned to the current user
 * as Foreman. Used as the data layer for the Foreman Mobile app home page.
 *
 * Design constraints:
 *  - Only reads WorkOrders where Foreman__c = current user
 *  - Returns lightweight DTOs — no raw SObject exposure
 *  - All methods @AuraEnabled(cacheable=true) where safe; cacheable=false
 *    on methods that must reflect live status
 */
public with sharing class LovingForemanMobileController {

    // ─────────────────────────────────────────────
    // Test injection statics (bypasses SOQL in test context)
    // WorkOrder INSERT is blocked in this org — use these to inject mock data.
    //   injectedTodayWorkOrders   — overrides getTodayWorkOrders() SOQL
    //   injectedUpcomingWorkOrders — overrides getUpcomingWorkOrders() SOQL
    // ─────────────────────────────────────────────
    @TestVisible static List<WorkOrder> injectedTodayWorkOrders   = null;
    @TestVisible static List<WorkOrder> injectedUpcomingWorkOrders = null;

    // ─────────────────────────────────────────────
    // DTOs
    // ─────────────────────────────────────────────

    public class WoSummaryDTO {
        @AuraEnabled public Integer totalToday;
        @AuraEnabled public Integer inProgress;
        @AuraEnabled public Integer pendingCloseout;
        @AuraEnabled public Integer scheduled;
        @AuraEnabled public Integer complete;
    }

    public class WoCardDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  woType;
        @AuraEnabled public String  status;
        @AuraEnabled public String  statusCategory;
        @AuraEnabled public String  lotNumber;
        @AuraEnabled public String  communityName;
        @AuraEnabled public String  scheduledDateLabel;
        @AuraEnabled public String  streetAddress;
        @AuraEnabled public String  city;
        @AuraEnabled public String  state;
        @AuraEnabled public String  priority;
        @AuraEnabled public Boolean isInProgress;
        @AuraEnabled public Boolean isPendingCloseout;
        @AuraEnabled public Boolean isComplete;
        @AuraEnabled public String  statusChipClass;
    }

    // ─────────────────────────────────────────────
    // Public methods
    // ─────────────────────────────────────────────

    /**
     * Returns KPI summary of today's WorkOrders for the current foreman.
     */
    @AuraEnabled(cacheable=false)
    public static WoSummaryDTO getTodaySummary() {
        if (injectedTodayWorkOrders != null) {
            return countStatuses(injectedTodayWorkOrders);
        }
        Id userId = UserInfo.getUserId();
        Date today = Date.today();

        List<WorkOrder> wos = [
            SELECT Status, StatusCategory
            FROM   WorkOrder
            WHERE  Foreman__c = :userId
            AND    Scheduled_Date__c = :today
            LIMIT  200
        ];

        return countStatuses(wos);
    }

    /**
     * Returns today's WorkOrders for the current foreman as WoCardDTOs.
     */
    @AuraEnabled(cacheable=false)
    public static List<WoCardDTO> getTodayWorkOrders() {
        if (injectedTodayWorkOrders != null) {
            return buildCards(injectedTodayWorkOrders);
        }
        Id userId = UserInfo.getUserId();
        Date today = Date.today();

        List<WorkOrder> wos = [
            SELECT Id, WorkOrderNumber, Subject, Status, StatusCategory,
                   Work_Order_Type__c, Lot_Number__c, Priority,
                   Scheduled_Date__c,
                   Community__r.Name,
                   Street, City, State,
                   Drive_Started_At__c
            FROM   WorkOrder
            WHERE  Foreman__c = :userId
            AND    Scheduled_Date__c = :today
            ORDER BY Priority DESC, WorkOrderNumber ASC
            LIMIT  50
        ];

        return buildCards(wos);
    }

    /**
     * Returns this week's upcoming WorkOrders for the current foreman
     * (tomorrow through end of week, excluding today).
     */
    @AuraEnabled(cacheable=false)
    public static List<WoCardDTO> getUpcomingWorkOrders() {
        if (injectedUpcomingWorkOrders != null) {
            return buildCards(injectedUpcomingWorkOrders);
        }
        Id userId = UserInfo.getUserId();
        Date tomorrow = Date.today().addDays(1);
        Date weekEnd  = Date.today().addDays(6);

        List<WorkOrder> wos = [
            SELECT Id, WorkOrderNumber, Subject, Status, StatusCategory,
                   Work_Order_Type__c, Lot_Number__c, Priority,
                   Scheduled_Date__c,
                   Community__r.Name,
                   Street, City, State
            FROM   WorkOrder
            WHERE  Foreman__c = :userId
            AND    Scheduled_Date__c >= :tomorrow
            AND    Scheduled_Date__c <= :weekEnd
            ORDER BY Scheduled_Date__c ASC, Priority DESC
            LIMIT  25
        ];

        return buildCards(wos);
    }

    // ─────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────

    private static WoSummaryDTO countStatuses(List<WorkOrder> wos) {
        WoSummaryDTO dto = new WoSummaryDTO();
        dto.totalToday       = wos.size();
        dto.inProgress       = 0;
        dto.pendingCloseout  = 0;
        dto.scheduled        = 0;
        dto.complete         = 0;
        for (WorkOrder wo : wos) {
            String s = wo.Status;
            if (s == 'In Progress')           dto.inProgress++;
            else if (s == 'Pending Closeout') dto.pendingCloseout++;
            else if (s == 'Completed')        dto.complete++;
            else                              dto.scheduled++;
        }
        return dto;
    }

    private static List<WoCardDTO> buildCards(List<WorkOrder> wos) {
        List<WoCardDTO> cards = new List<WoCardDTO>();
        for (WorkOrder wo : wos) {
            WoCardDTO c = new WoCardDTO();
            c.id              = wo.Id;
            c.name            = wo.WorkOrderNumber;
            c.woType          = wo.Work_Order_Type__c  != null ? wo.Work_Order_Type__c  : '—';
            c.status          = wo.Status             != null ? wo.Status             : '—';
            c.statusCategory  = wo.StatusCategory     != null ? wo.StatusCategory     : '';
            c.lotNumber       = wo.Lot_Number__c      != null ? wo.Lot_Number__c      : '—';
            c.communityName   = (wo.Community__r != null && wo.Community__r.Name != null)
                                    ? wo.Community__r.Name : '—';
            c.priority        = wo.Priority           != null ? wo.Priority           : 'Normal';
            c.streetAddress   = wo.Street             != null ? wo.Street             : '';
            c.city            = wo.City               != null ? wo.City               : '';
            c.state           = wo.State              != null ? wo.State              : '';
            c.scheduledDateLabel = wo.Scheduled_Date__c != null
                                    ? wo.Scheduled_Date__c.format() : '—';

            c.isInProgress       = (wo.Status == 'In Progress');
            c.isPendingCloseout  = (wo.Status == 'Pending Closeout');
            c.isComplete         = (wo.Status == 'Completed');

            c.statusChipClass = statusChip(wo.Status);
            cards.add(c);
        }
        return cards;
    }

    private static String statusChip(String status) {
        if (status == null)                return 'chip cgr';
        if (status == 'In Progress')       return 'chip caqua';
        if (status == 'Pending Closeout')  return 'chip ca';
        if (status == 'Completed')         return 'chip cg';
        if (status == 'On Hold')           return 'chip cr';
        if (status == 'New')               return 'chip cb2';
        return 'chip cgr';
    }
}