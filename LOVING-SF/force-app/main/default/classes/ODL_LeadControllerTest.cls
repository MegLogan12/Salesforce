@isTest
private class ODL_LeadControllerTest {

    @TestSetup
    static void setup() {
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'Homeowner',
            Company = 'Test Co',
            Status = 'New',
            ODL_Path__c = 'UMB',
            Phone = '555-0100'
        );
        insert l;
    }

    @isTest
    static void testGetLeadList_noFilter() {
        Test.startTest();
        List<Lead> leads = ODL_LeadController.getLeadList(null);
        Test.stopTest();
        System.assertNotEquals(null, leads, 'Should return list');
    }

    @isTest
    static void testGetLeadList_withFilter() {
        Test.startTest();
        List<Lead> leads = ODL_LeadController.getLeadList('UMB');
        Test.stopTest();
        System.assertNotEquals(null, leads, 'Should return list');
        System.assertEquals(1, leads.size(), 'Should have 1 UMB lead');
    }

    @isTest
    static void testGetLeadList_emptyFilter() {
        Test.startTest();
        List<Lead> leads = ODL_LeadController.getLeadList('');
        Test.stopTest();
        System.assertNotEquals(null, leads);
    }

    @isTest
    static void testGetLeadRecord() {
        Lead l = [SELECT Id FROM Lead WHERE LastName = 'Homeowner' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = ODL_LeadController.getLeadRecord(l.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('lead'), 'Should have lead key');
        System.assert(result.containsKey('tasks'), 'Should have tasks key');
    }
}
