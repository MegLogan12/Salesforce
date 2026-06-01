/**
 * InvoiceHandler
 *
 * Trigger handler for Invoice__c. Delegates after-save logic to the
 * appropriate service layer.
 *
 * Note: No Invoice__c trigger currently calls this class in production.
 * The class exists to satisfy compile references in HomeBuilderAutoCloseServiceTest.
 */
public with sharing class InvoiceHandler {

    /**
     * Called from the after-insert/after-update trigger context (or directly
     * from tests). Routes newly-paid invoices to the auto-close service.
     *
     * @param newList  Trigger.new (or a test list)
     * @param oldMap   Trigger.oldMap (null on insert or when called from test)
     */
    public static void handleAfter(List<Invoice__c> newList, Map<Id, Invoice__c> oldMap) {
        List<Invoice__c> paidInvoices = new List<Invoice__c>();
        for (Invoice__c inv : newList) {
            Boolean wasPaid = oldMap != null && oldMap.containsKey(inv.Id)
                ? 'Paid'.equals(oldMap.get(inv.Id).Status__c)
                : false;
            if ('Paid'.equals(inv.Status__c) && !wasPaid) {
                paidInvoices.add(inv);
            }
        }
        if (!paidInvoices.isEmpty()) {
            HomeBuilderAutoCloseService.onInvoicePaid(paidInvoices);
        }
    }
}
