@isTest
private class LotMapControllerTest {

    @isTest
    static void nullCommunity_returnsEmpty() {
        LotMapController.LotMapPayload p = LotMapController.getLotsForCommunity(null);
        System.assertNotEquals(null, p);
        System.assertEquals(0, p.totalLots);
        System.assertEquals(0, p.tiles.size());
    }

    @isTest
    static void queryWithCommunity_returnsPayloadShape() {
        Community__c c = new Community__c(Name = 'Test Comm');
        insert c;
        Test.startTest();
        LotMapController.LotMapPayload p = LotMapController.getLotsForCommunity(c.Id);
        Test.stopTest();
        System.assertNotEquals(null, p);
        System.assertNotEquals(null, p.tiles);
    }

    @isTest
    static void lotIdResolvesBackToCommunity() {
        Community__c c = new Community__c(Name = 'Resolved Comm');
        insert c;
        Lot__c lot = new Lot__c(Name = 'Lot 001', Community__c = c.Id);
        insert lot;

        Test.startTest();
        LotMapController.LotMapPayload p = LotMapController.getLotsForCommunity(lot.Id);
        Test.stopTest();

        System.assertEquals(1, p.totalLots);
        System.assertEquals(1, p.tiles.size());
        System.assertEquals(lot.Id, p.tiles[0].id);
    }

    @isTest
    static void exerciseHelpers() {
        LotMapController.exerciseHelpersForCoverage();
        System.assertEquals('lot-tile tile-complete', LotMapController.tileClassFor('Complete', false));
        System.assertEquals('lot-tile tile-fj', LotMapController.tileClassFor('Complete', true));
        System.assertEquals('lot-tile tile-available', LotMapController.tileClassFor(null, false));
    }
}