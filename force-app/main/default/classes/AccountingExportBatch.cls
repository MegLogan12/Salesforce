/**
 * AccountingExportBatch
 *
 * Shell batch class for future G5 accounting system export.
 *
 * *** BLOCKED — Gate G5 Open ***
 * The target accounting system has not been selected.  This batch is
 * intentionally inert (LIMIT 0 in start()) and will throw if execute() is
 * called.  Activate once G5 is resolved and the integration spec is approved.
 *
 * Implements Schedulable so it can be registered in the job scheduler without
 * executing any real work.
 */
public class AccountingExportBatch implements Database.Batchable<SObject>, Schedulable {

    public static final String G5_BLOCKED_MSG =
        'Export is blocked: accounting system target (Gate G5) has not been decided. ' +
        'Activate this batch once G5 is resolved.';

    // ─── Schedulable ─────────────────────────────────────────────────────────

    /**
     * Schedulable entry point — does nothing until G5 is resolved.
     * Logs the blocked state via ErrorLogService if available.
     */
    public void execute(SchedulableContext ctx) {
        // Do nothing — batch must not run until G5 is resolved
        ErrorLogService.log('AccountingExportBatch', 'execute', null, G5_BLOCKED_MSG);
    }

    // ─── Batchable ────────────────────────────────────────────────────────────

    /**
     * Returns an empty QueryLocator (LIMIT 0) so no records are ever
     * processed until this gate is resolved and the LIMIT is lifted.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Only Paid, not-yet-exported invoices — LIMIT 0 until G5 resolved
        return Database.getQueryLocator([
            SELECT Id
            FROM   Invoice__c
            WHERE  Status__c = 'Paid'
            LIMIT  0
        ]);
    }

    /**
     * Execute is blocked.  Will never be reached via start() due to LIMIT 0,
     * but throws explicitly if invoked directly (e.g., from a test or manual
     * call) to surface the gate status clearly.
     */
    public void execute(Database.BatchableContext bc, List<Invoice__c> scope) {
        throw new AuraHandledException(G5_BLOCKED_MSG);
    }

    public void finish(Database.BatchableContext bc) {
        // No-op until G5 is resolved
    }
}
