@isTest
private class LandedCostFormulaTest {

    @isTest
    static void landedCostIsUnitPlusFreight() {
        Product2 p = new Product2(Name = 'Test Sod', IsActive = true);
        insert p;

        Cost_Catalog__c cc = new Cost_Catalog__c(
            Item__c          = p.Id,
            Unit_Cost__c     = 10.00,
            Freight__c       = 2.50,
            Effective_Date__c = Date.today()
        );
        insert cc;

        cc = [SELECT Landed_Cost__c FROM Cost_Catalog__c WHERE Id = :cc.Id];
        System.assertEquals(12.50, cc.Landed_Cost__c, 'Landed cost = unit + freight');
    }

    @isTest
    static void landedCostWithNullFreight() {
        Product2 p = new Product2(Name = 'Test Plant', IsActive = true);
        insert p;

        Cost_Catalog__c cc = new Cost_Catalog__c(
            Item__c          = p.Id,
            Unit_Cost__c     = 5.00,
            Effective_Date__c = Date.today()
        );
        insert cc;

        cc = [SELECT Landed_Cost__c FROM Cost_Catalog__c WHERE Id = :cc.Id];
        System.assertEquals(5.00, cc.Landed_Cost__c, 'Null freight treated as zero');
    }

    @isTest
    static void gpPctCalculation() {
        Product2 p = new Product2(Name = 'Test Aggregate', IsActive = true);
        insert p;

        Cost_Catalog__c cc = new Cost_Catalog__c(
            Item__c           = p.Id,
            Unit_Cost__c      = 8.00,
            Freight__c        = 2.00,
            Standard_Price__c = 25.00,
            Effective_Date__c = Date.today()
        );
        insert cc;

        cc = [SELECT GP_Pct__c, Landed_Cost__c FROM Cost_Catalog__c WHERE Id = :cc.Id];
        System.assertEquals(10.00, cc.Landed_Cost__c, 'Landed cost');
        // Salesforce Percent formula fields store the value as the percent number (60.0 = 60%), not fraction
        Decimal expectedGP = (25.00 - 10.00) / 25.00 * 100;
        System.assertEquals(expectedGP.setScale(4), cc.GP_Pct__c.setScale(4), 'GP % formula');
    }
}
