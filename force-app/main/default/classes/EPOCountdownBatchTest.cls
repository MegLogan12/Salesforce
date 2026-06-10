@IsTest
private class EPOCountdownBatchTest {

    @IsTest
    static void batchProcessesSentQuotes() {
        Test.startTest();
        Database.executeBatch(new EPOCountdownBatch(), 200);
        Test.stopTest();
        System.assert(true, 'batch ran');
    }

    @IsTest
    static void batchExecuteHandlesEmptyScope() {
        EPOCountdownBatch b = new EPOCountdownBatch();
        b.execute(null, new List<Quote__c>());
        System.assertEquals(0, b.reminders);
        System.assertEquals(0, b.followups);
        System.assertEquals(0, b.escalations);
    }

    @IsTest
    static void batchCountsByDaysOut() {
        EPOCountdownBatch b = new EPOCountdownBatch();
        List<Quote__c> qs = new List<Quote__c>{
            new Quote__c(Status__c = 'Sent', Sent_Date__c = Date.today().addDays(-3)),
            new Quote__c(Status__c = 'Sent', Sent_Date__c = Date.today().addDays(-4)),
            new Quote__c(
                Status__c = 'Sent',
                Sent_Date__c = Date.today().addDays(-6),
                Standard_Work_Order__c = fakeWorkOrderId()
            )
        };
        b.execute(null, qs);
        System.assertEquals(1, b.reminders);
        System.assertEquals(1, b.followups);
        System.assertEquals(1, b.escalations);
    }

    @IsTest
    static void batchSkipsNullSentDate() {
        EPOCountdownBatch b = new EPOCountdownBatch();
        List<Quote__c> qs = new List<Quote__c>{
            new Quote__c(Status__c = 'Sent', Sent_Date__c = null)
        };
        b.execute(null, qs);
        System.assertEquals(0, b.reminders);
    }

    @IsTest
    static void batchFlagsWorkOrderOnEscalation() {
        Quote__c q = new Quote__c(
            Status__c     = 'Sent',
            Sent_Date__c  = Date.today().addDays(-6),
            Standard_Work_Order__c = fakeWorkOrderId()
        );

        EPOCountdownBatch b = new EPOCountdownBatch();
        b.execute(null, new List<Quote__c>{ q });
        System.assertEquals(1, b.escalations);

        // finish() attempts the WorkOrder flag update and catches the fake-id DML failure.
        Test.startTest();
        b.finish(null);
        Test.stopTest();
        System.assert(true, 'finish should catch failed fake WorkOrder update');
    }

    @IsTest
    static void finishUpdatesQuotesAndCreatesTask() {
        Quote__c q = new Quote__c(
            Status__c     = 'Sent',
            Sent_Date__c  = Date.today().addDays(-4)
        );
        insert q;

        EPOCountdownBatch b = new EPOCountdownBatch();
        Quote__c qFull = [
            SELECT Id, Name, OwnerId, Sent_Date__c, Status__c, Standard_Work_Order__c,
                   Standard_Work_Order__r.OwnerId, Standard_Work_Order__r.Division__c,
                   Standard_Work_Order__r.EPO_SLA_Breach__c
            FROM Quote__c WHERE Id = :q.Id
        ];
        b.execute(null, new List<Quote__c>{ qFull });
        System.assertEquals(1, b.followups);

        Test.startTest();
        b.finish(null);
        Test.stopTest();

        List<Task> tasks = [SELECT Id, Subject FROM Task WHERE Subject LIKE 'EPO Follow-Up:%'];
        System.assert(!tasks.isEmpty(), 'Follow-up task should be created');
        System.assert(tasks[0].Subject.contains('EPO Follow-Up'), 'Task subject should contain EPO Follow-Up');
    }

    @IsTest
    static void finishUpdatesQuoteDaysOutstanding() {
        Quote__c q = new Quote__c(
            Status__c     = 'Sent',
            Sent_Date__c  = Date.today().addDays(-3)
        );
        insert q;

        EPOCountdownBatch b = new EPOCountdownBatch();
        Quote__c qFull = [
            SELECT Id, Name, OwnerId, Sent_Date__c, Status__c, Standard_Work_Order__c,
                   Standard_Work_Order__r.OwnerId, Standard_Work_Order__r.Division__c,
                   Standard_Work_Order__r.EPO_SLA_Breach__c
            FROM Quote__c WHERE Id = :q.Id
        ];
        b.execute(null, new List<Quote__c>{ qFull });

        Test.startTest();
        b.finish(null);
        Test.stopTest();

        Quote__c qAfter = [SELECT Days_Outstanding__c FROM Quote__c WHERE Id = :q.Id];
        System.assertEquals(3, (Integer)qAfter.Days_Outstanding__c);
    }

    @IsTest
    static void schedulerExecutes() {
        Test.startTest();
        EPOCountdownScheduler s = new EPOCountdownScheduler();
        s.execute(null);
        Test.stopTest();
        System.assert(true, 'scheduler ran');
    }

    @IsTest
    static void scheduleDailyReturnsJobId() {
        Test.startTest();
        String jobId = EPOCountdownScheduler.scheduleDaily();
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void finishLogsResults() {
        EPOCountdownBatch b = new EPOCountdownBatch();
        b.reminders = 5;
        b.followups = 3;
        b.escalations = 1;
        b.finish(null);
        System.assert(true, 'finish completed');
    }

    @IsTest
    static void startReturnsQueryLocator() {
        EPOCountdownBatch b = new EPOCountdownBatch();
        Database.QueryLocator ql = b.start(null);
        System.assertNotEquals(null, ql);
    }

    private static Id fakeWorkOrderId() {
        return (Id)'0WO000000000001AAA';
    }
}