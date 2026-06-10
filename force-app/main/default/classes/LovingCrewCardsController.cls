/**
 * LovingCrewCardsController
 * Crews grouped by Service Division (Production Landscape / Lawn / Aqua) for the
 * Field Services Crew Optimization tab. Reads Crew__c live; no hardcoded data.
 */
public with sharing class LovingCrewCardsController {
    public class CrewDto {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String division;
        @AuraEnabled public String crewType;
        @AuraEnabled public String territory;
        @AuraEnabled public String foreman;
        @AuraEnabled public Integer headcount;
        @AuraEnabled public Decimal capacityHours;
        @AuraEnabled public Boolean active;
    }
    @AuraEnabled(cacheable=true)
    public static List<CrewDto> getCrews() {
        List<CrewDto> out = new List<CrewDto>();
        if (!Schema.getGlobalDescribe().containsKey('Crew__c')) { return out; }
        for (Crew__c c : [
            SELECT Id, Name, Service_Line__c, Crew_Type__c, Service_Territory__c,
                   Foreman__r.Name, Headcount__c, Crew_Size__c, Weekly_Capacity_Hours__c, Active__c
            FROM Crew__c
            WHERE Active__c = true
            ORDER BY Service_Line__c NULLS LAST, Name
        ]) {
            CrewDto d = new CrewDto();
            d.id = c.Id;
            d.name = c.Name;
            // Map the existing Service Line to the console division grouping.
            String sl = c.Service_Line__c;
            if (sl == 'Landscape') { d.division = 'Production Landscape'; }
            else if (sl == 'Lawn') { d.division = 'Lawn'; }
            else if (sl == 'Aqua' || c.Crew_Type__c == 'Aqua') { d.division = 'Aqua'; }
            else { d.division = String.isBlank(sl) ? 'Unassigned' : sl; }
            d.crewType = c.Crew_Type__c;
            d.territory = c.Service_Territory__c;
            d.foreman = (c.Foreman__r != null) ? c.Foreman__r.Name : '';
            d.headcount = (c.Headcount__c != null) ? Integer.valueOf(c.Headcount__c)
                          : (c.Crew_Size__c != null ? Integer.valueOf(c.Crew_Size__c) : null);
            d.capacityHours = c.Weekly_Capacity_Hours__c;
            d.active = c.Active__c;
            out.add(d);
        }
        return out;
    }
}