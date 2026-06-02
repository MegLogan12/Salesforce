/**
 * ForecastingConsoleController
 * Backend for the lovingForecastingConsole LWC (Forecasting & Workforce home page).
 * Returns KPI counts and recent Hire_Request__c / Crew__c records.
 */
public with sharing class ForecastingConsoleController {

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class HomeDTO {
        @AuraEnabled public Integer openHireRequests;
        @AuraEnabled public Integer activeCrew;
        @AuraEnabled public List<HireRequestRow> recentHireRequests;
        @AuraEnabled public List<CrewRow> recentCrews;
    }

    public class HireRequestRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String position;
        @AuraEnabled public String priority;
        @AuraEnabled public String createdDateLabel;
    }

    public class CrewRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String leadForeman;
        @AuraEnabled public String memberCount;
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

            // KPI: crew count (Status__c not available on Crew__c schema)
            dto.activeCrew = [SELECT COUNT() FROM Crew__c];

            // Recent hire requests (last 5)
            List<HireRequestRow> hrRows = new List<HireRequestRow>();
            for (Hire_Request__c hr : [
                SELECT Id, Name, Status__c, CreatedDate
                FROM Hire_Request__c
                ORDER BY CreatedDate DESC
                LIMIT 5
            ]) {
                HireRequestRow r = new HireRequestRow();
                r.id               = hr.Id;
                r.name             = hr.Name;
                r.status           = hr.Status__c != null   ? hr.Status__c   : '';
                r.position = '';
                r.priority = '';
                r.createdDateLabel = hr.CreatedDate != null
                    ? hr.CreatedDate.format('M/d/yyyy')
                    : '';
                hrRows.add(r);
            }
            dto.recentHireRequests = hrRows;

            // Recent active crews (5)
            List<CrewRow> crewRows = new List<CrewRow>();
            for (Crew__c c : [
                SELECT Id, Name FROM Crew__c
                LIMIT 5
            ]) {
                CrewRow r = new CrewRow();
                r.id          = c.Id;
                r.name        = c.Name;
                r.status = '';
                r.leadForeman = '';
                r.memberCount = '0';
                crewRows.add(r);
            }
            dto.recentCrews = crewRows;

            return dto;

        } catch (Exception e) {
            throw new AuraHandledException('Unable to load forecasting data: ' + e.getMessage());
        }
    }
}