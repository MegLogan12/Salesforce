public class DivisionKpiRecalcBatch implements Database.Batchable<SObject> {

    private static final Date T12M = Date.today().addDays(-365);
    // On-Time % is a trailing-30-day measure (field description / Spec 3.5).
    private static final DateTime T30 = DateTime.now().addDays(-30);

    // Terminal statuses loaded from WO_Status_Mapping__mdt so finance can
    // change the open/closed line without a code deploy (Prompt 2 requirement).
    private static final Set<String> WO_TERMINAL = loadTerminalStatuses();

    private static Set<String> loadTerminalStatuses() {
        Set<String> terminal = new Set<String>();
        for (WO_Status_Mapping__mdt m : [
            SELECT Status_Label__c FROM WO_Status_Mapping__mdt WHERE Is_Terminal__c = true
        ]) {
            terminal.add(m.Status_Label__c);
        }
        // Fallback in case CMT records are absent (deployment gap)
        if (terminal.isEmpty()) {
            terminal.addAll(new Set<String>{
                'Closed', 'Cancelled', 'Invoiced', 'Paid', 'Closeout Approved'
            });
        }
        return terminal;
    }

    public static void run() {
        Database.executeBatch(new DivisionKpiRecalcBatch(), 50);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id FROM Account ' +
            'WHERE RecordType.DeveloperName = \'Builder_Market\' ' +
            'AND Account_Status__c != \'Terminated\''
        );
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        Set<Id> divIds = (new Map<Id, Account>(scope)).keySet();

        // Revenue and GP cost from Invoice in one query.
        // GP logic lives in declarative formula fields, not Apex:
        //   Adjusted_Revenue__c = Total_Revenue__c - Customer_Revenue_Adjustment__c (customer credits)
        //   Adjusted_Cost__c    = Total_Cost__c    - Internal_Cost_Recovery__c      (vendor/crew back-charges)
        // Back-charges are no longer blanket-excluded; their effect is captured per-type via those
        // two adjustment fields, so finance can see and tune the rule on each invoice.
        Map<Id, Decimal> revByDiv = new Map<Id, Decimal>();
        Map<Id, Decimal> costByDiv = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Builder_Market_Account__c div,
                   SUM(Adjusted_Revenue__c) rev,
                   SUM(Adjusted_Cost__c) cost
            FROM Invoice__c
            WHERE Status__c = 'Paid'
              AND Date_Paid__c >= :T12M
              AND Builder_Market_Account__c IN :divIds
            GROUP BY Builder_Market_Account__c
        ]) {
            Decimal r = (Decimal) ar.get('rev');
            Decimal c = (Decimal) ar.get('cost');
            Id div = (Id) ar.get('div');
            revByDiv.put(div, r != null ? r : 0);
            costByDiv.put(div, c != null ? c : 0);
        }

        // Open WO count (not in terminal statuses)
        Map<Id, Integer> openWoByDiv = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Builder_Market_Account__c div, COUNT(Id) cnt
            FROM Work_Order__c
            WHERE Builder_Market_Account__c IN :divIds
              AND Status__c NOT IN :WO_TERMINAL
            GROUP BY Builder_Market_Account__c
        ]) {
            openWoByDiv.put((Id) ar.get('div'), (Integer) ar.get('cnt'));
        }

        // NFI count (canonical single value after picklist consolidation)
        Map<Id, Integer> nfiByDiv = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Builder_Market_Account__c div, COUNT(Id) cnt
            FROM Work_Order__c
            WHERE Builder_Market_Account__c IN :divIds
              AND Status__c = 'Need Further Info (NFI)'
            GROUP BY Builder_Market_Account__c
        ]) {
            nfiByDiv.put((Id) ar.get('div'), (Integer) ar.get('cnt'));
        }

        // Open Warranty count (Is_Warranty__c = true, not terminal)
        Map<Id, Integer> warrantyByDiv = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Builder_Market_Account__c div, COUNT(Id) cnt
            FROM Work_Order__c
            WHERE Builder_Market_Account__c IN :divIds
              AND Is_Warranty__c = true
              AND Status__c NOT IN :WO_TERMINAL
            GROUP BY Builder_Market_Account__c
        ]) {
            warrantyByDiv.put((Id) ar.get('div'), (Integer) ar.get('cnt'));
        }

        // Open PO count
        Map<Id, Integer> poByDiv = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Builder_Account__c div, COUNT(Id) cnt
            FROM Builder_PO__c
            WHERE Builder_Account__c IN :divIds
              AND Status__c NOT IN ('Closed', 'Cancelled')
            GROUP BY Builder_Account__c
        ]) {
            poByDiv.put((Id) ar.get('div'), (Integer) ar.get('cnt'));
        }

        // Active community count
        Map<Id, Integer> commByDiv = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Builder_Account__c div, COUNT(Id) cnt
            FROM Community__c
            WHERE Builder_Account__c IN :divIds
              AND Active__c = true
            GROUP BY Builder_Account__c
        ]) {
            commByDiv.put((Id) ar.get('div'), (Integer) ar.get('cnt'));
        }

        // Active lot count (sum of Community__c.Active_Lot_Count__c per division)
        Map<Id, Integer> lotsByDiv = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Builder_Account__c div, SUM(Active_Lot_Count__c) lots
            FROM Community__c
            WHERE Builder_Account__c IN :divIds
              AND Active__c = true
            GROUP BY Builder_Account__c
        ]) {
            Decimal l = (Decimal) ar.get('lots');
            lotsByDiv.put((Id) ar.get('div'), l != null ? l.intValue() : 0);
        }

        // On-Time Completion % (trailing 30 days).
        // Promise date  = Scheduled_End_DateTime__c (confirmed by Meg).
        // Actual finish = Field_Complete_Date__c (crew completion DateTime, comparable to the promise).
        // A WO is measurable only if it has a promise date; WOs without one are excluded from
        // both numerator and denominator so they neither help nor hurt the score.
        Map<Id, Integer> completedByDiv = new Map<Id, Integer>();
        Map<Id, Integer> onTimeByDiv = new Map<Id, Integer>();
        for (Work_Order__c wo : [
            SELECT Builder_Market_Account__c, Field_Complete_Date__c, Scheduled_End_DateTime__c
            FROM Work_Order__c
            WHERE Builder_Market_Account__c IN :divIds
              AND Field_Complete_Date__c >= :T30
              AND Scheduled_End_DateTime__c != null
        ]) {
            Id d = wo.Builder_Market_Account__c;
            completedByDiv.put(d, (completedByDiv.containsKey(d) ? completedByDiv.get(d) : 0) + 1);
            if (wo.Field_Complete_Date__c <= wo.Scheduled_End_DateTime__c) {
                onTimeByDiv.put(d, (onTimeByDiv.containsKey(d) ? onTimeByDiv.get(d) : 0) + 1);
            }
        }

        List<Account> updates = new List<Account>();
        for (Id divId : divIds) {
            Decimal rev  = revByDiv.containsKey(divId)  ? revByDiv.get(divId)  : null;
            Decimal cost = costByDiv.containsKey(divId) ? costByDiv.get(divId) : null;
            Decimal gp   = (rev != null && rev > 0 && cost != null)
                            ? ((rev - cost) / rev * 100).setScale(2)
                            : null;

            Account a = new Account(Id = divId);
            a.Division_Revenue_T12M__c    = (rev != null && rev > 0) ? rev : null;
            a.Division_GP_Pct__c          = gp;
            a.Active_Communities_Count__c = commByDiv.containsKey(divId)    ? commByDiv.get(divId)    : 0;
            a.Active_Lot_Count__c         = lotsByDiv.containsKey(divId)    ? lotsByDiv.get(divId)    : 0;
            a.Open_WO_Count__c            = openWoByDiv.containsKey(divId)  ? openWoByDiv.get(divId)  : 0;
            a.Open_PO_Count__c            = poByDiv.containsKey(divId)      ? poByDiv.get(divId)      : 0;
            a.Open_Warranty_Count__c      = warrantyByDiv.containsKey(divId)? warrantyByDiv.get(divId): 0;
            a.Open_NFI_Count__c           = nfiByDiv.containsKey(divId)     ? nfiByDiv.get(divId)     : 0;

            Integer completed = completedByDiv.containsKey(divId) ? completedByDiv.get(divId) : 0;
            Integer onTime    = onTimeByDiv.containsKey(divId)    ? onTimeByDiv.get(divId)    : 0;
            // Null (not 0) when there is nothing measurable, so the UI can show "—" rather than a false 0%.
            a.On_Time_Completion_Pct__c = completed > 0
                ? (((Decimal) onTime) / completed * 100).setScale(2)
                : null;

            updates.add(a);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Chain ParentRollupBatch after all divisions are current.
        // Division totals must be fresh before the parent sums them.
        Database.executeBatch(new ParentRollupBatch(), 50);
    }
}