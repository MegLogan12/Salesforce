@isTest
private class VpEscalationsControllerTest {

    // ── Create a standard Hire_Request__c ──────────────────────────
    private static Hire_Request__c buildHR() {
        return new Hire_Request__c(
            Status__c       = 'Submitted',
            Service_Line__c = 'Landscape',
            Role_Type__c    = 'Technician',
            Quantity__c     = 1
        );
    }

    // ── getOpenHireRequests — empty ─────────────────────────────────
    @isTest
    static void testGetOpenHireRequests_Empty() {
        Test.startTest();
        List<VpEscalationsController.HireRequestRow> result = VpEscalationsController.getOpenHireRequests();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    // ── getOpenHireRequests — with data (covers row-building loop) ──
    @isTest
    static void testGetOpenHireRequests_WithData() {
        Hire_Request__c hr = buildHR();
        hr.Status__c = 'Submitted';
        insert hr;

        Test.startTest();
        List<VpEscalationsController.HireRequestRow> result = VpEscalationsController.getOpenHireRequests();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() >= 1, 'Should return at least 1 hire request');
        VpEscalationsController.HireRequestRow row = result[0];
        System.assertNotEquals(null, row.id);
        System.assertNotEquals(null, row.name);
        System.assertNotEquals(null, row.status);
    }

