/**
 * LovingSchedulingConsoleOverlayController
 * @AuraEnabled entry points for lovingSchedulingConsoleOverlay LWC.
 * Overlays standard FSL Dispatch. All queries use ServiceAppointment,
 * AssignedResource, ServiceResource, ServiceTerritory, ResourceAbsence,
 * Weather_Alert__c, Traffic_Impact__c, WEX_GPS_Position__c, and approved
 * LOVING objects. No hardcoded data. Business logic in Service class.
 *
 * Non-destructive reads use cacheable=true.
 * Mutations (releaseSchedule, runFslOptimizer, etc.) are in SchedulingConsoleController
 * and are reused via the LWC JS directly.
 */
public with sharing class LovingSchedulingConsoleOverlayController {

    // ─── Dashboard DTO ───────────────────────────────────────────────────────

    public class OverlayDashboardDto {
        @AuraEnabled public Integer scheduledThisMonth;
        @AuraEnabled public Integer activeToday;
        @AuraEnabled public Integer readyToSchedule;
        @AuraEnabled public Integer issueCount;
        @AuraEnabled public Integer crewsActive;
        @AuraEnabled public Integer capacityPct;
        @AuraEnabled public String  alertNotice;
        @AuraEnabled public String  alertLevel;
        @AuraEnabled public String  releaseStatus;
        @AuraEnabled public String  nextRelease;
        @AuraEnabled public Integer openStops;
        @AuraEnabled public Integer weatherHoldCount;
        @AuraEnabled public Integer scheduleProgressPct;
        @AuraEnabled public List<FslAppointmentRowDto> appointmentQueue;
        @AuraEnabled public IntegrationStatusDto integrationStatus;
    }

    public class FslAppointmentRowDto {
        @AuraEnabled public Id     saId;
        @AuraEnabled public String saNumber;
        @AuraEnabled public Id     workOrderId;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public String community;
        @AuraEnabled public String lot;
        @AuraEnabled public String builder;
        @AuraEnabled public String window;
        @AuraEnabled public String crewName;
        @AuraEnabled public String foremanName;
        @AuraEnabled public String status;
        @AuraEnabled public String statusCss;
        @AuraEnabled public String risk;
        @AuraEnabled public String riskCss;
    }

    public class IntegrationStatusDto {
        @AuraEnabled public String fslStatus;
        @AuraEnabled public String weatherStatus;
        @AuraEnabled public String trafficStatus;
        @AuraEnabled public String wexGpsStatus;
        @AuraEnabled public String ripplingStatus;
        @AuraEnabled public String fslLabel;
        @AuraEnabled public String weatherLabel;
        @AuraEnabled public String trafficLabel;
        @AuraEnabled public String wexGpsLabel;
        @AuraEnabled public String ripplingLabel;
    }

    // ─── Auto-Schedule DTO ───────────────────────────────────────────────────

    public class AutoScheduleDto {
        @AuraEnabled public Integer eligibleJobs;
        @AuraEnabled public Integer crewsAvailable;
        @AuraEnabled public Integer humanReviewCount;
        @AuraEnabled public Boolean optimizerConfigured;
        @AuraEnabled public List<ProposedDayDto>          proposals;
        @AuraEnabled public List<ResourceAvailabilityDto> resourceAvailability;
    }

    public class ProposedDayDto {
        @AuraEnabled public String  label;
        @AuraEnabled public String  dateStr;
        @AuraEnabled public Id      workOrderId;
        @AuraEnabled public Integer stops;
        @AuraEnabled public Boolean needsReview;
        @AuraEnabled public String  reviewReason;
        @AuraEnabled public String  chipCss;
    }

    public class ResourceAvailabilityDto {
        @AuraEnabled public Id     resourceId;
        @AuraEnabled public String resourceName;
        @AuraEnabled public String monLabel;
        @AuraEnabled public String tueLabel;
        @AuraEnabled public String wedLabel;
        @AuraEnabled public String thuLabel;
        @AuraEnabled public String friLabel;
        @AuraEnabled public String weekStatus;
        @AuraEnabled public String weekCss;
    }

    // ─── Day-Of Monitor DTO ──────────────────────────────────────────────────

    public class DayOfMonitorDto {
        @AuraEnabled public List<CadenceDto>    cadence;
        @AuraEnabled public List<HealthCheckDto> healthChecks;
        @AuraEnabled public Integer redCount;
        @AuraEnabled public Integer greenCount;
    }

    public class CadenceDto {
        @AuraEnabled public String time;
        @AuraEnabled public String label;
        @AuraEnabled public String css;
    }

    public class HealthCheckDto {
        @AuraEnabled public String crewName;
        @AuraEnabled public String status;
        @AuraEnabled public String statusCss;
        @AuraEnabled public String checkTime;
        @AuraEnabled public String note;
    }

    // ─── Measuring Cup DTO ───────────────────────────────────────────────────

    public class MeasuringCupDto {
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal dayVariance;
        @AuraEnabled public Integer crewsGreen;
        @AuraEnabled public Integer crewsTotal;
        @AuraEnabled public List<MeasuringCupRowDto> rows;
    }

    public class MeasuringCupRowDto {
        @AuraEnabled public String  crewName;
        @AuraEnabled public String  workType;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal variance;
        @AuraEnabled public String  varianceCss;
        @AuraEnabled public String  source;
        @AuraEnabled public String  status;
        @AuraEnabled public String  statusCss;
    }

    // ─── Traffic DTO ─────────────────────────────────────────────────────────

    public class TrafficImpactDto {
        @AuraEnabled public Id     id;
        @AuraEnabled public String crewName;
        @AuraEnabled public String route;
        @AuraEnabled public String segment;
        @AuraEnabled public String impactLevel;
        @AuraEnabled public String impactCss;
        @AuraEnabled public String etaDelta;
        @AuraEnabled public String systemResponse;
    }

    // ─── @AuraEnabled read methods ───────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static OverlayDashboardDto getOverlayDashboard(Date schedDate, String division) {
        if (schedDate == null) schedDate = Date.today();
        try {
            return LovingSchedulingConsoleOverlayService.buildOverlayDashboard(schedDate, division);
        } catch (Exception e) {
            ErrorLogService.log('LovingSchedulingConsoleOverlayController','getOverlayDashboard',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static AutoScheduleDto getAutoScheduleData(Date schedDate, String division) {
        if (schedDate == null) schedDate = Date.today();
        try {
            return LovingSchedulingConsoleOverlayService.buildAutoSchedule(schedDate, division);
        } catch (Exception e) {
            ErrorLogService.log('LovingSchedulingConsoleOverlayController','getAutoScheduleData',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static DayOfMonitorDto getDayOfMonitor(Date schedDate, String division) {
        if (schedDate == null) schedDate = Date.today();
        try {
            return LovingSchedulingConsoleOverlayService.buildDayOfMonitor(schedDate, division);
        } catch (Exception e) {
            ErrorLogService.log('LovingSchedulingConsoleOverlayController','getDayOfMonitor',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static MeasuringCupDto getMeasuringCup(Date schedDate, String division) {
        if (schedDate == null) schedDate = Date.today();
        try {
            return LovingSchedulingConsoleOverlayService.buildMeasuringCup(schedDate, division);
        } catch (Exception e) {
            ErrorLogService.log('LovingSchedulingConsoleOverlayController','getMeasuringCup',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<TrafficImpactDto> getTrafficImpacts(Date schedDate, String division) {
        if (schedDate == null) schedDate = Date.today();
        try {
            return LovingSchedulingConsoleOverlayService.buildTrafficImpacts(schedDate, division);
        } catch (Exception e) {
            ErrorLogService.log('LovingSchedulingConsoleOverlayController','getTrafficImpacts',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── @AuraEnabled mutation methods ───────────────────────────────────────

    @AuraEnabled
    public static void runFslOptimizer(Date schedDate, String division) {
        if (schedDate == null) schedDate = Date.today();
        try {
            LovingSchedulingConsoleOverlayService.requestOptimizerRun(schedDate, division);
        } catch (Exception e) {
            ErrorLogService.log('LovingSchedulingConsoleOverlayController','runFslOptimizer',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void approveProposedDays(List<Id> workOrderIds) {
        if (workOrderIds == null || workOrderIds.isEmpty()) {
            throw new AuraHandledException('No work order IDs provided');
        }
        try {
            LovingSchedulingConsoleOverlayService.approveProposedDays(workOrderIds);
        } catch (Exception e) {
            ErrorLogService.log('LovingSchedulingConsoleOverlayController','approveProposedDays',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void notifyForemen(Date schedDate, String division) {
        if (schedDate == null) schedDate = Date.today();
        try {
            LovingSchedulingConsoleOverlayService.notifyForemen(schedDate, division);
        } catch (Exception e) {
            ErrorLogService.log('LovingSchedulingConsoleOverlayController','notifyForemen',null,e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
}
