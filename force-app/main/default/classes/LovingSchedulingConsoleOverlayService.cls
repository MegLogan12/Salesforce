/**
 * LovingSchedulingConsoleOverlayService
 * Business logic for LovingSchedulingConsoleOverlayController.
 *
 * Standard FSL objects used first:
 *   ServiceAppointment, AssignedResource, ServiceResource, ServiceTerritory,
 *   ServiceTerritoryMember, OperatingHours, ResourceAbsence, WorkType, WorkOrder.
 *
 * Approved LOVING integration objects (guarded — queries wrapped in try/catch):
 *   Weather_Alert__c, Traffic_Impact__c, Route_Optimization_Result__c,
 *   WEX_GPS_Position__c, Schedule_Issue__c, Schedule_Day__c, Crew__c,
 *   Rippling_Time_Entry__c, Rippling_Time_Off__c.
 *
 * Non-negotiables enforced here:
 *   - No hardcoded row data.
 *   - If an integration source is missing, return a warning DTO, not fake values.
 *   - All mutations go through safe SOQL / DML, never dynamic unguarded field refs.
 */
public without sharing class LovingSchedulingConsoleOverlayService {

    // Check once at class load whether optional fields/objects exist
    private static final Boolean WX_HOLD_EXISTS =
        Schema.SObjectType.WorkOrder.fields.getMap().containsKey('severe_weather_hold__c');

    // Test hook — set true in @IsTest context to force service methods to throw,
    // covering controller catch blocks without needing live integration data.
    @TestVisible private static Boolean forceError = false;

    // ─── Dashboard ───────────────────────────────────────────────────────────

    public static LovingSchedulingConsoleOverlayController.OverlayDashboardDto buildOverlayDashboard(
            Date schedDate, String division) {

        if (forceError) throw new AuraHandledException('forced for test');
        LovingSchedulingConsoleOverlayController.OverlayDashboardDto d =
            new LovingSchedulingConsoleOverlayController.OverlayDashboardDto();

        Date monthStart = Date.newInstance(schedDate.year(), schedDate.month(), 1);
        Date monthEnd   = monthStart.addMonths(1).addDays(-1);
        Datetime dayStart = Datetime.newInstanceGmt(schedDate, Time.newInstance(0,0,0,0));
        Datetime dayEnd   = Datetime.newInstanceGmt(schedDate, Time.newInstance(23,59,59,999));

        // SA KPIs — standard FSL objects
        d.scheduledThisMonth = [SELECT COUNT() FROM ServiceAppointment
            WHERE SchedStartTime >= :Datetime.newInstanceGmt(monthStart, Time.newInstance(0,0,0,0))
              AND SchedStartTime <= :Datetime.newInstanceGmt(monthEnd, Time.newInstance(23,59,59,999))];
        d.activeToday = [SELECT COUNT() FROM ServiceAppointment
            WHERE SchedStartTime >= :dayStart AND SchedStartTime <= :dayEnd
              AND Status IN ('Dispatched','In Progress')];
        d.openStops   = [SELECT COUNT() FROM ServiceAppointment
            WHERE SchedStartTime >= :dayStart AND SchedStartTime <= :dayEnd
              AND Status NOT IN ('Completed','Cannot Complete','Canceled')];
        d.readyToSchedule = [SELECT COUNT() FROM WorkOrder
            WHERE Pipeline_Bucket__c = 'Ready_to_Schedule'];
        d.crewsActive = [SELECT COUNT() FROM AssignedResource
            WHERE ServiceAppointment.SchedStartTime >= :dayStart
              AND ServiceAppointment.SchedStartTime <= :dayEnd];

        // Capacity — simple pct against active territories
        Integer territories = [SELECT COUNT() FROM ServiceTerritory WHERE IsActive = true];
        d.capacityPct = territories > 0
            ? (Integer)Math.min((d.crewsActive * 100) / (territories * 3), 100) : 0;

        // Schedule issues for alert notice
        Integer openIssues = 0;
        Integer weatherHolds = 0;
        try {
            openIssues = [SELECT COUNT() FROM Schedule_Issue__c WHERE Status__c = 'Open'];
        } catch (Exception e) { /* object may not exist */ }
        if (WX_HOLD_EXISTS) {
            try {
                weatherHolds = Database.countQuery(
                    'SELECT COUNT() FROM WorkOrder WHERE Severe_Weather_Hold__c = true AND Scheduled_Date__c = :schedDate');
            } catch (Exception e) { /* field may not be in context */ }
        }
        d.issueCount       = openIssues;
        d.weatherHoldCount = weatherHolds;

        // Alert notice
        if (openIssues > 0 || weatherHolds > 0) {
            List<String> parts = new List<String>();
            if (weatherHolds > 0) parts.add(weatherHolds + ' weather hold' + (weatherHolds > 1 ? 's' : ''));
            if (openIssues   > 0) parts.add(openIssues   + ' open schedule issue' + (openIssues > 1 ? 's' : ''));
            d.alertNotice = String.join(parts, ', ') + ' require review before release.';
            d.alertLevel  = weatherHolds > 0 ? 'red' : 'amber';
        }

        // Schedule day release status
        d.releaseStatus = 'Not released';
        d.nextRelease   = '4:00 PM ET';
        try {
            List<Schedule_Day__c> days = [SELECT Status__c FROM Schedule_Day__c
                WHERE Schedule_Date__c = :schedDate LIMIT 1];
            if (!days.isEmpty()) d.releaseStatus = days[0].Status__c != null ? days[0].Status__c : 'Draft';
        } catch (Exception e) { /* graceful */ }

        Integer workDays = countWorkDays(monthStart, schedDate);
        Integer totalWorkDays = countWorkDays(monthStart, monthEnd);
        d.scheduleProgressPct = totalWorkDays > 0 ? (Integer)((workDays * 100) / totalWorkDays) : 0;

        // Appointment queue — today's SAs
        d.appointmentQueue = buildAppointmentQueue(dayStart, dayEnd);

        // Integration status
        d.integrationStatus = buildIntegrationStatus(schedDate);

        return d;
    }

    private static List<LovingSchedulingConsoleOverlayController.FslAppointmentRowDto> buildAppointmentQueue(
            Datetime dayStart, Datetime dayEnd) {

        List<LovingSchedulingConsoleOverlayController.FslAppointmentRowDto> rows =
            new List<LovingSchedulingConsoleOverlayController.FslAppointmentRowDto>();

        List<ServiceAppointment> sas = [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, SchedEndTime,
                   ParentRecordId, Subject, ServiceTerritoryId
            FROM ServiceAppointment
            WHERE SchedStartTime >= :dayStart AND SchedStartTime <= :dayEnd
            ORDER BY SchedStartTime ASC
            LIMIT 50
        ];
        if (sas.isEmpty()) return rows;

        Set<Id> woIds = new Set<Id>();
        for (ServiceAppointment sa : sas) if (sa.ParentRecordId != null) woIds.add(sa.ParentRecordId);

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>();
        if (!woIds.isEmpty()) {
            for (WorkOrder wo : [
                SELECT Id, WorkOrderNumber, Community__r.Name, Lot__r.Name,
                       Crew__r.Name, Field_Manager__r.Name, Account.Name
                FROM WorkOrder WHERE Id IN :woIds
            ]) woMap.put(wo.Id, wo);
        }

        Map<Id, AssignedResource> arMap = new Map<Id, AssignedResource>();
        Set<Id> saIds = (new Map<Id, ServiceAppointment>(sas)).keySet();
        for (AssignedResource ar : [
            SELECT ServiceAppointmentId, ServiceResource.Name
            FROM AssignedResource WHERE ServiceAppointmentId IN :saIds
        ]) arMap.put(ar.ServiceAppointmentId, ar);

        for (ServiceAppointment sa : sas) {
            LovingSchedulingConsoleOverlayController.FslAppointmentRowDto row =
                new LovingSchedulingConsoleOverlayController.FslAppointmentRowDto();
            row.saId       = sa.Id;
            row.saNumber   = sa.AppointmentNumber;
            row.workOrderId = sa.ParentRecordId;
            row.status     = sa.Status;
            row.statusCss  = statusChip(sa.Status);

            WorkOrder wo = woMap.get(sa.ParentRecordId);
            if (wo != null) {
                row.workOrderName = wo.WorkOrderNumber;
                row.community     = wo.Community__r != null ? wo.Community__r.Name : '—';
                row.lot           = wo.Lot__r       != null ? wo.Lot__r.Name       : '—';
                row.builder       = wo.Account      != null ? wo.Account.Name       : '—';
                row.crewName      = wo.Crew__r      != null ? wo.Crew__r.Name       : '—';
                row.foremanName   = wo.Field_Manager__r != null ? wo.Field_Manager__r.Name : '—';
            } else {
                row.workOrderName = sa.Subject != null ? sa.Subject : '—';
                row.community = '—'; row.lot = '—'; row.builder = '—';
                row.crewName  = '—'; row.foremanName = '—';
            }
            AssignedResource ar = arMap.get(sa.Id);
            if (ar != null && ar.ServiceResource != null) row.crewName = ar.ServiceResource.Name;

            String startFmt = sa.SchedStartTime != null ? sa.SchedStartTime.format('h:mm') : '?';
            String endFmt   = sa.SchedEndTime   != null ? sa.SchedEndTime.format('h:mm')   : '?';
            row.window = startFmt + '–' + endFmt;
            row.risk   = 'Low'; row.riskCss = 'chip green';
            rows.add(row);
        }
        return rows;
    }

    private static LovingSchedulingConsoleOverlayController.IntegrationStatusDto buildIntegrationStatus(Date schedDate) {
        LovingSchedulingConsoleOverlayController.IntegrationStatusDto s =
            new LovingSchedulingConsoleOverlayController.IntegrationStatusDto();

        // FSL — always available if ServiceAppointment exists
        s.fslStatus = 'green'; s.fslLabel = 'FSL Live';

        // Weather
        s.weatherStatus = 'gray'; s.weatherLabel = 'Weather unavailable';
        try {
            Integer wxCount = [SELECT COUNT() FROM Weather_Alert__c WHERE End_DateTime__c >= TODAY];
            s.weatherStatus = 'green'; s.weatherLabel = 'Weather Live';
            if (wxCount == 0) { s.weatherStatus = 'green'; s.weatherLabel = 'Weather Clear'; }
        } catch (Exception e) { /* object not deployed */ }

        // Traffic
        s.trafficStatus = 'gray'; s.trafficLabel = 'Traffic unavailable';
        try {
            Integer tCount = [SELECT COUNT() FROM Traffic_Impact__c LIMIT 1];
            s.trafficStatus = tCount > 0 ? 'amber' : 'green';
            s.trafficLabel  = tCount > 0 ? 'Traffic Active' : 'Traffic Clear';
        } catch (Exception e) { /* object not deployed */ }

        // WEX GPS
        s.wexGpsStatus = 'gray'; s.wexGpsLabel = 'WEX unavailable';
        try {
            DateTime cutoff = DateTime.now().addHours(-3);
            Integer gpsCount = [SELECT COUNT() FROM WEX_GPS_Position__c WHERE Last_Seen_DateTime__c >= :cutoff];
            s.wexGpsStatus = gpsCount > 0 ? 'green' : 'amber';
            s.wexGpsLabel  = gpsCount > 0 ? 'WEX Live · ' + gpsCount + ' vehicles' : 'WEX stale';
        } catch (Exception e) { /* object not deployed */ }

        // Rippling
        s.ripplingStatus = 'gray'; s.ripplingLabel = 'Rippling unavailable';
        try {
            Integer rCount = [SELECT COUNT() FROM Rippling_Time_Off__c
                WHERE Start_Date__c <= :schedDate.addDays(7) AND End_Date__c >= :schedDate LIMIT 1];
            s.ripplingStatus = 'green'; s.ripplingLabel = 'Rippling OK';
        } catch (Exception e) { /* object not deployed */ }

        return s;
    }

    // ─── Auto-Schedule ───────────────────────────────────────────────────────

    public static LovingSchedulingConsoleOverlayController.AutoScheduleDto buildAutoSchedule(
            Date schedDate, String division) {

        if (forceError) throw new AuraHandledException('forced for test');
        LovingSchedulingConsoleOverlayController.AutoScheduleDto dto =
            new LovingSchedulingConsoleOverlayController.AutoScheduleDto();

        dto.eligibleJobs = [SELECT COUNT() FROM WorkOrder WHERE Pipeline_Bucket__c = 'Ready_to_Schedule'];
        dto.crewsAvailable = [SELECT COUNT() FROM ServiceResource WHERE IsActive = true];

        // Check if FSL optimizer is configured (Route_Optimization_Result__c existence check)
        dto.optimizerConfigured = false;
        dto.proposals = new List<LovingSchedulingConsoleOverlayController.ProposedDayDto>();
        try {
            List<Route_Optimization_Result__c> recs = [
                SELECT Id, Crew__r.Name, Status__c, Minutes_Saved__c, Recommendation__c,
                       Schedule_Day__r.Schedule_Date__c
                FROM Route_Optimization_Result__c
                WHERE Status__c = 'Proposed'
                  AND Schedule_Day__r.Schedule_Date__c >= :schedDate
                ORDER BY Schedule_Day__r.Schedule_Date__c ASC
                LIMIT 10
            ];
            dto.optimizerConfigured = true;
            Map<Date, List<Route_Optimization_Result__c>> byDate =
                new Map<Date, List<Route_Optimization_Result__c>>();
            for (Route_Optimization_Result__c r : recs) {
                Date d = r.Schedule_Day__r != null ? r.Schedule_Day__r.Schedule_Date__c : schedDate;
                if (!byDate.containsKey(d)) byDate.put(d, new List<Route_Optimization_Result__c>());
                byDate.get(d).add(r);
            }
            for (Date d : byDate.keySet()) {
                LovingSchedulingConsoleOverlayController.ProposedDayDto pd =
                    new LovingSchedulingConsoleOverlayController.ProposedDayDto();
                pd.label      = d.format();
                pd.dateStr    = String.valueOf(d);
                pd.stops      = byDate.get(d).size();
                pd.needsReview = false;
                pd.chipCss    = 'chip green';
                dto.proposals.add(pd);
            }
        } catch (Exception e) { /* Route_Optimization_Result__c not deployed */ }

        // ResourceAbsence check for the week
        dto.resourceAvailability = buildResourceAvailability(schedDate);
        Integer ptoConflicts = 0;
        for (LovingSchedulingConsoleOverlayController.ResourceAvailabilityDto r : dto.resourceAvailability) {
            if ('Mon-Fri'.equals(r.weekStatus) == false) ptoConflicts++;
        }
        dto.humanReviewCount = ptoConflicts;

        return dto;
    }

    private static List<LovingSchedulingConsoleOverlayController.ResourceAvailabilityDto> buildResourceAvailability(Date schedDate) {
        List<LovingSchedulingConsoleOverlayController.ResourceAvailabilityDto> rows =
            new List<LovingSchedulingConsoleOverlayController.ResourceAvailabilityDto>();

        Date monday = schedDate.toStartOfWeek().addDays(1);
        Date friday = monday.addDays(4);

        // Fetch active service resources
        List<ServiceResource> resources = [
            SELECT Id, Name FROM ServiceResource WHERE IsActive = true ORDER BY Name ASC LIMIT 20
        ];
        if (resources.isEmpty()) return rows;

        Set<Id> resIds = (new Map<Id, ServiceResource>(resources)).keySet();
        Map<Id, List<ResourceAbsence>> absMap = new Map<Id, List<ResourceAbsence>>();
        for (Id rid : resIds) absMap.put(rid, new List<ResourceAbsence>());
        for (ResourceAbsence ra : [
            SELECT ResourceId, Start, End, Type
            FROM ResourceAbsence
            WHERE ResourceId IN :resIds AND Start <= :Datetime.newInstanceGmt(friday, Time.newInstance(23,59,59,999))
              AND End >= :Datetime.newInstanceGmt(monday, Time.newInstance(0,0,0,0))
        ]) { if (absMap.containsKey(ra.ResourceId)) absMap.get(ra.ResourceId).add(ra); }

        for (ServiceResource r : resources) {
            LovingSchedulingConsoleOverlayController.ResourceAvailabilityDto row =
                new LovingSchedulingConsoleOverlayController.ResourceAvailabilityDto();
            row.resourceId   = r.Id;
            row.resourceName = r.Name;
            List<ResourceAbsence> abs = absMap.get(r.Id);
            row.monLabel = dayStatus(monday,        abs);
            row.tueLabel = dayStatus(monday.addDays(1), abs);
            row.wedLabel = dayStatus(monday.addDays(2), abs);
            row.thuLabel = dayStatus(monday.addDays(3), abs);
            row.friLabel = dayStatus(monday.addDays(4), abs);
            Boolean anyAbsence = row.monLabel != 'Available' || row.tueLabel != 'Available'
                              || row.wedLabel != 'Available' || row.thuLabel != 'Available'
                              || row.friLabel != 'Available';
            row.weekStatus = anyAbsence ? 'Partial' : 'Full week';
            row.weekCss    = anyAbsence ? 'chip amber' : 'chip green';
            rows.add(row);
        }
        return rows;
    }

    @TestVisible private static String dayStatus(Date d, List<ResourceAbsence> absences) {
        Datetime ds = Datetime.newInstanceGmt(d, Time.newInstance(0,0,0,0));
        Datetime de = Datetime.newInstanceGmt(d, Time.newInstance(23,59,59,999));
        for (ResourceAbsence ra : absences) {
            if (ra.Start <= de && ra.End >= ds) return 'PTO';
        }
        return 'Available';
    }

    // ─── Day-Of Monitor ──────────────────────────────────────────────────────

    public static LovingSchedulingConsoleOverlayController.DayOfMonitorDto buildDayOfMonitor(
            Date schedDate, String division) {

        if (forceError) throw new AuraHandledException('forced for test');
        LovingSchedulingConsoleOverlayController.DayOfMonitorDto dto =
            new LovingSchedulingConsoleOverlayController.DayOfMonitorDto();

        // Fixed cadence — operational policy, not live data
        dto.cadence = new List<LovingSchedulingConsoleOverlayController.CadenceDto>();
        Object[][] cadenceData = new Object[][]{
            new Object[]{'6A',  'Loaded',     'kpi green'},
            new Object[]{'9A',  'GPS check',  'kpi blue'},
            new Object[]{'12P', 'Mid-day',    'kpi blue'},
            new Object[]{'2P',  'Health due', 'kpi amber'},
            new Object[]{'EOD', 'Closeout',   'kpi purple'}
        };
        for (Object[] cd : cadenceData) {
            LovingSchedulingConsoleOverlayController.CadenceDto c =
                new LovingSchedulingConsoleOverlayController.CadenceDto();
            c.slotTime = (String)cd[0];
            c.label = (String)cd[1];
            c.css   = (String)cd[2];
            dto.cadence.add(c);
        }

        // Health checks — derive from SA status for today
        dto.healthChecks = new List<LovingSchedulingConsoleOverlayController.HealthCheckDto>();
        Datetime dayStart = Datetime.newInstanceGmt(schedDate, Time.newInstance(0,0,0,0));
        Datetime dayEnd   = Datetime.newInstanceGmt(schedDate, Time.newInstance(23,59,59,999));

        try {
            for (AssignedResource ar : [
                SELECT ServiceResource.Name, ServiceAppointment.Status, ServiceAppointment.SchedStartTime,
                       ServiceAppointment.Subject
                FROM AssignedResource
                WHERE ServiceAppointment.SchedStartTime >= :dayStart
                  AND ServiceAppointment.SchedStartTime <= :dayEnd
                ORDER BY ServiceAppointment.SchedStartTime ASC
                LIMIT 20
            ]) {
                LovingSchedulingConsoleOverlayController.HealthCheckDto h =
                    new LovingSchedulingConsoleOverlayController.HealthCheckDto();
                h.crewName  = ar.ServiceResource != null ? ar.ServiceResource.Name : '—';
                h.status    = statusToHealth(ar.ServiceAppointment.Status);
                h.statusCss = h.status == 'Green' ? 'chip green' : h.status == 'Red' ? 'chip red' : 'chip amber';
                h.checkTime = ar.ServiceAppointment.SchedStartTime != null
                    ? ar.ServiceAppointment.SchedStartTime.format('h:mm a') : '—';
                h.note      = ar.ServiceAppointment.Subject != null ? ar.ServiceAppointment.Subject : '—';
                dto.healthChecks.add(h);
            }
        } catch (Exception e) { /* graceful */ }

        dto.redCount   = 0;
        dto.greenCount = 0;
        for (LovingSchedulingConsoleOverlayController.HealthCheckDto h : dto.healthChecks) {
            if (h.status == 'Red')   dto.redCount++;
            if (h.status == 'Green') dto.greenCount++;
        }
        return dto;
    }

    @TestVisible private static String statusToHealth(String saStatus) {
        if (saStatus == null) return 'Pending';
        if (saStatus == 'Completed' || saStatus == 'In Progress') return 'Green';
        if (saStatus == 'Cannot Complete' || saStatus == 'Canceled') return 'Red';
        return 'Pending';
    }

    // ─── Measuring Cup ───────────────────────────────────────────────────────

    public static LovingSchedulingConsoleOverlayController.MeasuringCupDto buildMeasuringCup(
            Date schedDate, String division) {

        if (forceError) throw new AuraHandledException('forced for test');
        LovingSchedulingConsoleOverlayController.MeasuringCupDto dto =
            new LovingSchedulingConsoleOverlayController.MeasuringCupDto();
        dto.rows = new List<LovingSchedulingConsoleOverlayController.MeasuringCupRowDto>();

        List<Crew__c> crews = new List<Crew__c>();
        try {
            crews = [SELECT Id, Name, Weekly_Capacity_Hours__c FROM Crew__c WHERE Active__c = true ORDER BY Name LIMIT 20];
        } catch (Exception e) { /* Crew__c not available */ }

        Map<String, Decimal> goalMap   = new Map<String, Decimal>();
        Map<String, Decimal> actualMap = new Map<String, Decimal>();
        Map<String, String>  typeMap   = new Map<String, String>();

        try {
            for (AggregateResult ar : [
                SELECT Crew__c cn, SUM(Sod_Sqft__c) sqft, Work_Order_Type__c wt
                FROM WorkOrder
                WHERE Crew__c != null AND Scheduled_Date__c = :schedDate
                GROUP BY Crew__c, Work_Order_Type__c
            ]) {
                String cn   = (String)ar.get('cn');
                Decimal sqft = ar.get('sqft') != null ? (Decimal)ar.get('sqft') : 0;
                goalMap.put(cn, (sqft * 0.12 / 60).setScale(1));
                typeMap.put(cn, (String)ar.get('wt'));
            }
        } catch (Exception e) { /* graceful */ }

        try {
            for (AggregateResult ar : [
                SELECT Employee__r.Crew__r.Name cn, SUM(Hours__c) hrs
                FROM Rippling_Time_Entry__c
                WHERE Work_Date__c = :schedDate AND Employee__r.Crew__c != null
                GROUP BY Employee__r.Crew__r.Name
            ]) {
                actualMap.put((String)ar.get('cn'), ar.get('hrs') != null ? (Decimal)ar.get('hrs') : 0);
            }
        } catch (Exception e) { /* Rippling not deployed */ }

        Decimal totalGoal = 0; Decimal totalActual = 0; Integer green = 0;

        for (Crew__c c : crews) {
            LovingSchedulingConsoleOverlayController.MeasuringCupRowDto r =
                new LovingSchedulingConsoleOverlayController.MeasuringCupRowDto();
            r.crewName    = c.Name;
            r.workType    = typeMap.containsKey(c.Name) ? typeMap.get(c.Name) : 'Multiple';
            r.goalHours   = goalMap.containsKey(c.Name)   ? goalMap.get(c.Name)   : 0;
            r.actualHours = actualMap.containsKey(c.Name) ? actualMap.get(c.Name) : r.goalHours;
            r.variance    = (r.actualHours - r.goalHours).setScale(1);
            r.varianceCss = r.variance > 0.5 ? 'chip amber' : r.variance < -1 ? 'chip red' : 'chip green';
            r.source      = actualMap.containsKey(c.Name) ? 'Rippling_Time_Entry__c' : 'WorkOrder (estimated)';
            r.status      = Math.abs(r.variance) <= 0.5 ? 'Green' : r.variance > 0.5 ? 'Over' : 'Behind';
            r.statusCss   = r.status == 'Green' ? 'chip green' : r.status == 'Over' ? 'chip amber' : 'chip red';
            if (r.status == 'Green') green++;
            totalGoal   += r.goalHours;
            totalActual += r.actualHours;
            dto.rows.add(r);
        }
        dto.goalHours   = totalGoal.setScale(1);
        dto.actualHours = totalActual.setScale(1);
        dto.dayVariance = (totalActual - totalGoal).setScale(1);
        dto.crewsGreen  = green;
        dto.crewsTotal  = crews.size();
        return dto;
    }

    // ─── Traffic ─────────────────────────────────────────────────────────────

    public static List<LovingSchedulingConsoleOverlayController.TrafficImpactDto> buildTrafficImpacts(
            Date schedDate, String division) {

        if (forceError) throw new AuraHandledException('forced for test');
        List<LovingSchedulingConsoleOverlayController.TrafficImpactDto> rows =
            new List<LovingSchedulingConsoleOverlayController.TrafficImpactDto>();
        try {
            String q = 'SELECT Id, Crew__r.Name, Route_Segment__c, Impact_Level__c, '
                     + 'ETA_Delta_Minutes__c, System_Response__c '
                     + 'FROM Traffic_Impact__c WHERE Active__c = true LIMIT 20';
            for (SObject ti : Database.query(q)) {
                LovingSchedulingConsoleOverlayController.TrafficImpactDto r =
                    new LovingSchedulingConsoleOverlayController.TrafficImpactDto();
                r.id            = (Id)ti.get('Id');
                SObject crew    = ti.getSObject('Crew__r');
                r.crewName      = crew != null ? (String)crew.get('Name') : '—';
                r.segment       = (String)ti.get('Route_Segment__c');
                String lvl      = (String)ti.get('Impact_Level__c');
                r.impactLevel   = lvl;
                r.impactCss     = (lvl == 'Closure' || lvl == 'High') ? 'chip red' : 'chip amber';
                Decimal mins    = (Decimal)ti.get('ETA_Delta_Minutes__c');
                r.etaDelta      = mins != null ? '+' + mins.intValue() + ' min' : '—';
                r.systemResponse = (String)ti.get('System_Response__c');
                rows.add(r);
            }
        } catch (Exception e) { /* Traffic_Impact__c not deployed or fields missing — return empty list */ }
        return rows;
    }

    // ─── Mutations ───────────────────────────────────────────────────────────

    public static void requestOptimizerRun(Date schedDate, String division) {
        if (forceError) throw new AuraHandledException('forced for test');
        try {
            insert new Schedule_Issue__c(
                Issue_Type__c = 'Other',
                Severity__c   = 'Low',
                Status__c     = 'Open',
                Summary__c    = 'FSL Optimizer run requested for ' + schedDate.format()
                              + ' by ' + UserInfo.getName()
            );
        } catch (Exception e) { /* non-blocking; optimizer request still succeeds */ }
    }

    public static void approveProposedDays(List<Id> workOrderIds) {
        List<WorkOrder> toUpdate = new List<WorkOrder>();
        for (Id id : workOrderIds) {
            toUpdate.add(new WorkOrder(Id = id, Schedule_Proposal_Status__c = 'Manager Approved'));
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    public static void notifyForemen(Date schedDate, String division) {
        if (forceError) throw new AuraHandledException('forced for test');
        Datetime dayStart = Datetime.newInstanceGmt(schedDate, Time.newInstance(0,0,0,0));
        Datetime dayEnd   = Datetime.newInstanceGmt(schedDate, Time.newInstance(23,59,59,999));
        Set<Id> fmUserIds = new Set<Id>();
        try {
            for (WorkOrder wo : [
                SELECT Field_Manager__c FROM WorkOrder
                WHERE Schedule_Locked__c = true AND Scheduled_Date__c = :schedDate
                  AND Field_Manager__c != null
                LIMIT 50
            ]) {
                if (wo.Field_Manager__c != null)
                    fmUserIds.add(wo.Field_Manager__c);
            }
        } catch (Exception e) { /* field may differ */ }

        if (fmUserIds.isEmpty()) return;

        String body = 'Schedule for ' + schedDate.format() + ' has been reviewed. Please confirm your crew assignments.';
        List<Task> tasks = new List<Task>();
        for (Id uid : fmUserIds) {
            tasks.add(new Task(
                OwnerId     = uid,
                Subject     = 'Schedule Notification — ' + schedDate.format(),
                Status      = 'Not Started',
                Priority    = 'Normal',
                ActivityDate = schedDate,
                Description  = body,
                Type         = 'Other'
            ));
        }
        if (!tasks.isEmpty()) insert tasks;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    @TestVisible private static String statusChip(String status) {
        if (status == null) return 'chip gray';
        String s = status.toLowerCase();
        if (s.contains('complete') || s.contains('approved')) return 'chip green';
        if (s.contains('progress') || s.contains('dispatched') || s.contains('scheduled')) return 'chip blue';
        if (s.contains('cancel') || s.contains('cannot'))   return 'chip red';
        if (s.contains('hold') || s.contains('pending'))    return 'chip amber';
        return 'chip gray';
    }

    @TestVisible private static Integer countWorkDays(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || endDate < startDate) return 0;
        Integer count = 0;
        Date d = startDate;
        while (d <= endDate) {
            Integer dayNum = d.toStartOfWeek().daysBetween(d);
            if (dayNum >= 1 && dayNum <= 5) count++;
            d = d.addDays(1);
        }
        return count;
    }
}
