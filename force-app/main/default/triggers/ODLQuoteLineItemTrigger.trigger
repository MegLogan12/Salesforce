trigger ODLQuoteLineItemTrigger on QuoteLineItem (after insert, after update, after delete, after undelete) {
    Set<Id> quoteIds = new Set<Id>();
    if (Trigger.isDelete) {
        for (QuoteLineItem row : Trigger.old) {
            quoteIds.add(row.QuoteId);
        }
    } else {
        for (QuoteLineItem row : Trigger.new) {
            quoteIds.add(row.QuoteId);
        }
    }
    ODLVoucherLifecycleService.syncVoucherFromQuotes(quoteIds);
}