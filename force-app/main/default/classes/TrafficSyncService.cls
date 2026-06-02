/**
 * Syncs traffic data from OSRM (route timing) and HERE Traffic Incidents API.
 * OSRM: compares actual drive times to estimated, flags crew delays.
 * HERE: fetches live road incidents within today's stop bounding box.
 *
 * Scheduled every 5 minutes via TrafficSyncScheduler.startRealtime().
 */
public with sharing class TrafficSyncService {

    @TestVisible static final String  OSRM_BASE            = 'https://router.project-osrm.org';
    @TestVisible static final String  ROUTE_PATH           = '/route/v1/driving/';
    @TestVisible static final String  SOURCE               = 'OSRM';
    @TestVisible static final String  HERE_BASE            = 'https://data.traffic.hereapi.com';
    @TestVisible static final String  HERE_INCIDENTS_PATH  = '/v7/incidents';
    @TestVisible static final String  HERE_SOURCE          = 'HERE';
    @TestVisible static final Decimal BBOX_BUFFER          = 0.25;

    // Flag as delay when OSRM time exceeds estimated by this many minutes.
    @TestVisible static final Decimal DELAY_THRESHOLD_MIN = 5;

    // ── public entry point ───────────────────────────────────────────────────

    @future(callout=true)
    public static void syncTraffic() {
        try {
            List<Schedule_Day__c> sdays = [
                SELECT Id FROM Schedule_Day__c
                WHERE Schedule_Date__c = :Date.today() LIMIT 1
            ];
            if (sdays.isEmpty()) return;
            Id sdayId = sdays[0].Id;

            // All callouts must precede DML in a future method.
            List<Schedule_Stop__c> stops = [
                SELECT Id, Crew__c, Stop_Number__c,
                       GPS_Latitude__c, GPS_Longitude__c,
                       Estimated_Drive_Time_Minutes__c
                FROM Schedule_Stop__c
                WHERE Schedule_Day__c = :sdayId
                  AND GPS_Latitude__c != null
                  AND GPS_Longitude__c != null
                  AND Crew__c != null
                ORDER BY Crew__c, Stop_Number__c ASC NULLS LAST
            ];

            if (stops.isEmpty()) return;

            // Group by crew for OSRM.
            Map<Id, List<Schedule_Stop__c>> byCrew = new Map<Id, List<Schedule_Stop__c>>();
            for (Schedule_Stop__c s : stops) {
                if (!byCrew.containsKey(s.Crew__c)) {
                    byCrew.put(s.Crew__c, new List<Schedule_Stop__c>());
                }
                byCrew.get(s.Crew__c).add(s);
            }

            // ── OSRM callouts (one per crew) ─────────────────────────────────
            Map<Id, OsrmResult> osrmResults = new Map<Id, OsrmResult>();
            for (Id crewId : byCrew.keySet()) {
                List<Schedule_Stop__c> crewStops = byCrew.get(crewId);
                if (crewStops.size() < 2) continue;
                String coords = buildCoords(crewStops);
                if (String.isBlank(coords)) continue;
                OsrmResult r = callOsrm(coords);
                if (r != null) osrmResults.put(crewId, r);
            }

            // ── HERE callout (single bounding box across all stops) ──────────
            List<HereIncident> hereIncidents = new List<HereIncident>();
            String hereToken = IntegrationSecrets.get(HERE_SOURCE).token;
            if (!String.isBlank(hereToken)) {
                Decimal[] bbox = buildBbox(stops);
                if (bbox != null) {
                    hereIncidents = callHere(bbox, hereToken);
                }
            }

            // ── All callouts done — safe to DML ─────────────────────────────
            delete [SELECT Id FROM Traffic_Impact__c
                    WHERE Schedule_Day__c = :sdayId AND Source_System__c = :SOURCE];
            delete [SELECT Id FROM Traffic_Impact__c
                    WHERE Schedule_Day__c = :sdayId AND Source_System__c = :HERE_SOURCE];
            delete [SELECT Id FROM Route_Optimization_Result__c
                    WHERE Schedule_Day__c = :sdayId];

            List<Traffic_Impact__c>            impacts  = new List<Traffic_Impact__c>();
            List<Route_Optimization_Result__c> opts     = new List<Route_Optimization_Result__c>();
            List<Schedule_Stop__c>             stopUpd  = new List<Schedule_Stop__c>();
            DateTime now = DateTime.now();

            // ── OSRM results → impacts + route optimization ──────────────────
            for (Id crewId : osrmResults.keySet()) {
                OsrmResult osrm = osrmResults.get(crewId);
                List<Schedule_Stop__c> crewStops = byCrew.get(crewId);

                Decimal estimatedTotal = 0;
                for (Schedule_Stop__c s : crewStops) {
                    if (s.Estimated_Drive_Time_Minutes__c != null) {
                        estimatedTotal += s.Estimated_Drive_Time_Minutes__c;
                    }
                }

                Decimal osrmMin  = (osrm.totalDurationSec / 60).setScale(1);
                Decimal delayMin = (osrmMin - estimatedTotal).setScale(1);
                String  risk     = delayToRisk(delayMin);

                if (delayMin > 0) {
                    impacts.add(new Traffic_Impact__c(
                        Crew__c          = crewId,
                        Schedule_Day__c  = sdayId,
                        Delay_Minutes__c = delayMin,
                        Impact_Type__c   = 'Delay',
                        Severity__c      = risk,
                        Source__c        = SOURCE,
                        Source_System__c = SOURCE,
                        Last_Updated__c  = now,
                        Summary__c       = 'OSRM ' + osrmMin + ' min vs estimated '
                                         + estimatedTotal.setScale(1) + ' min'
                    ));
                }

                opts.add(new Route_Optimization_Result__c(
                    Crew__c                         = crewId,
                    Schedule_Day__c                 = sdayId,
                    Previous_Drive_Time_Minutes__c  = estimatedTotal,
                    Optimized_Drive_Time_Minutes__c = osrmMin,
                    Minutes_Saved__c                = (estimatedTotal - osrmMin).setScale(1),
                    Recommendation__c               = buildRecommendation(delayMin, osrmMin, estimatedTotal),
                    Status__c                       = 'Proposed',
                    Optimization_Run_DateTime__c    = now
                ));

                for (Schedule_Stop__c s : crewStops) {
                    stopUpd.add(new Schedule_Stop__c(Id = s.Id, Traffic_Risk__c = risk));
                }
            }

            // ── HERE incidents → impacts ─────────────────────────────────────
            for (HereIncident inc : hereIncidents) {
                impacts.add(new Traffic_Impact__c(
                    Schedule_Day__c  = sdayId,
                    Incident_Id__c   = inc.id,
                    Impact_Type__c   = inc.impactType,
                    Severity__c      = inc.severity,
                    Source__c        = HERE_SOURCE,
                    Source_System__c = HERE_SOURCE,
                    Summary__c       = inc.description,
                    Road__c          = inc.road,
                    Last_Updated__c  = now
                ));
            }

            if (!impacts.isEmpty())  insert impacts;
            if (!opts.isEmpty())     insert opts;
            if (!stopUpd.isEmpty())  update stopUpd;

        } catch (Exception e) {
            writeErrorLog('syncTraffic', e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    // ── OSRM callout ─────────────────────────────────────────────────────────

    @TestVisible
    static OsrmResult callOsrm(String coords) {
        HttpRequest req = new HttpRequest();
        // Semicolons and commas are valid in URL path — no encoding needed.
        req.setEndpoint(OSRM_BASE + ROUTE_PATH + coords + '?steps=false&overview=false');
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(15000);

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                writeErrorLog('callOsrm', 'HTTP ' + res.getStatusCode() + ' for ' + coords);
                return null;
            }
            return parseOsrmResponse(res.getBody());
        } catch (Exception e) {
            writeErrorLog('callOsrm', e.getMessage());
            return null;
        }
    }

    // ── HERE callout ─────────────────────────────────────────────────────────

    @TestVisible
    static List<HereIncident> callHere(Decimal[] bbox, String apiKey) {
        // bbox: [west, south, east, north]
        String bboxParam = bbox[0] + ',' + bbox[1] + ',' + bbox[2] + ',' + bbox[3];
        HttpRequest req = new HttpRequest();
        req.setEndpoint(HERE_BASE + HERE_INCIDENTS_PATH
            + '?in=bbox:' + bboxParam
            + '&apiKey=' + EncodingUtil.urlEncode(apiKey, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(15000);

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                writeErrorLog('callHere', 'HTTP ' + res.getStatusCode());
                return new List<HereIncident>();
            }
            return parseHereResponse(res.getBody());
        } catch (Exception e) {
            writeErrorLog('callHere', e.getMessage());
            return new List<HereIncident>();
        }
    }

    // ── parsing ──────────────────────────────────────────────────────────────

    @TestVisible
    static OsrmResult parseOsrmResponse(String body) {
        if (String.isBlank(body)) return null;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
            if (toStr(root.get('code')) != 'Ok') return null;
            List<Object> routes = (List<Object>) root.get('routes');
            if (routes == null || routes.isEmpty()) return null;
            Map<String, Object> route = (Map<String, Object>) routes[0];
            OsrmResult r = new OsrmResult();
            r.totalDurationSec = toDecimal(route.get('duration'));
            r.totalDistanceM   = toDecimal(route.get('distance'));
            return r;
        } catch (Exception e) {
            writeErrorLog('parseOsrmResponse', e.getMessage());
            return null;
        }
    }

    @TestVisible
    static List<HereIncident> parseHereResponse(String body) {
        List<HereIncident> out = new List<HereIncident>();
        if (String.isBlank(body)) return out;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
            List<Object> results = (List<Object>) root.get('results');
            if (results == null) return out;
            for (Object item : results) {
                Map<String, Object> row = (Map<String, Object>) item;
                Map<String, Object> det = (Map<String, Object>) row.get('incidentDetails');
                if (det == null) continue;
                HereIncident inc = new HereIncident();
                inc.id          = toStr(det.get('id'));
                inc.impactType  = hereTypeToImpact(toStr(det.get('type')));
                inc.severity    = hereCriticalityToSeverity(toStr(det.get('criticality')));
                inc.description = nestedStr(det, 'description');
                inc.road        = nestedStr(det, 'roadName');
                out.add(inc);
            }
        } catch (Exception e) {
            writeErrorLog('parseHereResponse', e.getMessage());
        }
        return out;
    }

    // Extracts the 'value' string from a nested {value: '...'} sub-object.
    private static String nestedStr(Map<String, Object> parent, String key) {
        Object sub = parent.get(key);
        if (sub == null) return '';
        return toStr(((Map<String, Object>) sub).get('value'));
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    @TestVisible
    static String buildCoords(List<Schedule_Stop__c> stops) {
        List<String> parts = new List<String>();
        for (Schedule_Stop__c s : stops) {
            if (s.GPS_Latitude__c == null || s.GPS_Longitude__c == null) continue;
            parts.add(s.GPS_Longitude__c + ',' + s.GPS_Latitude__c);
        }
        return parts.size() >= 2 ? String.join(parts, ';') : null;
    }

    // Returns [west, south, east, north] bounding box + BBOX_BUFFER degrees.
    @TestVisible
    static Decimal[] buildBbox(List<Schedule_Stop__c> stops) {
        Decimal minLat = null, maxLat = null, minLng = null, maxLng = null;
        for (Schedule_Stop__c s : stops) {
            if (s.GPS_Latitude__c == null || s.GPS_Longitude__c == null) continue;
            if (minLat == null || s.GPS_Latitude__c  < minLat) minLat = s.GPS_Latitude__c;
            if (maxLat == null || s.GPS_Latitude__c  > maxLat) maxLat = s.GPS_Latitude__c;
            if (minLng == null || s.GPS_Longitude__c < minLng) minLng = s.GPS_Longitude__c;
            if (maxLng == null || s.GPS_Longitude__c > maxLng) maxLng = s.GPS_Longitude__c;
        }
        if (minLat == null) return null;
        return new Decimal[]{
            (minLng - BBOX_BUFFER).setScale(6),
            (minLat - BBOX_BUFFER).setScale(6),
            (maxLng + BBOX_BUFFER).setScale(6),
            (maxLat + BBOX_BUFFER).setScale(6)
        };
    }

    @TestVisible
    static String hereTypeToImpact(String hereType) {
        if (hereType == null) return 'Delay';
        if (hereType == 'ACCIDENT')          return 'Accident';
        if (hereType == 'ROAD_CLOSURE')      return 'Closure';
        if (hereType == 'CONSTRUCTION'
         || hereType == 'PLANNED_EVENT')     return 'Construction';
        if (hereType == 'ROAD_HAZARD')       return 'Hazard';
        // CONGESTION, DISABLED_VEHICLE, LANE_RESTRICTION and anything else
        return 'Delay';
    }

    @TestVisible
    static String hereCriticalityToSeverity(String criticality) {
        if (criticality == null)         return 'Low';
        if (criticality == 'CRITICAL')   return 'Severe';
        if (criticality == 'MAJOR')      return 'High';
        if (criticality == 'MINOR')      return 'Medium';
        return 'Low';
    }

    @TestVisible
    static String delayToRisk(Decimal delayMin) {
        if (delayMin >= 15) return 'Severe';
        if (delayMin >= 10) return 'High';
        if (delayMin >= 5)  return 'Medium';
        return 'Low';
    }

    static String buildRecommendation(Decimal delayMin, Decimal osrmMin, Decimal estMin) {
        if (delayMin > DELAY_THRESHOLD_MIN) {
            return 'Route is running ~' + delayMin.setScale(0)
                 + ' min behind estimated drive time. Consider adjusting schedule.';
        }
        if (delayMin < -5) {
            return 'Route is ~' + delayMin.abs().setScale(0)
                 + ' min ahead of estimated drive time.';
        }
        return 'Route times within expected range ('
             + osrmMin.setScale(0) + ' min actual vs ' + estMin.setScale(0) + ' min estimated).';
    }

    @TestVisible
    static String toStr(Object o) { return o == null ? null : String.valueOf(o); }

    @TestVisible
    static Decimal toDecimal(Object o) {
        if (o == null) return 0;
        try { return Decimal.valueOf(String.valueOf(o)); } catch (Exception e) { return 0; }
    }

    @TestVisible
    static void writeErrorLog(String method, String message) {
        System.debug(LoggingLevel.ERROR, 'TrafficSyncService.' + method + ': ' + message);
        try {
            insert new Error_Log__c(
                Class_Name__c  = 'TrafficSyncService',
                Method_Name__c = method,
                Message__c     = message,
                Logged_At__c   = DateTime.now()
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'TrafficSyncService: could not write Error_Log__c: ' + e.getMessage());
        }
    }

    public class OsrmResult {
        public Decimal totalDurationSec;
        public Decimal totalDistanceM;
    }

    public class HereIncident {
        public String id;
        public String impactType;
        public String severity;
        public String description;
        public String road;
    }
}