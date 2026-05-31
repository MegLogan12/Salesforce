/**
 * SchedulingConsoleService
 * Business logic for SchedulingConsoleController.
 * Queries Salesforce records, aggregates KPIs, builds DTOs.
 * Uses Work_Line_Rate__mdt for duration calculations.
 * Falls back gracefully if new objects don't have data yet.
 *
 * Production field names (WorkOrder standard FSL object):
 *   Sod_Sqft__c, Sod_Square_Footage__c, Tree_Quantity__c,
 *   Field_Manager__c, Schedule_Locked__c, Scheduled_Date__c
 */
public without sharing class SchedulingConsoleService {

    private static final String[] CREW_COLORS = new String[]{
        '#534ab7','#0070d2','#ba7517','#2e844a','#c23934','#0a8aa6','#16325c','#8b5cf6'
    };

    // Severe_Weather_Hold__c is not deployed in all orgs — check once at class load time
    private static final Boolean WX_HOLD_EXISTS =
        Schema.SObjectType.WorkOrder.fields.getMap().containsKey('severe_weather_hold__c');

    // @TestVisible flag: when true, selected methods throw to exercise controller catch blocks in tests
    @TestVisible private static Boolean throwForCoverageTest = false;
    // @TestVisible mock data: when non-null, replace SOQL results in tests (FSL blocks WO inserts in test context)
    @TestVisible private static List<WorkOrder>            mockWorkOrders           = null;
    @TestVisible private static List<Schedule_Stop__c>    mockScheduleStops        = null;
    @TestVisible private static List<ServiceAppointment>  mockServiceAppointments  = null;
    @TestVisible private static List<Schedule_Issue__c>   mockScheduleIssues       = null;

    // ─── KPIs ──────────────────────────────────────────────────────────────
    public static SchedulingConsoleController.ScheduleKpiDto buildKpis(Date schedDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        SchedulingConsoleController.ScheduleKpiDto d = new SchedulingConsoleController.ScheduleKpiDto();
        Date monthStart = Date.newInstance(schedDate.year(), schedDate.month(), 1);
        Date monthEnd   = monthStart.addMonths(1).addDays(-1);

        d.workDaysThisMonth = countWorkDays(monthStart, monthEnd);
        d.workDaysElapsed   = countWorkDays(monthStart, schedDate);
        d.remainingWorkDays = countWorkDays(schedDate, monthEnd);
        d.monthProgressPct  = d.workDaysThisMonth > 0
                              ? (Integer)((d.workDaysElapsed * 100) / d.workDaysThisMonth) : 0;

        d.scheduledThisMonth = [SELECT COUNT() FROM WorkOrder
            WHERE Schedule_Locked__c = true AND Scheduled_Date__c >= :monthStart AND Scheduled_Date__c <= :monthEnd];
        d.activeToday = [SELECT COUNT() FROM WorkOrder
            WHERE Schedule_Locked__c = true AND Scheduled_Date__c = TODAY];
        d.readyToSchedule = [SELECT COUNT() FROM WorkOrder
            WHERE Pipeline_Bucket__c = 'Clear for Schedule' AND Schedule_Locked__c = false];

        List<String> closedStatuses = new List<String>{'Approved','Invoiced','Paid','Closed','Pending Closeout','FM QI Review'};
        d.closedThisMonth = [SELECT COUNT() FROM WorkOrder
            WHERE Status IN :closedStatuses
              AND Closed_Date__c >= :monthStart AND Closed_Date__c <= :monthEnd];

        d.stopsPerDayAvg = d.workDaysElapsed > 0
                           ? (d.closedThisMonth * 1.0 / d.workDaysElapsed).setScale(1) : 0;

        Map<String, Object[]> buckets = new Map<String, Object[]>{
            'Approved / Closed'          => new Object[]{'#2e844a', new List<String>{'Approved','Invoiced','Paid','Closed'}},
            'In Progress'                => new Object[]{'#534ab7', new List<String>{'In Progress','Pending Closeout','FM QI Review'}},
            'Scheduled — upcoming'       => new Object[]{'#0070d2', new List<String>{'Scheduled'}},
            'Ready to Schedule'          => new Object[]{'#ba7517', new List<String>{'Ready to Schedule'}},
            'Finish Jobs / NFI'          => new Object[]{'#c23934', new List<String>{'NFI','Pending Approval'}}
        };
        List<SchedulingConsoleController.StatusBarDto> bars = new List<SchedulingConsoleController.StatusBarDto>();
        Integer maxCount = 1;
        for (String lbl : buckets.keySet()) {
            Object[] cfg = buckets.get(lbl);
            List<String> statuses = (List<String>)cfg[1];
            Integer cnt = [SELECT COUNT() FROM WorkOrder
                WHERE Status IN :statuses
                  AND Scheduled_Date__c >= :monthStart AND Scheduled_Date__c <= :monthEnd];
            SchedulingConsoleController.StatusBarDto b = new SchedulingConsoleController.StatusBarDto();
            b.label = lbl; b.count = cnt; b.color = (String)cfg[0];
            bars.add(b);
            if (cnt > maxCount) maxCount = cnt;
        }
        for (SchedulingConsoleController.StatusBarDto b : bars) {
            b.widthPct = maxCount > 0 ? (Integer)((b.count * 100) / maxCount) : 0;
            if (b.widthPct < 2 && b.count > 0) b.widthPct = 2;
        }
        d.productionBars = bars;
        return d;
    }

    // ─── Schedule Board ─────────────────────────────────────────────────────
    public static SchedulingConsoleController.ScheduleBoardDto buildScheduleBoard(Date schedDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        SchedulingConsoleController.ScheduleBoardDto board = new SchedulingConsoleController.ScheduleBoardDto();
        board.scheduleDate = schedDate;
        board.scheduleDateDisplay = schedDate.format();
        board.crews = new List<SchedulingConsoleController.CrewBoardDto>();

        List<Schedule_Day__c> days = [
            SELECT Id, Status__c, Total_Jobs__c, Total_Crews__c, Weather_Risk__c, Traffic_Risk__c
            FROM Schedule_Day__c
            WHERE Schedule_Date__c = :schedDate
            LIMIT 1
        ];

        if (!days.isEmpty()) {
            board.scheduleDay = days[0];
            List<Schedule_Stop__c> stops = mockScheduleStops != null ? mockScheduleStops : [
                SELECT Id, Work_Order__c, Crew__c, Crew__r.Name, Field_Manager__c, Field_Manager__r.Name,
                       Stop_Number__c, Estimated_Duration_Minutes__c, Estimated_Drive_Time_Minutes__c,
                       Route_Status__c, GPS_Latitude__c, GPS_Longitude__c, Address__c,
                       Weather_Risk__c, Traffic_Risk__c, Notes__c,
                       Work_Order__r.Name, Work_Order__r.Community__r.Name,
                       Work_Order__r.Work_Order_Type__c, Work_Order__r.Sod_Sqft__c,
                       Work_Order__r.Route_Distance_Miles__c
                FROM Schedule_Stop__c
                WHERE Schedule_Day__c = :days[0].Id
                ORDER BY Crew__c, Stop_Number__c ASC NULLS LAST
                LIMIT 500
            ];
            board = buildBoardFromStops(board, stops, division);
        } else {
            // Fallback: query WorkOrder directly
            List<WorkOrder> wos = mockWorkOrders != null ? mockWorkOrders : [
                SELECT Id, WorkOrderNumber, Crew__c, Crew__r.Name, Field_Manager__r.Name, Stop_Sequence__c,
                       Route_Distance_Miles__c, Status, Community__r.Name,
                       Sod_Sqft__c, Work_Order_Type__c,
                       Lot_Latitude__c, Lot_Longitude__c
                FROM WorkOrder
                WHERE Schedule_Locked__c = true AND Scheduled_Date__c = :schedDate
                ORDER BY Crew__c ASC NULLS LAST, Stop_Sequence__c ASC NULLS LAST
                LIMIT 200
            ];
            board = buildBoardFromWos(board, wos, division);
        }

        Map<String, SchedulingConsoleController.GpsMarkerDto> gpsMap = buildGpsMap(schedDate, division);
        for (SchedulingConsoleController.CrewBoardDto crew : board.crews) {
            if (gpsMap.containsKey(crew.crewName)) {
                SchedulingConsoleController.GpsMarkerDto gps = gpsMap.get(crew.crewName);
                crew.gpsLat    = gps.lat;
                crew.gpsLng    = gps.lng;
                crew.gpsStatus = gps.ignitionStatus;
            }
        }
        return board;
    }

    private static SchedulingConsoleController.ScheduleBoardDto buildBoardFromStops(
            SchedulingConsoleController.ScheduleBoardDto board,
            List<Schedule_Stop__c> stops, String division) {

        Map<Id, List<Schedule_Stop__c>> crewStopMap = new Map<Id, List<Schedule_Stop__c>>();
        for (Schedule_Stop__c s : stops) {
            if (!crewStopMap.containsKey(s.Crew__c)) crewStopMap.put(s.Crew__c, new List<Schedule_Stop__c>());
            crewStopMap.get(s.Crew__c).add(s);
        }

        Integer ci = 0; Integer totalStops = 0; Decimal totalMiles = 0; Integer flagCount = 0;

        for (Id crewId : crewStopMap.keySet()) {
            List<Schedule_Stop__c> cStops = crewStopMap.get(crewId);
            SchedulingConsoleController.CrewBoardDto crew = new SchedulingConsoleController.CrewBoardDto();
            crew.crewId    = crewId;
            crew.crewName  = cStops[0].Crew__r != null ? cStops[0].Crew__r.Name : 'Crew';
            crew.foremanName = cStops[0].Field_Manager__r != null ? cStops[0].Field_Manager__r.Name : '—';
            crew.crewColor = CREW_COLORS[Math.mod(ci, CREW_COLORS.size())]; ci++;
            crew.stops     = new List<SchedulingConsoleController.StopDto>();

            Boolean hasFlag = false; String flagNote = ''; Decimal crewMiles = 0;
            for (Schedule_Stop__c s : cStops) {
                SchedulingConsoleController.StopDto st = new SchedulingConsoleController.StopDto();
                st.stopId    = s.Id;
                st.workOrderId   = s.Work_Order__c;
                st.workOrderName = s.Work_Order__r != null ? s.Work_Order__r.Name : '—';
                st.workOrderUrl  = s.Work_Order__c != null ? '/' + s.Work_Order__c : '#';
                st.stopNumber    = s.Stop_Number__c != null ? (Integer)s.Stop_Number__c : 0;
                st.communityName = s.Work_Order__r?.Community__r != null ? s.Work_Order__r.Community__r.Name : '—';
                st.workType      = s.Work_Order__r?.Work_Order_Type__c != null ? s.Work_Order__r.Work_Order_Type__c : 'PL';
                st.estimatedDurationMinutes = s.Estimated_Duration_Minutes__c;
                st.estimatedDriveMinutes    = s.Estimated_Drive_Time_Minutes__c;
                st.distanceMiles = s.Work_Order__r?.Route_Distance_Miles__c;
                st.sodSqft       = s.Work_Order__r?.Sod_Sqft__c;
                st.routeStatus   = s.Route_Status__c;
                st.weatherRisk   = s.Weather_Risk__c;
                st.trafficRisk   = s.Traffic_Risk__c;
                st.lat           = s.GPS_Latitude__c;
                st.lng           = s.GPS_Longitude__c;
                st.address       = s.Address__c;
                Boolean hi     = s.Weather_Risk__c == 'High' || s.Weather_Risk__c == 'Severe'
                              || s.Traffic_Risk__c == 'High' || s.Traffic_Risk__c == 'Severe';
                st.hasWarning  = hi;
                st.warningNote = hi ? s.Weather_Risk__c + ' risk' : '';
                if (st.hasWarning) { hasFlag = true; flagNote = st.warningNote; flagCount++; }
                if (s.Work_Order__r?.Route_Distance_Miles__c != null) crewMiles += s.Work_Order__r.Route_Distance_Miles__c;
                crew.stops.add(st);
                totalStops++;
            }
            crew.hasFlag      = hasFlag;
            crew.flagNote     = flagNote;
            crew.totalMiles   = crewMiles.setScale(1);
            crew.stopCount    = cStops.size();
            crew.summaryChip  = hasFlag ? flagNote : 'No flags · ' + crewMiles.setScale(0) + ' mi';
            crew.summaryChipCss = hasFlag ? 'chip chip-amber' : 'chip chip-green';
            board.crews.add(crew);
            totalMiles += crewMiles;
        }
        board.totalCrews = board.crews.size();
        board.totalStops = totalStops;
        board.totalMiles = totalMiles.setScale(1);
        board.flagCount  = flagCount;
        return board;
    }

    private static SchedulingConsoleController.ScheduleBoardDto buildBoardFromWos(
            SchedulingConsoleController.ScheduleBoardDto board,
            List<WorkOrder> wos, String division) {

        Map<String, List<WorkOrder>> crewMap = new Map<String, List<WorkOrder>>();
        for (WorkOrder wo : wos) {
            String cn = wo.Crew__c != null ? (String)wo.Crew__c : 'Unassigned';
            if (!crewMap.containsKey(cn)) crewMap.put(cn, new List<WorkOrder>());
            crewMap.get(cn).add(wo);
        }

        Integer ci = 0; Integer totalStops = 0; Decimal totalMiles = 0; Integer flagCount = 0;
        for (String cName : crewMap.keySet()) {
            List<WorkOrder> cWos = crewMap.get(cName);
            SchedulingConsoleController.CrewBoardDto crew = new SchedulingConsoleController.CrewBoardDto();
            crew.crewId      = cWos[0].Crew__c != null ? (Id)cWos[0].Crew__c : null;
            crew.crewName    = cWos[0].Crew__r != null ? cWos[0].Crew__r.Name : (crew.crewId != null ? cName : 'Unassigned');
            crew.foremanName = cWos[0].Field_Manager__r != null ? cWos[0].Field_Manager__r.Name : '—';
            crew.crewColor   = CREW_COLORS[Math.mod(ci, CREW_COLORS.size())]; ci++;
            crew.stops       = new List<SchedulingConsoleController.StopDto>();

            Boolean hasFlag = false; String flagNote = ''; Decimal crewMiles = 0;
            for (WorkOrder wo : cWos) {
                SchedulingConsoleController.StopDto st = new SchedulingConsoleController.StopDto();
                st.workOrderId   = wo.Id;
                st.workOrderName = wo.WorkOrderNumber;
                st.workOrderUrl  = '/' + wo.Id;
                st.stopNumber    = wo.Stop_Sequence__c != null ? (Integer)wo.Stop_Sequence__c : 0;
                st.communityName = wo.Community__r != null ? wo.Community__r.Name : '—';
                st.workType      = wo.Work_Order_Type__c != null ? wo.Work_Order_Type__c : 'PL';
                st.distanceMiles = wo.Route_Distance_Miles__c;
                st.sodSqft       = wo.Sod_Sqft__c;
                st.estimatedDurationMinutes = wo.Sod_Sqft__c != null ? wo.Sod_Sqft__c * 0.12 : 0;
                st.lat           = wo.Lot_Latitude__c;
                st.lng           = wo.Lot_Longitude__c;
                st.hasWarning    = false;
                st.warningNote   = '';
                if (st.hasWarning) { hasFlag = true; flagNote = st.warningNote; flagCount++; }
                if (wo.Route_Distance_Miles__c != null) crewMiles += wo.Route_Distance_Miles__c;
                crew.stops.add(st);
                totalStops++;
            }
            crew.hasFlag       = hasFlag;
            crew.flagNote      = flagNote;
            crew.totalMiles    = crewMiles.setScale(1);
            crew.stopCount     = cWos.size();
            crew.summaryChip   = hasFlag ? flagNote : 'No flags · ' + crewMiles.setScale(0) + ' mi';
            crew.summaryChipCss = hasFlag ? 'chip chip-amber' : 'chip chip-green';
            board.crews.add(crew);
            totalMiles += crewMiles;
        }
        board.totalCrews = board.crews.size();
        board.totalStops = totalStops;
        board.totalMiles = totalMiles.setScale(1);
        board.flagCount  = flagCount;
        return board;
    }

    // ─── GPS ─────────────────────────────────────────────────────────────────
    public static List<SchedulingConsoleController.GpsMarkerDto> buildGpsMarkers(Date schedDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.GpsMarkerDto> markers = new List<SchedulingConsoleController.GpsMarkerDto>();
        try {
            // Charlotte metro service area map bounds.
            // These align the vehicle pins with the hardcoded depot SVG at (260,190)
            // which corresponds to lat ~35.19, lng ~-80.83 (south Charlotte/Myers Park area).
            // SW bound: lat 34.65, lng -81.25   NE bound: lat 35.85, lng -80.15
            final Decimal LNG_MIN   = -81.25;
            final Decimal LNG_RANGE = 1.10;
            final Decimal LAT_MAX   = 35.85;
            final Decimal LAT_RANGE = 1.20;
            final Decimal SVG_W     = 680;
            final Decimal SVG_H     = 340;
            final Decimal PIN_HALF  = 8;    // half-width of triangle pin
            final Decimal PIN_H_TOP = 12;   // pixels above center to pin apex
            final Decimal PIN_H_BOT = 4;    // pixels below center to pin base

            DateTime cutoff = DateTime.now().addHours(-8);
            Integer ci = 0;
            for (WEX_GPS_Position__c gps : [
                SELECT Id, Driver__c, Driver__r.Name, Crew__c, Crew__r.Name,
                       Latitude__c, Longitude__c,
                       Speed_MPH__c, Ignition_Status__c, Last_Seen_DateTime__c
                FROM WEX_GPS_Position__c
                WHERE Last_Seen_DateTime__c >= :cutoff
                ORDER BY Last_Seen_DateTime__c DESC NULLS LAST
                LIMIT 20
            ]) {
                if (gps.Latitude__c == null || gps.Longitude__c == null) { continue; }

                SchedulingConsoleController.GpsMarkerDto m = new SchedulingConsoleController.GpsMarkerDto();

                // Label: prefer crew name; fall back to driver (Employee) name; then generic
                String label = (gps.Crew__r   != null) ? gps.Crew__r.Name
                             : (gps.Driver__r  != null) ? gps.Driver__r.Name
                             : 'Vehicle';
                String color = CREW_COLORS[Math.mod(ci, CREW_COLORS.size())]; ci++;

                m.crewName       = label;
                m.title          = label;
                m.markerId       = (String)gps.Id;
                m.crewLabel      = label;
                m.lat            = gps.Latitude__c;
                m.lng            = gps.Longitude__c;
                m.speedMph       = gps.Speed_MPH__c != null ? gps.Speed_MPH__c.setScale(0) + ' mph' : '—';
                m.ignitionStatus = gps.Ignition_Status__c;
                m.lastSeen       = gps.Last_Seen_DateTime__c != null ? gps.Last_Seen_DateTime__c.format() : '—';
                m.markerColor    = color;
                m.crewColor      = color;
                m.status         = String.isNotBlank(gps.Ignition_Status__c) ? gps.Ignition_Status__c : 'Unknown';
                m.routePath      = '';
                m.isDashed       = false;

                // Convert lat/lng to SVG pixel coordinates and clamp to viewBox edges
                Decimal rawX = (gps.Longitude__c - LNG_MIN) / LNG_RANGE * SVG_W;
                Decimal rawY = (LAT_MAX - gps.Latitude__c) / LAT_RANGE * SVG_H;
                Decimal cx = (rawX < PIN_HALF) ? PIN_HALF : (rawX > SVG_W - PIN_HALF ? SVG_W - PIN_HALF : rawX);
                Decimal cy = (rawY < PIN_H_TOP) ? PIN_H_TOP : (rawY > SVG_H - PIN_H_BOT ? SVG_H - PIN_H_BOT : rawY);
                cx = cx.setScale(1);
                cy = cy.setScale(1);

                // Upward-pointing triangle: apex at top, base below center
                m.svgPoints = cx + ',' + (cy - PIN_H_TOP).setScale(1)
                            + ' ' + (cx - PIN_HALF).setScale(1) + ',' + (cy + PIN_H_BOT).setScale(1)
                            + ' ' + (cx + PIN_HALF).setScale(1) + ',' + (cy + PIN_H_BOT).setScale(1);
                m.labelX = (cx + PIN_HALF + 2).setScale(1);
                m.labelY = (cy - 4).setScale(1);

                markers.add(m);
            }
        } catch (Exception e) { /* GPS table may not exist yet */ }
        return markers;
    }

    private static Map<String, SchedulingConsoleController.GpsMarkerDto> buildGpsMap(Date schedDate, String division) {
        Map<String, SchedulingConsoleController.GpsMarkerDto> m = new Map<String, SchedulingConsoleController.GpsMarkerDto>();
        for (SchedulingConsoleController.GpsMarkerDto gps : buildGpsMarkers(schedDate, division)) {
            m.put(gps.crewName, gps);
        }
        return m;
    }

    // ─── Weather alerts ──────────────────────────────────────────────────────
    public static List<SchedulingConsoleController.WeatherAlertDto> buildWeatherAlerts(Date schedDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.WeatherAlertDto> result = new List<SchedulingConsoleController.WeatherAlertDto>();
        try {
            List<Weather_Alert__c> alerts;
            if (String.isBlank(division)) {
                alerts = [
                    SELECT Id, Alert_Type__c, Severity__c, Summary__c, Details__c,
                           Start_DateTime__c, End_DateTime__c, Division__c
                    FROM Weather_Alert__c
                    WHERE End_DateTime__c >= TODAY
                    ORDER BY Severity__c DESC, Start_DateTime__c ASC LIMIT 20
                ];
            } else {
                alerts = [
                    SELECT Id, Alert_Type__c, Severity__c, Summary__c, Details__c,
                           Start_DateTime__c, End_DateTime__c, Division__c
                    FROM Weather_Alert__c
                    WHERE Division__c = :division AND End_DateTime__c >= TODAY
                    ORDER BY Severity__c DESC, Start_DateTime__c ASC LIMIT 20
                ];
            }
            for (Weather_Alert__c wa : alerts) {
                SchedulingConsoleController.WeatherAlertDto d = new SchedulingConsoleController.WeatherAlertDto();
                d.id           = wa.Id;
                d.alertType    = wa.Alert_Type__c;
                d.severity     = wa.Severity__c;
                d.summary      = wa.Summary__c;
                d.details      = wa.Details__c;
                d.startDisplay = wa.Start_DateTime__c != null ? wa.Start_DateTime__c.format() : '—';
                d.endDisplay   = wa.End_DateTime__c   != null ? wa.End_DateTime__c.format()   : '—';
                d.division     = wa.Division__c;
                d.severityCss  = wa.Severity__c == 'Severe' ? 'chip chip-red'
                               : wa.Severity__c == 'High'   ? 'chip chip-amber'
                               : 'chip chip-blue';
                if (WX_HOLD_EXISTS) {
                    d.affectedStops = Database.countQuery(
                        'SELECT COUNT() FROM WorkOrder WHERE Severe_Weather_Hold__c = true'
                        + ' AND Schedule_Locked__c = true AND Scheduled_Date__c >= :schedDate');
                } else {
                    d.affectedStops = 0;
                }
                result.add(d);
            }
        } catch (Exception e) { /* graceful fallback */ }
        return result;
    }

    // ─── Pending items ───────────────────────────────────────────────────────
    public static SchedulingConsoleController.PendingScheduleDto buildPendingItems(String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        SchedulingConsoleController.PendingScheduleDto pi = new SchedulingConsoleController.PendingScheduleDto();
        pi.inventoryBlocked     = new List<SchedulingConsoleController.PendingItemDto>();
        pi.siteReadinessBlocked = new List<SchedulingConsoleController.PendingItemDto>();
        pi.sameDayUrgent        = new List<SchedulingConsoleController.PendingItemDto>();
        pi.epoAwaiting          = new List<SchedulingConsoleController.PendingItemDto>();

        Map<Id, Schedule_Issue__c> issueMap = new Map<Id, Schedule_Issue__c>();
        try {
            for (Schedule_Issue__c si : [
                SELECT Id, Standard_WorkOrder__c, Issue_Type__c, Severity__c, Summary__c
                FROM Schedule_Issue__c
                WHERE Status__c IN ('Open','In Review')
                LIMIT 200
            ]) {
                if (si.Standard_WorkOrder__c != null)  issueMap.put(si.Standard_WorkOrder__c, si);
            }
        } catch (Exception e) { /* table may not exist */ }

        // 1. Inventory blocked via Pull Tickets
        Set<Id> invWoIds = new Set<Id>();
        for (Pull_Ticket__c pt : [SELECT Work_Order__c FROM Pull_Ticket__c
            WHERE Status__c = 'Pending Pull' LIMIT 50]) {
            if (pt.Work_Order__c != null) invWoIds.add(pt.Work_Order__c);
        }
        for (WorkOrder wo : [SELECT Id, WorkOrderNumber, Community__r.Name, Sod_Sqft__c, Sod_Species__c
            FROM WorkOrder WHERE Id IN :invWoIds ORDER BY WorkOrderNumber ASC LIMIT 20]) {
            SchedulingConsoleController.PendingItemDto r = makePendingRow(wo, '📦', '#fef3c7', 'Pull pending', 'chip chip-amber');
            r.blockDetail = (wo.Sod_Species__c != null ? wo.Sod_Species__c : 'Sod')
                            + (wo.Sod_Sqft__c != null ? ' · ' + wo.Sod_Sqft__c.intValue() + ' sf' : '');
            if (issueMap.containsKey(wo.Id)) r.scheduleIssueId = issueMap.get(wo.Id).Id;
            pi.inventoryBlocked.add(r);
        }

        // 2. Site readiness
        Date today = Date.today();
        Set<Id> srIds = new Set<Id>();
        for (Task t : [SELECT WhatId FROM Task WHERE Type='Site Readiness' AND Status!='Completed'
            AND ActivityDate <= :today.addDays(3) LIMIT 50]) if(t.WhatId!=null) srIds.add(t.WhatId);
        for (WorkOrder wo : [SELECT Id, WorkOrderNumber, Community__r.Name, Site_Not_Ready_Reason__c
            FROM WorkOrder WHERE Id IN :srIds AND Schedule_Locked__c = false ORDER BY WorkOrderNumber LIMIT 20]) {
            SchedulingConsoleController.PendingItemDto r = makePendingRow(wo, '🏗', '#e3f0fb', 'Site hold', 'chip chip-red');
            r.blockDetail = String.isNotBlank(wo.Site_Not_Ready_Reason__c) ? wo.Site_Not_Ready_Reason__c : 'Pending clearance';
            pi.siteReadinessBlocked.add(r);
        }

        // 3. Same-day urgent
        // Sub_Status__c not yet deployed. When deployed, add:
        //   OR Sub_Status__c = 'Same Day' to the WHERE clause
        //   and Sub_Status__c to the SELECT.
        for (WorkOrder wo : [SELECT Id, WorkOrderNumber, Community__r.Name, Status, Work_Order_Type__c
            FROM WorkOrder WHERE Status = 'NFI'
            AND Schedule_Locked__c = true AND Scheduled_Date__c = TODAY ORDER BY WorkOrderNumber LIMIT 10]) {
            SchedulingConsoleController.PendingItemDto r = makePendingRow(wo, '🚨', '#fce8e8', 'Urgent', 'chip chip-red');
            r.blockDetail = (wo.Work_Order_Type__c != null ? wo.Work_Order_Type__c + ' · ' : '') + wo.Status;
            pi.sameDayUrgent.add(r);
        }

        // 4. EPO awaiting
        // Sub_Status__c not yet deployed. Dynamic SOQL used so this compiles without the field.
        // When Sub_Status__c is deployed, this block will activate automatically.
        try {
            SObjectType woType = Schema.getGlobalDescribe().get('WorkOrder');
            if (woType != null && woType.getDescribe().fields.getMap().containsKey('sub_status__c')) {
                String q = 'SELECT Id, WorkOrderNumber, Community__r.Name FROM WorkOrder '
                         + 'WHERE Sub_Status__c = \'EPO Pending\' '
                         + 'ORDER BY WorkOrderNumber ASC NULLS LAST LIMIT 10';
                for (SObject obj : Database.query(q)) {
                    WorkOrder wo = (WorkOrder)obj;
                    SchedulingConsoleController.PendingItemDto r = makePendingRow(wo, '📄', '#e3f0fb', 'EPO Pending', 'chip chip-amber');
                    r.blockDetail = 'EPO pending — awaiting permit';
                    pi.epoAwaiting.add(r);
                }
            }
        } catch (Exception e) { /* Sub_Status__c not yet deployed */ }
        return pi;
    }

    private static SchedulingConsoleController.PendingItemDto makePendingRow(
            WorkOrder wo, String icon, String iconBg, String chipLabel, String chipCss) {
        SchedulingConsoleController.PendingItemDto r = new SchedulingConsoleController.PendingItemDto();
        r.workOrderId   = wo.Id;
        r.name          = wo.WorkOrderNumber;
        r.communityName = wo.Community__r != null ? wo.Community__r.Name : '—';
        r.icon          = icon;
        r.iconBg        = iconBg;
        r.chipLabel     = chipLabel;
        r.chipCss       = chipCss;
        r.url           = '/' + wo.Id;
        return r;
    }

    // ─── Schedule Issues ─────────────────────────────────────────────────────
    public static List<SchedulingConsoleController.ScheduleIssueDto> buildScheduleIssues(Date schedDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.ScheduleIssueDto> result = new List<SchedulingConsoleController.ScheduleIssueDto>();
        try {
            for (Schedule_Issue__c si : [
                SELECT Id, Name, Issue_Type__c, Severity__c, Status__c, Summary__c,
                       Standard_WorkOrder__c, Standard_WorkOrder__r.WorkOrderNumber,
                       Crew__r.Name
                FROM Schedule_Issue__c
                WHERE Status__c IN ('Open','In Review')
                ORDER BY Severity__c DESC, Name ASC
                LIMIT 50
            ]) {
                SchedulingConsoleController.ScheduleIssueDto d = new SchedulingConsoleController.ScheduleIssueDto();
                d.id           = si.Id;
                d.name         = si.Name;
                d.issueType    = si.Issue_Type__c;
                d.severity     = si.Severity__c;
                d.status       = si.Status__c;
                d.summary      = si.Summary__c;
                d.workOrderId   = si.Standard_WorkOrder__c;
                d.workOrderName = si.Standard_WorkOrder__r != null ? si.Standard_WorkOrder__r.WorkOrderNumber : '—';
                d.crewName      = si.Crew__r != null ? si.Crew__r.Name : '—';
                d.severityCss   = si.Severity__c == 'Critical' ? 'chip chip-red'
                                : si.Severity__c == 'High'     ? 'chip chip-amber'
                                : 'chip chip-blue';
                result.add(d);
            }
        } catch (Exception e) { /* graceful fallback */ }

        // Also add weather holds from WorkOrder — only if field exists in this org
        if (WX_HOLD_EXISTS) {
            for (SObject wo : Database.query(
                'SELECT Id, WorkOrderNumber, Community__r.Name, Crew__c, Crew__r.Name, Scheduled_Date__c'
                + ' FROM WorkOrder WHERE Severe_Weather_Hold__c = true AND Schedule_Locked__c = true LIMIT 20'
            )) {
                SchedulingConsoleController.ScheduleIssueDto d = new SchedulingConsoleController.ScheduleIssueDto();
                d.id          = (Id)wo.get('Id');
                d.issueType   = 'Weather';
                d.severity    = 'High';
                d.status      = 'Open';
                d.summary     = 'Severe weather hold active';
                d.workOrderName = (String)wo.get('WorkOrderNumber');
                d.workOrderId   = (Id)wo.get('Id');
                SObject crew = wo.getSObject('Crew__r');
                d.crewName    = crew != null ? (String)crew.get('Name') : '—';
                d.severityCss = 'chip chip-amber';
                result.add(d);
            }
        }
        return result;
    }

    // ─── Crew utilization ────────────────────────────────────────────────────
    public static List<SchedulingConsoleController.CrewUtilizationDto> buildCrewUtilization(
            Date startDate, Date endDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.CrewUtilizationDto> rows = new List<SchedulingConsoleController.CrewUtilizationDto>();
        List<Crew__c> crews = [
            SELECT Id, Name, Foreman__r.Name, Weekly_Capacity_Hours__c, Active__c
            FROM Crew__c WHERE Active__c = true ORDER BY Name ASC LIMIT 20
        ];
        if (crews.isEmpty()) return rows;

        Map<String, Decimal> schedHrs = new Map<String, Decimal>();
        for (AggregateResult ar : [
            SELECT Crew__c crName, SUM(Sod_Sqft__c) sqft
            FROM WorkOrder
            WHERE Schedule_Locked__c = true AND Scheduled_Date__c >= :startDate AND Scheduled_Date__c <= :endDate
              AND Crew__c != null GROUP BY Crew__c
        ]) {
            Decimal sqft = ar.get('sqft') != null ? (Decimal)ar.get('sqft') : 0;
            schedHrs.put((String)ar.get('crName'), (sqft * 0.12 / 60).setScale(1));
        }

        Map<String, Decimal> actualHrs = new Map<String, Decimal>();
        try {
            for (AggregateResult ar : [
                SELECT Employee__r.Crew__r.Name crName, SUM(Hours__c) hrs
                FROM Rippling_Time_Entry__c
                WHERE Work_Date__c >= :startDate AND Work_Date__c <= :endDate
                  AND Employee__r.Crew__c != null
                GROUP BY Employee__r.Crew__r.Name
            ]) {
                actualHrs.put((String)ar.get('crName'),
                    ar.get('hrs') != null ? (Decimal)ar.get('hrs') : 0);
            }
        } catch (Exception e) { /* Rippling table may not exist yet */ }

        Integer ci = 0;
        for (Crew__c c : crews) {
            SchedulingConsoleController.CrewUtilizationDto r = new SchedulingConsoleController.CrewUtilizationDto();
            r.crewId       = c.Id;
            r.crewName     = c.Name;
            r.foremanName  = c.Foreman__r != null ? c.Foreman__r.Name : '—';
            r.dotColor     = CREW_COLORS[Math.mod(ci, CREW_COLORS.size())]; ci++;
            r.goalHoursWeek = c.Weekly_Capacity_Hours__c != null ? c.Weekly_Capacity_Hours__c : 40;
            r.scheduledHoursWeek = schedHrs.containsKey(c.Name) ? schedHrs.get(c.Name) : 0;
            r.actualHoursWeek = actualHrs.containsKey(c.Name) ? actualHrs.get(c.Name) : r.scheduledHoursWeek;
            r.efficiencyPct = r.goalHoursWeek > 0
                              ? (Integer)((r.actualHoursWeek / r.goalHoursWeek) * 100) : 0;
            r.effCss  = r.efficiencyPct > 100 ? 'chip chip-amber'
                      : r.efficiencyPct >= 85  ? 'chip chip-green'
                      : 'chip chip-gray';
            r.otRisk  = r.actualHoursWeek > 40;
            r.otLabel = r.otRisk ? (r.actualHoursWeek - 40).setScale(1) + ' over' : 'None';
            r.otCss   = r.otRisk ? 'chip chip-amber' : 'chip chip-green';
            rows.add(r);
        }
        return rows;
    }

    // ─── Rippling time off ───────────────────────────────────────────────────
    public static List<SchedulingConsoleController.TimeOffDto> buildTimeOff(Date startDate, Date endDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.TimeOffDto> rows = new List<SchedulingConsoleController.TimeOffDto>();
        try {
            for (Rippling_Time_Off__c rto : [
                SELECT Id, Employee__r.Name, Employee__c, Employee__r.Crew__r.Name,
                       Employee__r.Role__c, Time_Off_Type__c, Start_Date__c, End_Date__c, Status__c
                FROM Rippling_Time_Off__c
                WHERE Start_Date__c <= :endDate AND End_Date__c >= :startDate
                  AND Status__c = 'Approved'
                ORDER BY Start_Date__c ASC LIMIT 50
            ]) {
                SchedulingConsoleController.TimeOffDto r = new SchedulingConsoleController.TimeOffDto();
                r.employeeName = rto.Employee__r != null ? rto.Employee__r.Name : '—';
                r.employeeId   = rto.Employee__c;
                r.crewName     = rto.Employee__r?.Crew__r != null ? rto.Employee__r.Crew__r.Name : '—';
                r.role         = rto.Employee__r?.Role__c;
                r.timeOffType  = rto.Time_Off_Type__c;
                r.startDate    = rto.Start_Date__c;
                r.endDate      = rto.End_Date__c;
                r.status       = rto.Status__c;
                r.chipCss      = rto.Time_Off_Type__c == 'PTO' ? 'chip chip-red'
                               : rto.Time_Off_Type__c == 'Sick' ? 'chip chip-amber' : 'chip chip-gray';
                rows.add(r);
            }
        } catch (Exception e) { /* Rippling table may not exist yet */ }
        return rows;
    }

    // ─── Overtime risks ──────────────────────────────────────────────────────
    public static List<SchedulingConsoleController.OvertimeRiskDto> buildOvertimeRisks(
            Date startDate, Date endDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.OvertimeRiskDto> rows = new List<SchedulingConsoleController.OvertimeRiskDto>();
        List<SchedulingConsoleController.CrewUtilizationDto> utilRows = buildCrewUtilization(startDate, endDate, division);
        for (SchedulingConsoleController.CrewUtilizationDto u : utilRows) {
            SchedulingConsoleController.OvertimeRiskDto r = new SchedulingConsoleController.OvertimeRiskDto();
            r.resourceName    = u.foremanName;
            r.crewName        = u.crewName;
            r.scheduledHours  = u.scheduledHoursWeek;
            r.actualHours     = u.actualHoursWeek;
            r.projectedHours  = u.actualHoursWeek;
            r.otRisk          = u.otRisk;
            r.otLabel         = u.otLabel;
            r.chipCss         = u.otCss;
            r.isHighlighted   = u.otRisk;
            rows.add(r);
        }
        return rows;
    }

    // ─── Crew efficiency MTD ─────────────────────────────────────────────────
    public static List<SchedulingConsoleController.CrewEfficiencyDto> buildCrewEfficiencyMtd(Date schedDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.CrewEfficiencyDto> rows = new List<SchedulingConsoleController.CrewEfficiencyDto>();
        Date monthStart = Date.newInstance(schedDate.year(), schedDate.month(), 1);
        List<Crew__c> crews = [SELECT Id, Name FROM Crew__c WHERE Active__c = true ORDER BY Name LIMIT 20];

        Map<String, Decimal> goalSqft = new Map<String, Decimal>();
        Map<String, Decimal> actSqft  = new Map<String, Decimal>();
        Map<String, Integer> stops    = new Map<String, Integer>();
        Map<String, Decimal> qiSum    = new Map<String, Decimal>();
        Map<String, Integer> fjCnt    = new Map<String, Integer>();

        for (AggregateResult ar : [
            SELECT Crew__c crName, SUM(Sod_Sqft__c) gs, SUM(Installed_Sod_Sqft__c) as2,
                   COUNT(Id) cnt, SUM(QI_Score__c) qi
            FROM WorkOrder
            WHERE Crew__c != null AND Scheduled_Date__c >= :monthStart AND Scheduled_Date__c <= :schedDate
            GROUP BY Crew__c
        ]) {
            String crName = (String)ar.get('crName');
            goalSqft.put(crName, ar.get('gs')  != null ? (Decimal)ar.get('gs')  : 0);
            actSqft.put(crName,  ar.get('as2') != null ? (Decimal)ar.get('as2') : 0);
            stops.put(crName,    ar.get('cnt') != null ? (Integer)ar.get('cnt') : 0);
            qiSum.put(crName,    ar.get('qi')  != null ? (Decimal)ar.get('qi')  : 0);
        }
        for (AggregateResult ar : [
            SELECT Crew__c crName, COUNT(Id) cnt FROM WorkOrder
            WHERE Is_Finished_Job__c = true AND Scheduled_Date__c >= :monthStart AND Scheduled_Date__c <= :schedDate
            GROUP BY Crew__c
        ]) { fjCnt.put((String)ar.get('crName'), (Integer)ar.get('cnt')); }

        Integer ci = 0;
        for (Crew__c c : crews) {
            SchedulingConsoleController.CrewEfficiencyDto r = new SchedulingConsoleController.CrewEfficiencyDto();
            r.crewName  = c.Name;
            r.color     = CREW_COLORS[Math.mod(ci, CREW_COLORS.size())]; ci++;
            r.stops     = stops.containsKey(c.Name) ? stops.get(c.Name) : 0;
            Decimal gs  = goalSqft.containsKey(c.Name) ? goalSqft.get(c.Name) : 0;
            Decimal as2 = actSqft.containsKey(c.Name)  ? actSqft.get(c.Name)  : gs;
            r.goalHours   = (gs  * 0.12 / 60).setScale(1);
            r.actualHours = (as2 * 0.12 / 60).setScale(1);
            r.variance    = (r.actualHours - r.goalHours).setScale(1);
            r.varLabel    = (r.variance > 0 ? '+' : '') + r.variance;
            r.varCss      = r.variance > 0 ? 'chip chip-amber' : 'chip chip-green';
            Integer fj    = fjCnt.containsKey(c.Name) ? fjCnt.get(c.Name) : 0;
            r.fjPct       = r.stops > 0 ? ((fj * 100.0) / r.stops).setScale(1) : 0;
            Decimal qi    = qiSum.containsKey(c.Name) ? qiSum.get(c.Name) : 0;
            r.qiScore     = r.stops > 0 ? (qi / r.stops).setScale(1) : 0;
            rows.add(r);
        }
        return rows;
    }

    // ─── Optimizer recs ──────────────────────────────────────────────────────
    public static List<SchedulingConsoleController.RouteOptDto> buildOptimizerRecs(Date schedDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.RouteOptDto> rows = new List<SchedulingConsoleController.RouteOptDto>();
        try {
            for (Route_Optimization_Result__c r : [
                SELECT Id, Crew__r.Name, Minutes_Saved__c, Recommendation__c, Status__c
                FROM Route_Optimization_Result__c
                WHERE Schedule_Day__r.Schedule_Date__c = :schedDate
                  AND Status__c = 'Proposed'
                LIMIT 10
            ]) {
                SchedulingConsoleController.RouteOptDto d = new SchedulingConsoleController.RouteOptDto();
                d.id             = r.Id;
                d.crewName       = r.Crew__r != null ? r.Crew__r.Name : '—';
                d.minutesSaved   = r.Minutes_Saved__c;
                d.recommendation = r.Recommendation__c;
                d.status         = r.Status__c;
                d.chipCss        = 'chip chip-blue';
                rows.add(d);
            }
        } catch (Exception e) { /* graceful fallback */ }
        return rows;
    }

    // ─── Draft review ─────────────────────────────────────────────────────────
    public static SchedulingConsoleController.DraftReviewDto buildDraftReview(Date schedDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        SchedulingConsoleController.DraftReviewDto dd = new SchedulingConsoleController.DraftReviewDto();
        dd.cleared  = new List<SchedulingConsoleController.DraftCrewDto>();
        dd.blocked  = new List<SchedulingConsoleController.DraftCrewDto>();
        dd.draftTime = '3:00 PM';

        List<Schedule_Day__c> days = [SELECT Id FROM Schedule_Day__c WHERE Schedule_Date__c = :schedDate LIMIT 1];
        if (!days.isEmpty()) dd.scheduleDayId = days[0].Id;

        Date weekStart = schedDate.toStartOfWeek().addDays(1);
        Date weekEnd   = weekStart.addDays(4);

        Set<String> otRiskCrews = new Set<String>();
        for (AggregateResult ar : [
            SELECT Crew__c cn, SUM(Sod_Sqft__c) sqft
            FROM WorkOrder
            WHERE Schedule_Locked__c = true AND Scheduled_Date__c >= :weekStart AND Scheduled_Date__c <= :weekEnd
              AND Crew__c != null GROUP BY Crew__c
        ]) {
            Decimal sqft = ar.get('sqft') != null ? (Decimal)ar.get('sqft') : 0;
            if ((sqft * 0.12 / 60) > 40) otRiskCrews.add((String)ar.get('cn'));
        }

        Set<String> wxCrews = new Set<String>();
        if (WX_HOLD_EXISTS) {
            for (SObject wo : Database.query(
                'SELECT Crew__c FROM WorkOrder WHERE Severe_Weather_Hold__c = true'
                + ' AND Scheduled_Date__c = :schedDate AND Crew__c != null'
            )) {
                String crewVal = (String)wo.get('Crew__c');
                if (String.isNotBlank(crewVal)) wxCrews.add(crewVal);
            }
        }

        Map<String, List<WorkOrder>> crewMap = new Map<String, List<WorkOrder>>();
        List<WorkOrder> draftWos = mockWorkOrders != null ? mockWorkOrders : [
            SELECT Crew__c, Crew__r.Name, Sod_Sqft__c, Route_Distance_Miles__c, Field_Manager__r.Name
            FROM WorkOrder WHERE Schedule_Locked__c = true AND Scheduled_Date__c = :schedDate AND Crew__c != null
            LIMIT 200
        ];
        for (WorkOrder wo : draftWos) {
            String crewKey = wo.Crew__c != null ? (String)wo.Crew__c : 'Unassigned';
            if (!crewMap.containsKey(crewKey)) crewMap.put(crewKey, new List<WorkOrder>());
            crewMap.get(crewKey).add(wo);
        }

        for (String cName : crewMap.keySet()) {
            List<WorkOrder> cWos = crewMap.get(cName);
            SchedulingConsoleController.DraftCrewDto r = new SchedulingConsoleController.DraftCrewDto();
            r.crewName    = cWos[0].Crew__r != null ? cWos[0].Crew__r.Name : cName;
            r.foremanName = cWos[0].Field_Manager__r != null ? cWos[0].Field_Manager__r.Name : '—';
            r.stops       = cWos.size();
            Decimal totSqft = 0; Decimal totMi = 0;
            for (WorkOrder w : cWos) {
                if (w.Sod_Sqft__c != null) totSqft += w.Sod_Sqft__c;
                if (w.Route_Distance_Miles__c != null) totMi += w.Route_Distance_Miles__c;
            }
            r.goalHours  = (totSqft * 0.12 / 60).setScale(1);
            r.routeMiles = totMi.setScale(1);
            Boolean otBlock = otRiskCrews.contains(cName);
            Boolean wxBlock = wxCrews.contains(cName);
            r.otStatus  = otBlock ? 'OT risk' : 'None';
            r.otCss     = otBlock ? 'chip chip-amber' : 'chip chip-green';
            r.weatherStatus = wxBlock ? 'Hold' : 'Clear';
            r.weatherCss    = wxBlock ? 'chip chip-red' : 'chip chip-green';
            r.cleared     = !otBlock && !wxBlock;
            r.blockReason = otBlock ? 'OT risk — resolve in Overtime tab'
                          : wxBlock  ? 'Severe weather hold active' : '';
            r.chipCss  = r.cleared ? 'chip chip-green' : 'chip chip-amber';
            if (r.cleared) dd.cleared.add(r); else dd.blocked.add(r);
        }
        dd.hasBlocked   = !dd.blocked.isEmpty();
        dd.clearedCount = dd.cleared.size();
        dd.blockedCount = dd.blocked.size();
        return dd;
    }

    // ─── Decision rules ──────────────────────────────────────────────────────
    public static List<SchedulingConsoleController.DecisionRuleDto> buildDecisionRules() {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.DecisionRuleDto> rules = new List<SchedulingConsoleController.DecisionRuleDto>();
        Object[][] data = new Object[][]{
            new Object[]{'Traffic +≤15 min','Update Travel_Minutes. RTN recalc.','No','No','','chip chip-green'},
            new Object[]{'Traffic — RTN past 5:30 PM','Alert scheduling. Needs Review.','Yes','After','warn-row','chip chip-red'},
            new Object[]{'Road closure','SF Maps alternate route.','Yes','After','warn-row','chip chip-red'},
            new Object[]{'Weather Watch','Dashboard flag. Proceeds.','No','Yes — note','','chip chip-green'},
            new Object[]{'Weather Warning','Stops → Needs Review.','Yes','If hold','warn-row','chip chip-red'},
            new Object[]{'Severe weather / tornado','Auto-hold all territory stops.','COO only','Do not depart','alert-row','chip chip-red'},
            new Object[]{'Schedule Issue alert','Flag stops. Auto-draft email.','Yes','After','warn-row','chip chip-amber'},
            new Object[]{'Standing water on lot','WO → Site Not Ready.','Yes','FM on site','warn-row','chip chip-amber'},
            new Object[]{'OT risk at 3PM draft','Block from auto-release.','Yes','After','warn-row','chip chip-amber'},
            new Object[]{'60-mile cap exceeded','Block auto-publish.','Yes','After','warn-row','chip chip-amber'},
            new Object[]{'Stop drag/drop (SF Maps)','SF Maps recalc segments.','No','Yes','','chip chip-green'},
            new Object[]{'Re-optimize one-click','SF Maps best sequence.','Yes','After','','chip chip-blue'},
            new Object[]{'Rippling PTO sync','Mark unavailable. Reassign.','Yes','No','ok-row','chip chip-blue'},
            new Object[]{'Inventory backorder','WO → Pending.','Yes','No','ok-row','chip chip-blue'},
            new Object[]{'Site not ready — builder','WO in backlog. Alert CSM.','Yes','No','','chip chip-amber'}
        };
        for (Object[] d : data) {
            SchedulingConsoleController.DecisionRuleDto r = new SchedulingConsoleController.DecisionRuleDto();
            r.condition       = (String)d[0];
            r.systemAction    = (String)d[1];
            r.requiresHuman   = (String)d[2];
            r.foremanNotified = (String)d[3];
            r.rowCss          = (String)d[4];
            r.humanCss        = (String)d[5];
            rules.add(r);
        }
        return rules;
    }

    // ─── Actions ─────────────────────────────────────────────────────────────
    public static void approveProposal(Id woId) {
        update new WorkOrder(Id = woId, Schedule_Proposal_Status__c = 'Manager Approved');
    }

    public static void approveAllProposals(List<Id> woIds) {
        List<WorkOrder> updates = new List<WorkOrder>();
        for (Id id : woIds) updates.add(new WorkOrder(Id=id, Schedule_Proposal_Status__c='Manager Approved'));
        update updates;
    }

    public static void rejectProposal(Id woId, String reason) {
        update new WorkOrder(
            Id = woId,
            Schedule_Proposal_Status__c = null,
            Proposed_Schedule_Date__c   = null,
            Proposed_Crew__c            = null,
            Route_Stop_Number__c        = null
        );
        if (String.isNotBlank(reason)) {
            insert new Task(WhatId=woId, OwnerId=UserInfo.getUserId(),
                Subject='Schedule Proposal Rejected — '+reason, Status='Completed',
                Priority='Normal', ActivityDate=Date.today(), Type='Schedule Review',
                Description='Reason: ' + reason);
        }
    }

    public static void releaseSchedule(Date schedDate, String division) {
        List<Schedule_Day__c> days = [SELECT Id FROM Schedule_Day__c
            WHERE Schedule_Date__c = :schedDate LIMIT 1];
        if (!days.isEmpty()) {
            update new Schedule_Day__c(
                Id = days[0].Id,
                Status__c = 'Released',
                Release_DateTime__c = DateTime.now(),
                Released_By__c = UserInfo.getUserId()
            );
        }
        try {
            insert new Schedule_Issue__c(
                Issue_Type__c = 'Other',
                Severity__c   = 'Low',
                Status__c     = 'Resolved',
                Summary__c    = 'Schedule released for ' + schedDate.format() + ' by ' + UserInfo.getName(),
                Resolution_Notes__c = 'Released at ' + DateTime.now().format()
            );
        } catch (Exception e) { /* graceful if table not yet deployed */ }

        // Push locked WOs into FSL as ServiceAppointments (non-blocking)
        try { syncFslAppointments(schedDate); } catch (Exception e) { /* FSL not blocking release */ }
    }

    // Creates FSL ServiceAppointment + AssignedResource for every locked WorkOrder
    // on schedDate that has a Crew with a ServiceResource but no SA yet.
    @TestVisible
    static void syncFslAppointments(Date schedDate) {
        List<WorkOrder> wos = [SELECT Id, WorkOrderNumber, Subject, Street, City, State,
            PostalCode, Latitude, Longitude, Crew__r.ServiceResource__c FROM WorkOrder
            WHERE Schedule_Locked__c = true AND Scheduled_Date__c = :schedDate
            AND Crew__c != null AND Crew__r.ServiceResource__c != null LIMIT 200];
        if (wos.isEmpty()) return;
        Set<Id> woIds = (new Map<Id, WorkOrder>(wos)).keySet();
        Set<Id> done = new Set<Id>();
        for (AggregateResult r : [SELECT ParentRecordId i FROM ServiceAppointment WHERE ParentRecordId IN :woIds GROUP BY ParentRecordId]) done.add((Id)r.get('i'));
        List<WorkOrder> tp = new List<WorkOrder>();
        for (WorkOrder w : wos) if (!done.contains(w.Id)) tp.add(w);
        if (tp.isEmpty()) return;
        Datetime ds = Datetime.newInstance(schedDate, Time.newInstance(7,0,0,0));
        Datetime de = Datetime.newInstance(schedDate, Time.newInstance(16,0,0,0));
        List<ServiceAppointment> sas = new List<ServiceAppointment>();
        for (WorkOrder w : tp) sas.add(new ServiceAppointment(ParentRecordId=w.Id,
            Subject=String.isNotBlank(w.Subject)?w.Subject:w.WorkOrderNumber,
            SchedStartTime=ds, SchedEndTime=de, Duration=540, DurationType='Minutes',
            Street=w.Street, City=w.City, State=w.State, PostalCode=w.PostalCode,
            Latitude=w.Latitude, Longitude=w.Longitude));
        Database.SaveResult[] res = Database.insert(sas, false);
        List<AssignedResource> ars = new List<AssignedResource>();
        for (Integer i = 0; i < res.size(); i++) if (res[i].isSuccess())
            ars.add(new AssignedResource(ServiceAppointmentId=sas[i].Id, ServiceResourceId=tp[i].Crew__r.ServiceResource__c));
        if (!ars.isEmpty()) Database.insert(ars, false);
    }

    public static void holdSchedule(Date schedDate, String division, String reason) {
        List<Schedule_Day__c> days = [SELECT Id FROM Schedule_Day__c
            WHERE Schedule_Date__c = :schedDate LIMIT 1];
        if (!days.isEmpty()) {
            update new Schedule_Day__c(Id = days[0].Id, Status__c = 'Draft', Notes__c = reason);
        }
    }

    public static void reassignStop(Id stopId, Id newCrewId, Id newFmId) {
        update new Schedule_Stop__c(
            Id              = stopId,
            Crew__c         = newCrewId,
            Field_Manager__c = newFmId,
            Route_Status__c = 'Reassigned'
        );
    }

    public static void approveOvertimeOverride(Id crewId, Date schedDate, String reason) {
        try {
            insert new Schedule_Issue__c(
                Issue_Type__c = 'Overtime',
                Severity__c   = 'High',
                Status__c     = 'Resolved',
                Crew__c       = crewId,
                Summary__c    = 'OT override approved for ' + schedDate.format(),
                Resolution_Notes__c = reason
            );
        } catch (Exception e) { /* graceful */ }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────
    private static Integer countWorkDays(Date startDate, Date endDate) {
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

    // ═══════════════════════════════════════════════════════════════════════════
    // 10-TAB REBUILD — service methods for new Scheduling Console architecture
    // ═══════════════════════════════════════════════════════════════════════════

    public static SchedulingConsoleController.TodayScheduleDto buildTodaySchedule(Date scheduleDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        SchedulingConsoleController.TodayScheduleDto dto = new SchedulingConsoleController.TodayScheduleDto();
        dto.stops = new List<SchedulingConsoleController.TodayStopDto>();

        Datetime dayStart = Datetime.newInstanceGmt(scheduleDate, Time.newInstance(0,0,0,0));
        Datetime dayEnd   = Datetime.newInstanceGmt(scheduleDate, Time.newInstance(23,59,59,999));

        List<ServiceAppointment> sas = [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, Duration,
                   ServiceTerritoryId, ServiceTerritory.Name,
                   FSL__Pinned__c, Subject, ParentRecordId
            FROM ServiceAppointment
            WHERE SchedStartTime >= :dayStart
              AND SchedStartTime <= :dayEnd
            ORDER BY SchedStartTime ASC
            LIMIT 500
        ];

        Set<Id> woIds = new Set<Id>();
        for (ServiceAppointment sa : sas) {
            if (sa.ParentRecordId != null) woIds.add(sa.ParentRecordId);
        }
        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>();
        if (!woIds.isEmpty()) {
            for (WorkOrder wo : [
                SELECT Id, WorkOrderNumber, Status, Work_Order_Type__c, Pipeline_Bucket__c,
                       Community__r.Name, Lot__r.Name, Field_Manager__r.Name, Crew__r.Name
                FROM WorkOrder
                WHERE Id IN :woIds
            ]) { woMap.put(wo.Id, wo); }
        }

        Integer completed = 0;
        for (ServiceAppointment sa : sas) {
            SchedulingConsoleController.TodayStopDto stop = new SchedulingConsoleController.TodayStopDto();
            stop.stopId        = sa.Id;
            stop.scheduledTime = sa.SchedStartTime != null ? sa.SchedStartTime.format('h:mm a') : '—';
            stop.goalHours     = sa.Duration != null ? (sa.Duration / 60.0).setScale(1) : null;
            stop.statusLabel   = sa.Status;
            WorkOrder wo = woMap.get(sa.ParentRecordId);
            if (wo != null) {
                stop.workOrderName = wo.WorkOrderNumber;
                stop.communityName = wo.Community__r != null ? wo.Community__r.Name : '—';
                stop.lotName       = wo.Lot__r != null ? wo.Lot__r.Name : '—';
                stop.fmName        = wo.Field_Manager__r != null ? wo.Field_Manager__r.Name : '—';
                stop.crewName      = wo.Crew__r != null ? wo.Crew__r.Name : '—';
            }
            dto.stops.add(stop);
            if ('Completed'.equalsIgnoreCase(sa.Status) || 'Closed'.equalsIgnoreCase(sa.Status)) completed++;
        }

        dto.stopsTotal     = sas.size();
        dto.stopsCompleted = completed;
        dto.stopsRemaining = sas.size() - completed;
        dto.crewsOut       = [SELECT COUNT() FROM ServiceResource WHERE IsActive = true];
        dto.issueCount     = [SELECT COUNT() FROM Schedule_Issue__c WHERE Status__c = 'Open' AND CreatedDate >= :dayStart];
        dto.readyCount     = [SELECT COUNT() FROM WorkOrder WHERE Pipeline_Bucket__c = 'Ready_to_Schedule'];
        return dto;
    }

    public static List<SchedulingConsoleController.UnscheduledWorkDto> buildUnscheduledWork(String division, String woType) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.UnscheduledWorkDto> result = new List<SchedulingConsoleController.UnscheduledWorkDto>();
        String soql = 'SELECT Id, WorkOrderNumber, Status, Work_Order_Type__c, Pipeline_Bucket__c, '
                    + 'Community__r.Name, Lot__r.Name, Field_Manager__r.Name, '
                    + 'Priority, CreatedDate '
                    + 'FROM WorkOrder '
                    + 'WHERE Pipeline_Bucket__c = \'Ready_to_Schedule\' ';
        if (String.isNotBlank(woType) && woType != 'All') {
            soql += 'AND Work_Order_Type__c = \'' + String.escapeSingleQuotes(woType) + '\' ';
        }
        soql += 'ORDER BY CreatedDate ASC LIMIT 500';
        List<WorkOrder> unschedWos = mockWorkOrders != null ? mockWorkOrders : (List<WorkOrder>)Database.query(soql);
        for (WorkOrder wo : unschedWos) {
            SchedulingConsoleController.UnscheduledWorkDto d = new SchedulingConsoleController.UnscheduledWorkDto();
            d.woId           = wo.Id;
            d.woName         = wo.WorkOrderNumber;
            d.woType         = wo.Work_Order_Type__c;
            d.communityName  = wo.Community__r != null ? wo.Community__r.Name : '—';
            d.lotName        = wo.Lot__r != null ? wo.Lot__r.Name : '—';
            d.fmName         = wo.Field_Manager__r != null ? wo.Field_Manager__r.Name : '—';
            d.daysWaiting    = wo.CreatedDate != null ? wo.CreatedDate.date().daysBetween(Date.today()) : 0;
            d.readinessReady = false;
            d.readinessLabel = 'Pending';
            d.status         = wo.Status;
            result.add(d);
        }
        return result;
    }

    public static List<SchedulingConsoleController.ScheduledWorkDto> buildScheduledWork(Date scheduleDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.ScheduledWorkDto> result = new List<SchedulingConsoleController.ScheduledWorkDto>();
        Datetime weekStart = Datetime.newInstanceGmt(scheduleDate.toStartOfWeek().addDays(1), Time.newInstance(0,0,0,0));
        Datetime weekEnd   = Datetime.newInstanceGmt(scheduleDate.toStartOfWeek().addDays(5), Time.newInstance(23,59,59,999));
        List<ServiceAppointment> schedSAs = mockServiceAppointments != null ? mockServiceAppointments : [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, Duration,
                   ServiceTerritoryId, ServiceTerritory.Name, FSL__Pinned__c, Subject
            FROM ServiceAppointment
            WHERE SchedStartTime >= :weekStart AND SchedStartTime <= :weekEnd
            ORDER BY SchedStartTime ASC
            LIMIT 500
        ];
        for (ServiceAppointment sa : schedSAs) {
            SchedulingConsoleController.ScheduledWorkDto d = new SchedulingConsoleController.ScheduledWorkDto();
            d.saId                  = sa.Id;
            d.saNumber              = sa.AppointmentNumber;
            d.workOrderName         = sa.Subject;
            d.territory             = sa.ServiceTerritory != null ? sa.ServiceTerritory.Name : '—';
            d.scheduledDateDisplay  = sa.SchedStartTime != null ? sa.SchedStartTime.format('M/d/yyyy') : '—';
            d.durationHrs           = sa.Duration != null ? (sa.Duration / 60.0).setScale(1) : null;
            d.status                = sa.Status;
            result.add(d);
        }
        return result;
    }

    public static List<SchedulingConsoleController.BlockedWorkDto> buildBlockedWork(String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.BlockedWorkDto> result = new List<SchedulingConsoleController.BlockedWorkDto>();
        for (Schedule_Issue__c si : [
            SELECT Id, Standard_WorkOrder__c, Standard_WorkOrder__r.WorkOrderNumber,
                   Standard_WorkOrder__r.Work_Order_Type__c, Standard_WorkOrder__r.Community__r.Name,
                   Standard_WorkOrder__r.Lot__r.Name, Standard_WorkOrder__r.Field_Manager__r.Name,
                   Summary__c, Severity__c, CreatedDate
            FROM Schedule_Issue__c
            WHERE Status__c = 'Open'
            ORDER BY CreatedDate DESC
            LIMIT 500
        ]) {
            SchedulingConsoleController.BlockedWorkDto d = new SchedulingConsoleController.BlockedWorkDto();
            d.woId         = si.Standard_WorkOrder__c;
            d.woName       = si.Standard_WorkOrder__r != null ? si.Standard_WorkOrder__r.WorkOrderNumber : '—';
            d.woType       = si.Standard_WorkOrder__r != null ? si.Standard_WorkOrder__r.Work_Order_Type__c : '—';
            d.communityName= si.Standard_WorkOrder__r != null && si.Standard_WorkOrder__r.Community__r != null ? si.Standard_WorkOrder__r.Community__r.Name : '—';
            d.lotName      = si.Standard_WorkOrder__r != null && si.Standard_WorkOrder__r.Lot__r != null ? si.Standard_WorkOrder__r.Lot__r.Name : '—';
            d.fmName       = si.Standard_WorkOrder__r != null && si.Standard_WorkOrder__r.Field_Manager__r != null ? si.Standard_WorkOrder__r.Field_Manager__r.Name : '—';
            d.blockReason  = si.Summary__c;
            d.blockedSince = si.CreatedDate != null ? si.CreatedDate.format('M/d/yyyy') : '—';
            d.severity     = si.Severity__c;
            result.add(d);
        }
        return result;
    }

    public static List<SchedulingConsoleController.FieldManagerDto> buildFieldManagerSummary(Date scheduleDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.FieldManagerDto> result = new List<SchedulingConsoleController.FieldManagerDto>();
        for (Employee__c emp : [
            SELECT Id, Name
            FROM Employee__c
            WHERE Role__c = 'Field Manager' AND Active__c = true
            ORDER BY Name ASC
            LIMIT 50
        ]) {
            SchedulingConsoleController.FieldManagerDto d = new SchedulingConsoleController.FieldManagerDto();
            d.fmId         = emp.Id;
            d.fmName       = emp.Name;
            d.hasIssue     = false;
            d.openWOs      = 0;
            d.scheduledWOs = 0;
            d.blockedWOs   = 0;
            d.crewsAssigned= 0;
            d.crewsToday   = 0;
            d.stopsToday   = 0;
            result.add(d);
        }
        return result;
    }

    public static List<SchedulingConsoleController.TerritoryDto> buildServiceTerritorySummary(Date scheduleDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.TerritoryDto> result = new List<SchedulingConsoleController.TerritoryDto>();
        for (ServiceTerritory st : [
            SELECT Id, Name, OperatingHoursId
            FROM ServiceTerritory
            WHERE IsActive = true
            ORDER BY Name ASC
            LIMIT 100
        ]) {
            SchedulingConsoleController.TerritoryDto d = new SchedulingConsoleController.TerritoryDto();
            d.territoryId    = st.Id;
            d.territoryName  = st.Name;
            d.weeklyCapacity = 40;
            d.scheduledSACount = 0;
            d.openWOCount    = 0;
            d.blockedWOCount = 0;
            d.utilizationPct = 0;
            d.isOverCapacity = false;
            result.add(d);
        }
        return result;
    }

    public static List<SchedulingConsoleController.WorkOrderSummaryDto> buildWorkOrderSummary(String division, String woType) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.WorkOrderSummaryDto> result = new List<SchedulingConsoleController.WorkOrderSummaryDto>();
        String soql = 'SELECT Id, WorkOrderNumber, Status, Work_Order_Type__c, Pipeline_Bucket__c, '
                    + 'Priority, CreatedDate, Community__r.Name, Lot__r.Name, Field_Manager__r.Name '
                    + 'FROM WorkOrder ';
        if (String.isNotBlank(woType) && woType != 'All') {
            soql += 'WHERE Work_Order_Type__c = \'' + String.escapeSingleQuotes(woType) + '\' ';
        }
        soql += 'ORDER BY CreatedDate DESC LIMIT 500';
        List<WorkOrder> woSumList = mockWorkOrders != null ? mockWorkOrders : (List<WorkOrder>)Database.query(soql);
        for (WorkOrder wo : woSumList) {
            SchedulingConsoleController.WorkOrderSummaryDto d = new SchedulingConsoleController.WorkOrderSummaryDto();
            d.woId          = wo.Id;
            d.woName        = wo.WorkOrderNumber;
            d.woType        = wo.Work_Order_Type__c;
            d.communityName = wo.Community__r != null ? wo.Community__r.Name : '—';
            d.lotName       = wo.Lot__r != null ? wo.Lot__r.Name : '—';
            d.fmName        = wo.Field_Manager__r != null ? wo.Field_Manager__r.Name : '—';
            d.status        = wo.Status;
            d.priority      = wo.Priority;
            d.daysOpen      = wo.CreatedDate != null ? wo.CreatedDate.date().daysBetween(Date.today()) : 0;
            result.add(d);
        }
        return result;
    }

    public static List<SchedulingConsoleController.ServiceAppointmentSummaryDto> buildServiceAppointmentSummary(Date scheduleDate, String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.ServiceAppointmentSummaryDto> result = new List<SchedulingConsoleController.ServiceAppointmentSummaryDto>();
        for (ServiceAppointment sa : [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, Duration,
                   ServiceTerritoryId, ServiceTerritory.Name, FSL__Pinned__c, Subject
            FROM ServiceAppointment
            ORDER BY SchedStartTime DESC NULLS LAST
            LIMIT 500
        ]) {
            SchedulingConsoleController.ServiceAppointmentSummaryDto d = new SchedulingConsoleController.ServiceAppointmentSummaryDto();
            d.saId                = sa.Id;
            d.saNumber            = sa.AppointmentNumber;
            d.workOrderName       = sa.Subject;
            d.territory           = sa.ServiceTerritory != null ? sa.ServiceTerritory.Name : '—';
            d.scheduledDateDisplay= sa.SchedStartTime != null ? sa.SchedStartTime.format('M/d/yyyy') : '—';
            d.durationHrs         = sa.Duration != null ? (sa.Duration / 60.0).setScale(1) : null;
            d.isPinned            = sa.FSL__Pinned__c;
            d.status              = sa.Status;
            result.add(d);
        }
        return result;
    }

    public static List<SchedulingConsoleController.ScheduleRequestDto> buildScheduleRequests(String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.ScheduleRequestDto> result = new List<SchedulingConsoleController.ScheduleRequestDto>();
        List<Schedule_Issue__c> schedReqs = mockScheduleIssues != null ? mockScheduleIssues : [
            SELECT Id, Standard_WorkOrder__c, Standard_WorkOrder__r.WorkOrderNumber,
                   Standard_WorkOrder__r.Work_Order_Type__c, Standard_WorkOrder__r.Community__r.Name,
                   Standard_WorkOrder__r.Lot__r.Name, Standard_WorkOrder__r.Field_Manager__r.Name,
                   Summary__c, Status__c, CreatedDate
            FROM Schedule_Issue__c
            WHERE Status__c = 'Pending_Approval'
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
        for (Schedule_Issue__c si : schedReqs) {
            SchedulingConsoleController.ScheduleRequestDto d = new SchedulingConsoleController.ScheduleRequestDto();
            d.requestId           = si.Id;
            d.workOrderName       = si.Standard_WorkOrder__r != null ? si.Standard_WorkOrder__r.WorkOrderNumber : '—';
            d.woType              = si.Standard_WorkOrder__r != null ? si.Standard_WorkOrder__r.Work_Order_Type__c : '—';
            d.communityName       = si.Standard_WorkOrder__r != null && si.Standard_WorkOrder__r.Community__r != null ? si.Standard_WorkOrder__r.Community__r.Name : '—';
            d.lotName             = si.Standard_WorkOrder__r != null && si.Standard_WorkOrder__r.Lot__r != null ? si.Standard_WorkOrder__r.Lot__r.Name : '—';
            d.fmName              = si.Standard_WorkOrder__r != null && si.Standard_WorkOrder__r.Field_Manager__r != null ? si.Standard_WorkOrder__r.Field_Manager__r.Name : '—';
            d.requestedDateDisplay= si.CreatedDate != null ? si.CreatedDate.format('M/d/yyyy') : '—';
            d.notes               = si.Summary__c;
            d.status              = si.Status__c;
            result.add(d);
        }
        return result;
    }

    public static List<SchedulingConsoleController.DataIssueDto> buildDataIssues(String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');
        List<SchedulingConsoleController.DataIssueDto> result = new List<SchedulingConsoleController.DataIssueDto>();
        List<WorkOrder> issueWos = mockWorkOrders != null ? mockWorkOrders : [
            SELECT Id, WorkOrderNumber, Work_Order_Type__c, Community__c, Lot__c,
                   Field_Manager__c, ServiceTerritoryId, WorkTypeId, Priority
            FROM WorkOrder
            WHERE Pipeline_Bucket__c = 'Ready_to_Schedule'
              AND (Community__c = null OR Lot__c = null OR Field_Manager__c = null
                   OR ServiceTerritoryId = null OR WorkTypeId = null)
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
        for (WorkOrder wo : issueWos) {
            if (wo.Community__c == null)        result.add(issueRow(wo.Id, wo.WorkOrderNumber, 'WorkOrder', 'Community__c',        'Missing Field', 'Community is required before scheduling', 'High',   'Set Community__c on the Work Order'));
            if (wo.Lot__c == null)              result.add(issueRow(wo.Id, wo.WorkOrderNumber, 'WorkOrder', 'Lot__c',              'Missing Field', 'Lot is required before scheduling',       'High',   'Set Lot__c on the Work Order'));
            if (wo.Field_Manager__c == null)    result.add(issueRow(wo.Id, wo.WorkOrderNumber, 'WorkOrder', 'Field_Manager__c',    'Missing Field', 'FM assignment required',                  'Medium', 'Assign Field Manager on the Work Order'));
            if (wo.ServiceTerritoryId == null)  result.add(issueRow(wo.Id, wo.WorkOrderNumber, 'WorkOrder', 'ServiceTerritoryId',  'Missing Field', 'Service Territory required for FSL',      'High',   'Set Service Territory on the Work Order'));
            if (wo.WorkTypeId == null)          result.add(issueRow(wo.Id, wo.WorkOrderNumber, 'WorkOrder', 'WorkTypeId',          'Missing Field', 'Work Type required for FSL scheduling',   'Medium', 'Set Work Type on the Work Order'));
        }
        return result;
    }

    private static SchedulingConsoleController.DataIssueDto issueRow(Id recId, String name, String objType, String field, String issueType, String description, String severity, String fix) {
        SchedulingConsoleController.DataIssueDto d = new SchedulingConsoleController.DataIssueDto();
        d.issueId      = recId;
        d.recordName   = name;
        d.objectType   = objType;
        d.fieldName    = field;
        d.issueType    = issueType;
        d.description  = description;
        d.severity     = severity;
        d.suggestedFix = fix;
        return d;
    }

    // ─── Pipeline Summary ─────────────────────────────────────────────────────
    public static List<SchedulingConsoleController.PipelineSummaryDto> buildPipelineSummary(String division) {
        if (throwForCoverageTest) throw new IllegalArgumentException('coverage');

        List<Account> lots = [
            SELECT Id, Name, FM__r.Name, Target_Start_Date__c,
                   Pipeline_Bucket__c, Takeoff_Complete__c, WO_Created__c
            FROM Account
            WHERE RecordType.DeveloperName = 'Lot'
            AND Lot_Status__c = 'Active'
            AND (Pipeline_Bucket__c = null
                 OR Pipeline_Bucket__c NOT IN ('Complete', 'Cancelled', 'Closed'))
            ORDER BY Target_Start_Date__c ASC NULLS LAST
            LIMIT 500
        ];

        Map<String, List<SchedulingConsoleController.PipelineLotDto>> bucketMap =
            new Map<String, List<SchedulingConsoleController.PipelineLotDto>>();
        Date today = Date.today();

        for (Account lot : lots) {
            String bucket = String.isNotBlank(lot.Pipeline_Bucket__c) ? lot.Pipeline_Bucket__c : 'Ready to Schedule';
            if (!bucketMap.containsKey(bucket)) {
                bucketMap.put(bucket, new List<SchedulingConsoleController.PipelineLotDto>());
            }
            SchedulingConsoleController.PipelineLotDto d = new SchedulingConsoleController.PipelineLotDto();
            d.lotId       = lot.Id;
            d.name        = lot.Name;
            d.fmName      = lot.FM__r != null ? lot.FM__r.Name : '—';
            d.takeoffDone = lot.Takeoff_Complete__c == true;
            d.woCreated   = lot.WO_Created__c == true;
            if (lot.Target_Start_Date__c != null) {
                d.daysUntil         = today.daysBetween(lot.Target_Start_Date__c);
                d.targetDateDisplay = lot.Target_Start_Date__c.format();
            } else {
                d.daysUntil         = null;
                d.targetDateDisplay = 'No date';
            }
            bucketMap.get(bucket).add(d);
        }

        List<String> stages = new List<String>{
            '90+ Days', '60+ Days', '30 Days', 'Ready to Schedule',
            'Takeoff In Progress', 'Takeoff Complete',
            'Scheduled', 'In Progress', 'On Hold'
        };
        Map<String, String> chipMap = new Map<String, String>{
            '90+ Days'            => 'chip gray',
            '60+ Days'            => 'chip blue',
            '30 Days'             => 'chip amber',
            'Ready to Schedule'   => 'chip green',
            'Takeoff In Progress' => 'chip purple',
            'Takeoff Complete'    => 'chip purple',
            'Scheduled'           => 'chip blue',
            'In Progress'         => 'chip green',
            'On Hold'             => 'chip amber'
        };

        List<SchedulingConsoleController.PipelineSummaryDto> result =
            new List<SchedulingConsoleController.PipelineSummaryDto>();
        Set<String> stageSet = new Set<String>(stages);

        for (String stage : stages) {
            List<SchedulingConsoleController.PipelineLotDto> stageLots =
                bucketMap.containsKey(stage) ? bucketMap.get(stage)
                : new List<SchedulingConsoleController.PipelineLotDto>();
            SchedulingConsoleController.PipelineSummaryDto s = new SchedulingConsoleController.PipelineSummaryDto();
            s.bucket  = stage;
            s.count   = stageLots.size();
            s.chipCss = chipMap.get(stage);
            s.lots    = stageLots;
            result.add(s);
        }

        for (String bucket : bucketMap.keySet()) {
            if (!stageSet.contains(bucket)) {
                SchedulingConsoleController.PipelineSummaryDto s = new SchedulingConsoleController.PipelineSummaryDto();
                s.bucket  = bucket;
                s.count   = bucketMap.get(bucket).size();
                s.chipCss = 'chip gray';
                s.lots    = bucketMap.get(bucket);
                result.add(s);
            }
        }

        return result;
    }
}