/**
 * HereTrafficSyncService
 * Syncs real-time traffic incidents from the HERE Traffic API
 * into Traffic_Impact__c records, one call per ServiceTerritory bounding box.
 *
 * API endpoint: https://traffic.ls.hereapi.com/traffic/6.1/incidents.json
 * Bbox format (HERE): maxLat, minLng, minLat, maxLng (top-left → bottom-right)
 *
 * Runs every 15 minutes via HereTrafficSyncScheduler.
 * API key is stored in HERE_Settings__mdt (enter via Setup UI — never in code).
 *
 * Impact_Type__c picklist: Delay | Closure | Accident | Congestion | Reroute
 * Severity__c picklist:    Low   | Medium  | High     | Severe
 */
public class HereTrafficSyncService implements Queueable, Database.AllowsCallouts {

    private static final String HERE_BASE_URL =
        'https://traffic.ls.hereapi.com/traffic/6.1/incidents.json';

    // Bounding boxes per territory: [maxLat, minLng, minLat, maxLng]
    @TestVisible
    private static final Map<String, List<Decimal>> TERRITORY_BBOXES =
        new Map<String, List<Decimal>>{
            'Asheville'       => new List<Decimal>{35.75, -82.80, 35.45, -82.35},
            'Cabarrus'        => new List<Decimal>{35.55, -80.85, 35.25, -80.45},
            'Charlotte'       => new List<Decimal>{35.55, -81.00, 35.22, -80.55},
            'Charlotte Metro' => new List<Decimal>{35.65, -81.25, 34.90, -80.40},
            'Charlotte South' => new List<Decimal>{35.22, -81.10, 34.85, -80.65},
            'Columbia'        => new List<Decimal>{34.20, -81.30, 33.90, -80.90},
            'Foothills'       => new List<Decimal>{35.85, -82.30, 35.45, -81.55},
            'Gaston'          => new List<Decimal>{35.40, -81.45, 35.05, -81.05},
            'Greenville'      => new List<Decimal>{34.95, -82.60, 34.70, -82.20},
            'Lake Norman'     => new List<Decimal>{35.75, -81.05, 35.45, -80.60},
            'Midlands SC'     => new List<Decimal>{34.40, -81.55, 33.75, -80.60},
            'Spartanburg'     => new List<Decimal>{35.10, -82.15, 34.85, -81.75},
            'Triad'           => new List<Decimal>{36.30, -80.45, 35.85, -79.55},
            'Triad Metro'     => new List<Decimal>{36.20, -80.30, 35.95, -79.75},
            'Triangle'        => new List<Decimal>{36.15, -79.20, 35.65, -78.40},
            'Triangle Metro'  => new List<Decimal>{36.05, -79.05, 35.75, -78.55},
            'Upstate SC'      => new List<Decimal>{35.20, -82.85, 34.50, -81.55},
            'Western NC'      => new List<Decimal>{36.00, -83.30, 35.20, -82.00},
            'York Lancaster'  => new List<Decimal>{35.15, -81.20, 34.80, -80.75}
        };

    // HERE incident type → Impact_Type__c picklist
    private static final Map<String, String> TYPE_MAP = new Map<String, String>{
        'ACCIDENT'          => 'Accident',
        'CONSTRUCTION'      => 'Delay',
        'ROAD_CLOSURE'      => 'Closure',
        'DISABLED_VEHICLE'  => 'Congestion',
        'WEATHER_CONDITION' => 'Delay',
        'MISC'              => 'Congestion',
        'PLANNED_EVENT'     => 'Delay',
        'MASS_TRANSIT'      => 'Delay'
    };

    // HERE criticality ID → Severity__c picklist
    private static final Map<String, String> SEVERITY_MAP = new Map<String, String>{
        '0' => 'Low',
        '1' => 'Low',
        '2' => 'Medium',
        '3' => 'High',
        '4' => 'Severe'
    };

