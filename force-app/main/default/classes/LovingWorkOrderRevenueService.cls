/**
 * LovingWorkOrderRevenueService
 *
 * Computes the Revenue KPI strip shown on the Work Orders list view.
 * Called by LovingWorkOrderListController with the filtered set of WO Ids.
 *
 * KPI definitions (from CLAUDE.md):
 *   woCount          — count of Work_Order__c records in filtered set
 *   projectedRevenue — SUM of Builder_PO__c.PO_Amount__c per WO;
 *                      No Charge WOs = $0
 *   invoiced         — SUM of Invoice__c.Total_Revenue__c where Status != 'Pending Send'
 *   paid             — SUM of Invoice__c.Amount_Paid__c where Status = 'Paid'
 *   unbilled         — projectedRevenue − invoiced
 *   outstanding      — invoiced − paid
 *   filterLabel      — human-readable description of current filter state
 *
 * @group Work Order Page
 */
public with sharing class LovingWorkOrderRevenueService {

    public class RevenueSummaryDTO {
        @AuraEnabled public Integer woCount;
        @AuraEnabled public Decimal projectedRevenue;
        @AuraEnabled public Decimal invoiced;
        @AuraEnabled public Decimal paid;
        @AuraEnabled public Decimal unbilled;
        @AuraEnabled public Decimal outstanding;
        @AuraEnabled public String  filterLabel;
    }

    /**
     * Returns the Revenue KPI strip DTO for the given Work Order Id set.
     *
     * @param workOrderIds  List of Work_Order__c Ids matching current filter.
     *                      May be empty; never null.
     * @param filterLabel   Human-readable description of the active filter
     *                      (e.g. "All Types · Jimbo · Scheduled").
     * @return              RevenueSummaryDTO with all six KPI values.
     */
    @AuraEnabled(cacheable=true)
    public static RevenueSummaryDTO getRevenueSummary(List<Id> workOrderIds, String filterLabel) {
        RevenueSummaryDTO result = new RevenueSummaryDTO();
        result.woCount          = workOrderIds != null ? workOrderIds.size() : 0;
        result.projectedRevenue = 0;
        result.invoiced         = 0;
        result.paid             = 0;
        result.filterLabel      = filterLabel != null ? filterLabel : 'All Work Orders';

        if (workOrderIds == null || workOrderIds.isEmpty()) {
            result.unbilled    = 0;
            result.outstanding = 0;
            return result;
        }

        // ── Projected Revenue ──────────────────────────────────────────────────
        // Sum Builder_PO__c.PO_Amount__c via the WO → Builder_PO__c lookup.
        // No Charge / Internal Fix WOs contribute $0.
        try {
            for (AggregateResult ar : [
                SELECT SUM(Builder_PO__r.PO_Amount__c) total
                FROM Work_Order__c
                WHERE Id IN :workOrderIds
                  AND Billable_Type__c != 'No Charge'
                  AND Billable_Type__c != 'Internal Fix'
                  AND Builder_PO__c != null
            ]) {
                result.projectedRevenue = (Decimal)(ar.get('total') != null ? ar.get('total') : 0);
            }
        } catch (Exception e) {
            // Builder_PO__c may not yet be linked on all WOs — default 0
        }

        // ── Invoiced ──────────────────────────────────────────────────────────
        // Invoice is considered "invoiced" when it has been sent (Status != 'Pending Send').
        try {
            for (AggregateResult ar : [
                SELECT SUM(Total_Revenue__c) total
                FROM Invoice__c
                WHERE Work_Order__c IN :workOrderIds
                  AND Status__c != 'Pending Send'
            ]) {
                result.invoiced = (Decimal)(ar.get('total') != null ? ar.get('total') : 0);
            }
        } catch (Exception e) {
            result.invoiced = 0;
        }

        // ── Paid ──────────────────────────────────────────────────────────────
        try {
            for (AggregateResult ar : [
                SELECT SUM(Amount_Paid__c) total
                FROM Invoice__c
                WHERE Work_Order__c IN :workOrderIds
                  AND Status__c = 'Paid'
            ]) {
                result.paid = (Decimal)(ar.get('total') != null ? ar.get('total') : 0);
            }
        } catch (Exception e) {
            result.paid = 0;
        }

        // ── Derived ───────────────────────────────────────────────────────────
        result.unbilled    = result.projectedRevenue - result.invoiced;
        result.outstanding = result.invoiced - result.paid;

        return result;
    }
}