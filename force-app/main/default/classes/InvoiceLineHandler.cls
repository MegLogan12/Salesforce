/**
 * InvoiceLineHandler
 *
 * Before-insert/update handler for Invoice_Line_Item__c.
 * Calculates all derived financial fields so the UI always shows
 * consistent, live numbers without requiring the user to save twice.
 *
 * Fields calculated:
 *   Line_Total__c         = Quantity × Unit_Price__c
 *   Line_Cost__c          = Quantity × Unit_Cost__c
 *   Gross_Margin__c       = Line_Total - Line_Cost
 *   Gross_Margin_Pct__c   = (Gross_Margin / Line_Total) × 100  (0 when Line_Total = 0)
 */
public with sharing class InvoiceLineHandler {

    public static void handleBefore(
            List<Invoice_Line_Item__c> newList,
            Map<Id, Invoice_Line_Item__c> oldMap) {

        for (Invoice_Line_Item__c line : newList) {
            // Skip recalculation if neither quantity nor price changed
            if (oldMap != null) {
                Invoice_Line_Item__c old = oldMap.get(line.Id);
                Boolean unchanged = (line.Quantity__c == old.Quantity__c)
                                 && (line.Unit_Price__c == old.Unit_Price__c)
                                 && (line.Unit_Cost__c  == old.Unit_Cost__c);
                if (unchanged) continue;
            }

            Decimal qty   = line.Quantity__c  != null ? line.Quantity__c  : 0;
            Decimal price = line.Unit_Price__c != null ? line.Unit_Price__c : 0;
            Decimal cost  = line.Unit_Cost__c  != null ? line.Unit_Cost__c  : 0;

            Decimal lineTotal = qty * price;
            Decimal lineCost  = qty * cost;
            Decimal margin    = lineTotal - lineCost;
            Decimal marginPct = (lineTotal != 0) ? (margin / lineTotal * 100) : 0;

            line.Line_Total__c        = lineTotal;
            line.Line_Cost__c         = lineCost;
            line.Gross_Margin__c      = margin;
            line.Gross_Margin_Pct__c  = marginPct;
        }
    }
}