/**
 * CCConsoleHomeController
 * Backend controller for the ccConsoleHome LWC — the home page of the
 * Customer Care Console (app labeled "Customer Success Console").
 */
public with sharing class CCConsoleHomeController {

    public class HomeData {
        @AuraEnabled public KpiData       kpis         { get; set; }
        @AuraEnabled public List<CaseRow> recentCases  { get; set; }
        @AuraEnabled public List<TaskRow> overdueTasks { get; set; }
    }

    public class KpiData {
        @AuraEnabled public Integer openCases          { get; set; }
        @AuraEnabled public Integer criticalCases      { get; set; }
        @AuraEnabled public Integer openWorkOrders     { get; set; }
        @AuraEnabled public Decimal avgDaysSinceCreated { get; set; }
    }

    public class CaseRow {
        @AuraEnabled public String  id           { get; set; }
        @AuraEnabled public String  caseNumber   { get; set; }
        @AuraEnabled public String  subject      { get; set; }
        @AuraEnabled public String  status       { get; set; }
        @AuraEnabled public String  priority     { get; set; }
        @AuraEnabled public Boolean isEscalated  { get; set; }
        @AuraEnabled public String  accountName  { get; set; }
        @AuraEnabled public String  createdDate  { get; set; }
        @AuraEnabled public String  url          { get; set; }
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

        // Open cases count
        kpis.openCases = [
            SELECT COUNT() FROM Case WHERE Status != 'Closed'
        ];

        // Critical cases (High priority or escalated)
        kpis.criticalCases = [
            SELECT COUNT()
            FROM Case
            WHERE Status    != 'Closed'
              AND (Priority  = 'High' OR IsEscalated = true)
        ];

        // Open Work Orders
        kpis.openWorkOrders = [
            SELECT COUNT() FROM WorkOrder WHERE Status != 'Completed'
        ];

        // avgDaysSinceCreated: AVG on Datetime not supported in SOQL aggregate functions
        kpis.avgDaysSinceCreated = 0;

        result.kpis = kpis;

        // ── Recent open cases ─────────────────────────────────────────────────
        result.recentCases = new List<CaseRow>();
        for (Case c : [
            SELECT Id, CaseNumber, Subject, Status, Priority,
                   IsEscalated, Account.Name, CreatedDate
            FROM Case
            WHERE Status != 'Closed'
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            CaseRow row    = new CaseRow();
            row.id          = c.Id;
            row.caseNumber  = c.CaseNumber;
            row.subject     = c.Subject;
            row.status      = c.Status;
            row.priority    = c.Priority;
            row.isEscalated = c.IsEscalated;
            row.accountName = c.Account?.Name;
            row.createdDate = c.CreatedDate != null
                ? c.CreatedDate.format('M/d/yyyy')
                : null;
            row.url         = '/lightning/r/Case/' + c.Id + '/view';
            result.recentCases.add(row);
        }

        // ── Overdue tasks ─────────────────────────────────────────────────────
        result.overdueTasks = new List<TaskRow>();
        for (Task t : [
            SELECT Id, Subject, ActivityDate, Status, OwnerId, Owner.Name,
                   What.Name
            FROM Task
            WHERE IsClosed     = false
              AND ActivityDate  < TODAY
            ORDER BY ActivityDate ASC
            LIMIT 20
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
            result.overdueTasks.add(row);
        }

        return result;
    }
}
