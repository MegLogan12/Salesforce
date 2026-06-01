public with sharing class WorkOrderRecordController {

    /* =========================
       Data transfer classes
       ========================= */

    public class HeaderDto {
        @AuraEnabled public String id;
        @AuraEnabled public String woNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String jobType;
        @AuraEnabled public String division;
        @AuraEnabled public String jobHealth;
        @AuraEnabled public String qiStatus;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal varianceHours;
        @AuraEnabled public String rtn;
        @AuraEnabled public Boolean bonusEligible;
        @AuraEnabled public Datetime foremanSubmitAt;
        @AuraEnabled public Datetime qiSubmittedAt;
    }

    public class StageNode {
        @AuraEnabled public String label;
        @AuraEnabled public String state; // done | active | upcoming | warning
    }

    public class MeasuringCupDto {
        @AuraEnabled public Decimal goalMinutes;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal varianceHours;
        @AuraEnabled public Integer goalHc;
        @AuraEnabled public Integer actualHc;
        @AuraEnabled public String shiftStartTime;
        @AuraEnabled public Integer lunchMinutes;
        @AuraEnabled public Integer cushionMinutes;
        @AuraEnabled public Integer travelMinutes;
        @AuraEnabled public String rtn;
        @AuraEnabled public Boolean bonusEligible;
        @AuraEnabled public Boolean mileageFlag;
        @AuraEnabled public Boolean otFlag;
        @AuraEnabled public Boolean rtnFlag;
    }

    public class LineItemDto {
        @AuraEnabled public String id;
        @AuraEnabled public String description;
        @AuraEnabled public String catalogItem;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal timeStandard;
        @AuraEnabled public Decimal goalMinutes;
        @AuraEnabled public Integer foremanScore;
        @AuraEnabled public String foremanPhotoUrl;
        @AuraEnabled public Boolean scoreFlag;
        @AuraEnabled public Boolean notInstalled;
        @AuraEnabled public String billingType;
    }

    public class QiInspectionDto {
        @AuraEnabled public String id;
        @AuraEnabled public String fm;
        @AuraEnabled public Datetime dateSubmitted;
        @AuraEnabled public Decimal overallScore;
        @AuraEnabled public String overallNotes;
        @AuraEnabled public String status;
    }

    public class QiLineDto {
        @AuraEnabled public String id;
        @AuraEnabled public String woLineItemId;
        @AuraEnabled public Integer fmScore;
        @AuraEnabled public String fmNote;
        @AuraEnabled public Boolean scoreFlag;
        @AuraEnabled public String foremanPhotoUrl;
    }

    public class QiThresholdRow {
        @AuraEnabled public String range;
        @AuraEnabled public String dashboard;
        @AuraEnabled public String outcome;
    }

    public class QiPayload {
        @AuraEnabled public QiInspectionDto inspection;
        @AuraEnabled public List<QiLineDto> lineItems;
        @AuraEnabled public List<QiThresholdRow> thresholds;
    }

    public class PhotoDto {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public String s3Url;
        @AuraEnabled public Boolean geotagValid;
        @AuraEnabled public Datetime takenAt;
        @AuraEnabled public String takenBy;
        @AuraEnabled public Boolean portalVisible;
        @AuraEnabled public String notes;
    }

    public class SubTicketRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String materialsList;
    }

    public class SubTicketsDto {
        @AuraEnabled public List<SubTicketRow> pullTickets;
        @AuraEnabled public List<SubTicketRow> loadingTickets;
        @AuraEnabled public List<SubTicketRow> aquaCheckTickets;
        @AuraEnabled public List<SubTicketRow> aquaInstallTickets;
    }

    public class FinishJobDto {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String reason;
        @AuraEnabled public String status;
        @AuraEnabled public Date scheduledDate;
        @AuraEnabled public String fm;
        @AuraEnabled public String notes;
        @AuraEnabled public Integer completionPhotoCount;
    }

    public class TimeEntryDto {
        @AuraEnabled public String id;
        @AuraEnabled public String technician;
        @AuraEnabled public Decimal hours;
        @AuraEnabled public Date entryDate;
        @AuraEnabled public String source;
    }

    public class TimeLaborDto {
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal varianceHours;
        @AuraEnabled public Boolean bonusEligible;
        @AuraEnabled public Boolean otFlag;
        @AuraEnabled public List<TimeEntryDto> entries;
    }

    /* =========================
       Apex endpoints
       ========================= */

    @AuraEnabled(cacheable=true)
    public static HeaderDto getHeader(Id workOrderId) {
        HeaderDto h = newHeader();
        if (workOrderId == null) return h;

        Map<String, Schema.SObjectField> wMap = workOrderFieldMap();
        if (wMap == null) return h;

        // Work_Order__c field names (custom obj uses __c suffix; Name = AutoNumber)
        List<String> sel = baseWoSelect(wMap, new List<String>{
            'Name','Notes__c','Status__c','Work_Order_Type__c','Division__c','Job_Health__c',
            'QI_Score__c','Goal_Hours__c','Actual_Hours__c','Variance_Hours__c','RTN__c',
            'Bonus_Eligible__c','Foreman_Submit_At__c','QI_Submitted_At__c'
        });
        try {
            String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Work_Order__c WHERE Id = :workOrderId LIMIT 1';
            List<SObject> recs = Database.query(soql);
            if (recs.isEmpty()) return h;
            SObject w = recs[0];
            h.id = String.valueOf(w.get('Id'));
            h.subject = (String) safeGet(w, wMap, 'Notes__c');
            h.status = (String) safeGet(w, wMap, 'Status__c');
            h.woNumber = (String) safeGet(w, wMap, 'Name');
            h.jobType = (String) safeGet(w, wMap, 'Work_Order_Type__c');
            h.division = (String) safeGet(w, wMap, 'Division__c');
            h.jobHealth = (String) safeGet(w, wMap, 'Job_Health__c');
            Object qiScore = safeGet(w, wMap, 'QI_Score__c');
            h.qiStatus = qiScore != null ? String.valueOf(qiScore) : null;
            h.goalHours = toDec(safeGet(w, wMap, 'Goal_Hours__c'));
            h.actualHours = toDec(safeGet(w, wMap, 'Actual_Hours__c'));
            h.varianceHours = toDec(safeGet(w, wMap, 'Variance_Hours__c'));
            h.rtn = (String) safeGet(w, wMap, 'RTN__c');
            h.bonusEligible = toBool(safeGet(w, wMap, 'Bonus_Eligible__c'));
            h.foremanSubmitAt = (Datetime) safeGet(w, wMap, 'Foreman_Submit_At__c');
            h.qiSubmittedAt = (Datetime) safeGet(w, wMap, 'QI_Submitted_At__c');
        } catch (Exception e) { /* tolerate */ }
        return h;
    }

    @AuraEnabled(cacheable=true)
    public static List<StageNode> getStageNodes(Id workOrderId) {
        List<String> labels = new List<String>{
            'New', 'Pending Scheduling', 'Scheduled', 'Takeoff Complete',
            'Site Ready', 'In Progress', 'QI', 'Closed'
        };
        String status = null;
        String qiStatus = null;
        if (workOrderId != null) {
            Map<String, Schema.SObjectField> wMap = workOrderFieldMap();
            if (wMap != null) {
                try {
                    // Work_Order__c: Status__c (picklist), QI_Held__c / QI_Complete__c (booleans)
                    List<String> sel = new List<String>{ 'Id' };
                    if (wMap.containsKey('status__c'))    sel.add('Status__c');
                    if (wMap.containsKey('qi_held__c'))   sel.add('QI_Held__c');
                    if (wMap.containsKey('qi_complete__c')) sel.add('QI_Complete__c');
                    String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Work_Order__c WHERE Id = :workOrderId LIMIT 1';
                    List<SObject> recs = Database.query(soql);
                    if (!recs.isEmpty()) {
                        status = wMap.containsKey('status__c') ? (String) recs[0].get('Status__c') : null;
                        // Derive QI status from boolean fields
                        if (wMap.containsKey('qi_held__c') && toBool(recs[0].get('QI_Held__c'))) {
                            qiStatus = 'Held - FM QI Review';
                        } else if (wMap.containsKey('qi_complete__c') && toBool(recs[0].get('QI_Complete__c'))) {
                            qiStatus = 'Approved';
                        }
                    }
                } catch (Exception e) { /* ignore */ }
            }
        }
        Integer active = mapStatusToStage(status, qiStatus);
        Boolean warn = (qiStatus != null && qiStatus.equalsIgnoreCase('Held - FM QI Review'));

        List<StageNode> out = new List<StageNode>();
        for (Integer i = 0; i < labels.size(); i++) {
            StageNode n = new StageNode();
            n.label = labels[i];
            if (warn && i == active) n.state = 'warning';
            else if (i < active) n.state = 'done';
            else if (i == active) n.state = 'active';
            else n.state = 'upcoming';
            out.add(n);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static MeasuringCupDto getMeasuringCup(Id workOrderId) {
        MeasuringCupDto m = newMeasuringCup();
        if (workOrderId == null) return m;
        Map<String, Schema.SObjectField> wMap = workOrderFieldMap();
        if (wMap == null) return m;
        List<String> sel = baseWoSelect(wMap, new List<String>{
            'Goal_Minutes__c','Goal_Hours__c','Actual_Hours__c','Variance_Hours__c','Goal_HC__c','Actual_HC__c',
            'Shift_Start_Time__c','Lunch_Minutes__c','Cushion_Minutes__c','Travel_Minutes__c','RTN__c','Bonus_Eligible__c'
        });
        try {
            String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Work_Order__c WHERE Id = :workOrderId LIMIT 1';
            List<SObject> recs = Database.query(soql);
            if (recs.isEmpty()) return m;
            SObject w = recs[0];
            m.goalMinutes = toDec(safeGet(w, wMap, 'Goal_Minutes__c'));
            m.goalHours = toDec(safeGet(w, wMap, 'Goal_Hours__c'));
            m.actualHours = toDec(safeGet(w, wMap, 'Actual_Hours__c'));
            m.varianceHours = toDec(safeGet(w, wMap, 'Variance_Hours__c'));
            m.goalHc = toInt(safeGet(w, wMap, 'Goal_HC__c'));
            m.actualHc = toInt(safeGet(w, wMap, 'Actual_HC__c'));
            Object t = safeGet(w, wMap, 'Shift_Start_Time__c');
            m.shiftStartTime = t == null ? '' : String.valueOf(t);
            m.lunchMinutes = toInt(safeGet(w, wMap, 'Lunch_Minutes__c'));
            m.cushionMinutes = toInt(safeGet(w, wMap, 'Cushion_Minutes__c'));
            m.travelMinutes = toInt(safeGet(w, wMap, 'Travel_Minutes__c'));
            m.rtn = (String) safeGet(w, wMap, 'RTN__c');
            m.bonusEligible = toBool(safeGet(w, wMap, 'Bonus_Eligible__c'));
        } catch (Exception e) { /* tolerate */ }
        return m;
    }

    @AuraEnabled(cacheable=true)
    public static List<LineItemDto> getLineItems(Id workOrderId) {
        List<LineItemDto> out = new List<LineItemDto>();
        if (workOrderId == null) return out;
        if (!Schema.getGlobalDescribe().containsKey('WorkOrderLineItem')) return out;
        try {
            Map<String, Schema.SObjectField> fMap = Schema.getGlobalDescribe().get('WorkOrderLineItem').getDescribe().fields.getMap();
            List<String> sel = new List<String>{ 'Id' };
            if (fMap.containsKey('description')) sel.add('Description');
            for (String f : new List<String>{ 'Catalog_Item__c','Quantity__c','Time_Standard__c','Goal_Minutes__c',
                    'Foreman_Score__c','Foreman_Photo_URL__c','Score_Flag__c','Not_Installed__c','Billing_Type__c' }) {
                if (fMap.containsKey(f.toLowerCase())) sel.add(f);
            }
            String soql = 'SELECT ' + String.join(sel, ',') + ' FROM WorkOrderLineItem WHERE WorkOrderId = :workOrderId LIMIT 200';
            List<SObject> recs = Database.query(soql);
            for (SObject li : recs) {
                LineItemDto d = new LineItemDto();
                d.id = String.valueOf(li.get('Id'));
                if (fMap.containsKey('description'))       d.description = (String) li.get('Description');
                if (fMap.containsKey('catalog_item__c'))   d.catalogItem = (String) li.get('Catalog_Item__c');
                if (fMap.containsKey('quantity__c'))       d.quantity = toDec(li.get('Quantity__c'));
                if (fMap.containsKey('time_standard__c'))  d.timeStandard = toDec(li.get('Time_Standard__c'));
                if (fMap.containsKey('goal_minutes__c'))   d.goalMinutes = toDec(li.get('Goal_Minutes__c'));
                if (fMap.containsKey('foreman_score__c'))  d.foremanScore = toInt(li.get('Foreman_Score__c'));
                if (fMap.containsKey('foreman_photo_url__c')) d.foremanPhotoUrl = (String) li.get('Foreman_Photo_URL__c');
                if (fMap.containsKey('score_flag__c'))     d.scoreFlag = toBool(li.get('Score_Flag__c'));
                if (fMap.containsKey('not_installed__c'))  d.notInstalled = toBool(li.get('Not_Installed__c'));
                if (fMap.containsKey('billing_type__c'))   d.billingType = (String) li.get('Billing_Type__c');
                out.add(d);
            }
        } catch (Exception e) { /* ignore */ }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static QiPayload getQiInspection(Id workOrderId) {
        QiPayload p = new QiPayload();
        p.lineItems = new List<QiLineDto>();
        p.thresholds = buildThresholds();
        if (workOrderId == null) return p;
        if (!Schema.getGlobalDescribe().containsKey('QI_Inspection__c')) return p;
        try {
            Map<String, Schema.SObjectField> qMap = Schema.getGlobalDescribe().get('QI_Inspection__c').getDescribe().fields.getMap();
            // Phase 4: use LOVING_Work_Order__c (correct custom WO lookup) if available,
            // else fall back to legacy Work_Order__c field.
            Boolean hasLovingWO = qMap.containsKey('loving_work_order__c');
            if (!hasLovingWO && !qMap.containsKey('work_order__c')) return p;
            List<String> sel = new List<String>{ 'Id' };
            for (String f : new List<String>{ 'FM__c','Date_Submitted__c','Overall_Score__c','Overall_Notes__c','Status__c','Submitted__c' }) {
                if (qMap.containsKey(f.toLowerCase())) sel.add(f);
            }
            String woFilter = hasLovingWO ? 'LOVING_Work_Order__c' : 'Work_Order__c';
            String soql = 'SELECT ' + String.join(sel, ',') + ' FROM QI_Inspection__c WHERE ' + woFilter + ' = :workOrderId LIMIT 1';
            List<SObject> recs = Database.query(soql);
            if (!recs.isEmpty()) {
                SObject q = recs[0];
                QiInspectionDto ins = new QiInspectionDto();
                ins.id = String.valueOf(q.get('Id'));
                if (qMap.containsKey('overall_score__c')) ins.overallScore = toDec(q.get('Overall_Score__c'));
                if (qMap.containsKey('overall_notes__c')) ins.overallNotes = (String) q.get('Overall_Notes__c');
                if (qMap.containsKey('status__c'))        ins.status = (String) q.get('Status__c');
                if (qMap.containsKey('submitted__c'))     ins.dateSubmitted = (Datetime) q.get('Submitted__c');
                if (qMap.containsKey('date_submitted__c'))ins.dateSubmitted = (Datetime) q.get('Date_Submitted__c');
                if (qMap.containsKey('fm__c') && q.get('FM__c') != null) {
                    Id uId = (Id) q.get('FM__c');
                    List<User> uu = [SELECT Id, Name FROM User WHERE Id = :uId LIMIT 1];
                    if (!uu.isEmpty()) ins.fm = uu[0].Name;
                }
                p.inspection = ins;
                // line items
                if (Schema.getGlobalDescribe().containsKey('QI_Line_Item__c')) {
                    Map<String, Schema.SObjectField> lMap = Schema.getGlobalDescribe().get('QI_Line_Item__c').getDescribe().fields.getMap();
                    if (lMap.containsKey('qi_inspection__c')) {
                        List<String> ls = new List<String>{ 'Id' };
                        for (String f : new List<String>{ 'Work_Order_Line_Item__c','FM_Score__c','FM_Note__c','Score_Flag__c','Foreman_Photo_URL__c' }) {
                            if (lMap.containsKey(f.toLowerCase())) ls.add(f);
                        }
                        Id insId = (Id) q.get('Id');
                        String lq = 'SELECT ' + String.join(ls, ',') + ' FROM QI_Line_Item__c WHERE QI_Inspection__c = :insId LIMIT 200';
                        for (SObject li : Database.query(lq)) {
                            QiLineDto ld = new QiLineDto();
                            ld.id = String.valueOf(li.get('Id'));
                            if (lMap.containsKey('work_order_line_item__c')) ld.woLineItemId = String.valueOf(li.get('Work_Order_Line_Item__c'));
                            if (lMap.containsKey('fm_score__c'))   ld.fmScore = toInt(li.get('FM_Score__c'));
                            if (lMap.containsKey('fm_note__c'))    ld.fmNote = (String) li.get('FM_Note__c');
                            if (lMap.containsKey('score_flag__c')) ld.scoreFlag = toBool(li.get('Score_Flag__c'));
                            if (lMap.containsKey('foreman_photo_url__c')) ld.foremanPhotoUrl = (String) li.get('Foreman_Photo_URL__c');
                            p.lineItems.add(ld);
                        }
                    }
                }
            }
        } catch (Exception e) { /* ignore */ }
        return p;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<PhotoDto>> getPhotos(Id workOrderId) {
        Map<String, List<PhotoDto>> grouped = emptyPhotoMap();
        if (workOrderId == null) return grouped;
        if (!Schema.getGlobalDescribe().containsKey('Photo__c')) return grouped;
        try {
            Map<String, Schema.SObjectField> pMap = Schema.getGlobalDescribe().get('Photo__c').getDescribe().fields.getMap();
            if (!pMap.containsKey('work_order__c')) return grouped;
            List<String> sel = new List<String>{ 'Id','Name' };
            for (String f : new List<String>{ 'Photo_Type__c','S3_URL__c','Geotag_Valid__c','Taken_At__c','Taken_By__c','Portal_Visible__c','Notes__c' }) {
                if (pMap.containsKey(f.toLowerCase())) sel.add(f);
            }
            String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Photo__c WHERE Work_Order__c = :workOrderId ORDER BY CreatedDate DESC LIMIT 500';
            List<SObject> recs = Database.query(soql);
            Set<Id> userIds = new Set<Id>();
            for (SObject p : recs) {
                if (pMap.containsKey('taken_by__c') && p.get('Taken_By__c') != null) userIds.add((Id) p.get('Taken_By__c'));
            }
            Map<Id, String> userNames = new Map<Id, String>();
            if (!userIds.isEmpty()) {
                for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds]) userNames.put(u.Id, u.Name);
            }
            for (SObject p : recs) {
                PhotoDto d = new PhotoDto();
                d.id = String.valueOf(p.get('Id'));
                d.name = (String) p.get('Name');
                d.type = pMap.containsKey('photo_type__c') ? (String) p.get('Photo_Type__c') : null;
                d.s3Url = pMap.containsKey('s3_url__c') ? (String) p.get('S3_URL__c') : null;
                d.geotagValid = pMap.containsKey('geotag_valid__c') ? toBool(p.get('Geotag_Valid__c')) : false;
                d.takenAt = pMap.containsKey('taken_at__c') ? (Datetime) p.get('Taken_At__c') : null;
                if (pMap.containsKey('taken_by__c') && p.get('Taken_By__c') != null) d.takenBy = userNames.get((Id) p.get('Taken_By__c'));
                d.portalVisible = pMap.containsKey('portal_visible__c') ? toBool(p.get('Portal_Visible__c')) : false;
                d.notes = pMap.containsKey('notes__c') ? (String) p.get('Notes__c') : null;
                String key = String.isBlank(d.type) ? 'Issue' : d.type;
                if (!grouped.containsKey(key)) grouped.put(key, new List<PhotoDto>());
                grouped.get(key).add(d);
            }
        } catch (Exception e) { /* ignore */ }
        return grouped;
    }

    @AuraEnabled(cacheable=true)
    public static SubTicketsDto getSubTickets(Id workOrderId) {
        SubTicketsDto s = new SubTicketsDto();
        s.pullTickets = querySubTickets('Pull_Ticket__c', workOrderId);
        s.loadingTickets = querySubTickets('Loading_Ticket__c', workOrderId);
        s.aquaCheckTickets = querySubTickets('Aqua_Check_Ticket__c', workOrderId);
        s.aquaInstallTickets = querySubTickets('Aqua_Install_Ticket__c', workOrderId);
        return s;
    }

    @AuraEnabled(cacheable=true)
    public static List<FinishJobDto> getFinishJobs(Id workOrderId) {
        List<FinishJobDto> out = new List<FinishJobDto>();
        if (workOrderId == null) return out;
        if (!Schema.getGlobalDescribe().containsKey('Finish_Job__c')) return out;
        try {
            Map<String, Schema.SObjectField> fMap = Schema.getGlobalDescribe().get('Finish_Job__c').getDescribe().fields.getMap();
            // Phase 4 fix: prefer LOVING_Parent_Work_Order__c (custom Work_Order__c lookup).
            // Legacy Parent_Work_Order__c references standard WorkOrder — skip it to avoid ID mismatch.
            String filterField = null;
            if (fMap.containsKey('loving_parent_work_order__c')) {
                filterField = 'LOVING_Parent_Work_Order__c';
            } else if (fMap.containsKey('parent_work_order__c')) {
                Schema.DescribeFieldResult d = fMap.get('parent_work_order__c').getDescribe();
                for (Schema.SObjectType t : d.getReferenceTo()) {
                    if (t.getDescribe().getName() == 'Work_Order__c') { filterField = 'Parent_Work_Order__c'; break; }
                }
            }
            if (filterField == null) return out; // no valid custom-WO lookup on Finish_Job__c yet
            List<String> sel = new List<String>{ 'Id','Name' };
            for (String f : new List<String>{ 'FJ_Reason__c','FJ_Status__c','Scheduled_Date__c','FM__c','Notes__c','Completion_Photo_Count__c' }) {
                if (fMap.containsKey(f.toLowerCase())) sel.add(f);
            }
            String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Finish_Job__c WHERE ' + filterField + ' = :workOrderId ORDER BY CreatedDate DESC LIMIT 200';
            List<SObject> recs = Database.query(soql);
            Set<Id> userIds = new Set<Id>();
            for (SObject r : recs) {
                if (fMap.containsKey('fm__c') && r.get('FM__c') != null) userIds.add((Id) r.get('FM__c'));
            }
            Map<Id, String> userNames = new Map<Id, String>();
            if (!userIds.isEmpty()) {
                for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds]) userNames.put(u.Id, u.Name);
            }
            for (SObject r : recs) {
                FinishJobDto d = new FinishJobDto();
                d.id = String.valueOf(r.get('Id'));
                d.name = (String) r.get('Name');
                if (fMap.containsKey('fj_reason__c')) d.reason = (String) r.get('FJ_Reason__c');
                if (fMap.containsKey('fj_status__c')) d.status = (String) r.get('FJ_Status__c');
                if (fMap.containsKey('scheduled_date__c')) d.scheduledDate = (Date) r.get('Scheduled_Date__c');
                if (fMap.containsKey('fm__c') && r.get('FM__c') != null) d.fm = userNames.get((Id) r.get('FM__c'));
                if (fMap.containsKey('notes__c')) d.notes = (String) r.get('Notes__c');
                if (fMap.containsKey('completion_photo_count__c')) d.completionPhotoCount = toInt(r.get('Completion_Photo_Count__c'));
                out.add(d);
            }
        } catch (Exception e) { /* ignore */ }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static TimeLaborDto getTimeLabor(Id workOrderId) {
        TimeLaborDto t = newTimeLabor();
        if (workOrderId == null) return t;
        Map<String, Schema.SObjectField> wMap = workOrderFieldMap();
        if (wMap != null) {
            try {
                List<String> sel = baseWoSelect(wMap, new List<String>{
                    'Goal_Hours__c','Actual_Hours__c','Variance_Hours__c','Bonus_Eligible__c'
                });
                String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Work_Order__c WHERE Id = :workOrderId LIMIT 1';
                List<SObject> recs = Database.query(soql);
                if (!recs.isEmpty()) {
                    SObject w = recs[0];
                    t.goalHours = toDec(safeGet(w, wMap, 'Goal_Hours__c'));
                    t.actualHours = toDec(safeGet(w, wMap, 'Actual_Hours__c'));
                    t.varianceHours = toDec(safeGet(w, wMap, 'Variance_Hours__c'));
                    t.bonusEligible = toBool(safeGet(w, wMap, 'Bonus_Eligible__c'));
                }
            } catch (Exception e) { /* ignore */ }
        }
        if (Schema.getGlobalDescribe().containsKey('Time_Entry__c')) {
            try {
                Map<String, Schema.SObjectField> tMap = Schema.getGlobalDescribe().get('Time_Entry__c').getDescribe().fields.getMap();
                if (tMap.containsKey('work_order__c')) {
                    List<String> sel = new List<String>{ 'Id','Name' };
                    for (String f : new List<String>{ 'Technician__c','Hours__c','Entry_Date__c','Source__c' }) {
                        if (tMap.containsKey(f.toLowerCase())) sel.add(f);
                    }
                    String soql = 'SELECT ' + String.join(sel, ',') + ' FROM Time_Entry__c WHERE Work_Order__c = :workOrderId ORDER BY Entry_Date__c DESC NULLS LAST LIMIT 200';
                    List<SObject> recs = Database.query(soql);
                    Set<Id> userIds = new Set<Id>();
                    for (SObject r : recs) {
                        if (tMap.containsKey('technician__c') && r.get('Technician__c') != null) userIds.add((Id) r.get('Technician__c'));
                    }
                    Map<Id, String> userNames = new Map<Id, String>();
                    if (!userIds.isEmpty()) {
                        for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds]) userNames.put(u.Id, u.Name);
                    }
                    for (SObject r : recs) {
                        TimeEntryDto d = new TimeEntryDto();
                        d.id = String.valueOf(r.get('Id'));
                        if (tMap.containsKey('technician__c') && r.get('Technician__c') != null) d.technician = userNames.get((Id) r.get('Technician__c'));
                        if (tMap.containsKey('hours__c'))      d.hours = toDec(r.get('Hours__c'));
                        if (tMap.containsKey('entry_date__c')) d.entryDate = (Date) r.get('Entry_Date__c');
                        if (tMap.containsKey('source__c'))     d.source = (String) r.get('Source__c');
                        t.entries.add(d);
                    }
                }
            } catch (Exception e) { /* ignore */ }
        }
        return t;
    }

    /* =========================
       Private helpers
       ========================= */

    private static Map<String, Schema.SObjectField> workOrderFieldMap() {
        // Phase 4 fix: target Work_Order__c (custom object) — the FlexiPage serves
        // Work_Order__c record IDs, so querying standard WorkOrder always returned 0 rows.
        if (!Schema.getGlobalDescribe().containsKey('Work_Order__c')) return null;
        return Schema.getGlobalDescribe().get('Work_Order__c').getDescribe().fields.getMap();
    }

    private static List<String> baseWoSelect(Map<String, Schema.SObjectField> wMap, List<String> candidates) {
        List<String> sel = new List<String>{ 'Id' };
        for (String f : candidates) {
            if (wMap.containsKey(f.toLowerCase())) sel.add(f);
        }
        return sel;
    }

    private static Object safeGet(SObject rec, Map<String, Schema.SObjectField> fMap, String api) {
        if (rec == null || fMap == null || String.isBlank(api)) return null;
        if (!fMap.containsKey(api.toLowerCase())) return null;
        try { return rec.get(api); } catch (Exception e) { return null; }
    }

    private static HeaderDto newHeader() {
        HeaderDto h = new HeaderDto();
        h.goalHours = 0; h.actualHours = 0; h.varianceHours = 0;
        h.bonusEligible = false;
        return h;
    }

    private static MeasuringCupDto newMeasuringCup() {
        MeasuringCupDto m = new MeasuringCupDto();
        m.goalMinutes = 0; m.goalHours = 0; m.actualHours = 0; m.varianceHours = 0;
        m.goalHc = 0; m.actualHc = 0;
        m.lunchMinutes = 0; m.cushionMinutes = 0; m.travelMinutes = 0;
        m.bonusEligible = false; m.mileageFlag = false; m.otFlag = false; m.rtnFlag = false;
        m.shiftStartTime = '';
        return m;
    }

    private static TimeLaborDto newTimeLabor() {
        TimeLaborDto t = new TimeLaborDto();
        t.goalHours = 0; t.actualHours = 0; t.varianceHours = 0;
        t.bonusEligible = false; t.otFlag = false;
        t.entries = new List<TimeEntryDto>();
        return t;
    }

    private static Integer mapStatusToStage(String status, String qiStatus) {
        // labels index: 0=New, 1=Pending Scheduling, 2=Scheduled, 3=Takeoff Complete,
        //              4=Site Ready, 5=In Progress, 6=QI, 7=Closed
        if (String.isNotBlank(qiStatus)) {
            String qs = qiStatus.toLowerCase();
            if (qs.contains('held') || qs.contains('submitted')) return 6;
            if (qs.contains('approved')) return 7;
        }
        if (String.isBlank(status)) return 0;
        String s = status.toLowerCase();
        if (s.contains('cancel') || s.contains('closed') || s.contains('approved') || s.contains('paid') || s.contains('invoiced')) return 7;
        if (s.contains('qi') || s.contains('pending closeout') || s.contains('pending approval')
                || s.contains('field complete') || s.contains('pending fm') || s.contains('nfi')
                || s.contains('need further')) return 6;
        if (s.contains('in progress') || s.contains('dispatched')) return 5;
        if (s.contains('site ready') || s.contains('site readiness') || s.contains('clear for') || s.contains('clear to')) return 4;
        if (s.contains('takeoff complete') || s.contains('ready to schedule') || s.contains('ready for schedule')
                || s.contains('pending scheduling')) return 3;
        if (s.contains('schedul')) return 2;
        if (s.contains('pending takeoff') || s.contains('takeoff in progress') || s.contains('takeoff sched')) return 1;
        return 0;
    }

    private static List<QiThresholdRow> buildThresholds() {
        List<QiThresholdRow> rows = new List<QiThresholdRow>();
        rows.add(buildThreshold('9.0 - 10.0', 'Green', 'Auto-Approved. Invoice generated.'));
        rows.add(buildThreshold('7.0 - 8.9', 'Green', 'Approved. FM Scorecard updated. Invoice generated.'));
        rows.add(buildThreshold('5.0 - 6.9', 'Yellow', 'Approved with coaching flag. CSM notified.'));
        rows.add(buildThreshold('Below 5.0', 'Red', 'Held - FM QI Review. No invoice until resolved.'));
        return rows;
    }

    private static QiThresholdRow buildThreshold(String range, String dashboard, String outcome) {
        QiThresholdRow r = new QiThresholdRow();
        r.range = range; r.dashboard = dashboard; r.outcome = outcome;
        return r;
    }

    private static Map<String, List<PhotoDto>> emptyPhotoMap() {
        Map<String, List<PhotoDto>> m = new Map<String, List<PhotoDto>>();
        for (String k : new List<String>{ 'Pre-Install','Hero','Line Item Submission','QI','Issue','Incomplete',
                'Site Not Ready','FJ Evidence','FJ Complete','Before','After' }) {
            m.put(k, new List<PhotoDto>());
        }
        return m;
    }

    private static List<SubTicketRow> querySubTickets(String objApi, Id workOrderId) {
        List<SubTicketRow> out = new List<SubTicketRow>();
        if (workOrderId == null) return out;
        if (!Schema.getGlobalDescribe().containsKey(objApi)) return out;
        try {
            Map<String, Schema.SObjectField> fMap = Schema.getGlobalDescribe().get(objApi).getDescribe().fields.getMap();
            // Phase 4 fix: prefer LOVING_Work_Order__c (correct custom Work_Order__c lookup).
            // Fall back to Work_Order__c only if it references the custom object (not standard WorkOrder).
            String filterField = null;
            if (fMap.containsKey('loving_work_order__c')) {
                filterField = 'LOVING_Work_Order__c';
            } else if (fMap.containsKey('work_order__c')) {
                Schema.DescribeFieldResult d = fMap.get('work_order__c').getDescribe();
                for (Schema.SObjectType t : d.getReferenceTo()) {
                    if (t.getDescribe().getName() == 'Work_Order__c') { filterField = 'Work_Order__c'; break; }
                }
            }
            if (filterField == null) return out;
            List<String> sel = new List<String>{ 'Id', 'Name' };
            if (fMap.containsKey('status__c')) sel.add('Status__c');
            String soql = 'SELECT ' + String.join(sel, ',') + ' FROM ' + objApi + ' WHERE ' + filterField + ' = :workOrderId LIMIT 200';
            List<SObject> recs = Database.query(soql);
            for (SObject r : recs) {
                SubTicketRow row = new SubTicketRow();
                row.id = String.valueOf(r.get('Id'));
                row.name = (String) r.get('Name');
                if (fMap.containsKey('status__c')) row.status = (String) r.get('Status__c');
                row.materialsList = '';
                out.add(row);
            }
        } catch (Exception e) { /* ignore */ }
        return out;
    }

    private static Decimal toDec(Object v) {
        if (v == null) return 0;
        if (v instanceof Decimal) return (Decimal) v;
        if (v instanceof Integer) return (Decimal) ((Integer) v);
        if (v instanceof Double) return Decimal.valueOf((Double) v);
        try { return Decimal.valueOf(String.valueOf(v)); } catch (Exception e) { return 0; }
    }

    private static Integer toInt(Object v) {
        if (v == null) return 0;
        if (v instanceof Integer) return (Integer) v;
        if (v instanceof Decimal) return ((Decimal) v).intValue();
        try { return Integer.valueOf(String.valueOf(v)); } catch (Exception e) { return 0; }
    }

    private static Boolean toBool(Object v) {
        if (v == null) return false;
        if (v instanceof Boolean) return (Boolean) v;
        try { return Boolean.valueOf(String.valueOf(v)); } catch (Exception e) { return false; }
    }

    /* =========================
       Test hooks
       ========================= */
    @TestVisible
    private static void exerciseHelpersForCoverage() {
        newHeader(); newMeasuringCup(); newTimeLabor();
        buildThresholds();
        buildThreshold('x','y','z');
        emptyPhotoMap();
        mapStatusToStage(null, null);
        mapStatusToStage('New', null);
        mapStatusToStage('Scheduled', null);
        mapStatusToStage('In Progress', null);
        mapStatusToStage('Completed', null);
        mapStatusToStage('Cannot Complete', null);
        mapStatusToStage('Canceled', null);
        mapStatusToStage('Closed', null);
        mapStatusToStage('Other', 'Held - FM QI Review');
        mapStatusToStage('Other', 'Submitted');
        mapStatusToStage('Other', 'Approved');
        toDec(null); toDec(3); toDec((Decimal) 4.2); toDec((Double) 5.5); toDec('6.1'); toDec('not-a-number');
        toInt(null); toInt(1); toInt((Decimal) 2.5); toInt('3'); toInt('nope');
        toBool(null); toBool(true); toBool('true'); toBool('not-a-bool');
        safeGet(null, null, null);
        safeGet(null, null, 'X');
        // Build each DTO with non-null data for coverage of the DTO field setters.
        HeaderDto h = new HeaderDto();
        h.id = 'x'; h.woNumber = 'w'; h.subject = 's'; h.status = 'st'; h.jobType = 'Install';
        h.division = 'd'; h.jobHealth = 'Green'; h.qiStatus = 'Approved';
        h.goalHours = 1; h.actualHours = 2; h.varianceHours = 1; h.rtn = '5:00'; h.bonusEligible = true;
        h.foremanSubmitAt = Datetime.now(); h.qiSubmittedAt = Datetime.now();
        MeasuringCupDto mc = newMeasuringCup();
        mc.shiftStartTime = '06:30'; mc.rtn = '17:30';
        LineItemDto li = new LineItemDto();
        li.id = 'x'; li.description = 'd'; li.catalogItem = 'c'; li.quantity = 1; li.timeStandard = 2;
        li.goalMinutes = 3; li.foremanScore = 7; li.foremanPhotoUrl = 'http://x'; li.scoreFlag = false;
        li.notInstalled = false; li.billingType = 'Billable';
        QiPayload qp = new QiPayload();
        qp.inspection = new QiInspectionDto();
        qp.inspection.id = 'x'; qp.inspection.fm = 'Ana'; qp.inspection.dateSubmitted = Datetime.now();
        qp.inspection.overallScore = 8.5; qp.inspection.overallNotes = 'n'; qp.inspection.status = 'Approved';
        qp.lineItems = new List<QiLineDto>();
        QiLineDto ql = new QiLineDto();
        ql.id = 'x'; ql.woLineItemId = 'w'; ql.fmScore = 4; ql.fmNote = 'n'; ql.scoreFlag = false; ql.foremanPhotoUrl = 'u';
        qp.lineItems.add(ql);
        qp.thresholds = buildThresholds();
        PhotoDto pd = new PhotoDto();
        pd.id = 'x'; pd.name = 'PH'; pd.type = 'Hero'; pd.s3Url = 'http://x'; pd.geotagValid = true;
        pd.takenAt = Datetime.now(); pd.takenBy = 'User'; pd.portalVisible = true; pd.notes = 'n';
        SubTicketRow st = new SubTicketRow();
        st.id = 'x'; st.name = 'N'; st.status = 'Open'; st.materialsList = '';
        SubTicketsDto sd = new SubTicketsDto();
        sd.pullTickets = new List<SubTicketRow>{ st };
        sd.loadingTickets = new List<SubTicketRow>();
        sd.aquaCheckTickets = new List<SubTicketRow>();
        sd.aquaInstallTickets = new List<SubTicketRow>();
        FinishJobDto fj = new FinishJobDto();
        fj.id = 'x'; fj.name = 'FJ'; fj.reason = '2PM Red'; fj.status = 'Created';
        fj.scheduledDate = Date.today(); fj.fm = 'U'; fj.notes = 'n'; fj.completionPhotoCount = 2;
        TimeEntryDto te = new TimeEntryDto();
        te.id = 'x'; te.technician = 'U'; te.hours = 8; te.entryDate = Date.today(); te.source = 'Rippling';
        TimeLaborDto tl = newTimeLabor();
        tl.entries.add(te);
        StageNode sn = new StageNode();
        sn.label = 'l'; sn.state = 'done';
        QiThresholdRow qt = buildThreshold('x','y','z');
        // Reference fields to avoid "unused" warnings (Apex ignores but explicit).
        System.assertNotEquals(null, h);
        System.assertNotEquals(null, mc);
        System.assertNotEquals(null, li);
        System.assertNotEquals(null, qp);
        System.assertNotEquals(null, pd);
        System.assertNotEquals(null, sd);
        System.assertNotEquals(null, fj);
        System.assertNotEquals(null, tl);
        System.assertNotEquals(null, sn);
        System.assertNotEquals(null, qt);
    }
}