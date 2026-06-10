@IsTest
private class LovingVehicleMapControllerTest {

    private class GeoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('{"display_name":"123 Test Street, Charlotte, NC 28202"}');
            return r;
        }
    }

    private static void seedPosition() {
        if (Schema.getGlobalDescribe().containsKey('WEX_GPS_Position__c')) {
            SObject p = Schema.getGlobalDescribe().get('WEX_GPS_Position__c').newSObject();
            try { p.put('Latitude__c', 35.2); p.put('Longitude__c', -80.8); insert p; } catch (Exception e) {}
        }
    }

    @IsTest static void returnsPositions() {
        seedPosition();
        Test.startTest();
        List<LovingVehicleMapController.VehiclePosition> r = LovingVehicleMapController.getLiveVehiclePositions();
        Test.stopTest();
        System.assertNotEquals(null, r, 'should not be null');
    }

    @IsTest static void returnsPositionsWithAddresses() {
        seedPosition();
        Test.setMock(HttpCalloutMock.class, new GeoMock());
        Test.startTest();
        List<LovingVehicleMapController.VehiclePosition> r = LovingVehicleMapController.getVehiclesWithAddresses();
        Test.stopTest();
        System.assertNotEquals(null, r, 'should not be null');
    }
}