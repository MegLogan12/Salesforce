/**
 * WorkOrderPipelineController
 * Backs the Work Order Pipeline View kanban LWC.
 * Spec reference: Section 15.1 (Pipeline View kanban).
 *
 * Phase 4 fix: now queries Work_Order__c (custom object) with correct field names.
 * Previously queried standard WorkOrder, which caused compile-time failures and
 * empty kanban columns because the page serves Work_Order__c record IDs.
 */
public with sharing class WorkOrderPipelineController {

    public class WoCard {
        @AuraEnabled public Id id;
        @AuraEnabled public String woNumber;
        @AuraEnabled public String url;
        @AuraEnabled public String lotName;
        @AuraEnabled public String builder;
        @AuraEnabled public String foreman;
        @AuraEnabled public String scope;
        @AuraEnabled public Date releaseDate;
        @AuraEnabled public String takeoffStatus;
        @AuraEnabled public String status;
        @AuraEnabled public String cardClass;
        @AuraEnabled public Decimal poAmount;
        @AuraEnabled public Integer daysUntilStart;
    }

    public class StageColumn {
        @AuraEnabled public String stage;
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
        @AuraEnabled public List<WoCard> cards;
    }

    @AuraEnabled(cacheable=true)
    public static List<StageColumn> getPipeline() {
        Map<String, StageColumn> byStage = new Map<String, StageColumn>();

        String[] stages = new String[]{
            'New', 'Pending Scheduling', 'Scheduled', 'Takeoff Complete',
            'Site Ready', 'In Progress', 'QI', 'Closed', 'Ready to Invoice', 'Invoiced'
        };
        for (String s : stages) {
            StageColumn c = new StageColumn();
            c.stage = s;
            c.label = s;
            c.count = 0;
            c.cards = new List<WoCard>();
            byStage.put(s, c);
        }

        try {
            for (Work_Order__c wo : [
                SELECT Id, Name, Status__c, Pipeline_Bucket__c, Takeoff_Status__c,
                       Lot__r.Name, Builder_Market_Account__r.Name, FM_Assignment__r.Name,
                       Notes__c, Total_Cost__c, Requested_Install_Date__c
                FROM Work_Order__c
                ORDER BY Requested_Install_Date__c NULLS LAST
                LIMIT 500
            ]) {
                WoCard card = buildCard(wo);
                String stageKey = mapStage(wo);
                if (stageKey != null && byStage.containsKey(stageKey)) {
                    byStage.get(stageKey).cards.add(card);
                    byStage.get(stageKey).count++;
                }
            }
        } catch (Exception e) {
            // Return empty columns on error
        }

        return byStage.values();
    }

    @TestVisible
    private static WoCard buildCard(Work_Order__c wo) {
        WoCard c = new WoCard();
        c.id = wo.Id;
        c.woNumber = wo.Name;
        c.url = '/lightning/r/Work_Order__c/' + wo.Id + '/view';
        c.lotName = wo.Lot__r != null ? wo.Lot__r.Name : '';
        c.builder = wo.Builder_Market_Account__r != null ? wo.Builder_Market_Account__r.Name : '';
        c.foreman = wo.FM_Assignment__r != null ? wo.FM_Assignment__r.Name : '';
        c.scope = wo.Notes__c;
        c.releaseDate = wo.Requested_Install_Date__c;
        c.takeoffStatus = wo.Takeoff_Status__c;
        c.status = wo.Status__c;
        c.poAmount = wo.Total_Cost__c;
        c.daysUntilStart = wo.Requested_Install_Date__c == null ? null : (Integer)(Date.today().daysBetween(wo.Requested_Install_Date__c));
        c.cardClass = computeCardClass(wo);
        return c;
    }

    @TestVisible
    private static String computeCardClass(Work_Order__c wo) {
        if (wo.Status__c == 'Closed' || wo.Status__c == 'Approved' || wo.Status__c == 'Invoiced') {
            return 'wo-card-green';
        }
        if (wo.Takeoff_Status__c == 'Returned') {
            return 'wo-card-red';
        }
        if (wo.Pipeline_Bucket__c == '30 Days' && (wo.Takeoff_Status__c == null || wo.Takeoff_Status__c == 'Not Started')) {
            return 'wo-card-amber';
        }
        return 'wo-card-green';
    }

    @TestVisible
    private static String mapStage(Work_Order__c wo) {
        String s = wo.Status__c;
        String b = wo.Pipeline_Bucket__c;
        if (s == 'Closed' || s == 'Approved' || s == 'Closeout Approved' || s == 'Cancelled') return 'Closed';
        if (s == 'Invoiced' || s == 'Paid') return 'Invoiced';
        if (s == 'Ready for Invoice') return 'Ready to Invoice';
        if (s == 'FM QI Review' || s == 'Pending Closeout' || s == 'Pending Approval'
                || s == 'Pending FM Review' || s == 'Pending QI'
                || s == 'QI Passed' || s == 'QI Failed'
                || s == 'Need Further Info (NFI)' || s == 'NFI'
                || s == 'Field Complete') {
            return 'QI';
        }
        if (s == 'In Progress' || s == 'Dispatched') return 'In Progress';
        if (s == 'Scheduled' || b == 'Scheduled') return 'Scheduled';
        if (s == 'Clear for Schedule' || s == 'Site Readiness Check'
                || s == 'Site Readiness Passed' || s == 'Site Not Ready'
                || s == 'Site Readiness Pending' || b == 'Clear to Schedule') {
            return 'Site Ready';
        }
        if (s == 'Takeoff Complete' || s == 'Ready to Schedule' || s == 'Ready for Scheduling'
                || s == 'Pending Scheduling'
                || b == 'Ready to Schedule' || b == 'Takeoff In Progress') {
            return 'Takeoff Complete';
        }
        if (s == 'Pending Takeoff' || s == 'Takeoff Scheduled' || s == 'Takeoff In Progress'
                || b == '30 Days' || b == '60+ Days') {
            return 'Pending Scheduling';
        }
        return 'New';
    }
}