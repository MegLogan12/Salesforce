@IsTest(SeeAllData=false)
private class InventoryMaterialsControllerTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static List<Aqua_Inventory__c> makeRecords() {
        return new List<Aqua_Inventory__c>{
            new Aqua_Inventory__c(
                Item_Type__c    = 'Rotor Head',
                Location__c     = 'Warehouse A',
                Location_Type__c = 'Warehouse',
                Quantity__c     = 25
            ),
            new Aqua_Inventory__c(
                Item_Type__c    = 'Spray Nozzle',
                Location__c     = 'Truck 01',
                Location_Type__c = 'Truck',
                Quantity__c     = 12
            ),
            new Aqua_Inventory__c(
                Item_Type__c    = 'Valve Box',
                Location__c     = 'Warehouse B',
                Location_Type__c = 'Warehouse',
                Quantity__c     = 3          // low stock — below 10
            )
        };
    }

    // ── Test 1: buildView counts low-stock records correctly ──────────────────

    @IsTest
    static void buildView_countsLowStock() {
        List<Aqua_Inventory__c> records = makeRecords();
        insert records;

        Test.startTest();
        InventoryMaterialsController.InventoryView view =
            InventoryMaterialsController.buildView(records);
        Test.stopTest();

        System.assertEquals(1, view.lowStockCount,
            'Expected exactly 1 low-stock record (qty 3 < 10).');
        System.assertEquals(3, view.totalItems,
            'Expected 3 total items.');
    }

    // ── Test 2: buildView rows are populated with correct field values ────────

    @IsTest
    static void buildView_rowsGroupCorrectly() {
        List<Aqua_Inventory__c> records = makeRecords();
        insert records;

        Test.startTest();
        InventoryMaterialsController.InventoryView view =
            InventoryMaterialsController.buildView(records);
        Test.stopTest();

        System.assertEquals(3, view.rows.size(),
            'Row count should match inserted records.');

        // Verify first row (Rotor Head, qty 25 — in stock)
        InventoryMaterialsController.InventoryRow first = view.rows[0];
        System.assertEquals('Rotor Head', first.itemType,
            'First row item type should be Rotor Head.');
        System.assertEquals(25, first.quantity,
            'First row quantity should be 25.');
        System.assertEquals(false, first.isLowStock,
            'Rotor Head should not be low stock.');

        // Verify third row (Valve Box, qty 3 — low stock)
        InventoryMaterialsController.InventoryRow third = view.rows[2];
        System.assertEquals('Valve Box', third.itemType,
            'Third row item type should be Valve Box.');
        System.assertEquals(true, third.isLowStock,
            'Valve Box qty 3 should be low stock.');
    }

    // ── Test 3: buildView handles empty list without error ────────────────────

    @IsTest
    static void buildView_emptyList() {
        Test.startTest();
        InventoryMaterialsController.InventoryView view =
            InventoryMaterialsController.buildView(new List<Aqua_Inventory__c>());
        Test.stopTest();

        System.assertEquals(0, view.totalItems,
            'Total items should be 0 for an empty input.');
        System.assertEquals(0, view.lowStockCount,
            'Low stock count should be 0 for an empty input.');
        System.assertNotEquals(null, view.rows,
            'Rows list should not be null.');
    }
}
