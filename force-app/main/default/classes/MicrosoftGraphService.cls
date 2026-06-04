public with sharing class MicrosoftGraphService {

    private static final String TOKEN_URL  = 'https://login.microsoftonline.com/{0}/oauth2/v2.0/token';
    private static final String GRAPH_BASE = 'https://graph.microsoft.com/v1.0';

    @TestVisible private static String testAccessToken;

    // ── Config ────────────────────────────────────────────────────────────────

    public static Microsoft_Graph_Config__mdt getConfig() {
        List<Microsoft_Graph_Config__mdt> rows = [
            SELECT Tenant_ID__c, Client_ID__c, Service_Account_Email__c,
                   Sync_Days_Ahead__c, Enabled__c
            FROM   Microsoft_Graph_Config__mdt
            WHERE  DeveloperName = 'Default'
            LIMIT  1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    @TestVisible
    static String getSecret() {
        Microsoft_Graph_Secrets__c s = Microsoft_Graph_Secrets__c.getInstance();
        return s?.Client_Secret__c;
    }

    // ── Token acquisition (OAuth 2.0 client credentials) ─────────────────────

    @TestVisible
    static String acquireToken() {
        if (testAccessToken != null) { return testAccessToken; }

        Microsoft_Graph_Config__mdt cfg = getConfig();
        String secret = getSecret();

        if (cfg == null || String.isBlank(cfg.Tenant_ID__c) || String.isBlank(cfg.Client_ID__c)) {
            throw new AuraHandledException(
                'Microsoft Graph is not configured. Go to Setup → Custom Metadata Types → '
                + 'Microsoft Graph Config → Manage Records → Default and fill in Tenant ID and Client ID.'
            );
        }
        if (String.isBlank(secret)) {
            throw new AuraHandledException(
                'Microsoft Graph client secret is missing. Go to Setup → Custom Settings → '
                + 'Microsoft Graph Secrets → Manage and enter the Client Secret.'
            );
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(String.format(TOKEN_URL, new List<String>{ cfg.Tenant_ID__c }));
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(
            'grant_type=client_credentials'
            + '&client_id='     + EncodingUtil.urlEncode(cfg.Client_ID__c, 'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(secret, 'UTF-8')
            + '&scope='         + EncodingUtil.urlEncode('https://graph.microsoft.com/.default', 'UTF-8')
        );
        req.setTimeout(15000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Microsoft authentication failed: ' + res.getBody());
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) parsed.get('access_token');
    }

    // ── HTTP helpers ──────────────────────────────────────────────────────────

    public static HttpResponse callGraph(String method, String path, String body) {
        String token = acquireToken();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(GRAPH_BASE + path);
        req.setMethod(method);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type',  'application/json');
        req.setTimeout(20000);
        if (body != null) { req.setBody(body); }
        return new Http().send(req);
    }

    // Convenience wrappers
    public static HttpResponse get(String path)                     { return callGraph('GET',    path, null); }
    public static HttpResponse post(String path, String body)       { return callGraph('POST',   path, body); }
    public static HttpResponse patch(String path, String body)      { return callGraph('PATCH',  path, body); }
    public static HttpResponse del(String path)                     { return callGraph('DELETE', path, null); }

    // Require 2xx or throw
    public static void requireSuccess(HttpResponse res, String context) {
        Integer code = res.getStatusCode();
        if (code < 200 || code >= 300) {
            throw new AuraHandledException(context + ': ' + res.getBody());
        }
    }

    // URL-encode a Microsoft UPN for use in a path segment
    public static String encodeUpn(String upn) {
        return EncodingUtil.urlEncode(upn, 'UTF-8');
    }
}
