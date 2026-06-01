/**
 * VpOpsDashboardControllerTest
 * Coverage for FMScorecardController and VpEscalationsController.
 *
 * Uses Test.startTest / stopTest to isolate governor limits.
 * All DML uses the standard WorkOrder object or avoids objects whose lookups
 * reference standard WorkOrder in production (same pattern as LovingServicesTest).
 */
@IsTest
private class VpOpsDashboardControllerTest {

    // ─────────────────────────────────────────────
    // SETUP
    // ─────────────────────────────────────────────
    @TestSetup
    static void setup() {
        // FM Scorecard record linked to running user
        FM_Scorecard__c sc = new FM_Scorecard__c(
            FM__c               = UserInfo.getUserId(),
            QI_Total_Score__c   = 46.5,
            QI_Total_Count__c   = 5,
            QI_Average__c       = 9.3,
            Last_QI_Score__c    = 9.5,
            Last_QI_Date__c     = Date.today(),
            FJ_Percent__c       = 4.2,
            Finish_Job_Count__c = 3
        );
        insert sc;

        // Hire Request in Submitted state
        // Note: Total_Annual_Cost__c = Quantity * Annual_Cost_Per_Person (formula, not writable)
        //       Y1_ROI__c = Y1_Revenue_Capacity__c - Total_Annual_Cost__c (formula, not writable)
        Hire_Request__c hr = new Hire_Request__c(
            Submitted_By_FM__c       = UserInfo.getUserId(),
            Service_Line__c          = 'Landscape',
            Role_Type__c             = 'Technician',
            Quantity__c              = 1,
            Annual_Cost_Per_Person__c = 55000,  // → Total_Annual_Cost__c = 55,000
            Y1_Revenue_Capacity__c   = 390000,  // → Y1_ROI__c = 390,000 - 55,000 = 335,000
            Justification__c         = 'Mallard Creek Phase 3 capacity constraint',
            Status__c                = 'Submitted'
        );
        insert hr;
    }

    // ─────────────────────────────────────────────
    // FMScorecardController
    // ─────────────────────────────────────────────
    @IsTest
    static void getScorecards_returnsRows() {
        Test.startTest();
        List<FMScorecardController.ScorecardRow> rows = FMScorecardController.getScorecards();
        Test.stopTest();

        System.assertNotEquals(null, rows, 'Should return a list');
        System.assert(!rows.isEmpty(), 'Should have at least one scorecard row');

        FMScorecardController.ScorecardRow r = rows[0];
        System.assertNotEquals(null, r.fmName,     'fmName should be populated');
        System.assertNotEquals(null, r.fmInitials, 'fmInitials should be populated');
        System.assertNotEquals(null, r.qiAverage,  'qiAverage should be populated');
        System.assertNotEquals(null, r.statusLabel, 'statusLabel should be set');
        System.assertNotEquals(null, r.avatarColor, 'avatarColor should be set');

        // QI avg = 9.3 → "Strong"
        System.assertEquals('Strong', r.statusLabel, 'QI 9.3 should yield Strong status');
        System.assertEquals('chip-green', r.statusClass);
    }

    @IsTest
    static void getScorecards_watchStatus() {
        // Update scorecard to QI avg in Watch range (8.5–8.99)
        FM_Scorecard__c sc = [SELECT Id FROM FM_Scorecard__c LIMIT 1];
        sc.QI_Average__c = 8.7;
        sc.QI_Total_Score__c = 8.7;
        sc.QI_Total_Count__c = 1;
        update sc;

        Test.startTest();
        List<FMScorecardController.ScorecardRow> rows = FMScorecardController.getScorecards();
        Test.stopTest();

        System.assertEquals('Watch', rows[0].statusLabel, 'QI 8.7 should yield Watch status');
        System.assertEquals('chip-amber', rows[0].statusClass);
        System.assertEquals('row-amber', rows[0].rowClass);
    }

    @IsTest
    static void getScorecards_atRiskStatus() {
        FM_Scorecard__c sc = [SELECT Id FROM FM_Scorecard__c LIMIT 1];
        sc.QI_Average__c = 7.5;
        sc.QI_Total_Score__c = 7.5;
        sc.QI_Total_Count__c = 1;
        update sc;

        Test.startTest();
        List<FMScorecardController.ScorecardRow> rows = FMScorecardController.getScorecards();
        Test.stopTest();

        System.assertEquals('At Risk', rows[0].statusLabel);
        System.assertEquals('chip-red', rows[0].statusClass);
    }

    @IsTest
    static void getScorecards_noDataStatus() {
        FM_Scorecard__c sc = [SELECT Id FROM FM_Scorecard__c LIMIT 1];
        sc.QI_Average__c = null;
        sc.QI_Total_Score__c = null;
        sc.QI_Total_Count__c = null;
        update sc;

        Test.startTest();
        List<FMScorecardController.ScorecardRow> rows = FMScorecardController.getScorecards();
        Test.stopTest();

        System.assertEquals('No Data', rows[0].statusLabel);
        System.assertEquals('chip-gray', rows[0].statusClass);
    }

    @IsTest
    static void getScorecards_emptyOrg() {
        delete [SELECT Id FROM FM_Scorecard__c];

        Test.startTest();
        List<FMScorecardController.ScorecardRow> rows = FMScorecardController.getScorecards();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(0, rows.size(), 'Empty org should return empty list');
    }

