@isTest
private class LoadReleaseGateTest {

    @isTest
    static void releaseBlockedWhenLinesNotFullyLoaded() {
        Loading_Ticket__c lt = new Loading_Ticket__c(
            Truck_Number__c = 1, Status__c = 'Loading',
            Load_Date__c = Date.today()
        );
        insert lt;

        Product2 p = new Product2(Name = 'Gate Test Item', IsActive = true);
        insert p;

        Loading_Ticket_Line__c line1 = new Loading_Ticket_Line__c(
            Loading_Ticket__c = lt.Id, Product__c = p.Id, Quantity__c = 5, Loaded__c = true
        );
        Loading_Ticket_Line__c line2 = new Loading_Ticket_Line__c(
            Loading_Ticket__c = lt.Id, Product__c = p.Id, Quantity__c = 3, Loaded__c = false
        );
        insert new List<Loading_Ticket_Line__c>{ line1, line2 };

        Test.startTest();
        Boolean threw = false;
        try {
            NightLoadingQueueController.releaseTruck(lt.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw when lines not all loaded');
        Test.stopTest();
    }

    @isTest
    static void releaseSucceedsWhenAllLinesLoaded() {
        Loading_Ticket__c lt = new Loading_Ticket__c(
            Truck_Number__c = 2, Status__c = 'Loading',
            Load_Date__c = Date.today()
        );
        insert lt;

        Product2 p = new Product2(Name = 'Full Load Item', IsActive = true);
        insert p;

        Loading_Ticket_Line__c line = new Loading_Ticket_Line__c(
            Loading_Ticket__c = lt.Id, Product__c = p.Id, Quantity__c = 5, Loaded__c = true
        );
        insert line;

        Test.startTest();
        NightLoadingQueueController.releaseTruck(lt.Id);
        Test.stopTest();

        Loading_Ticket__c updated = [SELECT Status__c FROM Loading_Ticket__c WHERE Id = :lt.Id];
        System.assertEquals('Released', updated.Status__c, 'Status set to Released');
    }

    @isTest
    static void releaseBlockedWithNoLines() {
        Loading_Ticket__c lt = new Loading_Ticket__c(
            Truck_Number__c = 3, Status__c = 'Generated',
            Load_Date__c = Date.today()
        );
        insert lt;

        Test.startTest();
        Boolean threw = false;
        try {
            NightLoadingQueueController.releaseTruck(lt.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw when no lines');
        Test.stopTest();
    }
}
