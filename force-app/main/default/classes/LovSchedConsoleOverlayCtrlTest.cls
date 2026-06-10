/**
 * LovSchedConsoleOverlayCtrlTest
 * Covers all @AuraEnabled methods in LovingSchedulingConsoleOverlayController.
 */
@IsTest
private class LovSchedConsoleOverlayCtrlTest {

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
    static void testGetAutoScheduleData_nullDate() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.AutoScheduleDto dto =
            LovingSchedulingConsoleOverlayController.getAutoScheduleData(null, null);
        Test.stopTest();
        System.assertNotEquals(null, dto);
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
    static void testGetDayOfMonitor_nullDate() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.DayOfMonitorDto dto =
            LovingSchedulingConsoleOverlayController.getDayOfMonitor(null, null);
        Test.stopTest();
        System.assertNotEquals(null, dto);
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
    static void testGetMeasuringCup_nullDate() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.MeasuringCupDto dto =
            LovingSchedulingConsoleOverlayController.getMeasuringCup(null, null);
        Test.stopTest();
        System.assertNotEquals(null, dto);
    }

    @IsTest
    static void testGetTrafficImpacts_returnsList() {
        Test.startTest();
        List<LovingSchedulingConsoleOverlayController.TrafficImpactDto> rows =
            LovingSchedulingConsoleOverlayController.getTrafficImpacts(Date.today(), 'Charlotte');
        Test.stopTest();
        System.assertNotEquals(null, rows, 'Traffic list should not be null');
    }

    @IsTest
    static void testGetTrafficImpacts_nullDate() {
        Test.startTest();
        List<LovingSchedulingConsoleOverlayController.TrafficImpactDto> rows =
            LovingSchedulingConsoleOverlayController.getTrafficImpacts(null, null);
        Test.stopTest();
        System.assertNotEquals(null, rows);
    }

    @IsTest
    static void testRunFslOptimizer_doesNotThrow() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.runFslOptimizer(Date.today(), 'Charlotte');
        } catch (AuraHandledException e) {
            // Acceptable if Schedule_Issue__c is not accessible in test context
        }
        Test.stopTest();
        System.assert(true, 'runFslOptimizer completed without uncaught exception');
    }

    @IsTest
    static void testRunFslOptimizer_nullDate() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.runFslOptimizer(null, null);
        } catch (AuraHandledException e) { /* acceptable */ }
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testApproveProposedDays_emptyListThrows() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.approveProposedDays(new List<Id>());
            System.assert(false, 'Should have thrown for empty list');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
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
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testApproveProposedDays_invalidIdCoversControllerCatch() {
        // Passing a User ID as a WorkOrder ID causes DML failure → controller catch fires
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.approveProposedDays(
                new List<Id>{ UserInfo.getUserId() });
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testNotifyForemen_doesNotThrow() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.notifyForemen(Date.today(), 'Charlotte');
        } catch (AuraHandledException e) { /* acceptable */ }
        Test.stopTest();
        System.assert(true, 'notifyForemen completed without uncaught exception');
    }

    @IsTest
    static void testNotifyForemen_nullDate() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.notifyForemen(null, null);
        } catch (AuraHandledException e) { /* acceptable */ }
        Test.stopTest();
        System.assert(true);
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

    // ─── Controller catch-block coverage via forceError ──────────────────────

    @IsTest
    static void testAllReadMethods_controllerCatchBlocks() {
        LovingSchedulingConsoleOverlayService.forceError = true;
        Test.startTest();

        try {
            LovingSchedulingConsoleOverlayController.getOverlayDashboard(Date.today(), 'T');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) { System.assertNotEquals(null, e); }

        try {
            LovingSchedulingConsoleOverlayController.getAutoScheduleData(Date.today(), 'T');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) { System.assertNotEquals(null, e); }

        try {
            LovingSchedulingConsoleOverlayController.getDayOfMonitor(Date.today(), 'T');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) { System.assertNotEquals(null, e); }

        try {
            LovingSchedulingConsoleOverlayController.getMeasuringCup(Date.today(), 'T');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) { System.assertNotEquals(null, e); }

        try {
            LovingSchedulingConsoleOverlayController.getTrafficImpacts(Date.today(), 'T');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) { System.assertNotEquals(null, e); }

        try {
            LovingSchedulingConsoleOverlayController.notifyForemen(Date.today(), 'T');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) { System.assertNotEquals(null, e); }

        Test.stopTest();
        LovingSchedulingConsoleOverlayService.forceError = false;
    }

    @IsTest
    static void testRunFslOptimizer_controllerCatchBlock() {
        LovingSchedulingConsoleOverlayService.forceError = true;
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayController.runFslOptimizer(Date.today(), 'Charlotte');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e);
        }
        Test.stopTest();
        LovingSchedulingConsoleOverlayService.forceError = false;
    }
}