/**
 * Scheduler for Rippling sync jobs.
 *
 * scheduleDaily() is the one-time setup entry point. It registers:
 *   Rippling Employee Sync    -> daily 02:00
 *   Rippling Time Off Sync    -> hourly
 *   Rippling PTO Rollup       -> daily 00:05
 *   Rippling Time Entry Batch -> first run now, self-reschedules every 15 min
 */
global with sharing class RipplingSyncScheduler implements Schedulable {

    global String jobType;

    global RipplingSyncScheduler() {
        this.jobType = 'EMPLOYEE';
    }

    global RipplingSyncScheduler(String jobType) {
        this.jobType = jobType;
    }

    global static void scheduleDaily() {
        abortIfScheduled('Rippling Employee Sync');
        abortIfScheduled('Rippling Time Off Sync');
        abortIfScheduled('Rippling PTO Rollup');
        System.schedule('Rippling Employee Sync', '0 0 2 * * ?', new RipplingSyncScheduler('EMPLOYEE'));
        System.schedule('Rippling Time Off Sync', '0 0 * * * ?', new RipplingSyncScheduler('TIME_OFF'));
        System.schedule('Rippling PTO Rollup',    '0 5 0 * * ?', new RipplingSyncScheduler('PTO_ROLLUP'));
        // Time entries run via a self-rescheduling batch every 15 min.
        Database.executeBatch(new RipplingTimeEntryBatcher(), 1);
    }

    global void execute(SchedulableContext sc) {
        if (jobType == 'EMPLOYEE') {
            RipplingSyncService.syncEmployees();
        } else if (jobType == 'TIME_OFF') {
            RipplingSyncService.syncTimeOff();
        } else if (jobType == 'PTO_ROLLUP') {
            RipplingSyncService.syncTimeOff();
        }
    }

    private static void abortIfScheduled(String name) {
        for (CronTrigger ct : [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name = :name]) {
            try {
                System.abortJob(ct.Id);
            } catch (Exception e) {
                // already aborted or completed
            }
        }
    }
}