public with sharing class GPSArrivalService {

    private static final Decimal ARRIVAL_RADIUS_METERS = 150;

    public class GPSException extends Exception {}

    public class PingResult {
        public Boolean arrived;
        public Decimal distanceMeters;
        public String status;
    }

    public static void beginDrive(Id workOrderId) {
        Work_Order__c wo = [
            SELECT Id, Schedule_Locked__c, Vehicle_Check_Completed__c,
                   Loading_Check_Completed__c, Drive_Started_At__c
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        if (wo.Schedule_Locked__c != true) {
            throw new GPSException('Schedule is not locked for this work order.');
        }
        if (wo.Vehicle_Check_Completed__c != true) {
            throw new GPSException('Vehicle checklist is incomplete.');
        }
        if (wo.Loading_Check_Completed__c != true) {
            throw new GPSException('Loaded checklist is incomplete.');
        }
        if (wo.Drive_Started_At__c != null) {
            throw new GPSException('Drive has already been started.');
        }

        update new Work_Order__c(Id = workOrderId, Drive_Started_At__c = DateTime.now());
    }

    public static PingResult processPing(Id workOrderId, Decimal lat, Decimal lng) {
        Work_Order__c wo = [
            SELECT Id, Status__c, Lot_Latitude__c, Lot_Longitude__c, Arrived_At__c
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        PingResult result = new PingResult();

        if (wo.Lot_Latitude__c == null || wo.Lot_Longitude__c == null) {
            result.arrived = false;
            result.distanceMeters = null;
            result.status = 'no_geofence';
            return result;
        }

        Decimal dist = haversineMeters(lat, lng, wo.Lot_Latitude__c, wo.Lot_Longitude__c);
        result.distanceMeters = dist;
        result.arrived = dist <= ARRIVAL_RADIUS_METERS;

        if (result.arrived && wo.Arrived_At__c == null) {
            update new Work_Order__c(
                Id = workOrderId,
                Arrived_At__c = DateTime.now(),
                Status__c = 'In Progress'
            );
        }

        result.status = result.arrived ? 'arrived' : 'en_route';
        return result;
    }

    private static Decimal haversineMeters(Decimal lat1, Decimal lng1, Decimal lat2, Decimal lng2) {
        Double r = 6371000.0;
        Double phi1 = lat1.doubleValue() * Math.PI / 180;
        Double phi2 = lat2.doubleValue() * Math.PI / 180;
        Double dPhi = (lat2 - lat1).doubleValue() * Math.PI / 180;
        Double dLambda = (lng2 - lng1).doubleValue() * Math.PI / 180;
        Double a = Math.sin(dPhi / 2) * Math.sin(dPhi / 2)
            + Math.cos(phi1) * Math.cos(phi2) * Math.sin(dLambda / 2) * Math.sin(dLambda / 2);
        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return Decimal.valueOf(r * c);
    }
}
