/**
 * ODLLifecycleRecalc
 * Materializes the computed homeowner lifecycle into Account.Lifecycle_Stage__c for
 * reporting/list-views. Uses ODLAccountRecordController.computeLifecycle so the stored
 * value always equals what the record page shows. Schedule nightly (Schedulable).
 */
public with sharing class ODLLifecycleRecalc implements Database.Batchable<SObject>, Schedulable {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id FROM Account WHERE IsPersonAccount = true]);
    }
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        Set<Id> ids = (new Map<Id, Account>(scope)).keySet();
        Map<Id, Integer> openOpp = new Map<Id, Integer>();
        for (AggregateResult ar : [SELECT AccountId aid, COUNT(Id) c FROM Opportunity WHERE AccountId IN :ids AND IsClosed = false GROUP BY AccountId]) {
            openOpp.put((Id) ar.get('aid'), (Integer) ar.get('c'));
        }
        Map<Id, Integer> completed = new Map<Id, Integer>();
        Set<Id> inProgress = new Set<Id>();
        for (WorkOrder w : [SELECT AccountId, Status FROM WorkOrder WHERE AccountId IN :ids]) {
            String st = (w.Status == null) ? '' : w.Status.toLowerCase();
            if (st.contains('complet')) { Integer c = completed.containsKey(w.AccountId) ? completed.get(w.AccountId) : 0; completed.put(w.AccountId, c + 1); }
            if (st.contains('progress')) inProgress.add(w.AccountId);
        }
        List<Account> updates = new List<Account>();
        for (Id aid : ids) {
            Integer comp = completed.containsKey(aid) ? completed.get(aid) : 0;
            Boolean jip = inProgress.contains(aid);
            Boolean hasOpen = openOpp.containsKey(aid) && openOpp.get(aid) > 0;
            updates.add(new Account(Id = aid, Lifecycle_Stage__c = ODLAccountRecordController.computeLifecycle(comp, jip, hasOpen)));
        }
        if (!updates.isEmpty()) update updates;
    }
    public void finish(Database.BatchableContext bc) {}
    public void execute(SchedulableContext sc) { Database.executeBatch(new ODLLifecycleRecalc(), 200); }
}