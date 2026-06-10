/**
 * Test coverage for TrafficSyncService and TrafficSyncScheduler.
 */
@IsTest(seeAllData=false)
private class TrafficSyncServiceTest {

    // ── HTTP mocks ────────────────────────────────────────────────────────────

    private class OsrmMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            // 30-minute route (1800 sec), 25 km.
            res.setBody(JSON.serialize(new Map<String, Object>{
                'code'   => 'Ok',
                'routes' => new List<Object>{
                    new Map<String, Object>{ 'duration' => 1800, 'distance' => 25000 }
                }
            }));
            return res;
        }
    }

    private class OsrmErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    // Routes to OSRM mock or HERE mock based on endpoint.
    private class MultiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('traffic.hereapi.com')) {
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, Object>{
                            'incidentDetails' => new Map<String, Object>{
                                'id'          => 'here-inc-001',
                                'type'        => 'ACCIDENT',
                                'criticality' => 'CRITICAL',
                                'description' => new Map<String, Object>{ 'value' => 'Major accident I-85 NB' },
                                'roadName'    => new Map<String, Object>{ 'value' => 'I-85' }
                            }
                        }
                    }
                }));
            } else {
                // OSRM: 30-minute route.
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'code'   => 'Ok',
                    'routes' => new List<Object>{
                        new Map<String, Object>{ 'duration' => 1800, 'distance' => 25000 }
                    }
                }));
            }
            return res;
        }
    }

    // ── setup helpers ─────────────────────────────────────────────────────────

    static Schedule_Day__c makeSchedDay() {
        Schedule_Day__c sd = new Schedule_Day__c(Schedule_Date__c = Date.today());
        insert sd;
        return sd;
    }

    static List<Schedule_Stop__c> makeTwoStops(Id sdayId, Id crewId) {
        List<Schedule_Stop__c> stops = new List<Schedule_Stop__c>{
            new Schedule_Stop__c(
                Schedule_Day__c=sdayId, Crew__c=crewId, Stop_Number__c=1,
                GPS_Latitude__c=35.2271, GPS_Longitude__c=-80.8431,
                Estimated_Drive_Time_Minutes__c=5
            ),
            new Schedule_Stop__c(
                Schedule_Day__c=sdayId, Crew__c=crewId, Stop_Number__c=2,
                GPS_Latitude__c=35.2400, GPS_Longitude__c=-80.8600,
                Estimated_Drive_Time_Minutes__c=5
            )
        };
        insert stops;
        return stops;
    }

    // ── OSRM tests ────────────────────────────────────────────────────────────

    @IsTest
    static void syncTraffic_createsImpactAndOptResult() {
        Schedule_Day__c sd = makeSchedDay();
        Crew__c crew = new Crew__c(Name = 'Test Crew');
        insert crew;

        // Estimated total = 10 min. OSRM returns 30 min → delay 20 → Severe.
        makeTwoStops(sd.Id, crew.Id);

        Test.setMock(HttpCalloutMock.class, new OsrmMock());
        Test.startTest();
        TrafficSyncService.syncTraffic();
        Test.stopTest();

        List<Traffic_Impact__c> impacts = [
            SELECT Id, Delay_Minutes__c, Severity__c FROM Traffic_Impact__c
            WHERE Crew__c = :crew.Id
        ];
        System.assertEquals(1, impacts.size(), 'One Traffic_Impact__c should be created');
        System.assertEquals('Severe', impacts[0].Severity__c, 'Delay of 20 min should be Severe');

        List<Route_Optimization_Result__c> opts = [
            SELECT Previous_Drive_Time_Minutes__c, Optimized_Drive_Time_Minutes__c, Minutes_Saved__c
            FROM Route_Optimization_Result__c WHERE Crew__c = :crew.Id
        ];
        System.assertEquals(1, opts.size());
        System.assertEquals(10, opts[0].Previous_Drive_Time_Minutes__c);
        System.assertEquals(30, opts[0].Optimized_Drive_Time_Minutes__c);
        System.assertEquals(-20, opts[0].Minutes_Saved__c);

        List<Schedule_Stop__c> stops = [SELECT Traffic_Risk__c FROM Schedule_Stop__c
                                         WHERE Crew__c = :crew.Id AND Schedule_Day__c = :sd.Id];
        for (Schedule_Stop__c s : stops) {
            System.assertEquals('Severe', s.Traffic_Risk__c);
        }
    }

    @IsTest
    static void syncTraffic_noDelay_noImpactRecord() {
        Schedule_Day__c sd = makeSchedDay();
        Crew__c crew = new Crew__c(Name = 'Fast Crew');
        insert crew;

        // Estimated = 40 min, OSRM = 30 min → no delay → no Traffic_Impact__c.
        insert new List<Schedule_Stop__c>{
            new Schedule_Stop__c(
                Schedule_Day__c=sd.Id, Crew__c=crew.Id, Stop_Number__c=1,
                GPS_Latitude__c=35.2271, GPS_Longitude__c=-80.8431,
                Estimated_Drive_Time_Minutes__c=20
            ),
            new Schedule_Stop__c(
                Schedule_Day__c=sd.Id, Crew__c=crew.Id, Stop_Number__c=2,
                GPS_Latitude__c=35.2400, GPS_Longitude__c=-80.8600,
                Estimated_Drive_Time_Minutes__c=20
            )
        };

        Test.setMock(HttpCalloutMock.class, new OsrmMock());
        Test.startTest();
        TrafficSyncService.syncTraffic();
        Test.stopTest();

        List<Traffic_Impact__c> impacts = [SELECT Id FROM Traffic_Impact__c WHERE Crew__c = :crew.Id];
        System.assertEquals(0, impacts.size(), 'No Traffic_Impact__c when route is ahead of schedule');
    }

    @IsTest
    static void syncTraffic_osrmError_writesErrorLog() {
        Schedule_Day__c sd = makeSchedDay();
        Crew__c crew = new Crew__c(Name = 'Error Crew');
        insert crew;

        makeTwoStops(sd.Id, crew.Id);

        Test.setMock(HttpCalloutMock.class, new OsrmErrorMock());
        Test.startTest();
        TrafficSyncService.syncTraffic();
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Id FROM Error_Log__c WHERE Class_Name__c = 'TrafficSyncService'];
        System.assertEquals(1, logs.size());
    }

    @IsTest
    static void syncTraffic_noScheduleDay_runsClean() {
        Test.setMock(HttpCalloutMock.class, new OsrmMock());
        Test.startTest();
        TrafficSyncService.syncTraffic();
        Test.stopTest();
    }

    @IsTest
    static void syncTraffic_singleStopPerCrew_skipped() {
        Schedule_Day__c sd = makeSchedDay();
        Crew__c crew = new Crew__c(Name = 'Solo Crew');
        insert crew;
        insert new Schedule_Stop__c(
            Schedule_Day__c=sd.Id, Crew__c=crew.Id, Stop_Number__c=1,
            GPS_Latitude__c=35.22, GPS_Longitude__c=-80.84, Estimated_Drive_Time_Minutes__c=5
        );

        Test.setMock(HttpCalloutMock.class, new OsrmMock());
        Test.startTest();
        TrafficSyncService.syncTraffic();
        Test.stopTest();

        List<Traffic_Impact__c> impacts = [SELECT Id FROM Traffic_Impact__c WHERE Crew__c = :crew.Id];
        System.assertEquals(0, impacts.size());
    }

    // ── HERE tests ────────────────────────────────────────────────────────────

    @IsTest
    static void syncTraffic_withHere_createsHereImpacts() {
        Schedule_Day__c sd = makeSchedDay();
        Crew__c crew = new Crew__c(Name = 'HERE Crew');
        insert crew;
        makeTwoStops(sd.Id, crew.Id);

        // Inject HERE token via testOverrides so the HERE branch is exercised.
        IntegrationSecrets.Secret hereSecret = new IntegrationSecrets.Secret();
        hereSecret.token = 'test-here-api-key';
        IntegrationSecrets.testOverrides.put('HERE', hereSecret);

        Test.setMock(HttpCalloutMock.class, new MultiMock());
        Test.startTest();
        TrafficSyncService.syncTraffic();
        Test.stopTest();

        List<Traffic_Impact__c> hereImpacts = [
            SELECT Id, Incident_Id__c, Impact_Type__c, Severity__c, Road__c, Source_System__c
            FROM Traffic_Impact__c
            WHERE Source_System__c = 'HERE' AND Schedule_Day__c = :sd.Id
        ];
        System.assertEquals(1, hereImpacts.size(), 'One HERE incident should be created');
        System.assertEquals('here-inc-001', hereImpacts[0].Incident_Id__c);
        System.assertEquals('Accident',     hereImpacts[0].Impact_Type__c);
        System.assertEquals('Severe',       hereImpacts[0].Severity__c);
        System.assertEquals('I-85',         hereImpacts[0].Road__c);
    }

    @IsTest
    static void syncTraffic_hereTokenBlank_skipsHere() {
        Schedule_Day__c sd = makeSchedDay();
        Crew__c crew = new Crew__c(Name = 'No HERE Crew');
        insert crew;
        makeTwoStops(sd.Id, crew.Id);

        // No HERE token → HERE branch should be skipped, only one OSRM callout.
        Test.setMock(HttpCalloutMock.class, new OsrmMock());
        Test.startTest();
        TrafficSyncService.syncTraffic();
        Test.stopTest();

        List<Traffic_Impact__c> hereImpacts = [
            SELECT Id FROM Traffic_Impact__c
            WHERE Source_System__c = 'HERE' AND Schedule_Day__c = :sd.Id
        ];
        System.assertEquals(0, hereImpacts.size(), 'No HERE impacts when token is blank');
    }

    @IsTest
    static void parseHereResponse_parsesIncidents() {
        String body = JSON.serialize(new Map<String, Object>{
            'results' => new List<Object>{
                new Map<String, Object>{
                    'incidentDetails' => new Map<String, Object>{
                        'id'          => 'inc-abc',
                        'type'        => 'ROAD_CLOSURE',
                        'criticality' => 'MAJOR',
                        'description' => new Map<String, Object>{ 'value' => 'Road closed' },
                        'roadName'    => new Map<String, Object>{ 'value' => 'Hwy 74' }
                    }
                }
            }
        });
        List<TrafficSyncService.HereIncident> incidents = TrafficSyncService.parseHereResponse(body);
        System.assertEquals(1,         incidents.size());
        System.assertEquals('inc-abc', incidents[0].id);
        System.assertEquals('Closure', incidents[0].impactType);
        System.assertEquals('High',    incidents[0].severity);
        System.assertEquals('Hwy 74',  incidents[0].road);
    }

    @IsTest
    static void parseHereResponse_emptyResults_returnsEmpty() {
        String body = JSON.serialize(new Map<String, Object>{ 'results' => new List<Object>() });
        System.assertEquals(0, TrafficSyncService.parseHereResponse(body).size());
    }

    @IsTest
    static void parseHereResponse_blankBody_returnsEmpty() {
        System.assertEquals(0, TrafficSyncService.parseHereResponse('').size());
        System.assertEquals(0, TrafficSyncService.parseHereResponse(null).size());
    }

    @IsTest
    static void buildBbox_correctWithBuffer() {
        List<Schedule_Stop__c> stops = new List<Schedule_Stop__c>{
            new Schedule_Stop__c(GPS_Latitude__c = 35.22, GPS_Longitude__c = -80.84),
            new Schedule_Stop__c(GPS_Latitude__c = 35.30, GPS_Longitude__c = -80.70)
        };
        Decimal[] bbox = TrafficSyncService.buildBbox(stops);
        System.assertNotEquals(null, bbox);
        System.assertEquals(4, bbox.size());
        // west = -80.84 - 0.25
        System.assertEquals(-81.090000, bbox[0]);
        // south = 35.22 - 0.25
        System.assertEquals(34.970000, bbox[1]);
        // east = -80.70 + 0.25
        System.assertEquals(-80.450000, bbox[2]);
        // north = 35.30 + 0.25
        System.assertEquals(35.550000, bbox[3]);
    }

    @IsTest
    static void buildBbox_allNullGps_returnsNull() {
        List<Schedule_Stop__c> stops = new List<Schedule_Stop__c>{
            new Schedule_Stop__c(GPS_Latitude__c = null, GPS_Longitude__c = null)
        };
        System.assertEquals(null, TrafficSyncService.buildBbox(stops));
    }

    @IsTest
    static void hereTypeToImpact_allTypes() {
        System.assertEquals('Accident',     TrafficSyncService.hereTypeToImpact('ACCIDENT'));
        System.assertEquals('Closure',      TrafficSyncService.hereTypeToImpact('ROAD_CLOSURE'));
        System.assertEquals('Construction', TrafficSyncService.hereTypeToImpact('CONSTRUCTION'));
        System.assertEquals('Construction', TrafficSyncService.hereTypeToImpact('PLANNED_EVENT'));
        System.assertEquals('Hazard',       TrafficSyncService.hereTypeToImpact('ROAD_HAZARD'));
        System.assertEquals('Delay',        TrafficSyncService.hereTypeToImpact('CONGESTION'));
        System.assertEquals('Delay',        TrafficSyncService.hereTypeToImpact('LANE_RESTRICTION'));
        System.assertEquals('Delay',        TrafficSyncService.hereTypeToImpact(null));
    }

    @IsTest
    static void hereCriticalityToSeverity_allLevels() {
        System.assertEquals('Severe', TrafficSyncService.hereCriticalityToSeverity('CRITICAL'));
        System.assertEquals('High',   TrafficSyncService.hereCriticalityToSeverity('MAJOR'));
        System.assertEquals('Medium', TrafficSyncService.hereCriticalityToSeverity('MINOR'));
        System.assertEquals('Low',    TrafficSyncService.hereCriticalityToSeverity('LOW_IMPACT'));
        System.assertEquals('Low',    TrafficSyncService.hereCriticalityToSeverity(null));
    }

    // ── shared helper tests ───────────────────────────────────────────────────

    @IsTest
    static void buildCoords_filtersNullGps() {
        List<Schedule_Stop__c> stops = new List<Schedule_Stop__c>{
            new Schedule_Stop__c(GPS_Latitude__c = 35.22, GPS_Longitude__c = -80.84),
            new Schedule_Stop__c(GPS_Latitude__c = null,  GPS_Longitude__c = -80.85),
            new Schedule_Stop__c(GPS_Latitude__c = 35.24, GPS_Longitude__c = -80.86)
        };
        String coords = TrafficSyncService.buildCoords(stops);
        System.assert(coords.contains(';'), 'Coords should have semicolon separator');
        System.assertEquals(2, coords.split(';').size(), 'Null-GPS stop should be excluded');
    }

    @IsTest
    static void delayToRisk_allBrackets() {
        System.assertEquals('Low',    TrafficSyncService.delayToRisk(0));
        System.assertEquals('Low',    TrafficSyncService.delayToRisk(4));
        System.assertEquals('Medium', TrafficSyncService.delayToRisk(5));
        System.assertEquals('Medium', TrafficSyncService.delayToRisk(9));
        System.assertEquals('High',   TrafficSyncService.delayToRisk(10));
        System.assertEquals('High',   TrafficSyncService.delayToRisk(14));
        System.assertEquals('Severe', TrafficSyncService.delayToRisk(15));
        System.assertEquals('Severe', TrafficSyncService.delayToRisk(60));
    }

    @IsTest
    static void parseOsrmResponse_invalidCode_returnsNull() {
        String body = JSON.serialize(new Map<String, Object>{
            'code' => 'NoRoute', 'message' => 'Could not find route'
        });
        TrafficSyncService.OsrmResult r = TrafficSyncService.parseOsrmResponse(body);
        System.assertEquals(null, r, 'Non-Ok OSRM code should return null');
    }

    // ── scheduler tests ───────────────────────────────────────────────────────

    @IsTest
    static void scheduler_executesAndReschedules() {
        makeSchedDay();
        Test.setMock(HttpCalloutMock.class, new OsrmMock());
        Test.startTest();
        new TrafficSyncScheduler().execute(null);
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :TrafficSyncScheduler.JOB_PREFIX + '%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ];
        System.assert(!jobs.isEmpty(), 'Scheduler should self-reschedule after execute()');
    }

    @IsTest
    static void scheduler_startRealtimeAndStop() {
        Test.startTest();
        TrafficSyncScheduler.startRealtime();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :TrafficSyncScheduler.JOB_PREFIX + '%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ];
        System.assert(!jobs.isEmpty(), 'startRealtime should register at least one job');

        TrafficSyncScheduler.stopRealtime();
        List<CronTrigger> afterStop = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :TrafficSyncScheduler.JOB_PREFIX + '%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ];
        System.assertEquals(0, afterStop.size(), 'stopRealtime should abort all Traffic Sync jobs');
    }

    @IsTest
    static void scheduler_scheduleHalfHourlyAlias_registersJob() {
        // scheduleHalfHourly() is now an alias for startRealtime().
        Test.startTest();
        TrafficSyncScheduler.scheduleHalfHourly();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :TrafficSyncScheduler.JOB_PREFIX + '%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ];
        System.assert(!jobs.isEmpty(), 'scheduleHalfHourly alias should register a Traffic Sync job');

        TrafficSyncScheduler.unschedule();
    }
}