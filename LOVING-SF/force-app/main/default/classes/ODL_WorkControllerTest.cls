@isTest
private class ODL_WorkControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'ODL Work Test Account');
        insert acc;

        WorkOrder wo = new WorkOrder(
            AccountId = acc.Id,
            Status = 'New',
            Subject = 'ODL Test Work Order',
            Division__c = 'Outdoor Living',
            Job_Type__c = 'Install'
        );
        insert wo;
    }

    @isTest
    static void testGetWorkOrderRecord() {
        WorkOrder wo = [SELECT Id FROM WorkOrder WHERE Subject = 'ODL Test Work Order' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = ODL_WorkController.getWorkOrderRecord(wo.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('workOrder'));
        System.assert(result.containsKey('lineItems'));
        System.assert(result.containsKey('appointments'));
    }

    @isTest
    static void testGetWorkOrderList() {
        Test.startTest();
        List<WorkOrder> wos = ODL_WorkController.getWorkOrderList();
        Test.stopTest();
        System.assertNotEquals(null, wos);
    }

    @isTest
    static void testGetServiceCalendar() {
        Test.startTest();
        List<ServiceAppointment> appointments = ODL_WorkController.getServiceCalendar();
        Test.stopTest();
        System.assertNotEquals(null, appointments);
    }
}
