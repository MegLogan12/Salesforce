/**
 * ScannerReceivingController
 * Backend for Screen 24 — Receiving & Scanner.
 * Provides read of recent Aqua_Inventory__c receipts and a write method
 * to insert a new receipt record.
 *
 * Note: Full barcode scan and vendor PO three-way match require handheld
 * scanner integration (G4 gate).
 */
public with sharing class ScannerReceivingController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class RecentReceiptRow {
        @AuraEnabled public Id       recordId;
        @AuraEnabled public String   itemType;
        @AuraEnabled public Decimal  quantity;
        @AuraEnabled public String   location;
        @AuraEnabled public String   locationType;
        @AuraEnabled public String   workOrderNumber;
        @AuraEnabled public DateTime createdDate;
    }

    // ─── Public API ──────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<RecentReceiptRow> getRecentReceipts() {
        if (!Schema.sObjectType.Aqua_Inventory__c.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to Aqua Inventory records.'
            );
        }
        List<Aqua_Inventory__c> items = [
            SELECT Id, Item_Type__c, Quantity__c, Location__c, Location_Type__c,
                   Work_Order__c, Work_Order__r.WorkOrderNumber, CreatedDate
            FROM Aqua_Inventory__c
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];

        List<RecentReceiptRow> rows = new List<RecentReceiptRow>();
        for (Aqua_Inventory__c inv : items) {
            RecentReceiptRow row = new RecentReceiptRow();
            row.recordId        = inv.Id;
            row.itemType        = inv.Item_Type__c;
            row.quantity        = inv.Quantity__c;
            row.location        = inv.Location__c;
            row.locationType    = inv.Location_Type__c;
            row.workOrderNumber = inv.Work_Order__c != null
                ? inv.Work_Order__r.WorkOrderNumber
                : null;
            row.createdDate     = inv.CreatedDate;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled
    public static Id receiveItem(
        String  itemType,
        Decimal quantity,
        String  location,
        String  locationType,
        Id      workOrderId
    ) {
        if (!Schema.sObjectType.Aqua_Inventory__c.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to Aqua Inventory records.'
            );
        }
        if (!Schema.sObjectType.Aqua_Inventory__c.isCreateable()) {
            throw new AuraHandledException(
                'Insufficient permission to create Aqua Inventory records.'
            );
        }

        Aqua_Inventory__c inv = new Aqua_Inventory__c(
            Item_Type__c     = itemType,
            Quantity__c      = quantity,
            Location__c      = location,
            Location_Type__c = locationType,
            Work_Order__c    = workOrderId
        );
        insert inv;
        return inv.Id;
    }
}
