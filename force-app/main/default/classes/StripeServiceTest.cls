@IsTest
private class StripeServiceTest {

    // ── Mock HTTP callout ────────────────────────────────────────────────────

    private class StripeMock implements HttpCalloutMock {
        private Integer statusCode;
        private String  body;
        StripeMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    private static final String SESSION_RESPONSE = '{'
        + '"id":"cs_test_abc123",'
        + '"url":"https://checkout.stripe.com/pay/cs_test_abc123",'
        + '"payment_status":"unpaid",'
        + '"status":"open"'
        + '}';

    private static final String PAID_RESPONSE = '{'
        + '"id":"cs_test_abc123",'
        + '"payment_status":"paid",'
        + '"status":"complete"'
        + '}';

    private static final String EXPIRED_RESPONSE = '{'
        + '"id":"cs_test_abc123",'
        + '"payment_status":"unpaid",'
        + '"status":"expired"'
        + '}';

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static void setupMockWorkOrder() {
        StripeService.testWorkOrderData = new Map<String, Object>{
            'WorkOrderNumber'   => 'WO-00001',
            'Invoice_Amount__c' => 150.00
        };
    }

    private static Stripe_Payment__c makePayment(Id workOrderId, String status, String sessionId) {
        Stripe_Payment__c p = new Stripe_Payment__c(
            Work_Order__c          = workOrderId,
            Amount__c              = 150.00,
            Status__c              = status,
            Checkout_Session_Id__c = sessionId,
            Checkout_URL__c        = 'https://checkout.stripe.com/pay/' + sessionId
        );
        insert p;
        return p;
    }

    // ── createCheckoutSession ─────────────────────────────────────────────────

    @IsTest
    static void createCheckoutSession_createsPaymentRecord() {
        StripeService.testSecretKey = 'sk_test_mockkey';
        setupMockWorkOrder();
        Test.setMock(HttpCalloutMock.class, new StripeMock(200, SESSION_RESPONSE));

        Test.startTest();
        Map<String, Object> result = StripeService.createCheckoutSession(null, 150.00, 'Test payment');
        Test.stopTest();

        System.assertEquals('cs_test_abc123', result.get('sessionId'));
        System.assert(((String) result.get('checkoutUrl')).contains('checkout.stripe.com'));

        List<Stripe_Payment__c> payments = [
            SELECT Status__c, Amount__c, Checkout_Session_Id__c FROM Stripe_Payment__c WHERE Checkout_Session_Id__c = 'cs_test_abc123'
        ];
        System.assertEquals(1, payments.size());
        System.assertEquals('Pending',        payments[0].Status__c);
        System.assertEquals(150.00,           payments[0].Amount__c);
        System.assertEquals('cs_test_abc123', payments[0].Checkout_Session_Id__c);
    }

    @IsTest
    static void createCheckoutSession_usesInvoiceAmountWhenNullPassed() {
        StripeService.testSecretKey = 'sk_test_mockkey';
        setupMockWorkOrder();
        Test.setMock(HttpCalloutMock.class, new StripeMock(200, SESSION_RESPONSE));

        Test.startTest();
        StripeService.createCheckoutSession(null, null, null);
        Test.stopTest();

        Stripe_Payment__c payment = [SELECT Amount__c FROM Stripe_Payment__c WHERE Checkout_Session_Id__c = 'cs_test_abc123' LIMIT 1];
        System.assertEquals(150.00, payment.Amount__c);
    }

    @IsTest
    static void createCheckoutSession_throwsOnZeroAmount() {
        StripeService.testSecretKey = 'sk_test_mockkey';
        StripeService.testWorkOrderData = new Map<String, Object>{
            'WorkOrderNumber'   => 'WO-00001',
            'Invoice_Amount__c' => 0
        };
        Test.setMock(HttpCalloutMock.class, new StripeMock(200, SESSION_RESPONSE));

        try {
            Test.startTest();
            StripeService.createCheckoutSession(null, 0, null);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e != null);
        }
    }

    @IsTest
    static void createCheckoutSession_throwsOnStripeError() {
        StripeService.testSecretKey = 'sk_test_mockkey';
        setupMockWorkOrder();
        String errBody = '{"error":{"message":"Your account cannot currently make live charges."}}';
        Test.setMock(HttpCalloutMock.class, new StripeMock(400, errBody));

        try {
            Test.startTest();
            StripeService.createCheckoutSession(null, 50.00, 'fail test');
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e != null);
        }
    }

    // ── refreshPaymentStatus ──────────────────────────────────────────────────

    @IsTest
    static void refreshPaymentStatus_marksComplete() {
        StripeService.testSecretKey = 'sk_test_mockkey';
        Stripe_Payment__c pay = makePayment(null, 'Pending', 'cs_test_abc123');
        Test.setMock(HttpCalloutMock.class, new StripeMock(200, PAID_RESPONSE));

        Test.startTest();
        String status = StripeService.refreshPaymentStatus(pay.Id);
        Test.stopTest();

        System.assertEquals('Complete', status);
        Stripe_Payment__c updated = [SELECT Status__c, Paid_At__c FROM Stripe_Payment__c WHERE Id = :pay.Id];
        System.assertEquals('Complete', updated.Status__c);
        System.assertNotEquals(null, updated.Paid_At__c);
    }

    @IsTest
    static void refreshPaymentStatus_marksExpired() {
        StripeService.testSecretKey = 'sk_test_mockkey';
        Stripe_Payment__c pay = makePayment(null, 'Pending', 'cs_test_abc123');
        Test.setMock(HttpCalloutMock.class, new StripeMock(200, EXPIRED_RESPONSE));

        Test.startTest();
        String status = StripeService.refreshPaymentStatus(pay.Id);
        Test.stopTest();

        System.assertEquals('Expired', status);
    }

    @IsTest
    static void refreshPaymentStatus_shortCircuitsWhenAlreadyComplete() {
        StripeService.testSecretKey = 'sk_test_mockkey';
        Stripe_Payment__c pay = new Stripe_Payment__c(
            Amount__c              = 50.00,
            Status__c              = 'Complete',
            Checkout_Session_Id__c = 'cs_test_abc123',
            Paid_At__c             = DateTime.now()
        );
        insert pay;

        Test.startTest();
        String status = StripeService.refreshPaymentStatus(pay.Id);
        Test.stopTest();

        System.assertEquals('Complete', status);
    }

    // ── getPayments ───────────────────────────────────────────────────────────

    @IsTest
    static void getPayments_returnsEmptyForUnknownWorkOrder() {
        StripeService.testSecretKey = 'sk_test_mockkey';

        Test.startTest();
        List<Stripe_Payment__c> results = StripeService.getPayments(null);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void secretKey_throwsWhenNotConfigured() {
        StripeService.testSecretKey = null;
        try {
            Test.startTest();
            StripeService.secretKey();
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            // AuraHandledException.getMessage() returns 'Script-thrown exception' in test context;
            // confirming the correct exception type was thrown is sufficient.
            System.assert(e != null);
        }
    }
}
