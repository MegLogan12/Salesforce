/**
 * AutoScheduleService
 *
 * Utility service for scheduling calculations. Provides the haversineMeters
 * helper used by GpsTransitionService for mobile crew geofencing.
 *
 * The scheduling proposal logic that originally lived here was removed; this
 * class retains only the utility methods still referenced by active classes.
 */
public with sharing class AutoScheduleService {

    private static final Double EARTH_RADIUS_M = 6371000.0;

    /**
     * Returns the great-circle distance in metres between two WGS-84 coordinates
     * using the Haversine formula.
     */
    public static Double haversineMeters(
        Decimal lat1, Decimal lng1,
        Decimal lat2, Decimal lng2
    ) {
        Double dLat = toRad(lat2 - lat1);
        Double dLng = toRad(lng2 - lng1);
        Double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2))
                 * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        Double c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));
        return EARTH_RADIUS_M * c;
    }

    private static Double toRad(Decimal degrees) {
        return degrees.doubleValue() * Math.PI / 180.0;
    }
}