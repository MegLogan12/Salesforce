/**
 * InventoryMaterialsController
 * Backend for the Inventory & Materials Console.
 * Maintains backward-compatible InventoryView for existing org consumers
 * while exposing Product2/Cost_Catalog__c methods for the LWC.
 */
public with sharing class InventoryMaterialsController {

    private static final Integer LOW_STOCK_THRESHOLD = 10;

    // ─── Legacy DTOs (kept for backward compatibility) ───────────────────────

    public class InventoryView {
        @AuraEnabled public Integer totalItems;
        @AuraEnabled public Integer lowStockCount;
        @AuraEnabled public List<InventoryRow> rows;
    }

    public class InventoryRow {
        @AuraEnabled public Id      recordId;
        @AuraEnabled public String  itemType;
        @AuraEnabled public String  location;
        @AuraEnabled public String  locationType;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Boolean isLowStock;
        @AuraEnabled public String  crewOrVehicle;
    }

    // ─── New DTOs ────────────────────────────────────────────────────────────

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

    // ─── Legacy API (kept for backward compatibility) ────────────────────────

    @AuraEnabled(cacheable=true)
    public static InventoryView getInventory() {
        if (!Schema.sObjectType.Aqua_Inventory__c.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to Aqua Inventory records.'
            );
        }
        List<Aqua_Inventory__c> items = [
            SELECT Id, Name, Item_Type__c, Location__c, Location_Type__c, Quantity__c
            FROM Aqua_Inventory__c
            ORDER BY Item_Type__c, Location_Type__c
            LIMIT 200
        ];
        return buildView(items);
    }

    @TestVisible
    private static InventoryView buildView(List<Aqua_Inventory__c> items) {
        InventoryView view = new InventoryView();
        view.rows = new List<InventoryRow>();
        Integer lowCount = 0;
        for (Aqua_Inventory__c inv : items) {
            InventoryRow row = new InventoryRow();
            row.recordId     = inv.Id;
            row.itemType     = inv.Item_Type__c;
            row.location     = inv.Location__c;
            row.locationType = inv.Location_Type__c;
            row.quantity     = inv.Quantity__c != null ? inv.Quantity__c : 0;
            row.isLowStock   = row.quantity < LOW_STOCK_THRESHOLD;
            row.crewOrVehicle = null;
            if (row.isLowStock) lowCount++;
            view.rows.add(row);
        }
        view.totalItems    = view.rows.size();
        view.lowStockCount = lowCount;
        return view;
    }

    // ─── New API ─────────────────────────────────────────────────────────────

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
            r.productId     = p.Id;
            r.name          = p.Name;
            r.sku           = p.StockKeepingUnit;
            r.category      = p.Category__c;
            r.unitOfMeasure = p.QuantityUnitOfMeasure;
            r.onHand        = p.On_Hand__c != null ? p.On_Hand__c : 0;
            r.reorderPoint  = p.Reorder_Point__c != null ? p.Reorder_Point__c : 0;
            r.lowStock      = (r.onHand <= r.reorderPoint && r.reorderPoint > 0);
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