public with sharing class ReceivingController {

    public class ScanResult {
        @AuraEnabled public Boolean matched;
        @AuraEnabled public String productName;
        @AuraEnabled public String sku;
        @AuraEnabled public Id productId;
        @AuraEnabled public Id poLineId;
        @AuraEnabled public Decimal poExpectedQty;
        @AuraEnabled public Decimal poReceivedQty;
        @AuraEnabled public String message;
    }

    public class PostResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String receiptStatus;
        @AuraEnabled public Integer matchedLines;
        @AuraEnabled public Integer varianceLines;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static ScanResult scan(String sku, Id vendorPoId) {
        ScanResult r = new ScanResult();
        r.matched = false;

        List<Product2> products = [
            SELECT Id, Name, StockKeepingUnit FROM Product2
            WHERE StockKeepingUnit = :sku AND IsActive = true LIMIT 1
        ];
        if (products.isEmpty()) {
            r.message = 'SKU not found in catalog: ' + sku;
            return r;
        }
        Product2 p = products[0];
        r.productId   = p.Id;
        r.productName = p.Name;
        r.sku         = p.StockKeepingUnit;

        List<Vendor_PO_Line__c> lines = [
            SELECT Id, Expected_Qty__c, Received_Qty__c, Line_Status__c
            FROM Vendor_PO_Line__c
            WHERE Vendor_PO__c = :vendorPoId
              AND Product__c = :p.Id
              AND Line_Status__c IN ('Open', 'Partial')
            LIMIT 1
        ];
        if (lines.isEmpty()) {
            r.message = 'No open PO line found for this SKU on the selected PO.';
            return r;
        }
        Vendor_PO_Line__c pol = lines[0];
        r.matched        = true;
        r.poLineId       = pol.Id;
        r.poExpectedQty  = pol.Expected_Qty__c;
        r.poReceivedQty  = pol.Received_Qty__c != null ? pol.Received_Qty__c : 0;
        r.message        = 'Matched — ' + p.Name;
        return r;
    }

    @AuraEnabled
    public static PostResult post(Id receiptId) {
        List<Receipt_Line__c> lines = [
            SELECT Id, Product__c, Qty__c, PO_Line__c, Match_Status__c
            FROM Receipt_Line__c
            WHERE Receipt__c = :receiptId
        ];

        Map<Id, Vendor_PO_Line__c> polMap = new Map<Id, Vendor_PO_Line__c>();
        Set<Id> polIds = new Set<Id>();
        for (Receipt_Line__c rl : lines) {
            if (rl.PO_Line__c != null) polIds.add(rl.PO_Line__c);
        }
        if (!polIds.isEmpty()) {
            for (Vendor_PO_Line__c pol : [
                SELECT Id, Expected_Qty__c, Received_Qty__c, Product__c FROM Vendor_PO_Line__c WHERE Id IN :polIds
            ]) {
                polMap.put(pol.Id, pol);
            }
        }

        List<Receipt_Line__c> linesToUpdate = new List<Receipt_Line__c>();
        List<Vendor_PO_Line__c> polsToUpdate = new List<Vendor_PO_Line__c>();
        List<Product2> productsToUpdate = new List<Product2>();
        Map<Id, Product2> productMap = new Map<Id, Product2>();

        Set<Id> productIds = new Set<Id>();
        for (Receipt_Line__c rl : lines) productIds.add(rl.Product__c);
        for (Product2 p : [SELECT Id, On_Hand__c FROM Product2 WHERE Id IN :productIds]) {
            productMap.put(p.Id, p);
        }

        Integer matchedCount = 0, varianceCount = 0;
        List<Task> discrepancyTasks = new List<Task>();

        for (Receipt_Line__c rl : lines) {
            String matchStatus = 'Unmatched';
            if (rl.PO_Line__c != null && polMap.containsKey(rl.PO_Line__c)) {
                Vendor_PO_Line__c pol = polMap.get(rl.PO_Line__c);
                Decimal alreadyReceived = pol.Received_Qty__c != null ? pol.Received_Qty__c : 0;
                Decimal newTotal = alreadyReceived + rl.Qty__c;
                Decimal expected = pol.Expected_Qty__c;

                pol.Received_Qty__c = newTotal;
                if (newTotal == expected) {
                    matchStatus = 'Matched';
                    pol.Line_Status__c = 'Received';
                    matchedCount++;
                } else if (newTotal < expected) {
                    matchStatus = 'Short';
                    pol.Line_Status__c = 'Partial';
                    varianceCount++;
                } else {
                    matchStatus = 'Over';
                    pol.Line_Status__c = 'Over-Received';
                    varianceCount++;
                }
                polsToUpdate.add(pol);

                if (matchStatus != 'Matched') {
                    discrepancyTasks.add(new Task(
                        Subject     = 'Receipt Variance: ' + matchStatus,
                        Status      = 'Not Started',
                        Priority    = 'Normal',
                        Description = 'Receipt line ' + rl.Id + ' — ' + matchStatus + '. Expected: ' + expected + ', Received: ' + newTotal
                    ));
                }
            }
            rl.Match_Status__c = matchStatus;
            linesToUpdate.add(rl);

            if (rl.Product__c != null && productMap.containsKey(rl.Product__c)) {
                Product2 p = productMap.get(rl.Product__c);
                p.On_Hand__c = (p.On_Hand__c != null ? p.On_Hand__c : 0) + rl.Qty__c;
                productsToUpdate.add(p);
            }
        }

        update linesToUpdate;
        if (!polsToUpdate.isEmpty()) update polsToUpdate;
        if (!productsToUpdate.isEmpty()) update productsToUpdate;
        if (!discrepancyTasks.isEmpty()) insert discrepancyTasks;

        String newStatus = varianceCount > 0 ? 'Variance' : 'Posted';
        update new Receipt__c(Id = receiptId, Status__c = newStatus);

        PostResult res = new PostResult();
        res.success       = true;
        res.receiptStatus = newStatus;
        res.matchedLines  = matchedCount;
        res.varianceLines = varianceCount;
        res.message       = 'Posted. Matched: ' + matchedCount + ', Variances: ' + varianceCount;
        return res;
    }

    @AuraEnabled
    public static void moveToTruck(Id receiptLineId, String truckNumber) {
        Receipt_Line__c rl = [SELECT Id, Product__c, Qty__c FROM Receipt_Line__c WHERE Id = :receiptLineId LIMIT 1];
        if (rl.Product__c == null) return;
        Product2 p = [SELECT Id, On_Hand__c FROM Product2 WHERE Id = :rl.Product__c LIMIT 1];
        p.On_Hand__c = Math.max(0, (p.On_Hand__c != null ? p.On_Hand__c : 0) - rl.Qty__c);
        update p;
    }
}