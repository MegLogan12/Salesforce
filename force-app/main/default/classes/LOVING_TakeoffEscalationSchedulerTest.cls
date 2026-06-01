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
    static void testEscalateWithOverdueWOs() {
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

        Work_Order__c wo = new Work_Order__c(
            Status__c                 = 'Pending Takeoff',
            Pipeline_Bucket__c        = 'Ready to Schedule',
            Takeoff_Tasks_Created__c  = true,
            Takeoff_Task_Complete__c  = false,
            Requested_Install_Date__c = Date.today().addDays(5),
            Field_Manager__c          = fm.Id
        );
        insert wo;

        Test.startTest();
        LOVING_TakeoffEscalationScheduler.runFromFlow(new List<String>());
        Test.stopTest();

        List<Task> created = [
            SELECT Id, Subject, OwnerId, Priority, Type
            FROM Task
            WHERE WhatId = :wo.Id AND Type = 'Escalation'
        ];
        System.assertEquals(1,          created.size(),       'One escalation task created');
        System.assertEquals(manager.Id, created[0].OwnerId,   'Task assigned to FM manager');
        System.assertEquals('High',     created[0].Priority,  'High priority');
        System.assert(created[0].Subject.startsWith('OVERDUE TAKEOFF'), 'Subject prefix correct');
    }

    @IsTest
    static void testEscalateNoFMSkipped() {
        Work_Order__c wo = new Work_Order__c(
            Status__c                = 'Pending Takeoff',
            Pipeline_Bucket__c       = 'Ready to Schedule',
            Takeoff_Tasks_Created__c = true,
            Takeoff_Task_Complete__c = false,
            Requested_Install_Date__c = Date.today().addDays(3)
            // No Field_Manager__c — should be skipped
        );
        insert wo;

        Test.startTest();
        LOVING_TakeoffEscalationScheduler.runFromFlow(new List<String>());
        Test.stopTest();

        System.assertEquals(0,
            [SELECT COUNT() FROM Task WHERE WhatId = :wo.Id AND Type = 'Escalation'],
            'No task created when FM is null');
    }
}
