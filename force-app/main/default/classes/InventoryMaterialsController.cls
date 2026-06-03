/**
 * InventoryMaterialsController
 * Backend for Screen 23 — Inventory & Materials Console.
 * Returns all Aqua_Inventory__c records grouped for display,
 * with low-stock flagging (threshold: qty < 10).
 */
public with sharing class InventoryMaterialsController {

    private static final Integer LOW_STOCK_THRESHOLD = 10;

    // ─── DTOs ────────────────────────────────────────────────────────────────

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

    // ─── Public API ──────────────────────────────────────────────────────────

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

    // ─── Testable builder ────────────────────────────────────────────────────

    @TestVisible
    private static InventoryView buildView(List<Aqua_Inventory__c> items) {
        InventoryView view      = new InventoryView();
        view.rows               = new List<InventoryRow>();
        Integer lowCount        = 0;

        for (Aqua_Inventory__c inv : items) {
            InventoryRow row    = new InventoryRow();
            row.recordId        = inv.Id;
            row.itemType        = inv.Item_Type__c;
            row.location        = inv.Location__c;
            row.locationType    = inv.Location_Type__c;
            row.quantity        = inv.Quantity__c != null ? inv.Quantity__c : 0;
            row.isLowStock      = row.quantity < LOW_STOCK_THRESHOLD;
            row.crewOrVehicle   = null; // Vehicle__c lookup omitted per spec
            if (row.isLowStock) lowCount++;
            view.rows.add(row);
        }

        view.totalItems   = view.rows.size();
        view.lowStockCount = lowCount;
        return view;
    }
}