    // HERE criticality ID → estimated delay in minutes
    private static final Map<String, Integer> DELAY_MAP = new Map<String, Integer>{
        '0' => 0,
        '1' => 5,
        '2' => 15,
        '3' => 30,
        '4' => 60
    };

    // ─── ENTRY POINTS ─────────────────────────────────────────────────────────

    public void execute(QueueableContext ctx) {
        syncAllTerritories();
    }

    public static void syncAllTerritories() {
        String apiKey = getApiKey();
        if (String.isBlank(apiKey)) {
            System.debug(LoggingLevel.WARN,
                'HereTrafficSyncService: No API key found in HERE_Settings__mdt.Default. ' +
                'Add the key via Setup → Custom Metadata Types → HERE Settings → Manage Records.');
            return;
        }

        List<Traffic_Impact__c> toUpsert = new List<Traffic_Impact__c>();
        Set<String> activeHereIds      = new Set<String>();
        Integer calloutCount           = 0;

        for (String territory : TERRITORY_BBOXES.keySet()) {
            if (calloutCount >= 90) break; // buffer under the 100-callout limit
            List<Decimal> bbox = TERRITORY_BBOXES.get(territory);
            try {
                List<Traffic_Impact__c> incidents =
                    fetchAndParseIncidents(apiKey, territory, bbox);
                calloutCount++;
                for (Traffic_Impact__c inc : incidents) {
                    activeHereIds.add(inc.Here_Incident_Id__c);
                    toUpsert.add(inc);
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN,
                    'HereTrafficSyncService: ' + territory + ' — ' + ex.getMessage());
            }
        }

        if (!toUpsert.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(
                toUpsert, Traffic_Impact__c.Fields.Here_Incident_Id__c, false);
            Integer failures = 0;
            for (Database.UpsertResult r : results) {
                if (!r.isSuccess()) {
                    failures++;
                    System.debug(LoggingLevel.WARN,
                        'HereTrafficSyncService upsert error: ' + r.getErrors());
                }
            }
            System.debug('HereTrafficSyncService: upserted ' + (results.size() - failures)
                + '/' + results.size() + ' incidents.');
        }

        // Remove incidents HERE no longer reports (cleared / resolved)
        if (!activeHereIds.isEmpty()) {
            deleteStaleRecords(activeHereIds);
        }
    }

    // ─── HTTP + PARSE ─────────────────────────────────────────────────────────

    private static List<Traffic_Impact__c> fetchAndParseIncidents(
        String apiKey, String territory, List<Decimal> bbox
    ) {
        // bbox: maxLat, minLng, minLat, maxLng
        String bboxParam = bbox[0] + ',' + bbox[1] + ',' + bbox[2] + ',' + bbox[3];
        String endpoint  = HERE_BASE_URL + '?bbox=' + bboxParam
            + '&criticality=0,1,2,3,4'
            + '&apiKey=' + EncodingUtil.urlEncode(apiKey, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new HereApiException(
                'HTTP ' + res.getStatusCode() + ' from HERE API for territory: ' + territory);
        }
        return parseResponse(res.getBody(), territory);
    }

