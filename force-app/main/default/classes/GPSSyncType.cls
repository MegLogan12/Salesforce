/**
 * GPSSyncType — top-level enum used by GPSINTEGRATION and GPSIntegrationScheduler
 * to specify which GPS Insight endpoints to sync.
 *
 * Defined as a standalone top-level class to avoid Apex inner-enum compiler
 * restrictions when comparing enum values inside instance methods.
 */
public enum GPSSyncType {
    ALL,
    VEHICLES,
    LOCATIONS,
    DRIVERS,
    LANDMARKS,
    ROUTES,
    MAINTENANCE,
    ALERTS,
    FUEL
}