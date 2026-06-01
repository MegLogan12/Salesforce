public with sharing class ODLQuoteWorkspaceController {
    public class QuoteRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String expirationDate;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String accountName;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public Boolean hasGrandTotal;
    }

    @AuraEnabled(cacheable=true)
    public static List<QuoteRow> getQuotes() {
        List<QuoteRow> rows = new List<QuoteRow>();
        for (Quote q : [
            SELECT Id, Name, Status, ExpirationDate, GrandTotal,
                   Opportunity.Name, Opportunity.Account.Name
            FROM Quote
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]) {
            QuoteRow row = new QuoteRow();
            row.id = q.Id;
            row.name = q.Name;
            row.status = q.Status;
            row.expirationDate = q.ExpirationDate != null ? String.valueOf(q.ExpirationDate) : null;
            row.grandTotal = q.GrandTotal;
            row.hasGrandTotal = q.GrandTotal != null;
            row.opportunityName = q.Opportunity != null ? q.Opportunity.Name : null;
            row.accountName = (q.Opportunity != null && q.Opportunity.Account != null)
                ? q.Opportunity.Account.Name : null;
            rows.add(row);
        }
        return rows;
    }
}
