public with sharing class ODLAccountWorkspaceController {

    private static final Id HOME_OWNER_RT_ID =
        Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Home_Owner')
            .getRecordTypeId();

    private static final Set<String> ODL_OPP_TYPES =
        new Set<String>{ 'UMB', 'Design and Build' };

    private static final Set<String> ACTIVE_WO_STATUSES =
        new Set<String>{
            'In Progress', 'Approved', 'Scheduled', 'Ready to Schedule'
        };

    // ── Entry point ─────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static WorkspaceDataDTO getWorkspaceData() {
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException(
                'You do not have access to view Account records.');
        }
        try {
            List<Account> accounts = [
                SELECT Id, Name, OwnerId, Owner.Name,
                       Market__c, AccountSource, LastActivityDate,
                       YTD_Revenue__c,
                       (SELECT Id, Name
                        FROM Contacts
                        ORDER BY CreatedDate
                        LIMIT 1),
                       (SELECT Id, Name, StageName, Amount, Type, IsClosed
                        FROM Opportunities
                        WHERE Type IN ('UMB', 'Design and Build')
                        ORDER BY LastModifiedDate DESC NULLS LAST
                        LIMIT 50),
                       (SELECT Id, Status
                        FROM WorkOrders
                        WHERE Status IN (
                            'In Progress', 'Approved',
                            'Scheduled', 'Ready to Schedule')
                        ORDER BY CreatedDate DESC NULLS LAST
                        LIMIT 5)
                FROM Account
                WHERE RecordTypeId = :HOME_OWNER_RT_ID
                ORDER BY LastActivityDate DESC NULLS LAST
                LIMIT 2000
            ];

            Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();

            // Open warranty count per account
            Map<Id, Integer> warrantyCountByAcct = new Map<Id, Integer>();
            if (!accountIds.isEmpty()
                && Schema.sObjectType.Warranty_Record__c.isAccessible()) {
                for (Warranty_Record__c w : [
                    SELECT Homeowner_Account__c
                    FROM Warranty_Record__c
                    WHERE Homeowner_Account__c IN :accountIds
                    AND Status__c IN ('Open', 'In Review')
                    LIMIT 5000
                ]) {
                    Integer c = warrantyCountByAcct.get(w.Homeowner_Account__c);
                    warrantyCountByAcct.put(
                        w.Homeowner_Account__c, (c == null ? 0 : c) + 1);
                }
            }

            // Closed Won opp count per account (for lifecycle derivation)
            Map<Id, Integer> closedWonByAcct = new Map<Id, Integer>();
            if (!accountIds.isEmpty()) {
                for (AggregateResult ar : [
                    SELECT AccountId acctId, COUNT(Id) ct
                    FROM Opportunity
                    WHERE AccountId IN :accountIds
                    AND StageName = 'Closed Won'
                    AND Type IN ('UMB', 'Design and Build')
                    GROUP BY AccountId
                ]) {
                    closedWonByAcct.put(
                        (Id) ar.get('acctId'), (Integer) ar.get('ct'));
                }
            }

            // Most recent Task per account
            Map<Id, Task> latestTaskByAcct = new Map<Id, Task>();
            if (!accountIds.isEmpty()
                && Schema.sObjectType.Task.isAccessible()) {
                for (Task t : [
                    SELECT Id, WhatId, Subject, Status,
                           CallDisposition, Type, ActivityDate
                    FROM Task
                    WHERE WhatId IN :accountIds
                    ORDER BY ActivityDate DESC NULLS LAST
                    LIMIT 5000
                ]) {
                    if (t.WhatId != null
                        && !latestTaskByAcct.containsKey(t.WhatId)) {
                        latestTaskByAcct.put(t.WhatId, t);
                    }
                }
            }

            // Vouchers via Opportunity → Account path
            Set<Id> oppIds = new Set<Id>();
            Map<Id, Id> oppToAcct = new Map<Id, Id>();
            for (Account a : accounts) {
                if (a.Opportunities != null) {
                    for (Opportunity o : a.Opportunities) {
                        oppIds.add(o.Id);
                        oppToAcct.put(o.Id, a.Id);
                    }
                }
            }
            Set<Id> acctIdsWithVoucher = new Set<Id>();
            if (!oppIds.isEmpty()
                && Schema.sObjectType.Voucher__c.isAccessible()) {
                for (Voucher__c v : [
                    SELECT Reserved_Opportunity__c
                    FROM Voucher__c
                    WHERE Reserved_Opportunity__c IN :oppIds
                ]) {
                    if (v.Reserved_Opportunity__c != null
                        && oppToAcct.containsKey(v.Reserved_Opportunity__c)) {
                        acctIdsWithVoucher.add(
                            oppToAcct.get(v.Reserved_Opportunity__c));
                    }
                }
            }

            // Build rows
            List<AccountRowDTO> rows = new List<AccountRowDTO>();
            for (Account a : accounts) {
                rows.add(buildRow(
                    a,
                    warrantyCountByAcct.get(a.Id),
                    closedWonByAcct.get(a.Id),
                    latestTaskByAcct.get(a.Id),
                    acctIdsWithVoucher.contains(a.Id)
                ));
            }

            WorkspaceDataDTO dto = new WorkspaceDataDTO();
            dto.rows = rows;
            dto.homeOwnerRecordTypeId = HOME_OWNER_RT_ID;
            return dto;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Row builder ─────────────────────────────────────────────────────────

    private static AccountRowDTO buildRow(Account a,
                                          Integer openWarrantyCount,
                                          Integer closedWonCount,
                                          Task latestTask,
                                          Boolean hasVoucher) {
        Integer wc = openWarrantyCount == null ? 0 : openWarrantyCount;
        Integer cw = closedWonCount    == null ? 0 : closedWonCount;

        String primaryContact = '';
        if (a.Contacts != null && !a.Contacts.isEmpty()) {
            primaryContact = a.Contacts[0].Name;
        }

        Opportunity openOpp = null;
        if (a.Opportunities != null) {
            for (Opportunity o : a.Opportunities) {
                if (!o.IsClosed) { openOpp = o; break; }
            }
        }

        WorkOrder activeJob = null;
        if (a.WorkOrders != null && !a.WorkOrders.isEmpty()) {
            activeJob = a.WorkOrders[0];
        }

        String lifecycle = computeLifecycle(openOpp, activeJob, cw);

        Date actDate = latestTask != null
            ? latestTask.ActivityDate
            : a.LastActivityDate;
        String actResult = deriveActivityResult(latestTask);

        String health     = computeHealth(wc, actDate, openOpp);
        String[] nextAct  = computeNextAction(wc, lifecycle, actDate, openOpp, activeJob, cw);

        AccountRowDTO row = new AccountRowDTO();
        row.accountId          = a.Id;
        row.name               = a.Name;
        row.primaryContact     = primaryContact;
        row.market             = a.Market__c;
        row.ownerId            = a.OwnerId;
        row.ownerName          = a.Owner != null ? a.Owner.Name : '';
        row.lifecycle          = lifecycle;
        // LTV proxy: YTD_Revenue__c until a proper lifetime roll-up is created (§9 workaround).
        // Gate: a Closed Won Opp roll-up or completed-job sum needs Meg approval before creation.
        row.lifetimeValue      = a.YTD_Revenue__c;
        row.openOppId          = openOpp != null ? openOpp.Id        : null;
        row.openOppName        = openOpp != null ? openOpp.Name      : null;
        row.openOppStage       = openOpp != null ? openOpp.StageName : null;
        row.openOppAmount      = openOpp != null ? openOpp.Amount    : null;
        row.activeJobId        = activeJob != null ? activeJob.Id     : null;
        row.activeJobStatus    = activeJob != null ? activeJob.Status : null;
        row.openWarrantyCount  = wc;
        row.hasVoucher         = hasVoucher;
        row.source             = a.AccountSource;
        row.lastActivityDate   = actDate != null ? String.valueOf(actDate) : null;
        row.lastActivityResult = actResult;
        row.health             = health;
        row.nextActionText     = nextAct[0];
        row.nextActionVerb     = nextAct[1];
        return row;
    }

    // ── Lifecycle engine (first match wins) ─────────────────────────────────

    private static String computeLifecycle(Opportunity openOpp,
                                            WorkOrder activeJob,
                                            Integer closedWonCount) {
        if (closedWonCount > 1) return 'Repeat Customer';
        if (activeJob   != null) return 'Active Customer';
        if (openOpp     != null) return 'Prospect';
        if (closedWonCount == 1) return 'Past Customer';
        return 'Lead';
    }

    // ── Health engine (first match wins) ────────────────────────────────────

    private static String computeHealth(Integer openWarrantyCount,
                                         Date lastActivityDate,
                                         Opportunity openOpp) {
        if (openWarrantyCount > 0) return 'At Risk';
        Integer daysSince = lastActivityDate != null
            ? lastActivityDate.daysBetween(Date.today())
            : 9999;
        if (daysSince >= 30) return 'Watch';
        if (openOpp != null
            && (openOpp.StageName == 'Deposit Pending'
                || openOpp.StageName == 'Contract Sent'))
            return 'Watch';
        return 'Healthy';
    }

    // ── Next Action engine (first match wins) ───────────────────────────────

    private static String[] computeNextAction(Integer wc,
                                               String lifecycle,
                                               Date lastActivityDate,
                                               Opportunity openOpp,
                                               WorkOrder activeJob,
                                               Integer closedWonCount) {
        Integer daysSince = lastActivityDate != null
            ? lastActivityDate.daysBetween(Date.today())
            : 9999;
        if (wc > 0)
            return new String[]{ 'Resolve warranty', 'Open Case' };
        if (lifecycle == 'Lead' && daysSince >= 9999)
            return new String[]{ 'Make first contact', 'Call' };
        if (daysSince >= 30)
            return new String[]{ 'Re-engage', 'Email' };
        if (openOpp != null)
            return new String[]{ 'Advance opportunity', 'Open Opp' };
        if (activeJob != null)
            return new String[]{ 'Monitor install', 'Open Job' };
        if (closedWonCount >= 1)
            return new String[]{ 'Offer next project', 'Email' };
        return new String[]{ 'Review account', 'Open' };
    }

    // ── Activity result derivation ──────────────────────────────────────────

    private static String deriveActivityResult(Task t) {
        if (t == null) return 'No Activity';
        String subj = (t.Subject         == null ? '' : t.Subject).toLowerCase();
        String disp = (t.CallDisposition == null ? '' : t.CallDisposition).toLowerCase();
        String typ  = (t.Type            == null ? '' : t.Type).toLowerCase();

        if (disp.contains('voicemail') || disp.contains('left message'))
            return 'Left Voicemail';
        if (typ == 'call' && t.Status == 'Completed')
            return 'Call Completed';
        if (typ == 'email' || subj.startsWith('email'))
            return 'Email Sent';
        if (subj.contains('consult') || typ == 'meeting')
            return 'Consult Scheduled';
        if (subj.contains('quote'))
            return 'Quote Sent';
        if (t.Status == 'Completed')
            return 'Activity Logged';
        return 'Activity Logged - Result Not Categorized';
    }

    // ── DTOs ────────────────────────────────────────────────────────────────

    public class WorkspaceDataDTO {
        @AuraEnabled public List<AccountRowDTO> rows;
        @AuraEnabled public Id                  homeOwnerRecordTypeId;
    }

    public class AccountRowDTO {
        @AuraEnabled public Id      accountId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  primaryContact;
        @AuraEnabled public String  market;
        @AuraEnabled public String  ownerId;
        @AuraEnabled public String  ownerName;
        @AuraEnabled public String  lifecycle;
        @AuraEnabled public Decimal lifetimeValue;
        @AuraEnabled public Id      openOppId;
        @AuraEnabled public String  openOppName;
        @AuraEnabled public String  openOppStage;
        @AuraEnabled public Decimal openOppAmount;
        @AuraEnabled public Id      activeJobId;
        @AuraEnabled public String  activeJobStatus;
        @AuraEnabled public Integer openWarrantyCount;
        @AuraEnabled public Boolean hasVoucher;
        @AuraEnabled public String  source;
        @AuraEnabled public String  lastActivityDate;
        @AuraEnabled public String  lastActivityResult;
        @AuraEnabled public String  health;
        @AuraEnabled public String  nextActionText;
        @AuraEnabled public String  nextActionVerb;
    }
}
