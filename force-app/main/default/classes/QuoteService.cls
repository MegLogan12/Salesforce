/**
 * QuoteService
 *
 * Business logic for Quote__c lifecycle.
 *
 * Two quote types:
 *
 *   Customer Care (CC) — originated from a CC Work Order site visit
 *     On Approved → build Invoice + Invoice_Line_Items from Billable determination lines
 *     On Rejected → set Work_Order NFI count, update Quote Work Order sub-status
 *
 *   Production Install — originated from Builder PO / Takeoff flow
 *     On Approved → mark linked standard WorkOrder as Scheduled (or create if not yet linked)
 *     On Rejected → return to Takeoff for revision
 *
 * Spec reference: Sections 7.5, 7.6, 7.7
 */
public with sharing class QuoteService {

    // ─────────────────────────────────────────────
    // BEFORE UPSERT — validation and auto-stamps
    // ─────────────────────────────────────────────
    public static void beforeUpsert(List<Quote__c> newList, Map<Id, Quote__c> oldMap) {
        for (Quote__c q : newList) {
            Quote__c old = (oldMap != null) ? oldMap.get(q.Id) : null;
            String oldStatus = (old != null) ? old.Status__c : null;

            // Cannot un-approve
            if (oldStatus == 'Approved' && q.Status__c != 'Approved') {
                q.addError('An Approved Quote cannot be moved back to ' + q.Status__c + '. Create a new Quote or Change Order to revise scope.');
            }

            // Auto-stamp dates
            if (q.Status__c == 'Approved' && (old == null || old.Status__c != 'Approved')
                    && q.Approved_Date__c == null) {
                q.Approved_Date__c = DateTime.now();
            }
            if (q.Status__c == 'Sent' && (old == null || old.Status__c != 'Sent')
                    && q.Sent_Date__c == null) {
                q.Sent_Date__c = Date.today();
            }
        }
    }

    // ─────────────────────────────────────────────
    // ON SENT — stamp Sent_Date__c (already done in before, kept for audit)
    // ─────────────────────────────────────────────
    public static void onSent(List<Quote__c> sentQuotes) {
        // Sent_Date__c is stamped in beforeUpsert. This hook is reserved for
        // future integrations (e.g. builder portal notification via external API).
    }

    // ─────────────────────────────────────────────
    // ON APPROVED
    // ─────────────────────────────────────────────
    public static void onApproved(List<Quote__c> approvedQuotes) {
        Set<Id> quoteIds = new Map<Id, Quote__c>(approvedQuotes).keySet();

        // Query lines — only Billable determination for CC invoicing
        Map<Id, List<Quote_Line_Item__c>> linesByQuote = new Map<Id, List<Quote_Line_Item__c>>();
        for (Quote_Line_Item__c li : [
            SELECT Id, Quote__c, Item_Description__c, Quantity__c, Unit_Price__c, Unit_Cost__c,
                   Total_Revenue__c, Total_Cost__c, Margin__c,
                   Determination__c, Line_Total__c, Billable_Type__c,
                   Item_Catalog__c, Builder_Pricing_Line__c, Unit__c
            FROM Quote_Line_Item__c
            WHERE Quote__c IN :quoteIds
        ]) {
            if (!linesByQuote.containsKey(li.Quote__c)) {
                linesByQuote.put(li.Quote__c, new List<Quote_Line_Item__c>());
            }
            linesByQuote.get(li.Quote__c).add(li);
        }

        // Query parent quotes with standard WorkOrder relationship.
        Map<Id, Quote__c> quoteMap = new Map<Id, Quote__c>([
            SELECT Id, Name, Standard_Work_Order__c, RecordType.DeveloperName,
                   Standard_Work_Order__r.Community_FML__c,
                   Standard_Work_Order__r.Lot__c,
                   Standard_Work_Order__r.Status,
                   Approved_By__c, Community__c, Lot__c, Division_Account__c
            FROM Quote__c WHERE Id IN :quoteIds
        ]);

        List<Invoice__c>          invoicesToInsert  = new List<Invoice__c>();
        List<Invoice_Line_Item__c> linesToInsert     = new List<Invoice_Line_Item__c>();
        List<WorkOrder>            wosToUpdate       = new List<WorkOrder>();

        // Map from quote id → invoice (to link lines after invoice insert)
        Map<Id, Invoice__c> quoteToInvoice = new Map<Id, Invoice__c>();

        for (Quote__c q : quoteMap.values()) {
            String rtName = q.RecordType != null ? q.RecordType.DeveloperName : '';
            List<Quote_Line_Item__c> lines = linesByQuote.get(q.Id);

            if (rtName == 'Customer_Care') {
                // Build Invoice from Billable lines
                Invoice__c inv = buildCCInvoice(q);
                invoicesToInsert.add(inv);
                quoteToInvoice.put(q.Id, inv);

            } else {
                // Production Install or other: move linked Work Order to Scheduled
                if (q.Standard_Work_Order__c != null) {
                    wosToUpdate.add(new WorkOrder(
                        Id     = q.Standard_Work_Order__c,
                        Status = 'Scheduled'
                    ));
                }
            }
        }

        // Insert invoices
        if (!invoicesToInsert.isEmpty()) {
            List<Database.SaveResult> invResults = Database.insert(invoicesToInsert, false);
            for (Integer i = 0; i < invResults.size(); i++) {
                if (!invResults[i].isSuccess()) {
                    Invoice__c failedInv = invoicesToInsert[i];
                    ErrorLogService.log('QuoteService', 'onApproved.invoice',
                        failedInv.Quote__c, invResults[i].getErrors()[0].getMessage());
                }
            }
        }

        // Build Invoice Line Items from Billable quote lines
        for (Id quoteId : quoteToInvoice.keySet()) {
            Invoice__c inv = quoteToInvoice.get(quoteId);
            if (inv.Id == null) continue;  // Insert failed

            List<Quote_Line_Item__c> lines = linesByQuote.get(quoteId);
            if (lines == null || lines.isEmpty()) continue;

            Integer sortOrder = 1;
            for (Quote_Line_Item__c ql : lines) {
                if (ql.Determination__c != 'Billable') continue;

                linesToInsert.add(new Invoice_Line_Item__c(
                    Invoice__c          = inv.Id,
                    Item__c             = ql.Item_Catalog__c,
                    Description__c      = ql.Item_Description__c,
                    Quantity__c         = ql.Quantity__c,
                    Unit_Price__c       = ql.Unit_Price__c,
                    Unit_Cost__c        = ql.Unit_Cost__c,
                    Billable__c         = true,
                    Quote_Line_Item__c  = ql.Id,
                    Sort_Order__c       = sortOrder++
                ));
            }
        }

        if (!linesToInsert.isEmpty()) {
            List<Database.SaveResult> lineResults = Database.insert(linesToInsert, false);
            for (Integer i = 0; i < lineResults.size(); i++) {
                if (!lineResults[i].isSuccess()) {
                    ErrorLogService.log('QuoteService', 'onApproved.lines', null,
                        lineResults[i].getErrors()[0].getMessage());
                }
            }
        }

        // Update Work Orders for Production Install approval
        if (!wosToUpdate.isEmpty()) {
            Map<Id, WorkOrder> deduped = new Map<Id, WorkOrder>(wosToUpdate);
            List<Database.SaveResult> woResults = Database.update(deduped.values(), false);
            for (Integer i = 0; i < woResults.size(); i++) {
                if (!woResults[i].isSuccess()) {
                    ErrorLogService.log('QuoteService', 'onApproved.woUpdate', null,
                        woResults[i].getErrors()[0].getMessage());
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // ON REJECTED
    // ─────────────────────────────────────────────
    public static void onRejected(List<Quote__c> rejectedQuotes) {
        List<WorkOrder> wosToUpdate = new List<WorkOrder>();
        for (Quote__c q : rejectedQuotes) {
            if (q.Standard_Work_Order__c == null) continue;
            wosToUpdate.add(new WorkOrder(
                Id     = q.Standard_Work_Order__c,
                Status = 'NFI'
            ));
        }
        if (!wosToUpdate.isEmpty()) {
            Map<Id, WorkOrder> deduped = new Map<Id, WorkOrder>(wosToUpdate);
            Database.update(deduped.values(), false);
        }
    }

    // ─────────────────────────────────────────────
    // INVOICE BUILDER — Customer Care
    // ─────────────────────────────────────────────
    private static Invoice__c buildCCInvoice(Quote__c q) {
        Id woId       = q.Standard_Work_Order__c;
        Id divAcctId  = q.Division_Account__c;
        Id builderAcct = q.Division_Account__c;
        Id lotId      = q.Lot__c != null ? q.Lot__c
                          : (q.Standard_Work_Order__r != null ? q.Standard_Work_Order__r.Lot__c : null);
        Id commId     = q.Community__c != null ? q.Community__c
                          : (q.Standard_Work_Order__r != null ? q.Standard_Work_Order__r.Community_FML__c : null);

        return new Invoice__c(
            Work_Order__c             = woId,
            Builder_WorkOrder__c      = woId,
            Quote__c                  = q.Id,
            Division_Account__c       = divAcctId,
            Builder_Market_Account__c = builderAcct,
            Lot__c                    = lotId,
            Community__c              = commId,
            Invoice_Type__c           = 'Customer Care',
            Invoice_Date__c           = Date.today(),
            Status__c                 = 'Pending Send',
            Due_Date__c               = Date.today().addDays(30)
        );
    }
}