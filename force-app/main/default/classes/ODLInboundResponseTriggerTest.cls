@IsTest
private class ODLInboundResponseTriggerTest {

    private static RecordType umbRt() {
        return [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'UMB' LIMIT 1];
    }

    private static Opportunity makeOpp() {
        Account a = new Account(Name = 'Trigger Coverage Account');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Trigger Coverage Opp',
            StageName = 'Consult Scheduled',
            CloseDate = Date.today().addDays(30),
            AccountId = a.Id,
            RecordTypeId = umbRt().Id,
            Quote_Status__c = 'Not Sent'
        );
        insert opp;
        return opp;
    }

    @IsTest
    static void testEmailMessageTrigger_fires() {
        Opportunity opp = makeOpp();

        Test.startTest();
        EmailMessage em = new EmailMessage(
            RelatedToId = opp.Id,
            Subject = 'Customer reply',
            MessageDate = Datetime.now(),
            Incoming = true,
            TextBody = 'Yes, proceed',
            FromAddress = 'customer@test.com',
            ToAddress = 'rep@loving.com'
        );
        insert em;
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, result.Last_Customer_Response_Date__c,
            'EmailMessage trigger should stamp Last_Customer_Response_Date__c');
    }

    @IsTest
    static void testTaskTrigger_fires_on_insert() {
        Opportunity opp = makeOpp();

        Test.startTest();
        Task t = new Task(
            WhatId = opp.Id,
            Subject = 'Customer called back',
            Status = 'Completed',
            ActivityDate = Date.today()
        );
        t.put('CallType', 'Inbound');
        insert t;
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, result.Last_Customer_Response_Date__c,
            'Task trigger (insert) should stamp Last_Customer_Response_Date__c');
    }

    @IsTest
    static void testTaskTrigger_fires_on_update() {
        Opportunity opp = makeOpp();

        Task t = new Task(
            WhatId = opp.Id,
            Subject = 'Customer called back',
            Status = 'Not Started',
            ActivityDate = Date.today()
        );
        t.put('CallType', 'Inbound');
        insert t;

        Test.startTest();
        t.Status = 'Completed';
        update t;
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, result.Last_Customer_Response_Date__c,
            'Task trigger (update to Completed) should stamp Last_Customer_Response_Date__c');
    }

    @IsTest
    static void testEventTrigger_fires_on_insert() {
        Opportunity opp = makeOpp();

        Test.startTest();
        Datetime evStart = Datetime.now().addDays(-1);
        Event ev = new Event(
            WhatId = opp.Id,
            Subject = 'Discovery Consult',
            ActivityDateTime = evStart,
            DurationInMinutes = 60,
            EndDateTime = evStart.addMinutes(60)
        );
        insert ev;
        Test.stopTest();

        Opportunity result = [SELECT Last_Customer_Response_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, result.Last_Customer_Response_Date__c,
            'Event trigger (insert) should stamp Last_Customer_Response_Date__c');
    }
}
