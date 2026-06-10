public with sharing class CloudscapeIngestService {

    public class CostPayload {
        public String sku;
        public Decimal unitCost;
        public Decimal freight;
        public String vendor;
        public Date effectiveDate;
    }

    public static void upsertCosts(List<CostPayload> payloads) {
        if (payloads == null || payloads.isEmpty()) return;

        Set<String> skus = new Set<String>();
        for (CostPayload cp : payloads) {
            if (String.isNotBlank(cp.sku)) skus.add(cp.sku);
        }

        Map<String, Id> skuToProductId = new Map<String, Id>();
        for (Product2 p : [SELECT Id, StockKeepingUnit FROM Product2 WHERE StockKeepingUnit IN :skus]) {
            skuToProductId.put(p.StockKeepingUnit, p.Id);
        }

        Map<Id, Decimal> productToStdPrice = new Map<Id, Decimal>();
        List<Pricebook2> stdBooks = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (!stdBooks.isEmpty()) {
            for (PricebookEntry pbe : [
                SELECT Product2Id, UnitPrice
                FROM PricebookEntry
                WHERE Pricebook2Id = :stdBooks[0].Id
                  AND Product2Id IN :skuToProductId.values()
            ]) {
                productToStdPrice.put(pbe.Product2Id, pbe.UnitPrice);
            }
        }

        Map<Id, Cost_Catalog__c> existingByProduct = new Map<Id, Cost_Catalog__c>();
        for (Cost_Catalog__c cc : [
            SELECT Id, Item__c FROM Cost_Catalog__c WHERE Item__c IN :skuToProductId.values()
        ]) {
            existingByProduct.put(cc.Item__c, cc);
        }

        List<Cost_Catalog__c> toInsert = new List<Cost_Catalog__c>();
        List<Cost_Catalog__c> toUpdate = new List<Cost_Catalog__c>();

        for (CostPayload cp : payloads) {
            Id prodId = skuToProductId.get(cp.sku);
            if (prodId == null) continue;
            Cost_Catalog__c cc = existingByProduct.containsKey(prodId)
                ? new Cost_Catalog__c(Id = existingByProduct.get(prodId).Id)
                : new Cost_Catalog__c();
            cc.Item__c            = prodId;
            cc.Unit_Cost__c       = cp.unitCost;
            cc.Freight__c         = cp.freight;
            cc.Vendor__c          = cp.vendor;
            cc.Effective_Date__c  = cp.effectiveDate != null ? cp.effectiveDate : Date.today();
            cc.Standard_Price__c  = productToStdPrice.get(prodId);
            if (existingByProduct.containsKey(prodId)) {
                toUpdate.add(cc);
            } else {
                toInsert.add(cc);
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;

        flagLowStock(skuToProductId.values());
    }

    private static void flagLowStock(List<Id> productIds) {
        List<Cost_Catalog__c> toUpdate = new List<Cost_Catalog__c>();
        for (Cost_Catalog__c cc : [
            SELECT Id, Item__c, Item__r.On_Hand__c, Item__r.Reorder_Point__c
            FROM Cost_Catalog__c
            WHERE Item__c IN :productIds
        ]) {
            Decimal onHand  = cc.Item__r.On_Hand__c != null ? cc.Item__r.On_Hand__c : 0;
            Decimal reorder = cc.Item__r.Reorder_Point__c != null ? cc.Item__r.Reorder_Point__c : 0;
            cc.Low_Stock_Flag__c = (reorder > 0 && onHand <= reorder);
            toUpdate.add(cc);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }
}
