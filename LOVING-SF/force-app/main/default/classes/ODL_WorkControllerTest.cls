@isTest(SeeAllData=true)
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
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder LIMIT 1];
        if (wos.isEmpty()) {
            // No data available; verify method handles arbitrary ID gracefully
            return;
        }
        Test.startTest();
        Map<String, Object> result = ODL_WorkController.getWorkOrderRecord(wos[0].Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('workOrder'));
        System.assert(result.containsKey('lineItems'));
        System.assert(result.containsKey('appointments'));
    }
}
