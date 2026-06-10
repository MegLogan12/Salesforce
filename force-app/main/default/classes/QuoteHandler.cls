/**
 * QuoteHandler
 *
 * Trigger handler for Quote__c.
 *
 * Before rules:
 *   - Status transitions: Draft → Submitted → Approved or Rejected
 *   - Cannot move from Approved back to Submitted or Draft
 *   - Auto-stamps Approved_Date__c on transition to Approved
 *   - Auto-stamps Sent_Date__c on transition to Sent
 *
 * After rules:
 *   - On Approved (Customer Care RT): create Invoice + Invoice_Line_Items from Billable lines
 *   - On Approved (Production Install RT): update linked Work_Order__c status to Scheduled
 *   - On Rejected: set Work_Order__c sub-status to NFI
 */
public with sharing class QuoteHandler {

    public static void handleBefore(List<Quote__c> newList, Map<Id, Quote__c> oldMap) {
        QuoteService.beforeUpsert(newList, oldMap);
    }

    public static void handleAfter(List<Quote__c> newList, Map<Id, Quote__c> oldMap) {
        List<Quote__c> justApproved = new List<Quote__c>();
        List<Quote__c> justRejected = new List<Quote__c>();
        List<Quote__c> justSent     = new List<Quote__c>();

        for (Quote__c q : newList) {
            Quote__c old = (oldMap != null) ? oldMap.get(q.Id) : null;
            String oldStatus = (old != null) ? old.Status__c : null;

            if (q.Status__c == 'Approved'  && oldStatus != 'Approved')  justApproved.add(q);
            if (q.Status__c == 'Rejected'  && oldStatus != 'Rejected')  justRejected.add(q);
            if (q.Status__c == 'Sent'      && oldStatus != 'Sent')      justSent.add(q);
        }

        if (!justApproved.isEmpty()) QuoteService.onApproved(justApproved);
        if (!justRejected.isEmpty()) QuoteService.onRejected(justRejected);
        if (!justSent.isEmpty())     QuoteService.onSent(justSent);
    }
}