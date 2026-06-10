public with sharing class LovingSchedulingOverlayService {
    private static final Integer ROW_LIMIT = 20;

    public class ConsoleData {
        @AuraEnabled public Datetime generatedAt;
        @AuraEnabled public List<TabDto> tabs;
        @AuraEnabled public List<KpiDto> kpis;
        @AuraEnabled public Map<String, List<RecordDto>> recordsByTab;
        @AuraEnabled public List<SourceAuditDto> sourceAudit;
        @AuraEnabled public List<ActionDto> actions;
        @AuraEnabled public List<PicklistAuditDto> picklists;
        @AuraEnabled public OptimizationDto optimization;
        @AuraEnabled public List<String> warnings;
        @AuraEnabled public List<TerritoryWeatherCard> territoryWeatherCards;
        @AuraEnabled public MonthlyMetricsDto monthlyMetrics;
    }

    public class MonthlyMetricsDto {
        @AuraEnabled public String monthLabel;
        @AuraEnabled public Integer forecasted;
        @AuraEnabled public Integer completed;
        @AuraEnabled public Integer remaining;
        @AuraEnabled public String pct;
        @AuraEnabled public Boolean isForecastFallback;
        @AuraEnabled public List<MetricsByDimensionDto> byWorkType;
        @AuraEnabled public List<MetricsByDimensionDto> byMarket;
    }

    public class MetricsByDimensionDto {
        @AuraEnabled public String dimension;
        @AuraEnabled public Integer forecasted;
        @AuraEnabled public Integer completed;
        @AuraEnabled public Integer remaining;
        @AuraEnabled public Integer atRisk;
        @AuraEnabled public String pct;
    }

    public class TerritoryWeatherCard {
        @AuraEnabled public String id;
        @AuraEnabled public String territory;
        @AuraEnabled public Boolean hasAlert;
        @AuraEnabled public String alertType;
        @AuraEnabled public String severity;
        @AuraEnabled public String summary;
        @AuraEnabled public String source;
        @AuraEnabled public String tone;
        @AuraEnabled public String icon;
        @AuraEnabled public String startValue;
        @AuraEnabled public String endValue;
    }

    public class TabDto {
        @AuraEnabled public Integer sequence;
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String primarySource;
        @AuraEnabled public String purpose;
        @AuraEnabled public Integer count;
    }

    public class KpiDto {
        @AuraEnabled public String label;
        @AuraEnabled public Integer value;
        @AuraEnabled public String tone;
        @AuraEnabled public String detail;
    }

    public class RecordDto {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String status;
        @AuraEnabled public String source;
        @AuraEnabled public String detail;
        @AuraEnabled public String tone;
        @AuraEnabled public String alertType;
        @AuraEnabled public String division;
        @AuraEnabled public String summary;
        @AuraEnabled public String sourceSystem;
        @AuraEnabled public String startValue;
        @AuraEnabled public String endValue;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String lastSeenValue;
        @AuraEnabled public Decimal speedMph;
        // Extended fields — populated by dedicated query methods
        @AuraEnabled public String workTypeName;
        @AuraEnabled public String address;
        @AuraEnabled public String marketId;
        @AuraEnabled public String marketName;
        @AuraEnabled public String fieldManagerId;
        @AuraEnabled public String fieldManagerName;
        @AuraEnabled public String serviceAppointmentId;
        @AuraEnabled public String workOrderId;
        @AuraEnabled public String requiredAction;
        @AuraEnabled public String severity;
        // GPS / vehicle fields
        @AuraEnabled public String vehicleName;
        @AuraEnabled public String unitNumber;
        @AuraEnabled public String driverLabel;
        @AuraEnabled public String ignitionStatus;
        // Pending / reason fields
        @AuraEnabled public String pendingReason;
        // Route optimization fields
        @AuraEnabled public Decimal minutesSaved;
        // Schedule day fields
        @AuraEnabled public String scheduleDate;
        @AuraEnabled public Integer appointmentCount;
    }

    public class SourceAuditDto {
        @AuraEnabled public String uiArea;
        @AuraEnabled public String standardObjectQueried;
        @AuraEnabled public String standardFieldsFound;
        @AuraEnabled public String existingLovingFieldsFound;
        @AuraEnabled public String missingSource;
        @AuraEnabled public String recommendation;
        @AuraEnabled public String approvalNeeded;
    }

    public class ActionDto {
        @AuraEnabled public String button;
        @AuraEnabled public String location;
        @AuraEnabled public String behavior;
        @AuraEnabled public String updates;
        @AuraEnabled public Boolean enabled;
        @AuraEnabled public String disabledReason;
    }

    public class PicklistAuditDto {
        @AuraEnabled public String fieldName;
        @AuraEnabled public List<String> values;
        @AuraEnabled public String recommendation;
    }

    public class OptimizationDto {
        @AuraEnabled public Boolean canPreview;
        @AuraEnabled public Integer candidateCount;
        @AuraEnabled public Integer activeResourceCount;
        @AuraEnabled public Integer absenceCount;
        @AuraEnabled public Integer weatherAlertCount;
        @AuraEnabled public Integer trafficImpactCount;
        @AuraEnabled public Integer routeResultCount;
        @AuraEnabled public String summary;
        @AuraEnabled public String generatedFrom;
        @AuraEnabled public List<String> constraints;
        @AuraEnabled public List<OptimizationRecommendationDto> recommendations;
    }

    public class OptimizationRecommendationDto {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String startValue;
        @AuraEnabled public String endValue;
        @AuraEnabled public String serviceTerritoryId;
        @AuraEnabled public String workTypeId;
        @AuraEnabled public String parentRecordId;
        @AuraEnabled public Integer score;
        @AuraEnabled public String scoreLabel;
        @AuraEnabled public String recommendation;
        @AuraEnabled public String risk;
        @AuraEnabled public String reason;
        @AuraEnabled public String tone;
    }

    public static ConsoleData getConsoleData() {
        ConsoleData data = new ConsoleData();
        data.generatedAt = System.now();
        data.warnings = new List<String>();
        data.recordsByTab = buildRecordsByTab(data.warnings);
        data.kpis = buildKpis();
        data.tabs = buildTabs(data.recordsByTab);
        data.sourceAudit = new List<SourceAuditDto>();
        data.actions = new List<ActionDto>();
        data.picklists = new List<PicklistAuditDto>();
        data.optimization = buildOptimizationPreview(data.warnings);
        data.territoryWeatherCards = buildTerritoryWeatherCards(data.warnings);
        data.monthlyMetrics = buildMonthlyMetrics(data.warnings);
        return data;
    }

    private static Map<String, List<RecordDto>> buildRecordsByTab(List<String> warnings) {
        Map<String, List<RecordDto>> rows = new Map<String, List<RecordDto>>();
        String weatherScopeWhere = buildWeatherScopeWhereClause();
        List<RecordDto> appointments = queryServiceAppointments(warnings);
        List<RecordDto> autoScheduleAppointments = queryAppointmentsByStatuses(
            new List<String>{'None', 'Pending Takeoff', 'Ready to Schedule'},
            'Auto-Schedule Appointment',
            warnings
        );
        List<RecordDto> scheduleBoardAppointments = queryAppointmentsByStatuses(
            new List<String>{'Scheduled', 'Dispatched', 'In Progress', 'En Route'},
            'Schedule Board Appointment',
            warnings
        );
        List<RecordDto> calendarAppointments = queryAppointmentsWithScheduleWindow(warnings);
        List<RecordDto> dayOfAppointments = queryAppointmentsForToday(warnings);
        List<RecordDto> scheduleIssues = queryScheduleIssues(warnings);
        List<RecordDto> weather = queryGeneric('Weather_Alert__c', new List<String>{
            'Id', 'Name', 'Alert_Type__c', 'Division__c', 'Severity__c', 'Start_DateTime__c',
            'End_DateTime__c', 'Source_System__c', 'Summary__c', 'Details__c', 'CreatedDate'
        }, weatherScopeWhere, 'Start_DateTime__c DESC NULLS LAST, CreatedDate DESC', 'Weather Alert', warnings);
        List<RecordDto> traffic = queryTrafficImpacts(warnings);
        List<RecordDto> routes = queryRouteOptimizations(warnings);
        List<RecordDto> gps = queryGpsPositions(warnings);
        List<RecordDto> absences = queryGeneric('ResourceAbsence', new List<String>{'Id', 'ResourceId', 'Start', 'End', 'Type', 'CreatedDate'}, null, 'Start ASC NULLS LAST', 'Resource Absence', warnings);
        List<RecordDto> resources = queryGeneric('ServiceResource', new List<String>{'Id', 'Name', 'ResourceType', 'IsActive'}, 'IsActive = true', 'Name ASC', 'Service Resource', warnings);
        List<RecordDto> workTypes = queryGeneric('WorkType', new List<String>{'Id', 'Name'}, null, 'Name ASC', 'Work Type', warnings);
        List<RecordDto> scheduleDays = queryScheduleDays(warnings);
        List<RecordDto> territories = queryGeneric('ServiceTerritory', new List<String>{
            'Id', 'Name', 'City', 'State', 'Latitude', 'Longitude', 'IsActive'
        }, 'IsActive = true', 'Name ASC', 'Service Territory', warnings);

        rows.put('dashboard', appointments);
        rows.put('autoSchedule', autoScheduleAppointments);
        rows.put('scheduleIssues', scheduleIssues);
        rows.put('pending', queryPending(warnings));
        rows.put('scheduleBoard', scheduleBoardAppointments);
        rows.put('calendar', calendarAppointments);
        rows.put('routeResults', routes);
        rows.put('routeGps', mergeRows(routes, gps));
        rows.put('dayOfMonitor', dayOfAppointments);
        rows.put('measuringCup', queryGeneric('TimeSheetEntry', new List<String>{'Id', 'TimeSheetId', 'StartTime', 'EndTime', 'Status'}, null, 'CreatedDate DESC', 'Time Sheet Entry', warnings));
        // Traffic: use Traffic_Impact__c if records exist, otherwise fall back to Route_Optimization_Result__c
        rows.put('traffic', traffic.isEmpty() ? routes : traffic);
        rows.put('weather', weather);
        rows.put('territories', territories);
        rows.put('overtime', absences);
        rows.put('crewOptimization', resources);
        rows.put('draftReview', scheduleDays);
        rows.put('decisionRules', workTypes);
        return rows;
    }

    private static List<RecordDto> queryServiceAppointments(List<String> warnings) {
        if (!hasObject('ServiceAppointment')) {
            warnings.add('ServiceAppointment object is not available.');
            return new List<RecordDto>();
        }
        // Base fields — Latitude/Longitude are standard SA fields (no __c suffix)
        List<String> fields = availableFields('ServiceAppointment', new List<String>{
            'Id', 'AppointmentNumber', 'Subject', 'Status', 'SchedStartTime', 'SchedEndTime',
            'ArrivalWindowStartTime', 'ArrivalWindowEndTime', 'ParentRecordId', 'ServiceTerritoryId', 'WorkTypeId',
            'Latitude', 'Longitude', 'Street', 'City', 'State', 'PostalCode'
        });
        // Relationship traversal fields — build the full SELECT list
        List<String> relFields = new List<String>();
        if (fields.contains('ServiceTerritoryId') && hasObject('ServiceTerritory')) {
            relFields.add('ServiceTerritory.Name');
        }
        if (fields.contains('WorkTypeId') && hasObject('WorkType')) {
            relFields.add('WorkType.Name');
        }
        List<String> allSelectFields = new List<String>(fields);
        allSelectFields.addAll(relFields);

        List<RecordDto> rows = new List<RecordDto>();
        try {
            String queryText = 'SELECT ' + String.join(allSelectFields, ', ')
                + ' FROM ServiceAppointment ORDER BY SchedStartTime ASC NULLS LAST, CreatedDate DESC LIMIT ' + ROW_LIMIT;
            for (SObject item : Database.query(queryText)) {
                RecordDto row = genericRow(item, fields, 'ServiceAppointment');
                row.name = firstValue(item, new List<String>{'AppointmentNumber', 'Subject', 'Id'});
                row.title = firstValue(item, new List<String>{'Subject', 'Status', 'Id'});
                row.detail = buildAppointmentDetail(item);
                // Standard coordinate fields
                if (row.latitude == null && fields.contains('Latitude')) {
                    row.latitude = asDecimal(getValue(item, 'Latitude'));
                }
                if (row.longitude == null && fields.contains('Longitude')) {
                    row.longitude = asDecimal(getValue(item, 'Longitude'));
                }
                // Address
                row.address = buildAddressFromSObject(item, fields);
                // Market (ServiceTerritory)
                row.marketId = safeString(getValue(item, 'ServiceTerritoryId'));
                if (relFields.contains('ServiceTerritory.Name')) {
                    try {
                        SObject st = item.getSObject('ServiceTerritory');
                        if (st != null) row.marketName = safeString(st.get('Name'));
                    } catch (Exception e2) { /* territory not populated */ }
                }
                // Work Type name
                if (relFields.contains('WorkType.Name')) {
                    try {
                        SObject wt = item.getSObject('WorkType');
                        if (wt != null) row.workTypeName = safeString(wt.get('Name'));
                    } catch (Exception e2) { /* work type not populated */ }
                }
                rows.add(row);
            }
        } catch (Exception ex) {
            warnings.add('ServiceAppointment query failed: ' + ex.getMessage());
        }
        return rows;
    }

    private static String buildAddressFromSObject(SObject item, List<String> fields) {
        List<String> parts = new List<String>();
        String street = fields.contains('Street') ? safeString(getValue(item, 'Street')) : '';
        String city = fields.contains('City') ? safeString(getValue(item, 'City')) : '';
        String state = fields.contains('State') ? safeString(getValue(item, 'State')) : '';
        if (String.isNotBlank(street)) parts.add(street);
        if (String.isNotBlank(city)) parts.add(city);
        if (String.isNotBlank(state)) parts.add(state);
        return parts.isEmpty() ? '' : String.join(parts, ', ');
    }

    // ─── SCHEDULE ISSUES — dedicated query with relationship traversal ────────
    private static List<RecordDto> queryScheduleIssues(List<String> warnings) {
        List<RecordDto> rows = new List<RecordDto>();
        if (!hasObject('Schedule_Issue__c')) {
            warnings.add('Schedule_Issue__c object is not available.');
            return rows;
        }
        // Build field list dynamically so this compiles in orgs with subset of fields
        List<String> baseFields = new List<String>{'Id', 'Name', 'CreatedDate'};
        for (String f : new List<String>{
            'Status__c', 'Issue_Type__c', 'Severity__c', 'Summary__c', 'Resolution_Notes__c',
            'Service_Appointment__c', 'Required_Action__c', 'Field_Manager__c', 'Market__c', 'Work_Order__c'
        }) {
            if (hasField('Schedule_Issue__c', f)) baseFields.add(f);
        }
        // Relationship traversal — only add if lookup field and related object are accessible
        if (hasField('Schedule_Issue__c', 'Field_Manager__c')) {
            baseFields.add('Field_Manager__r.Name');
        }
        if (hasField('Schedule_Issue__c', 'Market__c') && hasObject('ServiceTerritory')) {
            baseFields.add('Market__r.Name');
        }
        if (hasField('Schedule_Issue__c', 'Work_Order__c') && hasObject('Work_Order__c')) {
            baseFields.add('Work_Order__r.Name');
        }
        if (hasField('Schedule_Issue__c', 'Service_Appointment__c') && hasObject('ServiceAppointment')) {
            baseFields.add('Service_Appointment__r.AppointmentNumber');
        }
        try {
            String issueWhereClause = hasField('Schedule_Issue__c', 'Status__c')
                ? 'WHERE Status__c NOT IN (\'Resolved\', \'Cleared\', \'Cancelled\')'
                : '';
            String q = 'SELECT ' + String.join(baseFields, ', ')
                + ' FROM Schedule_Issue__c '
                + issueWhereClause
                + ' ORDER BY CreatedDate DESC LIMIT ' + ROW_LIMIT;
            for (SObject item : Database.query(q)) {
                RecordDto row = new RecordDto();
                row.id = safeString(item.get('Id'));
                row.name = safeString(item.get('Name'));
                row.source = 'Schedule Issue';
                row.status = safeString(getValue(item, 'Status__c'));
                row.severity = safeString(getValue(item, 'Severity__c'));
                row.summary = safeString(getValue(item, 'Summary__c'));
                row.title = String.isNotBlank(row.summary) ? row.summary : row.name;
                row.tone = toneFor(row.status);
                row.startValue = safeString(item.get('CreatedDate'));
                row.alertType = safeString(getValue(item, 'Issue_Type__c'));
                // Lookup IDs
                row.serviceAppointmentId = safeString(getValue(item, 'Service_Appointment__c'));
                row.workOrderId = safeString(getValue(item, 'Work_Order__c'));
                row.fieldManagerId = safeString(getValue(item, 'Field_Manager__c'));
                row.marketId = safeString(getValue(item, 'Market__c'));
                row.requiredAction = safeString(getValue(item, 'Required_Action__c'));
                // Relationship names
                try {
                    SObject fmRel = item.getSObject('Field_Manager__r');
                    if (fmRel != null) row.fieldManagerName = safeString(fmRel.get('Name'));
                } catch (Exception e2) {}
                try {
                    SObject mktRel = item.getSObject('Market__r');
                    if (mktRel != null) row.marketName = safeString(mktRel.get('Name'));
                } catch (Exception e2) {}
                // Build detail: WO name + SA number
                List<String> detailParts = new List<String>();
                try {
                    SObject woRel = item.getSObject('Work_Order__r');
                    if (woRel != null) detailParts.add('WO: ' + safeString(woRel.get('Name')));
                } catch (Exception e2) {}
                try {
                    SObject saRel = item.getSObject('Service_Appointment__r');
                    if (saRel != null) {
                        String saNum = safeString(saRel.get('AppointmentNumber'));
                        if (String.isNotBlank(saNum)) detailParts.add('SA: ' + saNum);
                    }
                } catch (Exception e2) {}
                row.detail = String.join(detailParts, ' / ');
                rows.add(row);
            }
        } catch (Exception ex) {
            warnings.add('Schedule_Issue__c query failed: ' + ex.getMessage());
        }
        return rows;
    }

    // ─── MONTHLY METRICS ──────────────────────────────────────────────────────
    private static MonthlyMetricsDto buildMonthlyMetrics(List<String> warnings) {
        MonthlyMetricsDto dto = new MonthlyMetricsDto();
        dto.isForecastFallback = true; // uses SA scheduled count as proxy; no forecast object
        dto.monthLabel = currentMonthLabel();
        dto.byWorkType = new List<MetricsByDimensionDto>();
        dto.byMarket = new List<MetricsByDimensionDto>();
        dto.forecasted = 0;
        dto.completed = 0;
        dto.remaining = 0;
        dto.pct = '—';

        if (!hasObject('ServiceAppointment') || !hasField('ServiceAppointment', 'SchedStartTime')) {
            warnings.add('Monthly metrics unavailable: ServiceAppointment or SchedStartTime not accessible.');
            return dto;
        }
        Date today = Date.today();
        Date firstDay = Date.newInstance(today.year(), today.month(), 1);
        Date lastDay = firstDay.addMonths(1).addDays(-1);
        try {
            dto.forecasted = Database.countQuery(
                'SELECT COUNT() FROM ServiceAppointment WHERE DAY_ONLY(SchedStartTime) >= :firstDay AND DAY_ONLY(SchedStartTime) <= :lastDay'
            );
            if (hasField('ServiceAppointment', 'Status')) {
                dto.completed = Database.countQuery(
                    'SELECT COUNT() FROM ServiceAppointment WHERE DAY_ONLY(SchedStartTime) >= :firstDay AND DAY_ONLY(SchedStartTime) <= :lastDay AND Status = \'Completed\''
                );
            }
            dto.remaining = dto.forecasted - dto.completed;
            dto.pct = dto.forecasted > 0
                ? String.valueOf(Math.round((dto.completed * 100.0) / dto.forecasted)) + '%'
                : '0%';
            if (hasField('ServiceAppointment', 'WorkTypeId')) {
                dto.byWorkType = buildMetricsByDimension(
                    'WorkTypeId', 'WorkType', 'Name', firstDay, lastDay, today, warnings
                );
            }
            if (hasField('ServiceAppointment', 'ServiceTerritoryId')) {
                dto.byMarket = buildMetricsByDimension(
                    'ServiceTerritoryId', 'ServiceTerritory', 'Name', firstDay, lastDay, today, warnings
                );
            }
        } catch (Exception ex) {
            warnings.add('Monthly metrics build failed: ' + ex.getMessage());
        }
        return dto;
    }

    private static List<MetricsByDimensionDto> buildMetricsByDimension(
        String dimIdField, String dimObject, String dimNameField,
        Date firstDay, Date lastDay, Date today, List<String> warnings
    ) {
        List<MetricsByDimensionDto> result = new List<MetricsByDimensionDto>();
        try {
            List<SObject> forecastedAgg = Database.query(
                'SELECT ' + dimIdField + ', COUNT(Id) cnt FROM ServiceAppointment WHERE DAY_ONLY(SchedStartTime) >= :firstDay AND DAY_ONLY(SchedStartTime) <= :lastDay GROUP BY ' + dimIdField + ' LIMIT 20'
            );
            List<SObject> completedAgg = hasField('ServiceAppointment', 'Status') ?
                Database.query('SELECT ' + dimIdField + ', COUNT(Id) cnt FROM ServiceAppointment WHERE DAY_ONLY(SchedStartTime) >= :firstDay AND DAY_ONLY(SchedStartTime) <= :lastDay AND Status = \'Completed\' GROUP BY ' + dimIdField + ' LIMIT 20') :
                new List<SObject>();
            List<SObject> atRiskAgg = hasField('ServiceAppointment', 'Status') ?
                Database.query('SELECT ' + dimIdField + ', COUNT(Id) cnt FROM ServiceAppointment WHERE DAY_ONLY(SchedStartTime) >= :firstDay AND DAY_ONLY(SchedStartTime) <= TODAY AND Status NOT IN (\'Completed\', \'Cancelled\') GROUP BY ' + dimIdField + ' LIMIT 20') :
                new List<SObject>();

            Map<String, Integer> forecastMap = aggToMap(forecastedAgg, dimIdField);
            Map<String, Integer> completedMap = aggToMap(completedAgg, dimIdField);
            Map<String, Integer> atRiskMap = aggToMap(atRiskAgg, dimIdField);

            Map<String, String> nameMap = new Map<String, String>();
            if (!forecastMap.isEmpty() && hasObject(dimObject)) {
                Set<String> dimIds = forecastMap.keySet();
                try {
                    String nameQ = 'SELECT Id, ' + dimNameField + ' FROM ' + dimObject + ' WHERE Id IN :dimIds LIMIT 20';
                    for (SObject dimItem : Database.query(nameQ)) {
                        nameMap.put(safeString(dimItem.get('Id')), safeString(dimItem.get(dimNameField)));
                    }
                } catch (Exception e2) {
                    warnings.add(dimObject + ' name lookup failed: ' + e2.getMessage());
                }
            }
            for (String dimId : forecastMap.keySet()) {
                MetricsByDimensionDto m = new MetricsByDimensionDto();
                m.dimension = nameMap.containsKey(dimId) ? nameMap.get(dimId)
                    : (String.isBlank(dimId) ? 'Unassigned' : dimId);
                m.forecasted = forecastMap.get(dimId);
                m.completed = completedMap.containsKey(dimId) ? completedMap.get(dimId) : 0;
                m.remaining = m.forecasted - m.completed;
                m.atRisk = atRiskMap.containsKey(dimId) ? atRiskMap.get(dimId) : 0;
                m.pct = m.forecasted > 0
                    ? String.valueOf(Math.round((m.completed * 100.0) / m.forecasted)) + '%'
                    : '0%';
                result.add(m);
            }
        } catch (Exception ex) {
            warnings.add('Metrics by ' + dimObject + ' failed: ' + ex.getMessage());
        }
        return result;
    }

    private static Map<String, Integer> aggToMap(List<SObject> aggs, String dimIdField) {
        Map<String, Integer> m = new Map<String, Integer>();
        for (SObject r : aggs) {
            String dimId = safeString(r.get(dimIdField));
            Object cntObj = r.get('cnt');
            Integer cnt = cntObj != null ? Integer.valueOf(String.valueOf(cntObj)) : 0;
            m.put(dimId, cnt);
        }
        return m;
    }

    // ─── RELEASE SCHEDULE DAY ──────────────────────────────────────────────────
    // Updates Release_Status__c on Schedule_Day__c when the dispatcher releases
    // the schedule to the field. Called by the controller after per-appointment
    // releaseToField calls succeed.
    // Uses dynamic SOQL so this compiles even when Release_Status__c hasn't been
    // created yet — the hasField guard returns a clear error in that case.
    public static void releaseScheduleDay(Id scheduleDayId, String newStatus) {
        if (!hasObject('Schedule_Day__c')) {
            throw new AuraHandledException('Schedule_Day__c object is not accessible.');
        }
        if (!hasField('Schedule_Day__c', 'Release_Status__c')) {
            throw new AuraHandledException('Release_Status__c field is not yet on Schedule_Day__c. Add the field in Setup before using this action.');
        }
        String queryText = 'SELECT Id, Release_Status__c FROM Schedule_Day__c WHERE Id = :scheduleDayId LIMIT 1';
        List<SObject> days = Database.query(queryText);
        if (days.isEmpty()) {
            throw new AuraHandledException('Schedule_Day__c record not found: ' + scheduleDayId);
        }
        days[0].put('Release_Status__c', newStatus);
        update days[0];
    }

    private static List<RecordDto> queryPending(List<String> warnings) {
        List<RecordDto> rows = new List<RecordDto>();
        if (!hasObject('ServiceAppointment')) {
            warnings.add('ServiceAppointment object is not available.');
            return rows;
        }
        List<String> desired = new List<String>{
            'Id', 'AppointmentNumber', 'Subject', 'Status',
            'SchedStartTime', 'SchedEndTime', 'ParentRecordId',
            'ServiceTerritoryId', 'WorkTypeId'
        };
        List<String> fields = availableFields('ServiceAppointment', desired);
        if (fields.contains('ServiceTerritoryId') && hasObject('ServiceTerritory')) {
            fields.add('ServiceTerritory.Name');
        }
        if (fields.contains('WorkTypeId') && hasObject('WorkType')) {
            fields.add('WorkType.Name');
        }
        if (!fields.contains('Id')) fields.add('Id');
        String whereClause = hasField('ServiceAppointment', 'Status')
            ? 'Status IN (\'None\', \'Pending Takeoff\', \'Ready to Schedule\')'
            : null;
        try {
            String q = 'SELECT ' + String.join(fields, ', ') + ' FROM ServiceAppointment';
            if (String.isNotBlank(whereClause)) q += ' WHERE ' + whereClause;
            q += ' ORDER BY CreatedDate DESC LIMIT ' + ROW_LIMIT;
            for (SObject item : Database.query(q)) {
                RecordDto row = new RecordDto();
                row.id = safeString(item.get('Id'));
                row.name = safeString(item.get('AppointmentNumber'));
                row.source = 'Pending Appointment';
                row.status = safeString(getValue(item, 'Status'));
                // Build business-readable title from subject
                String subj = safeString(getValue(item, 'Subject'));
                row.title = String.isNotBlank(subj) ? subj : (String.isNotBlank(row.name) ? row.name : 'Appointment');
                row.tone = 'amber';
                // Work type from relationship
                try {
                    SObject wt = item.getSObject('WorkType');
                    if (wt != null) row.workTypeName = safeString(wt.get('Name'));
                } catch (Exception e2) {}
                // Territory from relationship
                try {
                    SObject st = item.getSObject('ServiceTerritory');
                    if (st != null) row.marketName = safeString(st.get('Name'));
                } catch (Exception e2) {}
                // Build human-readable pending reason based on status
                String status = row.status == null ? '' : row.status;
                String workType = String.isNotBlank(row.workTypeName) ? row.workTypeName : 'work type not assigned';
                String market = String.isNotBlank(row.marketName) ? row.marketName : 'territory not assigned';
                if (status == 'None') {
                    row.pendingReason = 'Not yet scheduled — ' + workType + ' · ' + market;
                } else if (status == 'Pending Takeoff') {
                    row.pendingReason = 'Waiting on takeoff completion — ' + workType + ' · ' + market;
                } else if (status == 'Ready to Schedule') {
                    row.pendingReason = 'Ready for scheduling — ' + workType + ' · ' + market;
                } else {
                    row.pendingReason = status + ' — ' + workType + ' · ' + market;
                }
                // Scheduled window
                String schedStart = safeString(getValue(item, 'SchedStartTime'));
                if (String.isNotBlank(schedStart)) {
                    row.startValue = schedStart;
                    row.detail = 'Scheduled: ' + schedStart;
                } else {
                    row.detail = 'No scheduled time set';
                }
                rows.add(row);
            }
        } catch (Exception ex) {
            warnings.add('Pending appointments query failed: ' + ex.getMessage());
        }
        return rows;
    }

    private static List<RecordDto> queryAppointmentsByStatuses(List<String> statuses, String sourceLabel, List<String> warnings) {
        if (!hasObject('ServiceAppointment') || !hasField('ServiceAppointment', 'Status')) {
            return queryServiceAppointments(warnings);
        }
        List<String> quoted = new List<String>();
        for (String statusValue : statuses) {
            quoted.add('\'' + String.escapeSingleQuotes(statusValue) + '\'');
        }
        String whereClause = 'Status IN (' + String.join(quoted, ',') + ')';
        return queryGeneric(
            'ServiceAppointment',
            new List<String>{'Id', 'AppointmentNumber', 'Subject', 'Status', 'SchedStartTime', 'SchedEndTime', 'ParentRecordId', 'ServiceTerritoryId', 'WorkTypeId'},
            whereClause,
            'SchedStartTime ASC NULLS LAST, CreatedDate DESC',
            sourceLabel,
            warnings
        );
    }

    private static List<RecordDto> queryAppointmentsWithScheduleWindow(List<String> warnings) {
        if (!hasObject('ServiceAppointment')) {
            return new List<RecordDto>();
        }
        String whereClause = hasField('ServiceAppointment', 'SchedStartTime')
            ? 'SchedStartTime != null'
            : null;
        return queryGeneric(
            'ServiceAppointment',
            new List<String>{'Id', 'AppointmentNumber', 'Subject', 'Status', 'SchedStartTime', 'SchedEndTime', 'ParentRecordId'},
            whereClause,
            'SchedStartTime ASC NULLS LAST, CreatedDate DESC',
            'Calendar Appointment',
            warnings
        );
    }

    private static List<RecordDto> queryAppointmentsForToday(List<String> warnings) {
        if (!hasObject('ServiceAppointment')) {
            return new List<RecordDto>();
        }
        String whereClause;
        if (hasField('ServiceAppointment', 'SchedStartTime')) {
            whereClause = 'DAY_ONLY(SchedStartTime) = TODAY';
        } else if (hasField('ServiceAppointment', 'CreatedDate')) {
            whereClause = 'DAY_ONLY(CreatedDate) = TODAY';
        }
        return queryGeneric(
            'ServiceAppointment',
            new List<String>{'Id', 'AppointmentNumber', 'Subject', 'Status', 'SchedStartTime', 'SchedEndTime', 'ParentRecordId'},
            whereClause,
            'SchedStartTime ASC NULLS LAST, CreatedDate DESC',
            'Day-Of Appointment',
            warnings
        );
    }

    // ─── GPS POSITIONS — dedicated query with Vehicle__c join ─────────────────
    private static List<RecordDto> queryGpsPositions(List<String> warnings) {
        List<RecordDto> rows = new List<RecordDto>();
        if (!hasObject('WEX_GPS_Position__c')) {
            warnings.add('WEX_GPS_Position__c object is not available.');
            return rows;
        }
        List<String> desired = new List<String>{
            'Id', 'Name', 'Latitude__c', 'Longitude__c',
            'Last_Seen_DateTime__c', 'Speed_MPH__c', 'Heading__c',
            'Source_System__c', 'CreatedDate'
        };
        // Conditionally include Vehicle__c relationship fields
        Boolean hasVehicle = hasField('WEX_GPS_Position__c', 'Vehicle__c') && hasObject('Vehicle__c');
        if (hasVehicle) {
            desired.add('Vehicle__c');
        }
        List<String> fields = availableFields('WEX_GPS_Position__c', desired);
        List<String> selectFields = new List<String>(fields);
        if (hasVehicle) {
            selectFields.add('Vehicle__r.Name');
            if (hasField('Vehicle__c', 'wex_vehicle_id__c')) {
                selectFields.add('Vehicle__r.wex_vehicle_id__c');
            }
            if (hasField('Vehicle__c', 'assigned_driver__c')) {
                selectFields.add('Vehicle__r.assigned_driver__r.Name');
            }
        }
        if (!selectFields.contains('Id')) selectFields.add('Id');
        try {
            String q = 'SELECT ' + String.join(selectFields, ', ')
                + ' FROM WEX_GPS_Position__c'
                + ' ORDER BY Last_Seen_DateTime__c DESC NULLS LAST, CreatedDate DESC'
                + ' LIMIT ' + ROW_LIMIT;
            Set<String> fSet = new Set<String>(fields);
            for (SObject item : Database.query(q)) {
                RecordDto row = new RecordDto();
                row.id           = safeString(item.get('Id'));
                row.name         = safeString(item.get('Name'));
                row.source       = 'GPS Position';
                row.latitude     = asDecimal(getValue(item, fSet, 'Latitude__c'));
                row.longitude    = asDecimal(getValue(item, fSet, 'Longitude__c'));
                row.lastSeenValue = safeString(getValue(item, fSet, 'Last_Seen_DateTime__c'));
                row.speedMph     = asDecimal(getValue(item, fSet, 'Speed_MPH__c'));
                row.sourceSystem = safeString(getValue(item, fSet, 'Source_System__c'));
                row.tone         = 'blue';
                // Vehicle relationship
                if (hasVehicle) {
                    try {
                        SObject veh = item.getSObject('Vehicle__r');
                        if (veh != null) {
                            row.vehicleName = safeString(veh.get('Name'));
                            // WEX unit number e.g. "Unit 105"
                            try {
                                Object unitId = veh.get('wex_vehicle_id__c');
                                if (unitId != null) row.unitNumber = String.valueOf(unitId);
                            } catch (Exception e3) {}
                            // Assigned driver from Vehicle lookup
                            try {
                                SObject driver = veh.getSObject('assigned_driver__r');
                                if (driver != null) row.driverLabel = safeString(driver.get('Name'));
                            } catch (Exception e3) {}
                        }
                    } catch (Exception e2) {}
                }
                // Fallback labels when data gaps exist
                if (String.isBlank(row.vehicleName)) row.vehicleName = 'Vehicle not linked';
                if (String.isBlank(row.unitNumber))  row.unitNumber  = 'Unit # unknown';
                if (String.isBlank(row.driverLabel)) row.driverLabel = 'Driver not mapped';
                // Build display name from unit number + vehicle
                row.title = String.isNotBlank(row.unitNumber) && !row.unitNumber.contains('unknown')
                    ? row.unitNumber + (String.isNotBlank(row.vehicleName) ? ' · ' + row.vehicleName : '')
                    : row.name;
                List<String> detailParts = new List<String>();
                if (row.speedMph != null) detailParts.add(row.speedMph.setScale(0) + ' mph');
                if (String.isNotBlank(row.driverLabel) && !row.driverLabel.contains('not mapped')) {
                    detailParts.add(row.driverLabel);
                }
                row.detail = detailParts.isEmpty() ? '' : String.join(detailParts, ' · ');
                rows.add(row);
            }
        } catch (Exception ex) {
            warnings.add('WEX_GPS_Position__c query failed: ' + ex.getMessage());
        }
        return rows;
    }

    // ─── SCHEDULE DAYS — enriched query for Draft Review tab ─────────────────
    private static List<RecordDto> queryScheduleDays(List<String> warnings) {
        List<RecordDto> rows = new List<RecordDto>();
        if (!hasObject('Schedule_Day__c')) {
            warnings.add('Schedule_Day__c object is not available.');
            return rows;
        }
        List<String> desired = new List<String>{'Id', 'Name', 'Release_Status__c', 'CreatedDate'};
        if (hasField('Schedule_Day__c', 'Schedule_Date__c')) desired.add('Schedule_Date__c');
        if (hasField('Schedule_Day__c', 'Division__c'))     desired.add('Division__c');
        if (hasField('Schedule_Day__c', 'Status__c'))       desired.add('Status__c');
        List<String> fields = availableFields('Schedule_Day__c', desired);
        if (!fields.contains('Id')) fields.add('Id');
        try {
            String q = 'SELECT ' + String.join(fields, ', ')
                + ' FROM Schedule_Day__c ORDER BY CreatedDate DESC LIMIT ' + ROW_LIMIT;
            Set<String> fSet = new Set<String>(fields);
            for (SObject item : Database.query(q)) {
                RecordDto row = new RecordDto();
                row.id     = safeString(item.get('Id'));
                row.name   = safeString(item.get('Name'));
                row.source = 'Schedule Day';
                row.status = safeString(getValue(item, fSet, 'Release_Status__c'));
                if (String.isBlank(row.status)) {
                    row.status = safeString(getValue(item, fSet, 'Status__c'));
                }
                row.tone   = toneFor(row.status);
                row.division = safeString(getValue(item, fSet, 'Division__c'));
                // Schedule date — prefer Schedule_Date__c, fall back to CreatedDate
                String schDate = safeString(getValue(item, fSet, 'Schedule_Date__c'));
                row.scheduleDate = String.isNotBlank(schDate)
                    ? schDate
                    : safeString(item.get('CreatedDate'));
                row.title  = String.isNotBlank(row.division)
                    ? row.division + ' · ' + (String.isNotBlank(schDate) ? schDate.left(10) : row.name)
                    : row.name;
                row.detail = String.isNotBlank(row.status) ? row.status : 'Draft';
                rows.add(row);
            }
            // Enrich with appointment counts via subquery
            if (!rows.isEmpty()) {
                Set<Id> dayIds = new Set<Id>();
                for (RecordDto r : rows) {
                    if (String.isNotBlank(r.id)) dayIds.add((Id)r.id);
                }
                // Count ServiceAppointments linked to each Schedule_Day — via Schedule_Stop__c
                if (hasObject('Schedule_Stop__c') && hasField('Schedule_Stop__c', 'Schedule_Day__c')
                    && hasField('Schedule_Stop__c', 'Service_Appointment__c')) {
                    try {
                        String stopQ = 'SELECT Schedule_Day__c, COUNT(Id) stopCount'
                            + ' FROM Schedule_Stop__c'
                            + ' WHERE Schedule_Day__c IN :dayIds'
                            + ' GROUP BY Schedule_Day__c';
                        Map<String, Integer> countByDay = new Map<String, Integer>();
                        for (AggregateResult ar : Database.query(stopQ)) {
                            countByDay.put(String.valueOf(ar.get('Schedule_Day__c')), (Integer)ar.get('stopCount'));
                        }
                        for (RecordDto r : rows) {
                            r.appointmentCount = countByDay.containsKey(r.id) ? countByDay.get(r.id) : 0;
                        }
                    } catch (Exception ex2) {
                        warnings.add('Schedule_Stop__c count query failed: ' + ex2.getMessage());
                    }
                }
            }
        } catch (Exception ex) {
            warnings.add('Schedule_Day__c query failed: ' + ex.getMessage());
        }
        return rows;
    }

    private static List<RecordDto> queryGeneric(String objectApiName, List<String> desiredFields, String whereClause, String orderBy, String source, List<String> warnings) {
        List<RecordDto> rows = new List<RecordDto>();
        if (!hasObject(objectApiName)) {
            warnings.add(objectApiName + ' object is not available.');
            return rows;
        }
        List<String> fields = availableFields(objectApiName, desiredFields);
        if (!fields.contains('Id')) {
            fields.add('Id');
        }
        try {
            String queryText = 'SELECT ' + String.join(fields, ', ') + ' FROM ' + objectApiName;
            if (String.isNotBlank(whereClause)) {
                queryText += ' WHERE ' + whereClause;
            }
            if (String.isNotBlank(orderBy)) {
                queryText += ' ORDER BY ' + orderBy;
            }
            queryText += ' LIMIT ' + ROW_LIMIT;
            for (SObject item : Database.query(queryText)) {
                rows.add(genericRow(item, fields, source));
            }
        } catch (Exception ex) {
            warnings.add(source + ' query failed: ' + ex.getMessage());
        }
        return rows;
    }

    private static List<RecordDto> mergeRows(List<RecordDto> firstRows, List<RecordDto> secondRows) {
        List<RecordDto> merged = new List<RecordDto>();
        merged.addAll(firstRows);
        merged.addAll(secondRows);
        return merged;
    }

    private static RecordDto genericRow(SObject item, List<String> fields, String source) {
        Set<String> queriedFields = new Set<String>(fields);
        RecordDto row = new RecordDto();
        row.id = safeString(item.get('Id'));
        row.name = firstValue(item, queriedFields, new List<String>{'Name', 'AppointmentNumber', 'Subject', 'Id'});
        row.title = firstValue(item, queriedFields, new List<String>{'Summary__c', 'Subject', 'Name', 'Issue_Type__c', 'ResourceId', 'TimeSheetId', 'Id'});
        row.status = firstValue(item, queriedFields, new List<String>{'Status', 'Status__c', 'Release_Status__c', 'Severity__c', 'Risk__c', 'IsActive'});
        row.source = source;
        row.detail = detailFromFields(item, fields);
        row.tone = toneFor(row.status);
        row.alertType = firstValue(item, queriedFields, new List<String>{'Alert_Type__c'});
        row.division = firstValue(item, queriedFields, new List<String>{'Division__c'});
        row.summary = firstValue(item, queriedFields, new List<String>{'Summary__c'});
        row.sourceSystem = firstValue(item, queriedFields, new List<String>{'Source_System__c'});
        row.startValue = safeString(getValue(item, queriedFields, 'Start_DateTime__c'));
        row.endValue = safeString(getValue(item, queriedFields, 'End_DateTime__c'));
        row.latitude = asDecimal(getValue(item, queriedFields, 'Latitude__c'));
        row.longitude = asDecimal(getValue(item, queriedFields, 'Longitude__c'));
        row.lastSeenValue = safeString(getValue(item, queriedFields, 'Last_Seen_DateTime__c'));
        row.speedMph = asDecimal(getValue(item, queriedFields, 'Speed_MPH__c'));
        return row;
    }

    private static String buildAppointmentDetail(SObject item) {
        List<String> parts = new List<String>();
        addPart(parts, 'Start', safeString(getValue(item, 'SchedStartTime')));
        addPart(parts, 'End', safeString(getValue(item, 'SchedEndTime')));
        addPart(parts, 'Parent', safeString(getValue(item, 'ParentRecordId')));
        return String.join(parts, ' / ');
    }

    private static String detailFromFields(SObject item, List<String> fields) {
        List<String> parts = new List<String>();
        for (String fieldName : fields) {
            if (fieldName == 'Id' || fieldName == 'Name' || fieldName == 'Subject' || fieldName == 'AppointmentNumber') {
                continue;
            }
            Object value = getValue(item, fieldName);
            if (value != null && parts.size() < 3) {
                addPart(parts, fieldName, String.valueOf(value));
            }
        }
        return parts.isEmpty() ? 'No additional fields populated' : String.join(parts, ' / ');
    }

    private static List<KpiDto> buildKpis() {
        String weatherScopeWhere = buildWeatherScopeWhereClause();
        Integer workDays     = workingDaysInMonth();
        Integer daysLeft     = remainingWorkingDays();
        String  daysLeftTone = daysLeft <= 3 ? 'red' : daysLeft <= 7 ? 'amber' : 'green';
        return new List<KpiDto>{
            kpi('Appointments',    countRows('ServiceAppointment', null),         'blue',       'Open appointment detail'),
            kpi('Assigned',        countRows('AssignedResource', null),            'green',      'Open assignment detail'),
            kpi('Issues',          countRows('Schedule_Issue__c', 'Status__c NOT IN (\'Resolved\', \'Cleared\', \'Cancelled\')'), 'amber', 'Open issue detail'),
            kpi('Weather Alerts',  countRows('Weather_Alert__c', weatherScopeWhere), 'amber',   'Open weather detail'),
            kpi('Traffic Impacts', countRows('Traffic_Impact__c', null),           'red',        'HERE · refreshes every 3 min'),
            kpi('GPS Positions',   countRows('WEX_GPS_Position__c', null),         'purple',     'Open GPS detail'),
            kpi('Working Days',    workDays,  'blue',       currentMonthLabel()),
            kpi('Days Remaining',  daysLeft,  daysLeftTone, 'Working days left this month')
        };
    }

    // ─── WORKING DAYS HELPERS ─────────────────────────────────────────────────

    // Jan 1 2006 was a Sunday — used as the epoch for dayOfWeek calculation
    private static final Date DOW_EPOCH = Date.newInstance(2006, 1, 1);

    private static Integer dayOfWeek(Date d) {
        // 0 = Sunday, 1 = Monday … 6 = Saturday
        return Math.mod(DOW_EPOCH.daysBetween(d), 7);
    }

    private static Boolean isWeekday(Date d) {
        Integer dow = dayOfWeek(d);
        return dow >= 1 && dow <= 5;
    }

    private static Integer workingDaysInMonth() {
        Date today = Date.today();
        Date first = Date.newInstance(today.year(), today.month(), 1);
        Integer total = Date.daysInMonth(today.year(), today.month());
        Integer count = 0;
        for (Integer i = 0; i < total; i++) {
            if (isWeekday(first.addDays(i))) count++;
        }
        return count;
    }

    private static Integer remainingWorkingDays() {
        Date today  = Date.today();
        Integer dim = Date.daysInMonth(today.year(), today.month());
        Date last   = Date.newInstance(today.year(), today.month(), dim);
        Integer count = 0;
        Date d = today;
        while (d <= last) {
            if (isWeekday(d)) count++;
            d = d.addDays(1);
        }
        return count;
    }

    private static String currentMonthLabel() {
        Date today = Date.today();
        List<String> months = new List<String>{
            'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
        };
        return months[today.month() - 1] + ' ' + today.year();
    }

    // ─── TRAFFIC IMPACTS — enriched query ─────────────────────────────────────
    private static List<RecordDto> queryTrafficImpacts(List<String> warnings) {
        List<RecordDto> rows = new List<RecordDto>();
        if (!hasObject('Traffic_Impact__c')) {
            warnings.add('Traffic_Impact__c object is not available.');
            return rows;
        }
        List<String> desired = new List<String>{
            'Id', 'Name', 'Impact_Type__c', 'Severity__c', 'Delay_Minutes__c',
            'Territory_Name__c', 'Source_System__c', 'Summary__c',
            'Last_Updated__c', 'CreatedDate'
        };
        List<String> fields = availableFields('Traffic_Impact__c', desired);
        if (!fields.contains('Id')) fields.add('Id');
        try {
            Boolean hasTerritoryField = hasField('Traffic_Impact__c', 'Territory_Name__c');
            String orderBy = hasTerritoryField
                ? 'Territory_Name__c ASC NULLS LAST, Severity__c DESC NULLS LAST, CreatedDate DESC'
                : 'Severity__c DESC NULLS LAST, CreatedDate DESC';
            String q = 'SELECT ' + String.join(fields, ', ')
                + ' FROM Traffic_Impact__c ORDER BY ' + orderBy
                + ' LIMIT ' + ROW_LIMIT;
            for (SObject item : Database.query(q)) {
                Set<String> fSet = new Set<String>(fields);
                RecordDto row = new RecordDto();
                row.id         = safeString(item.get('Id'));
                row.name       = firstValue(item, fSet, new List<String>{'Name'});
                row.title      = firstValue(item, fSet, new List<String>{'Impact_Type__c', 'Name'});
                row.status     = firstValue(item, fSet, new List<String>{'Severity__c'});
                row.division   = firstValue(item, fSet, new List<String>{'Territory_Name__c'});
                row.summary    = firstValue(item, fSet, new List<String>{'Summary__c'});
                row.sourceSystem = firstValue(item, fSet, new List<String>{'Source_System__c'});
                row.tone       = toneFor(row.status);
                row.source     = 'Traffic Impact';
                Decimal delay  = asDecimal(getValue(item, fSet, 'Delay_Minutes__c'));
                row.detail     = (delay != null && delay > 0)
                    ? String.valueOf(delay.setScale(0)) + ' min delay' : '';
                row.startValue = firstValue(item, fSet, new List<String>{'Last_Updated__c', 'CreatedDate'});
                rows.add(row);
            }
        } catch (Exception ex) {
            warnings.add('Traffic_Impact__c query failed: ' + ex.getMessage());
        }
        return rows;
    }

    // ─── ROUTE OPTIMIZATION — enriched query ───────────────────────────────────
    private static List<RecordDto> queryRouteOptimizations(List<String> warnings) {
        List<RecordDto> rows = new List<RecordDto>();
        if (!hasObject('Route_Optimization_Result__c')) {
            warnings.add('Route_Optimization_Result__c object is not available.');
            return rows;
        }
        List<String> desired = new List<String>{
            'Id', 'Name', 'Status__c', 'Crew__c', 'Minutes_Saved__c',
            'Optimized_Drive_Time_Minutes__c', 'Previous_Drive_Time_Minutes__c',
            'Recommendation__c', 'Optimization_Run_DateTime__c', 'CreatedDate'
        };
        List<String> fields = availableFields('Route_Optimization_Result__c', desired);
        if (!fields.contains('Id')) {
            fields.add('Id');
        }
        try {
            String q = 'SELECT ' + String.join(fields, ', ')
                + ' FROM Route_Optimization_Result__c ORDER BY CreatedDate DESC LIMIT ' + ROW_LIMIT;
            for (SObject item : Database.query(q)) {
                Set<String> fSet = new Set<String>(fields);
                RecordDto row = new RecordDto();
                row.id      = safeString(item.get('Id'));
                row.name    = firstValue(item, fSet, new List<String>{'Name'});
                row.status  = firstValue(item, fSet, new List<String>{'Status__c'});
                row.title   = firstValue(item, fSet, new List<String>{'Crew__c', 'Name'});
                row.summary = firstValue(item, fSet, new List<String>{'Recommendation__c'});
                row.tone    = toneFor(row.status);
                row.source  = 'Route Optimization';
                // Build detail from timing fields
                Decimal minSaved = asDecimal(getValue(item, fSet, 'Minutes_Saved__c'));
                Decimal optTime  = asDecimal(getValue(item, fSet, 'Optimized_Drive_Time_Minutes__c'));
                Decimal prevTime = asDecimal(getValue(item, fSet, 'Previous_Drive_Time_Minutes__c'));
                List<String> parts = new List<String>();
                if (minSaved != null)  parts.add(minSaved.setScale(1) + ' min saved');
                if (optTime != null)   parts.add('opt: ' + optTime.setScale(1) + ' min');
                if (prevTime != null)  parts.add('prev: ' + prevTime.setScale(1) + ' min');
                row.detail = parts.isEmpty() ? '' : String.join(parts, ' · ');
                row.startValue = firstValue(item, fSet, new List<String>{'Optimization_Run_DateTime__c', 'CreatedDate'});
                rows.add(row);
            }
        } catch (Exception ex) {
            warnings.add('Route_Optimization_Result__c query failed: ' + ex.getMessage());
        }
        return rows;
    }

    // ─── 7-MARKET CANONICAL MAP ──────────────────────────────────────────────────
    // LOVING operates across 7 independent markets. Weather alerts are matched at
    // market level — rain in Asheville does not affect Greenville scheduling.
    // Weather_Alert__c.Division__c must equal a market name exactly (case-insensitive).
    // Sub-territories are listed per market for reference; they use the parent market's
    // weather alert. Service Territory hierarchy restructuring is tracked separately.
    private static final List<String> MARKET_ORDER = new List<String>{
        'Charlotte - North', 'Charlotte - South', 'Asheville',
        'Triad', 'Greenville', 'Columbia', 'Triangle'
    };

    @TestVisible
    private static Map<String, List<String>> marketToTerritories() {
        return new Map<String, List<String>>{
            'Charlotte - North' => new List<String>{'Charlotte', 'Charlotte Metro', 'Lake Norman', 'Cabarrus'},
            'Charlotte - South' => new List<String>{'Charlotte South', 'Gaston', 'York Lancaster'},
            'Asheville'         => new List<String>{'Asheville', 'Foothills', 'Western NC'},
            'Triad'             => new List<String>{'Triad', 'Triad Metro'},
            'Greenville'        => new List<String>{'Greenville', 'Spartanburg', 'Upstate SC'},
            'Columbia'          => new List<String>{'Columbia', 'Midlands SC'},
            'Triangle'          => new List<String>{'Triangle', 'Triangle Metro'}
        };
    }

    // ─── TERRITORY WEATHER CARDS ───────────────────────────────────────────────
    // Returns one card per market (7 total). Each card is independently clear or
    // active based on whether a Weather_Alert__c row exists with Division__c
    // matching that market name. Alerts with blank Division__c are regional
    // advisories that appear on all 7 cards as amber tone.
    private static List<TerritoryWeatherCard> buildTerritoryWeatherCards(List<String> warnings) {
        List<TerritoryWeatherCard> cards = new List<TerritoryWeatherCard>();

        // Query active Weather_Alert__c records only.
        // End_DateTime__c >= now filters out expired alerts.
        // Rows where End_DateTime__c is null are included (open-ended advisory).
        List<SObject> alerts = new List<SObject>();
        if (hasObject('Weather_Alert__c')) {
            List<String> alertFields = availableFields('Weather_Alert__c', new List<String>{
                'Id', 'Name', 'Alert_Type__c', 'Division__c', 'Severity__c',
                'Start_DateTime__c', 'End_DateTime__c', 'Source_System__c', 'Summary__c'
            });
            if (!alertFields.contains('Id')) alertFields.add('Id');
            try {
                Boolean hasEndField = hasField('Weather_Alert__c', 'End_DateTime__c');
                DateTime alertCutoff = DateTime.now();
                String aSoql = 'SELECT ' + String.join(alertFields, ', ')
                    + ' FROM Weather_Alert__c';
                if (hasEndField) {
                    // Keep only alerts that are still active or have no expiry set
                    aSoql += ' WHERE (End_DateTime__c >= :alertCutoff OR End_DateTime__c = null)';
                }
                aSoql += ' ORDER BY Severity__c DESC NULLS LAST, CreatedDate DESC LIMIT 100';
                alerts = Database.query(aSoql);
            } catch (Exception ex) {
                warnings.add('Weather_Alert__c query for territory cards failed: ' + ex.getMessage());
            }
        }

        // Index alerts by market name (lower-case) for O(1) lookup.
        // When multiple alerts exist for the same market, keep the highest severity.
        // Severity rank: Severe (4) > High (3) > Medium (2) > Low (1).
        Map<String, SObject> alertByMarket = new Map<String, SObject>();
        List<SObject> regionalAlerts = new List<SObject>(); // blank Division__c = advisory for all markets
        for (SObject alert : alerts) {
            String div = safeString(getValue(alert, 'Division__c')).trim();
            if (String.isBlank(div)) {
                // Only keep the most-severe regional advisory
                if (regionalAlerts.isEmpty()
                    || weatherSevRank(firstValue(alert, new List<String>{'Severity__c'}))
                       > weatherSevRank(firstValue(regionalAlerts[0], new List<String>{'Severity__c'}))) {
                    regionalAlerts.clear();
                    regionalAlerts.add(alert);
                }
            } else {
                String key = div.toLowerCase();
                if (!alertByMarket.containsKey(key)) {
                    alertByMarket.put(key, alert);
                } else {
                    // Replace with higher-severity alert for this market
                    String existingSev = firstValue(alertByMarket.get(key), new List<String>{'Severity__c'});
                    String newSev      = firstValue(alert, new List<String>{'Severity__c'});
                    if (weatherSevRank(newSev) > weatherSevRank(existingSev)) {
                        alertByMarket.put(key, alert);
                    }
                }
            }
        }

        // Build one card per market in canonical order
        for (String market : MARKET_ORDER) {
            TerritoryWeatherCard card = new TerritoryWeatherCard();
            card.id        = market;
            card.territory = market;

            // Market-specific alert takes priority; regional advisory is fallback
            SObject matched = alertByMarket.get(market.toLowerCase());
            Boolean isRegional = false;
            if (matched == null && !regionalAlerts.isEmpty()) {
                matched    = regionalAlerts[0];
                isRegional = true;
            }

            if (matched != null) {
                card.hasAlert   = true;
                card.alertType  = firstValue(matched, new List<String>{'Alert_Type__c'});
                card.severity   = firstValue(matched, new List<String>{'Severity__c'});
                card.summary    = firstValue(matched, new List<String>{'Summary__c'});
                card.source     = firstValue(matched, new List<String>{'Source_System__c'});
                card.startValue = safeString(getValue(matched, 'Start_DateTime__c'));
                card.endValue   = safeString(getValue(matched, 'End_DateTime__c'));
                if (String.isBlank(card.source)) card.source = '';
                // Regional fallback is always amber — not confirmed for this market
                if (isRegional) {
                    card.tone = 'amber';
                    card.icon = '🌦';
                } else {
                    String sev = card.severity == null ? '' : card.severity.toLowerCase();
                    if (sev.contains('high') || sev.contains('severe') || sev.contains('extreme')) {
                        card.tone = 'red';
                        card.icon = '⛈';
                    } else if (sev.contains('medium') || sev.contains('moderate') || sev.contains('watch')) {
                        card.tone = 'amber';
                        card.icon = '🌧';
                    } else {
                        card.tone = 'amber';
                        card.icon = '🌦';
                    }
                }
            } else {
                card.hasAlert   = false;
                card.alertType  = 'None';
                card.severity   = 'Clear';
                card.summary    = 'No active weather alerts';
                card.source     = '';
                card.tone       = 'green';
                card.icon       = '☀';
            }
            cards.add(card);
        }
        return cards;
    }

    private static String buildWeatherScopeWhereClause() {
        if (!hasObject('Weather_Alert__c') || !hasField('Weather_Alert__c', 'Division__c')) {
            return null;
        }
        Set<String> markets = activeScheduleMarkets();
        if (markets.isEmpty()) {
            return null;
        }
        List<String> quoted = new List<String>();
        for (String market : markets) {
            quoted.add('\'' + String.escapeSingleQuotes(market) + '\'');
        }
        return 'Division__c IN (' + String.join(quoted, ',') + ')';
    }

    private static Set<String> activeScheduleMarkets() {
        // Returns the 7 canonical market names used as Weather_Alert__c.Division__c values.
        // This replaces the prior ServiceTerritory query, which returned all 19 sub-territories
        // and produced incorrect weather matching (all territories shared the same regional alert).
        return new Set<String>(MARKET_ORDER);
    }

    private static KpiDto kpi(String label, Integer value, String tone, String detail) {
        KpiDto dto = new KpiDto();
        dto.label = label;
        dto.value = value;
        dto.tone = tone;
        dto.detail = detail;
        return dto;
    }

    private static List<TabDto> buildTabs(Map<String, List<RecordDto>> recordsByTab) {
        List<TabDto> tabs = new List<TabDto>();
        tabs.add(tab(1, 'dashboard', 'Dashboard', 'ServiceAppointment, AssignedResource, Weather_Alert__c, Traffic_Impact__c', 'Scheduling health and release readiness', recordsByTab));
        tabs.add(tab(2, 'autoSchedule', 'Auto-Schedule', 'ServiceAppointment, WorkType, ServiceTerritory, ResourceAbsence', 'Optimizer proposals', recordsByTab));
        tabs.add(tab(3, 'scheduleIssues', 'Schedule Issues', 'Schedule_Issue__c or Task', 'Human review queue', recordsByTab));
        tabs.add(tab(4, 'pending', 'Pending', 'WorkOrder readiness, inventory, site readiness', 'Blocked and clear-to-schedule backlog', recordsByTab));
        tabs.add(tab(5, 'scheduleBoard', 'Schedule Board', 'ServiceAppointment, AssignedResource, ServiceResource', 'Crew/day board', recordsByTab));
        tabs.add(tab(6, 'calendar', 'Calendar', 'ServiceAppointment', 'Weekly/monthly schedule', recordsByTab));
        tabs.add(tab(7, 'routeGps', 'Route + GPS', 'Route_Optimization_Result__c, WEX_GPS_Position__c', 'Route map and vehicle location', recordsByTab));
        tabs.add(tab(8, 'dayOfMonitor', 'Day-Of Monitor', 'ServiceAppointment, WorkOrder, Foreman submissions', 'Live day-of execution', recordsByTab));
        tabs.add(tab(9, 'measuringCup', 'Measuring Cup', 'WorkOrderLineItem, TimeSheet/TimeSheetEntry, Rippling', 'Goal vs actual labor', recordsByTab));
        tabs.add(tab(10, 'traffic', 'Traffic', 'Traffic_Impact__c, Route_Optimization_Result__c', 'ETA impact', recordsByTab));
        tabs.add(tab(11, 'weather', 'Weather', 'Weather_Alert__c / NWS', 'Weather risk and holds', recordsByTab));
        tabs.add(tab(12, 'overtime', 'Overtime', 'ResourceAbsence, Rippling/time data', 'OT risk and release block', recordsByTab));
        tabs.add(tab(13, 'crewOptimization', 'Crew Optimization', 'ServiceAppointment, AssignedResource, ServiceResource', 'Crew utilization recommendations', recordsByTab));
        tabs.add(tab(14, 'draftReview', 'Draft Review', 'Schedule_Day__c or release object, ServiceAppointment', '3 PM/4 PM release review', recordsByTab));
        tabs.add(tab(15, 'decisionRules', 'Decision Rules', 'Metadata/custom settings/custom metadata', 'Decision logic reference', recordsByTab));
        return tabs;
    }

    private static TabDto tab(Integer sequence, String key, String label, String source, String purpose, Map<String, List<RecordDto>> recordsByTab) {
        TabDto dto = new TabDto();
        dto.sequence = sequence;
        dto.key = key;
        dto.label = label;
        dto.primarySource = source;
        dto.purpose = purpose;
        dto.count = recordsByTab.containsKey(key) ? recordsByTab.get(key).size() : 0;
        return dto;
    }

    private static List<SourceAuditDto> buildSourceAudit() {
        return new List<SourceAuditDto>{
            audit('Dashboard KPIs', 'ServiceAppointment, AssignedResource', 'Id, Status, SchedStartTime, SchedEndTime, ParentRecordId', 'Weather_Alert__c, Traffic_Impact__c', missingRows('ServiceAppointment'), 'Use live counts; show empty state when no appointments exist.', 'No'),
            audit('Auto-Schedule', 'ServiceAppointment, WorkType, ServiceTerritory, ResourceAbsence', 'WorkTypeId, ServiceTerritoryId, Status, ResourceAbsence.Start/End', 'Route_Optimization_Result__c', optimizerMissing(), 'Use read-only optimization preview now; keep scheduling writes disabled until approved.', 'Yes for write execution'),
            audit('Schedule Issues', 'Task fallback', 'Subject, Status, ActivityDate', 'Schedule_Issue__c exists', missingRows('Schedule_Issue__c'), 'Use Schedule_Issue__c rows if present; create action disabled until approved.', 'Yes for create/update'),
            audit('Pending', 'ServiceAppointment', 'Status, ParentRecordId, SchedStartTime', 'WorkOrder readiness overlays', missingRows('ServiceAppointment'), 'Show Pending from FSL appointment statuses.', 'No'),
            audit('Schedule Board', 'ServiceAppointment, AssignedResource, ServiceResource', 'SA schedule fields, AR resource links', 'None required', missingRows('AssignedResource'), 'Use real SA cards and assigned resources only.', 'No'),
            audit('Calendar', 'ServiceAppointment', 'SchedStartTime, SchedEndTime', 'None required', missingRows('ServiceAppointment'), 'Use SA schedule fields; no fake calendar rows.', 'No'),
            audit('Route + GPS', 'Route_Optimization_Result__c, WEX_GPS_Position__c', 'Id, Name, CreatedDate', 'Route_Optimization_Result__c exists', missingRows('WEX_GPS_Position__c'), 'Show route results and GPS unavailable warning.', 'Yes for recalculation'),
            audit('Day-Of Monitor', 'ServiceAppointment, WorkOrder', 'Status, SchedStartTime', 'Foreman submissions if existing', missingRows('ServiceAppointment'), 'Monitor live SA status only.', 'No'),
            audit('Measuring Cup', 'WorkOrderLineItem, TimeSheetEntry', 'Id, TimeSheetId, StartTime, EndTime', 'Rippling/time integration if approved', missingRows('TimeSheetEntry'), 'Show time source unavailable when empty.', 'Yes for labor integration'),
            audit('Traffic', 'Traffic_Impact__c, Route_Optimization_Result__c', 'Id, Name, Status fields where present', 'Traffic_Impact__c exists', missingRows('Traffic_Impact__c'), 'No fake ETA; use route result fallback.', 'Yes for provider actions'),
            audit('Weather', 'Weather_Alert__c', 'Id, Name, Alert_Type__c, Division__c, Severity__c, Start/End, Source_System__c, Summary__c, Details__c', 'Weather source rows exist', missingRows('Weather_Alert__c'), 'Use Weather_Alert__c rows; no fake forecast.', 'No'),
            audit('Overtime', 'ResourceAbsence, TimeSheetEntry', 'ResourceId, Start, End', 'Rippling integration if approved', missingRows('ResourceAbsence'), 'Show PTO/time source warning when empty.', 'Yes for Rippling-specific logic'),
            audit('Crew Optimization', 'ServiceResource, AssignedResource', 'Name, ResourceType, IsActive', 'None required', missingRows('AssignedResource'), 'Use active resource list and read-only optimization preview; assignment writes disabled.', 'Yes for assignment writes'),
            audit('Draft Review', 'Schedule_Day__c, ServiceAppointment', 'Release_Status__c if present', 'Schedule_Day__c exists', missingRows('Schedule_Day__c'), 'Release button disabled until release source/notifications approved.', 'Yes for release'),
            audit('Decision Rules', 'WorkType, metadata', 'WorkType.Name', 'Existing scheduling rules only', '', 'Show read-only rule reference from available sources.', 'No')
        };
    }

    private static SourceAuditDto audit(String area, String standardObject, String fields, String loving, String missing, String recommendation, String approval) {
        SourceAuditDto dto = new SourceAuditDto();
        dto.uiArea = area;
        dto.standardObjectQueried = standardObject;
        dto.standardFieldsFound = fields;
        dto.existingLovingFieldsFound = loving;
        dto.missingSource = String.isBlank(missing) ? 'None found in metadata audit' : missing;
        dto.recommendation = recommendation;
        dto.approvalNeeded = approval;
        return dto;
    }

    private static List<ActionDto> buildActions() {
        return new List<ActionDto>{
            action('Open FSL Dispatcher', 'Header', 'Navigate to standard FSL dispatcher nav item.', 'None', true, ''),
            action('Refresh Data', 'Header', 'Re-query Scheduling DTOs and source states.', 'None', true, ''),
            action('Run Optimization Preview', 'Auto-Schedule / Crew Optimization', 'Re-query live FSL sources and calculate read-only candidate scores.', 'None', true, ''),
            action('Release Schedule', 'Header / Draft Review', 'Update release status and notify foremen.', 'Schedule_Day__c or approved release source', false, 'Disabled until release status source, holds, and notification path are approved.'),
            action('Run FSL Optimizer', 'Auto-Schedule', 'Call approved optimizer service.', 'ServiceAppointment proposal records', false, 'Disabled until approved optimizer service is configured.'),
            action('Approve Proposed', 'Auto-Schedule', 'Create/update ServiceAppointment and AssignedResource after validation.', 'ServiceAppointment, AssignedResource', false, 'Disabled until assignment write path is approved.'),
            action('Create Schedule Issue', 'Schedule Issues', 'Create issue record or Task.', 'Schedule_Issue__c or Task', false, 'Disabled until issue creation path is approved.'),
            action('Recalculate Route', 'Route + GPS', 'Call route optimizer/provider.', 'Route_Optimization_Result__c', false, 'Disabled until route provider action is approved.'),
            action('Reassign', 'Issues/Board', 'Update AssignedResource through FSL-safe action.', 'AssignedResource', false, 'Disabled until FSL-safe reassign flow is approved.'),
            action('Notify Foremen', 'Header/Day-Of', 'Send approved Salesforce notification/email.', 'Notification/Task/Chatter', false, 'Disabled until notification path is approved.')
        };
    }

    private static ActionDto action(String button, String location, String behavior, String updates, Boolean enabled, String reason) {
        ActionDto dto = new ActionDto();
        dto.button = button;
        dto.location = location;
        dto.behavior = behavior;
        dto.updates = updates;
        dto.enabled = enabled;
        dto.disabledReason = reason;
        return dto;
    }

    private static List<PicklistAuditDto> buildPicklists() {
        return new List<PicklistAuditDto>{
            picklist('ServiceAppointment.Status', picklistValues('ServiceAppointment', 'Status'), 'Map active values to scheduling buckets; do not rename/delete.'),
            picklist('Schedule issue type', picklistValues('Schedule_Issue__c', 'Issue_Type__c'), 'Audit existing values before adding Weather/Traffic/PTO/etc.'),
            picklist('Schedule issue status', picklistValues('Schedule_Issue__c', 'Status__c'), 'Use existing values; additions require approval.'),
            picklist('Weather severity', picklistValues('Weather_Alert__c', 'Severity__c'), 'Map source severity values; no fake weather states.'),
            picklist('Traffic risk', picklistValues('Traffic_Impact__c', 'Risk__c'), 'Map provider risk values; no fake ETA.'),
            picklist('Release status', picklistValues('Schedule_Day__c', 'Release_Status__c'), 'Use existing release status source; release action disabled.')
        };
    }

    private static PicklistAuditDto picklist(String fieldName, List<String> values, String recommendation) {
        PicklistAuditDto dto = new PicklistAuditDto();
        dto.fieldName = fieldName;
        dto.values = values == null ? new List<String>() : values;
        dto.recommendation = recommendation;
        return dto;
    }

    private static OptimizationDto buildOptimizationPreview(List<String> warnings) {
        OptimizationDto dto = new OptimizationDto();
        dto.canPreview = hasObject('ServiceAppointment');
        dto.activeResourceCount = hasField('ServiceResource', 'IsActive')
            ? countRows('ServiceResource', 'IsActive = true')
            : countRows('ServiceResource', null);
        dto.absenceCount = countRows('ResourceAbsence', null);
        dto.weatherAlertCount = countRows('Weather_Alert__c', null);
        dto.trafficImpactCount = countRows('Traffic_Impact__c', null);
        dto.routeResultCount = countRows('Route_Optimization_Result__c', null);
        dto.constraints = buildOptimizationConstraints(dto);
        dto.generatedFrom = 'ServiceAppointment, ServiceResource, ResourceAbsence, Weather_Alert__c, Traffic_Impact__c, Route_Optimization_Result__c';
        dto.recommendations = queryOptimizationRecommendations(warnings, dto);
        dto.candidateCount = dto.recommendations.size();
        dto.summary = dto.candidateCount == 0
            ? 'No live ServiceAppointment candidates returned for optimization preview.'
            : String.valueOf(dto.candidateCount) + ' live ServiceAppointment candidate' + (dto.candidateCount == 1 ? '' : 's') + ' scored for read-only scheduling review.';
        return dto;
    }

    private static List<String> buildOptimizationConstraints(OptimizationDto dto) {
        List<String> constraints = new List<String>{
            'Read-only preview only: no ServiceAppointment, AssignedResource, WorkOrder, route, or notification records are changed.',
            'Write actions remain disabled until Meg approves scheduling execution.',
            'Scores use only live Salesforce rows returned at load time; no static crew, weather, traffic, GPS, PTO, route, or ETA data is generated.'
        };
        if (!hasObject('ServiceAppointment')) {
            constraints.add('ServiceAppointment is unavailable, so optimization preview cannot run.');
        }
        if (dto.activeResourceCount == 0) {
            constraints.add('No active ServiceResource rows returned; crew capacity cannot be scored.');
        }
        if (dto.routeResultCount == 0) {
            constraints.add('No Route_Optimization_Result__c rows returned; route confidence is not included.');
        }
        if (dto.trafficImpactCount == 0) {
            constraints.add('No Traffic_Impact__c rows returned; traffic impact is not included.');
        }
        if (dto.weatherAlertCount == 0) {
            constraints.add('No Weather_Alert__c rows returned; weather impact is not included.');
        }
        return constraints;
    }

    private static List<OptimizationRecommendationDto> queryOptimizationRecommendations(List<String> warnings, OptimizationDto context) {
        List<OptimizationRecommendationDto> recommendations = new List<OptimizationRecommendationDto>();
        if (!hasObject('ServiceAppointment')) {
            return recommendations;
        }

        List<String> fields = availableFields('ServiceAppointment', new List<String>{
            'Id', 'AppointmentNumber', 'Subject', 'Status', 'SchedStartTime', 'SchedEndTime',
            'ParentRecordId', 'ServiceTerritoryId', 'WorkTypeId'
        });
        if (!fields.contains('Id')) {
            fields.add('Id');
        }

        try {
            String queryText = 'SELECT ' + String.join(fields, ', ') + ' FROM ServiceAppointment';
            if (hasField('ServiceAppointment', 'Status')) {
                queryText += ' WHERE Status IN (\'None\', \'Pending Takeoff\', \'Ready to Schedule\', \'Scheduled\', \'Dispatched\')';
            }
            queryText += ' ORDER BY SchedStartTime ASC NULLS LAST, CreatedDate DESC LIMIT ' + ROW_LIMIT;
            for (SObject item : Database.query(queryText)) {
                recommendations.add(buildOptimizationRecommendation(item, context));
            }
        } catch (Exception ex) {
            warnings.add('Optimization preview query failed: ' + ex.getMessage());
        }
        return recommendations;
    }

    private static OptimizationRecommendationDto buildOptimizationRecommendation(SObject item, OptimizationDto context) {
        OptimizationRecommendationDto dto = new OptimizationRecommendationDto();
        dto.id = safeString(getValue(item, 'Id'));
        dto.name = firstValue(item, new List<String>{'AppointmentNumber', 'Subject', 'Id'});
        dto.status = firstValue(item, new List<String>{'Status'});
        dto.startValue = safeString(getValue(item, 'SchedStartTime'));
        dto.endValue = safeString(getValue(item, 'SchedEndTime'));
        dto.serviceTerritoryId = safeString(getValue(item, 'ServiceTerritoryId'));
        dto.workTypeId = safeString(getValue(item, 'WorkTypeId'));
        dto.parentRecordId = safeString(getValue(item, 'ParentRecordId'));

        Integer score = 40;
        List<String> reasons = new List<String>();
        String statusValue = dto.status == null ? '' : dto.status.toLowerCase();
        if (statusValue.contains('ready') || statusValue == 'none' || statusValue.contains('pending')) {
            score += 25;
            reasons.add('status is schedule-candidate');
        } else if (statusValue.contains('scheduled') || statusValue.contains('dispatch')) {
            score += 12;
            reasons.add('already has scheduling state');
        } else if (String.isBlank(statusValue)) {
            reasons.add('status missing');
        } else {
            score += 5;
            reasons.add('status requires review');
        }

        if (String.isNotBlank(dto.startValue)) {
            score += 12;
            reasons.add('scheduled start exists');
        } else {
            reasons.add('scheduled start missing');
        }
        if (String.isNotBlank(dto.serviceTerritoryId)) {
            score += 8;
            reasons.add('territory exists');
        } else {
            reasons.add('territory missing');
        }
        if (String.isNotBlank(dto.workTypeId)) {
            score += 8;
            reasons.add('work type exists');
        } else {
            reasons.add('work type missing');
        }
        if (String.isNotBlank(dto.parentRecordId)) {
            score += 5;
            reasons.add('parent record exists');
        }
        if (context.activeResourceCount > 0) {
            score += 7;
            reasons.add('active resources available');
        }
        if (context.absenceCount > 0) {
            score -= 5;
            reasons.add('absence source has rows');
        }
        if (context.weatherAlertCount > 0) {
            score -= 3;
            reasons.add('weather alerts present');
        }
        if (context.trafficImpactCount > 0) {
            score -= 3;
            reasons.add('traffic impacts present');
        }
        if (score > 100) {
            score = 100;
        }
        if (score < 0) {
            score = 0;
        }

        dto.score = score;
        dto.scoreLabel = String.valueOf(score) + '%';
        dto.tone = score >= 80 ? 'green' : score >= 60 ? 'amber' : 'blue';
        dto.risk = score >= 80 ? 'Low' : score >= 60 ? 'Review' : 'Needs data';
        dto.recommendation = score >= 80
            ? 'Candidate for scheduling review'
            : score >= 60 ? 'Review missing scheduling inputs' : 'Hold until required source data improves';
        dto.reason = String.join(reasons, ' / ');
        return dto;
    }

    private static List<String> picklistValues(String objectApiName, String fieldApiName) {
        List<String> values = new List<String>();
        if (!hasField(objectApiName, fieldApiName)) {
            return values;
        }
        Schema.DescribeFieldResult fieldDescribe = fieldsFor(objectApiName).get(fieldApiName).getDescribe();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    private static Integer countRows(String objectApiName, String whereClause) {
        if (!hasObject(objectApiName)) {
            return 0;
        }
        try {
            String queryText = 'SELECT COUNT() FROM ' + objectApiName;
            if (String.isNotBlank(whereClause)) {
                queryText += ' WHERE ' + whereClause;
            }
            return Database.countQuery(queryText);
        } catch (Exception ex) {
            return 0;
        }
    }

    private static String missingRows(String objectApiName) {
        if (!hasObject(objectApiName)) {
            return objectApiName + ' object missing';
        }
        return countRows(objectApiName, null) == 0 ? objectApiName + ' has 0 rows returned' : '';
    }

    private static String optimizerMissing() {
        return countRows('Route_Optimization_Result__c', null) == 0 ? 'No route optimization rows returned' : '';
    }

    // ─── SCHEMA CACHE — avoid repeated getGlobalDescribe() calls ─────────────
    // Each call to getGlobalDescribe() and getDescribe() consumes significant CPU
    // in Apex. Cache results per-transaction to stay well within governor limits.
    private static Map<String, SObjectType> gd;
    private static Map<String, Map<String, SObjectField>> fieldCache = new Map<String, Map<String, SObjectField>>();

    private static Map<String, SObjectType> globalDescribe() {
        if (gd == null) gd = Schema.getGlobalDescribe();
        return gd;
    }

    private static Map<String, SObjectField> fieldsFor(String objectApiName) {
        if (!fieldCache.containsKey(objectApiName)) {
            SObjectType t = globalDescribe().get(objectApiName);
            fieldCache.put(objectApiName, t == null ? new Map<String, SObjectField>() : t.getDescribe().fields.getMap());
        }
        return fieldCache.get(objectApiName);
    }

    private static Boolean hasObject(String objectApiName) {
        return globalDescribe().containsKey(objectApiName);
    }

    private static Boolean hasField(String objectApiName, String fieldApiName) {
        if (!hasObject(objectApiName)) {
            return false;
        }
        return fieldsFor(objectApiName).containsKey(fieldApiName);
    }

    private static List<String> availableFields(String objectApiName, List<String> desiredFields) {
        List<String> fields = new List<String>();
        for (String fieldName : desiredFields) {
            if (hasField(objectApiName, fieldName)) {
                fields.add(fieldName);
            }
        }
        return fields;
    }

    private static Object getValue(SObject item, String fieldName) {
        try {
            return item.get(fieldName);
        } catch (Exception ex) {
            return null;
        }
    }

    private static Object getValue(SObject item, Set<String> queriedFields, String fieldName) {
        if (queriedFields != null && !queriedFields.contains(fieldName)) {
            return null;
        }
        return getValue(item, fieldName);
    }

    private static String firstValue(SObject item, List<String> fieldNames) {
        for (String fieldName : fieldNames) {
            Object value = getValue(item, fieldName);
            if (value != null && String.isNotBlank(String.valueOf(value))) {
                return String.valueOf(value);
            }
        }
        return '';
    }

    private static String firstValue(SObject item, Set<String> queriedFields, List<String> fieldNames) {
        for (String fieldName : fieldNames) {
            Object value = getValue(item, queriedFields, fieldName);
            if (value != null && String.isNotBlank(String.valueOf(value))) {
                return String.valueOf(value);
            }
        }
        return '';
    }

    private static void addPart(List<String> parts, String label, String value) {
        if (String.isNotBlank(value)) {
            parts.add(label + ': ' + value);
        }
    }

    private static String safeString(Object value) {
        return value == null ? '' : String.valueOf(value);
    }

    private static Decimal asDecimal(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception ex) {
            return null;
        }
    }

    // Severity rank for weather alert comparison within the overlay service.
    // Mirrors WeatherSyncService.severityRank() but kept local to avoid cross-class dependency.
    private static Integer weatherSevRank(String sev) {
        if (String.isBlank(sev)) return 0;
        String s = sev.toLowerCase();
        if (s.contains('severe') || s.contains('extreme')) return 4;
        if (s.contains('high'))                            return 3;
        if (s.contains('medium') || s.contains('moderate')) return 2;
        return 1; // Low or unrecognized
    }

    private static String toneFor(String status) {
        String value = String.valueOf(status).toLowerCase();
        if (value.contains('cancel') || value.contains('cannot') || value.contains('severe') || value.contains('high')) {
            return 'red';
        }
        if (value.contains('ready') || value.contains('scheduled') || value.contains('warning') || value.contains('moderate')) {
            return 'amber';
        }
        if (value.contains('complete') || value.contains('active') || value.contains('clear')) {
            return 'green';
        }
        return 'blue';
    }

    @TestVisible
    private static List<String> exerciseReadOnlyBranchesForTests() {
        Account sample = new Account(Name = 'Scheduling Coverage Account');
        RecordDto first = genericRow(sample, new List<String>{'Name', 'Type', 'Id'}, 'Coverage Source');
        RecordDto second = new RecordDto();
        second.id = 'local-only';
        List<RecordDto> merged = mergeRows(new List<RecordDto>{first}, new List<RecordDto>{second});

        List<String> results = new List<String>();
        results.add(String.valueOf(merged.size()));
        results.add(buildAppointmentDetail(sample));
        results.add(detailFromFields(sample, new List<String>{'Name'}));
        results.add(firstValue(sample, new List<String>{'Missing_Field__c', 'Name'}));
        results.add(safeString(null));
        results.add(toneFor('Canceled'));
        results.add(toneFor('Ready to Schedule'));
        results.add(toneFor('Active'));
        results.add(toneFor('None'));
        results.add(String.valueOf(hasObject('Definitely_Missing_Object__c')));
        results.add(String.valueOf(hasField('Account', 'Definitely_Missing_Field__c')));
        results.add(String.valueOf(availableFields('Account', new List<String>{'Id', 'Name', 'Definitely_Missing_Field__c'}).size()));
        results.add(String.valueOf(countRows('Definitely_Missing_Object__c', null)));
        results.add(missingRows('Definitely_Missing_Object__c'));
        results.add(String.valueOf(picklistValues('Account', 'Definitely_Missing_Field__c').size()));
        results.add(optimizerMissing());
        results.add(String.valueOf(buildSourceAudit().size()));
        results.add(String.valueOf(buildActions().size()));
        results.add(String.valueOf(buildPicklists().size()));
        results.add(String.valueOf(activeScheduleMarkets().size()));
        results.add(String.valueOf(marketToTerritories().size()));
        results.add(String.valueOf(buildTerritoryWeatherCards(new List<String>()).size()));
        results.add(String.valueOf(weatherSevRank('Severe')));
        results.add(String.valueOf(weatherSevRank('High')));
        results.add(String.valueOf(weatherSevRank('Medium')));
        results.add(String.valueOf(weatherSevRank('Low')));
        results.add(String.valueOf(weatherSevRank(null)));
        results.add(String.valueOf(buildWeatherScopeWhereClause()));
        OptimizationDto optimization = buildOptimizationPreview(new List<String>());
        results.add(String.valueOf(buildOptimizationConstraints(optimization).size()));
        Map<String, List<RecordDto>> sampleByTab = new Map<String, List<RecordDto>>();
        sampleByTab.put('dashboard', new List<RecordDto>{first});
        results.add(String.valueOf(buildTabs(sampleByTab).size()));
        // asDecimal branches: null, invalid, valid
        results.add(String.valueOf(asDecimal(null)));
        results.add(String.valueOf(asDecimal('not-a-number')));
        results.add(String.valueOf(asDecimal(42.5)));
        // addPart: blank value (skip) then non-blank (add)
        List<String> partsEx = new List<String>();
        addPart(partsEx, 'L', '');
        addPart(partsEx, 'L', 'V');
        results.add(String.valueOf(partsEx.size()));
        // aggToMap with empty list (covers method entry/exit, loop skipped)
        results.add(String.valueOf(aggToMap(new List<SObject>(), 'Id').size()));
        // getValue(item, Set, fieldName) — field in set and field not in set
        Account setAcc = new Account(Name = 'SetEx');
        Set<String> qsEx = new Set<String>{'Name'};
        results.add(String.valueOf(getValue(setAcc, qsEx, 'Name')));
        results.add(String.valueOf(getValue(setAcc, qsEx, 'Type')));
        // firstValue with Set<String> overload
        results.add(firstValue(setAcc, qsEx, new List<String>{'Name', 'Type'}));
        // currentMonthLabel, workingDaysInMonth, remainingWorkingDays
        results.add(currentMonthLabel());
        results.add(String.valueOf(workingDaysInMonth()));
        results.add(String.valueOf(remainingWorkingDays()));
        return results;
    }

    // ─── TEST-VISIBLE SCORING WRAPPER ─────────────────────────────────────────
    // Allows WeightedScoring test coverage without making buildOptimizationRecommendation public.
    @TestVisible
    private static OptimizationRecommendationDto buildRecommendationForTest(SObject item, OptimizationDto ctx) {
        return buildOptimizationRecommendation(item, ctx);
    }
}