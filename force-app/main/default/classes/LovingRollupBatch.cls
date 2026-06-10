/**
 * LovingRollupBatch
 *
 * Nightly scheduled batch that maintains aggregate count and financial
 * fields on Community__c and Account that cannot be Salesforce Summary fields
 * because the child relationships are Lookup (not MasterDetail).
 *
 * Fields maintained:
 *
 *   Community__c
 *     Active_Lot_Count__c   — Lot__c with Lot_Status__c != 'Closed' linked to this community
 *     Closed_Lot_Count__c   — Lot__c with Lot_Status__c = 'Closed' linked to this community
 *
 *   Account
 *     Total_Communities__c  — Community__c records linked to this account (Builder_Account__c)
 *     Total_Active_WOs__c   — standard WorkOrder with non-terminal status linked via AccountId
 *     YTD_Revenue__c        — Sum of Invoice__c.Total_Revenue__c with Invoice_Date__c in current year
 *     AR_Balance__c         — Sum of Invoice__c.Total_Revenue__c - Amount_Paid__c for unpaid invoices
 *
 * Run schedule: every night at 2 AM via LovingRollupScheduler.
 * Can also be triggered on-demand from Admin UI.
 */
public with sharing class LovingRollupBatch implements Database.Batchable<SObject>, Database.Stateful {

    // Batch scope: one account or community at a time is too slow — process all in two passes
    private static final String MODE_COMMUNITY = 'COMMUNITY';
    private static final String MODE_ACCOUNT   = 'ACCOUNT';

    private String mode;

    public LovingRollupBatch() {
        this.mode = MODE_COMMUNITY;  // Start with community pass
    }

    public LovingRollupBatch(String mode) {
        this.mode = mode;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (mode == MODE_COMMUNITY) {
            return Database.getQueryLocator([
                SELECT Id FROM Community__c
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id FROM Account
            ]);
        }
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (mode == MODE_COMMUNITY) {
            processCommunities((List<Community__c>) scope);
        } else {
            processAccounts((List<Account>) scope);
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (mode == MODE_COMMUNITY) {
            // Chain account pass
            Database.executeBatch(new LovingRollupBatch(MODE_ACCOUNT), 200);
        }
        System.debug('LovingRollupBatch ' + mode + ' pass complete.');
    }

    // ─────────────────────────────────────────────
    // COMMUNITY PASS
    // ─────────────────────────────────────────────
    private void processCommunities(List<Community__c> communities) {
        Set<Id> commIds = new Map<Id, Community__c>(communities).keySet();

        // Aggregate active and closed lots per community
        Map<Id, Integer> activeLots = new Map<Id, Integer>();
        Map<Id, Integer> closedLots = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT Community__c commId, Lot_Status__c status, COUNT(Id) cnt
            FROM Lot__c
            WHERE Community__c IN :commIds
            GROUP BY Community__c, Lot_Status__c
        ]) {
            Id cId    = (Id)     ar.get('commId');
            String st = (String) ar.get('status');
            Integer n = (Integer) ar.get('cnt');

            if (st == 'Closed') {
                closedLots.put(cId, (closedLots.containsKey(cId) ? closedLots.get(cId) : 0) + n);
            } else {
                activeLots.put(cId, (activeLots.containsKey(cId) ? activeLots.get(cId) : 0) + n);
            }
        }

        List<Community__c> toUpdate = new List<Community__c>();
        for (Community__c comm : communities) {
            Integer active = activeLots.containsKey(comm.Id) ? activeLots.get(comm.Id) : 0;
            Integer closed = closedLots.containsKey(comm.Id) ? closedLots.get(comm.Id) : 0;
            toUpdate.add(new Community__c(
                Id                  = comm.Id,
                Active_Lot_Count__c = active,
                Closed_Lot_Count__c = closed
            ));
        }

        if (!toUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(toUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    ErrorLogService.log('LovingRollupBatch', 'processCommunities',
                        toUpdate[i].Id, results[i].getErrors()[0].getMessage());
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // ACCOUNT PASS
    // ─────────────────────────────────────────────
    private void processAccounts(List<Account> accounts) {
        Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
        Integer currentYear = Date.today().year();
        Date ytdStart = Date.newInstance(currentYear, 1, 1);

        // Total communities per account (via Builder_Account__c lookup on Community__c)
        Map<Id, Integer> commCount = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Builder_Account__c acctId, COUNT(Id) cnt
            FROM Community__c
            WHERE Builder_Account__c IN :accountIds
            GROUP BY Builder_Account__c
        ]) {
            commCount.put((Id) ar.get('acctId'), (Integer) ar.get('cnt'));
        }

        // Active Work Orders per account (via standard WorkOrder.AccountId)
        Set<String> terminalStatuses = new Set<String>{ 'Closed', 'Canceled' };
        Map<Id, Integer> activeWOs = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT AccountId acctId, COUNT(Id) cnt
            FROM WorkOrder
            WHERE AccountId IN :accountIds
            AND Status NOT IN :terminalStatuses
            GROUP BY AccountId
        ]) {
            activeWOs.put((Id) ar.get('acctId'), (Integer) ar.get('cnt'));
        }

        // YTD Revenue — sum of Total_Revenue__c on Invoice__c with Invoice_Date in current year
        Map<Id, Decimal> ytdRevenue = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Builder_Market_Account__c acctId, SUM(Total_Revenue__c) rev
            FROM Invoice__c
            WHERE Builder_Market_Account__c IN :accountIds
            AND Invoice_Date__c >= :ytdStart
            AND Status__c != 'Void'
            GROUP BY Builder_Market_Account__c
        ]) {
            Decimal rev = (Decimal) ar.get('rev');
            ytdRevenue.put((Id) ar.get('acctId'), rev != null ? rev : 0);
        }

        // AR Balance — total unpaid invoice amounts (Sent / Pending Send status)
        Map<Id, Decimal> arBalance = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Builder_Market_Account__c acctId,
                   SUM(Total_Revenue__c) totalRev,
                   SUM(Amount_Paid__c) totalPaid
            FROM Invoice__c
            WHERE Builder_Market_Account__c IN :accountIds
            AND Status__c IN ('Sent', 'Pending Send')
            GROUP BY Builder_Market_Account__c
        ]) {
            Decimal rev  = (Decimal) ar.get('totalRev');
            Decimal paid = (Decimal) ar.get('totalPaid');
            arBalance.put((Id) ar.get('acctId'),
                (rev != null ? rev : 0) - (paid != null ? paid : 0));
        }

        List<Account> toUpdate = new List<Account>();
        for (Account acct : accounts) {
            toUpdate.add(new Account(
                Id                  = acct.Id,
                Total_Communities__c = commCount.containsKey(acct.Id)  ? commCount.get(acct.Id)  : 0,
                Total_Active_WOs__c  = activeWOs.containsKey(acct.Id)  ? activeWOs.get(acct.Id)  : 0,
                YTD_Revenue__c       = ytdRevenue.containsKey(acct.Id)  ? ytdRevenue.get(acct.Id)  : 0,
                AR_Balance__c        = arBalance.containsKey(acct.Id)   ? arBalance.get(acct.Id)   : 0
            ));
        }

        if (!toUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(toUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    ErrorLogService.log('LovingRollupBatch', 'processAccounts',
                        toUpdate[i].Id, results[i].getErrors()[0].getMessage());
                }
            }
        }
    }
}