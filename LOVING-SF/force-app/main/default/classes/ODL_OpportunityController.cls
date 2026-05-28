public with sharing class ODL_OpportunityController {

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunityList(String odlPath) {
        String query = 'SELECT Id, Name, AccountId, Account.Name, StageName, Amount, ' +
                       'ODL_Path__c, Selected_Package__c, CloseDate, ' +
                       'LastActivityDate, Voicemail_Left__c, Last_Voicemail_Date__c, ' +
                       'OwnerId, Owner.Name ' +
                       'FROM Opportunity WHERE StageName != \'Closed Won\' AND StageName != \'Closed Lost\'';
        if (String.isNotBlank(odlPath)) {
            query += ' AND ODL_Path__c = :odlPath';
        }
        query += ' ORDER BY LastActivityDate DESC NULLS LAST LIMIT 100';
        return Database.query(query);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUmbRecord(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Account.Name, StageName, Amount, CloseDate,
                   ODL_Path__c, Design_Status__c, Portal_Published__c, Selected_Package__c,
                   Customer_Viewed_Date__c, Quote_Status__c, Contract_Status__c, Deposit_Due__c,
                   Voicemail_Left__c, Last_Voicemail_Date__c,
                   Homeowner_Property__c, Homeowner_Property__r.Name,
                   Homeowner_Property__r.Access_Type__c, Homeowner_Property__r.Drainage_Risk__c,
                   Homeowner_Property__r.Utility_Review_Status__c,
                   OwnerId, Owner.Name, LastActivityDate
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate, Status, OwnerId, Owner.Name,
                   CallDisposition, Description
            FROM Task
            WHERE WhatId = :opportunityId
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 10
        ];

        return new Map<String, Object>{
            'opp'   => opp,
            'tasks' => tasks
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCustomBuildRecord(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Account.Name, StageName, Amount, CloseDate,
                   ODL_Path__c, Project_Vision__c, Budget_Comfort__c, Decision_Makers__c,
                   Timeline__c, Estimate_Status__c, Projected_Cost__c,
                   Voicemail_Left__c, Last_Voicemail_Date__c,
                   Homeowner_Property__c, Homeowner_Property__r.Name,
                   Homeowner_Property__r.Access_Type__c, Homeowner_Property__r.Drainage_Risk__c,
                   Homeowner_Property__r.Utility_Review_Status__c,
                   OwnerId, Owner.Name, LastActivityDate
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate, Status, OwnerId, Owner.Name,
                   CallDisposition, Description
            FROM Task
            WHERE WhatId = :opportunityId
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 10
        ];

        return new Map<String, Object>{
            'opp'   => opp,
            'tasks' => tasks
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLawnCareRecord(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Account.Name, StageName, Amount, CloseDate,
                   ODL_Path__c, Service_Interest__c, Billing_Frequency__c, Monthly_Billing__c,
                   Contract_Term__c, Estimate_Status__c,
                   Voicemail_Left__c, Last_Voicemail_Date__c,
                   Homeowner_Property__c, Homeowner_Property__r.Name,
                   Homeowner_Property__r.Lot_Size__c, Homeowner_Property__r.Irrigation__c,
                   Homeowner_Property__r.Gate_Access__c,
                   OwnerId, Owner.Name, LastActivityDate
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate, Status, OwnerId, Owner.Name,
                   CallDisposition, Description
            FROM Task
            WHERE WhatId = :opportunityId
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 10
        ];

        return new Map<String, Object>{
            'opp'   => opp,
            'tasks' => tasks
        };
    }
}
