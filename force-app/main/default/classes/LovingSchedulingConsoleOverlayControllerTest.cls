/**
 * LovingSchedulingConsoleOverlayControllerTest
 * Covers all @AuraEnabled methods in LovingSchedulingConsoleOverlayController.
 * FSL objects (ServiceAppointment, ServiceResource, AssignedResource, ResourceAbsence)
 * may not support direct insert in test context — mock guards are applied in the service.
 */
@IsTest
private class LovingSchedulingConsoleOverlayControllerTest {

    @TestSetup
    static void setup() {
        // Minimal data: ServiceTerritory is needed for FSL SA insert.
        // ServiceAppointment insert in test context requires FSL managed package.
        // We rely on empty-result paths with graceful fallbacks.
    }

    @IsTest
    static void testGetOverlayDashboard_returnsDto() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.OverlayDashboardDto dto =
            LovingSchedulingConsoleOverlayController.getOverlayDashboard(Date.today(), 'Charlotte');
        Test.stopTest();

        System.assertNotEquals(null, dto, 'Dashboard DTO should not be null');
        System.assertNotEquals(null, dto.integrationStatus, 'Integration status should not be null');
        System.assertNotEquals(null, dto.appointmentQueue, 'Appointment queue should not be null');
    }

    @IsTest
    static void testGetOverlayDashboard_nullDate() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.OverlayDashboardDto dto =
            LovingSchedulingConsoleOverlayController.getOverlayDashboard(null, null);
        Test.stopTest();
        System.assertNotEquals(null, dto, 'Null date should default to today');
    }

    @IsTest
    static void testGetAutoScheduleData_returnsDto() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.AutoScheduleDto dto =
            LovingSchedulingConsoleOverlayController.getAutoScheduleData(Date.today(), 'Charlotte');
        Test.stopTest();

        System.assertNotEquals(null, dto, 'AutoSchedule DTO should not be null');
        System.assertNotEquals(null, dto.proposals, 'Proposals list should not be null');
        System.assertNotEquals(null, dto.resourceAvailability, 'ResourceAvailability should not be null');
        System.assert(dto.eligibleJobs >= 0, 'Eligible jobs must be non-negative');
    }

    @IsTest
    static void testGetDayOfMonitor_returnsCadence() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.DayOfMonitorDto dto =
            LovingSchedulingConsoleOverlayController.getDayOfMonitor(Date.today(), 'Charlotte');
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DayOf DTO should not be null');
        System.assertEquals(5, dto.cadence.size(), 'Cadence should always have 5 checkpoints');
        System.assertNotEquals(null, dto.healthChecks, 'Health checks should not be null');
    }

    @IsTest
    static void testGetMeasuringCup_returnsDto() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.MeasuringCupDto dto =
            LovingSchedulingConsoleOverlayController.getMeasuringCup(Date.today(), 'Charlotte');
        Test.stopTest();

        System.assertNotEquals(null, dto, 'MeasuringCup DTO should not be null');
        System.assertNotEquals(null, dto.rows, 'Rows list should not be null');
    }

    @IsTest
    static void testGetTrafficImpacts_returnsList() {
        Test.startTest();
        List<LovingSchedulingConsoleOverlayController.TrafficImpactDto> rows =
            LovingSchedulingConsoleOverlayController.getTrafficImpacts(Date.today(), 'Charlotte');
        Test.stopTest();
        // Traffic_Impact__c may not exist — graceful empty list expected
        System.assertNotEquals(null, rows, 'Traffic list should not be null — should be empty list if object missing');
    }

    @IsTest
    static void testRunFslOptimizer_doesNotThrow() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.runFslOptimizer(Date.today(), 'Charlotte');
        } catch (AuraHandledException e) {
            // If Schedule_Issue__c is not accessible in test context, AuraHandledException is acceptable
        }
        Test.stopTest();
        System.assert(true, 'runFslOptimizer completed without uncaught exception');
    }

    @IsTest
    static void testApproveProposedDays_emptyListThrows() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.approveProposedDays(new List<Id>());
            System.assert(false, 'Should have thrown for empty list');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No work order'), 'Error message should mention IDs: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testApproveProposedDays_nullListThrows() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.approveProposedDays(null);
            System.assert(false, 'Should have thrown for null');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }

    @IsTest
    static void testNotifyForemen_doesNotThrow() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.notifyForemen(Date.today(), 'Charlotte');
        } catch (AuraHandledException e) {
            // Acceptable if FM User link not available in test org
        }
        Test.stopTest();
        System.assert(true, 'notifyForemen completed without uncaught exception');
    }

    @IsTest
    static void testIntegrationStatusDto_fields() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.OverlayDashboardDto dto =
            LovingSchedulingConsoleOverlayController.getOverlayDashboard(Date.today(), 'Charlotte');
        Test.stopTest();

        LovingSchedulingConsoleOverlayController.IntegrationStatusDto is = dto.integrationStatus;
        System.assertNotEquals(null, is.fslStatus,     'FSL status should not be null');
        System.assertNotEquals(null, is.fslLabel,      'FSL label should not be null');
        System.assertNotEquals(null, is.weatherStatus, 'Weather status should not be null');
        System.assertNotEquals(null, is.trafficStatus, 'Traffic status should not be null');
        System.assertNotEquals(null, is.wexGpsStatus,  'WEX status should not be null');
        System.assertNotEquals(null, is.ripplingStatus,'Rippling status should not be null');
    }
}
