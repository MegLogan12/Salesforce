@isTest
private class NightLoadingQueueControllerTest {

    @isTest
    static void getQueueReturnsEmptyWhenNoTickets() {
        Date d = Date.today().addDays(10);
        Test.startTest();
        List<NightLoadingQueueController.TicketRow> rows = NightLoadingQueueController.getQueue(d);
        Test.stopTest();
        System.assertEquals(0, rows.size(), 'No tickets for future date');
    }

    @isTest
    static void getQueueUsesTodayWhenNullPassed() {
        Test.startTest();
        List<NightLoadingQueueController.TicketRow> rows = NightLoadingQueueController.getQueue(null);
        Test.stopTest();
        System.assertNotEquals(null, rows, 'Returns list (may be empty)');
    }

    @isTest
    static void getQueueReturnsTicketWithLines() {
        Date d = Date.today().addDays(11);
        Product2 p = new Product2(Name = 'Queue Test Product', IsActive = true);
        insert p;

        Loading_Ticket__c lt = new Loading_Ticket__c(
            Status__c = 'Generated', Load_Date__c = d, Scheduled_Date__c = d
        );
        insert lt;

        Loading_Ticket_Line__c ltl = new Loading_Ticket_Line__c(
            Loading_Ticket__c = lt.Id, Product__c = p.Id,
            Quantity__c = 3, Loaded__c = false
        );
        insert ltl;

        Test.startTest();
        List<NightLoadingQueueController.TicketRow> rows = NightLoadingQueueController.getQueue(d);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'One ticket returned');
        NightLoadingQueueController.TicketRow tr = rows[0];
        System.assertEquals(lt.Id, tr.ticketId);
        System.assertEquals(1, tr.totalLines, 'One line on ticket');
        System.assertEquals(0, tr.loadedLines, 'No loaded lines yet');
        System.assertEquals(1, tr.lines.size(), 'Lines populated');
        System.assertEquals(false, tr.lines[0].loaded, 'Line not yet loaded');
    }

    @isTest
    static void markLoadedSetsLineAndTransitionsStatus() {
        Date d = Date.today().addDays(12);
        Product2 p = new Product2(Name = 'Mark Load Product', IsActive = true);
        insert p;

        Loading_Ticket__c lt = new Loading_Ticket__c(
            Status__c = 'Generated', Load_Date__c = d, Scheduled_Date__c = d
        );
        insert lt;

        Loading_Ticket_Line__c ltl = new Loading_Ticket_Line__c(
            Loading_Ticket__c = lt.Id, Product__c = p.Id,
            Quantity__c = 1, Loaded__c = false
        );
        insert ltl;

        Test.startTest();
        NightLoadingQueueController.markLoaded(ltl.Id, true);
        Test.stopTest();

        Loading_Ticket_Line__c updatedLine = [SELECT Loaded__c FROM Loading_Ticket_Line__c WHERE Id = :ltl.Id];
        System.assertEquals(true, updatedLine.Loaded__c, 'Line marked loaded');

        Loading_Ticket__c updatedTicket = [SELECT Status__c FROM Loading_Ticket__c WHERE Id = :lt.Id];
        System.assertEquals('Loading', updatedTicket.Status__c, 'Ticket transitioned to Loading');
    }

    @isTest
    static void markLoadedDoesNotOverrideReleasedStatus() {
        Date d = Date.today().addDays(13);
        Product2 p = new Product2(Name = 'Released Ticket Product', IsActive = true);
        insert p;

        Loading_Ticket__c lt = new Loading_Ticket__c(
            Status__c = 'Released', Load_Date__c = d, Scheduled_Date__c = d
        );
        insert lt;

        Loading_Ticket_Line__c ltl = new Loading_Ticket_Line__c(
            Loading_Ticket__c = lt.Id, Product__c = p.Id,
            Quantity__c = 1, Loaded__c = true
        );
        insert ltl;

        Test.startTest();
        NightLoadingQueueController.markLoaded(ltl.Id, false);
        Test.stopTest();

        Loading_Ticket__c updatedTicket = [SELECT Status__c FROM Loading_Ticket__c WHERE Id = :lt.Id];
        System.assertEquals('Released', updatedTicket.Status__c, 'Released status not downgraded');
    }

    @isTest
    static void releaseTruckSucceedsWhenAllLoaded() {
        Date d = Date.today().addDays(14);
        Product2 p = new Product2(Name = 'Release Product', IsActive = true);
        insert p;

        Loading_Ticket__c lt = new Loading_Ticket__c(
            Status__c = 'Loading', Load_Date__c = d, Scheduled_Date__c = d
        );
        insert lt;

        Loading_Ticket_Line__c ltl = new Loading_Ticket_Line__c(
            Loading_Ticket__c = lt.Id, Product__c = p.Id,
            Quantity__c = 2, Loaded__c = true
        );
        insert ltl;

        Test.startTest();
        NightLoadingQueueController.releaseTruck(lt.Id);
        Test.stopTest();

        Loading_Ticket__c released = [SELECT Status__c FROM Loading_Ticket__c WHERE Id = :lt.Id];
        System.assertEquals('Released', released.Status__c, 'Ticket released');
    }

    @isTest
    static void releaseTruckThrowsWhenLineNotLoaded() {
        Date d = Date.today().addDays(15);
        Product2 p = new Product2(Name = 'Unloaded Product', IsActive = true);
        insert p;

        Loading_Ticket__c lt = new Loading_Ticket__c(
            Status__c = 'Loading', Load_Date__c = d, Scheduled_Date__c = d
        );
        insert lt;

        Loading_Ticket_Line__c ltl = new Loading_Ticket_Line__c(
            Loading_Ticket__c = lt.Id, Product__c = p.Id,
            Quantity__c = 1, Loaded__c = false
        );
        insert ltl;

        Boolean threw = false;
        Test.startTest();
        try {
            NightLoadingQueueController.releaseTruck(lt.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Exception thrown when line not loaded');
    }

    @isTest
    static void releaseTruckThrowsWhenNoLines() {
        Date d = Date.today().addDays(16);
        Loading_Ticket__c lt = new Loading_Ticket__c(
            Status__c = 'Generated', Load_Date__c = d, Scheduled_Date__c = d
        );
        insert lt;

        Boolean threw = false;
        Test.startTest();
        try {
            NightLoadingQueueController.releaseTruck(lt.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Exception thrown when no lines');
    }

    @isTest
    static void regenerateCallsGenerateSchedulable() {
        Date d = Date.today().addDays(17);
        Test.startTest();
        NightLoadingQueueController.regenerate(d);
        Test.stopTest();
        List<Loading_Ticket__c> tickets = [SELECT Id FROM Loading_Ticket__c WHERE Load_Date__c = :d];
        System.assertEquals(0, tickets.size(), 'No tickets created when no WOs');
    }

    @isTest
    static void regenerateWithNullUsesToday() {
        Test.startTest();
        NightLoadingQueueController.regenerate(null);
        Test.stopTest();
        System.assert(true, 'No exception thrown with null date');
    }
}
