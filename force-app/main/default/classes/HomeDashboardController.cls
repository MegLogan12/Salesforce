/**
 * HomeDashboardController
 * Backs the home dashboard widgets shared across the 7 LOVING Lightning Apps.
 * Provides: today's KPIs, open hire requests, this week's 1:1s.
 */
public with sharing class HomeDashboardController {

    public class TodaysKpis {
        @AuraEnabled public Integer activeWorkOrders;
        @AuraEnabled public Integer scheduledToday;
        @AuraEnabled public Integer inProgressToday;
        @AuraEnabled public Integer pendingApproval;
        @AuraEnabled public Integer pendingCloseout;
        @AuraEnabled public Integer openHireRequests;
        @AuraEnabled public Integer thisWeekOneOnOnes;
        @AuraEnabled public Integer openActionItems;
    }

    public class HireRequestRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String hrNumber;
        @AuraEnabled public String url;
        @AuraEnabled public String submittedBy;
        @AuraEnabled public String serviceLine;
        @AuraEnabled public String roleType;
        @AuraEnabled public Decimal totalCost;
        @AuraEnabled public Decimal y1ROI;
        @AuraEnabled public String status;
        @AuraEnabled public Date submittedDate;
    }

    public class OneOnOneRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String url;
        @AuraEnabled public String manager;
        @AuraEnabled public String directReport;
        @AuraEnabled public DateTime meetingDate;
        @AuraEnabled public String status;
    }

    @AuraEnabled(cacheable=true)
    public static TodaysKpis getKpis() {
        TodaysKpis k = new TodaysKpis();
        k.activeWorkOrders = 0;
        k.scheduledToday = 0;
        k.inProgressToday = 0;
        k.pendingApproval = 0;
        k.pendingCloseout = 0;
        k.openHireRequests = 0;
        k.thisWeekOneOnOnes = 0;
        k.openActionItems = 0;

        try {
            k.activeWorkOrders = [SELECT COUNT() FROM WorkOrder WHERE Status NOT IN ('Closed', 'Canceled')];
            k.scheduledToday  = [SELECT COUNT() FROM WorkOrder WHERE Scheduled_Date__c = TODAY AND Status = 'Scheduled'];
            k.inProgressToday = [SELECT COUNT() FROM WorkOrder WHERE Status = 'In Progress'];
            k.pendingApproval = [SELECT COUNT() FROM WorkOrder WHERE Status = 'FM QI Review'];
            k.pendingCloseout = [SELECT COUNT() FROM WorkOrder WHERE Status = 'Pending Closeout'];
        } catch (Exception e) {}

        try {
            k.openHireRequests = [SELECT COUNT() FROM Hire_Request__c WHERE Status__c IN ('Submitted', 'Under VP Review', 'Under COO Review')];
        } catch (Exception e) {}

        try {
            DateTime weekStart = DateTime.newInstance(Date.today(), Time.newInstance(0,0,0,0));
            DateTime weekEnd = weekStart.addDays(7);
            k.thisWeekOneOnOnes = [SELECT COUNT() FROM OneOnOne__c WHERE Meeting_Date__c >= :weekStart AND Meeting_Date__c < :weekEnd];
        } catch (Exception e) {}

        try {
            k.openActionItems = [SELECT COUNT() FROM Action_Item__c WHERE Status__c != 'Done'];
        } catch (Exception e) {}

        return k;
    }

    @AuraEnabled(cacheable=true)
    public static List<HireRequestRow> getOpenHireRequests() {
        List<HireRequestRow> result = new List<HireRequestRow>();
        try {
            for (Hire_Request__c hr : [
                SELECT Id, Name, Service_Line__c, Role_Type__c, Total_Annual_Cost__c, Y1_ROI__c,
                       Status__c, CreatedDate, Submitted_By_FM__r.Name
                FROM Hire_Request__c
                WHERE Status__c IN ('Submitted', 'Under VP Review', 'Under COO Review')
                ORDER BY CreatedDate DESC
                LIMIT 25
            ]) {
                result.add(buildHireRow(hr));
            }
        } catch (Exception e) {}
        return result;
    }

    @TestVisible
    private static HireRequestRow buildHireRow(Hire_Request__c hr) {
        HireRequestRow r = new HireRequestRow();
        r.id = hr.Id;
        r.hrNumber = hr.Name;
        r.url = '/lightning/r/Hire_Request__c/' + hr.Id + '/view';
        r.submittedBy = hr.Submitted_By_FM__r != null ? hr.Submitted_By_FM__r.Name : '';
        r.serviceLine = hr.Service_Line__c;
        r.roleType = hr.Role_Type__c;
        r.totalCost = hr.Total_Annual_Cost__c;
        r.y1ROI = hr.Y1_ROI__c;
        r.status = hr.Status__c;
        r.submittedDate = hr.CreatedDate == null ? null : hr.CreatedDate.date();
        return r;
    }

    @AuraEnabled(cacheable=true)
    public static List<OneOnOneRow> getThisWeekOneOnOnes() {
        List<OneOnOneRow> result = new List<OneOnOneRow>();
        try {
            DateTime weekStart = DateTime.newInstance(Date.today(), Time.newInstance(0,0,0,0));
            DateTime weekEnd = weekStart.addDays(7);
            for (OneOnOne__c o : [
                SELECT Id, Name, Manager__r.Name, Direct_Report__r.Name, Meeting_Date__c, Status__c
                FROM OneOnOne__c
                WHERE Meeting_Date__c >= :weekStart
                AND Meeting_Date__c < :weekEnd
                ORDER BY Meeting_Date__c ASC
                LIMIT 25
            ]) {
                result.add(buildOneOnOneRow(o));
            }
        } catch (Exception e) {}
        return result;
    }

    @TestVisible
    private static OneOnOneRow buildOneOnOneRow(OneOnOne__c o) {
        OneOnOneRow r = new OneOnOneRow();
        r.id = o.Id;
        r.name = o.Name;
        r.url = '/lightning/r/OneOnOne__c/' + o.Id + '/view';
        r.manager = o.Manager__r != null ? o.Manager__r.Name : '';
        r.directReport = o.Direct_Report__r != null ? o.Direct_Report__r.Name : '';
        r.meetingDate = o.Meeting_Date__c;
        r.status = o.Status__c;
        return r;
    }
}