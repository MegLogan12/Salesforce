@IsTest
private class HomeDashboardControllerTest {

    @IsTest
    static void getKpisReturnsObject() {
        Test.startTest();
        HomeDashboardController.TodaysKpis k = HomeDashboardController.getKpis();
        Test.stopTest();
        System.assertNotEquals(null, k);
    }

    @IsTest
    static void getOpenHireRequestsReturnsList() {
        Test.startTest();
        List<HomeDashboardController.HireRequestRow> rows = HomeDashboardController.getOpenHireRequests();
        Test.stopTest();
        System.assertNotEquals(null, rows);
    }

    @IsTest
    static void getThisWeekOneOnOnesReturnsList() {
        Test.startTest();
        List<HomeDashboardController.OneOnOneRow> rows = HomeDashboardController.getThisWeekOneOnOnes();
        Test.stopTest();
        System.assertNotEquals(null, rows);
    }

    @IsTest
    static void buildHireRowFromConstructed() {
        Hire_Request__c hr = new Hire_Request__c(
            Service_Line__c = 'Landscape',
            Role_Type__c = 'Technician',
            Status__c = 'Submitted'
        );
        Test.startTest();
        HomeDashboardController.HireRequestRow r = HomeDashboardController.buildHireRow(hr);
        Test.stopTest();
        System.assertEquals('Landscape', r.serviceLine);
        System.assertEquals('Technician', r.roleType);
        System.assertEquals('Submitted', r.status);
    }

    @IsTest
    static void buildOneOnOneRowFromConstructed() {
        OneOnOne__c o = new OneOnOne__c(
            Cadence__c = 'Weekly',
            Status__c = 'Scheduled',
            Meeting_Date__c = DateTime.now()
        );
        Test.startTest();
        HomeDashboardController.OneOnOneRow r = HomeDashboardController.buildOneOnOneRow(o);
        Test.stopTest();
        System.assertEquals('Scheduled', r.status);
        System.assertNotEquals(null, r.meetingDate);
    }

    @IsTest
    static void todaysKpisInstantiation() {
        HomeDashboardController.TodaysKpis k = new HomeDashboardController.TodaysKpis();
        k.activeWorkOrders = 5;
        k.scheduledToday = 2;
        k.inProgressToday = 3;
        k.pendingApproval = 1;
        k.pendingCloseout = 1;
        k.openHireRequests = 2;
        k.thisWeekOneOnOnes = 5;
        k.openActionItems = 12;
        System.assertEquals(5, k.activeWorkOrders);
        System.assertEquals(12, k.openActionItems);
    }

    @IsTest
    static void hireRequestRowInstantiation() {
        HomeDashboardController.HireRequestRow r = new HomeDashboardController.HireRequestRow();
        r.id = null;
        r.hrNumber = 'HR-001';
        r.url = '/test';
        r.submittedBy = 'Test FM';
        r.serviceLine = 'Aqua';
        r.roleType = 'Foreman';
        r.totalCost = 75000;
        r.y1ROI = 100000;
        r.status = 'Submitted';
        r.submittedDate = Date.today();
        System.assertEquals('HR-001', r.hrNumber);
        System.assertEquals(75000, r.totalCost);
    }

    @IsTest
    static void oneOnOneRowInstantiation() {
        HomeDashboardController.OneOnOneRow r = new HomeDashboardController.OneOnOneRow();
        r.id = null;
        r.name = '1on1-001';
        r.url = '/test';
        r.manager = 'Mgr';
        r.directReport = 'Rep';
        r.meetingDate = DateTime.now();
        r.status = 'Scheduled';
        System.assertEquals('1on1-001', r.name);
    }
}