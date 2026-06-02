/**
 * SchedulingConsoleController
 * @AuraEnabled entry points for lovingSchedulingConsole and child LWC components.
 * All business logic lives in SchedulingConsoleService.
 * Inputs: scheduleDate (Date), division (String, e.g. 'Charlotte'), weekStart (Date).
 */
public with sharing class SchedulingConsoleController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    /** Dashboard KPI strip — 6 tiles */
    public class ScheduleKpiDto {
        @AuraEnabled public Integer scheduledThisMonth;
        @AuraEnabled public Integer closedThisMonth;
        @AuraEnabled public Integer activeToday;
        @AuraEnabled public Integer readyToSchedule;
        @AuraEnabled public Integer workDaysThisMonth;
        @AuraEnabled public Integer remainingWorkDays;
        @AuraEnabled public Integer workDaysElapsed;
        @AuraEnabled public Decimal stopsPerDayAvg;
        @AuraEnabled public Integer monthProgressPct;
        @AuraEnabled public List<StatusBarDto> productionBars;
    }

    public class StatusBarDto {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
        @AuraEnabled public String color;
        @AuraEnabled public Integer widthPct;
    }

    /** Calendar pace card */
    public class CalendarPaceDto {
        @AuraEnabled public Integer workDaysTotal;
        @AuraEnabled public Integer workDaysElapsed;
        @AuraEnabled public Integer workDaysRemaining;
        @AuraEnabled public Decimal stopsPerDayAvg;
        @AuraEnabled public Integer monthProgressPct;
        @AuraEnabled public Integer stopsLeft;
        @AuraEnabled public Integer activeAlertCount;
    }

    /** Schedule board for a given date — list of crew rows */
    public class ScheduleBoardDto {
        @AuraEnabled public Date scheduleDate;
        @AuraEnabled public String scheduleDateDisplay;
        @AuraEnabled public Integer totalCrews;
        @AuraEnabled public Integer totalStops;
        @AuraEnabled public Decimal totalMiles;
        @AuraEnabled public Integer flagCount;
        @AuraEnabled public List<CrewBoardDto> crews;
        @AuraEnabled public Schedule_Day__c scheduleDay; // null safe if no SD record yet
    }

    public class CrewBoardDto {
        @AuraEnabled public Id crewId;
        @AuraEnabled public String crewName;
        @AuraEnabled public String foremanName;
        @AuraEnabled public Id scheduleDayId;
        @AuraEnabled public String crewColor;
        @AuraEnabled public Boolean hasFlag;
        @AuraEnabled public String flagNote;
        @AuraEnabled public String summaryChip;
        @AuraEnabled public String summaryChipCss;
        @AuraEnabled public Decimal totalMiles;
        @AuraEnabled public Integer stopCount;
        @AuraEnabled public String gpsStatus;
        @AuraEnabled public Decimal gpsLat;
        @AuraEnabled public Decimal gpsLng;
        @AuraEnabled public List<StopDto> stops;
    }

    public class StopDto {
        @AuraEnabled public Id stopId;
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public String workOrderUrl;
        @AuraEnabled public Integer stopNumber;
        @AuraEnabled public String communityName;
        @AuraEnabled public String workType;
        @AuraEnabled public Decimal estimatedDurationMinutes;
        @AuraEnabled public Decimal estimatedDriveMinutes;
        @AuraEnabled public Decimal distanceMiles;
        @AuraEnabled public Decimal sodSqft;
        @AuraEnabled public String routeStatus;
        @AuraEnabled public String weatherRisk;
        @AuraEnabled public String trafficRisk;
        @AuraEnabled public Boolean hasWarning;
        @AuraEnabled public String warningNote;
        @AuraEnabled public String address;
        @AuraEnabled public Decimal lat;
        @AuraEnabled public Decimal lng;
    }

    /** Pending items — 4 categories */
    public class PendingScheduleDto {
        @AuraEnabled public List<PendingItemDto> inventoryBlocked;
        @AuraEnabled public List<PendingItemDto> siteReadinessBlocked;
        @AuraEnabled public List<PendingItemDto> sameDayUrgent;
        @AuraEnabled public List<PendingItemDto> epoAwaiting;
    }

    public class PendingItemDto {
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String name;
        @AuraEnabled public String communityName;
        @AuraEnabled public String blockDetail;
        @AuraEnabled public String chipLabel;
        @AuraEnabled public String chipCss;
        @AuraEnabled public String icon;
        @AuraEnabled public String iconBg;
        @AuraEnabled public String url;
        @AuraEnabled public Id scheduleIssueId;
    }

    /** Schedule Issues */
    public class ScheduleIssueDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String issueType;
        @AuraEnabled public String severity;
        @AuraEnabled public String status;
        @AuraEnabled public String summary;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String crewName;
        @AuraEnabled public String severityCss;
    }

    /** Weather alert */
    public class WeatherAlertDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String alertType;
        @AuraEnabled public String severity;
        @AuraEnabled public String summary;
        @AuraEnabled public String details;
        @AuraEnabled public String startDisplay;
        @AuraEnabled public String endDisplay;
        @AuraEnabled public String division;
        @AuraEnabled public String severityCss;
        @AuraEnabled public Integer affectedStops;
    }

    /** Crew utilization row */
    public class CrewUtilizationDto {
        @AuraEnabled public Id crewId;
        @AuraEnabled public String crewName;
        @AuraEnabled public String foremanName;
        @AuraEnabled public String dotColor;
        @AuraEnabled public Decimal goalHoursWeek;
        @AuraEnabled public Decimal scheduledHoursWeek;
        @AuraEnabled public Decimal actualHoursWeek;
        @AuraEnabled public Integer efficiencyPct;
        @AuraEnabled public String effCss;
        @AuraEnabled public Boolean otRisk;
        @AuraEnabled public String otLabel;
        @AuraEnabled public String otCss;
        @AuraEnabled public String timeOffStatus;
    }

    /** Rippling time off row */
    public class TimeOffDto {
        @AuraEnabled public String employeeName;
        @AuraEnabled public Id employeeId;
        @AuraEnabled public String crewName;
        @AuraEnabled public String role;
        @AuraEnabled public String timeOffType;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String status;
        @AuraEnabled public String chipCss;
        @AuraEnabled public List<String> affectedDates; // dates in the next 7 days
    }

    /** Overtime risk row */
    public class OvertimeRiskDto {
        @AuraEnabled public String resourceName;
        @AuraEnabled public Id employeeId;
        @AuraEnabled public String crewName;
        @AuraEnabled public Decimal scheduledHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal projectedHours;
        @AuraEnabled public Boolean otRisk;
        @AuraEnabled public String otLabel;
        @AuraEnabled public String chipCss;
        @AuraEnabled public Boolean isHighlighted;
    }

    /** Crew efficiency MTD */
    public class CrewEfficiencyDto {
        @AuraEnabled public String crewName;
        @AuraEnabled public String color;
        @AuraEnabled public Integer stops;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal variance;
        @AuraEnabled public String varLabel;
        @AuraEnabled public String varCss;
        @AuraEnabled public Decimal fjPct;
        @AuraEnabled public Decimal qiScore;
    }

    /** Draft review */
    public class DraftReviewDto {
        @AuraEnabled public List<DraftCrewDto> cleared;
        @AuraEnabled public List<DraftCrewDto> blocked;
        @AuraEnabled public String draftTime;
        @AuraEnabled public Boolean hasBlocked;
        @AuraEnabled public Integer clearedCount;
        @AuraEnabled public Integer blockedCount;
        @AuraEnabled public Id scheduleDayId;
    }

    public class DraftCrewDto {
        @AuraEnabled public String crewName;
        @AuraEnabled public String foremanName;
        @AuraEnabled public Integer stops;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal routeMiles;
        @AuraEnabled public String otStatus;
        @AuraEnabled public String otCss;
        @AuraEnabled public String weatherStatus;
        @AuraEnabled public String weatherCss;
        @AuraEnabled public Boolean cleared;
        @AuraEnabled public String blockReason;
        @AuraEnabled public String chipCss;
    }

    /** Decision rule */
    public class DecisionRuleDto {
        @AuraEnabled public String condition;
        @AuraEnabled public String systemAction;
        @AuraEnabled public String requiresHuman;
        @AuraEnabled public String foremanNotified;
        @AuraEnabled public String rowCss;
        @AuraEnabled public String humanCss;
    }

    /** Route optimization result */
    public class RouteOptDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String crewName;
        @AuraEnabled public Decimal minutesSaved;
        @AuraEnabled public String recommendation;
        @AuraEnabled public String status;
        @AuraEnabled public String chipCss;
    }

    /** GPS marker for map */
    public class GpsMarkerDto {
        @AuraEnabled public String title;
        @AuraEnabled public String crewName;
        @AuraEnabled public Decimal lat;
        @AuraEnabled public Decimal lng;
        @AuraEnabled public String speedMph;
        @AuraEnabled public String ignitionStatus;
        @AuraEnabled public String lastSeen;
        @AuraEnabled public String markerColor;
        // SVG rendering fields expected by lovingSchedulingConsole.js gpsMarkers getter
        @AuraEnabled public String markerId;
        @AuraEnabled public String svgPoints;
        @AuraEnabled public String crewColor;
        @AuraEnabled public String crewLabel;
        @AuraEnabled public Decimal labelX;
        @AuraEnabled public Decimal labelY;
        @AuraEnabled public String status;
        @AuraEnabled public String routePath;
        @AuraEnabled public Boolean isDashed;
    }

    // ─── @AuraEnabled methods ────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static ScheduleKpiDto getSchedulingHomeData(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildKpis(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getSchedulingHomeData',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static ScheduleBoardDto getScheduleBoard(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildScheduleBoard(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getScheduleBoard',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static PendingScheduleDto getPendingSchedule(String division) {
        try {
            return SchedulingConsoleService.buildPendingItems(division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getPendingSchedule',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ScheduleIssueDto> getScheduleIssues(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildScheduleIssues(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getScheduleIssues',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<CrewUtilizationDto> getCrewUtilization(Date startDate, Date endDate, String division) {
        if (startDate == null) startDate = Date.today().toStartOfWeek().addDays(1);
        if (endDate   == null) endDate   = startDate.addDays(4);
        try {
            return SchedulingConsoleService.buildCrewUtilization(startDate, endDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getCrewUtilization',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<TimeOffDto> getRipplingTimeOff(Date startDate, Date endDate, String division) {
        if (startDate == null) startDate = Date.today();
        if (endDate   == null) endDate   = startDate.addDays(6);
        try {
            return SchedulingConsoleService.buildTimeOff(startDate, endDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getRipplingTimeOff',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<GpsMarkerDto> getRouteAndGpsData(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildGpsMarkers(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getRouteAndGpsData',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<WeatherAlertDto> getWeatherAlerts(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildWeatherAlerts(scheduleDate, null) /* territory-wide active alerts, not Division-filtered */;
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getWeatherAlerts',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<OvertimeRiskDto> getOvertimeRisks(Date startDate, Date endDate, String division) {
        if (startDate == null) startDate = Date.today().toStartOfWeek().addDays(1);
        if (endDate   == null) endDate   = startDate.addDays(4);
        try {
            return SchedulingConsoleService.buildOvertimeRisks(startDate, endDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getOvertimeRisks',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<RouteOptDto> getOptimizerRecommendations(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildOptimizerRecs(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getOptimizerRecommendations',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static DraftReviewDto getDraftReview(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildDraftReview(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getDraftReview',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<DecisionRuleDto> getDecisionRules() {
        try {
            return SchedulingConsoleService.buildDecisionRules();
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getDecisionRules',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<CrewEfficiencyDto> getCrewEfficiencyMtd(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildCrewEfficiencyMtd(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getCrewEfficiencyMtd',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── Actions ─────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void approveProposal(Id workOrderId) {
        try {
            SchedulingConsoleService.approveProposal(workOrderId);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','approveProposal',workOrderId,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void approveAllProposals(List<Id> workOrderIds) {
        try {
            SchedulingConsoleService.approveAllProposals(workOrderIds);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','approveAllProposals',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void rejectProposal(Id workOrderId, String reason) {
        try {
            SchedulingConsoleService.rejectProposal(workOrderId, reason);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','rejectProposal',workOrderId,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void releaseSchedule(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            SchedulingConsoleService.releaseSchedule(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','releaseSchedule',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void holdSchedule(Date scheduleDate, String division, String reason) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            SchedulingConsoleService.holdSchedule(scheduleDate, division, reason);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','holdSchedule',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void resolveScheduleIssue(Id issueId, String resolution) {
        try {
            update new Schedule_Issue__c(
                Id = issueId,
                Status__c = 'Resolved',
                Resolution_Notes__c = resolution
            );
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','resolveScheduleIssue',issueId,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void reassignStop(Id stopId, Id newCrewId, Id newFmId) {
        try {
            SchedulingConsoleService.reassignStop(stopId, newCrewId, newFmId);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','reassignStop',stopId,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void approveOvertimeOverride(Id crewId, Date scheduleDate, String reason) {
        try {
            SchedulingConsoleService.approveOvertimeOverride(crewId, scheduleDate, reason);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','approveOvertimeOverride',crewId,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 10-TAB REBUILD — DTOs and methods for new Scheduling Console architecture
    // ═══════════════════════════════════════════════════════════════════════════

    /** Today schedule — KPIs + stop list */
    public class TodayScheduleDto {
        @AuraEnabled public Integer crewsOut;
        @AuraEnabled public Integer stopsTotal;
        @AuraEnabled public Integer stopsCompleted;
        @AuraEnabled public Integer stopsRemaining;
        @AuraEnabled public Integer issueCount;
        @AuraEnabled public Integer readyCount;
        @AuraEnabled public List<TodayStopDto> stops;
    }
    public class TodayStopDto {
        @AuraEnabled public Id stopId;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String crewName;
        @AuraEnabled public String fmName;
        @AuraEnabled public String scheduledTime;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public String statusLabel;
    }

    /** Unscheduled work — WOs in pre-schedule state */
    public class UnscheduledWorkDto {
        @AuraEnabled public Id woId;
        @AuraEnabled public String woName;
        @AuraEnabled public String woType;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String fmName;
        @AuraEnabled public Integer daysWaiting;
        @AuraEnabled public String readinessLabel;
        @AuraEnabled public Boolean readinessReady;
        @AuraEnabled public String status;
    }

    /** Scheduled work — SAs with scheduled dates */
    public class ScheduledWorkDto {
        @AuraEnabled public Id saId;
        @AuraEnabled public String saNumber;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public String communityName;
        @AuraEnabled public String territory;
        @AuraEnabled public String crewName;
        @AuraEnabled public String scheduledDateDisplay;
        @AuraEnabled public Decimal durationHrs;
        @AuraEnabled public String status;
    }

    /** Blocked work — WOs with active blockers */
    public class BlockedWorkDto {
        @AuraEnabled public Id woId;
        @AuraEnabled public String woName;
        @AuraEnabled public String woType;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String fmName;
        @AuraEnabled public String blockReason;
        @AuraEnabled public String blockedSince;
        @AuraEnabled public String severity;
    }

    /** Field Manager summary */
    public class FieldManagerDto {
        @AuraEnabled public Id fmId;
        @AuraEnabled public String fmName;
        @AuraEnabled public String territory;
        @AuraEnabled public Integer openWOs;
        @AuraEnabled public Integer scheduledWOs;
        @AuraEnabled public Integer blockedWOs;
        @AuraEnabled public Integer crewsAssigned;
        @AuraEnabled public Integer crewsToday;
        @AuraEnabled public Integer stopsToday;
        @AuraEnabled public Boolean hasIssue;
    }

    /** Service Territory summary */
    public class TerritoryDto {
        @AuraEnabled public Id territoryId;
        @AuraEnabled public String territoryName;
        @AuraEnabled public String division;
        @AuraEnabled public Decimal weeklyCapacity;
        @AuraEnabled public Integer scheduledSACount;
        @AuraEnabled public Integer openWOCount;
        @AuraEnabled public Integer blockedWOCount;
        @AuraEnabled public Integer utilizationPct;
        @AuraEnabled public Boolean isOverCapacity;
    }

    /** Work Order summary */
    public class WorkOrderSummaryDto {
        @AuraEnabled public Id woId;
        @AuraEnabled public String woName;
        @AuraEnabled public String woType;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String fmName;
        @AuraEnabled public String territory;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public Integer daysOpen;
    }

    /** Service Appointment summary */
    public class ServiceAppointmentSummaryDto {
        @AuraEnabled public Id saId;
        @AuraEnabled public String saNumber;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public String territory;
        @AuraEnabled public String crewName;
        @AuraEnabled public String scheduledDateDisplay;
        @AuraEnabled public Decimal durationHrs;
        @AuraEnabled public Boolean isPinned;
        @AuraEnabled public String status;
    }

    /** Schedule Request */
    public class ScheduleRequestDto {
        @AuraEnabled public Id requestId;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public String woType;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String fmName;
        @AuraEnabled public String requestedDateDisplay;
        @AuraEnabled public String notes;
        @AuraEnabled public String status;
    }

    /** Data Issue */
    public class DataIssueDto {
        @AuraEnabled public Id issueId;
        @AuraEnabled public String recordName;
        @AuraEnabled public String objectType;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String issueType;
        @AuraEnabled public String description;
        @AuraEnabled public String severity;
        @AuraEnabled public String suggestedFix;
    }

    // ─── 10-Tab read methods ─────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static TodayScheduleDto getTodaySchedule(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildTodaySchedule(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getTodaySchedule',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<UnscheduledWorkDto> getUnscheduledWork(String division, String woType) {
        try {
            return SchedulingConsoleService.buildUnscheduledWork(division, woType);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getUnscheduledWork',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ScheduledWorkDto> getScheduledWork(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildScheduledWork(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getScheduledWork',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<BlockedWorkDto> getBlockedWork(String division) {
        try {
            return SchedulingConsoleService.buildBlockedWork(division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getBlockedWork',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldManagerDto> getFieldManagerSummary(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildFieldManagerSummary(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getFieldManagerSummary',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<TerritoryDto> getServiceTerritorySummary(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildServiceTerritorySummary(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getServiceTerritorySummary',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<WorkOrderSummaryDto> getWorkOrderSummary(String division, String woType) {
        try {
            return SchedulingConsoleService.buildWorkOrderSummary(division, woType);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getWorkOrderSummary',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ServiceAppointmentSummaryDto> getServiceAppointmentSummary(Date scheduleDate, String division) {
        if (scheduleDate == null) scheduleDate = Date.today();
        try {
            return SchedulingConsoleService.buildServiceAppointmentSummary(scheduleDate, division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getServiceAppointmentSummary',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ScheduleRequestDto> getScheduleRequests(String division) {
        try {
            return SchedulingConsoleService.buildScheduleRequests(division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getScheduleRequests',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<DataIssueDto> getDataIssues(String division) {
        try {
            return SchedulingConsoleService.buildDataIssues(division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getDataIssues',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── 10-Tab action methods ────────────────────────────────────────────────

    @AuraEnabled
    public static void markReadyForScheduling(Id woId) {
        if (woId == null) throw new AuraHandledException('Work Order ID required');
        try {
            update new WorkOrder(Id = woId, Pipeline_Bucket__c = 'Clear for Schedule');
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','markReadyForScheduling',woId,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendToScheduling(Id woId) {
        if (woId == null) throw new AuraHandledException('Work Order ID required');
        try {
            update new WorkOrder(Id = woId, Schedule_Proposal_Status__c = 'Pending Approval');
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','sendToScheduling',woId,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void createSchedulingRequest(Id requestId, String action) {
        if (requestId == null) throw new AuraHandledException('Request ID required');
        try {
            String newStatus = 'Approve'.equalsIgnoreCase(action) ? 'Resolved' : 'Open';
            update new Schedule_Issue__c(Id = requestId, Status__c = newStatus);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','createSchedulingRequest',requestId,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void markWorkOrderBlocked(Id woId, String reason) {
        if (woId == null) throw new AuraHandledException('Work Order ID required');
        try {
            update new WorkOrder(Id = woId, Pipeline_Bucket__c = 'On Hold');
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','markWorkOrderBlocked',woId,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void clearWorkOrderBlocker(Id woId) {
        if (woId == null) throw new AuraHandledException('Work Order ID required');
        try {
            update new WorkOrder(Id = woId, Pipeline_Bucket__c = 'Clear for Schedule');
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','clearWorkOrderBlocker',woId,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void refreshSchedulingConsole() {
        // No-op cachebuster — client calls this to signal a full refresh cycle.
        // Log the refresh event for audit purposes.
        try {
            ErrorLogService.log('SchedulingConsoleController','refreshSchedulingConsole',null,'Manual refresh triggered by ' + UserInfo.getName());
        } catch (Exception e) { /* non-blocking */ }
    }

    // ─── Pipeline Summary ─────────────────────────────────────────────────────
    public class PipelineSummaryDto {
        @AuraEnabled public String                bucket;
        @AuraEnabled public Integer               count;
        @AuraEnabled public String                chipCss;
        @AuraEnabled public List<PipelineLotDto>  lots;
    }
    public class PipelineLotDto {
        @AuraEnabled public Id      lotId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  fmName;
        @AuraEnabled public Integer daysUntil;
        @AuraEnabled public String  targetDateDisplay;
        @AuraEnabled public Boolean takeoffDone;
        @AuraEnabled public Boolean woCreated;
    }

    @AuraEnabled(cacheable=true)
    public static List<PipelineSummaryDto> getPipelineSummary(String division) {
        try {
            return SchedulingConsoleService.buildPipelineSummary(division);
        } catch (Exception e) {
            ErrorLogService.log('SchedulingConsoleController','getPipelineSummary',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class DivisionDto {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
    }

    @AuraEnabled(cacheable=true)
    public static List<DivisionDto> getDivisions() {
        List<DivisionDto> out = new List<DivisionDto>();
        for (LOVING_Division__mdt m : [
            SELECT Division_Value__c, Display_Label__c, Latitude__c, Longitude__c, Sort_Order__c
            FROM LOVING_Division__mdt
            WHERE Is_Active__c = true
            ORDER BY Sort_Order__c ASC, Display_Label__c ASC
        ]) {
            DivisionDto d = new DivisionDto();
            d.value     = m.Division_Value__c;
            d.label     = m.Display_Label__c;
            d.latitude  = m.Latitude__c;
            d.longitude = m.Longitude__c;
            out.add(d);
        }
        return out;
    }
}