    @TestVisible
    private static List<Traffic_Impact__c> parseResponse(String jsonBody, String territory) {
        List<Traffic_Impact__c> results = new List<Traffic_Impact__c>();
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            Map<String, Object> items = (Map<String, Object>) root.get('TRAFFICITEMS');
            if (items == null) return results;

            Object rawItems = items.get('TRAFFICITEM');
            if (rawItems == null) return results;

            // HERE returns a single Map (not List) when exactly 1 incident
            List<Object> itemList = rawItems instanceof List<Object>
                ? (List<Object>) rawItems
                : new List<Object>{ rawItems };

            for (Object rawItem : itemList) {
                try {
                    Traffic_Impact__c inc =
                        parseIncident((Map<String, Object>) rawItem, territory);
                    if (inc != null) results.add(inc);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.WARN,
                        'HereTrafficSyncService: Skipping malformed incident in '
                        + territory + ': ' + ex.getMessage());
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN,
                'HereTrafficSyncService: JSON parse failure for ' + territory
                + ': ' + ex.getMessage());
        }
        return results;
    }

    private static Traffic_Impact__c parseIncident(
        Map<String, Object> item, String territory
    ) {
        String hereId = safeStr(item.get('TRAFFICITEMID'));
        if (String.isBlank(hereId)) return null;

        // Type mapping
        String hereType  = safeStr(item.get('TRAFFICITEMTYPEDESC')).toUpperCase();
        String impactType = TYPE_MAP.containsKey(hereType)
            ? TYPE_MAP.get(hereType) : 'Congestion';

        // Criticality → severity + delay
        Map<String, Object> crit = (Map<String, Object>) item.get('CRITICALITY');
        String critId  = crit != null ? safeStr(crit.get('ID')) : '0';
        String severity = SEVERITY_MAP.containsKey(critId) ? SEVERITY_MAP.get(critId) : 'Low';
        Integer delay   = DELAY_MAP.containsKey(critId)    ? DELAY_MAP.get(critId)    : 0;

        // Description text
        String descText  = extractDesc(item);
        String roadName  = extractRoad(item);
        String summary   = String.isBlank(roadName)
            ? descText
            : roadName + ' — ' + descText;
        if (String.isBlank(summary)) summary = hereType + ' · ' + territory;
        if (summary.length() > 255) summary = summary.left(255);

        return new Traffic_Impact__c(
            Here_Incident_Id__c = hereId.left(50),
            Territory_Name__c   = territory,
            Impact_Type__c      = impactType,
            Severity__c         = severity,
            Delay_Minutes__c    = delay,
            Summary__c          = summary,
            Source_System__c    = 'HERE',
            Last_Updated__c     = Datetime.now()
        );
    }

    private static String extractDesc(Map<String, Object> item) {
        Object raw = item.get('TRAFFICITEMDESCRIPTION');
        if (raw == null) return '';
        if (raw instanceof List<Object>) {
            List<Object> lst = (List<Object>) raw;
            if (!lst.isEmpty() && lst[0] instanceof Map<String, Object>) {
                return safeStr(((Map<String, Object>) lst[0]).get('value'));
            }
        } else if (raw instanceof Map<String, Object>) {
            return safeStr(((Map<String, Object>) raw).get('value'));
        }
        return '';
    }

    private static String extractRoad(Map<String, Object> item) {
        Map<String, Object> location = (Map<String, Object>) item.get('TRAFFICLOCATION');
        if (location == null) return '';
        Object locDesc = location.get('DESCRIPTION');
        if (locDesc instanceof Map<String, Object>) {
            return safeStr(((Map<String, Object>) locDesc).get('value'));
        }
        return '';
    }

    // ─── STALE CLEANUP ────────────────────────────────────────────────────────

    private static void deleteStaleRecords(Set<String> activeHereIds) {
        List<Traffic_Impact__c> stale = [
            SELECT Id FROM Traffic_Impact__c
            WHERE Source_System__c = 'HERE'
            AND Here_Incident_Id__c NOT IN :activeHereIds
        ];
        if (!stale.isEmpty()) {
            delete stale;
            System.debug('HereTrafficSyncService: deleted ' + stale.size() + ' stale incidents.');
        }
    }

    // ─── HELPERS ──────────────────────────────────────────────────────────────

    private static String getApiKey() {
        List<HERE_Settings__mdt> settings = [
            SELECT API_Key__c FROM HERE_Settings__mdt
            WHERE DeveloperName = 'Default' LIMIT 1
        ];
        return settings.isEmpty() ? null : settings[0].API_Key__c;
    }

    private static String safeStr(Object val) {
        return val == null ? '' : String.valueOf(val).trim();
    }

    public class HereApiException extends Exception {}
}