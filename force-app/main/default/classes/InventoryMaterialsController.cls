public with sharing class InventoryMaterialsController {

    public class CatalogRow {
        @AuraEnabled public Id productId;
        @AuraEnabled public String name;
        @AuraEnabled public String sku;
        @AuraEnabled public String category;
        @AuraEnabled public String unitOfMeasure;
        @AuraEnabled public Decimal onHand;
        @AuraEnabled public Decimal reorderPoint;
        @AuraEnabled public Boolean lowStock;
    }

    public class CostDetail {
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal unitCost;
        @AuraEnabled public Decimal freight;
        @AuraEnabled public Decimal landedCost;
        @AuraEnabled public Decimal standardPrice;
        @AuraEnabled public Decimal gpPct;
        @AuraEnabled public String vendor;
        @AuraEnabled public Date effectiveDate;
    }

    @AuraEnabled(cacheable=true)
    public static List<CatalogRow> getCatalog(String category) {
        String q = 'SELECT Id, Name, StockKeepingUnit, Category__c, QuantityUnitOfMeasure, On_Hand__c, Reorder_Point__c '
                 + 'FROM Product2 WHERE IsActive = true';
        if (String.isNotBlank(category) && category != 'All') {
            q += ' AND Category__c = :category';
        }
        q += ' ORDER BY Name LIMIT 500';

        List<CatalogRow> rows = new List<CatalogRow>();
        for (Product2 p : Database.query(q)) {
            CatalogRow r = new CatalogRow();
            r.productId      = p.Id;
            r.name           = p.Name;
            r.sku            = p.StockKeepingUnit;
            r.category       = p.Category__c;
            r.unitOfMeasure  = p.QuantityUnitOfMeasure;
            r.onHand         = p.On_Hand__c != null ? p.On_Hand__c : 0;
            r.reorderPoint   = p.Reorder_Point__c != null ? p.Reorder_Point__c : 0;
            r.lowStock       = (r.onHand <= r.reorderPoint && r.reorderPoint > 0);
            rows.add(r);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static CostDetail getCostDetail(Id productId) {
        List<Cost_Catalog__c> entries = [
            SELECT Item__c, Item__r.Name, Unit_Cost__c, Freight__c, Landed_Cost__c,
                   Standard_Price__c, GP_Pct__c, Vendor__c, Effective_Date__c
            FROM Cost_Catalog__c
            WHERE Item__c = :productId
            ORDER BY Effective_Date__c DESC
            LIMIT 1
        ];
        if (entries.isEmpty()) return null;
        Cost_Catalog__c cc = entries[0];
        CostDetail d = new CostDetail();
        d.productId     = cc.Item__c;
        d.productName   = cc.Item__r.Name;
        d.unitCost      = cc.Unit_Cost__c;
        d.freight       = cc.Freight__c;
        d.landedCost    = cc.Landed_Cost__c;
        d.standardPrice = cc.Standard_Price__c;
        d.gpPct         = cc.GP_Pct__c;
        d.vendor        = cc.Vendor__c;
        d.effectiveDate = cc.Effective_Date__c;
        return d;
    }

    @AuraEnabled
    public static void updateStandardPrice(Id costCatalogId, Decimal price) {
        Cost_Catalog__c cc = new Cost_Catalog__c(Id = costCatalogId, Standard_Price__c = price);
        update cc;
    }

    @AuraEnabled
    public static void createReorderTask(Id productId) {
        Product2 p = [SELECT Name FROM Product2 WHERE Id = :productId LIMIT 1];
        Task t = new Task(
            Subject     = 'Reorder: ' + p.Name,
            Status      = 'Not Started',
            Priority    = 'High',
            WhatId      = productId,
            Description = 'On-hand quantity has fallen to or below reorder point. Please initiate a vendor PO.'
        );
        insert t;
    }
}
