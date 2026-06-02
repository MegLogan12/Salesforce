/**
 * QuoteLineHandler
 *
 * Before-insert/update handler for Quote_Line_Item__c.
 * Calculates all derived financial fields.
 *
 * Fields calculated:
 *   Line_Total__c     = Quantity × Unit_Price__c          (stored; also rolled up by Summary field)
 *   Total_Revenue__c  = Quantity × Unit_Price__c
 *   Total_Cost__c     = Quantity × Unit_Cost__c
 *   Margin__c         = Total_Revenue - Total_Cost        ($ margin)
 *
 * Note: Line_Total__c is a formula field (Qty × Price) set at field level.
 *       Total_Revenue__c and Total_Cost__c are plain Currency fields set here.
 *       Billable_Total__c and Warranty_Total__c on Quote__c are Summary fields
 *       that roll up from Line_Total__c — no Apex needed for those.
 */
public with sharing class QuoteLineHandler {

    public static void handleBefore(
            List<Quote_Line_Item__c> newList,
            Map<Id, Quote_Line_Item__c> oldMap) {

        for (Quote_Line_Item__c line : newList) {
            // Skip if nothing financial changed
            if (oldMap != null) {
                Quote_Line_Item__c old = oldMap.get(line.Id);
                Boolean unchanged = (line.Quantity__c   == old.Quantity__c)
                                 && (line.Unit_Price__c  == old.Unit_Price__c)
                                 && (line.Unit_Cost__c   == old.Unit_Cost__c);
                if (unchanged) continue;
            }

            Decimal qty   = line.Quantity__c   != null ? line.Quantity__c   : 0;
            Decimal price = line.Unit_Price__c  != null ? line.Unit_Price__c  : 0;
            Decimal cost  = line.Unit_Cost__c   != null ? line.Unit_Cost__c   : 0;

            Decimal revenue = qty * price;
            Decimal totalCost = qty * cost;
            Decimal margin  = revenue - totalCost;

            line.Total_Revenue__c = revenue;
            line.Total_Cost__c    = totalCost;
            line.Margin__c        = margin;
        }
    }
}