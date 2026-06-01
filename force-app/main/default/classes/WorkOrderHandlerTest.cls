@IsTest
private class WorkOrderHandlerTest {

    @TestSetup
    static void seed() {
        insert new Crew__c(Name = 'Stage7 Crew');
    }

    @IsTest
    static void approvalPromotesScheduleAndLocks() {
        Crew__c crew = [SELECT Id FROM Crew__c LIMIT 1];
        Date proposed = Date.today().addDays(5);
        Work_Order__c wo = new Work_Order__c(
            Status__c                       = 'Pending Takeoff',
            Schedule_Locked__c              = false,
            Schedule_Proposal_Status__c     = 'Pending Review',
            Proposed_Schedule_Date__c       = proposed,
            Proposed_Crew__c                = crew.Id,
            Requested_Install_Date__c       = Date.today().addDays(20),
            Takeoff_Task_Complete__c        = true,
            Utility_Marking_Complete__c     = true
        );
        insert wo;

        Test.startTest();
        wo.Schedule_Proposal_Status__c = 'Manager Approved';
        update wo;
        Test.stopTest();

        Work_Order__c reloaded = [
            SELECT Schedule_Locked__c, Scheduled_Date__c, Crew__c, Pipeline_Bucket__c
            FROM Work_Order__c WHERE Id = :wo.Id
        ];
        System.assertEquals('Clear to Schedule', reloaded.Pipeline_Bucket__c,
            'WO should have advanced to Clear to Schedule on insert with both task checkboxes set.');
        System.assertEquals(true, reloaded.Schedule_Locked__c);
        System.assertEquals(proposed, reloaded.Scheduled_Date__c);
        System.assertEquals(crew.Id, reloaded.Crew__c);
    }

    @IsTest
    static void approvalBlockedWhenBucketNotClearToSchedule() {
        Crew__c crew = [SELECT Id FROM Crew__c LIMIT 1];
        Work_Order__c wo = new Work_Order__c(
            Status__c                       = 'Pending Takeoff',
            Schedule_Locked__c              = false,
            Schedule_Proposal_Status__c     = 'Pending Review',
            Proposed_Schedule_Date__c       = Date.today().addDays(5),
            Proposed_Crew__c                = crew.Id,
            Requested_Install_Date__c       = Date.today().addDays(20),
            Takeoff_Task_Complete__c        = false,
            Utility_Marking_Complete__c     = false
        );
        insert wo;

        Test.startTest();
        wo.Schedule_Proposal_Status__c = 'Manager Approved';
        Database.SaveResult sr = Database.update(wo, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Expected approval to be blocked.');
        System.assert(sr.getErrors()[0].getMessage().contains('Clear to Schedule'),
            'Expected Clear to Schedule gating error, got: ' + sr.getErrors()[0].getMessage());

        Work_Order__c reloaded = [SELECT Schedule_Locked__c FROM Work_Order__c WHERE Id = :wo.Id];
        System.assertEquals(false, reloaded.Schedule_Locked__c);
    }

    @IsTest
    static void inProgressBlockedWithoutReadiness() {
        Work_Order__c wo = new Work_Order__c(
            Status__c = 'Ready to Schedule',
            Schedule_Locked__c = true,
            Scheduled_Date__c = Date.today().addDays(3)
        );
        insert wo;

        Test.startTest();
        wo.Status__c = 'In Progress';
        Database.SaveResult sr = Database.update(wo, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Expected save failure');
        System.assert(sr.getErrors()[0].getMessage().contains('Site Readiness'),
            'Expected readiness error, got: ' + sr.getErrors()[0].getMessage());
    }

    @IsTest
    static void inProgressAllowedWhenReadinessComplete() {
        Work_Order__c wo = new Work_Order__c(
            Status__c = 'Ready to Schedule',
            Schedule_Locked__c = true,
            Scheduled_Date__c = Date.today().addDays(3)
        );
        insert wo;

        insert new Task(
            WhatId = wo.Id,
            Subject = 'Site Readiness Check (T-48)',
            Type = 'Site Readiness',
            Status = 'Completed'
        );

        Test.startTest();
        wo.Status__c = 'In Progress';
        update wo;
        Test.stopTest();

        Work_Order__c reloaded = [SELECT Status__c FROM Work_Order__c WHERE Id = :wo.Id];
        System.assertEquals('In Progress', reloaded.Status__c);
    }

    @IsTest
    static void noPromotionWithoutApproval() {
        Crew__c crew = [SELECT Id FROM Crew__c LIMIT 1];
        Work_Order__c wo = new Work_Order__c(
            Status__c                       = 'Ready to Schedule',
            Schedule_Locked__c              = false,
            Schedule_Proposal_Status__c     = 'Pending Review',
            Proposed_Schedule_Date__c       = Date.today().addDays(5),
            Proposed_Crew__c                = crew.Id
        );
        insert wo;

        Test.startTest();
        wo.Schedule_Proposal_Status__c = 'Pending Review';
        update wo;
        Test.stopTest();

        Work_Order__c reloaded = [
            SELECT Schedule_Locked__c, Scheduled_Date__c
            FROM Work_Order__c WHERE Id = :wo.Id
        ];
        System.assertEquals(false, reloaded.Schedule_Locked__c);
        System.assertEquals(null, reloaded.Scheduled_Date__c);
    }
}