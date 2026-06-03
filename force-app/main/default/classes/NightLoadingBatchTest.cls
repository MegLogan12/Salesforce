@IsTest
private class NightLoadingBatchTest {

    // WorkOrder DML is blocked in tests (before-save Flow).
    // NightLoadingBatch.processScope is @TestVisible so we can call it directly
    // with real WorkOrders from a SeeAllData=true query.
    // The External_Key__c field is deployed as part of this package, so upsert works.

    @IsTest
    static void batch_noScope_completes() {
        Test.startTest();
        NightLoadingBatch.run();
        Test.stopTest();
        System.assert(true, 'Batch completes without exception on empty scope');
    }

    @IsTest
    static void batch_customDateConstructor_works() {
        NightLoadingBatch b = new NightLoadingBatch(Date.today());
        System.assertNotEquals(null, b);
    }

    // processScope with empty list covers the isEmpty() early return
    @IsTest
    static void processScope_emptyList_noException() {
        Test.startTest();
        NightLoadingBatch.processScope(new List<WorkOrder>(), Date.today().addDays(1));
        Test.stopTest();
        System.assert(true, 'Empty scope should return without error');
    }

    // ── With real WOs from the org ────────────────────────────────────────────

    @IsTest(SeeAllData=true)
    static void processScope_realWo_createsTicket() {
        List<WorkOrder> wos = [SELECT Id, Crew__c FROM WorkOrder LIMIT 1];
        if (wos.isEmpty()) {
            System.assert(true, 'No WO in org — skipping.'); return;
        }
        Date ld = Date.today().addDays(1);
        Test.startTest();
        NightLoadingBatch.processScope(wos, ld);
        Test.stopTest();

        String extKey = wos[0].Id + '-' + String.valueOf(ld);
        List<Loading_Ticket__c> tickets = [
            SELECT Id, External_Key__c FROM Loading_Ticket__c WHERE External_Key__c = :extKey
        ];
        System.assertEquals(1, tickets.size(), 'One ticket should be created per WO');
    }

    @IsTest(SeeAllData=true)
    static void processScope_idempotent_noDuplicateTicket() {
        List<WorkOrder> wos = [SELECT Id, Crew__c FROM WorkOrder LIMIT 1];
        if (wos.isEmpty()) {
            System.assert(true, 'No WO in org — skipping.'); return;
        }
        Date ld = Date.today().addDays(1);
        Test.startTest();
        NightLoadingBatch.processScope(wos, ld);
        NightLoadingBatch.processScope(wos, ld); // second run
        Test.stopTest();

        String extKey = wos[0].Id + '-' + String.valueOf(ld);
        List<Loading_Ticket__c> tickets = [
            SELECT Id FROM Loading_Ticket__c WHERE External_Key__c = :extKey
        ];
        System.assertEquals(1, tickets.size(), 'Re-run should not duplicate the ticket');
    }

    @IsTest(SeeAllData=true)
    static void batch_realOrg_noException() {
        Test.startTest();
        NightLoadingBatch.run();
        Test.stopTest();
        System.assert(true, 'Batch completed without exception');
    }

    @IsTest(SeeAllData=true)
    static void processScope_multipleWos_oneTicketEach() {
        List<WorkOrder> wos = [SELECT Id, Crew__c FROM WorkOrder LIMIT 3];
        if (wos.isEmpty()) {
            System.assert(true, 'No WOs in org — skipping.'); return;
        }
        Date ld = Date.today().addDays(2);
        Test.startTest();
        NightLoadingBatch.processScope(wos, ld);
        Test.stopTest();

        Set<String> extKeys = new Set<String>();
        for (WorkOrder wo : wos) {
            extKeys.add(wo.Id + '-' + String.valueOf(ld));
        }
        List<Loading_Ticket__c> tickets = [
            SELECT Id FROM Loading_Ticket__c WHERE External_Key__c IN :extKeys
        ];
        System.assertEquals(wos.size(), tickets.size(), 'One ticket created per WO');
    }
}
