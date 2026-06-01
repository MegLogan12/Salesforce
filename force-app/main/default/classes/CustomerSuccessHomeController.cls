/**
 * CustomerSuccessHomeController
 * Backend controller for the customerSuccessConsoleHome LWC — the home page
 * of the Customer Success Service Console.
 *
 * Focuses on warranty and service cases, escalations, resolution metrics,
 * and overdue follow-up tasks for the CS team.
 */
public with sharing class CustomerSuccessHomeController {

    public class HomeData {
        @AuraEnabled public KpiData       kpis           { get; set; }
        @AuraEnabled public List<CaseRow> recentCases    { get; set; }
        @AuraEnabled public List<TaskRow> overdueFollowUps { get; set; }
    }

    public class KpiData {
        @AuraEnabled public Integer openCases          { get; set; }
        @AuraEnabled public Integer escalatedCases     { get; set; }
        @AuraEnabled public Decimal avgResolutionDays  { get; set; }
        @AuraEnabled public Integer warrantyCases      { get; set; }
    }

    public class CaseRow {
        @AuraEnabled public String  id          { get; set; }
        @AuraEnabled public String  caseNumber  { get; set; }
        @AuraEnabled public String  subject     { get; set; }
        @AuraEnabled public String  status      { get; set; }
        @AuraEnabled public String  priority    { get; set; }
        @AuraEnabled public Boolean isEscalated { get; set; }
        @AuraEnabled public String  type        { get; set; }
        @AuraEnabled public String  accountName { get; set; }
        @AuraEnabled public String  createdDate { get; set; }
        @AuraEnabled public String  closedDate  { get; set; }
        @AuraEnabled public Boolean isClosed    { get; set; }
        @AuraEnabled public String  url         { get; set; }
    }

    public class TaskRow {
        @AuraEnabled public String id           { get; set; }
        @AuraEnabled public String subject      { get; set; }
        @AuraEnabled public String activityDate { get; set; }
        @AuraEnabled public String status       { get; set; }
        @AuraEnabled public String ownerName    { get; set; }
        @AuraEnabled public String relatedTo    { get; set; }
        @AuraEnabled public String url          { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static HomeData getHomeData() {
        HomeData result = new HomeData();

        // ── KPIs ─────────────────────────────────────────────────────────────
        KpiData kpis = new KpiData();

        // Total open cases
        kpis.openCases = [
            SELECT COUNT() FROM Case WHERE Status != 'Closed'
        ];

        // Escalated open cases
        kpis.escalatedCases = [
            SELECT COUNT()
            FROM Case
            WHERE Status      != 'Closed'
              AND IsEscalated  = true
        ];

        // Average resolution time (days) for cases closed in the last 90 days
        AggregateResult[] avgRes = [
            SELECT AVG(ClosedDate) avgClosed, AVG(CreatedDate) avgCreated
            FROM Case
            WHERE IsClosed     = true
              AND ClosedDate   >= LAST_N_DAYS:90
        ];
        if (avgRes[0].get('avgClosed') != null && avgRes[0].get('avgCreated') != null) {
            DateTime avgClosed  = (DateTime) avgRes[0].get('avgClosed');
            DateTime avgCreated = (DateTime) avgRes[0].get('avgCreated');
            Long diffMs         = avgClosed.getTime() - avgCreated.getTime();
            kpis.avgResolutionDays = ((Decimal) diffMs / 86400000L).setScale(1);
        } else {
            kpis.avgResolutionDays = 0;
        }

        // Warranty / service cases (Type = 'Warranty' OR 'Service')
        kpis.warrantyCases = [
            SELECT COUNT()
            FROM Case
            WHERE Status   != 'Closed'
              AND (Type     = 'Warranty' OR Type = 'Service')
        ];

        result.kpis = kpis;

        // ── Recent cases (warranty + service types first, then all open) ─────
        result.recentCases = new List<CaseRow>();
        for (Case c : [
            SELECT Id, CaseNumber, Subject, Status, Priority,
                   IsEscalated, Type, Account.Name, CreatedDate, ClosedDate, IsClosed
            FROM Case
            WHERE Status != 'Closed'
            ORDER BY IsEscalated DESC, Priority DESC, CreatedDate DESC
            LIMIT 20
        ]) {
            CaseRow row    = new CaseRow();
            row.id          = c.Id;
            row.caseNumber  = c.CaseNumber;
            row.subject     = c.Subject;
            row.status      = c.Status;
            row.priority    = c.Priority;
            row.isEscalated = c.IsEscalated;
            row.type        = c.Type;
            row.accountName = c.Account?.Name;
            row.createdDate = c.CreatedDate != null
                ? c.CreatedDate.format('M/d/yyyy')
                : null;
            row.closedDate  = c.ClosedDate != null
                ? c.ClosedDate.format('M/d/yyyy')
                : null;
            row.isClosed    = c.IsClosed;
            row.url         = '/lightning/r/Case/' + c.Id + '/view';
            result.recentCases.add(row);
        }

        // ── Overdue follow-up tasks ───────────────────────────────────────────
        result.overdueFollowUps = new List<TaskRow>();
        for (Task t : [
            SELECT Id, Subject, ActivityDate, Status, OwnerId, Owner.Name,
                   What.Name
            FROM Task
            WHERE IsClosed     = false
              AND ActivityDate  < TODAY
            ORDER BY ActivityDate ASC
            LIMIT 25
        ]) {
            TaskRow row    = new TaskRow();
            row.id          = t.Id;
            row.subject     = t.Subject;
            row.activityDate = t.ActivityDate != null
                ? String.valueOf(t.ActivityDate)
                : null;
            row.status      = t.Status;
            row.ownerName   = t.Owner?.Name;
            row.relatedTo   = t.What?.Name;
            row.url         = '/lightning/r/Task/' + t.Id + '/view';
            result.overdueFollowUps.add(row);
        }

        return result;
    }
}
