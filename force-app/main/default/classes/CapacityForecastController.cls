/**
 * CapacityForecastController
 * Provides a 6-week forward-looking capacity vs. demand view grouped by
 * zone (Crew Division) for the Capacity Forecast Console (Screen 21).
 */
public with sharing class CapacityForecastController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class WeekRow {
        @AuraEnabled public String  weekLabel;      // e.g. "Wk Jun 9"
        @AuraEnabled public Date    weekStart;
        @AuraEnabled public Integer capacity;       // sum of active-crew weekly-capacity hours
        @AuraEnabled public Integer booked;         // count of WOs scheduled that week
        @AuraEnabled public Boolean overCapacity;
    }

    public class ZoneRow {
        @AuraEnabled public String  zoneName;
        @AuraEnabled public Integer crewCount;
        @AuraEnabled public Decimal capacityHours;
        @AuraEnabled public Integer bookedWOs;
        @AuraEnabled public Boolean overCapacity;
    }

    public class BacklogRow {
        @AuraEnabled public Id     woId;
        @AuraEnabled public String woNumber;
        @AuraEnabled public String communityName;
        @AuraEnabled public String workType;
        @AuraEnabled public Date   readyDate;   // StartDate falling back to Scheduled_Date__c
        @AuraEnabled public Integer ageDays;
    }

    public class ForecastView {
        @AuraEnabled public Integer         weeksOverCapacity;
        @AuraEnabled public Integer         backlogCount;
        @AuraEnabled public List<WeekRow>   weeks;
        @AuraEnabled public List<ZoneRow>   zones;
        @AuraEnabled public List<BacklogRow> backlog;
    }

    // ─── AuraEnabled entry point ─────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static ForecastView getForecast(String division) {

        // FLS: WorkOrder
        Schema.DescribeSObjectResult woDesc = Schema.SObjectType.WorkOrder;
        if (!woDesc.isAccessible()) {
            throw new AuraHandledException('Insufficient access to WorkOrder object.');
        }
        // FLS: Crew__c
        Schema.DescribeSObjectResult crewDesc = Schema.SObjectType.Crew__c;
        if (!crewDesc.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Crew__c object.');
        }

        // ── Scheduled WOs for next 6 weeks ───────────────────────────────────
        Date today     = Date.today();
        Date sixWksOut = today.addDays(42);

        List<WorkOrder> scheduledWos = [
            SELECT Id, WorkOrderNumber, Scheduled_Date__c, Division__c
            FROM   WorkOrder
            WHERE  Status IN ('Scheduled', 'In Progress')
            AND    Scheduled_Date__c >= :today
            AND    Scheduled_Date__c <= :sixWksOut
        ];

        // ── Active crews (optionally filtered by division) ───────────────────
        List<Crew__c> crews;
        if (String.isNotBlank(division)) {
            crews = [
                SELECT Id, Name, Division__c, Weekly_Capacity_Hours__c
                FROM   Crew__c
                WHERE  Active__c = true
                AND    Division__c = :division
            ];
        } else {
            crews = [
                SELECT Id, Name, Division__c, Weekly_Capacity_Hours__c
                FROM   Crew__c
                WHERE  Active__c = true
            ];
        }

        // ── Backlog: Ready to Schedule, oldest first ──────────────────────────
        List<WorkOrder> backlogWos = [
            SELECT Id, WorkOrderNumber, Community__r.Name,
                   Job_Type__c, Work_Order_Type__c,
                   StartDate, Scheduled_Date__c
            FROM   WorkOrder
            WHERE  Status = 'Ready to Schedule'
            ORDER BY StartDate ASC NULLS LAST
            LIMIT  20
        ];

        return buildForecast(scheduledWos, crews, backlogWos);
    }

    // ─── Testable builder ─────────────────────────────────────────────────────

    @TestVisible
    private static ForecastView buildForecast(
            List<WorkOrder> scheduledWos,
            List<Crew__c>   crews,
            List<WorkOrder> backlogWos) {

        ForecastView v = new ForecastView();
        Date today = Date.today();

        // ── Weekly capacity: sum of crew Weekly_Capacity_Hours__c or 8h fallback
        Integer totalCrewCapacityPerWeek = 0;
        for (Crew__c c : crews) {
            totalCrewCapacityPerWeek +=
                (c.Weekly_Capacity_Hours__c != null)
                    ? c.Weekly_Capacity_Hours__c.intValue()
                    : 8;
        }

        // ── Build week buckets ────────────────────────────────────────────────
        // Find the Monday of the current week
        Date monday = today.toStartOfWeek();
        // toStartOfWeek returns Sunday in some locales; advance to Monday if needed
        // Salesforce toStartOfWeek returns Sunday. Advance by 1 day to Monday.
        if (monday.daysBetween(today) == 6) {
            monday = monday.addDays(1);
        } else {
            // Standard: toStartOfWeek gives Sunday; add 1 to get Monday
            monday = monday.addDays(1);
        }

        // Build a map: week-start Date → WO count
        Map<Date, Integer> weekBookedMap = new Map<Date, Integer>();
        List<Date>         weekStarts    = new List<Date>();
        for (Integer w = 0; w < 6; w++) {
            Date ws = monday.addDays(w * 7);
            weekStarts.add(ws);
            weekBookedMap.put(ws, 0);
        }

        for (WorkOrder wo : scheduledWos) {
            if (wo.Scheduled_Date__c == null) continue;
            for (Date ws : weekStarts) {
                Date we = ws.addDays(6);
                if (wo.Scheduled_Date__c >= ws && wo.Scheduled_Date__c <= we) {
                    weekBookedMap.put(ws, weekBookedMap.get(ws) + 1);
                    break;
                }
            }
        }

        // ── Assemble WeekRow list ─────────────────────────────────────────────
        List<String> MONTH_ABBR = new List<String>{
            'Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec'
        };

        v.weeks = new List<WeekRow>();
        Integer overCapacityCount = 0;
        for (Date ws : weekStarts) {
            WeekRow wr   = new WeekRow();
            wr.weekStart = ws;
            wr.weekLabel = 'Wk ' + MONTH_ABBR[ws.month() - 1] + ' ' + ws.day();
            wr.capacity  = totalCrewCapacityPerWeek;
            wr.booked    = weekBookedMap.get(ws);
            wr.overCapacity = (wr.capacity > 0 && wr.booked > wr.capacity);
            if (wr.overCapacity) overCapacityCount++;
            v.weeks.add(wr);
        }
        v.weeksOverCapacity = overCapacityCount;

        // ── Zone rows: group crews by Division__c ─────────────────────────────
        // Count booked WOs per division for the 6-week window
        Map<String, Integer> divisionBookedMap = new Map<String, Integer>();
        for (WorkOrder wo : scheduledWos) {
            String div = String.isNotBlank(wo.Division__c) ? wo.Division__c : '(None)';
            Integer cur = divisionBookedMap.containsKey(div) ? divisionBookedMap.get(div) : 0;
            divisionBookedMap.put(div, cur + 1);
        }

        // Group crews by division
        Map<String, List<Crew__c>> crewsByDivision = new Map<String, List<Crew__c>>();
        for (Crew__c c : crews) {
            String div = String.isNotBlank(c.Division__c) ? c.Division__c : '(None)';
            if (!crewsByDivision.containsKey(div)) {
                crewsByDivision.put(div, new List<Crew__c>());
            }
            crewsByDivision.get(div).add(c);
        }

        v.zones = new List<ZoneRow>();
        for (String div : crewsByDivision.keySet()) {
            ZoneRow zr       = new ZoneRow();
            zr.zoneName      = div;
            zr.crewCount     = crewsByDivision.get(div).size();
            Decimal totalHrs = 0;
            for (Crew__c c : crewsByDivision.get(div)) {
                totalHrs += (c.Weekly_Capacity_Hours__c != null)
                            ? c.Weekly_Capacity_Hours__c
                            : 8;
            }
            zr.capacityHours = totalHrs;
            zr.bookedWOs     = divisionBookedMap.containsKey(div)
                                ? divisionBookedMap.get(div)
                                : 0;
            zr.overCapacity  = (zr.capacityHours > 0
                                && zr.bookedWOs > zr.capacityHours);
            v.zones.add(zr);
        }

        // ── Backlog rows ──────────────────────────────────────────────────────
        v.backlog = new List<BacklogRow>();
        for (WorkOrder wo : backlogWos) {
            BacklogRow br  = new BacklogRow();
            br.woId        = wo.Id;
            br.woNumber    = wo.WorkOrderNumber;
            br.communityName = (wo.Community__r != null) ? wo.Community__r.Name : null;
            br.workType    = String.isNotBlank(wo.Work_Order_Type__c)
                              ? wo.Work_Order_Type__c
                              : wo.Job_Type__c;
            br.readyDate   = (wo.StartDate != null)
                              ? wo.StartDate.date()
                              : wo.Scheduled_Date__c;
            br.ageDays     = (br.readyDate != null)
                              ? br.readyDate.daysBetween(today)
                              : null;
            v.backlog.add(br);
        }
        v.backlogCount = v.backlog.size();

        return v;
    }
}
