/**
 * Self-rescheduling batch that pulls Rippling time entries.
 *
 * Queues the sync, then schedules itself to run again in ~7 minutes.
 * Changed from 15 minutes to 7 minutes per operational requirements (2026-05-30).
 */
global with sharing class RipplingTimeEntryBatcher implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id FROM Organization LIMIT 1');
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        RipplingSyncService.syncTimeEntriesSync(null);
    }

    global void finish(Database.BatchableContext bc) {
        rescheduleNext();
    }

    @TestVisible
    private static void rescheduleNext() {
        if (Test.isRunningTest()) {
            return;
        }
        System.scheduleBatch(new RipplingTimeEntryBatcher(), 'Rippling Time Entry Batch', 7, 1);
    }
}