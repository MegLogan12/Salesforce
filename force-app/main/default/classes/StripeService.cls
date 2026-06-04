public with sharing class StripeService {

    private static final String BASE = 'https://api.stripe.com';
    private static final String ORG_URL = URL.getOrgDomainUrl().toExternalForm();

    @TestVisible private static String testSecretKey;
    @TestVisible private static Map<String, Object> testWorkOrderData;

    @TestVisible private static String secretKey() {
        if (testSecretKey != null) { return testSecretKey; }
        Stripe_Settings__c s = Stripe_Settings__c.getInstance();
        if (s == null || String.isBlank(s.Secret_Key__c)) {
            throw new AuraHandledException('Stripe secret key not configured. Go to Setup → Custom Settings → Stripe Settings → Manage and enter your secret key.');
        }
        return s.Secret_Key__c;
    }

    // ── Create a Checkout Session and persist a Stripe_Payment__c record ──────

    @AuraEnabled
    public static Map<String, Object> createCheckoutSession(Id workOrderId, Decimal amount, String description) {
        String woNumber;
        Decimal invoiceAmount;
        if (testWorkOrderData != null) {
            woNumber      = (String)  testWorkOrderData.get('WorkOrderNumber');
            invoiceAmount = (Decimal) testWorkOrderData.get('Invoice_Amount__c');
        } else {
            WorkOrder wo = [SELECT WorkOrderNumber, Invoice_Amount__c FROM WorkOrder WHERE Id = :workOrderId LIMIT 1];
            woNumber      = wo.WorkOrderNumber;
            invoiceAmount = wo.Invoice_Amount__c;
        }

        if (amount == null || amount <= 0) {
            amount = invoiceAmount != null ? invoiceAmount : 0;
        }
        if (amount <= 0) {
            throw new AuraHandledException('Amount must be greater than zero.');
        }

        Long amountCents = (amount * 100).longValue();
        String productName = String.isBlank(description) ? ('Work Order ' + woNumber) : description;

        String body = 'mode=payment'
            + '&line_items[0][quantity]=1'
            + '&line_items[0][price_data][currency]=usd'
            + '&line_items[0][price_data][unit_amount]=' + amountCents
            + '&line_items[0][price_data][product_data][name]=' + EncodingUtil.urlEncode(productName, 'UTF-8')
            + '&success_url=' + EncodingUtil.urlEncode(ORG_URL + '/lightning/r/WorkOrder/' + workOrderId + '/view?payment=success', 'UTF-8')
            + '&cancel_url='  + EncodingUtil.urlEncode(ORG_URL + '/lightning/r/WorkOrder/' + workOrderId + '/view?payment=cancel',  'UTF-8')
            + '&metadata[work_order_id]=' + workOrderId
            + '&expires_at=' + (DateTime.now().addHours(24).getTime() / 1000);

        HttpResponse res = callStripe('POST', '/v1/checkout/sessions', body);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        if (res.getStatusCode() != 200) {
            Map<String, Object> err = (Map<String, Object>) parsed.get('error');
            throw new AuraHandledException('Stripe error: ' + (err != null ? (String) err.get('message') : res.getBody()));
        }

        String sessionId  = (String) parsed.get('id');
        String sessionUrl = (String) parsed.get('url');

        Stripe_Payment__c payment = new Stripe_Payment__c(
            Work_Order__c          = workOrderId,
            Amount__c              = amount,
            Status__c              = 'Pending',
            Checkout_Session_Id__c = sessionId,
            Checkout_URL__c        = sessionUrl
        );
        insert payment;

        return new Map<String, Object>{
            'paymentId'  => payment.Id,
            'sessionId'  => sessionId,
            'checkoutUrl'=> sessionUrl,
            'amount'     => amount
        };
    }

    // ── Refresh status of an existing payment ─────────────────────────────────

    @AuraEnabled
    public static String refreshPaymentStatus(Id paymentRecordId) {
        Stripe_Payment__c payment = [
            SELECT Checkout_Session_Id__c, Status__c
            FROM Stripe_Payment__c
            WHERE Id = :paymentRecordId
            LIMIT 1
        ];

        if (payment.Status__c == 'Complete') { return 'Complete'; }

        HttpResponse res = callStripe('GET', '/v1/checkout/sessions/' + payment.Checkout_Session_Id__c, null);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Could not retrieve Stripe status.');
        }

        Map<String, Object> parsed    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String paymentStatus = (String) parsed.get('payment_status');
        String sessionStatus = (String) parsed.get('status');

        String newStatus;
        DateTime paidAt;
        if (paymentStatus == 'paid') {
            newStatus = 'Complete';
            paidAt    = DateTime.now();
        } else if (sessionStatus == 'expired') {
            newStatus = 'Expired';
        } else {
            newStatus = 'Pending';
        }

        payment.Status__c = newStatus;
        if (paidAt != null) { payment.Paid_At__c = paidAt; }
        update payment;

        return newStatus;
    }

    // ── List payments for a work order ────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Stripe_Payment__c> getPayments(Id workOrderId) {
        return [
            SELECT Id, Name, Amount__c, Status__c, Checkout_URL__c, Paid_At__c, CreatedDate
            FROM Stripe_Payment__c
            WHERE Work_Order__c = :workOrderId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
    }

    // ── HTTP helper ───────────────────────────────────────────────────────────

    private static HttpResponse callStripe(String method, String path, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE + path);
        req.setMethod(method);
        req.setHeader('Authorization', 'Bearer ' + secretKey());
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setTimeout(15000);
        if (body != null) { req.setBody(body); }
        return new Http().send(req);
    }
}
