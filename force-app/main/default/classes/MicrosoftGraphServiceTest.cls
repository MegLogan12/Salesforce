/**
 * Tests for MicrosoftGraphService + MicrosoftGraphFlowActions.
 * Uses HttpCalloutMock — no real Graph traffic.
 */
@IsTest
private class MicrosoftGraphServiceTest {

    // --------- Mocks ---------
    private class SendMailOk implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().contains('/sendMail'), 'wrong endpoint');
            System.assertEquals('POST', req.getMethod());
            HttpResponse r = new HttpResponse();
            r.setStatusCode(202);
            r.setStatus('Accepted');
            r.setBody('');
            return r;
        }
    }
    private class SendMailFail implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(403);
            r.setStatus('Forbidden');
            r.setBody('{"error":{"code":"Forbidden","message":"no consent"}}');
            return r;
        }
    }
    private class CreateEventOk implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().contains('/calendar/events'), 'wrong endpoint');
            HttpResponse r = new HttpResponse();
            r.setStatusCode(201);
            r.setStatus('Created');
            r.setBody('{"id":"AAMkAGI2TG93","subject":"Site Readiness"}');
            return r;
        }
    }
    private class PingOk implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('{"value":[]}');
            return r;
        }
    }

    // --------- Tests ---------

    @IsTest
    static void sendMail_success_returns202() {
        Test.setMock(HttpCalloutMock.class, new SendMailOk());
        Test.startTest();
        Integer code = MicrosoftGraphService.sendMail(
            'megan.logan@thelovingcompanies.com',
            new List<String>{'dispatch@example.com'},
            'T-48 Site Readiness',
            '<p>Loading ticket ready.</p>'
        );
        Test.stopTest();
        System.assertEquals(202, code);
    }

    @IsTest
    static void sendMail_failure_throws() {
        Test.setMock(HttpCalloutMock.class, new SendMailFail());
        Boolean threw = false;
        Test.startTest();
        try {
            MicrosoftGraphService.sendMail(
                'bad@thelovingcompanies.com',
                new List<String>{'x@example.com'},
                'x', 'x'
            );
        } catch (MicrosoftGraphService.MicrosoftGraphException e) {
            threw = true;
            System.assert(e.getMessage().contains('403'));
        }
        Test.stopTest();
        System.assert(threw);
    }

    @IsTest
    static void sendMail_blankFrom_throws() {
        Boolean threw = false;
        try {
            MicrosoftGraphService.sendMail('', new List<String>{'a@b.com'}, 's', 'b');
        } catch (MicrosoftGraphService.MicrosoftGraphException e) {
            threw = true;
        }
        System.assert(threw);
    }

    @IsTest
    static void sendMail_emptyTo_throws() {
        Boolean threw = false;
        try {
            MicrosoftGraphService.sendMail('a@b.com', new List<String>(), 's', 'b');
        } catch (MicrosoftGraphService.MicrosoftGraphException e) {
            threw = true;
        }
        System.assert(threw);
    }

    @IsTest
    static void createEvent_success_returnsId() {
        Test.setMock(HttpCalloutMock.class, new CreateEventOk());
        Test.startTest();
        String id = MicrosoftGraphService.createEvent(
            'megan.logan@thelovingcompanies.com',
            'T-48 Site Readiness',
            '<p>Confirm water/power on site.</p>',
            Datetime.newInstanceGmt(2026, 5, 1, 14, 0, 0),
            Datetime.newInstanceGmt(2026, 5, 1, 15, 0, 0),
            new List<String>{'dispatch@example.com'},
            '309 Morningside Rd'
        );
        Test.stopTest();
        System.assertEquals('AAMkAGI2TG93', id);
    }

    @IsTest
    static void ping_returnsTrueOn200() {
        Test.setMock(HttpCalloutMock.class, new PingOk());
        System.assert(MicrosoftGraphService.ping());
    }

    @IsTest
    static void flowAction_sendEmail_buildsOutput() {
        Test.setMock(HttpCalloutMock.class, new SendMailOk());
        MicrosoftGraphFlowActions.SendEmailInput i = new MicrosoftGraphFlowActions.SendEmailInput();
        i.fromUpn = 'megan.logan@thelovingcompanies.com';
        i.toEmails = 'a@b.com;c@d.com';
        i.subject = 'hi';
        i.htmlBody = '<p>hi</p>';
        Test.startTest();
        List<MicrosoftGraphFlowActions.SendEmailOutput> outs =
            MicrosoftGraphFlowActions.sendEmails(new List<MicrosoftGraphFlowActions.SendEmailInput>{i});
        Test.stopTest();
        System.assertEquals(1, outs.size());
        System.assert(outs[0].success);
        System.assertEquals(202, outs[0].statusCode);
    }

    @IsTest
    static void flowAction_createEvent_buildsOutput() {
        Test.setMock(HttpCalloutMock.class, new CreateEventOk());
        MicrosoftGraphFlowCalendar.CreateEventInput i = new MicrosoftGraphFlowCalendar.CreateEventInput();
        i.ownerUpn = 'megan.logan@thelovingcompanies.com';
        i.subject = 'x';
        i.bodyHtml = '<p>x</p>';
        i.startUtc = Datetime.newInstanceGmt(2026,5,1,14,0,0);
        i.endUtc   = Datetime.newInstanceGmt(2026,5,1,15,0,0);
        i.attendeesCsv = 'a@b.com; c@d.com';
        i.location = '309 Morningside Rd';
        Test.startTest();
        List<MicrosoftGraphFlowCalendar.CreateEventOutput> outs =
            MicrosoftGraphFlowCalendar.createEvents(new List<MicrosoftGraphFlowCalendar.CreateEventInput>{i});
        Test.stopTest();
        System.assert(outs[0].success);
        System.assertEquals('AAMkAGI2TG93', outs[0].eventId);
    }

    private class CreateEventFail implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(500);
            r.setStatus('Server Error');
            r.setBody('{"error":{"code":"InternalServerError"}}');
            return r;
        }
    }

    @IsTest
    static void flowAction_createEvent_errorPathReturnsErrorMessage() {
        Test.setMock(HttpCalloutMock.class, new CreateEventFail());
        MicrosoftGraphFlowCalendar.CreateEventInput i = new MicrosoftGraphFlowCalendar.CreateEventInput();
        i.ownerUpn = 'megan.logan@thelovingcompanies.com';
        i.subject = 'x';
        i.startUtc = Datetime.newInstanceGmt(2026,5,1,14,0,0);
        i.endUtc   = Datetime.newInstanceGmt(2026,5,1,15,0,0);
        Test.startTest();
        List<MicrosoftGraphFlowCalendar.CreateEventOutput> outs =
            MicrosoftGraphFlowCalendar.createEvents(new List<MicrosoftGraphFlowCalendar.CreateEventInput>{i});
        Test.stopTest();
        System.assertEquals(false, outs[0].success);
        System.assert(outs[0].errorMessage != null && outs[0].errorMessage.contains('500'));
    }

    @IsTest
    static void flowAction_sendEmail_errorPathReturnsErrorMessage() {
        Test.setMock(HttpCalloutMock.class, new SendMailFail());
        MicrosoftGraphFlowActions.SendEmailInput i = new MicrosoftGraphFlowActions.SendEmailInput();
        i.fromUpn = 'megan.logan@thelovingcompanies.com';
        i.toEmails = 'a@b.com';
        i.subject = 'x';
        i.htmlBody = '<p>x</p>';
        Test.startTest();
        List<MicrosoftGraphFlowActions.SendEmailOutput> outs =
            MicrosoftGraphFlowActions.sendEmails(new List<MicrosoftGraphFlowActions.SendEmailInput>{i});
        Test.stopTest();
        System.assertEquals(false, outs[0].success);
        System.assert(outs[0].errorMessage != null);
    }
}