    // ── getOpenHireRequests — Under VP Review ──────────────────────
    @isTest
    static void testGetOpenHireRequests_UnderVPReview() {
        Hire_Request__c hr = buildHR();
        hr.Status__c = 'Under VP Review';
        insert hr;

        Test.startTest();
        List<VpEscalationsController.HireRequestRow> result = VpEscalationsController.getOpenHireRequests();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() >= 1);
    }

    // ── getEscalationTasks — empty ─────────────────────────────────
    @isTest
    static void testGetEscalationTasks_Empty() {
        Test.startTest();
        List<VpEscalationsController.EscalationTaskRow> result = VpEscalationsController.getEscalationTasks();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    // ── getEscalationTasks — Overdue ───────────────────────────────
    @isTest
    static void testGetEscalationTasks_Overdue() {
        Task t = new Task(Subject='Overdue', Priority='High', Status='Not Started',
                          Type='Escalation', ActivityDate=Date.today().addDays(-1));
        insert t;

        Test.startTest();
        List<VpEscalationsController.EscalationTaskRow> result = VpEscalationsController.getEscalationTasks();
        Test.stopTest();

        Boolean found = false;
        for (VpEscalationsController.EscalationTaskRow row : result) {
            if (row.id == t.Id) {
                System.assertEquals('Overdue', row.statusLabel);
                System.assertEquals('chip-red', row.statusClass);
                found = true;
            }
        }
        System.assert(found, 'Should find the overdue task');
    }

    // ── getEscalationTasks — Due Today ─────────────────────────────
    @isTest
    static void testGetEscalationTasks_DueToday() {
        Task t = new Task(Subject='DueToday', Priority='High', Status='Not Started',
                          Type='GP Breach', ActivityDate=Date.today());
        insert t;

        Test.startTest();
        List<VpEscalationsController.EscalationTaskRow> result = VpEscalationsController.getEscalationTasks();
        Test.stopTest();

        Boolean found = false;
        for (VpEscalationsController.EscalationTaskRow row : result) {
            if (row.id == t.Id) {
                System.assertEquals('Due Today', row.statusLabel);
                System.assertEquals('chip-amber', row.statusClass);
                found = true;
            }
        }
        System.assert(found, 'Should find the due-today task');
    }

    // ── getEscalationTasks — Open (future date) ────────────────────
    @isTest
    static void testGetEscalationTasks_OpenFuture() {
        Task t = new Task(Subject='Future', Priority='High', Status='Not Started',
                          Type='NFI Alert', ActivityDate=Date.today().addDays(5));
        insert t;

        Test.startTest();
        List<VpEscalationsController.EscalationTaskRow> result = VpEscalationsController.getEscalationTasks();
        Test.stopTest();

        Boolean found = false;
        for (VpEscalationsController.EscalationTaskRow row : result) {
            if (row.id == t.Id) {
                System.assertEquals('Open', row.statusLabel);
                System.assertEquals('chip-blue', row.statusClass);
                found = true;
            }
        }
        System.assert(found, 'Should find the future task');
    }

    // ── getEscalationTasks — all supported types ───────────────────
    @isTest
    static void testGetEscalationTasks_AllTypes() {
        List<Task> tasks = new List<Task>();
        for (String typ : new List<String>{
                'Escalation','GP Breach','NFI Alert','Schedule Review',
                'QI Alert','Invoice Alert','Takeoff Overdue','Aqua Alert'}) {
            tasks.add(new Task(Subject=typ, Priority='High', Status='Not Started', Type=typ));
        }
        insert tasks;

        Test.startTest();
        List<VpEscalationsController.EscalationTaskRow> result = VpEscalationsController.getEscalationTasks();
        Test.stopTest();

        System.assert(result.size() >= 8, 'Should return tasks for all types');
    }

    // ── approveHireRequest — success ───────────────────────────────
    @isTest
    static void testApproveHireRequest_Success() {
        Hire_Request__c hr = buildHR();
        insert hr;

        Test.startTest();
        VpEscalationsController.approveHireRequest(hr.Id, 'Approved in test');
        Test.stopTest();

        Hire_Request__c updated = [SELECT Status__c FROM Hire_Request__c WHERE Id = :hr.Id];
        System.assertEquals('Approved', updated.Status__c);
    }

    // ── denyHireRequest — success ──────────────────────────────────
    @isTest
    static void testDenyHireRequest_Success() {
        Hire_Request__c hr = buildHR();
        insert hr;

        Test.startTest();
        VpEscalationsController.denyHireRequest(hr.Id, 'Denied in test');
        Test.stopTest();

        Hire_Request__c updated = [SELECT Status__c FROM Hire_Request__c WHERE Id = :hr.Id];
        System.assertEquals('Denied', updated.Status__c);
    }

    // ── deferHireRequest — success ─────────────────────────────────
    @isTest
    static void testDeferHireRequest_Success() {
        Hire_Request__c hr = buildHR();
        insert hr;

        Test.startTest();
        VpEscalationsController.deferHireRequest(hr.Id, 'Deferred in test');
        Test.stopTest();

        Hire_Request__c updated = [SELECT Status__c FROM Hire_Request__c WHERE Id = :hr.Id];
        System.assertEquals('Deferred', updated.Status__c);
    }

    // ── markTaskComplete ───────────────────────────────────────────
    @isTest
    static void testMarkTaskComplete_Success() {
        Task t = new Task(Subject='Complete Me', Priority='High', Status='Not Started', Type='Escalation');
        insert t;

        Test.startTest();
        VpEscalationsController.markTaskComplete(t.Id);
        Test.stopTest();

        System.assertEquals('Completed', [SELECT Status FROM Task WHERE Id = :t.Id].Status);
    }

    // ── markTaskComplete — error path ──────────────────────────────
    @isTest
    static void testMarkTaskComplete_ErrorPath() {
        Account acc = new Account(Name = 'TestAccForEscal');
        insert acc;

        Test.startTest();
        try {
            VpEscalationsController.markTaskComplete(acc.Id);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ── approveHireRequest — error path ────────────────────────────
    @isTest
    static void testApproveHireRequest_ErrorPath() {
        Account acc = new Account(Name = 'TestAccApproveErr');
        insert acc;

        Test.startTest();
        try {
            VpEscalationsController.approveHireRequest(acc.Id, 'test');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ── denyHireRequest — error path ───────────────────────────────
    @isTest
    static void testDenyHireRequest_ErrorPath() {
        Account acc = new Account(Name = 'TestAccDenyErr');
        insert acc;

        Test.startTest();
        try {
            VpEscalationsController.denyHireRequest(acc.Id, 'test');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ── deferHireRequest — error path ──────────────────────────────
    @isTest
    static void testDeferHireRequest_ErrorPath() {
        Account acc = new Account(Name = 'TestAccDeferErr');
        insert acc;

        Test.startTest();
        try {
            VpEscalationsController.deferHireRequest(acc.Id, 'test');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ── DTO field coverage ──────────────────────────────────────────
    @isTest
    static void testDtoFields() {
        VpEscalationsController.HireRequestRow hr = new VpEscalationsController.HireRequestRow();
        hr.id = null;
        hr.name = 'HR-001';
        hr.url = '/001abc';
        hr.submittedByName = 'Test FM';
        hr.serviceLine = 'Production Install';
        hr.roleType = 'Foreman';
        hr.quantity = 2;
        hr.totalAnnualCost = 50000;
        hr.y1ROI = 120;
        hr.justification = 'Need more headcount';
        hr.driverCommunities = 'Oak Park, Pine Ridge';
        hr.status = 'Submitted';
        hr.createdDate = Date.today();
        System.assertEquals('HR-001', hr.name);

        VpEscalationsController.EscalationTaskRow task = new VpEscalationsController.EscalationTaskRow();
        task.id = null;
        task.subject = 'GP Breach Alert';
        task.type = 'GP Breach';
        task.activityDate = Date.today();
        task.relatedToName = 'WO-0001';
        task.relatedToId = null;
        task.ownerName = 'Jim Ops';
        task.description = 'Gross profit below threshold';
        task.statusLabel = 'Overdue';
        task.statusClass = 'chip-red';
        System.assertEquals('GP Breach Alert', task.subject);
    }
}