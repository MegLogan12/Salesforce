/**
 * Read integration tokens from the Integration_Secret__mdt custom metadata type.
 * Records are managed via Setup > Custom Metadata Types > Integration Secret > Manage Records.
 */
public with sharing class IntegrationSecrets {

    public class Secret {
        public String token;
        public String headerFormat;
    }

    @TestVisible
    private static Map<String, Secret> testOverrides = new Map<String, Secret>();

    public static Secret get(String developerName) {
        if (String.isBlank(developerName)) return new Secret();
        if (Test.isRunningTest() && testOverrides.containsKey(developerName)) {
            return testOverrides.get(developerName);
        }
        List<Integration_Secret__mdt> recs = [
            SELECT Token__c, Header_Format__c
            FROM Integration_Secret__mdt
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        Secret s = new Secret();
        if (recs.isEmpty()) return s;
        s.token        = recs[0].Token__c;
        s.headerFormat = recs[0].Header_Format__c;
        return s;
    }

    public static String authHeader(String developerName) {
        Secret s = get(developerName);
        if (String.isBlank(s.token)) return null;
        if (String.isBlank(s.headerFormat)) return s.token;
        return s.headerFormat + ' ' + s.token;
    }

    public static void applyAuth(HttpRequest req, String developerName) {
        String h = authHeader(developerName);
        if (h != null) req.setHeader('Authorization', h);
    }
}