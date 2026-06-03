@isTest
private class LowStockFlagTest {

    @isTest
    static void flagSetWhenOnHandBelowReorderPoint() {
        Product2 p = new Product2(
            Name = 'Low Stock Item', IsActive = true, StockKeepingUnit = 'LST-001',
            On_Hand__c = 3, Reorder_Point__c = 5
        );
        insert p;

        Cost_Catalog__c cc = new Cost_Catalog__c(
            Item__c = p.Id, Unit_Cost__c = 10.00, Effective_Date__c = Date.today()
        );
        insert cc;

        CloudscapeIngestService.CostPayload cp = new CloudscapeIngestService.CostPayload();
        cp.sku = 'LST-001'; cp.unitCost = 10.00; cp.effectiveDate = Date.today();

        Test.startTest();
        CloudscapeIngestService.upsertCosts(new List<CloudscapeIngestService.CostPayload>{ cp });
        Test.stopTest();

        cc = [SELECT Low_Stock_Flag__c FROM Cost_Catalog__c WHERE Item__c = :p.Id LIMIT 1];
        System.assertEquals(true, cc.Low_Stock_Flag__c, 'Low stock flag set when on_hand <= reorder_point');
    }

    @isTest
    static void flagClearedWhenOnHandAboveReorderPoint() {
        Product2 p = new Product2(
            Name = 'Stocked Item', IsActive = true, StockKeepingUnit = 'LST-002',
            On_Hand__c = 50, Reorder_Point__c = 5
        );
        insert p;

        CloudscapeIngestService.CostPayload cp = new CloudscapeIngestService.CostPayload();
        cp.sku = 'LST-002'; cp.unitCost = 10.00; cp.effectiveDate = Date.today();

        Test.startTest();
        CloudscapeIngestService.upsertCosts(new List<CloudscapeIngestService.CostPayload>{ cp });
        Test.stopTest();

        Cost_Catalog__c cc = [SELECT Low_Stock_Flag__c FROM Cost_Catalog__c WHERE Item__c = :p.Id LIMIT 1];
        System.assertEquals(false, cc.Low_Stock_Flag__c, 'Flag cleared when well-stocked');
    }
}
