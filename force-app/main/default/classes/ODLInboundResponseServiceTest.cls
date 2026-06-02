@IsTest
private class ODLInboundResponseServiceTest {

    private static RecordType umbRt() {
        return [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'UMB' LIMIT 1];
    }

    private static RecordType dbRt() {
        return [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Design_Build' LIMIT 1];
    }

    private static Opportunity makeOpp(Id accountId, Id rtId) {
        Opportunity opp = new Opportunity(
            Name = 'Test Stamp Opp',
            StageName = 'Consult Scheduled',
            CloseDate = Date.today().addDays(30),
            AccountId = accountId,
            RecordTypeId = rtId,
            Quote_Status__c = 'Not Sent'
        );
        insert opp;
        return opp;
    }

    @IsTest
    static void testStampFromInboundEmail_stampsDate() {
        Account a = new Account(Name = 'Stamp Test Account');
        insert a;
        Opportunity opp = makeOpp(a.Id, umbRt().Id);

        EmailMessage em = new EmailMessage(
            RelatedToId = opp.Id,
            Subject = 'I got your message',
            MessageDate = Datetime.now().addDays(-1),
            Incoming = true,
            TextBody = 'Looks good, let me know',
            FromAddress = 'customer@test.com',
            ToAddress = 'rep@loving.com'
        );

        Test.startTest();
        ODLInboundResponseService.stampFromEmailMessages(new List<EmailMessage>{ em });
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, result.Last_Customer_Response_Date__c, 'Should have stamped a date');
    }

    @IsTest
    static void testOutboundEmailDoesNotStamp() {
        Account a = new Account(Name = 'No Stamp Account');
        insert a;
        Opportunity opp = makeOpp(a.Id, umbRt().Id);

        EmailMessage em = new EmailMessage(
            RelatedToId = opp.Id,
            Subject = 'Your quote is attached',
            MessageDate = Datetime.now(),
            Incoming = false,
            TextBody = 'Please review',
            FromAddress = 'rep@loving.com',
            ToAddress = 'customer@test.com'
        );

        Test.startTest();
        ODLInboundResponseService.stampFromEmailMessages(new List<EmailMessage>{ em });
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, result.Last_Customer_Response_Date__c, 'Outbound email should NOT stamp');
    }

    @IsTest
    static void testStampFromInboundTask_callType() {
        Account a = new Account(Name = 'Task Stamp Account');
        insert a;
        Opportunity opp = makeOpp(a.Id, umbRt().Id);

        Task t = new Task(
            WhatId = opp.Id,
            Subject = 'Inbound call returned',
            Status = 'Completed',
            ActivityDate = Date.today()
        );
        t.put('CallType', 'Inbound');

        Test.startTest();
        ODLInboundResponseService.stampFromTasks(new List<Task>{ t });
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, result.Last_Customer_Response_Date__c, 'Inbound call task should stamp');
    }

    @IsTest
    static void testOutboundTaskDoesNotStamp() {
        Account a = new Account(Name = 'Outbound Task Account');
        insert a;
        Opportunity opp = makeOpp(a.Id, umbRt().Id);

        Task t = new Task(
            WhatId = opp.Id,
            Subject = 'Called customer',
            Status = 'Completed',
            ActivityDate = Date.today()
        );
        // No inbound CallType, no inbound subject

        Test.startTest();
        ODLInboundResponseService.stampFromTasks(new List<Task>{ t });
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, result.Last_Customer_Response_Date__c, 'Outbound task should NOT stamp');
    }

    @IsTest
    static void testStampDoesNotOverwriteNewerDate() {
        Account a = new Account(Name = 'No Overwrite Account');
        insert a;
        Opportunity opp = makeOpp(a.Id, umbRt().Id);
        opp.Last_Customer_Response_Date__c = Date.today();
        update opp;

        EmailMessage em = new EmailMessage(
            RelatedToId = opp.Id,
            Subject = 'Old email',
            MessageDate = Datetime.now().addDays(-5),
            Incoming = true,
            TextBody = 'Old',
            FromAddress = 'customer@test.com',
            ToAddress = 'rep@loving.com'
        );

        Test.startTest();
        ODLInboundResponseService.stampFromEmailMessages(new List<EmailMessage>{ em });
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(Date.today(), result.Last_Customer_Response_Date__c, 'Should not overwrite newer date');
    }

    @IsTest
    static void testOnlyODLRecordTypesStamped() {
        // Non-ODL opportunity should not be stamped
        List<RecordType> rtList = [SELECT Id FROM RecordType
            WHERE SObjectType = 'Opportunity' AND DeveloperName NOT IN ('UMB', 'Design_Build')
            LIMIT 1];
        if (rtList.isEmpty()) return;
        RecordType lawnRt = rtList[0];

        Account a = new Account(Name = 'Non-ODL Account');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Non-ODL Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30),
            AccountId = a.Id, RecordTypeId = lawnRt.Id
        );
        insert opp;

        EmailMessage em = new EmailMessage(
            RelatedToId = opp.Id,
            Subject = 'Response',
            MessageDate = Datetime.now(),
            Incoming = true,
            TextBody = 'Yes',
            FromAddress = 'customer@test.com',
            ToAddress = 'rep@loving.com'
        );

        Test.startTest();
        ODLInboundResponseService.stampFromEmailMessages(new List<EmailMessage>{ em });
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, result.Last_Customer_Response_Date__c, 'Non-ODL opp should NOT be stamped');
    }

    @IsTest
    static void testStampFromAttendedEvent() {
        Account a = new Account(Name = 'Event Stamp Account');
        insert a;
        Opportunity opp = makeOpp(a.Id, dbRt().Id);

        Event ev = new Event(
            WhatId = opp.Id,
            Subject = 'Discovery Consult Meeting',
            ActivityDateTime = Datetime.now().addDays(-2),
            DurationInMinutes = 60,
            EndDateTime = Datetime.now().addDays(-1)
        );

        Test.startTest();
        ODLInboundResponseService.stampFromEvents(new List<Event>{ ev });
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, result.Last_Customer_Response_Date__c, 'Attended consult event should stamp');
    }
}