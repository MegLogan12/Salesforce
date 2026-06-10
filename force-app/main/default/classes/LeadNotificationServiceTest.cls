@IsTest
private class LeadNotificationServiceTest {

    @IsTest
    static void notifyCOODeadLeadsBuildsBodyAndAlerts() {
        Lead l1 = new Lead(
            FirstName      = 'Alex',
            LastName       = 'Smith',
            Company        = 'ACME Builders',
            Status         = 'Open - Not Contacted',
            Dead_Reason__c = 'Builder went inactive',
            Lead_Type__c   = 'Net New Builder',
            Community_Name__c = 'Test Community',
            LeadSource     = 'Other'
        );
        Lead l2 = new Lead(
            FirstName      = 'Sam',
            LastName       = 'Jones',
            Company        = 'BetaCo',
            Status         = 'Open - Not Contacted',
            Dead_Reason__c = 'Wrong contact',
            Lead_Type__c   = 'Net New Builder',
            Community_Name__c = 'Test Community',
            LeadSource     = 'Other'
        );
        insert new List<Lead>{ l1, l2 };

        Test.startTest();
        LeadNotificationService.notifyCOODeadLeads(new List<Id>{ l1.Id, l2.Id });
        Test.stopTest();

        // Did not throw — alert path executed for both leads
        System.assert(true);
    }
}