    // ─────────────────────────────────────────────
    // VpEscalationsController — reads
    // ─────────────────────────────────────────────
    @IsTest
    static void getOpenHireRequests_returnsRows() {
        Test.startTest();
        List<VpEscalationsController.HireRequestRow> rows = VpEscalationsController.getOpenHireRequests();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assert(!rows.isEmpty(), 'Should have at least one hire request');

        VpEscalationsController.HireRequestRow r = rows[0];
        System.assertEquals('Submitted', r.status);
        System.assertEquals('Landscape', r.serviceLine);
        System.assertNotEquals(null, r.id);
        System.assertNotEquals(null, r.url);
    }

    @IsTest
    static void getOpenHireRequests_emptyWhenNone() {
        delete [SELECT Id FROM Hire_Request__c];

        Test.startTest();
        List<VpEscalationsController.HireRequestRow> rows = VpEscalationsController.getOpenHireRequests();
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }

    @IsTest
    static void getEscalationTasks_returnsNoErrors() {
        // Insert a high-priority escalation task
        insert new Task(
            OwnerId      = UserInfo.getUserId(),
            Subject      = 'Test Escalation Task',
            Priority     = 'High',
            Status       = 'Not Started',
            Type         = 'Escalation',
            ActivityDate = Date.today()
        );

        Test.startTest();
        List<VpEscalationsController.EscalationTaskRow> rows = VpEscalationsController.getEscalationTasks();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        // At least our task should be present
        System.assert(!rows.isEmpty(), 'Should find the high-priority escalation task');

        VpEscalationsController.EscalationTaskRow r = rows[0];
        System.assertNotEquals(null, r.statusLabel, 'Status label should be set');
        System.assertNotEquals(null, r.statusClass, 'Status class should be set');
        // Due today → "Due Today"
        System.assertEquals('Due Today', r.statusLabel, 'Task due today should have Due Today label');
    }

    @IsTest
    static void getEscalationTasks_overdueLabel() {
        insert new Task(
            OwnerId      = UserInfo.getUserId(),
            Subject      = 'Overdue Escalation',
            Priority     = 'High',
            Status       = 'Not Started',
            Type         = 'GP Breach',
            ActivityDate = Date.today().addDays(-3)
        );

        Test.startTest();
        List<VpEscalationsController.EscalationTaskRow> rows = VpEscalationsController.getEscalationTasks();
        Test.stopTest();

        Boolean foundOverdue = false;
        for (VpEscalationsController.EscalationTaskRow r : rows) {
            if (r.subject == 'Overdue Escalation') {
                System.assertEquals('Overdue', r.statusLabel);
                System.assertEquals('chip-red', r.statusClass);
                foundOverdue = true;
            }
        }
        System.assert(foundOverdue, 'Overdue task should be found');
    }

    // ─────────────────────────────────────────────
    // VpEscalationsController — action methods
    // ─────────────────────────────────────────────
    @IsTest
    static void approveHireRequest_updatesStatus() {
        Hire_Request__c hr = [SELECT Id FROM Hire_Request__c LIMIT 1];

        Test.startTest();
        VpEscalationsController.approveHireRequest(hr.Id, 'Approved in test');
        Test.stopTest();

        Hire_Request__c reloaded = [SELECT Status__c, Decision_Notes__c FROM Hire_Request__c WHERE Id = :hr.Id];
        System.assertEquals('Approved', reloaded.Status__c);
        System.assertEquals('Approved in test', reloaded.Decision_Notes__c);
    }

    @IsTest
    static void denyHireRequest_updatesStatus() {
        Hire_Request__c hr = [SELECT Id FROM Hire_Request__c LIMIT 1];

        Test.startTest();
        VpEscalationsController.denyHireRequest(hr.Id, 'Not approved');
        Test.stopTest();

        Hire_Request__c reloaded = [SELECT Status__c FROM Hire_Request__c WHERE Id = :hr.Id];
        System.assertEquals('Denied', reloaded.Status__c);
    }

    @IsTest
    static void deferHireRequest_updatesStatus() {
        Hire_Request__c hr = [SELECT Id FROM Hire_Request__c LIMIT 1];

        Test.startTest();
        VpEscalationsController.deferHireRequest(hr.Id, 'Revisit Q3');
        Test.stopTest();

        Hire_Request__c reloaded = [SELECT Status__c, Decision_Notes__c FROM Hire_Request__c WHERE Id = :hr.Id];
        System.assertEquals('Deferred', reloaded.Status__c);
        System.assertEquals('Revisit Q3', reloaded.Decision_Notes__c);
    }

    @IsTest
    static void markTaskComplete_closesTask() {
        Task t = new Task(
            OwnerId  = UserInfo.getUserId(),
            Subject  = 'To Complete',
            Priority = 'High',
            Status   = 'Not Started',
            Type     = 'Escalation'
        );
        insert t;

        Test.startTest();
        VpEscalationsController.markTaskComplete(t.Id);
        Test.stopTest();

        Task reloaded = [SELECT Status FROM Task WHERE Id = :t.Id];
        System.assertEquals('Completed', reloaded.Status);
    }
}