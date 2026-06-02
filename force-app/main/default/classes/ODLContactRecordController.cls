public with sharing class ODLContactRecordController {

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class ContactPageData {
        @AuraEnabled public Contact contactRecord;
        @AuraEnabled public String  accountName;
        @AuraEnabled public Id      accountId;
        @AuraEnabled public String  contactInitials;
        @AuraEnabled public String  location;
        @AuraEnabled public String  ownerName;
        @AuraEnabled public String  leadSource;
        @AuraEnabled public Boolean isPrimary;
        @AuraEnabled public Boolean isRepeatCustomer;
        // Consent
        @AuraEnabled public Boolean smsConsent;
        @AuraEnabled public String  smsOptInDate;
        @AuraEnabled public String  smsOptInSource;
        @AuraEnabled public Boolean emailOptedOut;
        @AuraEnabled public Boolean emailBounced;
        @AuraEnabled public String  emailStatus;
        @AuraEnabled public String  commsChip;
        @AuraEnabled public String  commsChipClass;
        // Next action
        @AuraEnabled public String  nextActionText;
        @AuraEnabled public String  nextActionWhy;
        @AuraEnabled public String  nextActionPrimaryLabel;
        @AuraEnabled public Id      nextActionCaseId;
        @AuraEnabled public Id      nextActionOppId;
        // Related
        @AuraEnabled public String  accountUrl;
        @AuraEnabled public List<DealRow>        dealsAndService;
        @AuraEnabled public List<HouseholdMember> householdMembers;
        @AuraEnabled public List<ActivityItem>    recentActivity;
        @AuraEnabled public String  householdLtv;
    }

    public class DealRow {
        @AuraEnabled public Id     recordId;
        @AuraEnabled public String recordUrl;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public String status;
        @AuraEnabled public String chipClass;
        @AuraEnabled public String value;
    }

    public class HouseholdMember {
        @AuraEnabled public Id     contactId;
        @AuraEnabled public String recordUrl;
        @AuraEnabled public String name;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String initials;
    }

    public class ActivityItem {
        @AuraEnabled public String subject;
        @AuraEnabled public String dateText;
        @AuraEnabled public String description;
    }

    // ── Main query ────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static ContactPageData getContactPageData(Id contactId) {
        Contact con = [
            SELECT Id, FirstName, LastName, Name, Phone, MobilePhone, Email, Title,
                MailingStreet, MailingCity, MailingState, MailingPostalCode,
                HasOptedOutOfEmail, IsEmailBounced, EmailBouncedDate,
                LeadSource, ContactSource,
                SMS_Consent__c, SMS_Opt_In_Date__c, SMS_Opt_In_Source__c,
                Last_Activity_DateTime__c, Last_Activity_Summary__c,
                Next_Follow_Up_DateTime__c,
                AccountId, Account.Name, Account.BillingCity, Account.BillingState,
                OwnerId, Owner.Name
            FROM Contact
            WHERE Id = :contactId
            WITH SECURITY_ENFORCED
        ];

        ContactPageData pd = new ContactPageData();
        pd.contactRecord = con;
        pd.accountId     = con.AccountId;
        pd.accountName   = con.Account?.Name;
        pd.accountUrl    = con.AccountId != null
                            ? '/lightning/r/Account/' + con.AccountId + '/view' : null;
        pd.contactInitials = initials(con.FirstName, con.LastName);
        pd.location      = location(con.Account?.BillingCity, con.Account?.BillingState);
        pd.ownerName     = con.Owner?.Name;
        pd.leadSource    = String.isNotBlank(con.LeadSource) ? con.LeadSource : con.ContactSource;

        // Consent
        pd.smsConsent    = con.SMS_Consent__c;
        pd.smsOptInDate  = con.SMS_Opt_In_Date__c != null
                            ? con.SMS_Opt_In_Date__c.format() : null;
        pd.smsOptInSource = con.SMS_Opt_In_Source__c;
        pd.emailOptedOut = con.HasOptedOutOfEmail;
        pd.emailBounced  = con.IsEmailBounced;
        pd.emailStatus   = emailStatus(con);
        pd.commsChip     = commsChipLabel(con);
        pd.commsChipClass = commsChipClass(con);

        // Related records
        List<OpportunityContactRole> roles = [
            SELECT OpportunityId, Role, IsPrimary,
                Opportunity.Name, Opportunity.StageName, Opportunity.Amount,
                Opportunity.CloseDate, Opportunity.RecordType.DeveloperName,
                Opportunity.IsWon, Opportunity.IsClosed
            FROM OpportunityContactRole
            WHERE ContactId = :contactId
            WITH SECURITY_ENFORCED
            ORDER BY Opportunity.CloseDate DESC NULLS LAST
            LIMIT 20
        ];

        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Status, Type, CreatedDate
            FROM Case
            WHERE ContactId = :contactId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        List<Quote> quotes = [
            SELECT Id, Name, Status, TotalPrice, CreatedDate
            FROM Quote
            WHERE ContactId = :contactId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        pd.isPrimary       = anyPrimary(roles);
        pd.isRepeatCustomer = anyClosedWon(roles);
        pd.dealsAndService  = buildDeals(roles, cases, quotes);

        buildNextAction(pd, con, cases, roles);

        if (con.AccountId != null) {
            pd.householdMembers = buildHousehold(contactId, con.AccountId);
            pd.householdLtv     = buildLtv(con.AccountId);
        }

        pd.recentActivity = buildActivity(contactId);

        return pd;
    }

    // ── Next action engine ────────────────────────────────────────────────────
    // First-match wins. Consent and service aware.

    private static void buildNextAction(
        ContactPageData pd, Contact con,
        List<Case> cases, List<OpportunityContactRole> roles
    ) {
        // Rule 1 — Open case: resolve before next marketing send
        Case openCase = firstOpenCase(cases);
        if (openCase != null) {
            String caseLabel = String.isNotBlank(openCase.Subject)
                ? openCase.Subject : openCase.CaseNumber;
            pd.nextActionText         = 'Resolve the open case before the next campaign sends';
            pd.nextActionWhy          = '"' + caseLabel + '" is open. '
                + 'Do not upsell or re-engage a contact with an unresolved service issue.';
            pd.nextActionPrimaryLabel = 'Open case';
            pd.nextActionCaseId       = openCase.Id;
            return;
        }

        // Rule 2 — SMS consent missing while phone is present
        Boolean hasPhone = String.isNotBlank(con.Phone) || String.isNotBlank(con.MobilePhone);
        if (!con.SMS_Consent__c && hasPhone) {
            pd.nextActionText  = 'Obtain SMS consent — text cadence is paused for this contact';
            pd.nextActionWhy   = 'SMS_Consent__c is false. The going-dark cadence '
                + 'and any SMS journey are suppressed until this contact explicitly opts in.';
            pd.nextActionPrimaryLabel = null;
            return;
        }

        // Rule 3 — Email opted out
        if (con.HasOptedOutOfEmail) {
            pd.nextActionText  = 'Email is opted out — reach this contact by phone or SMS only';
            pd.nextActionWhy   = 'HasOptedOutOfEmail is true. Email sends are suppressed.';
            pd.nextActionPrimaryLabel = null;
            return;
        }

        // Rule 4 — Open opportunity
        OpportunityContactRole openRole = firstOpenOpp(roles);
        if (openRole != null) {
            pd.nextActionText         = 'Follow up on ' + openRole.Opportunity.Name;
            pd.nextActionWhy          = 'Active deal at ' + openRole.Opportunity.StageName + '.';
            pd.nextActionPrimaryLabel = 'Open opportunity';
            pd.nextActionOppId        = openRole.OpportunityId;
            return;
        }

        // Rule 5 — No recent activity
        if (con.Last_Activity_DateTime__c == null
                || con.Last_Activity_DateTime__c < Datetime.now().addDays(-60)) {
            pd.nextActionText  = 'No recent contact — log an interaction or schedule a follow-up';
            pd.nextActionWhy   = con.Last_Activity_DateTime__c == null
                ? 'No activity recorded on this contact.'
                : 'Last activity was more than 60 days ago.';
            pd.nextActionPrimaryLabel = null;
            return;
        }

        // Default
        pd.nextActionText  = 'Stay in touch — log your last interaction with ' + con.FirstName;
        pd.nextActionWhy   = null;
        pd.nextActionPrimaryLabel = null;
    }

    // ── Deals and service ────────────────────────────────────────────────────

    private static List<DealRow> buildDeals(
        List<OpportunityContactRole> roles,
        List<Case> cases,
        List<Quote> quotes
    ) {
        List<DealRow> rows = new List<DealRow>();

        for (OpportunityContactRole r : roles) {
            DealRow row = new DealRow();
            row.recordId  = r.OpportunityId;
            row.recordUrl = '/lightning/r/Opportunity/' + r.OpportunityId + '/view';
            row.label     = r.Opportunity.Name;
            row.type      = oppType(r.Opportunity.RecordType?.DeveloperName);
            row.status    = r.Opportunity.StageName;
            row.chipClass = oppChipClass(r.Opportunity.StageName, r.Opportunity.IsWon, r.Opportunity.IsClosed);
            row.value     = r.Opportunity.Amount != null
                ? '$' + String.valueOf(r.Opportunity.Amount.setScale(0, RoundingMode.HALF_UP)
                    .toPlainString()) : '—';
            rows.add(row);
        }

        for (Case c : cases) {
            DealRow row = new DealRow();
            row.recordId  = c.Id;
            row.recordUrl = '/lightning/r/Case/' + c.Id + '/view';
            row.label     = c.CaseNumber;
            row.type      = String.isNotBlank(c.Type) ? c.Type : 'Case';
            row.status    = c.Status;
            row.chipClass = caseChipClass(c.Status);
            row.value     = 'Covered';
            rows.add(row);
        }

        for (Quote q : quotes) {
            DealRow row = new DealRow();
            row.recordId  = q.Id;
            row.recordUrl = '/lightning/r/Quote/' + q.Id + '/view';
            row.label     = q.Name;
            row.type      = 'Quote';
            row.status    = q.Status;
            row.chipClass = quoteChipClass(q.Status);
            row.value     = q.TotalPrice != null
                ? '$' + String.valueOf(q.TotalPrice.setScale(0, RoundingMode.HALF_UP)
                    .toPlainString()) : '—';
            rows.add(row);
        }

        return rows;
    }

    // ── Household ────────────────────────────────────────────────────────────

    private static List<HouseholdMember> buildHousehold(Id selfId, Id accountId) {
        List<HouseholdMember> members = new List<HouseholdMember>();
        for (Contact c : [
            SELECT Id, Name, FirstName, LastName, Title
            FROM Contact
            WHERE AccountId = :accountId AND Id != :selfId
            WITH SECURITY_ENFORCED
            ORDER BY Name
            LIMIT 10
        ]) {
            HouseholdMember m = new HouseholdMember();
            m.contactId = c.Id;
            m.recordUrl = '/lightning/r/Contact/' + c.Id + '/view';
            m.name      = c.Name;
            m.subtitle  = String.isNotBlank(c.Title) ? c.Title : 'Contact';
            m.initials  = initials(c.FirstName, c.LastName);
            members.add(m);
        }
        return members;
    }

    private static String buildLtv(Id accountId) {
        AggregateResult ar = [
            SELECT SUM(Amount) ltv
            FROM Opportunity
            WHERE AccountId = :accountId AND IsWon = true
            WITH SECURITY_ENFORCED
        ];
        Decimal ltv = (Decimal) ar.get('ltv');
        if (ltv == null || ltv == 0) return null;
        return '$' + String.valueOf(ltv.setScale(0, RoundingMode.HALF_UP).toPlainString());
    }

    // ── Activity ─────────────────────────────────────────────────────────────

    private static List<ActivityItem> buildActivity(Id contactId) {
        List<ActivityItem> items = new List<ActivityItem>();

        for (Task t : [
            SELECT Subject, ActivityDate, Description
            FROM Task
            WHERE WhoId = :contactId
            WITH SECURITY_ENFORCED
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 5
        ]) {
            ActivityItem a = new ActivityItem();
            a.subject     = t.Subject;
            a.dateText    = t.ActivityDate != null ? t.ActivityDate.format() : '';
            a.description = t.Description;
            items.add(a);
        }

        for (Event e : [
            SELECT Subject, ActivityDateTime, Description
            FROM Event
            WHERE WhoId = :contactId
            WITH SECURITY_ENFORCED
            ORDER BY ActivityDateTime DESC NULLS LAST
            LIMIT 5
        ]) {
            ActivityItem a = new ActivityItem();
            a.subject     = e.Subject;
            a.dateText    = e.ActivityDateTime != null
                ? e.ActivityDateTime.format() : '';
            a.description = e.Description;
            items.add(a);
        }

        items.sort(new ActivitySorter());
        List<ActivityItem> limited = new List<ActivityItem>();
        for (Integer i = 0; i < Math.min(6, items.size()); i++) {
            limited.add(items[i]);
        }
        return limited;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static String initials(String firstName, String lastName) {
        String f = String.isNotBlank(firstName) ? firstName.substring(0, 1).toUpperCase() : '';
        String l = String.isNotBlank(lastName)  ? lastName.substring(0, 1).toUpperCase()  : '';
        return f + l;
    }

    private static String location(String city, String state) {
        if (String.isNotBlank(city) && String.isNotBlank(state)) return city + ', ' + state;
        if (String.isNotBlank(city))  return city;
        if (String.isNotBlank(state)) return state;
        return null;
    }

    private static String emailStatus(Contact con) {
        if (con.IsEmailBounced)    return 'Bounced';
        if (con.HasOptedOutOfEmail) return 'Opted Out';
        return 'Subscribed';
    }

    private static String commsChipLabel(Contact con) {
        Boolean emailOk = !con.HasOptedOutOfEmail && !con.IsEmailBounced;
        if (con.SMS_Consent__c && emailOk) return 'Reachable on all channels';
        if (con.SMS_Consent__c)            return 'SMS and phone only';
        if (emailOk)                       return 'Email and phone only';
        return 'Phone only';
    }

    private static String commsChipClass(Contact con) {
        Boolean emailOk = !con.HasOptedOutOfEmail && !con.IsEmailBounced;
        if (con.SMS_Consent__c && emailOk) return 'chip-green';
        if (con.SMS_Consent__c || emailOk) return 'chip-amber';
        return 'chip-red';
    }

    private static Boolean anyPrimary(List<OpportunityContactRole> roles) {
        for (OpportunityContactRole r : roles) { if (r.IsPrimary) return true; }
        return false;
    }

    private static Boolean anyClosedWon(List<OpportunityContactRole> roles) {
        for (OpportunityContactRole r : roles) { if (r.Opportunity.IsWon) return true; }
        return false;
    }

    private static Case firstOpenCase(List<Case> cases) {
        for (Case c : cases) {
            if (c.Status != 'Closed') return c;
        }
        return null;
    }

    private static OpportunityContactRole firstOpenOpp(List<OpportunityContactRole> roles) {
        for (OpportunityContactRole r : roles) {
            if (!r.Opportunity.IsClosed) return r;
        }
        return null;
    }

    private static String oppType(String devName) {
        if ('Design_Build'.equals(devName)) return 'Design Build';
        if ('UMB'.equals(devName))          return 'UpgradeMyBackyard';
        return String.isNotBlank(devName) ? devName : 'Opportunity';
    }

    private static String oppChipClass(String stage, Boolean isWon, Boolean isClosed) {
        if (isWon)    return 'chip-green';
        if (isClosed) return 'chip-red';
        String s = stage != null ? stage.toLowerCase() : '';
        if (s.contains('quote') || s.contains('proposal') || s.contains('design agreement'))
            return 'chip-amber';
        return 'chip-slate';
    }

    private static String caseChipClass(String status) {
        if (status == null) return 'chip-slate';
        String s = status.toLowerCase();
        if (s == 'closed')      return 'chip-green';
        if (s == 'escalated')   return 'chip-red';
        return 'chip-amber';
    }

    private static String quoteChipClass(String status) {
        if (status == null) return 'chip-slate';
        String s = status.toLowerCase();
        if (s == 'accepted')  return 'chip-green';
        if (s == 'rejected')  return 'chip-red';
        if (s == 'presented') return 'chip-amber';
        return 'chip-slate';
    }

    private class ActivitySorter implements Comparator<ActivityItem> {
        public Integer compare(ActivityItem a, ActivityItem b) {
            if (a.dateText == b.dateText) return 0;
            if (a.dateText == null) return 1;
            if (b.dateText == null) return -1;
            return b.dateText.compareTo(a.dateText);
        }
    }
}
