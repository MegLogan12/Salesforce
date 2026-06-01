public class ParentRollupBatch implements Database.Batchable<SObject> {

    public static void run() {
        Database.executeBatch(new ParentRollupBatch(), 50);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id FROM Account WHERE RecordType.DeveloperName = \'Builder_Parent\''
        );
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        Set<Id> parentIds = (new Map<Id, Account>(scope)).keySet();

        // Sum child division revenue into Parent_Revenue_T12M__c.
        // Concentration_Pct_Q__c on each division reads this via cross-object formula.
        Map<Id, Decimal> revByParent = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT ParentId pid, SUM(Division_Revenue_T12M__c) rev
            FROM Account
            WHERE ParentId IN :parentIds
              AND RecordType.DeveloperName = 'Builder_Market'
            GROUP BY ParentId
        ]) {
            Decimal r = (Decimal) ar.get('rev');
            revByParent.put((Id) ar.get('pid'), r != null ? r : 0);
        }

        // Build Active_Markets__c: sorted, deduplicated market values from active divisions
        Map<Id, Set<String>> marketSetsByParent = new Map<Id, Set<String>>();
        for (Account div : [
            SELECT ParentId, Market__c
            FROM Account
            WHERE ParentId IN :parentIds
              AND RecordType.DeveloperName = 'Builder_Market'
              AND Account_Status__c = 'Active'
              AND Market__c != null
        ]) {
            if (!marketSetsByParent.containsKey(div.ParentId)) {
                marketSetsByParent.put(div.ParentId, new Set<String>());
            }
            marketSetsByParent.get(div.ParentId).add(div.Market__c);
        }

        List<Account> updates = new List<Account>();
        for (Id parentId : parentIds) {
            Decimal rev = revByParent.containsKey(parentId) ? revByParent.get(parentId) : null;

            Account a = new Account(Id = parentId);
            a.Parent_Revenue_T12M__c = (rev != null && rev > 0) ? rev : null;

            if (marketSetsByParent.containsKey(parentId)) {
                List<String> markets = new List<String>(marketSetsByParent.get(parentId));
                markets.sort();
                a.Active_Markets__c = String.join(markets, ', ');
            } else {
                a.Active_Markets__c = null;
            }
            updates.add(a);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public void finish(Database.BatchableContext bc) {}
}
