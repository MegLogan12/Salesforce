/**
 * HomeownerAccountCmdController
 * Returns all data needed for the homeownerAccountCommandCenter LWC component
 * displayed on the LOVING_Account_Homeowner_Record_Page.
 */
public with sharing class HomeownerAccountCmdController {

    public class CommandData {
        @AuraEnabled public AccountInfo         account      { get; set; }
        @AuraEnabled public List<OppRow>        opps         { get; set; }
        @AuraEnabled public List<ActivityRow>   activities   { get; set; }
        @AuraEnabled public List<LeadRow>       leads        { get; set; }
        @AuraEnabled public List<CaseRow>       cases        { get; set; }
    }

    public class AccountInfo {
        @AuraEnabled public String id            { get; set; }
        @AuraEnabled public String name          { get; set; }
        @AuraEnabled public String phone         { get; set; }
        @AuraEnabled public String email         { get; set; }
        @AuraEnabled public String billingStreet { get; set; }
        @AuraEnabled public String billingCity   { get; set; }
        @AuraEnabled public String billingState  { get; set; }
        @AuraEnabled public String ownerId       { get; set; }
        @AuraEnabled public String ownerName     { get; set; }
    }

    public class OppRow {
        @AuraEnabled public String  id         { get; set; }
        @AuraEnabled public String  name       { get; set; }
        @AuraEnabled public String  type       { get; set; }
        @AuraEnabled public String  stageName  { get; set; }
        @AuraEnabled public Decimal amount     { get; set; }
        @AuraEnabled public String  closeDate  { get; set; }
        @AuraEnabled public String  url        { get; set; }
    }

    public class ActivityRow {
        @AuraEnabled public String id           { get; set; }
        @AuraEnabled public String subject      { get; set; }
        @AuraEnabled public String activityDate { get; set; }
        @AuraEnabled public String status       { get; set; }
        @AuraEnabled public String whoId        { get; set; }
        @AuraEnabled public String whoName      { get; set; }
        @AuraEnabled public String url          { get; set; }
    }

    public class LeadRow {
        @AuraEnabled public String id         { get; set; }
        @AuraEnabled public String name       { get; set; }
        @AuraEnabled public String status     { get; set; }
        @AuraEnabled public String leadSource { get; set; }
        @AuraEnabled public String url        { get; set; }
    }

    public class CaseRow {
        @AuraEnabled public String id         { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String status     { get; set; }
        @AuraEnabled public String subject    { get; set; }
        @AuraEnabled public String priority   { get; set; }
        @AuraEnabled public String url        { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static CommandData getCommandData(Id accountId) {
        CommandData result = new CommandData();

        // ── Account record ───────────────────────────────────────────────────
        Account acct = [
            SELECT Id, Name, Phone, PersonEmail, BillingStreet, BillingCity,
                   BillingState, OwnerId, Owner.Name
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        AccountInfo ai  = new AccountInfo();
        ai.id            = acct.Id;
        ai.name          = acct.Name;
        ai.phone         = acct.Phone;
        ai.email         = acct.PersonEmail;
        ai.billingStreet = acct.BillingStreet;
        ai.billingCity   = acct.BillingCity;
        ai.billingState  = acct.BillingState;
        ai.ownerId       = acct.OwnerId;
        ai.ownerName     = acct.Owner?.Name;
        result.account   = ai;

        // ── Open Opportunities ───────────────────────────────────────────────
        result.opps = new List<OppRow>();
        for (Opportunity opp : [
            SELECT Id, Name, Type, StageName, Amount, CloseDate
            FROM Opportunity
            WHERE AccountId = :accountId
              AND IsClosed   = false
            ORDER BY CloseDate ASC
            LIMIT 25
        ]) {
            OppRow row   = new OppRow();
            row.id        = opp.Id;
            row.name      = opp.Name;
            row.type      = opp.Type;
            row.stageName = opp.StageName;
            row.amount    = opp.Amount;
            row.closeDate = opp.CloseDate != null ? String.valueOf(opp.CloseDate) : null;
            row.url       = '/lightning/r/Opportunity/' + opp.Id + '/view';
            result.opps.add(row);
        }

        // ── Activity / Tasks ─────────────────────────────────────────────────
        result.activities = new List<ActivityRow>();
        List<Id> oppIds   = new List<Id>();
        for (OppRow r : result.opps) {
            oppIds.add(r.id);
        }

        Set<Id> whatIds = new Set<Id>{ accountId };
        whatIds.addAll(oppIds);

        for (Task t : [
            SELECT Id, Subject, ActivityDate, Status, WhoId, Who.Name
            FROM Task
            WHERE WhatId IN :whatIds
              AND IsClosed = false
            ORDER BY ActivityDate ASC NULLS LAST
            LIMIT 25
        ]) {
            ActivityRow row  = new ActivityRow();
            row.id            = t.Id;
            row.subject       = t.Subject;
            row.activityDate  = t.ActivityDate != null ? String.valueOf(t.ActivityDate) : null;
            row.status        = t.Status;
            row.whoId         = t.WhoId;
            row.whoName       = t.Who?.Name;
            row.url           = '/lightning/r/Task/' + t.Id + '/view';
            result.activities.add(row);
        }

        // ── Leads ─────────────────────────────────────────────────────────
        result.leads = new List<LeadRow>();
        for (Lead l : [
            SELECT Id, Name, Status, LeadSource
            FROM Lead
            WHERE ConvertedAccountId = :accountId
              AND IsConverted         = false
            ORDER BY CreatedDate DESC
            LIMIT 25
        ]) {
            LeadRow row  = new LeadRow();
            row.id        = l.Id;
            row.name      = l.Name;
            row.status    = l.Status;
            row.leadSource = l.LeadSource;
            row.url       = '/lightning/r/Lead/' + l.Id + '/view';
            result.leads.add(row);
        }

        // ── Cases ─────────────────────────────────────────────────────────
        result.cases = new List<CaseRow>();
        for (Case c : [
            SELECT Id, CaseNumber, Status, Subject, Priority
            FROM Case
            WHERE AccountId = :accountId
              AND Status     != 'Closed'
            ORDER BY CreatedDate DESC
            LIMIT 25
        ]) {
            CaseRow row  = new CaseRow();
            row.id        = c.Id;
            row.caseNumber = c.CaseNumber;
            row.status    = c.Status;
            row.subject   = c.Subject;
            row.priority  = c.Priority;
            row.url       = '/lightning/r/Case/' + c.Id + '/view';
            result.cases.add(row);
        }

        return result;
    }
}
