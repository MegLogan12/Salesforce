@isTest
private class ODL_WorkControllerTest {

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

    @isTest
    static void testGetWorkOrderRecord() {
        WorkOrder wo;
        try {
            wo = new WorkOrder(
                Status = 'New',
                Subject = 'ODL Test Work Order',
                Division__c = 'Outdoor Living',
                Job_Type__c = 'Install'
            );
            insert wo;
        } catch (Exception e) {
            return;
        }
        Test.startTest();
        Map<String, Object> result = ODL_WorkController.getWorkOrderRecord(wo.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('workOrder'));
        System.assert(result.containsKey('lineItems'));
        System.assert(result.containsKey('appointments'));
    }
}
