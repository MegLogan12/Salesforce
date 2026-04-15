/**
 * @description Lightweight Tooling API client for dependency and metadata lookups.
 */
public with sharing class ToolingApiClient {
    public static final String NAMED_CREDENTIAL = 'FieldUsage_Tooling';

    /**
     * @description Runs a Tooling API query and returns the records list as untyped maps.
     * @param soql The Tooling API SOQL query.
     * @return List of untyped record maps.
     */
    public static List<Object> query(String soql) {
        if (String.isBlank(soql)) {
            return new List<Object>();
        }
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        String endpoint = 'callout:' + NAMED_CREDENTIAL + '/services/data/v60.0/tooling/query/?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8');
        req.setEndpoint(endpoint);
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('Tooling API error: ' + res.getStatus() + ' - ' + res.getBody());
        }
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object records = payload.get('records');
        return records == null ? new List<Object>() : (List<Object>) records;
    }
}
