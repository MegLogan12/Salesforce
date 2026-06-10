/**
 * Test coverage for GpsInsightsSyncService + GpsInsightsSyncScheduler.
 */
@IsTest(seeAllData=false)
private class GpsInsightsSyncServiceTest {

    private class GpsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String url = req.getEndpoint();
            if (url.contains('/v1/vehicles')) {
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, Object>{
                            'id' => 'veh-001',
                            'vin' => '1FTFW1ET5DFC12345',
                            'license_plate' => 'ABC-123',
                            'make' => 'Ford',
                            'model' => 'F-150',
                            'year' => 2022,
                            'odometer_miles' => 42150.5,
                            'status' => 'active'
                        }
                    }
                }));
                return res;
            }
            if (url.contains('/v1/locations/latest')) {
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, Object>{
                            'id' => 'loc-001',
                            'vehicle_id' => 'veh-001',
                            'latitude' => 35.7796,
                            'longitude' => -78.6382,
                            'address' => '123 Main St, Raleigh NC',
                            'timestamp' => DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
                            'speed_mph' => 32.4,
                            'ignition_on' => true,
                            'odometer_miles' => 42160.0
                        }
                    }
                }));
                return res;
            }
            res.setStatusCode(404);
            res.setBody('{}');
            return res;
        }
    }

    @IsTest
    static void syncVehicles_upsertsVehicle() {
        Test.setMock(HttpCalloutMock.class, new GpsMock());
        Test.startTest();
        GpsInsightsSyncService.syncVehicles();
        Test.stopTest();

        List<Vehicle__c> vs = [SELECT Id, GPS_Insights_Id__c, Make__c, Model__c, Year__c FROM Vehicle__c];
        System.assertEquals(1, vs.size());
        System.assertEquals('veh-001', vs[0].GPS_Insights_Id__c);
        System.assertEquals('Ford', vs[0].Make__c);
    }

    @IsTest
    static void syncLocations_insertsLocationAndUpdatesVehicle() {
        Vehicle__c v = new Vehicle__c(GPS_Insights_Id__c = 'veh-001', Status__c = 'Active');
        insert v;

        Test.setMock(HttpCalloutMock.class, new GpsMock());
        Test.startTest();
        GpsInsightsSyncService.syncLocations();
        Test.stopTest();

        List<Vehicle_Location__c> locs = [SELECT Id, Latitude__c, Ignition_On__c FROM Vehicle_Location__c WHERE Vehicle__c = :v.Id];
        System.assertEquals(1, locs.size());
        System.assertEquals(true, locs[0].Ignition_On__c);

        Vehicle__c reloaded = [SELECT Id, Last_Location_Lat__c, Last_Location_Lng__c, Last_GPS_Sync__c FROM Vehicle__c WHERE Id = :v.Id];
        System.assertNotEquals(null, reloaded.Last_Location_Lat__c);
        System.assertNotEquals(null, reloaded.Last_Location_Lng__c);
        System.assertNotEquals(null, reloaded.Last_GPS_Sync__c);
    }

    @IsTest
    static void scheduler_defaultJobTypeIsVehicles() {
        GpsInsightsSyncScheduler def = new GpsInsightsSyncScheduler();
        System.assertEquals('VEHICLES', def.jobType);
    }

    @IsTest
    static void scheduler_executeVehicles_callsSync() {
        Test.setMock(HttpCalloutMock.class, new GpsMock());
        Test.startTest();
        new GpsInsightsSyncScheduler('VEHICLES').execute(null);
        Test.stopTest();
    }

    @IsTest
    static void scheduler_executeLocations_callsSyncAndReschedules() {
        Test.setMock(HttpCalloutMock.class, new GpsMock());
        Test.startTest();
        new GpsInsightsSyncScheduler('LOCATIONS').execute(null);
        Test.stopTest();
        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :GpsInsightsSyncScheduler.LOCATION_PREFIX + '%'
        ];
        System.assert(!jobs.isEmpty(), 'Location sync should have self-rescheduled');
    }

    @IsTest
    static void scheduler_scheduleVehicleDaily_registersJob() {
        Test.startTest();
        GpsInsightsSyncScheduler.scheduleVehicleDaily();
        Test.stopTest();
        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = :GpsInsightsSyncScheduler.VEHICLE_JOB
        ];
        System.assertEquals(1, jobs.size());
        GpsInsightsSyncScheduler.scheduleVehicleDaily(); // second call aborts + reschedules
    }

    @IsTest
    static void scheduler_startLocationRealtime_registersJob() {
        Test.startTest();
        GpsInsightsSyncScheduler.startLocationRealtime();
        Test.stopTest();
        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :GpsInsightsSyncScheduler.LOCATION_PREFIX + '%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ];
        System.assert(!jobs.isEmpty(), 'At least one realtime location job should be scheduled');
    }

    @IsTest
    static void scheduler_stopLocationRealtime_abortsJob() {
        Test.startTest();
        GpsInsightsSyncScheduler.startLocationRealtime();
        GpsInsightsSyncScheduler.stopLocationRealtime();
        Test.stopTest();
        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :GpsInsightsSyncScheduler.LOCATION_PREFIX + '%'
              AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
        ];
        System.assertEquals(0, jobs.size());
    }

    @IsTest
    static void scheduler_scheduleDaily_registersVehicleAndLocationJobs() {
        Test.startTest();
        GpsInsightsSyncScheduler.scheduleDaily();
        Test.stopTest();
        List<CronTrigger> vehicleJobs = [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :GpsInsightsSyncScheduler.VEHICLE_JOB
        ];
        List<CronTrigger> locationJobs = [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE :GpsInsightsSyncScheduler.LOCATION_PREFIX + '%'
        ];
        System.assertEquals(1, vehicleJobs.size());
        System.assert(!locationJobs.isEmpty(), 'Location realtime job should be scheduled');
        GpsInsightsSyncScheduler.scheduleDaily(); // second call aborts + reschedules cleanly
    }
}