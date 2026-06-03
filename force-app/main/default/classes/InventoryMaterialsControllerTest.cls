@isTest
private class InventoryMaterialsControllerTest {

    @isTest
    static void getCatalogReturnsActiveProducts() {
        Product2 p1 = new Product2(Name = 'Test Pavers', IsActive = true, Category__c = 'Hardscape',
            On_Hand__c = 50, Reorder_Point__c = 10);
        Product2 p2 = new Product2(Name = 'Test Shrub', IsActive = true, Category__c = 'Planting',
            On_Hand__c = 3, Reorder_Point__c = 5);
        insert new List<Product2>{ p1, p2 };

        Test.startTest();
        List<InventoryMaterialsController.CatalogRow> all = InventoryMaterialsController.getCatalog('All');
        List<InventoryMaterialsController.CatalogRow> hardscape = InventoryMaterialsController.getCatalog('Hardscape');
        Test.stopTest();

        System.assert(all.size() >= 2, 'Returns all active products');
        Boolean foundHardscape = false;
        for (InventoryMaterialsController.CatalogRow r : hardscape) {
            if (r.name == 'Test Pavers') foundHardscape = true;
        }
        System.assert(foundHardscape, 'Hardscape filter works');
    }

    @isTest
    static void getCatalogFlagsLowStock() {
        Product2 p = new Product2(Name = 'Low Stock Plant', IsActive = true,
            On_Hand__c = 2, Reorder_Point__c = 5);
        insert p;

        Test.startTest();
        List<InventoryMaterialsController.CatalogRow> rows = InventoryMaterialsController.getCatalog('All');
        Test.stopTest();

        Boolean foundLowStock = false;
        for (InventoryMaterialsController.CatalogRow r : rows) {
            if (r.name == 'Low Stock Plant') {
                foundLowStock = r.lowStock;
            }
        }
        System.assert(foundLowStock, 'Low stock flag set');
    }

    @isTest
    static void getCostDetailReturnsNullWhenNoEntry() {
        Product2 p = new Product2(Name = 'No Cost Product', IsActive = true);
        insert p;

        Test.startTest();
        InventoryMaterialsController.CostDetail detail = InventoryMaterialsController.getCostDetail(p.Id);
        Test.stopTest();

        System.assertEquals(null, detail, 'Returns null when no cost catalog entry');
    }

    @isTest
    static void getCostDetailReturnsCostEntry() {
        Product2 p = new Product2(Name = 'Costed Product', IsActive = true);
        insert p;

        Cost_Catalog__c cc = new Cost_Catalog__c(
            Item__c = p.Id, Unit_Cost__c = 10.00, Freight__c = 2.00,
            Standard_Price__c = 25.00, Effective_Date__c = Date.today(), Vendor__c = 'Test Vendor'
        );
        insert cc;

        Test.startTest();
        InventoryMaterialsController.CostDetail detail = InventoryMaterialsController.getCostDetail(p.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Returns cost detail');
        System.assertEquals(10.00, detail.unitCost);
        System.assertEquals(2.00, detail.freight);
        System.assertEquals(12.00, detail.landedCost);
        System.assertEquals(25.00, detail.standardPrice);
    }

    @isTest
    static void updateStandardPriceWorks() {
        Product2 p = new Product2(Name = 'Price Update Product', IsActive = true);
        insert p;

        Cost_Catalog__c cc = new Cost_Catalog__c(
            Item__c = p.Id, Unit_Cost__c = 5.00, Effective_Date__c = Date.today()
        );
        insert cc;

        Test.startTest();
        InventoryMaterialsController.updateStandardPrice(cc.Id, 30.00);
        Test.stopTest();

        cc = [SELECT Standard_Price__c FROM Cost_Catalog__c WHERE Id = :cc.Id];
        System.assertEquals(30.00, cc.Standard_Price__c, 'Standard price updated');
    }

    @isTest
    static void createReorderTaskCreatesTask() {
        Product2 p = new Product2(Name = 'Reorder Product', IsActive = true);
        insert p;

        Test.startTest();
        InventoryMaterialsController.createReorderTask(p.Id);
        Test.stopTest();

        List<Task> tasks = [SELECT Subject FROM Task WHERE WhatId = :p.Id];
        System.assertEquals(1, tasks.size(), 'Task created');
        System.assert(tasks[0].Subject.contains('Reorder'), 'Subject mentions reorder');
    }
}
