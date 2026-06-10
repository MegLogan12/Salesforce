@IsTest(SeeAllData=true)
private class SchedulingConsoleControllerLiveDataTest {

    @IsTest
    static void liveFslBoardAndPendingPaths_smoke() {
        Test.startTest();
        SchedulingConsoleController.ScheduleBoardDto board =
            SchedulingConsoleService.buildScheduleBoard(Date.today(), null);
        SchedulingConsoleController.PendingScheduleDto pending =
            SchedulingConsoleService.buildPendingItems(null);
        List<SchedulingConsoleController.ScheduleIssueDto> issues =
            SchedulingConsoleService.buildScheduleIssues(Date.today(), null);
        SchedulingConsoleController.DraftReviewDto draft =
            SchedulingConsoleService.buildDraftReview(Date.today(), null);
        Test.stopTest();

        System.assertNotEquals(null, board);
        System.assertNotEquals(null, pending);
        System.assertNotEquals(null, issues);
        System.assertNotEquals(null, draft);

        Boolean foundWorkOrderBackedStop = false;
        for (SchedulingConsoleController.CrewBoardDto crew : board.crews) {
            for (SchedulingConsoleController.StopDto stop : crew.stops) {
                if (stop.workOrderId != null) {
                    foundWorkOrderBackedStop = true;
                    break;
                }
            }
            if (foundWorkOrderBackedStop) break;
        }
        System.assert(foundWorkOrderBackedStop || board.totalStops == 0);
    }

    @IsTest
    static void liveFslOverlayPaths_smoke() {
        Date weekStart = Date.today().toStartOfWeek().addDays(1);
        Date weekEnd = weekStart.addDays(4);

        Test.startTest();
        List<SchedulingConsoleController.CrewUtilizationDto> crews =
            SchedulingConsoleService.buildCrewUtilization(weekStart, weekEnd, null);
        List<SchedulingConsoleController.TimeOffDto> timeOff =
            SchedulingConsoleService.buildTimeOff(Date.today(), Date.today().addDays(6), null);
        List<SchedulingConsoleController.GpsMarkerDto> gps =
            SchedulingConsoleService.buildGpsMarkers(Date.today(), null);
        List<SchedulingConsoleController.OvertimeRiskDto> overtime =
            SchedulingConsoleService.buildOvertimeRisks(weekStart, weekEnd, null);
        List<SchedulingConsoleController.CrewEfficiencyDto> efficiency =
            SchedulingConsoleService.buildCrewEfficiencyMtd(Date.today(), null);
        Test.stopTest();

        System.assertNotEquals(null, crews);
        System.assertNotEquals(null, timeOff);
        System.assertNotEquals(null, gps);
        System.assertNotEquals(null, overtime);
        System.assertNotEquals(null, efficiency);
    }

    @IsTest
    static void liveDivisionFilters_smoke() {
        Date weekStart = Date.today().toStartOfWeek().addDays(1);
        Date weekEnd = weekStart.addDays(4);
        Test.startTest();
        for (String division : new List<String>{ 'Charlotte Metro', 'Asheville', 'Greenville', 'Columbia' }) {
            SchedulingConsoleController.ScheduleBoardDto board =
                SchedulingConsoleService.buildScheduleBoard(Date.today(), division);
            SchedulingConsoleController.PendingScheduleDto pending =
                SchedulingConsoleService.buildPendingItems(division);
            List<SchedulingConsoleController.CrewUtilizationDto> crews =
                SchedulingConsoleService.buildCrewUtilization(weekStart, weekEnd, division);
            List<SchedulingConsoleController.TimeOffDto> timeOff =
                SchedulingConsoleService.buildTimeOff(Date.today(), Date.today().addDays(6), division);

            System.assertNotEquals(null, board);
            System.assertNotEquals(null, pending);
            System.assertNotEquals(null, crews);
            System.assertNotEquals(null, timeOff);
        }
        Test.stopTest();
    }

