@isTest
private class CloudscapeIngestTest {

    @isTest
    static void upsertCreatesNewEntry() {
        Product2 p = new Product2(Name = 'Test Item', IsActive = true, StockKeepingUnit = 'TST-001');
        insert p;

        CloudscapeIngestService.CostPayload cp = new CloudscapeIngestService.CostPayload();
        cp.sku           = 'TST-001';
        cp.unitCost      = 12.00;
        cp.freight       = 3.00;
        cp.vendor        = 'Cloudscape Vendor';
        cp.effectiveDate = Date.today();

        Test.startTest();
        CloudscapeIngestService.upsertCosts(new List<CloudscapeIngestService.CostPayload>{ cp });
        Test.stopTest();

        List<Cost_Catalog__c> entries = [SELECT Unit_Cost__c, Freight__c, Landed_Cost__c FROM Cost_Catalog__c WHERE Item__c = :p.Id];
        System.assertEquals(1, entries.size(), 'One cost entry created');
        System.assertEquals(12.00, entries[0].Unit_Cost__c);
        System.assertEquals(15.00, entries[0].Landed_Cost__c);
    }

    @isTest
    static void upsertUpdatesExistingByProduct() {
        Product2 p = new Product2(Name = 'Test Item2', IsActive = true, StockKeepingUnit = 'TST-002');
        insert p;

        Cost_Catalog__c existing = new Cost_Catalog__c(
            Item__c = p.Id, Unit_Cost__c = 5.00, Effective_Date__c = Date.today()
        );
        insert existing;

        CloudscapeIngestService.CostPayload cp = new CloudscapeIngestService.CostPayload();
        cp.sku = 'TST-002'; cp.unitCost = 7.00; cp.freight = 1.00; cp.effectiveDate = Date.today();

        Test.startTest();
        CloudscapeIngestService.upsertCosts(new List<CloudscapeIngestService.CostPayload>{ cp });
        Test.stopTest();

        List<Cost_Catalog__c> entries = [SELECT Unit_Cost__c FROM Cost_Catalog__c WHERE Item__c = :p.Id];
        System.assertEquals(1, entries.size(), 'No duplicate created on upsert');
        System.assertEquals(7.00, entries[0].Unit_Cost__c, 'Cost updated');
    }

    @isTest
    static void gpRecalcAfterIngest() {
        Product2 p = new Product2(Name = 'Test Item3', IsActive = true, StockKeepingUnit = 'TST-003');
        insert p;

        // In test context, must use Test.getStandardPricebookId() to get the accessible standard PB
        Id stdPbId = Test.getStandardPricebookId();
        // Activate the standard pricebook for test context
        update new Pricebook2(Id = stdPbId, IsActive = true);
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId, Product2Id = p.Id, UnitPrice = 20.00, IsActive = true
        );
        insert pbe;

        CloudscapeIngestService.CostPayload cp = new CloudscapeIngestService.CostPayload();
        cp.sku = 'TST-003'; cp.unitCost = 8.00; cp.freight = 2.00; cp.effectiveDate = Date.today();

        Test.startTest();
        CloudscapeIngestService.upsertCosts(new List<CloudscapeIngestService.CostPayload>{ cp });
        Test.stopTest();

        Cost_Catalog__c cc = [SELECT Standard_Price__c, GP_Pct__c, Landed_Cost__c FROM Cost_Catalog__c WHERE Item__c = :p.Id LIMIT 1];
        System.assertEquals(20.00, cc.Standard_Price__c, 'Standard price synced from PBE');
        System.assertEquals(10.00, cc.Landed_Cost__c, 'Landed cost');
        // Percent formula stores as percentage number (50.0 = 50%)
        Decimal expectedGP = (20.00 - 10.00) / 20.00 * 100;
        System.assertEquals(expectedGP.setScale(4), cc.GP_Pct__c.setScale(4), 'GP recalculated');
    }
}
