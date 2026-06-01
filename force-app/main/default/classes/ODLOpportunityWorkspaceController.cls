public with sharing class ODLOpportunityWorkspaceController {

    public class KpiCard {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
        @AuraEnabled public String amountDisplay;
    }

    public class OppRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String oppHref;
        @AuraEnabled public String oppName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountHref;
        @AuraEnabled public String accountName;
        @AuraEnabled public String lob;
        @AuraEnabled public String lobChipClass;
        @AuraEnabled public String stageName;
        @AuraEnabled public String stageChipClass;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String amountDisplay;
        @AuraEnabled public String packageDisplay;
        @AuraEnabled public String voucherCode;
        @AuraEnabled public String voucherStatus;
        @AuraEnabled public Boolean hasBuilderVoucher;
        @AuraEnabled public String campaignName;
        @AuraEnabled public String quoteStatus;
        @AuraEnabled public String quoteStatusChipClass;
        @AuraEnabled public String contractStatus;
        @AuraEnabled public Boolean depositPaid;
        @AuraEnabled public Boolean woReady;
        @AuraEnabled public String lastActivityResult;
        @AuraEnabled public String lastActivityChipClass;
        @AuraEnabled public Date lastActivityDate;
        @AuraEnabled public String lastActivityDateDisplay;
        @AuraEnabled public String followUpSubject;
        @AuraEnabled public Date followUpDate;
        @AuraEnabled public String followUpDateDisplay;
        @AuraEnabled public String followUpChipClass;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Id ownerId;
        @AuraEnabled public String nextActionText;
        @AuraEnabled public String nextActionButton;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public Boolean voicemailLeft;
    }

    public class WorkspaceData {
        @AuraEnabled public List<KpiCard> kpis;
        @AuraEnabled public List<OppRow> rows;
        @AuraEnabled public List<String> ownerNames;
    }

    @AuraEnabled(cacheable=true)
    public static WorkspaceData getWorkspaceData() {
        WorkspaceData result = new WorkspaceData();
        result.rows = new List<OppRow>();
        result.ownerNames = new List<String>();

        List<Opportunity> opps = [
            SELECT Id, Name, AccountId, Account.Name, StageName, Amount, CloseDate,
                   OwnerId, Owner.Name, RecordType.DeveloperName,
                   BMG_Package__c, Selected_Package__c,
                   Quote_Status__c, Contract_Status__c, Deposit_Paid__c,
                   Voicemail_Left__c, LastActivityDate,
                   CampaignId, Campaign.Name
            FROM Opportunity
            WHERE IsClosed = false
              AND Account.Type = 'Home Owner'
              AND RecordType.DeveloperName IN ('UMB', 'Design_Build')
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ];

        if (opps.isEmpty()) {
            result.kpis = buildKpis(result.rows);
            return result;
        }

        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : opps) {
            oppIds.add(opp.Id);
        }

        Map<Id, SObject> voucherByOpp = queryVouchers(oppIds);
        Map<Id, Task> latestCompletedByOpp = queryLatestCompletedTask(oppIds);
        Map<Id, Task> nextOpenByOpp = queryNextOpenTask(oppIds);

        Set<String> ownerSet = new Set<String>();
        for (Opportunity opp : opps) {
            OppRow row = buildRow(opp, voucherByOpp, latestCompletedByOpp, nextOpenByOpp);
            result.rows.add(row);
            if (row.ownerName != null) {
                ownerSet.add(row.ownerName);
            }
        }

        result.ownerNames = new List<String>(ownerSet);
        result.ownerNames.sort();
        result.kpis = buildKpis(result.rows);
        return result;
    }

    private static OppRow buildRow(Opportunity opp, Map<Id, SObject> voucherByOpp,
                                    Map<Id, Task> latestCompletedByOpp, Map<Id, Task> nextOpenByOpp) {
        OppRow row = new OppRow();
        row.id = opp.Id;
        row.oppHref = '/lightning/r/Opportunity/' + opp.Id + '/view';
        row.oppName = opp.Name;
        row.accountId = opp.AccountId;
        row.accountHref = opp.AccountId != null ? '/lightning/r/Account/' + opp.AccountId + '/view' : null;
        row.accountName = opp.Account != null ? opp.Account.Name : null;
        row.lob = opp.RecordType.DeveloperName == 'UMB' ? 'UpgradeMyBackyard' : 'Design Build';
        row.lobChipClass = opp.RecordType.DeveloperName == 'UMB' ? 'chip chip-umb' : 'chip chip-design';
        row.stageName = opp.StageName;
        row.stageChipClass = stageChipClass(opp.StageName);
        row.amount = opp.Amount;
        row.amountDisplay = opp.Amount != null ? '$' + String.valueOf(opp.Amount.setScale(0)) : null;
        String rawPkg = opp.BMG_Package__c != null ? opp.BMG_Package__c : opp.Selected_Package__c;
        row.packageDisplay = normalizePackage(rawPkg);
        row.quoteStatus = opp.Quote_Status__c;
        row.quoteStatusChipClass = quoteStatusChipClass(opp.Quote_Status__c);
        row.contractStatus = opp.Contract_Status__c;
        row.depositPaid = opp.Deposit_Paid__c;
        row.woReady = isWoReady(opp);
        row.voicemailLeft = opp.Voicemail_Left__c;
        row.ownerName = opp.Owner != null ? opp.Owner.Name : null;
        row.ownerId = opp.OwnerId;
        row.closeDate = opp.CloseDate;
        row.campaignName = opp.CampaignId != null && opp.Campaign != null ? opp.Campaign.Name : null;
        row.lastActivityDate = opp.LastActivityDate;
        row.lastActivityDateDisplay = formatDate(opp.LastActivityDate);

        SObject voucher = voucherByOpp.get(opp.Id);
        if (voucher != null) {
            Object code = voucher.get('Voucher_Code__c');
            Object status = voucher.get('Status__c');
            Object builder = voucher.get('Builder_Account__c');
            row.voucherCode = code != null ? String.valueOf(code) : null;
            row.voucherStatus = status != null ? String.valueOf(status) : null;
            row.hasBuilderVoucher = builder != null;
        }

        Task latestTask = latestCompletedByOpp.get(opp.Id);
        if (latestTask != null) {
            row.lastActivityResult = deriveActivityResult(latestTask.Subject, latestTask.CallDisposition);
            row.lastActivityChipClass = activityChipClass(row.lastActivityResult);
            if (latestTask.ActivityDate != null) {
                row.lastActivityDate = latestTask.ActivityDate;
                row.lastActivityDateDisplay = formatDate(latestTask.ActivityDate);
            }
        } else if (opp.LastActivityDate != null) {
            row.lastActivityResult = 'Activity';
            row.lastActivityChipClass = 'chip chip-gray';
        } else {
            row.lastActivityResult = 'No Activity';
            row.lastActivityChipClass = 'chip chip-gray';
        }

        Task nextTask = nextOpenByOpp.get(opp.Id);
        if (nextTask != null) {
            row.followUpSubject = nextTask.Subject;
            row.followUpDate = nextTask.ActivityDate;
            row.followUpDateDisplay = formatDate(nextTask.ActivityDate);
            row.followUpChipClass = followUpChipClass(nextTask.ActivityDate);
        }

        row.nextActionText = deriveNextActionText(row, opp);
        row.nextActionButton = deriveNextActionButton(row, opp);
        return row;
    }

    private static Boolean isWoReady(Opportunity opp) {
        return opp.Quote_Status__c == 'Accepted'
            && opp.Contract_Status__c == 'Signed'
            && opp.Deposit_Paid__c == true;
    }

    private static String stageChipClass(String stage) {
        if (stage == null) return 'chip chip-gray';
        String lower = stage.toLowerCase();
        if (lower == 'discovery') return 'chip chip-stone';
        if (lower == 'consult scheduled') return 'chip chip-blue-lt';
        if (lower == 'design in progress') return 'chip chip-blue';
        if (lower == 'quote review') return 'chip chip-amber';
        if (lower == 'contract sent') return 'chip chip-amber';
        if (lower == 'deposit pending') return 'chip chip-orange';
        if (lower == 'closed won') return 'chip chip-green';
        if (lower == 'closed lost') return 'chip chip-red';
        return 'chip chip-gray';
    }

    private static String quoteStatusChipClass(String status) {
        if (status == 'Accepted') return 'chip chip-green';
        if (status == 'Sent') return 'chip chip-amber';
        if (status == 'Rejected') return 'chip chip-red';
        return 'chip chip-gray';
    }

    private static String activityChipClass(String result) {
        if (result == 'Left Voicemail') return 'chip chip-amber';
        if (result == 'Email Sent') return 'chip chip-blue';
        if (result == 'Call Connected') return 'chip chip-green';
        if (result == 'Text Sent') return 'chip chip-blue';
        return 'chip chip-gray';
    }

    private static String followUpChipClass(Date d) {
        if (d == null) return 'chip chip-gray';
        Date today = Date.today();
        if (d < today) return 'chip chip-red';
        if (d == today || d <= today.addDays(2)) return 'chip chip-amber';
        return 'chip chip-green';
    }

    private static String normalizePackage(String rawValue) {
        if (String.isBlank(rawValue)) return null;
        String lower = rawValue.toLowerCase().trim();
        if (lower == 'retreat' || lower == 'good') return 'Retreat';
        if (lower == 'entertainer' || lower == 'better') return 'Entertainer';
        if (lower == 'signature' || lower == 'best') return 'Signature';
        return rawValue;
    }

    private static String deriveActivityResult(String subject, String callDisposition) {
        if (!String.isBlank(callDisposition)) {
            String disp = callDisposition.toLowerCase();
            if (disp.contains('voicemail')) return 'Left Voicemail';
            if (disp.contains('connected') || disp.contains('reached') || disp.contains('answered')) return 'Call Connected';
        }
        if (!String.isBlank(subject)) {
            String lower = subject.toLowerCase();
            if (lower.contains('voicemail')) return 'Left Voicemail';
            if (lower.contains('email')) return 'Email Sent';
            if (lower.contains('text') || lower.contains('sms')) return 'Text Sent';
            if (lower.contains('call') || lower.contains('phone')) return 'Call Connected';
        }
        return 'Activity';
    }

    private static String deriveNextActionText(OppRow row, Opportunity opp) {
        if (row.woReady) return 'Work order ready to release';
        if (opp.Voicemail_Left__c) return 'Schedule callback — voicemail was left';
        if (row.followUpDate != null && row.followUpDate < Date.today()) {
            return 'Overdue: ' + (row.followUpSubject != null ? row.followUpSubject : 'follow-up task');
        }
        if (opp.StageName == 'Deposit Pending') return 'Collect deposit to release work order';
        if (opp.StageName == 'Contract Sent' || opp.Contract_Status__c == 'Sent') {
            return 'Contract awaiting signature';
        }
        if (opp.StageName == 'Quote Review' || opp.Quote_Status__c == 'Sent') {
            return 'Quote awaiting customer decision';
        }
        if (opp.StageName == 'Design In Progress') return 'Complete design and send quote';
        if (opp.StageName == 'Consult Scheduled') return 'Confirm consultation appointment';
        if (row.followUpDate != null && row.followUpDate == Date.today()) {
            return 'Due today: ' + (row.followUpSubject != null ? row.followUpSubject : 'follow-up task');
        }
        if (opp.LastActivityDate == null || row.lastActivityResult == 'No Activity') return 'Log first contact';
        if (row.followUpDate == null) return 'Schedule next follow-up';
        return 'On track';
    }

    private static String deriveNextActionButton(OppRow row, Opportunity opp) {
        if (row.woReady) return 'Release WO';
        if (opp.Voicemail_Left__c) return 'Schedule';
        if (row.followUpDate != null && row.followUpDate <= Date.today()) return 'Log Activity';
        if (opp.StageName == 'Deposit Pending') return 'Call';
        if (opp.StageName == 'Contract Sent' || opp.Contract_Status__c == 'Sent') return 'Call';
        if (opp.StageName == 'Quote Review' || opp.Quote_Status__c == 'Sent') return 'Call';
        if (opp.StageName == 'Design In Progress') return 'Send Quote';
        if (opp.StageName == 'Consult Scheduled') return 'Confirm';
        if (opp.LastActivityDate == null) return 'Log Call';
        if (row.followUpDate == null) return 'New Task';
        return 'View';
    }

    private static List<KpiCard> buildKpis(List<OppRow> rows) {
        Integer total = 0, umbCount = 0, designCount = 0;
        Integer voicemailCount = 0, followUpDueCount = 0, woReadyCount = 0;
        Decimal totalAmount = 0;

        for (OppRow row : rows) {
            total++;
            totalAmount += row.amount != null ? row.amount : 0;
            if ('UpgradeMyBackyard'.equals(row.lob)) umbCount++;
            if ('Design Build'.equals(row.lob)) designCount++;
            if (row.voicemailLeft == true) voicemailCount++;
            if (row.followUpDate != null && row.followUpDate <= Date.today()) followUpDueCount++;
            if (row.woReady == true) woReadyCount++;
        }

        List<KpiCard> kpis = new List<KpiCard>();
        kpis.add(makeKpi('all', 'All Open Opps', total, totalAmount));
        kpis.add(makeKpi('umb', 'UpgradeMyBackyard', umbCount, null));
        kpis.add(makeKpi('design', 'Design Build', designCount, null));
        kpis.add(makeKpi('woReady', 'WO Ready', woReadyCount, null));
        kpis.add(makeKpi('voicemail', 'Voicemail Pending', voicemailCount, null));
        kpis.add(makeKpi('followUp', 'Follow-Up Due', followUpDueCount, null));
        return kpis;
    }

    private static KpiCard makeKpi(String key, String label, Integer count, Decimal amount) {
        KpiCard kpi = new KpiCard();
        kpi.key = key;
        kpi.label = label;
        kpi.count = count;
        kpi.amountDisplay = amount != null && amount > 0 ? '$' + String.valueOf(amount.setScale(0)) : null;
        return kpi;
    }

    private static Map<Id, SObject> queryVouchers(Set<Id> oppIds) {
        Map<Id, SObject> result = new Map<Id, SObject>();
        if (!Schema.getGlobalDescribe().containsKey('Voucher__c')) {
            return result;
        }
        for (SObject v : Database.query(
            'SELECT Id, Voucher_Code__c, Status__c, Builder_Account__c, Reserved_Opportunity__c ' +
            'FROM Voucher__c WHERE Reserved_Opportunity__c IN :oppIds ORDER BY CreatedDate DESC'
        )) {
            Id relOppId = (Id) v.get('Reserved_Opportunity__c');
            if (!result.containsKey(relOppId)) {
                result.put(relOppId, v);
            }
        }
        return result;
    }

    private static Map<Id, Task> queryLatestCompletedTask(Set<Id> oppIds) {
        Map<Id, Task> result = new Map<Id, Task>();
        for (Task t : [
            SELECT WhatId, Subject, CallDisposition, ActivityDate
            FROM Task
            WHERE WhatId IN :oppIds
              AND IsClosed = true
            ORDER BY ActivityDate DESC NULLS LAST, CreatedDate DESC
            LIMIT 400
        ]) {
            if (!result.containsKey(t.WhatId)) {
                result.put(t.WhatId, t);
            }
        }
        return result;
    }

    private static Map<Id, Task> queryNextOpenTask(Set<Id> oppIds) {
        Map<Id, Task> result = new Map<Id, Task>();
        for (Task t : [
            SELECT WhatId, Subject, ActivityDate
            FROM Task
            WHERE WhatId IN :oppIds
              AND IsClosed = false
            ORDER BY ActivityDate ASC NULLS LAST, CreatedDate ASC
            LIMIT 400
        ]) {
            if (!result.containsKey(t.WhatId)) {
                result.put(t.WhatId, t);
            }
        }
        return result;
    }

    private static String formatDate(Date d) {
        if (d == null) return null;
        String m = d.month() < 10 ? '0' + String.valueOf(d.month()) : String.valueOf(d.month());
        String day = d.day() < 10 ? '0' + String.valueOf(d.day()) : String.valueOf(d.day());
        return m + '/' + day + '/' + String.valueOf(d.year());
    }
}
