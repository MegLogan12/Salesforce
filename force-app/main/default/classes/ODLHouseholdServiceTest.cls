@IsTest
private class ODLHouseholdServiceTest {
    @IsTest
    static void testScopedUmbDuplicateBlockedByHouseholdAddress() {
        Account johnAccount = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Smith',
            PersonEmail = 'john.smith@test.example',
            BillingStreet = '123 Oak Street',
            BillingCity = 'Houston',
            BillingState = 'TX',
            BillingPostalCode = '77001',
            Type = 'Homeowner',
            ODL_Household_Display_Name__c = 'Smith Household'
        );
        insert johnAccount;

        insert new Opportunity(
            Name = 'John Smith - Backyard Design',
            AccountId = johnAccount.Id,
            StageName = 'Quote Requested',
            CloseDate = Date.today().addDays(30),
            Type = 'UMB',
            LeadSource = 'Lennar Voucher'
        );

        Account janeAccount = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Smith',
            PersonEmail = 'jane.smith@test.example',
            BillingStreet = '123 Oak Street',
            BillingCity = 'Houston',
            BillingState = 'TX',
            BillingPostalCode = '77001',
            Type = 'Homeowner',
            ODL_Household_Display_Name__c = 'Smith Household'
        );
        insert janeAccount;

        Test.startTest();
        try {
            insert new Opportunity(
                Name = 'Jane Smith - Consultation',
                AccountId = janeAccount.Id,
                StageName = 'Quote Requested',
                CloseDate = Date.today().addDays(14),
                Type = 'UMB',
                LeadSource = 'Web - Consultation Form'
            );
            System.assert(false, 'Expected duplicate household opportunity insert to fail.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('active ODL household opportunity already exists'));
        }
        Test.stopTest();
    }
}