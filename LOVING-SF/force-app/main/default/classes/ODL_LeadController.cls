public with sharing class ODL_LeadController {

    @AuraEnabled(cacheable=true)
    public static List<Lead> getLeadList(String odlPath) {
        String query = 'SELECT Id, Name, ODL_Path__c, LeadSource, Status, ' +
                       'Budget_Range__c, Service_Interest__c, LastActivityDate, ' +
                       'Voicemail_Left__c, Last_Voicemail_Date__c, OwnerId, Owner.Name, ' +
                       'Company ' +
                       'FROM Lead WHERE IsConverted = false';
        if (String.isNotBlank(odlPath)) {
            query += ' AND ODL_Path__c = :odlPath';
        }
        query += ' ORDER BY LastActivityDate DESC NULLS LAST LIMIT 100';
        return Database.query(query);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLeadRecord(Id leadId) {
        Lead l = [
            SELECT Id, Name, ODL_Path__c, LeadSource, Status,
                   Budget_Range__c, Service_Interest__c, Package_Fit__c,
                   Desired_Timeline__c, Project_Vision__c, Decision_Makers__c,
                   Property_Size__c, Preferred_Frequency__c, Start_Window__c,
                   Voicemail_Left__c, Last_Voicemail_Date__c,
                   Phone, Email, Company,
                   OwnerId, Owner.Name, CreatedDate, LastActivityDate
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate, Status, Description,
                   TaskSubtype, CallDisposition
            FROM Task
            WHERE WhoId = :leadId
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 10
        ];

        return new Map<String, Object>{
            'lead'  => l,
            'tasks' => tasks
        };
    }
}
