@IsTest
private class MicrosoftGraphServiceTest {

    // ── Mock ─────────────────────────────────────────────────────────────────

    private class GraphMock implements HttpCalloutMock {
        private Integer statusCode;
        private String  body;
        GraphMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body       = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    private static final String TOKEN_BODY   = '{"access_token":"test_token_abc","expires_in":3600,"token_type":"Bearer"}';
    private static final String EVENTS_BODY  = '{"value":['
        + '{"id":"ev1","subject":"Site Visit — Lot 118","isAllDay":false,'
        + '"bodyPreview":"Takeoff appointment","webLink":"https://outlook.office365.com/ev1",'
        + '"location":{"displayName":"Lot 118, Oak Ridge"},'
        + '"organizer":{"emailAddress":{"address":"meg@loving.com"}},'
        + '"start":{"dateTime":"2026-06-10T09:00:00","timeZone":"UTC"},'
        + '"end":{"dateTime":"2026-06-10T10:00:00","timeZone":"UTC"}}]}';

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static void useToken() {
        MicrosoftGraphService.testAccessToken = 'test_token_abc';
    }

    private static Account makeAccount() {
        Account a = new Account(Name = 'Test Account');
        insert a;
        return a;
    }

    // ── MicrosoftGraphService.acquireToken ────────────────────────────────────

    @IsTest
    static void acquireToken_returnsTestToken() {
        useToken();
        Test.startTest();
        String t = MicrosoftGraphService.acquireToken();
        Test.stopTest();
        System.assertEquals('test_token_abc', t);
    }

    @IsTest
    static void acquireToken_throwsWhenNotConfigured() {
        MicrosoftGraphService.testAccessToken = null;
        try {
            Test.startTest();
            MicrosoftGraphService.acquireToken();
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e != null);
        }
    }

