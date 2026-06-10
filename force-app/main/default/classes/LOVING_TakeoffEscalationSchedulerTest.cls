@IsTest
private class LOVING_TakeoffEscalationSchedulerTest {

    @TestSetup
    static void setup() {
        try {
            Extentia_SIM__MapPlotterTriggerSettings__c bypass =
                Extentia_SIM__MapPlotterTriggerSettings__c.getOrgDefaults();
            bypass.Extentia_SIM__Bypass_Trigger__c = true;
            upsert bypass;
        } catch (Exception e) {}
    }

    @IsTest
    static void testRunFromFlowEmpty() {
        Test.startTest();
        LOVING_TakeoffEscalationScheduler.runFromFlow(new List<String>());
        Test.stopTest();
        System.assertEquals(0,
            [SELECT COUNT() FROM Task WHERE Type = 'Escalation'],
            'No escalation tasks when no qualifying work orders');
    }

    @IsTest
    static void testScheduledExecution() {
        Test.startTest();
        String jobId = System.schedule(
            'Test Takeoff Escalation ' + System.currentTimeMillis(),
            '0 0 0 1 1 ? 2099',
            new LOVING_TakeoffEscalationScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Job scheduled successfully');
    }

    @IsTest
    static void testBuildEscalationTask() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User manager = new User(
            Username    = 'escmgr.' + System.currentTimeMillis() + '@testloving.invalid',
            Email       = 'escmgr@testloving.invalid',
            LastName    = 'EscMgr',
            Alias       = 'escmgr',
            ProfileId   = p.Id,
            TimeZoneSidKey   = 'America/New_York',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert manager;
        User fm = new User(
            Username    = 'escfm.' + System.currentTimeMillis() + '@testloving.invalid',
            Email       = 'escfm@testloving.invalid',
            LastName    = 'EscFM',
            Alias       = 'escfm',
            ProfileId   = p.Id,
            ManagerId   = manager.Id,
            TimeZoneSidKey   = 'America/New_York',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert fm;

        WorkOrder wo = new WorkOrder(Requested_Install_Date__c = Date.today().addDays(5));

        Test.startTest();
        Task created = LOVING_TakeoffEscalationScheduler.buildEscalationTask(wo, manager.Id);
        Test.stopTest();

        System.assertEquals(manager.Id, created.OwnerId, 'Task assigned to provided owner');
        System.assertEquals('High', created.Priority, 'High priority');
        System.assertEquals('Escalation', created.Type, 'Escalation task type');
        System.assert(created.Subject.startsWith('OVERDUE TAKEOFF'), 'Subject prefix correct');
        System.assert(created.Description.contains('Target install date'), 'Description includes target date');
    }

    @IsTest
    static void testEscalateWithMockWorkOrders() {
        WorkOrder included = new WorkOrder(
            Id = '0WO000000000101AAA',
            Requested_Install_Date__c = Date.today().addDays(5),
            Field_Manager__c = UserInfo.getUserId()
        );
        WorkOrder skipped = new WorkOrder(
            Id = '0WO000000000102AAA',
            Requested_Install_Date__c = Date.today().addDays(5),
            Field_Manager__c = UserInfo.getUserId()
        );
        LOVING_TakeoffEscalationScheduler.mockWorkOrders = new List<WorkOrder>{ included, skipped };
        LOVING_TakeoffEscalationScheduler.mockWorkOrdersWithTakeoffTasks = new Set<Id>{ included.Id };

        Test.startTest();
        LOVING_TakeoffEscalationScheduler.runFromFlow(new List<String>());
        Test.stopTest();

        System.assertEquals(1, LOVING_TakeoffEscalationScheduler.lastCreatedTasks.size(), 'Only WOs with takeoff task escalate');
        System.assertEquals(included.Id, LOVING_TakeoffEscalationScheduler.lastCreatedTasks[0].WhatId, 'Escalation linked to included WO');
    }
}