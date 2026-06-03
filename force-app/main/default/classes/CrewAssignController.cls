public with sharing class CrewAssignController {

    public class CrewRow {
        @AuraEnabled public Id      crewId;
        @AuraEnabled public String  crewName;
        @AuraEnabled public String  foreman;
        @AuraEnabled public String  crewType;
        @AuraEnabled public String  truckNumber;
        @AuraEnabled public String  vehicle;
        @AuraEnabled public Boolean isAssigned;
    }

    @AuraEnabled(cacheable=true)
    public static List<CrewRow> getTomorrowsCrews(String division) {
        if (!Schema.sObjectType.Crew__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Crew');
        }

        String query = 'SELECT Id, Name, Foreman__r.Name, Crew_Type__c, ' +
                       'Truck_Number__c, Vehicle__c ' +
                       'FROM Crew__c ' +
                       'WHERE Active__c = true ' +
                       'AND Available_For_Scheduling__c = true';

        if (String.isNotBlank(division)) {
            query += ' AND Division__c = :division';
        }

        query += ' ORDER BY Name';

        List<Crew__c> crews = Database.query(query);

        List<CrewRow> rows = new List<CrewRow>();
        for (Crew__c c : crews) {
            CrewRow r = new CrewRow();
            r.crewId      = c.Id;
            r.crewName    = c.Name;
            r.foreman     = (c.Foreman__r != null) ? c.Foreman__r.Name : null;
            r.crewType    = c.Crew_Type__c;
            r.truckNumber = c.Truck_Number__c;
            r.vehicle     = c.Vehicle__c;
            r.isAssigned  = String.isNotBlank(c.Truck_Number__c);
            rows.add(r);
        }
        return rows;
    }

    @AuraEnabled
    public static void assignRig(Id crewId, String truckNumber, String vehicle) {
        if (!Schema.sObjectType.Crew__c.isAccessible() ||
            !Schema.sObjectType.Crew__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient access to update Crew');
        }

        Crew__c c = new Crew__c(
            Id            = crewId,
            Truck_Number__c = truckNumber,
            Vehicle__c     = vehicle
        );
        update c;
    }
}
