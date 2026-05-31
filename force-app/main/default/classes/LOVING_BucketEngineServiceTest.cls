@IsTest
private class LOVING_BucketEngineServiceTest {

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
    static void testEmptyOrg() {
        // No qualifying WOs — exercises empty-path return
        Test.startTest();
        LOVING_BucketEngineService.runBucketEngine();
        Test.stopTest();
    }

    @IsTest
    static void testBucketAssignment() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User fm = new User(
            Username          = 'bkttest.' + System.currentTimeMillis() + '@testloving.invalid',
            Email             = 'bkttest@testloving.invalid',
            LastName          = 'BktTestFM',
            Alias             = 'bktfm2',
            ProfileId         = p.Id,
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert fm;

        // 100 days → 90+ Days
        Work_Order__c wo90 = new Work_Order__c(
            Status__c = 'Pending Takeoff',
            Requested_Install_Date__c = Date.today().addDays(100),
            Field_Manager__c = fm.Id
        );
        // 45 days → 60+ Days (no FM → task not created even if needsTask)
        Work_Order__c wo60 = new Work_Order__c(
            Status__c = 'Pending Takeoff',
            Requested_Install_Date__c = Date.today().addDays(45)
        );
        // 20 days → 30 Days, task created
        Work_Order__c wo30 = new Work_Order__c(
            Status__c = 'Pending Takeoff',
            Requested_Install_Date__c = Date.today().addDays(20),
            Field_Manager__c = fm.Id
        );
        // -5 days (past due), no takeoff → forced Ready to Schedule
        Work_Order__c woRts = new Work_Order__c(
            Status__c = 'Pending Takeoff',
            Requested_Install_Date__c = Date.today().addDays(-5),
            Field_Manager__c = fm.Id
        );
        // takeoff done → Takeoff Complete regardless of date
        Work_Order__c woTakeoff = new Work_Order__c(
            Status__c = 'Pending Takeoff',
            Requested_Install_Date__c = Date.today().addDays(10),
            Takeoff_Task_Complete__c = true,
            Field_Manager__c = fm.Id
        );
        insert new List<Work_Order__c>{ wo90, wo60, wo30, woRts, woTakeoff };

        Test.startTest();
        LOVING_BucketEngineService.runBucketEngine();
        Test.stopTest();

        Map<Id, Work_Order__c> res = new Map<Id, Work_Order__c>([
            SELECT Id, Pipeline_Bucket__c, Takeoff_Tasks_Created__c
            FROM Work_Order__c
            WHERE Id IN (:wo90.Id, :wo60.Id, :wo30.Id, :woRts.Id, :woTakeoff.Id)
        ]);

        System.assertEquals('90+ Days',         res.get(wo90.Id).Pipeline_Bucket__c,     '100d → 90+ Days');
        System.assertEquals('60+ Days',         res.get(wo60.Id).Pipeline_Bucket__c,     '45d  → 60+ Days');
        System.assertEquals('30 Days',          res.get(wo30.Id).Pipeline_Bucket__c,     '20d  → 30 Days');
        System.assertEquals('Ready to Schedule',res.get(woRts.Id).Pipeline_Bucket__c,    '-5d  → Ready to Schedule');
        System.assertEquals('Takeoff Complete', res.get(woTakeoff.Id).Pipeline_Bucket__c,'Takeoff done → Takeoff Complete');
        System.assert(res.get(wo30.Id).Takeoff_Tasks_Created__c,  'WO 30d task flag set');
        System.assert(res.get(woRts.Id).Takeoff_Tasks_Created__c, 'WO RTS task flag set');
    }

    @IsTest
    static void testBuildTakeoffTask() {
        Work_Order__c wo = new Work_Order__c(
            Status__c                 = 'Pending Takeoff',
            Requested_Install_Date__c = Date.today().addDays(20),
            Field_Manager__c          = UserInfo.getUserId()
        );
        insert wo;
        wo = [SELECT Id, Name, Field_Manager__c, Requested_Install_Date__c FROM Work_Order__c WHERE Id = :wo.Id];

        Work_Order__c woNoDate = new Work_Order__c(
            Status__c        = 'Pending Takeoff',
            Field_Manager__c = UserInfo.getUserId()
        );
        insert woNoDate;
        woNoDate = [SELECT Id, Name, Field_Manager__c, Requested_Install_Date__c FROM Work_Order__c WHERE Id = :woNoDate.Id];

        Test.startTest();
        Task tNormal   = LOVING_BucketEngineService.buildTakeoffTask(wo, false);
        Task tHigh     = LOVING_BucketEngineService.buildTakeoffTask(wo, true);
        Task tTbd      = LOVING_BucketEngineService.buildTakeoffTask(woNoDate, true);
        Test.stopTest();

        System.assertEquals('Normal',   tNormal.Priority,        'Normal priority task');
        System.assertEquals('High',     tHigh.Priority,          'High priority task');
        System.assertEquals('Takeoff',  tNormal.Type,            'Task type Takeoff');
        System.assertEquals(wo.Id,      tNormal.WhatId,          'Task linked to WO');
        System.assertEquals(UserInfo.getUserId(), tNormal.OwnerId, 'Task owned by FM');
        System.assert(tNormal.Subject.startsWith('Site Takeoff Required'), 'Subject prefix');
        System.assert(tNormal.Description.contains('PHYSICAL SITE VISIT'), 'Description present');
        System.assert(tTbd.Description.endsWith('TBD'), 'No-date WO shows TBD');
    }
}