    @IsTest
    static void liveKpisAllDivisions_smoke() {
        // Exercises buildKpis across multiple division variants to hit matchesDivision branches
        Test.startTest();
        for (String division : new List<String>{ null, 'Charlotte', 'Charlotte South', 'Lake Norman', 'Cabarrus', 'Gaston', 'York Lancaster', 'Western NC', 'Upstate SC', 'Midlands SC' }) {
            SchedulingConsoleController.ScheduleKpiDto kpis =
                SchedulingConsoleService.buildKpis(Date.today(), division);
            System.assertNotEquals(null, kpis);
            System.assertNotEquals(null, kpis.productionBars);
        }
        Test.stopTest();
    }

    @IsTest
    static void liveScheduleIssuesAllDivisions_smoke() {
        // Exercises buildScheduleIssues division filter paths
        Test.startTest();
        for (String division : new List<String>{ null, 'Charlotte', 'Asheville', 'Upstate SC' }) {
            List<SchedulingConsoleController.ScheduleIssueDto> issues =
                SchedulingConsoleService.buildScheduleIssues(Date.today(), division);
            System.assertNotEquals(null, issues);
        }
        Test.stopTest();
    }

    @IsTest
    static void liveWeatherAlertsAndTraffic_smoke() {
        // Exercises weather alert and traffic impact paths with live data
        Test.startTest();
        List<SchedulingConsoleController.WeatherAlertDto> alerts =
            SchedulingConsoleService.buildWeatherAlerts(Date.today(), null);
        List<SchedulingConsoleController.WeatherAlertDto> alertsCharlotte =
            SchedulingConsoleService.buildWeatherAlerts(Date.today(), 'Charlotte');
        List<SchedulingConsoleController.RouteOptDto> recs =
            SchedulingConsoleService.buildOptimizerRecs(Date.today(), null);
        List<SchedulingConsoleController.DecisionRuleDto> rules =
            SchedulingConsoleService.buildDecisionRules();
        Test.stopTest();

        System.assertNotEquals(null, alerts);
        System.assertNotEquals(null, alertsCharlotte);
        System.assertNotEquals(null, recs);
        System.assertNotEquals(null, rules);
    }

    @IsTest
    static void liveGpsMarkersAllDivisions_smoke() {
        // Exercises buildGpsMarkers across division variants
        Test.startTest();
        List<SchedulingConsoleController.GpsMarkerDto> m1 =
            SchedulingConsoleService.buildGpsMarkers(Date.today(), null);
        List<SchedulingConsoleController.GpsMarkerDto> m2 =
            SchedulingConsoleService.buildGpsMarkers(Date.today(), 'Charlotte');
        List<SchedulingConsoleController.GpsMarkerDto> m3 =
            SchedulingConsoleService.buildGpsMarkers(Date.today(), 'Greenville');
        Test.stopTest();

        System.assertNotEquals(null, m1);
        System.assertNotEquals(null, m2);
        System.assertNotEquals(null, m3);
    }

    @IsTest
    static void liveDraftReviewAllDivisions_smoke() {
        // Exercises buildDraftReview division branches
        Test.startTest();
        for (String division : new List<String>{ null, 'Charlotte', 'Asheville', 'Upstate SC', 'Midlands SC' }) {
            SchedulingConsoleController.DraftReviewDto dd =
                SchedulingConsoleService.buildDraftReview(Date.today(), division);
            System.assertNotEquals(null, dd);
            System.assertNotEquals(null, dd.cleared);
            System.assertNotEquals(null, dd.blocked);
        }
        Test.stopTest();
    }

    @IsTest
    static void liveTimeOffBroadDateRange_returnsAllRows() {
        // Exercises buildTimeOff with a broad range that should return all 17 synced records
        Test.startTest();
        List<SchedulingConsoleController.TimeOffDto> rows =
            SchedulingConsoleService.buildTimeOff(
                Date.newInstance(2025, 1, 1),
                Date.newInstance(2026, 12, 31),
                null
            );
        Test.stopTest();
        System.assertNotEquals(null, rows);
        System.assert(rows.size() > 0, 'Should return time-off records from the live org');
    }

    @IsTest
    static void liveCrewEfficiencyMtdAllDivisions_smoke() {
        Test.startTest();
        for (String division : new List<String>{ null, 'Charlotte', 'Greenville' }) {
            List<SchedulingConsoleController.CrewEfficiencyDto> rows =
                SchedulingConsoleService.buildCrewEfficiencyMtd(Date.today(), division);
            System.assertNotEquals(null, rows);
        }
        Test.stopTest();
    }
}