public class SiteReadinessAutoCreateBatch implements Database.Batchable<SObject>, Schedulable {

    // Open statuses: WOs in terminal states should not get a readiness record.
    private static final Set<String> SKIP_STATUSES = new Set<String>{
        'Cancelled', 'Closed', 'Completed', 'Invoiced', 'Paid', 'Closeout Approved'
    };

    // Runs nightly; creates Site_Readiness__c + 6 items for WorkOrders whose
    // StartDate is exactly 2 days from today (48-hour advance creation).
    // Idempotency is enforced inside SiteReadinessHandler.autoCreate (skips if exists).
    public static void run() {
        Database.executeBatch(new SiteReadinessAutoCreateBatch(), 50);
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new SiteReadinessAutoCreateBatch(), 50);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date targetDate = Date.today().addDays(2);
        return Database.getQueryLocator(
            'SELECT Id, QI_FM__c, Status FROM WorkOrder ' +
            'WHERE StartDate = :targetDate'
        );
    }

    public void execute(Database.BatchableContext bc, List<WorkOrder> scope) {
        processScope(scope);
    }

    @TestVisible
    static void processScope(List<WorkOrder> scope) {
        for (WorkOrder wo : scope) {
            if (SKIP_STATUSES.contains(wo.Status)) continue;
            SiteReadinessHandler.autoCreate(wo.Id, (Id) wo.QI_FM__c);
        }
    }

    public void finish(Database.BatchableContext bc) {}
}
