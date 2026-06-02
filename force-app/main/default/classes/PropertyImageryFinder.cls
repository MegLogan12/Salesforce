/**
 * PropertyImageryFinder
 * Finds a property's backyard from PUBLIC data when the customer has not uploaded a photo:
 *   1. Geocode the address with the US Census geocoder (free, no key).
 *   2. Pull a top-down aerial of the lot from Esri World Imagery (free, no key).
 *   3. Save it as a File on the Opportunity so the design pipeline can draw on it.
 *
 * Honest limits: this sources the aerial of the actual lot. It cannot find a private
 * ground-level backyard photo, a recorded survey, or drone imagery (none are public).
 * Can be upgraded to Google Maps (paid, cheap) by swapping the aerial source.
 */
public with sharing class PropertyImageryFinder {

    private static final String CENSUS_BASE =
        'https://geocoding.geo.census.gov/geocoder/locations/onelineaddress';
    private static final String ESRI_EXPORT =
        'https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/export';

    @AuraEnabled
    public static void findAndAttachAerial(Id opportunityId) {
        if (opportunityId == null) throw new AuraHandledException('No opportunity provided.');
        System.enqueueJob(new FindAerialJob(opportunityId));
    }

    @InvocableMethod(label='Find Property Aerial' description='Finds a public aerial of the property and saves it on the Opportunity.')
    public static void findFromFlow(List<Id> opportunityIds) {
        for (Id oppId : opportunityIds) System.enqueueJob(new FindAerialJob(oppId));
    }

    public class FindAerialJob implements Queueable, Database.AllowsCallouts {
        private Id opportunityId;
        public FindAerialJob(Id opportunityId) { this.opportunityId = opportunityId; }
        public void execute(QueueableContext ctx) {
            try {
                String address = addressFor(opportunityId);
                if (String.isBlank(address)) {
                    System.debug(LoggingLevel.WARN, 'No address available for opportunity ' + opportunityId);
                    return;
                }
                Map<String, Decimal> coords = geocode(address);
                if (coords == null) {
                    System.debug(LoggingLevel.WARN, 'Census geocoder returned no match for: ' + address);
                    return;
                }
                Blob aerial = fetchAerial(coords.get('lat'), coords.get('lng'));
                if (aerial != null) {
                    saveAerial(opportunityId, address, aerial);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Aerial finder failed: ' + e.getMessage());
            }
        }
    }

    // ── Address assembly ─────────────────────────────────────────────────────────

    @TestVisible
    private static String addressFor(Id opportunityId) {
        List<Opportunity> opps = [
            SELECT Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode,
                   Homeowner_Property__r.Name
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];
        if (opps.isEmpty()) return null;
        Opportunity o = opps[0];
        if (o.Account != null && String.isNotBlank(o.Account.BillingStreet)) {
            return String.join(new List<String>{
                o.Account.BillingStreet,
                o.Account.BillingCity,
                o.Account.BillingState,
                o.Account.BillingPostalCode
            }, ', ').replaceAll(', ,', ',');
        }
        if (o.Homeowner_Property__r != null) return o.Homeowner_Property__r.Name;
        return null;
    }

    // ── Census geocoder (free, no key) ───────────────────────────────────────────

    @TestVisible
    private static Map<String, Decimal> geocode(String address) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(CENSUS_BASE + '?address=' + EncodingUtil.urlEncode(address, 'UTF-8') +
                        '&benchmark=Public_AR_Current&format=json');
        req.setMethod('GET');
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) return null;
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> result = (Map<String, Object>) root.get('result');
        if (result == null) return null;
        List<Object> matches = (List<Object>) result.get('addressMatches');
        if (matches == null || matches.isEmpty()) return null;
        Map<String, Object> coords = (Map<String, Object>) ((Map<String, Object>) matches[0]).get('coordinates');
        if (coords == null) return null;
        return new Map<String, Decimal>{
            'lng' => (Decimal) coords.get('x'),
            'lat' => (Decimal) coords.get('y')
        };
    }

    // ── Esri World Imagery aerial (free, no key) ─────────────────────────────────

    @TestVisible
    private static Blob fetchAerial(Decimal lat, Decimal lng) {
        // ~90m box around the point — tight enough to frame a single residential lot.
        Decimal dLat = 0.0004;
        Decimal dLng = 0.0005;
        String bbox = (lng - dLng) + ',' + (lat - dLat) + ',' + (lng + dLng) + ',' + (lat + dLat);
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ESRI_EXPORT + '?bbox=' + bbox +
                        '&bboxSR=4326&imageSR=4326&size=640,640&format=jpg&transparent=false&f=image');
        req.setMethod('GET');
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) return null;
        return res.getBodyAsBlob();
    }

    // ── Save the aerial as a File on the Opportunity ─────────────────────────────

    @TestVisible
    private static Id saveAerial(Id opportunityId, String address, Blob aerial) {
        ContentVersion cv = new ContentVersion(
            Title = 'Aerial View - ' + address,
            PathOnClient = 'aerial_view.jpg',
            VersionData = aerial,
            FirstPublishLocationId = opportunityId
        );
        insert cv;
        return cv.Id;
    }
}