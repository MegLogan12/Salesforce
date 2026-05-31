/**
 * AquaConsoleController
 * Backend controller for the 9-tab LOVING Aqua Service Console LWC.
 * All methods are @AuraEnabled. Cacheable methods return read-only data;
 * action methods perform DML and are non-cacheable.
 *
 * Season dates: Apr 1 – Oct 31 = 213 days
 * Off-season months: January, February, March, November, December
 */
public with sharing class AquaConsoleController {

    // ─── Season constants ────────────────────────────────────────────────────
    private static final Integer SEASON_START_MONTH = 4;  // April
    private static final Integer SEASON_START_DAY   = 1;
    private static final Integer SEASON_END_MONTH   = 10; // October
    private static final Integer SEASON_END_DAY     = 31;
    private static final Integer SEASON_TOTAL_DAYS  = 213;

    private static final Set<String> OFF_SEASON_MONTHS = new Set<String>{
        'January', 'February', 'March', 'November', 'December'
    };

    // Month number → name (1-indexed)
    private static final List<String> MONTH_NAMES = new List<String>{
        'January','February','March','April','May','June',
        'July','August','September','October','November','December'
    };
    private static final List<String> MONTH_ABBR = new List<String>{
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
    };

    // Reorder thresholds — read from Aqua_Master_Inventory__c.Reorder_Threshold__c
    private static Map<String,Integer> getReorderThresholds() {
        Map<String,Integer> result = new Map<String,Integer>();
        for (Aqua_Master_Inventory__c item : [
            SELECT Item_Type__c, Reorder_Threshold__c
            FROM Aqua_Master_Inventory__c
            WHERE Reorder_Threshold__c != null
        ]) {
            if (item.Item_Type__c != null) {
                result.put(item.Item_Type__c, item.Reorder_Threshold__c.intValue());
            }
        }
        return result;
    }

    // GPS projection helpers (Charlotte metro → 680×280 SVG)
    private static Decimal mapX(Decimal lng) {
        return (lng - (-81.5)) / 1.0 * 680;
    }
    private static Decimal mapY(Decimal lat) {
        return (35.6 - lat) / 0.7 * 280;
    }

    // ─── Avatar palette ──────────────────────────────────────────────────────
    private static final List<String> AVATAR_COLORS = new List<String>{
        '#075d70','#0a8aa6','#1a93b0','#06b6d4','#0891b2'
    };

    private static final List<String> WEEKDAY_ORDER = new List<String>{
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    };

    // =========================================================================
    // DTO INNER CLASSES
    // =========================================================================

    public class HomeDTO {
        @AuraEnabled public String todayLabel;
        @AuraEnabled public String seasonDay;
        @AuraEnabled public String seasonSub;
        @AuraEnabled public String fmName;
        @AuraEnabled public String teamSub;
        @AuraEnabled public List<TeamMemberDTO> teamMembers;
        @AuraEnabled public Integer kpiInstallsToday;
        @AuraEnabled public Integer kpiChecksToday;
        @AuraEnabled public Integer kpiSameDay;
        @AuraEnabled public Integer kpiOnSiteLots;
        @AuraEnabled public Integer kpiAwaitingCloseout;
        @AuraEnabled public String kpiRunTimePct;
        @AuraEnabled public List<TodayInstallRow> installsToday;
        @AuraEnabled public List<SameDayRow> sameDayRepairs;
        @AuraEnabled public List<TechStatusRow> techStatus;
        @AuraEnabled public List<AlertRow> inventoryAlerts;
        @AuraEnabled public List<AlertRow> tamperFlags;
        @AuraEnabled public List<ActivityRow> activity;
        @AuraEnabled public String wateringCurrentMonthLabel;
        @AuraEnabled public String wateringCurrentMonthPct;
        @AuraEnabled public Integer wateringAffectedLots;
        @AuraEnabled public String wateringAdjustedBy;
        @AuraEnabled public String wateringAdjustedDate;
        @AuraEnabled public String divisionTerritory;
    }

    public class TeamMemberDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String initials;
        @AuraEnabled public String name;
        @AuraEnabled public Boolean isLead;
        @AuraEnabled public String avatarBg;
        @AuraEnabled public String avatarStyle;
    }

    public class TodayInstallRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String woName;           // ticket name (Home tab)
        @AuraEnabled public String aquaWoName;       // ticket name (Installs tab)
        @AuraEnabled public String lotName;
        @AuraEnabled public String communityName;
        @AuraEnabled public String communityBuilder; // communityName + builder
        @AuraEnabled public String installWoName;
        @AuraEnabled public String installWoCrew;    // installWoName + crewName
        @AuraEnabled public String crewName;
        @AuraEnabled public String aquaTechName;
        @AuraEnabled public String techName;         // same as aquaTechName
        @AuraEnabled public String scheduledTime;
        @AuraEnabled public Decimal goalMin;
        @AuraEnabled public String statusChip;       // CSS class string
        @AuraEnabled public String statusLabel;
    }

    public class InstallScopeRow {
        @AuraEnabled public String component;
        @AuraEnabled public Decimal standardQty;
        @AuraEnabled public Decimal goalMin;
        @AuraEnabled public String validationNote;
        @AuraEnabled public Boolean isTotal;
    }

    public class SameDayRow {
        @AuraEnabled public String id;
        @AuraEnabled public String timeIn;
        @AuraEnabled public String lotName;
        @AuraEnabled public String communityName;
        @AuraEnabled public String issue;
        @AuraEnabled public String sourceType;
        @AuraEnabled public String techName;
        @AuraEnabled public String slaLabel;
        @AuraEnabled public String slaChip;
    }

    public class TechStatusRow {
        @AuraEnabled public String id;
        @AuraEnabled public String techName;
        @AuraEnabled public String routeLabel;
        @AuraEnabled public Integer stopsPlanned;
        @AuraEnabled public Integer stopsDone;
        @AuraEnabled public Integer stopsRemaining;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String statusChip;
        @AuraEnabled public String locationLabel;
    }

    public class AlertRow {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public String severity;
        @AuraEnabled public String lotName;
        @AuraEnabled public String flagDescription;
        @AuraEnabled public String itemName;
    }

    public class ActivityRow {
        @AuraEnabled public String id;
        @AuraEnabled public String initials;
        @AuraEnabled public String authorName;
        @AuraEnabled public String timeAgo;
        @AuraEnabled public String body;
        @AuraEnabled public String avatarBg;
        @AuraEnabled public String avatarStyle;
    }

    public class TechRouteDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String techName;
        @AuraEnabled public String initials;
        @AuraEnabled public String avatarBg;
        @AuraEnabled public String avatarStyle;
        @AuraEnabled public String communityList;
        @AuraEnabled public Integer stopsPlanned;
        @AuraEnabled public Integer stopsDone;
        @AuraEnabled public Integer stopsRemaining;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String statusChip;
        @AuraEnabled public Decimal svgX;
        @AuraEnabled public Decimal svgY;
        @AuraEnabled public List<StopRow> stops;
    }

    public class StopRow {
        @AuraEnabled public Integer stopNum;
        @AuraEnabled public Boolean isComplete;
        @AuraEnabled public Boolean isCurrent;
        @AuraEnabled public Boolean isUpcoming;
        @AuraEnabled public Boolean isSameDay;
        @AuraEnabled public String stopType;
        @AuraEnabled public String lotName;           // stop title for display
        @AuraEnabled public String stopTitle;
        @AuraEnabled public String completionNotes;   // alias for stopSub
        @AuraEnabled public String stopSub;
        @AuraEnabled public String scheduledTime;
        @AuraEnabled public String typeChip;          // alias for chipLabel
        @AuraEnabled public String typeChipCss;       // alias for chipClass
        @AuraEnabled public String chipLabel;
        @AuraEnabled public String chipClass;
        @AuraEnabled public String rowBg;
        @AuraEnabled public Boolean showOpenBtn;
        @AuraEnabled public String openBtnClass;
        @AuraEnabled public String ticketId;          // for navigate button
    }

    public class SameDayDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String lotName;
        @AuraEnabled public String communityName;
        @AuraEnabled public String reportedBy;
        @AuraEnabled public String timeIn;
        @AuraEnabled public String issue;
        @AuraEnabled public String sourceType;
        @AuraEnabled public String techName;
        @AuraEnabled public String dispatchEta;
        @AuraEnabled public String vanStatusChip;
        @AuraEnabled public String vanStatusClass;
        @AuraEnabled public String weatherRisk;
        @AuraEnabled public String weatherChipClass;
        @AuraEnabled public List<TlStep> tlSteps;
        @AuraEnabled public String cardClass;
        @AuraEnabled public String timeInLabel;
        @AuraEnabled public String vanInventoryStatus;
        @AuraEnabled public String tlStep1Class;
        @AuraEnabled public String tlStep2Class;
        @AuraEnabled public String tlStep3Class;
        @AuraEnabled public String tlStep4Class;
        @AuraEnabled public String tlStep5Class;
    }

    public class TlStep {
        @AuraEnabled public String label;
        @AuraEnabled public String stepClass;
    }

    public class InventoryPageDTO {
        @AuraEnabled public List<InventoryPartDTO> partRows;
        @AuraEnabled public List<VanTechDTO> vanRows;
        @AuraEnabled public List<LogRow> logRows;
    }

    public class InventoryPartDTO {
        @AuraEnabled public String itemType;
        @AuraEnabled public String itemName;
        @AuraEnabled public Decimal shopQty;
        @AuraEnabled public Decimal vanQty;
        @AuraEnabled public Decimal onsiteQty;
        @AuraEnabled public Decimal totalQty;
        @AuraEnabled public Decimal shopPct;
        @AuraEnabled public Decimal vanPct;
        @AuraEnabled public Decimal onsitePct;
        @AuraEnabled public Boolean isBelowThreshold;
        @AuraEnabled public String alertLabel;
    }

    public class VanTechDTO {
        @AuraEnabled public String techName;
        @AuraEnabled public String vehicleName;
        @AuraEnabled public List<VanPartCount> partCounts;
    }

    public class VanPartCount {
        @AuraEnabled public String itemType;
        @AuraEnabled public Decimal qty;
        @AuraEnabled public String cellClass;
    }

    public class LogRow {
        @AuraEnabled public String id;
        @AuraEnabled public String dateLabel;
        @AuraEnabled public String techName;
        @AuraEnabled public String part;
        @AuraEnabled public String partName;
        @AuraEnabled public Decimal qtyAdded;
        @AuraEnabled public String reasonCode;
        @AuraEnabled public String reasonClass;
        @AuraEnabled public String locationLabel;
        @AuraEnabled public String location;
    }

    public class CommunityPageDTO {
        @AuraEnabled public List<CommunityAssignRow> communityRows;
        @AuraEnabled public List<TechCapacityRow> techCapacityRows;
        @AuraEnabled public List<SelectOption> techOptions;
    }

    public class CommunityAssignRow {
        @AuraEnabled public String id;
        @AuraEnabled public String communityName;
        @AuraEnabled public String builderName;
        @AuraEnabled public String communityBuilder;
        @AuraEnabled public String primaryTechId;
        @AuraEnabled public String primaryTechName;
        @AuraEnabled public String backupTechId;
        @AuraEnabled public String backupTechName;
        @AuraEnabled public Integer activeLots;
        @AuraEnabled public String serviceDays;
    }

    public class TechCapacityRow {
        @AuraEnabled public String techName;
        @AuraEnabled public Integer communitiesAssigned;
        @AuraEnabled public Integer activeLots;
        @AuraEnabled public Integer dailyAvgStops;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String capacityLabel;
        @AuraEnabled public String statusChipClass;
        @AuraEnabled public String capacityChip;
    }

    public class SelectOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class WateringPageDTO {
        @AuraEnabled public Integer year;
        @AuraEnabled public List<WateringMonthDTO> months;
        @AuraEnabled public String currentMonthName;
        @AuraEnabled public Decimal currentMonthPct;
        @AuraEnabled public String adjustedBy;
        @AuraEnabled public String lastAdjustedBy;
        @AuraEnabled public String lastAdjustedDate;
        @AuraEnabled public Integer affectedLots;
        @AuraEnabled public List<WateringHistRow> history;
        @AuraEnabled public List<WateringOptionDto> scheduleTypeOptions;
        @AuraEnabled public List<WateringOptionDto> frequencyOptions;
        @AuraEnabled public List<WateringProgramDto> programs;
        @AuraEnabled public String currentScheduleType;
        @AuraEnabled public String currentScheduleKey;
        @AuraEnabled public String serviceDayNote;
    }

    public class WateringMonthDTO {
        @AuraEnabled public Integer monthNum;
        @AuraEnabled public String monthName;
        @AuraEnabled public String monthAbbr;
        @AuraEnabled public Decimal pct;
        @AuraEnabled public Boolean isOff;
        @AuraEnabled public String cellClass;
        @AuraEnabled public Boolean isCurrent;
        @AuraEnabled public String pctLabel;
    }

    public class WateringHistRow {
        @AuraEnabled public String monthLabel;
        @AuraEnabled public Decimal scheduledPct;
        @AuraEnabled public Decimal actualAvgPct;
        @AuraEnabled public String adjustedBy;
        @AuraEnabled public String dateSet;
    }

    public class WateringOptionDto {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class WateringProgramDto {
        @AuraEnabled public String scheduleKey;
        @AuraEnabled public String scheduleType;
        @AuraEnabled public String monthName;
        @AuraEnabled public Integer weekNumber;
        @AuraEnabled public String periodLabel;
        @AuraEnabled public String runFrequency;
        @AuraEnabled public Integer runDurationMin;
        @AuraEnabled public Decimal runTimePct;
        @AuraEnabled public Integer recordCount;
        @AuraEnabled public Boolean isCurrent;
    }

    public class CloseoutTicketDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String lotName;
        @AuraEnabled public String communityName;
        @AuraEnabled public String techName;
        @AuraEnabled public String ticketType;
        @AuraEnabled public String scheduledDateLabel;
        @AuraEnabled public String scheduledDate;
        @AuraEnabled public String issues;
        @AuraEnabled public String issuesFound;
        @AuraEnabled public Boolean isDeviceInstalled;
        @AuraEnabled public Boolean isTimerTested;
        @AuraEnabled public Boolean isCoverageVerified;
        @AuraEnabled public Boolean isPhotosUploaded;
        @AuraEnabled public Boolean isCloseoutNotes;
        @AuraEnabled public Boolean isInventoryRecorded;
        @AuraEnabled public Boolean isCloseoutReady;
        @AuraEnabled public String pendingLabel;
        @AuraEnabled public String ageLabel;
        @AuraEnabled public String cardClass;
        @AuraEnabled public String cardChipClass;
        @AuraEnabled public String ageChipCss;
        @AuraEnabled public Decimal pendingHrs;
    }

    public class PickupPageDTO {
        @AuraEnabled public Integer seasonYear;
        @AuraEnabled public Integer seasonDay;
        @AuraEnabled public Integer seasonTotal;
        @AuraEnabled public Integer seasonDaysUntilRetrieve;
        @AuraEnabled public String seasonSubLabel;
        @AuraEnabled public Integer activeLots;
        @AuraEnabled public Integer pendingPickups;
        @AuraEnabled public Integer closedPickups;
        @AuraEnabled public List<PickupRow> pickupRows;
    }

    public class PickupRow {
        @AuraEnabled public String id;
        @AuraEnabled public String lotName;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotCommunity;
        @AuraEnabled public String closedBy;
        @AuraEnabled public String installDateLabel;
        @AuraEnabled public String installDate;
        @AuraEnabled public Integer daysOnSite;
        @AuraEnabled public String techName;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String statusChipClass;
        @AuraEnabled public Boolean hasVariance;
        @AuraEnabled public String rowBg;
    }

    // =========================================================================
    // HELPER UTILITIES
    // =========================================================================

    private static String formatDate(Date d) {
        if (d == null) return '';
        return d.month() + '/' + d.day() + '/' + d.year();
    }

    private static String formatDatetime(Datetime dt) {
        if (dt == null) return '';
        return dt.format('M/d/yyyy h:mm a');
    }

    private static String getInitials(String firstName, String lastName) {
        String f = (firstName != null && firstName.length() > 0)
            ? firstName.substring(0,1).toUpperCase() : '';
        String l = (lastName != null && lastName.length() > 0)
            ? lastName.substring(0,1).toUpperCase() : '';
        return f + l;
    }

    private static String getInitialsFromFullName(String fullName) {
        if (fullName == null || fullName.trim() == '') return '?';
        List<String> parts = fullName.trim().split(' ');
        if (parts.size() == 1) return parts[0].substring(0,1).toUpperCase();
        return parts[0].substring(0,1).toUpperCase()
             + parts[parts.size()-1].substring(0,1).toUpperCase();
    }

    private static String avatarColor(Integer idx) {
        return AVATAR_COLORS[Math.mod(idx, AVATAR_COLORS.size())];
    }

    /**
     * Compute season metrics relative to today.
     * Returns: [seasonDayNum (1-213 or 0 if off-season), daysUntilRetrieve]
     */
    private static Integer[] getSeasonMetrics(Date today) {
        Date seasonStart = Date.newInstance(today.year(), SEASON_START_MONTH, SEASON_START_DAY);
        Date seasonEnd   = Date.newInstance(today.year(), SEASON_END_MONTH,   SEASON_END_DAY);
        Integer dayNum = 0;
        if (today >= seasonStart && today <= seasonEnd) {
            dayNum = seasonStart.daysBetween(today) + 1;
            if (dayNum > SEASON_TOTAL_DAYS) dayNum = SEASON_TOTAL_DAYS;
        }
        Integer daysUntil = today <= seasonEnd ? today.daysBetween(seasonEnd) : 0;
        return new Integer[]{ dayNum, daysUntil };
    }

    private static String currentMonthName() {
        Integer m = Date.today().month();
        return MONTH_NAMES[m - 1];
    }

    private static String timeAgoLabel(Datetime dt) {
        if (dt == null) return '';
        Long diffMs = Datetime.now().getTime() - dt.getTime();
        Long diffMin = diffMs / 60000;
        if (diffMin < 1)   return 'just now';
        if (diffMin < 60)  return diffMin + 'm ago';
        Long diffHr = diffMin / 60;
        if (diffHr < 24)   return diffHr + 'h ago';
        Long diffDays = diffHr / 24;
        return diffDays + 'd ago';
    }

    private static String statusChipClass(String status) {
        if (status == null) return 'chip cgr';
        String s = status.toLowerCase();
        if (s.contains('progress') || s.contains('active')) return 'chip caqua';
        if (s.contains('complet') || s.contains('closed'))  return 'chip cg';
        if (s.contains('block'))                             return 'chip cr';
        return 'chip cb2';
    }

    private static String statusChipLabel(String status) {
        if (status == null) return 'Unknown';
        return status;
    }

    private static String serviceDayName(Date forDate) {
        return Datetime.newInstance(forDate, Time.newInstance(0, 0, 0, 0)).format('EEEE');
    }

    private static List<String> parseServiceDays(String rawValue) {
        List<String> ordered = new List<String>();
        if (String.isBlank(rawValue)) return ordered;
        Set<String> selected = new Set<String>();
        for (String token : rawValue.split(';')) {
            String trimmed = token == null ? null : token.trim();
            if (String.isNotBlank(trimmed)) selected.add(trimmed);
        }
        for (String dayName : WEEKDAY_ORDER) {
            if (selected.contains(dayName)) ordered.add(dayName);
        }
        return ordered;
    }

    private static Boolean serviceDayIncludes(String rawValue, String dayName) {
        return parseServiceDays(rawValue).contains(dayName);
    }

    private static String abbreviateServiceDay(String dayName) {
        if (dayName == 'Monday') return 'Mon';
        if (dayName == 'Tuesday') return 'Tue';
        if (dayName == 'Wednesday') return 'Wed';
        if (dayName == 'Thursday') return 'Thu';
        if (dayName == 'Friday') return 'Fri';
        if (dayName == 'Saturday') return 'Sat';
        if (dayName == 'Sunday') return 'Sun';
        return dayName;
    }

    private static String formatServiceDays(String rawValue) {
        List<String> days = parseServiceDays(rawValue);
        if (days.isEmpty()) return 'No service days set';
        if (days.size() == 5
            && days[0] == 'Monday'
            && days[1] == 'Tuesday'
            && days[2] == 'Wednesday'
            && days[3] == 'Thursday'
            && days[4] == 'Friday') {
            return 'Monday-Friday';
        }
        List<String> labels = new List<String>();
        for (String dayName : days) labels.add(abbreviateServiceDay(dayName));
        return String.join(labels, '-');
    }

    private static Id resolveCommunityFmId(Community__c communityRow) {
        if (communityRow == null) return null;
        if ((Id) communityRow.get('Assigned_FM__c') != null) {
            return (Id) communityRow.get('Assigned_FM__c');
        }
        if ((Id) communityRow.get('FM_Assignment__c') != null) {
            return (Id) communityRow.get('FM_Assignment__c');
        }
        return (Id) communityRow.getSObject('Builder_Account__r')?.get('Loving_FM__c');
    }

    private static String resolveCommunityFmName(Community__c communityRow) {
        if (communityRow == null) return 'Unassigned';
        User assignedFm = (User) communityRow.getSObject('Assigned_FM__r');
        if (assignedFm != null && String.isNotBlank(assignedFm.Name)) return assignedFm.Name;
        User legacyFm = (User) communityRow.getSObject('FM_Assignment__r');
        if (legacyFm != null && String.isNotBlank(legacyFm.Name)) return legacyFm.Name;
        Account builder = (Account) communityRow.getSObject('Builder_Account__r');
        if (builder != null) {
            User marketFm = (User) builder.getSObject('Loving_FM__r');
            if (marketFm != null && String.isNotBlank(marketFm.Name)) return marketFm.Name;
        }
        return 'Unassigned';
    }

    private static List<Community__c> loadAquaCommunities() {
        return [
            SELECT Id, Name, Service_Day__c, Aqua_Active__c,
                   Assigned_FM__c, Assigned_FM__r.Name,
                   FM_Assignment__c, FM_Assignment__r.Name,
                   Builder_Account__c, Builder_Account__r.Name,
                   Builder_Account__r.Loving_FM__c, Builder_Account__r.Loving_FM__r.Name
            FROM Community__c
            WHERE Aqua_Active__c = true
            ORDER BY Name
        ];
    }

    private static Map<Id, Integer> buildActiveAquaLotCountByCommunity(Set<Id> communityIds) {
        Map<Id, Integer> lotCountMap = new Map<Id, Integer>();
        if (communityIds == null || communityIds.isEmpty()) return lotCountMap;
        for (Lot__c lotRow : [
            SELECT Community__c
            FROM Lot__c
            WHERE Community__c IN :communityIds
              AND Aqua_Add_On__c > 0
              AND Lot_Status__c != 'Closed'
        ]) {
            Integer currentCount = lotCountMap.containsKey(lotRow.Community__c)
                ? lotCountMap.get(lotRow.Community__c)
                : 0;
            lotCountMap.put(lotRow.Community__c, currentCount + 1);
        }
        return lotCountMap;
    }

    private static String getInitialsFromName(String fullName) {
        if (String.isBlank(fullName)) return 'FM';
        List<String> pieces = fullName.split('\\s+');
        String first = pieces.isEmpty() ? '' : pieces[0];
        String last = pieces.size() > 1 ? pieces[pieces.size() - 1] : '';
        return getInitials(first, last);
    }

    // =========================================================================
    // 1. HOME TAB
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static HomeDTO getHomeData() {
        try {
            HomeDTO dto = new HomeDTO();
            Date today = Date.today();
            String todayServiceDay = serviceDayName(today);

            // ── Today label ──────────────────────────────────────────────────
            Datetime todayDt = Datetime.newInstance(today, Time.newInstance(0,0,0,0));
            dto.todayLabel = todayDt.format('EEEE, MMMM d, yyyy');

            // ── Season metrics ───────────────────────────────────────────────
            Integer[] season = getSeasonMetrics(today);
            Integer seasonDayNum = season[0];
            Date seasonStart = Date.newInstance(today.year(), SEASON_START_MONTH, SEASON_START_DAY);
            Date seasonEnd   = Date.newInstance(today.year(), SEASON_END_MONTH,   SEASON_END_DAY);
            dto.seasonDay = 'Day ' + seasonDayNum + ' of ' + SEASON_TOTAL_DAYS
                + ' (Apr 1 – Oct 31)';

            // ── Active Aqua communities + FM ownership ──────────────────────
            List<Community__c> aquaCommunities = [
                SELECT Id, Name, Service_Day__c, Aqua_Active__c,
                       Assigned_FM__c, Assigned_FM__r.Name,
                       FM_Assignment__c, FM_Assignment__r.Name,
                       Builder_Account__c, Builder_Account__r.Name,
                       Builder_Account__r.Loving_FM__c, Builder_Account__r.Loving_FM__r.Name
                FROM Community__c
                WHERE Aqua_Active__c = true
                ORDER BY Name
            ];
            Set<Id> fmUserIds = new Set<Id>();
            Integer communitiesWateringToday = 0;
            for (Community__c communityRow : aquaCommunities) {
                Id fmId = resolveCommunityFmId(communityRow);
                if (fmId != null) fmUserIds.add(fmId);
                if (serviceDayIncludes(communityRow.Service_Day__c, todayServiceDay)) {
                    communitiesWateringToday++;
                }
            }
            Map<Id, User> fmUsers = fmUserIds.isEmpty()
                ? new Map<Id, User>()
                : new Map<Id, User>([
                    SELECT Id, Name
                    FROM User
                    WHERE Id IN :fmUserIds
                ]);
            dto.fmName = !fmUsers.isEmpty()
                ? fmUsers.values()[0].Name
                : '';

            // ── FM roster for Aqua schedule ownership ───────────────────────
            List<TeamMemberDTO> members = new List<TeamMemberDTO>();
            List<String> fmNames = new List<String>();
            Integer idx = 0;
            for (Id fmUserId : fmUsers.keySet()) {
                User userRow = fmUsers.get(fmUserId);
                TeamMemberDTO m = new TeamMemberDTO();
                m.id       = (String) fmUserId;
                m.name     = userRow.Name;
                m.initials = getInitialsFromName(userRow.Name);
                m.isLead   = true;
                m.avatarBg = avatarColor(idx);
                m.avatarStyle = 'background:' + m.avatarBg + ';border-radius:50%';
                members.add(m);
                fmNames.add(userRow.Name);
                idx++;
            }
            dto.teamMembers = members;
            dto.teamSub = fmNames.isEmpty()
                ? '0 field managers assigned to Aqua communities.'
                : fmNames.size() + ' field managers · '
                    + communitiesWateringToday + ' communities watering today';

            // ── KPI: installs today ──────────────────────────────────────────
            Integer installsToday = [
                SELECT COUNT() FROM Aqua_Install_Ticket__c
                WHERE Scheduled_Date__c = :today
            ];
            dto.kpiInstallsToday = installsToday;

            // ── KPI: checks today ────────────────────────────────────────────
            dto.kpiChecksToday = communitiesWateringToday;

            // ── KPI: same-day (open check tickets with billing reason code) ──
            Integer sameDayCount = [
                SELECT COUNT() FROM Aqua_Check_Ticket__c
                WHERE Status__c = 'Open'
                  AND Billing_Reason_Code__c != null
            ];
            dto.kpiSameDay = sameDayCount;

            // ── KPI: on-site lots ────────────────────────────────────────────
            Integer onSiteLots = [
                SELECT COUNT() FROM Lot__c
                WHERE Aqua_Add_On__c > 0
                  AND Lot_Status__c != 'Closed'
            ];
            dto.kpiOnSiteLots = onSiteLots;

            // ── KPI: awaiting closeout ────────────────────────────────────────
            Integer awaitingCloseout = [
                SELECT COUNT() FROM Aqua_Install_Ticket__c
                WHERE Status__c = 'Open'
            ] + [
                SELECT COUNT() FROM Aqua_Check_Ticket__c
                WHERE Status__c = 'Open'
                  AND Billing_Reason_Code__c = null
            ];
            dto.kpiAwaitingCloseout = awaitingCloseout;

            // ── KPI: run-time pct ─────────────────────────────────────────────
            String monthName = currentMonthName();
            dto.wateringCurrentMonthLabel = monthName;
            List<Aqua_Watering_Schedule__c> wsRecs = [
                SELECT Run_Time_Pct__c, Notes__c, LastModifiedDate, LastModifiedById
                FROM Aqua_Watering_Schedule__c
                WHERE Month__c = :monthName
                LIMIT 1
            ];
            Decimal runPct = 0;
            String wateringAdjBy = '';
            if (!wsRecs.isEmpty()) {
                runPct = wsRecs[0].Run_Time_Pct__c != null ? wsRecs[0].Run_Time_Pct__c : 0;
                // Get modifier name
                if (wsRecs[0].LastModifiedById != null) {
                    List<User> modUser = [
                        SELECT Name FROM User WHERE Id = :wsRecs[0].LastModifiedById LIMIT 1
                    ];
                    if (!modUser.isEmpty()) {
                        wateringAdjBy = modUser[0].Name + ' '
                            + wsRecs[0].LastModifiedDate.format('M/d/yyyy');
                        dto.wateringAdjustedDate = wsRecs[0].LastModifiedDate.format('MMMM d, yyyy');
                    }
                }
            }
            dto.kpiRunTimePct              = String.valueOf(runPct.intValue());
            dto.wateringCurrentMonthPct    = String.valueOf(runPct.intValue());
            dto.wateringAffectedLots       = onSiteLots;
            dto.wateringAdjustedBy         = wateringAdjBy;
            dto.divisionTerritory          = 'Division Territory';

            // ── seasonSub ────────────────────────────────────────────────────
            dto.seasonSub = members.size() + ' field managers · '
                + communitiesWateringToday + ' communities watering ' + todayServiceDay + ' · Run-time '
                + monthName + ': ' + dto.kpiRunTimePct + '%';

            // ── Today's installs ─────────────────────────────────────────────
            dto.installsToday = buildTodayInstallRows(today);

            // ── Same-day repairs (home preview — limit 5) ─────────────────────
            dto.sameDayRepairs = buildSameDayRows(5);

            // ── FM schedule coverage ────────────────────────────────────────
            dto.techStatus = buildTechStatusRows(aquaCommunities);

            // ── Inventory alerts ──────────────────────────────────────────────
            dto.inventoryAlerts = buildInventoryAlerts();

            // ── Tamper / quality flags ────────────────────────────────────────
            dto.tamperFlags = buildTamperFlags();

            // ── Recent activity ───────────────────────────────────────────────
            dto.activity = buildActivityRows();

            return dto;

        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getHomeData', null, e.getMessage());
            throw new AuraHandledException('Unable to load home data: ' + e.getMessage());
        }
    }

    // =========================================================================
    // 2. INSTALLS TODAY TAB
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static List<TodayInstallRow> getTodayInstalls() {
        try {
            return buildTodayInstallRows(Date.today());
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getTodayInstalls', null, e.getMessage());
            throw new AuraHandledException('Unable to load installs: ' + e.getMessage());
        }
    }

    private static List<TodayInstallRow> buildTodayInstallRows(Date forDate) {
        List<TodayInstallRow> rows = new List<TodayInstallRow>();
        List<Aqua_Install_Ticket__c> tickets = [
            SELECT Id, Name, Community__r.Name, Work_Order__c,
                   Crew__c, FM_Assignment__r.Name, Scheduled_Date__c, Status__c
            FROM Aqua_Install_Ticket__c
            WHERE Scheduled_Date__c = :forDate
            ORDER BY Scheduled_Date__c, Name
        ];
        Set<Id> woIds = new Set<Id>();
        for (Aqua_Install_Ticket__c t : tickets) {
            if (t.Work_Order__c != null) woIds.add(t.Work_Order__c);
        }
        Map<Id,String> woNameMap = new Map<Id,String>();
        for (Work_Order__c wo : [SELECT Id, Name FROM Work_Order__c WHERE Id IN :woIds]) {
            woNameMap.put(wo.Id, wo.Name);
        }
        for (Aqua_Install_Ticket__c t : tickets) {
            TodayInstallRow r = new TodayInstallRow();
            r.id            = t.Id;
            r.name          = t.Name;
            r.lotName       = t.Name;
            r.communityName = t.Community__c != null ? t.Community__r.Name : '';
            r.installWoName = t.Work_Order__c != null
                ? (woNameMap.containsKey(t.Work_Order__c) ? woNameMap.get(t.Work_Order__c) : String.valueOf(t.Work_Order__c))
                : '';
            r.crewName      = t.Crew__c != null ? t.Crew__c : '';
            r.aquaTechName  = t.FM_Assignment__c != null ? t.FM_Assignment__r.Name : '';
            r.woName        = t.Name;
            r.aquaWoName    = t.Name;
            r.techName      = r.aquaTechName;
            r.communityBuilder = (r.communityName != null ? r.communityName : '') + ' · ';
            r.installWoCrew = (r.installWoName != null ? r.installWoName : '')
                + (r.crewName != null && r.crewName != '' ? ' (' + r.crewName + ')' : '');
            r.goalMin       = 0;
            r.scheduledTime = t.Scheduled_Date__c != null
                ? Datetime.newInstance(t.Scheduled_Date__c, Time.newInstance(0,0,0,0)).format('M/d/yyyy')
                : '';
            r.statusChip    = statusChipClass(t.Status__c);
            r.statusLabel   = statusChipLabel(t.Status__c);
            rows.add(r);
        }
        return rows;
    }

    // =========================================================================
    // 3. INSTALL SCOPE (standard scope from Aqua_Master_Inventory__c)
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static List<InstallScopeRow> getInstallScope() {
        try {
            List<InstallScopeRow> rows = new List<InstallScopeRow>();
            List<Aqua_Master_Inventory__c> items = [
                SELECT Id, Item_Type__c, Standard_Qty_Per_Lot__c, Goal_Min_Per_Lot__c, Validation_Note__c
                FROM Aqua_Master_Inventory__c
                ORDER BY Item_Type__c
            ];
            Decimal totalGoalMin = 0;
            for (Aqua_Master_Inventory__c item : items) {
                InstallScopeRow r = new InstallScopeRow();
                r.component      = item.Item_Type__c;
                r.standardQty    = item.Standard_Qty_Per_Lot__c != null ? item.Standard_Qty_Per_Lot__c : 0;
                r.goalMin        = item.Goal_Min_Per_Lot__c != null ? item.Goal_Min_Per_Lot__c : 0;
                r.validationNote = item.Validation_Note__c != null ? item.Validation_Note__c : 'Verify qty at close';
                r.isTotal        = false;
                totalGoalMin += r.goalMin;
                rows.add(r);
            }
            // Summary total row
            InstallScopeRow total = new InstallScopeRow();
            total.component   = 'Total';
            total.standardQty = null;
            total.goalMin     = totalGoalMin;
            total.validationNote = 'System validates installed quantities, transfers count to next-day Check ticket, decrements van inventory, increments on-site inventory.';
            total.isTotal     = true;
            rows.add(total);
            return rows;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getInstallScope', null, e.getMessage());
            throw new AuraHandledException('Unable to load install scope: ' + e.getMessage());
        }
    }

    // =========================================================================
    // 4. CHECK ROUTES TAB
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static List<TechRouteDTO> getTechRoutes() {
        try {
            Date today = Date.today();
            String todayServiceDay = serviceDayName(today);
            List<Community__c> communities = loadAquaCommunities();
            Set<Id> communityIds = new Set<Id>();
            Set<Id> fmUserIds = new Set<Id>();
            for (Community__c communityRow : communities) {
                communityIds.add(communityRow.Id);
                Id fmId = resolveCommunityFmId(communityRow);
                if (fmId != null) fmUserIds.add(fmId);
            }

            Map<Id, Integer> lotCountMap = buildActiveAquaLotCountByCommunity(communityIds);
            Map<Id, User> fmUsers = fmUserIds.isEmpty()
                ? new Map<Id, User>()
                : new Map<Id, User>([
                    SELECT Id, Name
                    FROM User
                    WHERE Id IN :fmUserIds
                ]);

            Map<Id, List<Community__c>> communitiesByFm = new Map<Id, List<Community__c>>();
            List<Community__c> unassignedCommunities = new List<Community__c>();
            for (Community__c communityRow : communities) {
                Id fmId = resolveCommunityFmId(communityRow);
                if (fmId == null) {
                    unassignedCommunities.add(communityRow);
                    continue;
                }
                if (!communitiesByFm.containsKey(fmId)) communitiesByFm.put(fmId, new List<Community__c>());
                communitiesByFm.get(fmId).add(communityRow);
            }

            List<TechRouteDTO> result = new List<TechRouteDTO>();
            Integer colorIdx = 0;
            for (Id fmId : communitiesByFm.keySet()) {
                List<Community__c> fmCommunities = communitiesByFm.get(fmId);
                TechRouteDTO dto = new TechRouteDTO();
                dto.id = (String) fmId;
                dto.techName = fmUsers.containsKey(fmId) ? fmUsers.get(fmId).Name : 'Unassigned';
                dto.initials = getInitialsFromName(dto.techName);
                dto.avatarBg = avatarColor(colorIdx++);
                dto.avatarStyle = 'background:' + dto.avatarBg;

                List<String> allCommunityNames = new List<String>();
                List<StopRow> stopRows = new List<StopRow>();
                Integer stopNum = 1;
                for (Community__c communityRow : fmCommunities) {
                    allCommunityNames.add(communityRow.Name);
                    if (!serviceDayIncludes(communityRow.Service_Day__c, todayServiceDay)) continue;
                    StopRow row = new StopRow();
                    row.stopNum = stopNum++;
                    row.isComplete = false;
                    row.isCurrent = stopRows.isEmpty();
                    row.isUpcoming = !row.isCurrent;
                    row.isSameDay = false;
                    row.stopType = 'Watering Day';
                    row.lotName = communityRow.Name;
                    row.stopTitle = communityRow.Name + ' · ' + formatServiceDays(communityRow.Service_Day__c);
                    row.stopSub = (communityRow.Builder_Account__r != null ? communityRow.Builder_Account__r.Name : 'Builder not linked')
                        + ' · ' + String.valueOf(lotCountMap.containsKey(communityRow.Id) ? lotCountMap.get(communityRow.Id) : 0)
                        + ' active Aqua lots';
                    row.completionNotes = row.stopSub;
                    row.scheduledTime = todayServiceDay;
                    row.chipLabel = formatServiceDays(communityRow.Service_Day__c);
                    row.chipClass = 'chip caqua';
                    row.typeChip = row.chipLabel;
                    row.typeChipCss = row.chipClass;
                    row.rowBg = row.isCurrent ? '#fffbf2' : '';
                    row.showOpenBtn = true;
                    row.openBtnClass = 'sf-btn primary';
                    row.ticketId = (String) communityRow.Id;
                    stopRows.add(row);
                }

                dto.communityList = allCommunityNames.isEmpty() ? '0 communities assigned' : String.join(allCommunityNames, ', ');
                dto.stops = stopRows;
                dto.stopsPlanned = stopRows.size();
                dto.stopsDone = 0;
                dto.stopsRemaining = stopRows.size();
                if (stopRows.isEmpty()) {
                    dto.statusLabel = 'No service today';
                    dto.statusChip = 'chip cgr';
                } else {
                    dto.statusLabel = 'Watering today';
                    dto.statusChip = 'chip caqua';
                }
                result.add(dto);
            }

            if (!unassignedCommunities.isEmpty()) {
                TechRouteDTO dto = new TechRouteDTO();
                dto.id = 'unassigned';
                dto.techName = 'Unassigned';
                dto.initials = 'UA';
                dto.avatarBg = avatarColor(colorIdx);
                dto.avatarStyle = 'background:' + dto.avatarBg;
                List<String> unassignedNames = new List<String>();
                for (Community__c communityRow : unassignedCommunities) unassignedNames.add(communityRow.Name);
                dto.communityList = String.join(unassignedNames, ', ');
                dto.stops = new List<StopRow>();
                dto.stopsPlanned = 0;
                dto.stopsDone = 0;
                dto.stopsRemaining = 0;
                dto.statusLabel = 'Assign field manager';
                dto.statusChip = 'chip cr';
                result.add(dto);
            }
            return result;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getTechRoutes', null, e.getMessage());
            throw new AuraHandledException('Unable to load field manager routes: ' + e.getMessage());
        }
    }

    // =========================================================================
    // 5. SAME-DAY TAB
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static List<SameDayDTO> getSameDayQueue() {
        try {
            List<SameDayDTO> result = new List<SameDayDTO>();
            List<Aqua_Check_Ticket__c> tickets = [
                SELECT Id, Name, Community__r.Name, Work_Order__c,
                       Assigned_To__r.Name, Billing_Reason_Code__c, Check_Notes__c,
                       Turf_Condition_Score__c, System_Tampered__c,
                       Scheduled_Date__c, CreatedDate, Status__c
                FROM Aqua_Check_Ticket__c
                WHERE Status__c = 'Open'
                  AND Billing_Reason_Code__c != null
                ORDER BY CreatedDate DESC
            ];
            Integer idx = 0;
            for (Aqua_Check_Ticket__c t : tickets) {
                SameDayDTO dto = new SameDayDTO();
                dto.id            = t.Id;
                dto.lotName       = t.Name;
                dto.communityName = t.Community__c != null ? t.Community__r.Name : '';
                dto.reportedBy    = 'Community Manager'; // source not directly on Check ticket
                dto.timeIn        = t.CreatedDate != null ? t.CreatedDate.format('h:mm a') : '';
                Decimal slaHrs = t.CreatedDate != null ? (Datetime.now().getTime() - t.CreatedDate.getTime()) / 3600000.0 : 0;
                dto.timeInLabel   = slaHrs.setScale(1) + ' hrs';
                dto.issue         = t.Check_Notes__c != null ? t.Check_Notes__c : 'See ticket';
                // Derive source from billing reason code
                String brc = t.Billing_Reason_Code__c;
                if (brc != null && brc.startsWith('(A)')) dto.sourceType = 'Missing Material';
                else if (brc != null && brc.startsWith('(B)')) dto.sourceType = 'Warranty';
                else if (brc != null && brc.startsWith('(C)')) dto.sourceType = 'Additional Coverage';
                else dto.sourceType = 'Field Discovery';
                dto.techName     = t.Assigned_To__c != null ? t.Assigned_To__r.Name : 'Unassigned';
                dto.dispatchEta  = 'Calculating…';
                dto.vanStatusChip      = 'OK';
                dto.vanStatusClass     = 'chip cg';
                dto.vanInventoryStatus = 'OK';
                dto.weatherRisk    = 'None';
                dto.weatherChipClass = 'chip cgr';

                // Timeline steps
                List<TlStep> steps = new List<TlStep>();
                steps.add(makeTlStep('Reported',   'done'));
                steps.add(makeTlStep('Dispatched', t.Assigned_To__c != null ? 'done' : 'blank'));
                steps.add(makeTlStep('En Route',   'blank'));
                steps.add(makeTlStep('Arrived',    'blank'));
                steps.add(makeTlStep('Resolved',   'blank'));
                dto.tlSteps   = steps;
                dto.cardClass = 'alert';
                dto.tlStep1Class = steps[0].stepClass;
                dto.tlStep2Class = steps[1].stepClass;
                dto.tlStep3Class = steps[2].stepClass;
                dto.tlStep4Class = steps[3].stepClass;
                dto.tlStep5Class = steps[4].stepClass;
                result.add(dto);
                idx++;
            }
            return result;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getSameDayQueue', null, e.getMessage());
            throw new AuraHandledException('Unable to load same-day queue: ' + e.getMessage());
        }
    }

    private static TlStep makeTlStep(String lbl, String cls) {
        TlStep s = new TlStep();
        s.label     = lbl;
        s.stepClass = cls;
        return s;
    }

    // =========================================================================
    // 6. INVENTORY TAB
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static InventoryPageDTO getInventoryData() {
        try {
            InventoryPageDTO dto = new InventoryPageDTO();
            Map<String,Integer> thresholds = getReorderThresholds();

            // ── Part rows: aggregate by Item_Type__c + Location_Type__c ─────────
            Map<String, Map<String,Decimal>> itemLocQty = new Map<String, Map<String,Decimal>>();
            for (AggregateResult ar : [
                SELECT Item_Type__c itype, Location_Type__c loc, SUM(Quantity__c) total
                FROM Aqua_Inventory__c
                GROUP BY Item_Type__c, Location_Type__c
            ]) {
                String itype = (String) ar.get('itype');
                String loc   = (String) ar.get('loc');
                Decimal qty  = ar.get('total') != null ? (Decimal) ar.get('total') : 0;
                if (!itemLocQty.containsKey(itype)) {
                    itemLocQty.put(itype, new Map<String,Decimal>());
                }
                itemLocQty.get(itype).put(loc, qty);
            }

            List<InventoryPartDTO> partRows = new List<InventoryPartDTO>();
            for (String itype : itemLocQty.keySet()) {
                Map<String,Decimal> locMap = itemLocQty.get(itype);
                Decimal shopQty   = locMap.containsKey('Shop')    ? locMap.get('Shop')    : 0;
                Decimal vanQty    = locMap.containsKey('Van')     ? locMap.get('Van')     : 0;
                Decimal onsiteQty = locMap.containsKey('On-Site') ? locMap.get('On-Site') : 0;
                Decimal total     = shopQty + vanQty + onsiteQty;

                InventoryPartDTO p = new InventoryPartDTO();
                p.itemType    = itype;
                p.itemName    = itype;
                p.shopQty     = shopQty;
                p.vanQty      = vanQty;
                p.onsiteQty   = onsiteQty;
                p.totalQty    = total;
                p.shopPct     = total > 0 ? (shopQty   / total * 100).setScale(1) : 0;
                p.vanPct      = total > 0 ? (vanQty    / total * 100).setScale(1) : 0;
                p.onsitePct   = total > 0 ? (onsiteQty / total * 100).setScale(1) : 0;
                Integer threshold = thresholds.containsKey(itype) ? thresholds.get(itype) : 5;
                p.isBelowThreshold = (shopQty < threshold);
                p.alertLabel  = p.isBelowThreshold
                    ? 'Low: ' + shopQty.intValue() + ' in shop (min ' + threshold + ')'
                    : '';
                partRows.add(p);
            }
            dto.partRows = partRows;

            // ── Van rows: group by Employee__c, show Vehicle__c name ────────────
            Map<Id, Map<String,Decimal>> empItemQty = new Map<Id, Map<String,Decimal>>();
            for (AggregateResult ar : [
                SELECT Employee__c empid, Item_Type__c itype, SUM(Quantity__c) total
                FROM Aqua_Inventory__c
                WHERE Location_Type__c = 'Van'
                  AND Employee__c != null
                GROUP BY Employee__c, Item_Type__c
            ]) {
                Id empid     = (Id) ar.get('empid');
                String itype = (String) ar.get('itype');
                Decimal qty  = ar.get('total') != null ? (Decimal) ar.get('total') : 0;
                if (!empItemQty.containsKey(empid)) {
                    empItemQty.put(empid, new Map<String,Decimal>());
                }
                empItemQty.get(empid).put(itype, qty);
            }
            // Employee names
            Map<Id,String> empNameMap = new Map<Id,String>();
            for (Employee__c emp : [SELECT Id, Name FROM Employee__c WHERE Id IN :empItemQty.keySet()]) {
                empNameMap.put(emp.Id, emp.Name);
            }
            // Vehicle names — latest vehicle per employee from Aqua_Inventory__c
            Map<Id,String> empVehicleMap = new Map<Id,String>();
            for (Aqua_Inventory__c inv : [
                SELECT Employee__c, Vehicle__r.Name
                FROM Aqua_Inventory__c
                WHERE Location_Type__c = 'Van'
                  AND Employee__c != null
                  AND Vehicle__c != null
                ORDER BY LastModifiedDate DESC
            ]) {
                if (!empVehicleMap.containsKey(inv.Employee__c)) {
                    empVehicleMap.put(inv.Employee__c, inv.Vehicle__r.Name != null ? inv.Vehicle__r.Name : '');
                }
            }
            // Collect all item types from part rows for consistent columns
            List<String> allItemTypes = new List<String>();
            for (InventoryPartDTO p : partRows) allItemTypes.add(p.itemType);

            List<VanTechDTO> vanRows = new List<VanTechDTO>();
            for (Id empid : empItemQty.keySet()) {
                VanTechDTO vr  = new VanTechDTO();
                vr.techName    = empNameMap.containsKey(empid) ? empNameMap.get(empid) : String.valueOf(empid);
                vr.vehicleName = empVehicleMap.containsKey(empid) ? empVehicleMap.get(empid) : '';
                Map<String,Decimal> itemMap = empItemQty.get(empid);
                List<VanPartCount> pCounts = new List<VanPartCount>();
                for (String itype : allItemTypes) {
                    VanPartCount vpc = new VanPartCount();
                    vpc.itemType  = itype;
                    vpc.qty       = itemMap.containsKey(itype) ? itemMap.get(itype) : 0;
                    Integer thr   = thresholds.containsKey(itype) ? thresholds.get(itype) : 5;
                    vpc.cellClass = vpc.qty == 0 ? 'cell-zero' : (vpc.qty < thr ? 'cell-low' : '');
                    pCounts.add(vpc);
                }
                vr.partCounts = pCounts;
                vanRows.add(vr);
            }
            dto.vanRows = vanRows;

            // ── Adjustment log (this week, Reason B) ─────────────────────────
            Date weekStart = Date.today().toStartOfWeek();
            List<LogRow> logRows = new List<LogRow>();
            for (Aqua_Inventory_Adjustment__c adj : [
                SELECT Id, Adjustment_DateTime__c, Lot__c, Lot__r.Name,
                       Quantity__c, Tech__c, Tech__r.Name, Aqua_Inventory_Reason_Code__c
                FROM Aqua_Inventory_Adjustment__c
                WHERE Adjustment_DateTime__c >= :Datetime.newInstance(weekStart, Time.newInstance(0,0,0,0))
                  AND Aqua_Inventory_Reason_Code__c = '(B) Damaged or Malfunctioning (Warranty)'
                ORDER BY Adjustment_DateTime__c DESC
            ]) {
                LogRow lr = new LogRow();
                lr.id          = adj.Id;
                lr.dateLabel   = adj.Adjustment_DateTime__c != null
                    ? adj.Adjustment_DateTime__c.format('M/d/yyyy') : '';
                lr.techName    = adj.Tech__c != null ? adj.Tech__r.Name : '';
                lr.part          = '';   // Item_Catalog__c is a ghost field — omitted from SELECT
                lr.partName      = lr.part;
                lr.qtyAdded      = adj.Quantity__c != null ? adj.Quantity__c : 0;
                lr.reasonCode    = adj.Aqua_Inventory_Reason_Code__c;
                lr.reasonClass   = 'chip ca';
                lr.locationLabel = adj.Lot__c != null ? adj.Lot__r.Name : 'Van';
                lr.location      = lr.locationLabel;
                logRows.add(lr);
            }
            dto.logRows = logRows;

            return dto;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getInventoryData', null, e.getMessage());
            throw new AuraHandledException('Unable to load inventory data: ' + e.getMessage());
        }
    }

    // =========================================================================
    // 7. COMMUNITY ASSIGNMENTS TAB
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static CommunityPageDTO getCommunityData() {
        try {
            CommunityPageDTO dto = new CommunityPageDTO();
            Date today = Date.today();
            String todayServiceDay = serviceDayName(today);
            List<Community__c> communities = loadAquaCommunities();
            Set<Id> communityIds = new Set<Id>();
            Set<Id> fmUserIds = new Set<Id>();
            for (Community__c communityRow : communities) {
                communityIds.add(communityRow.Id);
                Id fmId = resolveCommunityFmId(communityRow);
                if (fmId != null) fmUserIds.add(fmId);
            }

            Map<Id, Integer> lotCountMap = buildActiveAquaLotCountByCommunity(communityIds);
            Map<Id, User> fmUsers = fmUserIds.isEmpty()
                ? new Map<Id, User>()
                : new Map<Id, User>([
                    SELECT Id, Name
                    FROM User
                    WHERE Id IN :fmUserIds
                ]);

            List<SelectOption> fmOptions = new List<SelectOption>();
            SelectOption blank = new SelectOption();
            blank.label = '-- Unassigned --';
            blank.value = '';
            fmOptions.add(blank);
            for (User fmUser : fmUsers.values()) {
                SelectOption option = new SelectOption();
                option.label = fmUser.Name;
                option.value = (String) fmUser.Id;
                fmOptions.add(option);
            }
            dto.techOptions = fmOptions;

            Map<Id, Integer> fmCommunityCount = new Map<Id, Integer>();
            Map<Id, Integer> fmLotCount = new Map<Id, Integer>();
            Map<Id, Integer> fmTodayCount = new Map<Id, Integer>();
            List<CommunityAssignRow> commRows = new List<CommunityAssignRow>();
            for (Community__c communityRow : communities) {
                CommunityAssignRow row = new CommunityAssignRow();
                row.id = (String) communityRow.Id;
                row.communityName = communityRow.Name;
                row.builderName = communityRow.Builder_Account__r != null ? communityRow.Builder_Account__r.Name : '';
                row.communityBuilder = row.builderName == '' ? row.communityName : row.communityName + ' · ' + row.builderName;
                Id fmId = resolveCommunityFmId(communityRow);
                row.primaryTechId = fmId != null ? (String) fmId : '';
                row.primaryTechName = resolveCommunityFmName(communityRow);
                row.backupTechId = communityRow.Builder_Account__r != null && communityRow.Builder_Account__r.Loving_FM__c != null
                    ? (String) communityRow.Builder_Account__r.Loving_FM__c
                    : '';
                row.backupTechName = communityRow.Builder_Account__r != null
                    && communityRow.Builder_Account__r.Loving_FM__r != null
                    && row.backupTechId != row.primaryTechId
                    ? communityRow.Builder_Account__r.Loving_FM__r.Name
                    : '—';
                row.activeLots = lotCountMap.containsKey(communityRow.Id) ? lotCountMap.get(communityRow.Id) : 0;
                row.serviceDays = formatServiceDays(communityRow.Service_Day__c);
                commRows.add(row);

                if (fmId != null) {
                    fmCommunityCount.put(fmId, (fmCommunityCount.containsKey(fmId) ? fmCommunityCount.get(fmId) : 0) + 1);
                    fmLotCount.put(fmId, (fmLotCount.containsKey(fmId) ? fmLotCount.get(fmId) : 0) + row.activeLots);
                    if (serviceDayIncludes(communityRow.Service_Day__c, todayServiceDay)) {
                        fmTodayCount.put(fmId, (fmTodayCount.containsKey(fmId) ? fmTodayCount.get(fmId) : 0) + 1);
                    }
                }
            }
            dto.communityRows = commRows;

            List<TechCapacityRow> capRows = new List<TechCapacityRow>();
            for (Id fmId : fmUsers.keySet()) {
                TechCapacityRow cap = new TechCapacityRow();
                cap.techName = fmUsers.get(fmId).Name;
                cap.communitiesAssigned = fmCommunityCount.containsKey(fmId) ? fmCommunityCount.get(fmId) : 0;
                cap.activeLots = fmLotCount.containsKey(fmId) ? fmLotCount.get(fmId) : 0;
                cap.dailyAvgStops = fmTodayCount.containsKey(fmId) ? fmTodayCount.get(fmId) : 0;
                if (cap.dailyAvgStops == 0) {
                    cap.statusLabel = 'No watering today';
                    cap.statusChipClass = 'chip cgr';
                } else if (cap.dailyAvgStops <= 3) {
                    cap.statusLabel = 'Balanced';
                    cap.statusChipClass = 'chip cg';
                } else if (cap.dailyAvgStops <= 6) {
                    cap.statusLabel = 'Near capacity';
                    cap.statusChipClass = 'chip ca';
                } else {
                    cap.statusLabel = 'Heavy day';
                    cap.statusChipClass = 'chip cr';
                }
                cap.capacityLabel = cap.statusLabel;
                cap.capacityChip = cap.statusChipClass;
                capRows.add(cap);
            }
            dto.techCapacityRows = capRows;

            return dto;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getCommunityData', null, e.getMessage());
            throw new AuraHandledException('Unable to load community data: ' + e.getMessage());
        }
    }

    // =========================================================================
    // 8. WATERING SCHEDULE TAB
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static WateringPageDTO getWateringData() {
        try {
            WateringPageDTO dto = new WateringPageDTO();
            Integer yr = Date.today().year();
            dto.year = yr;
            String currMonth = currentMonthName();

            // All watering schedule records for current year
            List<Aqua_Watering_Schedule__c> recs = [
                SELECT Id, Month__c, Run_Time_Pct__c, Notes__c,
                       Effective_Year__c, LastModifiedDate, LastModifiedById,
                       Schedule_Type__c, Run_Frequency__c, Run_Duration_Min__c,
                       Week_Number__c
                FROM Aqua_Watering_Schedule__c
                WHERE Effective_Year__c = :yr
                ORDER BY Schedule_Type__c, Month__c, Week_Number__c
            ];
            Map<String,Aqua_Watering_Schedule__c> monthRecMap = new Map<String,Aqua_Watering_Schedule__c>();
            Map<String, WateringProgramDto> programByKey = new Map<String, WateringProgramDto>();
            List<String> programKeyOrder = new List<String>();
            Set<Id> wateringUserIds = new Set<Id>();
            for (Aqua_Watering_Schedule__c r : recs) {
                if (r.Month__c != null) monthRecMap.put(r.Month__c, r);
                if (r.LastModifiedById != null) {
                    wateringUserIds.add(r.LastModifiedById);
                }
                String scheduleType = String.isNotBlank(r.Schedule_Type__c) ? r.Schedule_Type__c : 'Seasonal Monthly';
                String monthName = String.isNotBlank(r.Month__c) ? r.Month__c : 'Unassigned';
                Integer weekNumber = r.Week_Number__c != null ? Integer.valueOf(r.Week_Number__c) : null;
                String programKey = scheduleType + '|' + monthName + '|' + (weekNumber == null ? '' : String.valueOf(weekNumber));
                if (!programByKey.containsKey(programKey)) {
                    WateringProgramDto program = new WateringProgramDto();
                    program.scheduleKey = programKey;
                    program.scheduleType = scheduleType;
                    program.monthName = monthName;
                    program.weekNumber = weekNumber;
                    program.periodLabel = weekNumber == null ? monthName : ('Week ' + weekNumber + ' · ' + monthName);
                    program.runFrequency = r.Run_Frequency__c;
                    program.runDurationMin = r.Run_Duration_Min__c != null ? Integer.valueOf(r.Run_Duration_Min__c) : null;
                    program.runTimePct = r.Run_Time_Pct__c != null ? r.Run_Time_Pct__c : 0;
                    program.recordCount = 0;
                    program.isCurrent = (monthName == currMonth);
                    programByKey.put(programKey, program);
                    programKeyOrder.add(programKey);
                }
                programByKey.get(programKey).recordCount++;
            }
            Map<Id, User> wateringUserMap = wateringUserIds.isEmpty()
                ? new Map<Id, User>()
                : new Map<Id, User>([
                    SELECT Id, Name
                    FROM User
                    WHERE Id IN :wateringUserIds
                ]);

            dto.currentMonthName = currMonth;
            Integer currMonthNum = Date.today().month();

            // Build 12-month grid
            List<WateringMonthDTO> months = new List<WateringMonthDTO>();
            for (Integer mi = 1; mi <= 12; mi++) {
                String mName = MONTH_NAMES[mi - 1];
                WateringMonthDTO m = new WateringMonthDTO();
                m.monthNum  = mi;
                m.monthName = mName;
                m.monthAbbr = MONTH_ABBR[mi - 1];
                m.isCurrent = (mi == currMonthNum);
                m.isOff     = OFF_SEASON_MONTHS.contains(mName);

                Aqua_Watering_Schedule__c rec = monthRecMap.containsKey(mName)
                    ? monthRecMap.get(mName) : null;
                m.pct = (rec != null && rec.Run_Time_Pct__c != null) ? rec.Run_Time_Pct__c : 0;

                String cellCls = 'month-cell';
                if (m.isOff) {
                    cellCls += ' off';
                } else if (m.pct <= 50) {
                    cellCls += ' low';
                } else if (m.pct <= 80) {
                    cellCls += ' medium';
                } else {
                    cellCls += ' high';
                }
                if (m.isCurrent) cellCls += ' current';
                m.cellClass = cellCls;
                m.pctLabel  = m.isOff ? '—' : (m.pct != null ? m.pct.intValue() + '%' : '—');
                months.add(m);
            }
            dto.months = months;

            // Current month details
            Decimal currPct = 0;
            String adjBy = '';
            if (monthRecMap.containsKey(currMonth)) {
                Aqua_Watering_Schedule__c cur = monthRecMap.get(currMonth);
                currPct = cur.Run_Time_Pct__c != null ? cur.Run_Time_Pct__c : 0;
                if (cur.LastModifiedById != null && wateringUserMap.containsKey(cur.LastModifiedById)) {
                    User adjustedByUser = wateringUserMap.get(cur.LastModifiedById);
                    if (adjustedByUser != null) {
                        adjBy = adjustedByUser.Name + ' on '
                            + cur.LastModifiedDate.format('MMMM d, yyyy');
                        dto.lastAdjustedBy   = adjustedByUser.Name;
                        dto.lastAdjustedDate = cur.LastModifiedDate.format('MMMM d, yyyy');
                    }
                }
            }
            dto.currentMonthPct = currPct;
            dto.adjustedBy      = adjBy;
            dto.lastAdjustedBy  = dto.lastAdjustedBy != null ? dto.lastAdjustedBy : adjBy;
            dto.scheduleTypeOptions = new List<WateringOptionDto>();
            for (String scheduleType : new List<String>{ 'Seasonal Monthly', 'New Install Ramp' }) {
                WateringOptionDto opt = new WateringOptionDto();
                opt.label = scheduleType;
                opt.value = scheduleType;
                dto.scheduleTypeOptions.add(opt);
            }
            dto.frequencyOptions = new List<WateringOptionDto>();
            for (String freq : new List<String>{
                'Daily','Every Other Day','3x Per Week','2x Per Week','Weekly',
                'As Needed','3x/day','1x/day','3x/week','Other'
            }) {
                WateringOptionDto opt = new WateringOptionDto();
                opt.label = freq;
                opt.value = freq;
                dto.frequencyOptions.add(opt);
            }
            dto.programs = new List<WateringProgramDto>();
            dto.currentScheduleType = 'Seasonal Monthly';
            dto.currentScheduleKey = null;
            for (String programKey : programKeyOrder) {
                WateringProgramDto program = programByKey.get(programKey);
                dto.programs.add(program);
                if (program.isCurrent && program.scheduleType == 'Seasonal Monthly' && dto.currentScheduleKey == null) {
                    dto.currentScheduleKey = program.scheduleKey;
                }
            }
            if (dto.currentScheduleKey == null && !dto.programs.isEmpty()) {
                dto.currentScheduleKey = dto.programs[0].scheduleKey;
                dto.currentScheduleType = dto.programs[0].scheduleType;
            } else if (dto.currentScheduleKey != null) {
                for (WateringProgramDto program : dto.programs) {
                    if (program.scheduleKey == dto.currentScheduleKey) {
                        dto.currentScheduleType = program.scheduleType;
                        dto.currentMonthPct = program.runTimePct;
                        break;
                    }
                }
            }
            String todayServiceDay = serviceDayName(Date.today());
            Set<String> cadenceLabels = new Set<String>();
            Integer communitiesToday = 0;
            for (Community__c communityRow : loadAquaCommunities()) {
                String cadenceLabel = formatServiceDays(communityRow.Service_Day__c);
                if (cadenceLabel != 'No service days set') cadenceLabels.add(cadenceLabel);
                if (serviceDayIncludes(communityRow.Service_Day__c, todayServiceDay)) {
                    communitiesToday++;
                }
            }
            List<String> orderedCadences = new List<String>();
            orderedCadences.addAll(cadenceLabels);
            orderedCadences.sort();
            String cadenceSuffix = orderedCadences.isEmpty()
                ? '.'
                : ' · Active cadences: ' + String.join(orderedCadences, ', ') + '.';
            if (communitiesToday > 0) {
                dto.serviceDayNote = 'Community.Service_Day__c drives the live schedule. '
                    + communitiesToday + ' communities are tagged for '
                    + todayServiceDay + cadenceSuffix;
            } else {
                dto.serviceDayNote = 'Community.Service_Day__c drives the live schedule. 0 Aqua communities are tagged for '
                    + todayServiceDay + cadenceSuffix;
            }

            // Affected lots (active on-site)
            dto.affectedLots = [
                SELECT COUNT() FROM Lot__c
                WHERE Aqua_Add_On__c > 0 AND Lot_Status__c != 'Closed'
            ];

            // History — all months for current year
            List<WateringHistRow> hist = new List<WateringHistRow>();
            for (Aqua_Watering_Schedule__c r : recs) {
                WateringHistRow hr = new WateringHistRow();
                hr.monthLabel    = r.Month__c != null ? r.Month__c : '';
                hr.scheduledPct  = r.Run_Time_Pct__c != null ? r.Run_Time_Pct__c : 0;
                hr.actualAvgPct  = 0; // Would require aggregating closed check ticket actual durations
                hr.adjustedBy    = '';
                hr.dateSet       = r.LastModifiedDate != null ? r.LastModifiedDate.format('M/d/yyyy') : '';
                if (r.LastModifiedById != null && wateringUserMap.containsKey(r.LastModifiedById)) {
                    User historyUser = wateringUserMap.get(r.LastModifiedById);
                    if (historyUser != null) {
                        hr.adjustedBy = historyUser.Name;
                    }
                }
                hist.add(hr);
            }
            dto.history = hist;

            return dto;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getWateringData', null, e.getMessage());
            throw new AuraHandledException('Unable to load watering data: ' + e.getMessage());
        }
    }

    // =========================================================================
    // 9. CLOSEOUT QUEUE TAB
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static List<CloseoutTicketDTO> getCloseoutQueue() {
        try {
            List<CloseoutTicketDTO> result = new List<CloseoutTicketDTO>();
            Datetime now = Datetime.now();

            // Open install tickets
            List<Aqua_Install_Ticket__c> installs = [
                SELECT Id, Name, Community__r.Name, FM_Assignment__r.Name,
                       Scheduled_Date__c, Status__c, CreatedDate,
                       Device_Installed__c, Timer_Tested__c, Coverage_Verified__c,
                       Photos_Uploaded__c, Closeout_Notes__c, Inventory_Recorded__c
                FROM Aqua_Install_Ticket__c
                WHERE Status__c = 'Open'
                ORDER BY CreatedDate ASC
            ];
            for (Aqua_Install_Ticket__c t : installs) {
                CloseoutTicketDTO dto = new CloseoutTicketDTO();
                dto.id               = t.Id;
                dto.lotName          = t.Name;
                dto.communityName    = t.Community__c != null ? t.Community__r.Name : '';
                dto.techName         = t.FM_Assignment__c != null ? t.FM_Assignment__r.Name : 'Unassigned';
                dto.ticketType       = 'Install';
                dto.scheduledDateLabel = t.Scheduled_Date__c != null ? formatDate(t.Scheduled_Date__c) : '';
                dto.scheduledDate      = dto.scheduledDateLabel;
                dto.issues             = '';
                dto.issuesFound        = dto.issues;
                // Use actual checkbox fields created in Deploy 2
                dto.isDeviceInstalled  = t.Device_Installed__c == true;
                dto.isTimerTested      = t.Timer_Tested__c == true;
                dto.isCoverageVerified = t.Coverage_Verified__c == true;
                dto.isPhotosUploaded   = t.Photos_Uploaded__c == true;
                dto.isCloseoutNotes    = t.Closeout_Notes__c != null && t.Closeout_Notes__c.trim() != '';
                dto.isInventoryRecorded = t.Inventory_Recorded__c == true;
                dto.isCloseoutReady    = dto.isDeviceInstalled && dto.isTimerTested
                    && dto.isCoverageVerified && dto.isPhotosUploaded
                    && dto.isCloseoutNotes && dto.isInventoryRecorded;
                dto.pendingHrs         = t.CreatedDate != null
                    ? (now.getTime() - t.CreatedDate.getTime()) / 3600000.0 : 0;
                dto.pendingLabel       = dto.pendingHrs.intValue() + ' hrs pending';
                dto.ageLabel           = dto.pendingLabel;
                dto.cardClass          = dto.pendingHrs > 8 ? 'alert' : 'warn';
                dto.cardChipClass      = dto.pendingHrs > 8 ? 'chip cr' : 'chip ca';
                dto.ageChipCss         = dto.cardChipClass;
                result.add(dto);
            }

            // Open check tickets (no billing reason = routine check pending closeout)
            List<Aqua_Check_Ticket__c> checks = [
                SELECT Id, Name, Community__r.Name, Assigned_To__r.Name,
                       Scheduled_Date__c, Status__c, Check_Notes__c, CreatedDate,
                       Turf_Condition_Score__c, Landscape_Score__c, System_Tampered__c
                FROM Aqua_Check_Ticket__c
                WHERE Status__c = 'Open'
                  AND Billing_Reason_Code__c = null
                ORDER BY CreatedDate ASC
            ];
            for (Aqua_Check_Ticket__c t : checks) {
                CloseoutTicketDTO dto = new CloseoutTicketDTO();
                dto.id               = t.Id;
                dto.lotName          = t.Name;
                dto.communityName    = t.Community__c != null ? t.Community__r.Name : '';
                dto.techName         = t.Assigned_To__c != null ? t.Assigned_To__r.Name : 'Unassigned';
                dto.ticketType       = 'Check';
                dto.scheduledDateLabel = t.Scheduled_Date__c != null ? formatDate(t.Scheduled_Date__c) : '';
                dto.scheduledDate      = dto.scheduledDateLabel;
                List<String> issueList = new List<String>();
                if (t.System_Tampered__c == true) issueList.add('Tamper detected');
                if (t.Turf_Condition_Score__c != null && t.Turf_Condition_Score__c < 3)
                    issueList.add('Low turf score');
                if (t.Landscape_Score__c != null && t.Landscape_Score__c < 3)
                    issueList.add('Low landscape score');
                dto.issues             = String.join(issueList, '; ');
                dto.issuesFound        = dto.issues;
                dto.isDeviceInstalled  = true; // Check tickets assume device exists
                dto.isTimerTested      = true;
                dto.isCoverageVerified = t.Turf_Condition_Score__c != null;
                dto.isPhotosUploaded   = false;
                dto.isCloseoutNotes    = t.Check_Notes__c != null && t.Check_Notes__c.trim() != '';
                dto.isInventoryRecorded = true;
                dto.isCloseoutReady    = dto.isCoverageVerified && dto.isCloseoutNotes;
                dto.pendingHrs         = t.CreatedDate != null
                    ? (now.getTime() - t.CreatedDate.getTime()) / 3600000.0 : 0;
                dto.pendingLabel       = dto.pendingHrs.intValue() + ' hrs pending';
                dto.ageLabel           = dto.pendingLabel;
                dto.cardClass          = dto.pendingHrs > 8 ? 'alert' : 'warn';
                dto.cardChipClass      = dto.pendingHrs > 8 ? 'chip cr' : 'chip ca';
                dto.ageChipCss         = dto.cardChipClass;
                result.add(dto);
            }

            return result;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getCloseoutQueue', null, e.getMessage());
            throw new AuraHandledException('Unable to load closeout queue: ' + e.getMessage());
        }
    }

    // =========================================================================
    // 10. END-OF-SEASON PICKUP TAB
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static PickupPageDTO getPickupData() {
        try {
            PickupPageDTO dto = new PickupPageDTO();
            Date today = Date.today();

            // Season
            Integer[] seasonMetrics = getSeasonMetrics(today);
            dto.seasonYear            = today.year();
            dto.seasonDay             = seasonMetrics[0];
            dto.seasonTotal           = SEASON_TOTAL_DAYS;
            dto.seasonDaysUntilRetrieve = seasonMetrics[1];
            Date seasonEnd = Date.newInstance(today.year(), SEASON_END_MONTH, SEASON_END_DAY);
            dto.seasonSubLabel = 'Apr 1, ' + today.year() + ' → Oct 31, ' + today.year();

            // Active lots
            dto.activeLots = [
                SELECT COUNT() FROM Lot__c
                WHERE Aqua_Add_On__c > 0 AND Lot_Status__c != 'Closed'
            ];

            // Pending pickup count
            dto.pendingPickups = [
                SELECT COUNT() FROM Aqua_Pickup_Ticket__c
                WHERE Status__c = 'Open'
            ];

            // Closed pickups this season
            dto.closedPickups = [
                SELECT COUNT() FROM Aqua_Pickup_Ticket__c
                WHERE Status__c = 'Closed'
                  AND Closed_Date__c >= :Date.newInstance(today.year(), SEASON_START_MONTH, SEASON_START_DAY)
            ];

            // Pickup rows
            List<Aqua_Pickup_Ticket__c> pickups = [
                SELECT Id, Name, Community__r.Name, Assigned_To__r.Name,
                       Scheduled_Date__c, Status__c, Billing_Reason_Code__c,
                       CreatedDate, Closed_Date__c,
                       Controllers_Retrieved__c, Heads_Retrieved__c, Pickup_Notes__c
                FROM Aqua_Pickup_Ticket__c
                WHERE Status__c = 'Open'
                ORDER BY CreatedDate ASC
            ];

            // Get install dates per community to compute days-on-site
            Set<Id> communityIds = new Set<Id>();
            for (Aqua_Pickup_Ticket__c p : pickups) {
                if (p.Community__c != null) communityIds.add(p.Community__c);
            }
            Map<Id,Date> communityInstallDate = new Map<Id,Date>();
            for (AggregateResult ar : [
                SELECT Community__c cid, MIN(Scheduled_Date__c) minDate
                FROM Aqua_Install_Ticket__c
                WHERE Status__c = 'Closed'
                  AND Community__c IN :communityIds
                GROUP BY Community__c
            ]) {
                Id cid = (Id) ar.get('cid');
                Date mn = ar.get('minDate') != null ? (Date) ar.get('minDate') : null;
                if (mn != null) communityInstallDate.put(cid, mn);
            }

            List<PickupRow> pRows = new List<PickupRow>();
            for (Aqua_Pickup_Ticket__c p : pickups) {
                PickupRow row = new PickupRow();
                row.id            = p.Id;
                row.lotName       = p.Name;
                row.communityName = p.Community__c != null ? p.Community__r.Name : '';
                row.lotCommunity  = row.lotName + ' · ' + row.communityName;
                row.closedBy      = ''; // Not on pickup ticket schema
                Date installDate  = communityInstallDate.containsKey(p.Community__c)
                    ? communityInstallDate.get(p.Community__c) : null;
                row.installDateLabel = installDate != null ? formatDate(installDate) : '';
                row.installDate      = row.installDateLabel;
                row.daysOnSite       = installDate != null ? installDate.daysBetween(today) : 0;
                row.techName      = p.Assigned_To__c != null ? p.Assigned_To__r.Name : 'Unassigned';
                // Determine status
                if (p.Scheduled_Date__c != null) {
                    row.statusLabel    = 'Scheduled ' + formatDate(p.Scheduled_Date__c);
                    row.statusChipClass = 'chip cb2';
                } else {
                    row.statusLabel    = 'Unassigned';
                    row.statusChipClass = 'chip ca';
                }
                // Variance: if retrieved < expected (simple check on controllers)
                Boolean hasVariance = (p.Controllers_Retrieved__c != null
                    && p.Controllers_Retrieved__c == 0);
                row.hasVariance   = hasVariance;
                row.rowBg         = hasVariance ? '#fef9f9' : '';
                pRows.add(row);
            }
            dto.pickupRows = pRows;

            return dto;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getPickupData', null, e.getMessage());
            throw new AuraHandledException('Unable to load pickup data: ' + e.getMessage());
        }
    }

    // =========================================================================
    // SHARED PRIVATE HELPERS (used across multiple @AuraEnabled methods)
    // =========================================================================

    private static List<SameDayRow> buildSameDayRows(Integer maxRows) {
        List<SameDayRow> rows = new List<SameDayRow>();
        List<Aqua_Check_Ticket__c> tickets = [
            SELECT Id, Name, Community__r.Name, Assigned_To__r.Name,
                   Billing_Reason_Code__c, Check_Notes__c, CreatedDate
            FROM Aqua_Check_Ticket__c
            WHERE Status__c = 'Open'
              AND Billing_Reason_Code__c != null
            ORDER BY CreatedDate DESC
            LIMIT :maxRows
        ];
        for (Aqua_Check_Ticket__c t : tickets) {
            SameDayRow r = new SameDayRow();
            r.id            = t.Id;
            r.lotName       = t.Name;
            r.communityName = t.Community__c != null ? t.Community__r.Name : '';
            r.issue         = t.Check_Notes__c != null ? t.Check_Notes__c : 'See ticket';
            String brc = t.Billing_Reason_Code__c;
            r.sourceType = brc != null && brc.startsWith('(A)') ? 'Missing Material'
                         : brc != null && brc.startsWith('(B)') ? 'Warranty'
                         : brc != null && brc.startsWith('(C)') ? 'Additional Coverage'
                         : 'Field';
            r.techName  = t.Assigned_To__c != null ? t.Assigned_To__r.Name : 'Unassigned';
            // SLA: hours since creation
            Decimal hrs = t.CreatedDate != null
                ? (Datetime.now().getTime() - t.CreatedDate.getTime()) / 3600000.0 : 0;
            r.slaLabel = hrs.setScale(1) + ' hrs';
            r.slaChip  = hrs > 4 ? 'chip cr' : (hrs > 2 ? 'chip ca' : 'chip cg');
            r.timeIn   = t.CreatedDate != null ? t.CreatedDate.format('h:mm a') : '';
            rows.add(r);
        }
        return rows;
    }

    private static List<TechStatusRow> buildTechStatusRows(List<Community__c> communities) {
        List<TechStatusRow> rows = new List<TechStatusRow>();
        Date today = Date.today();
        String todayServiceDay = serviceDayName(today);
        Set<Id> communityIds = new Set<Id>();
        Set<Id> fmUserIds = new Set<Id>();
        for (Community__c communityRow : communities) {
            communityIds.add(communityRow.Id);
            Id fmId = resolveCommunityFmId(communityRow);
            if (fmId != null) fmUserIds.add(fmId);
        }
        Map<Id, Integer> lotCountMap = buildActiveAquaLotCountByCommunity(communityIds);
        Map<Id, User> fmUsers = fmUserIds.isEmpty()
            ? new Map<Id, User>()
            : new Map<Id, User>([
                SELECT Id, Name
                FROM User
                WHERE Id IN :fmUserIds
            ]);
        Map<Id, Integer> fmCommunitiesToday = new Map<Id, Integer>();
        Map<Id, Integer> fmLotsToday = new Map<Id, Integer>();
        for (Community__c communityRow : communities) {
            Id fmId = resolveCommunityFmId(communityRow);
            if (fmId == null || !serviceDayIncludes(communityRow.Service_Day__c, todayServiceDay)) continue;
            fmCommunitiesToday.put(fmId, (fmCommunitiesToday.containsKey(fmId) ? fmCommunitiesToday.get(fmId) : 0) + 1);
            Integer activeLots = lotCountMap.containsKey(communityRow.Id) ? lotCountMap.get(communityRow.Id) : 0;
            fmLotsToday.put(fmId, (fmLotsToday.containsKey(fmId) ? fmLotsToday.get(fmId) : 0) + activeLots);
        }

        for (Id fmId : fmUsers.keySet()) {
            TechStatusRow r = new TechStatusRow();
            r.id = (String) fmId;
            r.techName = fmUsers.get(fmId).Name;
            r.routeLabel = todayServiceDay;
            r.stopsPlanned = fmCommunitiesToday.containsKey(fmId) ? fmCommunitiesToday.get(fmId) : 0;
            r.stopsDone = 0;
            r.stopsRemaining = r.stopsPlanned - r.stopsDone;

            if (r.stopsPlanned == 0) {
                r.statusLabel = 'No watering today';
                r.statusChip = 'chip cgr';
            } else {
                r.statusLabel = 'Communities scheduled';
                r.statusChip = 'chip caqua';
            }

            Integer activeLots = fmLotsToday.containsKey(fmId) ? fmLotsToday.get(fmId) : 0;
            r.locationLabel = r.stopsPlanned == 0
                ? 'No communities tagged for ' + todayServiceDay
                : activeLots + ' active Aqua lots across the scheduled communities';
            rows.add(r);
        }
        return rows;
    }

    private static List<AlertRow> buildInventoryAlerts() {
        List<AlertRow> alerts = new List<AlertRow>();
        Map<String,Integer> thresholds = getReorderThresholds();

        // Shop quantities
        Map<String,Decimal> shopQtyMap = new Map<String,Decimal>();
        for (AggregateResult ar : [
            SELECT Item_Type__c itype, SUM(Quantity__c) total
            FROM Aqua_Inventory__c
            WHERE Location_Type__c = 'Shop'
            GROUP BY Item_Type__c
        ]) {
            String itype = (String) ar.get('itype');
            Decimal qty  = ar.get('total') != null ? (Decimal) ar.get('total') : 0;
            shopQtyMap.put(itype, qty);
        }

        for (String itype : thresholds.keySet()) {
            Integer threshold = thresholds.get(itype);
            Decimal onHand    = shopQtyMap.containsKey(itype) ? shopQtyMap.get(itype) : 0;
            if (onHand < threshold) {
                AlertRow a = new AlertRow();
                a.id          = itype;
                a.label       = itype;
                a.description = 'Only ' + onHand.intValue() + ' in shop — reorder threshold: ' + threshold;
                a.severity    = 'warn';
                a.itemName    = itype;
                alerts.add(a);
            }
        }
        return alerts;
    }

    private static List<AlertRow> buildTamperFlags() {
        List<AlertRow> flags = new List<AlertRow>();
        List<Aqua_Check_Ticket__c> checks = [
            SELECT Id, Name, Community__r.Name, System_Tampered__c,
                   Turf_Condition_Score__c, Landscape_Score__c
            FROM Aqua_Check_Ticket__c
            WHERE Status__c = 'Open'
              AND (System_Tampered__c = true
                   OR Turf_Condition_Score__c < 3
                   OR Landscape_Score__c < 3)
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
        for (Aqua_Check_Ticket__c t : checks) {
            AlertRow a = new AlertRow();
            a.id = t.Id;
            a.label = t.Name
                + (t.Community__c != null ? ' · ' + t.Community__r.Name : '');
            List<String> issues = new List<String>();
            if (t.System_Tampered__c == true) issues.add('Tamper detected');
            if (t.Turf_Condition_Score__c != null && t.Turf_Condition_Score__c < 3)
                issues.add('Turf score: ' + t.Turf_Condition_Score__c.intValue());
            if (t.Landscape_Score__c != null && t.Landscape_Score__c < 3)
                issues.add('Landscape score: ' + t.Landscape_Score__c.intValue());
            a.description    = String.join(issues, ' · ');
            a.severity       = t.System_Tampered__c == true ? 'alert' : 'warn';
            a.lotName        = t.Name + (t.Community__c != null ? ' · ' + t.Community__r.Name : '');
            a.flagDescription = a.description;
            flags.add(a);
        }
        return flags;
    }

    private static List<ActivityRow> buildActivityRows() {
        List<ActivityRow> rows = new List<ActivityRow>();
        // Query recent Task records on Aqua objects as proxy for activity feed
        List<Task> tasks = [
            SELECT Id, Subject, Description, CreatedDate, CreatedById, CreatedBy.Name
            FROM Task
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        Integer idx = 0;
        for (Task t : tasks) {
            ActivityRow r = new ActivityRow();
            r.id          = t.Id;
            r.authorName  = t.CreatedBy != null ? t.CreatedBy.Name : 'System';
            r.initials    = getInitialsFromFullName(r.authorName);
            r.timeAgo     = t.CreatedDate != null ? timeAgoLabel(t.CreatedDate) : '';
            r.body        = t.Subject != null ? t.Subject : '';
            r.avatarBg    = avatarColor(idx++);
            r.avatarStyle = 'background:' + r.avatarBg;
            rows.add(r);
        }
        return rows;
    }

    // =========================================================================
    // ACTION METHODS (non-cacheable DML)
    // =========================================================================

    /**
     * Apply a new run-time percentage to all Aqua_Watering_Schedule__c records
     * for the current month and current year.
     */
    @AuraEnabled
    public static void applyRunTimePct(Integer newPct) {
        try {
            if (newPct == null || newPct < 0 || newPct > 100) {
                throw new AuraHandledException('Run-time percentage must be between 0 and 100.');
            }
            String monthName = currentMonthName();
            Integer yr = Date.today().year();
            List<Aqua_Watering_Schedule__c> recs = [
                SELECT Id, Run_Time_Pct__c
                FROM Aqua_Watering_Schedule__c
                WHERE Month__c = :monthName
                  AND Effective_Year__c = :yr
            ];
            if (recs.isEmpty()) {
                throw new AuraHandledException(
                    'No watering schedule records found for ' + monthName + ' ' + yr + '.');
            }
            for (Aqua_Watering_Schedule__c r : recs) {
                r.Run_Time_Pct__c = newPct;
            }
            update recs;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'applyRunTimePct', null, e.getMessage());
            throw new AuraHandledException('Failed to apply run-time %: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateWateringSchedule(
        String scheduleType,
        String monthName,
        Integer weekNumber,
        String runFrequency,
        Integer runDurationMin,
        Integer runTimePct
    ) {
        try {
            if (String.isBlank(scheduleType) || String.isBlank(monthName)) {
                throw new AuraHandledException('Schedule type and period are required.');
            }
            if (runTimePct == null || runTimePct < 0 || runTimePct > 100) {
                throw new AuraHandledException('Run-time percentage must be between 0 and 100.');
            }
            Integer yr = Date.today().year();
            List<Aqua_Watering_Schedule__c> recs;
            if (weekNumber == null) {
                recs = [
                    SELECT Id, Run_Frequency__c, Run_Duration_Min__c, Run_Time_Pct__c
                    FROM Aqua_Watering_Schedule__c
                    WHERE Effective_Year__c = :yr
                      AND Schedule_Type__c = :scheduleType
                      AND Month__c = :monthName
                ];
            } else {
                recs = [
                    SELECT Id, Run_Frequency__c, Run_Duration_Min__c, Run_Time_Pct__c
                    FROM Aqua_Watering_Schedule__c
                    WHERE Effective_Year__c = :yr
                      AND Schedule_Type__c = :scheduleType
                      AND Month__c = :monthName
                      AND Week_Number__c = :weekNumber
                ];
            }
            if (recs.isEmpty()) {
                throw new AuraHandledException('No watering schedule records found for the selected schedule.');
            }
            for (Aqua_Watering_Schedule__c r : recs) {
                r.Run_Time_Pct__c = runTimePct;
                r.Run_Frequency__c = runFrequency;
                r.Run_Duration_Min__c = runDurationMin;
            }
            update recs;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'updateWateringSchedule', null, e.getMessage());
            throw new AuraHandledException('Failed to update watering schedule: ' + e.getMessage());
        }
    }

    /**
     * Approve closeout — sets Status__c = 'Closed' on install or check ticket.
     * Validates checklist fields before closing.
     */
    @AuraEnabled
    public static void approveCloseout(Id ticketId, String ticketType) {
        try {
            if (ticketId == null || ticketType == null) {
                throw new AuraHandledException('Ticket ID and type are required.');
            }
            if (ticketType == 'Install') {
                Aqua_Install_Ticket__c t = [
                    SELECT Id, Status__c, Device_Installed__c, Timer_Tested__c,
                           Coverage_Verified__c, Photos_Uploaded__c,
                           Closeout_Notes__c, Inventory_Recorded__c
                    FROM Aqua_Install_Ticket__c
                    WHERE Id = :ticketId
                    LIMIT 1
                ];
                if (t.Device_Installed__c != true)
                    throw new AuraHandledException('Device installation not confirmed. Cannot approve closeout.');
                if (t.Timer_Tested__c != true)
                    throw new AuraHandledException('Timer not tested. Cannot approve closeout.');
                if (t.Coverage_Verified__c != true)
                    throw new AuraHandledException('Coverage not verified. Cannot approve closeout.');
                if (t.Photos_Uploaded__c != true)
                    throw new AuraHandledException('Photos not uploaded. Cannot approve closeout.');
                if (t.Closeout_Notes__c == null || t.Closeout_Notes__c.trim() == '')
                    throw new AuraHandledException('Closeout notes are required before approval.');
                if (t.Inventory_Recorded__c != true)
                    throw new AuraHandledException('Inventory not recorded. Cannot approve closeout.');
                t.Status__c    = 'Closed';
                t.Closed_Date__c = Date.today();
                update t;

            } else if (ticketType == 'Check') {
                Aqua_Check_Ticket__c t = [
                    SELECT Id, Status__c, Check_Notes__c, Turf_Condition_Score__c
                    FROM Aqua_Check_Ticket__c
                    WHERE Id = :ticketId
                    LIMIT 1
                ];
                if (t.Check_Notes__c == null || t.Check_Notes__c.trim() == '')
                    throw new AuraHandledException('Check notes are required before approval.');
                t.Status__c    = 'Closed';
                t.Closed_Date__c = Date.today();
                update t;

            } else {
                throw new AuraHandledException('Unknown ticket type: ' + ticketType);
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'approveCloseout', ticketId, e.getMessage());
            throw new AuraHandledException('Failed to approve closeout: ' + e.getMessage());
        }
    }

    /**
     * Return ticket as NFI (No Further Issues).
     * Sets Check_Notes__c to 'Returned as NFI' on check ticket,
     * or Close_Notes__c on install ticket.
     */
    @AuraEnabled
    public static void returnNfi(Id ticketId, String ticketType) {
        try {
            if (ticketId == null || ticketType == null) {
                throw new AuraHandledException('Ticket ID and type are required.');
            }
            if (ticketType == 'Install') {
                Aqua_Install_Ticket__c t = [
                    SELECT Id, Close_Notes__c FROM Aqua_Install_Ticket__c WHERE Id = :ticketId LIMIT 1
                ];
                t.Close_Notes__c = 'Returned as NFI';
                update t;
            } else if (ticketType == 'Check') {
                Aqua_Check_Ticket__c t = [
                    SELECT Id, Check_Notes__c FROM Aqua_Check_Ticket__c WHERE Id = :ticketId LIMIT 1
                ];
                t.Check_Notes__c = 'Returned as NFI';
                update t;
            } else {
                throw new AuraHandledException('Unknown ticket type: ' + ticketType);
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'returnNfi', ticketId, e.getMessage());
            throw new AuraHandledException('Failed to return as NFI: ' + e.getMessage());
        }
    }

    /**
     * Create a same-day repair check ticket.
     * Requires Billing_Reason_Code__c to flag it as a same-day ticket.
     */
    @AuraEnabled
    public static Id createSameDayRepair(String lotName, String issue, String source) {
        try {
            if (String.isBlank(lotName)) {
                throw new AuraHandledException('Lot name is required.');
            }
            if (String.isBlank(issue)) {
                throw new AuraHandledException('Issue description is required.');
            }
            Aqua_Check_Ticket__c ticket = new Aqua_Check_Ticket__c(
                Scheduled_Date__c      = Date.today(),
                Status__c              = 'Open',
                Check_Notes__c         = issue,
                Billing_Reason_Code__c = '(A) Missing Material (Stolen)'
            );
            insert ticket;
            return ticket.Id;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'createSameDayRepair', null, e.getMessage());
            throw new AuraHandledException('Failed to create same-day repair: ' + e.getMessage());
        }
    }

    // =========================================================================
    // 11. PICKUP RECONCILIATION
    // =========================================================================

    public class ReconciliationDTO {
        @AuraEnabled public String lotName;
        @AuraEnabled public List<ReconciliationRow> rows;
        @AuraEnabled public Boolean isClean;
        @AuraEnabled public String cmName;
        @AuraEnabled public Decimal estimatedBill;
    }

    public class ReconciliationRow {
        @AuraEnabled public String itemType;
        @AuraEnabled public Decimal expectedQty;
        @AuraEnabled public Decimal retrievedQty;
        @AuraEnabled public Decimal varianceQty;
        @AuraEnabled public String varianceLabel;
        @AuraEnabled public String varianceChip;
        @AuraEnabled public Boolean hasMissing;
        @AuraEnabled public Decimal missingQty;
        @AuraEnabled public String action;
    }

    @AuraEnabled(cacheable=true)
    public static ReconciliationDTO getPickupReconciliation(Id pickupTicketId) {
        if (pickupTicketId == null) return null;
        try {
            ReconciliationDTO result = new ReconciliationDTO();
            result.rows        = new List<ReconciliationRow>();
            result.isClean     = true;
            result.cmName      = '';
            result.estimatedBill = 0;

            Aqua_Pickup_Ticket__c pt = [
                SELECT Id, Name, Community__c, Community__r.Name,
                       Device_Retrieved__c, Inventory_Reconciled__c,
                       Variance_Controllers__c, Variance_Heads__c
                FROM Aqua_Pickup_Ticket__c
                WHERE Id = :pickupTicketId
                LIMIT 1
            ];

            result.lotName = pt.Name;
            // CM name: look up via Community__c custom object CM_Contact__c field
            if (pt.Community__c != null) {
                List<Community__c> comms = [
                    SELECT Id, CM_Contact__r.Name
                    FROM Community__c
                    WHERE Id = :pt.Community__c
                    LIMIT 1
                ];
                if (!comms.isEmpty() && comms[0].CM_Contact__c != null) {
                    result.cmName = comms[0].CM_Contact__r.Name != null ? comms[0].CM_Contact__r.Name : '';
                }
            }

            // Expected on-site quantities: aggregate all On-Site inventory
            // (Community__c field not available on Aqua_Inventory__c — use lot-based filter via Employee__c TBD)
            Map<String,Decimal> expectedMap = new Map<String,Decimal>();
            for (AggregateResult ar : [
                SELECT Item_Type__c itype, SUM(Quantity__c) total
                FROM Aqua_Inventory__c
                WHERE Location_Type__c = 'On-Site'
                GROUP BY Item_Type__c
            ]) {
                String itype = (String) ar.get('itype');
                Decimal qty  = ar.get('total') != null ? (Decimal) ar.get('total') : 0;
                if (itype != null) expectedMap.put(itype, qty);
            }

            // Retrieve variances and unit costs from master inventory
            Map<String,Decimal> unitCostMap = new Map<String,Decimal>();
            for (Aqua_Master_Inventory__c mi : [
                SELECT Item_Type__c, Unit_Cost__c
                FROM Aqua_Master_Inventory__c
                WHERE Unit_Cost__c != null
            ]) {
                if (mi.Item_Type__c != null) unitCostMap.put(mi.Item_Type__c, mi.Unit_Cost__c);
            }

            // Build reconciliation rows
            // For simplicity, Controllers and Heads use the Variance_* fields on the pickup ticket
            // Other items use expectedMap vs 0 retrieved (no individual retrieved counts — schema limitation)
            Boolean hasAnyVariance = false;
            for (String itype : expectedMap.keySet()) {
                ReconciliationRow row = new ReconciliationRow();
                row.itemType    = itype;
                row.expectedQty = expectedMap.get(itype);
                // Use Variance fields for known items; default 0 variance for others
                Decimal varQty = 0;
                if (itype.equalsIgnoreCase('Controllers') && pt.Variance_Controllers__c != null) {
                    varQty = pt.Variance_Controllers__c;
                } else if (itype.equalsIgnoreCase('Heads') && pt.Variance_Heads__c != null) {
                    varQty = pt.Variance_Heads__c;
                }
                row.retrievedQty = row.expectedQty - varQty;
                row.varianceQty  = varQty;
                row.hasMissing   = varQty > 0;
                row.missingQty   = varQty;
                row.varianceLabel = varQty == 0 ? '✓ 0' : '−' + varQty.intValue();
                row.varianceChip  = varQty == 0 ? 'chip cg' : 'chip cr';
                row.action        = varQty > 0 ? 'Flag billing' : '';
                if (varQty > 0) {
                    hasAnyVariance = true;
                    Decimal unitCost = unitCostMap.containsKey(itype) ? unitCostMap.get(itype) : 0;
                    result.estimatedBill += varQty * unitCost;
                }
                result.rows.add(row);
            }
            result.isClean = !hasAnyVariance;
            return result;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'getPickupReconciliation', pickupTicketId, e.getMessage());
            throw new AuraHandledException('Unable to load reconciliation: ' + e.getMessage());
        }
    }

    /**
     * Bulk end-of-season retrieve — delegates to AquaPickupService.
     */
    @AuraEnabled
    public static void bulkRetrieveEndOfSeason() {
        try {
            AquaPickupService.bulkRetrieve();
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'bulkRetrieveEndOfSeason', null, e.getMessage());
            throw new AuraHandledException('Bulk retrieve failed: ' + e.getMessage());
        }
    }

    /**
     * Reassign a pickup ticket to a different tech.
     */
    @AuraEnabled
    public static void reassignPickup(Id pickupTicketId, Id newTechId) {
        try {
            AquaPickupService.reassignPickup(pickupTicketId, newTechId);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'reassignPickup', pickupTicketId, e.getMessage());
            throw new AuraHandledException('Reassign failed: ' + e.getMessage());
        }
    }

    /**
     * Submit route re-optimization request — delegates to AquaRouteService.
     */
    @AuraEnabled
    public static void reoptimizeRoutes() {
        try {
            AquaRouteService.reoptimize();
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'reoptimizeRoutes', null, e.getMessage());
            throw new AuraHandledException('Route optimization failed: ' + e.getMessage());
        }
    }

    /**
     * Add a shop stop for a tech — delegates to AquaRouteService.
     */
    @AuraEnabled
    public static void addShopStop(Id techId, String notes) {
        try {
            AquaRouteService.addShopStop(techId, notes);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'addShopStop', techId, e.getMessage());
            throw new AuraHandledException('Add shop stop failed: ' + e.getMessage());
        }
    }

    /**
     * Mark a check ticket as resolved (Status = Closed).
     */
    @AuraEnabled
    public static void resolveTicket(Id ticketId) {
        try {
            if (ticketId == null) {
                throw new AuraHandledException('Ticket ID is required.');
            }
            Aqua_Check_Ticket__c t = [
                SELECT Id, Status__c, Check_Notes__c
                FROM Aqua_Check_Ticket__c
                WHERE Id = :ticketId
                LIMIT 1
            ];
            if (t.Check_Notes__c == null || t.Check_Notes__c.trim() == '') {
                throw new AuraHandledException(
                    'Check notes are required before resolving a ticket.');
            }
            t.Status__c    = 'Closed';
            t.Closed_Date__c = Date.today();
            update t;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ErrorLogService.log('AquaConsoleController', 'resolveTicket', ticketId, e.getMessage());
            throw new AuraHandledException('Failed to resolve ticket: ' + e.getMessage());
        }
    }
}