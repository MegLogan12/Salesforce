/**
 * LovingRevenueCloudQuoteService
 *
 * Placeholder service for Revenue / quote integration.
 * Revenue features are enabled in the org, but this LOVING work-order page
 * has not yet been wired to the live Revenue/Data Cloud quote source.
 * All callers currently receive a QuoteDTO with isSbqqAvailable = false so
 * the UI can render a graceful "not connected" state rather than an error.
 *
 * Replace this class body with the live Revenue quote query path used by this
 * org once the work-order quote source is finalized and connected.
 *
 * @group Work Order Page
 */
public with sharing class LovingRevenueCloudQuoteService {

    /**
     * Returns a placeholder QuoteDTO indicating the quote source is not yet connected.
     *
     * @param workOrderId  Id of the Work_Order__c record (reserved for future use)
     * @return             QuoteDTO with isSbqqAvailable = false
     */
    public static WorkOrderPageDTO.QuoteDTO buildQuote(Id workOrderId) {
        WorkOrderPageDTO.QuoteDTO dto = new WorkOrderPageDTO.QuoteDTO();
        dto.isSbqqAvailable = false;
        dto.quoteId         = null;
        dto.quoteName       = 'Revenue quote source not connected';
        dto.quoteStatus     = null;
        dto.quoteTotal      = null;
        return dto;
    }
}