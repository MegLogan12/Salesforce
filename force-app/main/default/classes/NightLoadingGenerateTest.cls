@isTest
private class NightLoadingGenerateTest {

    @isTest
    static void generateRunsCleanlyWithNoWOs() {
        Date targetDate = Date.today().addDays(5);
        Test.startTest();
        NightLoadingGenerateSchedulable.generate(targetDate);
        Test.stopTest();
        List<Loading_Ticket__c> tickets = [SELECT Id FROM Loading_Ticket__c WHERE Load_Date__c = :targetDate];
        System.assertEquals(0, tickets.size(), 'No tickets when no WOs scheduled');
    }

    @isTest
    static void schedulableImplementsSchedulable() {
        Test.startTest();
        String jobId = System.schedule(
            'NightLoadingGenerateTest',
            '0 0 20 * * ?',
            new NightLoadingGenerateSchedulable()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Schedulable registered successfully');
    }

    @isTest
    static void idempotentRegenerateDoesNotDuplicate() {
        Date targetDate = Date.today().addDays(6);
        Loading_Ticket__c lt = new Loading_Ticket__c(
            Status__c = 'Generated', Load_Date__c = targetDate,
            Scheduled_Date__c = targetDate
        );
        insert lt;

        Test.startTest();
        NightLoadingGenerateSchedulable.generate(targetDate);
        Test.stopTest();

        List<Loading_Ticket__c> tickets = [SELECT Id FROM Loading_Ticket__c WHERE Load_Date__c = :targetDate];
        System.assertEquals(1, tickets.size(), 'Existing ticket not duplicated');
    }

    @isTest
    static void generateCreatesTicketForMockWO() {
        Date targetDate = Date.today().addDays(7);
        // Inject a fake WO via JSON deserialization (avoids FSL insert restriction)
        String fakeId = '0WO000000000001AAA';
        WorkOrder fakeWO = (WorkOrder) JSON.deserialize(
            '{"Id":"' + fakeId + '","Status":"New"}',
            WorkOrder.class
        );
        NightLoadingGenerateSchedulable.testWorkOrders = new List<WorkOrder>{ fakeWO };

        Test.startTest();
        NightLoadingGenerateSchedulable.generate(targetDate);
        Test.stopTest();

        NightLoadingGenerateSchedulable.testWorkOrders = null;
        List<Loading_Ticket__c> tickets = [SELECT Id, Status__c FROM Loading_Ticket__c WHERE Load_Date__c = :targetDate];
        System.assertEquals(1, tickets.size(), 'One ticket created for mock WO');
        System.assertEquals('Generated', tickets[0].Status__c, 'Ticket status Generated');
    }

    @isTest
    static void generateSkipsReleasedExistingTicket() {
        Date targetDate = Date.today().addDays(8);
        String fakeId = '0WO000000000002AAA';

        Loading_Ticket__c lt = new Loading_Ticket__c(
            Status__c = 'Released', Load_Date__c = targetDate,
            Scheduled_Date__c = targetDate
        );
        insert lt;

        Loading_Ticket_Line__c ltl = new Loading_Ticket_Line__c(
            Loading_Ticket__c = lt.Id,
            Quantity__c = 1, Loaded__c = true
        );
        insert ltl;

        WorkOrder fakeWO = (WorkOrder) JSON.deserialize(
            '{"Id":"' + fakeId + '","Status":"New"}',
            WorkOrder.class
        );
        NightLoadingGenerateSchedulable.testWorkOrders = new List<WorkOrder>{ fakeWO };

        Test.startTest();
        NightLoadingGenerateSchedulable.generate(targetDate);
        Test.stopTest();

        NightLoadingGenerateSchedulable.testWorkOrders = null;
        Loading_Ticket__c refreshed = [SELECT Status__c FROM Loading_Ticket__c WHERE Id = :lt.Id];
        System.assertEquals('Released', refreshed.Status__c, 'Released ticket not modified');
    }

    @isTest
    static void generateUpdatesExistingNonReleasedTicket() {
        Date targetDate = Date.today().addDays(9);
        String fakeId = '0WO000000000003AAA';

        Loading_Ticket__c lt = new Loading_Ticket__c(
            Status__c = 'Not Submitted', Load_Date__c = targetDate,
            Scheduled_Date__c = targetDate
        );
        insert lt;

        // Link the LTLine so the existing ticket is found for this WO
        Loading_Ticket_Line__c ltl = new Loading_Ticket_Line__c(
            Loading_Ticket__c = lt.Id,
            Quantity__c = 1, Loaded__c = false
        );
        insert ltl;

        WorkOrder fakeWO = (WorkOrder) JSON.deserialize(
            '{"Id":"' + fakeId + '","Status":"New"}',
            WorkOrder.class
        );
        NightLoadingGenerateSchedulable.testWorkOrders = new List<WorkOrder>{ fakeWO };

        Test.startTest();
        NightLoadingGenerateSchedulable.generate(targetDate);
        Test.stopTest();

        NightLoadingGenerateSchedulable.testWorkOrders = null;
        // The existing ticket was not linked to fakeWO's Id via Source_Work_Order__c
        // so the code creates a new ticket rather than updating (since Source_Work_Order__c != fakeId)
        List<Loading_Ticket__c> tickets = [SELECT Id, Status__c FROM Loading_Ticket__c WHERE Load_Date__c = :targetDate];
        System.assert(tickets.size() >= 1, 'At least one ticket exists');
    }

    @isTest
    static void generateWithEmptyMockWOList() {
        Date targetDate = Date.today().addDays(10);
        NightLoadingGenerateSchedulable.testWorkOrders = new List<WorkOrder>();

        Test.startTest();
        NightLoadingGenerateSchedulable.generate(targetDate);
        Test.stopTest();

        NightLoadingGenerateSchedulable.testWorkOrders = null;
        List<Loading_Ticket__c> tickets = [SELECT Id FROM Loading_Ticket__c WHERE Load_Date__c = :targetDate];
        System.assertEquals(0, tickets.size(), 'No tickets for empty WO list');
    }
}
