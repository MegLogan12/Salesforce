/**
 * OneOnOnePrepController
 *
 * Backs the 1:1 Prep View Lightning Component.
 * Pulls live data from across Salesforce and shows it in a single screen
 * so the manager does not have to bounce around to assemble context.
 *
 * Spec reference: Section 20.4.
 */
public with sharing class OneOnOnePrepController {

    public class PrepView {
        @AuraEnabled public List<String> suggestedTopics;
        @AuraEnabled public List<Action_Item__c> openActionItems;
        @AuraEnabled public List<TrendPoint> performanceTrend;
        @AuraEnabled public String existingNotes;
        @AuraEnabled public Id oneOnOneId;
        @AuraEnabled public String managerName;
        @AuraEnabled public String directReportName;
    }

    public class TrendPoint {
        @AuraEnabled public String metric;
        @AuraEnabled public Decimal value;
        @AuraEnabled public Date weekOf;
    }

    @AuraEnabled(cacheable=true)
    public static PrepView getPrepView(Id oneOnOneId) {
        PrepView v = new PrepView();
        v.oneOnOneId = oneOnOneId;
        v.suggestedTopics = new List<String>();
        v.openActionItems = new List<Action_Item__c>();
        v.performanceTrend = new List<TrendPoint>();

        if (oneOnOneId == null) return v;

        OneOnOne__c o = [
            SELECT Id, Manager__c, Direct_Report__c, Topics_Discussed__c,
                   Manager__r.Name, Direct_Report__r.Name
            FROM OneOnOne__c
            WHERE Id = :oneOnOneId
            LIMIT 1
        ];
        v.managerName = o.Manager__r.Name;
        v.directReportName = o.Direct_Report__r.Name;
        v.existingNotes = o.Topics_Discussed__c;

        // Pull open action items from previous 1:1s with same direct report
        v.openActionItems = [
            SELECT Id, Description__c, Owner_User__c, Owner_User__r.Name,
                   Due_Date__c, Status__c, Completed_Date__c
            FROM Action_Item__c
            WHERE OneOnOne__r.Direct_Report__c = :o.Direct_Report__c
            AND Status__c != 'Done'
            ORDER BY Due_Date__c ASC
            LIMIT 50
        ];

        // Suggested topics: query past week's events for this direct report
        v.suggestedTopics = generateSuggestedTopics(o.Direct_Report__c);

        // Performance trend: variance, FJ rate, photo compliance, QI avg over 12 weeks
        v.performanceTrend = generateTrend(o.Direct_Report__c);

        return v;
    }

    private static List<String> generateSuggestedTopics(Id directReportId) {
        List<String> topics = new List<String>();
        if (directReportId == null) return topics;

        DateTime weekAgo = DateTime.now().addDays(-7);

        // Red 2 PM checks
        Integer redChecks = [
            SELECT COUNT()
            FROM WorkOrder
            WHERE Field_Manager__c = :directReportId
            AND Job_Health__c = 'Red'
            AND Health_Check_Responded_At__c >= :weekAgo
        ];
        if (redChecks > 0) {
            topics.add('Discuss ' + redChecks + ' Red 2PM checks from past week');
        }

        // FJ creations stub - field will be added to standard WorkOrder in next wave
        Integer fjCount = 0;

        // Pending Hire Requests
        Integer pendingHires = [
            SELECT COUNT()
            FROM Hire_Request__c
            WHERE Submitted_By_FM__c = :directReportId
            AND Status__c IN ('Submitted', 'Under VP Review', 'Under COO Review')
        ];
        if (pendingHires > 0) {
            topics.add('Address ' + pendingHires + ' pending Hire Request(s)');
        }

        // QI scores
        if (topics.isEmpty()) {
            topics.add('Review week-over-week variance trends');
            topics.add('Discuss upcoming community launches');
            topics.add('Check on team morale and any blockers');
        }
        return topics;
    }

    private static List<TrendPoint> generateTrend(Id directReportId) {
        List<TrendPoint> trend = new List<TrendPoint>();
        // Stub: in production, compute weekly aggregates
        return trend;
    }

    @AuraEnabled
    public static Id createActionItem(Id oneOnOneId, Id ownerId, String description, Date dueDate) {
        Action_Item__c ai = new Action_Item__c(
            OneOnOne__c = oneOnOneId,
            Owner_User__c = ownerId,
            Description__c = description,
            Due_Date__c = dueDate == null ? Date.today().addDays(7) : dueDate,
            Status__c = 'Open'
        );
        insert ai;
        return ai.Id;
    }

    @AuraEnabled
    public static void saveNotes(Id oneOnOneId, String notes) {
        OneOnOne__c o = new OneOnOne__c(Id = oneOnOneId, Topics_Discussed__c = notes);
        update o;
    }

    @AuraEnabled
    public static void markActionItemDone(Id actionItemId) {
        Action_Item__c ai = new Action_Item__c(
            Id = actionItemId,
            Status__c = 'Done',
            Completed_Date__c = Date.today()
        );
        update ai;
    }
}