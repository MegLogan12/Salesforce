/**
 * OneOnOneScheduler
 *
 * Schedulable Apex class that runs every Monday at 6:00 AM.
 * For each manager-direct-report pair with Cadence__c = Weekly,
 * creates that week's OneOnOne__c record if one does not already exist.
 *
 * Spec reference: Section 7.12.
 */
public with sharing class OneOnOneScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        run();
    }

    /**
     * Public entry point for testing and manual invocation.
     * Returns count of records created.
     */
    public static Integer run() {
        Date weekStart = computeNextMonday(Date.today());

        // Find all OneOnOne records with Weekly cadence to determine recurring pairs
        // We treat each manager+direct_report combo with Cadence Weekly as recurring
        Map<String, Id[]> recurringPairs = new Map<String, Id[]>();

        for (OneOnOne__c existing : [
            SELECT Manager__c, Direct_Report__c, Cadence__c, Meeting_Date__c
            FROM OneOnOne__c
            WHERE Cadence__c = 'Weekly'
            ORDER BY Meeting_Date__c DESC
            LIMIT 5000
        ]) {
            String key = existing.Manager__c + '|' + existing.Direct_Report__c;
            if (!recurringPairs.containsKey(key)) {
                recurringPairs.put(key, new Id[]{ existing.Manager__c, existing.Direct_Report__c });
            }
        }

        // Find pairs that already have a meeting scheduled this week
        DateTime weekStartDT = DateTime.newInstance(weekStart, Time.newInstance(0, 0, 0, 0));
        DateTime weekEndDT = weekStartDT.addDays(7);

        Set<String> alreadyScheduled = new Set<String>();
        for (OneOnOne__c existing : [
            SELECT Manager__c, Direct_Report__c
            FROM OneOnOne__c
            WHERE Meeting_Date__c >= :weekStartDT
            AND Meeting_Date__c < :weekEndDT
        ]) {
            alreadyScheduled.add(existing.Manager__c + '|' + existing.Direct_Report__c);
        }

        // Create new records for pairs not already scheduled
        List<OneOnOne__c> toCreate = new List<OneOnOne__c>();
        for (String key : recurringPairs.keySet()) {
            if (alreadyScheduled.contains(key)) continue;
            Id[] ids = recurringPairs.get(key);
            OneOnOne__c o = new OneOnOne__c(
                Manager__c = ids[0],
                Direct_Report__c = ids[1],
                Meeting_Date__c = weekStartDT.addHours(9),
                Cadence__c = 'Weekly',
                Status__c = 'Scheduled'
            );
            toCreate.add(o);
        }

        if (!toCreate.isEmpty()) {
            insert toCreate;
        }
        return toCreate.size();
    }

    /**
     * Find next Monday (or today if today is Monday).
     */
    @TestVisible
    private static Date computeNextMonday(Date d) {
        DateTime dt = DateTime.newInstance(d.year(), d.month(), d.day());
        Integer dow = Integer.valueOf(dt.format('u'));  // 1=Mon..7=Sun
        if (dow == 1) return d;
        return d.addDays(8 - dow);
    }

    /**
     * Schedule this job for every Monday at 6:00 AM.
     * Call from anonymous Apex: OneOnOneScheduler.scheduleWeekly();
     */
    public static String scheduleWeekly() {
        List<CronTrigger> existing = [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'OneOnOne Weekly Scheduler' LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        String cron = '0 0 6 ? * MON';
        return System.schedule('OneOnOne Weekly Scheduler', cron, new OneOnOneScheduler());
    }
}