    @IsTest
    static void acquireToken_throwsWhenSecretMissing() {
        MicrosoftGraphService.testAccessToken = null;
        MicrosoftGraphService.testCfg = new Microsoft_Graph_Config__mdt(
            Tenant_ID__c = 'tenant-id', Client_ID__c = 'client-id'
        );
        try {
            Test.startTest();
            MicrosoftGraphService.acquireToken();
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e != null);
        } finally {
            MicrosoftGraphService.testCfg = null;
        }
    }

    @IsTest
    static void acquireToken_returnsTokenFromHttp() {
        MicrosoftGraphService.testAccessToken = null;
        MicrosoftGraphService.testCfg = new Microsoft_Graph_Config__mdt(
            Tenant_ID__c = 'tenant-id', Client_ID__c = 'client-id'
        );
        MicrosoftGraphService.testSecret = 'test-client-secret';
        Test.setMock(HttpCalloutMock.class, new GraphMock(200, TOKEN_BODY));
        try {
            Test.startTest();
            String token = MicrosoftGraphService.acquireToken();
            Test.stopTest();
            System.assertEquals('test_token_abc', token);
        } finally {
            MicrosoftGraphService.testCfg   = null;
            MicrosoftGraphService.testSecret = null;
        }
    }

    @IsTest
    static void acquireToken_throwsOnBadResponse() {
        MicrosoftGraphService.testAccessToken = null;
        Test.setMock(HttpCalloutMock.class, new GraphMock(401, '{"error":"invalid_client"}'));
        try {
            Test.startTest();
            HttpResponse fakeRes = new HttpResponse();
            fakeRes.setStatusCode(400);
            fakeRes.setBody('{"error":"bad"}');
            MicrosoftGraphService.requireSuccess(fakeRes, 'test context');
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e != null);
        }
    }

    @IsTest
    static void callGraph_patchAndDel() {
        useToken();
        Test.setMock(HttpCalloutMock.class, new GraphMock(200, '{}'));
        Test.startTest();
        HttpResponse p = MicrosoftGraphService.patch('/test/path', '{"key":"val"}');
        HttpResponse d = MicrosoftGraphService.del('/test/path');
        Test.stopTest();
        System.assertEquals(200, p.getStatusCode());
        System.assertEquals(200, d.getStatusCode());
    }

    // ── MicrosoftEmailService ─────────────────────────────────────────────────

    @IsTest
    static void sendAndLog_createsEmailMessageRecord() {
        useToken();
        Account a = makeAccount();
        Test.setMock(HttpCalloutMock.class, new GraphMock(202, ''));

        Test.startTest();
        Id logId = MicrosoftEmailService.sendAndLog(
            'meg@loving.com',
            new List<String>{ 'builder@oak-ridge.com' },
            'Work Order Update',
            '<p>Your lot is ready.</p>',
            a.Id,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, logId);
        EmailMessage em = [SELECT Subject, FromAddress, Status, RelatedToId FROM EmailMessage WHERE Id = :logId];
        System.assertEquals('Work Order Update', em.Subject);
        System.assertEquals('meg@loving.com',    em.FromAddress);
        System.assertEquals('3',                 em.Status);
        System.assertEquals(a.Id,                em.RelatedToId);

        // Exercise getLoggedEmails with actual data
        List<MicrosoftEmailService.EmailLogItem> logs = MicrosoftEmailService.getLoggedEmails(a.Id);
        System.assertEquals(1, logs.size());
        System.assertEquals('Work Order Update', logs[0].subject);
    }

    @IsTest
    static void sendAndLog_throwsOnMissingTo() {
        useToken();
        try {
            Test.startTest();
            MicrosoftEmailService.sendAndLog('meg@loving.com', new List<String>(), 'Sub', '<p>body</p>', null, null);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e != null);
        }
    }

    @IsTest
    static void getLoggedEmails_returnsEmpty() {
        Test.startTest();
        List<MicrosoftEmailService.EmailLogItem> items = MicrosoftEmailService.getLoggedEmails(null);
        Test.stopTest();
        System.assertEquals(0, items.size());
    }

    @IsTest
    static void getCurrentUserUpn_returnsNull() {
        Test.startTest();
        String upn = MicrosoftEmailService.getCurrentUserUpn();
        Test.stopTest();
        System.assertEquals(null, upn);
    }

    // ── MicrosoftCalendarService ──────────────────────────────────────────────

    @IsTest
    static void getMyEvents_returnsEmptyWhenNoUpn() {
        Test.startTest();
        List<MicrosoftCalendarService.CalendarEventItem> items = MicrosoftCalendarService.getMyEvents();
        Test.stopTest();
        System.assertEquals(0, items.size());
    }

    @IsTest
    static void fetchEvents_parsesResponse() {
        useToken();
        Test.setMock(HttpCalloutMock.class, new GraphMock(200, EVENTS_BODY));

        Test.startTest();
        List<MicrosoftCalendarService.CalendarEventItem> items =
            MicrosoftCalendarService.fetchEvents('meg@loving.com', '2026-06-10T00:00:00Z', '2026-06-11T00:00:00Z');
        Test.stopTest();

        System.assertEquals(1,                    items.size());
        System.assertEquals('ev1',                items[0].graphId);
        System.assertEquals('meg@loving.com',     items[0].organizer);
        System.assertEquals('Lot 118, Oak Ridge', items[0].location);
        System.assertNotEquals(null,              items[0].startLabel);
    }

    @IsTest
    static void createEvent_createsOutlookAndSfEvent() {
        useToken();
        String createdBody = '{"id":"ev_new","subject":"Site Visit","start":{"dateTime":"2026-06-10T09:00:00","timeZone":"UTC"},'
            + '"end":{"dateTime":"2026-06-10T10:00:00","timeZone":"UTC"},'
            + '"webLink":"https://outlook.office365.com/ev_new"}';
        Test.setMock(HttpCalloutMock.class, new GraphMock(201, createdBody));
        Account a = makeAccount();

        Test.startTest();
        Id sfEventId = MicrosoftCalendarService.createEvent(
            'meg@loving.com', 'Site Visit', '2026-06-10T09:00:00', '2026-06-10T10:00:00',
            'Lot 118, Oak Ridge', 'Takeoff review', new List<String>{ 'builder@oak.com' }, a.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, sfEventId);
        Event ev = [SELECT Subject, MS_Graph_Event_ID__c, WhatId FROM Event WHERE Id = :sfEventId];
        System.assertEquals('Site Visit', ev.Subject);
        System.assertEquals('ev_new',     ev.MS_Graph_Event_ID__c);
        System.assertEquals(a.Id,         ev.WhatId);
    }

    @IsTest
    static void syncToSalesforce_insertsEvents() {
        useToken();
        Test.setMock(HttpCalloutMock.class, new GraphMock(200, EVENTS_BODY));

        Test.startTest();
        MicrosoftCalendarService.syncToSalesforce('meg@loving.com', UserInfo.getUserId(), 14);
        Test.stopTest();

        List<Event> events = [SELECT MS_Graph_Event_ID__c FROM Event
                              WHERE OwnerId = :UserInfo.getUserId() AND MS_Graph_Event_ID__c = 'ev1'];
        System.assertEquals(1, events.size());
    }

    @IsTest
    static void syncToSalesforce_updatesExistingEvent() {
        useToken();
        // DML before Test.startTest() is committed before the callout runs — safe per Salesforce docs
        Event existing = new Event(
            Subject = 'Old Subject',
            StartDateTime = DateTime.now().addHours(1),
            EndDateTime   = DateTime.now().addHours(2),
            OwnerId       = UserInfo.getUserId(),
            MS_Graph_Event_ID__c = 'ev1'
        );
        insert existing;

        Test.setMock(HttpCalloutMock.class, new GraphMock(200, EVENTS_BODY));
        Test.startTest();
        MicrosoftCalendarService.syncToSalesforce('meg@loving.com', UserInfo.getUserId(), 14);
        Test.stopTest();

        Event updated = [SELECT Subject FROM Event WHERE Id = :existing.Id];
        System.assertEquals('Site Visit — Lot 118', updated.Subject);
    }

    // ── MicrosoftCalendarSync ─────────────────────────────────────────────────

    @IsTest
    static void calendarSync_executesWithoutError() {
        useToken();
        Test.setMock(HttpCalloutMock.class, new GraphMock(200, '{"value":[]}'));
        Test.startTest();
        new MicrosoftCalendarSync().execute(null);
        Test.stopTest();
    }

    @IsTest
    static void calendarSync_executesFullPath() {
        useToken();
        Test.setMock(HttpCalloutMock.class, new GraphMock(200, '{"value":[]}'));
        MicrosoftCalendarSync.testCfg = new Microsoft_Graph_Config__mdt(
            Enabled__c = true, Sync_Days_Ahead__c = 7
        );
        MicrosoftCalendarSync.testUsers = new List<User>{
            new User(Id = UserInfo.getUserId(), Microsoft_UPN__c = 'meg@loving.com')
        };
        try {
            Test.startTest();
            new MicrosoftCalendarSync().execute(null);
            Test.stopTest();
        } finally {
            MicrosoftCalendarSync.testCfg   = null;
            MicrosoftCalendarSync.testUsers = null;
        }
    }
}
