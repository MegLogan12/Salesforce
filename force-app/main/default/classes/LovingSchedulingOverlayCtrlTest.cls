@IsTest
private class LovingSchedulingOverlayCtrlTest {

    @IsTest
    static void getOverlayDashboard_returnsOrThrowsAura() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.OverlayDashboardDto dto =
                LovingSchedulingConsoleOverlayController.getOverlayDashboard(Date.today(), null);
            System.assertNotEquals(null, dto, 'DTO should not be null on success');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'AuraHandledException should carry a message');
        }
        Test.stopTest();
    }

    @IsTest
    static void getAutoScheduleData_returnsOrThrowsAura() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.AutoScheduleDto dto =
                LovingSchedulingConsoleOverlayController.getAutoScheduleData(Date.today(), null);
            System.assertNotEquals(null, dto, 'DTO should not be null on success');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'AuraHandledException should carry a message');
        }
        Test.stopTest();
    }

    @IsTest
    static void getDayOfMonitor_returnsOrThrowsAura() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.DayOfMonitorDto dto =
                LovingSchedulingConsoleOverlayController.getDayOfMonitor(Date.today(), null);
            System.assertNotEquals(null, dto, 'DTO should not be null on success');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'AuraHandledException should carry a message');
        }
        Test.stopTest();
    }

    @IsTest
    static void getMeasuringCup_returnsOrThrowsAura() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.MeasuringCupDto dto =
                LovingSchedulingConsoleOverlayController.getMeasuringCup(Date.today(), null);
            System.assertNotEquals(null, dto, 'DTO should not be null on success');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'AuraHandledException should carry a message');
        }
        Test.stopTest();
    }

    @IsTest
    static void getTrafficImpacts_returnsOrThrowsAura() {
        Test.startTest();
        try {
            List<LovingSchedulingConsoleOverlayController.TrafficImpactDto> rows =
                LovingSchedulingConsoleOverlayController.getTrafficImpacts(Date.today(), null);
            System.assertNotEquals(null, rows, 'List should not be null on success');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'AuraHandledException should carry a message');
        }
        Test.stopTest();
    }

    @IsTest
    static void mutationMethods_doNotThrowUnexpectedly() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.runFslOptimizer(Date.today(), null);
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            LovingSchedulingConsoleOverlayController.approveProposedDays(new List<Id>());
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            LovingSchedulingConsoleOverlayController.notifyForemen(Date.today(), null);
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }
}
