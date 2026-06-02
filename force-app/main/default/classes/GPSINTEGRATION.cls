/**
 * GPSINTEGRATION — high-level orchestrator for the WEX Fleet Intelligence sync pipeline.
 *
 * Implements Queueable + Database.AllowsCallouts so each sync type runs as an
 * async job that is allowed to make HTTP callouts.
 *
 * Design: each Queueable instance handles ONE sync type.  run() / run(ALL) enqueues
 * three separate jobs so no single job mixes HTTP callouts with prior DML.
 *
 * Usage (Anonymous Apex / Schedulable):
 *   GPSINTEGRATION.run();                            // enqueues VEHICLES + LOCATIONS + DRIVERS
 *   GPSINTEGRATION.run(GPSSyncType.LOCATIONS);       // locations only
 *
 * Phase 1 sync types:
 *   VEHICLES    → WEXVehicleSyncService     — upserts Vehicle__c from /vehicle
 *   LOCATIONS   → WEXLocationSyncService    — upserts WEX_GPS_Position__c + mirrors Vehicle__c
 *   DRIVERS     → WEXDriverSyncService      — upserts Driver_Assignment__c from /driver
 *
 * Phase 2 sync types:
 *   LANDMARKS   → WEXLandmarkSyncService    — upserts GPS_Landmark__c from /landmark
 *   ROUTES      → WEXRouteSyncService       — upserts Vehicle_Location__c from /vehicle/history
 *   MAINTENANCE → WEXMaintenanceSyncService — upserts Vehicle_Diagnostic__c from /vehicle/diagnostic
 *   ALERTS      → WEXAlertSyncService       — upserts GPS_Alert__c from /alert
 *   FUEL        → WEXFuelSyncService        — upserts Vehicle_Fuel_Transaction__c from /vehicle/ifta
 */
public with sharing class GPSINTEGRATION implements Queueable, Database.AllowsCallouts {

    private final GPSSyncType syncType;

    public GPSINTEGRATION(GPSSyncType t) {
        this.syncType = t;
    }

    // ── Factory methods ───────────────────────────────────────────────────────

    /** Enqueues all eight sync types as separate Queueable jobs. */
    public static void run() {
        System.enqueueJob(new GPSINTEGRATION(GPSSyncType.VEHICLES));
        System.enqueueJob(new GPSINTEGRATION(GPSSyncType.LOCATIONS));
        System.enqueueJob(new GPSINTEGRATION(GPSSyncType.DRIVERS));
        System.enqueueJob(new GPSINTEGRATION(GPSSyncType.LANDMARKS));
        System.enqueueJob(new GPSINTEGRATION(GPSSyncType.ROUTES));
        System.enqueueJob(new GPSINTEGRATION(GPSSyncType.MAINTENANCE));
        System.enqueueJob(new GPSINTEGRATION(GPSSyncType.ALERTS));
        System.enqueueJob(new GPSINTEGRATION(GPSSyncType.FUEL));
    }

    /** Enqueues one job for the specified sync type.  ALL enqueues three separate jobs. */
    public static void run(GPSSyncType t) {
        if (t == GPSSyncType.ALL) { run(); return; }
        System.enqueueJob(new GPSINTEGRATION(t));
    }

    // ── Execution ─────────────────────────────────────────────────────────────

    public void execute(QueueableContext ctx) {
        try {
            if (syncType == GPSSyncType.VEHICLES)    { WEXVehicleSyncService.sync(); }
            if (syncType == GPSSyncType.LOCATIONS)   { WEXLocationSyncService.sync(); }
            if (syncType == GPSSyncType.DRIVERS)     { WEXDriverSyncService.sync(); }
            if (syncType == GPSSyncType.LANDMARKS)   { WEXLandmarkSyncService.sync(); }
            if (syncType == GPSSyncType.ROUTES)      { WEXRouteSyncService.sync(); }
            if (syncType == GPSSyncType.MAINTENANCE) { WEXMaintenanceSyncService.sync(); }
            if (syncType == GPSSyncType.ALERTS)      { WEXAlertSyncService.sync(); }
            if (syncType == GPSSyncType.FUEL)        { WEXFuelSyncService.sync(); }
        } catch (Exception e) {
            WEXGpsClient.logError('execute', 0,
                'SyncType=' + syncType + ' — ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
}