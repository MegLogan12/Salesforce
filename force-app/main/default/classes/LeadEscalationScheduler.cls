/**
 * LeadEscalationScheduler
 * Schedules a future check for leads stuck in 'Awaiting Decision' > 30 days.
 * Called from LeadHandler when a lead moves to Awaiting Decision.
 */
global class LeadEscalationScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        checkAwaitingDecisionLeads();
    }

    public static void scheduleAwaitingDecisionCheck(List<Id> leadIds) {
        // Batch check handled by nightly job instead of per-record scheduling
        // The AwaitingDecisionBatch runs daily and flags leads > 30 days
    }

    // Called by a daily scheduled job
    public static void checkAwaitingDecisionLeads() {
        Date cutoff = Date.today().addDays(-30);
        List<Lead> stale = [
            SELECT Id, Name, Company, OwnerId, Status
            FROM Lead
            WHERE Status = 'Awaiting Decision'
            AND LastModifiedDate <= :Datetime.newInstance(cutoff, Time.newInstance(0, 0, 0, 0))
            AND IsConverted = false
        ];

        for (Lead l : stale) {
            EscalationService.sendAlert(
                EscalationService.getCOOId(),
                'Lead Awaiting Decision > 30 Days',
                l.Company + ' has been in Awaiting Decision status for more than 30 days. Follow up required.',
                l.Id
            );
        }
    }
}