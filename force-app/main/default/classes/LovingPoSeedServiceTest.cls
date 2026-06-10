@isTest
private class LovingPoSeedServiceTest {

    @TestSetup
    static void setup() {
        Account builder = new Account(Name = 'Seed Builder');
        insert builder;
        Account division = new Account(Name = 'Seed Division');
        insert division;

        Product2 product = new Product2(Name = 'Seed Sod', ProductCode = 'SEED-SOD', IsActive = true);
        insert product;
        insert new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            UnitPrice = 14,
            IsActive = true
        );

        Purchase_Order__c sourcePo = new Purchase_Order__c(
            Builder_Account__c = builder.Id,
            Division_Account__c = division.Id,
            PO_Number__c = 'SEED-PO-001',
            Quantity__c = 25,
            Total_Amount__c = 350,
            Status__c = 'Pending Takeoff',
            Package_BMG_Status__c = 'Matched',
            Item__c = null
        );
        insert sourcePo;

        insert new Builder_PO__c(
            PO_Number__c = 'SEED-PO-001',
            Status__c = 'Pending Takeoff',
            Builder_Account__c = builder.Id,
            Division_Account__c = division.Id
        );

        insert new PO_Line_Item__c(
            Purchase_Order__c = sourcePo.Id,
            Item__c = product.Id,
            Line_Description__c = 'Seed Sod Line',
            Quantity__c = 25,
            Unit_Price__c = 14,
            Work_Type__c = 'Other',
            Source_Line_Number__c = 1,
            Package_Match__c = 'Matched'
        );
    }

    @isTest
    static void testClonePurchaseOrderForPilotClonesProductBackedLines() {
        Purchase_Order__c sourcePo = [SELECT Id FROM Purchase_Order__c WHERE PO_Number__c = 'SEED-PO-001' LIMIT 1];

        Test.startTest();
        LovingPoSeedService.CloneResult result =
            LovingPoSeedService.clonePurchaseOrderForPilot(sourcePo.Id, 'SEED-PO-002', Date.today().addDays(3));
        Test.stopTest();

        System.assertNotEquals(null, result.purchaseOrderId);
        System.assertNotEquals(null, result.builderPoId);
        System.assertEquals(1, result.poLineCount);
        System.assertEquals(false, result.usedHeaderFallback);

        Purchase_Order__c clonedPo = [
            SELECT Id, PO_Number__c, Item__c, Quantity__c, Estimated_Start_Date__c
            FROM Purchase_Order__c
            WHERE Id = :result.purchaseOrderId
        ];
        System.assertEquals('SEED-PO-002', clonedPo.PO_Number__c);
        System.assertNotEquals(null, clonedPo.Item__c, 'Header item should be backfilled from the first product-backed source line.');
        System.assertEquals(25, Integer.valueOf(clonedPo.Quantity__c));
        System.assertEquals(Date.today().addDays(3), clonedPo.Estimated_Start_Date__c);

        List<PO_Line_Item__c> clonedLines = [
            SELECT Item__c, Line_Description__c, Quantity__c, Unit_Price__c, Purchase_Order__c
            FROM PO_Line_Item__c
            WHERE Purchase_Order__c = :result.purchaseOrderId
        ];
        System.assertEquals(1, clonedLines.size());
        System.assertNotEquals(null, clonedLines[0].Item__c);
        System.assertEquals('Seed Sod Line', clonedLines[0].Line_Description__c);
        System.assertEquals(25, Integer.valueOf(clonedLines[0].Quantity__c));

        Builder_PO__c clonedBuilderPo = [
            SELECT PO_Number__c
            FROM Builder_PO__c
            WHERE Id = :result.builderPoId
        ];
        System.assertEquals('SEED-PO-002', clonedBuilderPo.PO_Number__c);
    }

    @isTest
    static void testClonePurchaseOrderForPilotSeedsProductionInstallLineWhenTemplateHasNoLines() {
        Account builder = new Account(Name = 'Header Seed Builder');
        insert builder;
        Account division = new Account(Name = 'Header Seed Division');
        insert division;

        Purchase_Order__c sourcePo = new Purchase_Order__c(
            Builder_Account__c = builder.Id,
            Division_Account__c = division.Id,
            PO_Number__c = 'SEED-PO-HEADER',
            Quantity__c = 500,
            Total_Amount__c = 6000,
            Status__c = 'Pending Takeoff',
            Package_BMG_Status__c = 'Matched',
            Item__c = null
        );
        insert sourcePo;

        insert new Builder_PO__c(
            PO_Number__c = 'SEED-PO-HEADER',
            Status__c = 'Pending Takeoff',
            Builder_Account__c = builder.Id,
            Division_Account__c = division.Id
        );

        Test.startTest();
        LovingPoSeedService.CloneResult result =
            LovingPoSeedService.clonePurchaseOrderForPilot(sourcePo.Id, 'SEED-PO-HEADER-CLONE', Date.today().addDays(5));
        Test.stopTest();

        System.assertEquals(1, result.poLineCount, 'Header-only pilot seeds should create one real PO line.');
        System.assertEquals(false, result.usedHeaderFallback, 'Seeded pilot lines should not be reported as empty/fallback clones.');

        Purchase_Order__c clonedPo = [
            SELECT Id, Item__c, Quantity__c
            FROM Purchase_Order__c
            WHERE Id = :result.purchaseOrderId
        ];
        System.assertNotEquals(null, clonedPo.Item__c, 'Cloned PO header should be backfilled with the seeded scope product.');
        System.assertEquals(500, Integer.valueOf(clonedPo.Quantity__c));

        PO_Line_Item__c seededLine = [
            SELECT Item__c, Line_Description__c, Quantity__c, Unit__c, Unit_Price__c, Work_Type__c, Package_Match__c
            FROM PO_Line_Item__c
            WHERE Purchase_Order__c = :result.purchaseOrderId
            LIMIT 1
        ];
        System.assertEquals(clonedPo.Item__c, seededLine.Item__c);
        System.assertEquals('Production Install · Sod', seededLine.Line_Description__c);
        System.assertEquals(500, Integer.valueOf(seededLine.Quantity__c));
        System.assertEquals('Sqft', seededLine.Unit__c);
        System.assertEquals(12, Integer.valueOf(seededLine.Unit_Price__c));
        System.assertEquals('Production Install', seededLine.Work_Type__c);
        System.assertEquals('Matched', seededLine.Package_Match__c);

        Product2 seededProduct = [
            SELECT ProductCode, Family, IsActive
            FROM Product2
            WHERE Id = :seededLine.Item__c
            LIMIT 1
        ];
        System.assertEquals('LOVING_PI_SOD_SCOPE', seededProduct.ProductCode);
        System.assertEquals('Production Install', seededProduct.Family);
        System.assertEquals(true, seededProduct.IsActive);
    }
}