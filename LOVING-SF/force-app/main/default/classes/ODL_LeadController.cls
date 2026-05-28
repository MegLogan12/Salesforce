public with sharing class ODL_LeadController {

    @AuraEnabled(cacheable=true)
    public static List<Lead> getLeadList(String odlPath) {
        String q = 'SELECT Id, Name, ODL_Path__c, LeadSource, Status, ' +
                   'Budget_Range__c, Service_Interest__c, LastActivityDate, ' +
                   'Voicemail_Left__c, Last_Voicemail_Date__c, OwnerId, Owner.Name, Company, ' +
                   '(SELECT Id, Subject, ActivityDate FROM OpenActivities ' +
                   ' ORDER BY ActivityDate ASC NULLS LAST LIMIT 1), ' +
                   '(SELECT Id, Subject, ActivityDate FROM ActivityHistories ' +
                   ' ORDER BY ActivityDate DESC NULLS LAST LIMIT 1) ' +
                   'FROM Lead WHERE IsConverted = false ' +
                   'AND ODL_Path__c IN (\'UMB\', \'Custom Build\', \'Lawn Care\')';
        if (String.isNotBlank(odlPath)) {
            q += ' AND ODL_Path__c = :odlPath';
        }
        q += ' ORDER BY LastActivityDate DESC NULLS LAST LIMIT 100';
        return Database.query(q);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLeadRecord(Id leadId) {
        Lead l = [
            SELECT Id, Name, ODL_Path__c, LeadSource, Status,
                   Budget_Range__c, Service_Interest__c, Package_Fit__c,
                   Desired_Timeline__c, Project_Vision__c, Decision_Makers__c,
                   Property_Size__c, Preferred_Frequency__c, Start_Window__c,
                   Voicemail_Left__c, Last_Voicemail_Date__c, Site_Visit_Needed__c,
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
            ORDER BY ActivityDate ASC NULLS LAST
            LIMIT 20
        ];

        String campaignName = null;
        List<CampaignMember> cms = [
            SELECT Campaign.Name FROM CampaignMember
            WHERE LeadId = :leadId LIMIT 1
        ];
        if (!cms.isEmpty()) {
            campaignName = cms[0].Campaign.Name;
        }

        return new Map<String, Object>{
            'lead'         => l,
            'tasks'        => tasks,
            'campaignName' => campaignName
        };
    }
}
