@isTest
private class AquaRouteServiceTest {

    @TestSetup
    static void makeData() {
        Employee__c emp = new Employee__c(
            Name          = 'Route Test Tech',
            First_Name__c = 'Route',
            Last_Name__c  = 'Tech',
            Active__c     = true,
            Department__c = 'Aqua',
            Role__c       = 'Technician'
        );
        insert emp;

        Schedule_Day__c sd = new Schedule_Day__c(
            Schedule_Date__c = Date.today(),
            Status__c        = 'Released'
        );
        insert sd;
    }

    @isTest
    static void testReoptimize_CreatesRORAndTask() {
        Test.startTest();
        AquaRouteService.reoptimize();
        Test.stopTest();

        List<Route_Optimization_Result__c> results = [
            SELECT Status__c, Optimization_Run_DateTime__c
            FROM Route_Optimization_Result__c
        ];
        System.assertEquals(1, results.size(), 'One ROR should be created');
        System.assertEquals('Proposed', results[0].Status__c, 'Status should be Proposed');

        List<Task> tasks = [SELECT Subject FROM Task WHERE Subject LIKE '%Re-Optimization%'];
        System.assertEquals(1, tasks.size(), 'Task should be created');
    }

    @isTest
    static void testReoptimize_LinkedToScheduleDay() {
        Test.startTest();
        AquaRouteService.reoptimize();
        Test.stopTest();

        Schedule_Day__c sd = [SELECT Id FROM Schedule_Day__c WHERE Schedule_Date__c = :Date.today() LIMIT 1];
        List<Route_Optimization_Result__c> results = [
            SELECT Schedule_Day__c FROM Route_Optimization_Result__c
        ];
        System.assertEquals(1, results.size(), 'One ROR expected');
        System.assertEquals(sd.Id, results[0].Schedule_Day__c, 'ROR should link to today\'s schedule day');
    }

    @isTest
    static void testAddShopStop_CreatesStop() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Name = 'Route Test Tech' LIMIT 1];

        Test.startTest();
        AquaRouteService.addShopStop(emp.Id, 'Restock controllers');
        Test.stopTest();

        List<Schedule_Stop__c> stops = [
            SELECT Stop_Type__c, Employee__c, Notes__c, Stop_Number__c
            FROM Schedule_Stop__c
            WHERE Employee__c = :emp.Id
        ];
        System.assertEquals(1, stops.size(), 'One stop should be created');
        System.assertEquals('Shop', stops[0].Stop_Type__c, 'Stop type should be Shop');
        System.assertEquals('Restock controllers', stops[0].Notes__c, 'Notes should match');
        System.assertEquals(1, stops[0].Stop_Number__c.intValue(), 'First stop should be number 1');
    }

    @isTest
    static void testAddShopStop_SequenceIncrement() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Name = 'Route Test Tech' LIMIT 1];
        Schedule_Day__c sd = [SELECT Id FROM Schedule_Day__c WHERE Schedule_Date__c = :Date.today() LIMIT 1];

        // Pre-create an existing stop
        Schedule_Stop__c existing = new Schedule_Stop__c(
            Employee__c     = emp.Id,
            Schedule_Day__c = sd.Id,
            Stop_Type__c    = 'Check',
            Stop_Number__c  = 3,
            Route_Status__c = 'Complete'
        );
        insert existing;

        Test.startTest();
        AquaRouteService.addShopStop(emp.Id, null);
        Test.stopTest();

        List<Schedule_Stop__c> newStops = [
            SELECT Stop_Number__c
            FROM Schedule_Stop__c
            WHERE Employee__c = :emp.Id AND Stop_Type__c = 'Shop'
        ];
        System.assertEquals(1, newStops.size(), 'One shop stop created');
        System.assertEquals(4, newStops[0].Stop_Number__c.intValue(), 'Should be sequence 4 (max+1)');
    }

    @isTest
    static void testAddShopStop_NullTech() {
        try {
            Test.startTest();
            AquaRouteService.addShopStop(null, 'test');
            Test.stopTest();
            System.assert(false, 'Expected exception for null techId');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception should be thrown');
        }
    }
}