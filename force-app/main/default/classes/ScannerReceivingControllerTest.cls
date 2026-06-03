@IsTest(SeeAllData=false)
private class ScannerReceivingControllerTest {

    // ── Test 1: receiveItem inserts a record correctly ─────────────────────────

    @IsTest
    static void receiveItem_insertsRecord() {
        Test.startTest();
        Id newId = ScannerReceivingController.receiveItem(
            'Rotor Head',
            10,
            'Warehouse A',
            'Shop',
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, newId,
            'receiveItem should return the Id of the inserted record.');
        Integer count = [
            SELECT COUNT() FROM Aqua_Inventory__c WHERE Id = :newId
        ];
        System.assertEquals(1, count,
            'Exactly one Aqua_Inventory__c record should exist with the returned Id.');
    }

    // ── Test 2: getRecentReceipts returns inserted records ────────────────────

    @IsTest
    static void getRecentReceipts_returnsRows() {
        insert new List<Aqua_Inventory__c>{
            new Aqua_Inventory__c(
                Item_Type__c     = 'Spray Nozzle',
                Quantity__c      = 5,
                Location__c      = 'Truck 02',
                Location_Type__c = 'Van'
            ),
            new Aqua_Inventory__c(
                Item_Type__c     = 'Valve Box',
                Quantity__c      = 8,
                Location__c      = 'Warehouse B',
                Location_Type__c = 'Shop'
            )
        };

        Test.startTest();
        List<ScannerReceivingController.RecentReceiptRow> rows =
            ScannerReceivingController.getRecentReceipts();
        Test.stopTest();

        System.assert(rows.size() >= 2,
            'getRecentReceipts should return at least the 2 inserted records.');
    }

    // ── Test 3: receiveItem with null workOrderId still inserts ───────────────

    @IsTest
    static void receiveItem_nullWorkOrder_succeeds() {
        Test.startTest();
        Id newId = ScannerReceivingController.receiveItem(
            'Control Module',
            3,
            'Warehouse A',
            'Shop',
            null    // explicitly null — no WO association
        );
        Test.stopTest();

        Aqua_Inventory__c inserted = [
            SELECT Id, Item_Type__c, Work_Order__c
            FROM Aqua_Inventory__c
            WHERE Id = :newId
        ];
        System.assertEquals('Control Module', inserted.Item_Type__c,
            'Item type should be persisted correctly.');
        System.assertEquals(null, inserted.Work_Order__c,
            'Work_Order__c should remain null when not provided.');
    }
}
