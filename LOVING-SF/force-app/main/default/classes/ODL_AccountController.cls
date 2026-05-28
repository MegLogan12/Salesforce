public with sharing class ODL_AccountController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAccountData(Id accountId) {
        Account acc = [
            SELECT Id, Name, Phone, BillingStreet, BillingCity, BillingState,
                   Customer_Health__c, Preferred_Contact_Method__c, SMS_Opt_In__c, Portal_Status__c,
                   (SELECT Id, Name FROM Contacts ORDER BY CreatedDate ASC LIMIT 1),
                   (SELECT Id, Name, StageName, Amount, ODL_Path__c, CloseDate,
                           LastActivityDate, Voicemail_Left__c, Last_Voicemail_Date__c,
                           Deposit_Due__c
                    FROM Opportunities ORDER BY LastActivityDate DESC NULLS LAST LIMIT 10),
                   (SELECT Id, Name, Account__c, Access_Type__c, Drainage_Risk__c,
                           Utility_Review_Status__c, Lot_Size__c, Irrigation__c,
                           Gate_Access__c, Property_Notes__c, Customer_Readiness__c
                    FROM Homeowner_Properties__r LIMIT 5)
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate, Status, WhoId, WhatId
            FROM Task
            WHERE WhatId = :accountId AND Status != 'Completed'
            ORDER BY ActivityDate ASC NULLS LAST
            LIMIT 10
        ];

        Integer openOppCount = 0;
        Integer activeProjectCount = 0;
        Decimal depositPostedAmount = 0;
        Decimal openDepositAmount = 0;
        Decimal finalDueAmount = 0;
        for (Opportunity o : acc.Opportunities) {
            if (o.StageName != 'Closed Won' && o.StageName != 'Closed Lost') {
                openOppCount++;
            }
            if (o.StageName == 'Deposit Paid' || o.StageName == 'Scheduled' ||
                o.StageName == 'Construction' || o.StageName == 'Pre-Con' || o.StageName == 'Punch') {
                activeProjectCount++;
                if (o.Deposit_Due__c != null) depositPostedAmount += o.Deposit_Due__c;
                if (o.Amount != null && o.Deposit_Due__c != null) finalDueAmount += (o.Amount - o.Deposit_Due__c);
            } else if (o.Deposit_Due__c != null && o.StageName != 'Closed Won' && o.StageName != 'Closed Lost') {
                openDepositAmount += o.Deposit_Due__c;
            }
        }

        return new Map<String, Object>{
            'account'        => acc,
            'tasks'          => tasks,
            'openOppCount'   => openOppCount,
            'activeProjects' => activeProjectCount,
            'openTaskCount'  => tasks.size(),
            'depositPosted'  => depositPostedAmount,
            'openDeposit'    => openDepositAmount,
            'finalDueLater'  => finalDueAmount
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getAccountOpportunities(Id accountId) {
        return [
            SELECT Id, Name, StageName, Amount, ODL_Path__c, CloseDate,
                   LastActivityDate, Voicemail_Left__c, Last_Voicemail_Date__c,
                   Selected_Package__c
            FROM Opportunity
            WHERE AccountId = :accountId
            ORDER BY LastActivityDate DESC NULLS LAST
            LIMIT 20
        ];
    }
}
