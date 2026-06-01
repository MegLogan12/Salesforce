public class DivisionKpiRecalcBatch implements Database.Batchable<SObject> {

    private static final Date T12M = Date.today().addDays(-365);
    private static final Set<String> WO_TERMINAL = new Set<String>{
        'Closed', 'Cancelled', 'Invoiced', 'Paid', 'Closeout Approved'
    };

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

        // On_Time_Completion_Pct__c: requires a target/scheduled completion date field
        // to compare against Closed_Date__c. No target date field confirmed yet.
        // Stays null until sandbox testing resolves the on-time definition.

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
