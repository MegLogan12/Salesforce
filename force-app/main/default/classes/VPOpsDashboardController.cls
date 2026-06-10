/**
 * VPOpsDashboardController
 * Backend for the vpOpsDashboard LWC.
 * Returns KPI counts: open hire requests, pending 1:1s, open action items,
 * open work orders, and active crew count.
 */
public with sharing class VPOpsDashboardController {

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class HomeDTO {
        @AuraEnabled public Integer openHireRequests;
        @AuraEnabled public Integer pendingOneOnOnes;
        @AuraEnabled public Integer openActionItems;
        @AuraEnabled public Integer openWorkOrders;
        @AuraEnabled public Integer crewCount;
        @AuraEnabled public List<HireRequestRow>  recentHireRequests;
        @AuraEnabled public List<ActionItemRow>   recentActionItems;
    }

    public class HireRequestRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public String createdDateLabel;
    }

    public class ActionItemRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String dueDateLabel;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Boolean isOverdue;
        @AuraEnabled public String statusChip;
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private static String chipClass(String status) {
        if (status == null) return 'chip-neutral';
        String s = status.toLowerCase();
        if (s.contains('open') || s.contains('pending'))    return 'chip-orange';
        if (s.contains('complet') || s.contains('closed'))  return 'chip-green';
        if (s.contains('cancel'))                           return 'chip-neutral';
        return 'chip-blue';
    }

    // ── Main query ────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static HomeDTO getHomeData() {
        try {
            HomeDTO dto = new HomeDTO();

            // KPI: open hire requests
            dto.openHireRequests = [
                SELECT COUNT() FROM Hire_Request__c
                WHERE Status__c NOT IN ('Filled', 'Cancelled', 'Closed')
            ];

            // KPI: pending 1:1s
            dto.pendingOneOnOnes = [
                SELECT COUNT() FROM OneOnOne__c
                WHERE Status__c = 'Pending'
            ];

            // KPI: open action items
            dto.openActionItems = [
                SELECT COUNT() FROM Action_Item__c
                WHERE Status__c NOT IN ('Completed', 'Cancelled', 'Closed')
            ];

            // KPI: open work orders
            dto.openWorkOrders = [
                SELECT COUNT() FROM WorkOrder
                WHERE Status NOT IN ('Completed', 'Cancelled', 'Closed')
            ];

            // KPI: crew count (Status__c not available on Crew__c schema)
            dto.crewCount = [SELECT COUNT() FROM Crew__c];

            // Recent hire requests (5)
            List<HireRequestRow> hrRows = new List<HireRequestRow>();
            for (Hire_Request__c hr : [
                SELECT Id, Name, Status__c, CreatedDate
                FROM Hire_Request__c
                WHERE Status__c NOT IN ('Filled', 'Cancelled', 'Closed')
                ORDER BY CreatedDate DESC
                LIMIT 5
            ]) {
                HireRequestRow r = new HireRequestRow();
                r.id               = hr.Id;
                r.name             = hr.Name;
                r.status           = hr.Status__c != null ? hr.Status__c : '';
                r.priority         = '';
                r.createdDateLabel = hr.CreatedDate != null
                    ? hr.CreatedDate.format('M/d/yyyy')
                    : '';
                hrRows.add(r);
            }
            dto.recentHireRequests = hrRows;

            // Recent open action items (5)
            Date today = Date.today();
            List<ActionItemRow> aiRows = new List<ActionItemRow>();
            for (Action_Item__c ai : [
                SELECT Id, Name, Status__c, Due_Date__c
                FROM Action_Item__c
                WHERE Status__c NOT IN ('Completed', 'Cancelled', 'Closed')
                ORDER BY Due_Date__c ASC NULLS LAST
                LIMIT 5
            ]) {
                ActionItemRow r = new ActionItemRow();
                r.id           = ai.Id;
                r.name         = ai.Name;
                r.status       = ai.Status__c != null ? ai.Status__c : '';
                r.dueDateLabel = ai.Due_Date__c != null
                    ? ai.Due_Date__c.month() + '/' + ai.Due_Date__c.day() + '/' + ai.Due_Date__c.year()
                    : '';
                r.ownerName    = '';
                r.isOverdue    = (ai.Due_Date__c != null && ai.Due_Date__c < today);
                r.statusChip   = chipClass(ai.Status__c);
                aiRows.add(r);
            }
            dto.recentActionItems = aiRows;

            return dto;

        } catch (Exception e) {
            throw new AuraHandledException('Unable to load VP Ops data: ' + e.getMessage());
        }
    }
}
