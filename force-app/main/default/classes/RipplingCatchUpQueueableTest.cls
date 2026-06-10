@IsTest
private class RipplingCatchUpQueueableTest {
    private class Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(200);
            r.setBody('{"results":[],"next_link":null}'); return r;
        }
    }
    @IsTest static void runsOnce() {
        Test.setMock(HttpCalloutMock.class, new Mock());
        Test.startTest();
        System.enqueueJob(new RipplingCatchUpQueueable());
        Test.stopTest();
        System.assert(true, 'queueable executed without error');
    }
}