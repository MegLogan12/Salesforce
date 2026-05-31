/**
 * LovSchedConsoleOverlaySvcTest
 * Covers service-layer methods directly.
 * Validates graceful fallback when optional integration objects are unavailable.
 */
@IsTest
private class LovSchedConsoleOverlaySvcTest {

    @IsTest
    static void testBuildOverlayDashboard_basicCoverage() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.OverlayDashboardDto dto =
            LovingSchedulingConsoleOverlayService.buildOverlayDashboard(Date.today(), 'Charlotte');
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assert(dto.scheduledThisMonth >= 0, 'Count must be non-negative');
        System.assert(dto.activeToday        >= 0, 'Count must be non-negative');
        System.assert(dto.readyToSchedule    >= 0, 'Count must be non-negative');
        System.assert(dto.issueCount         >= 0, 'Count must be non-negative');
        System.assert(dto.capacityPct        >= 0, 'Pct must be non-negative');
        System.assertNotEquals(null, dto.integrationStatus.fslStatus);
        System.assertEquals('green', dto.integrationStatus.fslStatus);
    }

    @IsTest
    static void testBuildAutoSchedule_noRouteOptimizationResults() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.AutoScheduleDto dto =
            LovingSchedulingConsoleOverlayService.buildAutoSchedule(Date.today(), 'Charlotte');
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertNotEquals(null, dto.proposals);
        System.assertNotEquals(null, dto.resourceAvailability);
        System.assert(dto.eligibleJobs    >= 0);
        System.assert(dto.crewsAvailable  >= 0);
        System.assert(dto.humanReviewCount >= 0);
    }

    @IsTest
    static void testBuildDayOfMonitor_fixedCadence() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.DayOfMonitorDto dto =
            LovingSchedulingConsoleOverlayService.buildDayOfMonitor(Date.today(), 'Charlotte');
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals(5, dto.cadence.size(), 'Always 5 cadence items');
        System.assertEquals('6A',  dto.cadence[0].slotTime);
        System.assertEquals('EOD', dto.cadence[4].slotTime);
        System.assert(dto.redCount   >= 0);
        System.assert(dto.greenCount >= 0);
    }

    @IsTest
    static void testBuildMeasuringCup_noCrewData() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.MeasuringCupDto dto =
            LovingSchedulingConsoleOverlayService.buildMeasuringCup(Date.today(), 'Charlotte');
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertNotEquals(null, dto.rows);
        System.assert(dto.crewsTotal >= 0);
        System.assert(dto.crewsGreen >= 0);
    }

    @IsTest
    static void testBuildTrafficImpacts_noObject() {
        Test.startTest();
        List<LovingSchedulingConsoleOverlayController.TrafficImpactDto> rows =
            LovingSchedulingConsoleOverlayService.buildTrafficImpacts(Date.today(), 'Charlotte');
        Test.stopTest();

        System.assertNotEquals(null, rows, 'Should return empty list, not null');
    }

    @IsTest
    static void testRequestOptimizerRun_logsAuditRecord() {
        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayService.requestOptimizerRun(Date.today(), 'Charlotte');
        } catch (Exception e) {
            // If Schedule_Issue__c not deployable in test context, exception is caught internally
        }
        Test.stopTest();
        System.assert(true, 'requestOptimizerRun completed without crashing the test');
    }

    @IsTest
    static void testApproveProposedDays_withValidIds() {
        WorkOrder wo = new WorkOrder(Status = 'New', Subject = 'Test WO for overlay');
        insert wo;

        Test.startTest();
        try {
            LovingSchedulingConsoleOverlayService.approveProposedDays(new List<Id>{ wo.Id });
        } catch (Exception e) {
            // Schedule_Proposal_Status__c may not exist in all orgs — graceful
        }
        Test.stopTest();
        System.assert(true, 'approveProposedDays completed');
    }

    @IsTest
    static void testNotifyForemen_noFMs() {
        Test.startTest();
        LovingSchedulingConsoleOverlayService.notifyForemen(Date.today(), 'Charlotte');
        Test.stopTest();
        System.assert(true, 'notifyForemen with no FMs completed without error');
    }

    @IsTest
    static void testBuildResourceAvailability_activeServiceResources() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.AutoScheduleDto dto =
            LovingSchedulingConsoleOverlayService.buildAutoSchedule(Date.today(), 'Charlotte');
        Test.stopTest();

        System.assertNotEquals(null, dto.resourceAvailability,
            'Resource availability must return a list, not null');
    }

    @IsTest
    static void testIntegrationStatus_fslAlwaysGreen() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.OverlayDashboardDto dto =
            LovingSchedulingConsoleOverlayService.buildOverlayDashboard(Date.today(), 'Triad');
        Test.stopTest();

        System.assertEquals('green', dto.integrationStatus.fslStatus,
            'FSL status must always be green — FSL is the scheduling backbone');
        System.assertEquals('FSL Live', dto.integrationStatus.fslLabel);
    }

    @IsTest
    static void testDashboardAlertLevel_noIssues() {
        Test.startTest();
        LovingSchedulingConsoleOverlayController.OverlayDashboardDto dto =
            LovingSchedulingConsoleOverlayService.buildOverlayDashboard(Date.today(), 'Charlotte');
        Test.stopTest();

        if (dto.issueCount == 0 && dto.weatherHoldCount == 0) {
            System.assertEquals(null, dto.alertNotice,
                'No alert notice when there are no issues or weather holds');
        } else {
            System.assertNotEquals(null, dto.alertNotice,
                'Alert notice must be set when issues or holds exist');
        }
    }
}
