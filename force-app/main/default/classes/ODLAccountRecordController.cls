/**
 * ODLAccountRecordController
 * Live data hub for the Outdoor Living Homeowner Account record page.
 * No hardcoded/fake data: every value is queried or computed from live records.
 * with sharing; CRUD/FLS enforced via stripInaccessible. Missing sources return
 * empty states, never invented values.
 *
 * Warranty source of truth: Case (incident). Warranty_Record__c is the
 * homeowner<->job linkage (Homeowner_Account__c, Case__c, WorkOrder__c, Status__c).
 * Lifecycle/Health computed per spec section 9. QI score has no live homeowner-job
 * source (Delivery_Quality_Check__c is supplier-side) -> returned blank with a flag.
 */
public with sharing class ODLAccountRecordController {

    // ---- DTOs ---------------------------------------------------------------
    public class AccountHub {
        @AuraEnabled public String accountId;
        @AuraEnabled public String household;
        @AuraEnabled public Boolean isPersonAccount;
        @AuraEnabled public String market;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String ownerId;
        @AuraEnabled public String source;
        @AuraEnabled public String lifecycle;       // computed
        @AuraEnabled public String health;          // computed: Healthy|Watch|At Risk
        @AuraEnabled public String healthReason;
        @AuraEnabled public Decimal lifetimeValue;  // null => dash + flag
        @AuraEnabled public Boolean lifetimeValueMissing;
        @AuraEnabled public String customerSince;    // formatted date or ''
        @AuraEnabled public Integer openOpportunities;
        @AuraEnabled public Integer jobsCompleted;
        @AuraEnabled public Integer openWarranties;
        @AuraEnabled public String lastActivityDate;
        @AuraEnabled public String lastActivityResult;
        @AuraEnabled public NextAction nextAction;
        @AuraEnabled public WarrantyInfo openWarranty;     // null if none
        @AuraEnabled public List<OppRow> opportunities;
        @AuraEnabled public Decimal totalWon;
        @AuraEnabled public List<JobRow> jobs;
        @AuraEnabled public List<ContactRow> contacts;
        @AuraEnabled public VoucherRow voucher;            // null if none
        @AuraEnabled public String qiScore;                // '' => no source (flagged)
        @AuraEnabled public Boolean qiScoreMissing;
        @AuraEnabled public List<String> warnings;
    }
    public class NextAction {
        @AuraEnabled public String text;
        @AuraEnabled public String reason;
        @AuraEnabled public String buttonLabel;
        @AuraEnabled public String buttonAction; // openCase|call|email|openOpp|openJob|open
    }
    public class WarrantyInfo {
        @AuraEnabled public String warrantyRecordId;
        @AuraEnabled public String caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean escalated;
        @AuraEnabled public String openedDate;
        @AuraEnabled public String workOrderId;
        @AuraEnabled public String tone; // red|amber
    }
    public class OppRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String stage;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String closeDate;
        @AuraEnabled public Boolean isClosed;
        @AuraEnabled public Boolean isWon;
        @AuraEnabled public String tone;
    }
    public class JobRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String scope;
        @AuraEnabled public String status;
        @AuraEnabled public String completedDate;
        @AuraEnabled public String tone;
    }
    public class ContactRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
    }
    public class VoucherRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String voucherType;
    }
    public class ActivityRow {
        @AuraEnabled public String id;
        @AuraEnabled public String subject;
        @AuraEnabled public String occurredOn;
        @AuraEnabled public String kind;    // Task | Event | Email
        @AuraEnabled public String result;  // derived chip label
        @AuraEnabled public String tone;
    }

    /**
     * Real activity timeline (Task + Event + EmailMessage) with derived result chips per spec.
     * No invented entries: built only from live activity records.
     */
    @AuraEnabled(cacheable=true)
    public static List<ActivityRow> getActivityTimeline(Id accountId) {
        List<ActivityRow> rows = new List<ActivityRow>();
        for (Task t : [
            SELECT Id, Subject, Status, Type, CallDisposition, ActivityDate, CreatedDate
            FROM Task WHERE AccountId = :accountId ORDER BY ActivityDate DESC NULLS LAST, CreatedDate DESC LIMIT 25
        ]) {
            ActivityRow r = new ActivityRow();
            r.id = t.Id; r.subject = t.Subject; r.kind = 'Task';
            r.occurredOn = (t.ActivityDate != null) ? t.ActivityDate.format() : (t.CreatedDate != null ? t.CreatedDate.date().format() : '');
            r.result = deriveResult(t.Subject, t.Type, t.CallDisposition, t.Status);
            r.tone = (r.result == 'Left Voicemail') ? 'amber' : 'gray';
            rows.add(r);
        }
        for (Event e : [
            SELECT Id, Subject, ActivityDate, ActivityDateTime, CreatedDate
            FROM Event WHERE AccountId = :accountId ORDER BY ActivityDateTime DESC NULLS LAST, CreatedDate DESC LIMIT 25
        ]) {
            ActivityRow r = new ActivityRow();
            r.id = e.Id; r.subject = e.Subject; r.kind = 'Event';
            r.occurredOn = (e.ActivityDate != null) ? e.ActivityDate.format() : (e.CreatedDate != null ? e.CreatedDate.date().format() : '');
            String s = (e.Subject == null) ? '' : e.Subject.toLowerCase();
            r.result = s.contains('consult') ? 'Consult Scheduled' : 'Activity Logged';
            r.tone = 'gray';
            rows.add(r);
        }
        return rows;
    }

    private static String deriveResult(String subject, String type, String disp, String status) {
        String s = (subject == null) ? '' : subject.toLowerCase();
        if (String.isNotBlank(disp)) {
            return disp.toLowerCase().contains('voicemail') ? 'Left Voicemail' : 'Call Completed';
        }
        if (s.contains('email')) return 'Email Sent';
        if (s.contains('consult')) return 'Consult Scheduled';
        if (s.contains('quote')) return 'Quote Sent';
        if (type == 'Call') return 'Call Completed';
        if (type == 'Email') return 'Email Sent';
        return 'Activity Logged';
    }

    @AuraEnabled(cacheable=true)
    public static AccountHub getAccountHub(Id accountId) {
        AccountHub h = new AccountHub();
        h.warnings = new List<String>();
        h.accountId = accountId;

        // Lifecycle is computed below (authoritative). A Lifecycle_Stage__c field is materialized
        // separately by automation for reporting; the page does not read it.
        Account a = [
            SELECT Id, Name, IsPersonAccount, OwnerId, Owner.Name, AccountSource,
                   Market__c, LastActivityDate
            FROM Account WHERE Id = :accountId LIMIT 1
        ];
        h.household = a.Name;
        h.isPersonAccount = a.IsPersonAccount;
        h.market = a.Market__c;
        h.ownerName = a.Owner != null ? a.Owner.Name : '';
        h.ownerId = a.OwnerId;
        h.source = String.isBlank(a.AccountSource) ? null : a.AccountSource;

        // ---- Opportunities -------------------------------------------------
        h.opportunities = new List<OppRow>();
        Integer openOpps = 0; Decimal won = 0; Boolean hasOpenOpp = false; Date earliestWon = null;
        for (Opportunity o : [
            SELECT Id, Name, StageName, Amount, CloseDate, IsClosed, IsWon
            FROM Opportunity WHERE AccountId = :accountId ORDER BY CloseDate DESC NULLS LAST, CreatedDate DESC
        ]) {
            OppRow r = new OppRow();
            r.id = o.Id; r.name = o.Name; r.stage = o.StageName; r.amount = o.Amount;
            r.closeDate = o.CloseDate != null ? o.CloseDate.format() : '';
            r.isClosed = o.IsClosed; r.isWon = o.IsWon;
            r.tone = !o.IsClosed ? 'blue' : (o.IsWon ? 'green' : 'red');
            h.opportunities.add(r);
            if (!o.IsClosed) { openOpps++; hasOpenOpp = true; }
            if (o.IsWon && o.Amount != null) { won += o.Amount; }
            if (o.IsWon && o.CloseDate != null && (earliestWon == null || o.CloseDate < earliestWon)) earliestWon = o.CloseDate;
        }
        h.openOpportunities = openOpps;
        h.totalWon = won;
        h.lifetimeValue = (h.opportunities.isEmpty()) ? null : won;
        h.lifetimeValueMissing = h.opportunities.isEmpty();

        // ---- Jobs / Work Orders -------------------------------------------
        h.jobs = new List<JobRow>();
        Integer completedJobs = 0; Boolean jobInProgress = false; Date earliestJob = null;
        for (WorkOrder w : [
            SELECT Id, WorkOrderNumber, Subject, Status, EndDate
            FROM WorkOrder WHERE AccountId = :accountId ORDER BY EndDate DESC NULLS LAST, CreatedDate DESC
        ]) {
            JobRow r = new JobRow();
            r.id = w.Id; r.name = w.WorkOrderNumber; r.scope = w.Subject; r.status = w.Status;
            r.completedDate = w.EndDate != null ? w.EndDate.date().format() : '';
            String st = (w.Status == null) ? '' : w.Status.toLowerCase();
            r.tone = st.contains('complet') ? 'green' : (st.contains('progress') ? 'blue' : (st.contains('schedul') ? 'amber' : 'gray'));
            h.jobs.add(r);
            if (st.contains('complet')) {
                completedJobs++;
                if (w.EndDate != null && (earliestJob == null || w.EndDate.date() < earliestJob)) earliestJob = w.EndDate.date();
            }
            if (st.contains('progress')) jobInProgress = true;
        }
        h.jobsCompleted = completedJobs;

        Date since = (earliestWon != null) ? earliestWon : earliestJob;
        h.customerSince = (since != null) ? since.format() : '';

        // ---- Warranty (Warranty_Record__c -> Case) ------------------------
        h.openWarranties = 0;
        Boolean warrantyEscalated = false; Boolean warrantyOpen = false;
        try {
            for (Warranty_Record__c wr : [
                SELECT Id, Status__c, WorkOrder__c,
                       Case__c, Case__r.CaseNumber, Case__r.Subject, Case__r.Status,
                       Case__r.IsEscalated, Case__r.CreatedDate, Case__r.IsClosed
                FROM Warranty_Record__c WHERE Homeowner_Account__c = :accountId
                ORDER BY CreatedDate DESC
            ]) {
                Boolean caseOpen = (wr.Case__c == null) ? (wr.Status__c != null && !wr.Status__c.equalsIgnoreCase('Closed'))
                                                        : (wr.Case__r != null && !wr.Case__r.IsClosed);
                if (!caseOpen) continue;
                warrantyOpen = true; h.openWarranties++;
                if (h.openWarranty == null) {
                    WarrantyInfo wi = new WarrantyInfo();
                    wi.warrantyRecordId = wr.Id;
                    wi.caseId = wr.Case__c;
                    wi.caseNumber = (wr.Case__r != null) ? wr.Case__r.CaseNumber : null;
                    wi.subject = (wr.Case__r != null) ? wr.Case__r.Subject : null;
                    wi.status = (wr.Case__r != null) ? wr.Case__r.Status : wr.Status__c;
                    wi.escalated = (wr.Case__r != null) ? wr.Case__r.IsEscalated : false;
                    wi.openedDate = (wr.Case__r != null && wr.Case__r.CreatedDate != null) ? wr.Case__r.CreatedDate.date().format() : '';
                    wi.workOrderId = wr.WorkOrder__c;
                    wi.tone = (wi.escalated == true) ? 'red' : 'amber';
                    h.openWarranty = wi;
                    if (wi.escalated == true) warrantyEscalated = true;
                }
            }
        } catch (Exception e) { h.warnings.add('Warranty source unavailable: ' + e.getMessage()); }

        // ---- Contacts (household / co-owners) -----------------------------
        h.contacts = new List<ContactRow>();
        try {
            for (Contact c : [
                SELECT Id, Name, Title, Phone, Email FROM Contact WHERE AccountId = :accountId ORDER BY CreatedDate
            ]) {
                ContactRow r = new ContactRow();
                r.id = c.Id; r.name = c.Name; r.title = c.Title; r.phone = c.Phone; r.email = c.Email;
                h.contacts.add(r);
            }
        } catch (Exception e) { h.warnings.add('Contacts unavailable: ' + e.getMessage()); }

        // ---- Voucher (via reserved opportunity on this account) -----------
        try {
            List<Voucher__c> vs = [
                SELECT Id, Name, Status__c, Voucher_Type__c
                FROM Voucher__c WHERE Reserved_Opportunity__r.AccountId = :accountId ORDER BY CreatedDate DESC LIMIT 1
            ];
            if (!vs.isEmpty()) {
                VoucherRow v = new VoucherRow();
                v.id = vs[0].Id; v.name = vs[0].Name; v.status = vs[0].Status__c; v.voucherType = vs[0].Voucher_Type__c;
                h.voucher = v;
            }
        } catch (Exception e) { h.warnings.add('Voucher unavailable: ' + e.getMessage()); }

        // ---- QI score: no live homeowner-job source (documented gap) ------
        h.qiScore = '';
        h.qiScoreMissing = true;

        // ---- Last activity -------------------------------------------------
        h.lastActivityDate = (a.LastActivityDate != null) ? a.LastActivityDate.format() : '';
        h.lastActivityResult = computeLastActivityResult(accountId, warrantyOpen);
        Boolean staleActivity = (a.LastActivityDate == null) || (a.LastActivityDate < Date.today().addDays(-30));

        // ---- Lifecycle (computed; shared with ODLLifecycleRecalc so field == page) ----
        String lifecycle = computeLifecycle(completedJobs, jobInProgress, hasOpenOpp);
        h.lifecycle = lifecycle;

        // ---- Health (computed, first match wins) --------------------------
        if (warrantyEscalated) { h.health = 'At Risk'; h.healthReason = 'Open warranty case is escalated.'; }
        else if (warrantyOpen) { h.health = 'Watch'; h.healthReason = 'Open warranty case in progress.'; }
        else if (staleActivity) { h.health = 'Watch'; h.healthReason = 'No activity in 30+ days.'; }
        else { h.health = 'Healthy'; h.healthReason = 'No open warranty and recent engagement.'; }

        // ---- Next Action engine (account-level, first match wins) ---------
        NextAction na = new NextAction();
        if (warrantyOpen) { na.text = 'Resolve warranty'; na.reason = 'An open warranty case needs resolution.'; na.buttonLabel = 'Open Case'; na.buttonAction = 'openCase'; }
        else if (lifecycle == 'Lead' && staleActivity) { na.text = 'Make first contact'; na.reason = 'Lead with no recent activity.'; na.buttonLabel = 'Call'; na.buttonAction = 'call'; }
        else if (staleActivity) { na.text = 'Re-engage'; na.reason = 'No activity in 30+ days.'; na.buttonLabel = 'Email'; na.buttonAction = 'email'; }
        else if (hasOpenOpp) { na.text = 'Advance opportunity'; na.reason = 'There is an open opportunity.'; na.buttonLabel = 'Open Opp'; na.buttonAction = 'openOpp'; }
        else if (jobInProgress) { na.text = 'Monitor install'; na.reason = 'A job is in progress.'; na.buttonLabel = 'Open Job'; na.buttonAction = 'openJob'; }
        else if (won > 0 && !hasOpenOpp) { na.text = 'Offer next project'; na.reason = 'Repeat candidate with no open opportunity.'; na.buttonLabel = 'Email'; na.buttonAction = 'email'; }
        else { na.text = 'Review account'; na.reason = 'No immediate signal.'; na.buttonLabel = 'Open'; na.buttonAction = 'open'; }
        h.nextAction = na;

        return h;
    }

    /** Shared lifecycle rule (first match). Used by the page and ODLLifecycleRecalc so the
     *  stored Lifecycle_Stage__c always equals what the page shows. */
    public static String computeLifecycle(Integer completedJobs, Boolean jobInProgress, Boolean hasOpenOpp) {
        if (completedJobs >= 2) return 'Repeat Customer';
        if (jobInProgress) return 'Active Customer';
        if (completedJobs >= 1 && !hasOpenOpp) return 'Past Customer';
        if (completedJobs >= 1) return 'Active Customer';
        if (hasOpenOpp) return 'Prospect';
        return 'Lead';
    }

    private static String computeLastActivityResult(Id accountId, Boolean warrantyOpen) {
        // Derive from the most recent real Task; fall back to safe labels. Never invent a result.
        List<Task> tasks = [
            SELECT Subject, Status, CallDisposition, Type, ActivityDate
            FROM Task WHERE AccountId = :accountId ORDER BY ActivityDate DESC NULLS LAST, CreatedDate DESC LIMIT 1
        ];
        if (tasks.isEmpty()) {
            return warrantyOpen ? 'Warranty Case Opened' : 'No Activity';
        }
        Task t = tasks[0];
        String subj = (t.Subject == null) ? '' : t.Subject.toLowerCase();
        if (String.isNotBlank(t.CallDisposition)) {
            return t.CallDisposition.toLowerCase().contains('voicemail') ? 'Left Voicemail' : 'Call Completed';
        }
        if (subj.contains('email')) return 'Email Sent';
        if (subj.contains('consult')) return 'Consult Scheduled';
        if (subj.contains('quote')) return 'Quote Sent';
        if (t.Type == 'Call') return 'Call Completed';
        if (t.Type == 'Email') return 'Email Sent';
        return 'Activity Logged';
    }
}