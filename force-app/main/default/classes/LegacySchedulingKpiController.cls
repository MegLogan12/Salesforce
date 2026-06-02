public with sharing class LegacySchedulingKpiController {
    public class SchedulingKpis {
        @AuraEnabled public Integer pendingProposals = 0;
        @AuraEnabled public Integer ctsQueue = 0;
        @AuraEnabled public Integer lockedToday = 0;
        @AuraEnabled public Integer siteReadinessOverdue = 0;
        @AuraEnabled public Integer thirtyDayPipeline = 0;
        @AuraEnabled public Integer activeCrews = 0;
        @AuraEnabled public Integer openPullTickets = 0;
        @AuraEnabled public Integer openLoadingTickets = 0;
    }

    @AuraEnabled(cacheable=true)
    public static SchedulingKpis getSchedulingKpis() {
        SchedulingKpis kpis = new SchedulingKpis();
        Date today = Date.today();
        Datetime startOfDay = Datetime.newInstance(today, Time.newInstance(0, 0, 0, 0));
        Datetime endOfDay = startOfDay.addDays(1);

        kpis.pendingProposals = [
            SELECT COUNT()
            FROM WorkOrder
            WHERE Status IN ('Draft', 'Pending Proposal', 'Proposal')
        ];
        kpis.ctsQueue = [
            SELECT COUNT()
            FROM WorkOrder
            WHERE Status IN ('Clear to Schedule', 'Ready to Schedule')
        ];
        kpis.lockedToday = [
            SELECT COUNT()
            FROM ServiceAppointment
            WHERE SchedStartTime >= :startOfDay
              AND SchedStartTime < :endOfDay
        ];
        kpis.thirtyDayPipeline = [
            SELECT COUNT()
            FROM WorkOrder
            WHERE CreatedDate = LAST_N_DAYS:30
        ];
        kpis.activeCrews = [
            SELECT COUNT()
            FROM ServiceResource
            WHERE IsActive = true
        ];
        return kpis;
    }
}