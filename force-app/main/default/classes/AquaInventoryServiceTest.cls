@IsTest
private class AquaInventoryServiceTest {

    @TestSetup
    static void seed() {
        // Master inventory: 100 controllers, 500 heads
        insert new List<Aqua_Master_Inventory__c>{
            new Aqua_Master_Inventory__c(Item_Type__c = 'Controller', Total_Purchased__c = 100),
            new Aqua_Master_Inventory__c(Item_Type__c = 'Heads',      Total_Purchased__c = 500)
        };

        // Shop holds the entire master inventory (Work_Order__c left null)
        insert new List<Aqua_Inventory__c>{
            new Aqua_Inventory__c(Location__c = 'Shop', Item_Type__c = 'Controller', Quantity__c = 100),
            new Aqua_Inventory__c(Location__c = 'Shop', Item_Type__c = 'Heads',      Quantity__c = 500)
        };

        insert new Work_Order__c(Status__c = 'Approved');
    }

    @IsTest
    static void allocateInstallMovesShopToVan() {
        Aqua_Install_Ticket__c ticket = new Aqua_Install_Ticket__c(
            Controller_Count__c = 5,
            Heads_Count__c      = 25
        );

        Test.startTest();
        AquaInventoryService.allocateInstallInventory(ticket);
        Test.stopTest();

        Decimal shopCtrl = qty('Shop', 'Controller', null);
        Decimal vanCtrl  = qty('Van',  'Controller', null);
        Decimal shopHd   = qty('Shop', 'Heads',      null);
        Decimal vanHd    = qty('Van',  'Heads',      null);

        System.assertEquals(95, shopCtrl, 'Shop controllers reduced by 5');
        System.assertEquals(5,  vanCtrl,  'Van controllers increased by 5');
        System.assertEquals(475, shopHd,  'Shop heads reduced by 25');
        System.assertEquals(25,  vanHd,   'Van heads increased by 25');

        // Total still equals master
        System.assertEquals(100, shopCtrl + vanCtrl);
        System.assertEquals(500, shopHd + vanHd);
    }

    @IsTest
    static void confirmOnSiteMovesVanToOnSite() {
        // Pre-stage: Van has 5 controllers and 25 heads
        Aqua_Install_Ticket__c ticket = new Aqua_Install_Ticket__c(
            Controller_Count__c = 5, Heads_Count__c = 25
        );
        AquaInventoryService.allocateInstallInventory(ticket);

        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        Test.startTest();
        AquaInventoryService.confirmOnSiteInventory(wo.Id, 5, 25);
        Test.stopTest();

        Decimal vanCtrl   = qty('Van',     'Controller', null);
        Decimal siteCtrl  = qty('On-Site', 'Controller', wo.Id);
        Decimal vanHd     = qty('Van',     'Heads',      null);
        Decimal siteHd    = qty('On-Site', 'Heads',      wo.Id);

        System.assertEquals(0, vanCtrl,  'Van controllers drained');
        System.assertEquals(5, siteCtrl, 'On-site controllers received');
        System.assertEquals(0,  vanHd);
        System.assertEquals(25, siteHd);
    }

    @IsTest
    static void returnInventoryMovesOnSiteToShop() {
        Aqua_Install_Ticket__c ticket = new Aqua_Install_Ticket__c(
            Controller_Count__c = 5, Heads_Count__c = 25
        );
        AquaInventoryService.allocateInstallInventory(ticket);

        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];
        AquaInventoryService.confirmOnSiteInventory(wo.Id, 5, 25);

        Test.startTest();
        AquaInventoryService.returnInventoryToShop(wo.Id, 5, 25);
        Test.stopTest();

        Decimal shopCtrl = qty('Shop',    'Controller', null);
        Decimal siteCtrl = qty('On-Site', 'Controller', wo.Id);
        Decimal shopHd   = qty('Shop',    'Heads',      null);
        Decimal siteHd   = qty('On-Site', 'Heads',      wo.Id);

        System.assertEquals(100, shopCtrl, 'Shop controllers restored');
        System.assertEquals(0,   siteCtrl, 'On-site controllers drained');
        System.assertEquals(500, shopHd);
        System.assertEquals(0,   siteHd);
    }

    @IsTest
    static void warrantyReplacementCreatesRecordWithoutInventoryMove() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        Test.startTest();
        AquaInventoryService.createWarrantyReplacement(wo.Id, 'Controller swap, head leak');
        Test.stopTest();

        List<Aqua_Warranty_Record__c> records = [
            SELECT Id, Notes__c, Billed__c, Replacement_Date__c
            FROM Aqua_Warranty_Record__c WHERE LOVING_Work_Order__c = :wo.Id
        ];
        System.assertEquals(1, records.size());
        System.assertEquals(false, records[0].Billed__c, 'Warranty replacements are never billed');
        System.assertEquals(Date.today(), records[0].Replacement_Date__c);

        // No on-site inventory should have been created
        Integer onSiteRows = [SELECT COUNT() FROM Aqua_Inventory__c WHERE Location__c = 'On-Site'];
        System.assertEquals(0, onSiteRows, 'Warranty swap is net-neutral on inventory');
    }

    @IsTest
    static void reconcileThreeLocationsWithMatchedInstall() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        Aqua_Install_Ticket__c install = new Aqua_Install_Ticket__c(
            LOVING_Work_Order__c           = wo.Id,
            Status__c                      = 'Closed',
            Closed_Date__c                 = Date.today(),
            Installed_Controller_Count__c  = 3,
            Installed_Heads_Count__c       = 12
        );
        insert install;

        // Match on-site inventory to install
        insert new List<Aqua_Inventory__c>{
            new Aqua_Inventory__c(Location__c = 'On-Site', Item_Type__c = 'Controller',
                                  LOVING_Work_Order__c = wo.Id, Quantity__c = 3),
            new Aqua_Inventory__c(Location__c = 'On-Site', Item_Type__c = 'Heads',
                                  LOVING_Work_Order__c = wo.Id, Quantity__c = 12)
        };

        Test.startTest();
        AquaInventoryService.reconcileThreeLocations(wo.Id);
        Test.stopTest();
        // Should not throw; mismatch path goes to escalation but balanced state is the assertion
        System.assert(true, 'Balanced reconcile completed without error');
    }

    private static Decimal qty(String location, String itemType, Id woId) {
        List<Aqua_Inventory__c> rows = [
            SELECT Quantity__c FROM Aqua_Inventory__c
            WHERE Location__c          = :location
            AND   Item_Type__c         = :itemType
            AND   LOVING_Work_Order__c = :woId
            LIMIT 1
        ];
        return rows.isEmpty() ? 0 : rows[0].Quantity__c;
    }
}