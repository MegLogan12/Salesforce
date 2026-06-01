public with sharing class LovingSAWorkspaceController {

    public class WorkspaceDto {
        @AuraEnabled public HeaderDto header;
        @AuraEnabled public List<KpiDto> kpis;
        @AuraEnabled public List<RowDto> overviewRows;
        @AuraEnabled public List<RowDto> typeRows;
        @AuraEnabled public List<RowDto> routeRows;
        @AuraEnabled public List<RowDto> builderRows;
        @AuraEnabled public List<RowDto> proofRows;
        @AuraEnabled public List<RowDto> overlayRows;
        @AuraEnabled public List<ActivityDto> activity;
    }

    public class HeaderDto {
        @AuraEnabled public Id serviceAppointmentId;
        @AuraEnabled public String appointmentNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String scheduledWindow;
        @AuraEnabled public String schedStartIso;
        @AuraEnabled public String schedEndIso;
        @AuraEnabled public String serviceTerritory;
        @AuraEnabled public String assignedResource;
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String workOrderSubject;
        @AuraEnabled public String builderName;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String poNumber;
        @AuraEnabled public String address;
        @AuraEnabled public String fieldManager;
        @AuraEnabled public String appointmentType;
        @AuraEnabled public String appointmentTypeKey;
        @AuraEnabled public String appointmentTypeSource;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public String contactEmail;
        @AuraEnabled public String contactPhone;
    }

    public class KpiDto {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String detail;
        @AuraEnabled public String tone;
    }

    public class RowDto {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String note;
    }

    public class ActivityDto {
        @AuraEnabled public String label;
        @AuraEnabled public String detail;
        @AuraEnabled public String whenLabel;
    }

    private class TypeDecision {
        String key;
        String label;
        String source;
        TypeDecision(String key, String label, String source) {
            this.key = key;
            this.label = label;
            this.source = source;
        }
    }

    @AuraEnabled(cacheable=true)
    public static WorkspaceDto getWorkspace(Id serviceAppointmentId) {
        WorkspaceDto dto = new WorkspaceDto();
        dto.header = new HeaderDto();
        dto.kpis = new List<KpiDto>();
        dto.overviewRows = new List<RowDto>();
        dto.typeRows = new List<RowDto>();
        dto.routeRows = new List<RowDto>();
        dto.builderRows = new List<RowDto>();
        dto.proofRows = new List<RowDto>();
        dto.overlayRows = new List<RowDto>();
        dto.activity = new List<ActivityDto>();
        if (serviceAppointmentId == null) {
            return dto;
        }

        ServiceAppointment appointment = [
            SELECT Id, AppointmentNumber, Status, Subject, Description, CreatedDate,
                   ParentRecordId, ServiceTerritoryId, ServiceTerritory.Name,
                   SchedStartTime, SchedEndTime, EarliestStartTime, WorkType.Name
            FROM ServiceAppointment
            WHERE Id = :serviceAppointmentId
            LIMIT 1
        ];

        WorkOrder workOrder = appointment.ParentRecordId == null ? null : [
            SELECT Id, WorkOrderNumber, Subject, Description, Status, Work_Order_Type__c,
                   Invoice_Amount__c, QI_Status__c,
                   Street, City, State, PostalCode, AccountId, Account.Name,
                   ContactId, Contact.Name, Contact.Email, Contact.Phone,
                   CaseId, Case.CaseNumber, Case.Subject, Case.Status,
                   WorkType.Name, RecordType.DeveloperName, Field_Manager__r.Name,
                   ServiceTerritory.Name
            FROM WorkOrder
            WHERE Id = :appointment.ParentRecordId
            LIMIT 1
        ];

        Purchase_Order__c po = null;
        if (workOrder != null) {
            List<Purchase_Order__c> pos = [
                SELECT Id, Name, PO_Number__c, Status__c, Takeoff_Status__c, Total_Amount__c,
                       Builder_Account__r.Name, Community__r.Name, Lot__r.Name, Work_Order__c
                FROM Purchase_Order__c
                WHERE Work_Order__c = :workOrder.Id
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (!pos.isEmpty()) {
                po = pos[0];
            }
        }

        AssignedResource assigned = null;
        List<AssignedResource> assignedRows = [
            SELECT Id, ServiceResourceId, ServiceResource.Name
            FROM AssignedResource
            WHERE ServiceAppointmentId = :serviceAppointmentId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (!assignedRows.isEmpty()) {
            assigned = assignedRows[0];
        }

        Integer workOrderFileCount = workOrder == null ? 0 : [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :workOrder.Id];
        Integer workOrderNoteCount = workOrder == null ? 0 : [SELECT COUNT() FROM Note WHERE ParentId = :workOrder.Id];
        Integer workOrderPhotoCount = workOrder == null ? 0 : [SELECT COUNT() FROM Photo__c WHERE Work_Order__c = :workOrder.Id];

        Crew__c crew = null;
        if (assigned != null && assigned.ServiceResourceId != null) {
            List<Crew__c> crews = [
                SELECT Id, Name, Foreman__r.Name, Vehicle__c, Vehicle__r.Name
                FROM Crew__c
                WHERE ServiceResource__c = :assigned.ServiceResourceId
                ORDER BY Active__c DESC, LastModifiedDate DESC
                LIMIT 1
            ];
            if (!crews.isEmpty()) {
                crew = crews[0];
            }
        }

        WEX_GPS_Position__c gps = null;
        if (crew != null && crew.Vehicle__c != null) {
            List<WEX_GPS_Position__c> gpsRows = [
                SELECT Id, Vehicle__r.Name
                FROM WEX_GPS_Position__c
                WHERE Vehicle__c = :crew.Vehicle__c
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (!gpsRows.isEmpty()) {
                gps = gpsRows[0];
            }
        }

        TypeDecision decision = resolveType(appointment, workOrder);
        String trailingToken = trailingSubjectToken(appointment.Subject);
        Aqua_Check_Ticket__c aquaCheck = loadAquaCheck(decision, trailingToken);
        Aqua_Pickup_Ticket__c aquaPickup = loadAquaPickup(decision, trailingToken);
        Aqua_Watering_Schedule__c aquaSchedule = loadAquaSchedule(aquaCheck, aquaPickup);

        dto.header.serviceAppointmentId = appointment.Id;
        dto.header.appointmentNumber = blankToDash(appointment.AppointmentNumber);
        dto.header.status = blankToDash(appointment.Status);
        dto.header.scheduledWindow = formatWindow(appointment);
        dto.header.schedStartIso = appointment.SchedStartTime == null ? null : appointment.SchedStartTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        dto.header.schedEndIso = appointment.SchedEndTime == null ? null : appointment.SchedEndTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        dto.header.serviceTerritory = appointment.ServiceTerritory == null ? 'Unassigned' : appointment.ServiceTerritory.Name;
        dto.header.assignedResource = assigned == null || assigned.ServiceResource == null ? 'Unassigned' : assigned.ServiceResource.Name;
        dto.header.workOrderId = workOrder == null ? null : workOrder.Id;
        dto.header.workOrderNumber = workOrder == null ? 'Not linked' : workOrder.WorkOrderNumber;
        dto.header.workOrderSubject = workOrder == null ? 'Not linked' : blankToDash(workOrder.Subject);
        dto.header.builderName =
            po != null && po.Builder_Account__r != null
                ? po.Builder_Account__r.Name
                : (workOrder != null && workOrder.Account != null ? workOrder.Account.Name : 'Not linked');
        dto.header.communityName = po == null || po.Community__r == null ? 'Not linked' : po.Community__r.Name;
        dto.header.lotName = po == null || po.Lot__r == null ? inferLotName(aquaCheck, aquaPickup) : po.Lot__r.Name;
        dto.header.poNumber = po == null ? 'Not linked' : po.PO_Number__c;
        dto.header.address = workOrder == null ? 'Address not available' : fullAddress(workOrder.Street, workOrder.City, workOrder.State, workOrder.PostalCode);
        dto.header.fieldManager = workOrder == null || workOrder.Field_Manager__r == null ? 'Unassigned' : workOrder.Field_Manager__r.Name;
        dto.header.appointmentType = decision.label;
        dto.header.appointmentTypeKey = decision.key;
        dto.header.appointmentTypeSource = decision.source;
        dto.header.accountId = workOrder == null ? null : workOrder.AccountId;
        dto.header.accountName = workOrder == null || workOrder.Account == null ? 'Not linked' : workOrder.Account.Name;
        dto.header.contactId = workOrder == null ? null : workOrder.ContactId;
        dto.header.contactName = workOrder == null || workOrder.Contact == null ? 'Not linked' : blankToDash(workOrder.Contact.Name);
        dto.header.contactEmail = workOrder == null || workOrder.Contact == null ? null : workOrder.Contact.Email;
        dto.header.contactPhone = workOrder == null || workOrder.Contact == null ? null : workOrder.Contact.Phone;

        dto.kpis = buildKpis(dto.header, workOrder, po, crew, gps, aquaSchedule);
        dto.overviewRows = buildOverviewRows(dto.header, workOrder);
        dto.typeRows = buildTypeRows(decision, dto.header, workOrder, po, aquaCheck, aquaPickup, aquaSchedule);
        dto.routeRows = buildRouteRows(decision, dto.header, crew, gps, workOrder, aquaCheck, aquaPickup);
        dto.builderRows = buildContextRows(decision, dto.header, workOrder, po, aquaCheck, aquaPickup, aquaSchedule);
        dto.proofRows = buildProofRows(decision, dto.header, workOrder, po, aquaCheck, aquaPickup, aquaSchedule, workOrderFileCount, workOrderPhotoCount, workOrderNoteCount);
        dto.activity.add(activity('Service Appointment Created', dto.header.appointmentNumber + ' · ' + dto.header.status, appointment.CreatedDate == null ? 'Unknown' : appointment.CreatedDate.format('M/d/yyyy h:mm a')));
        if (workOrder != null) {
            dto.activity.add(activity('Parent Work Order', dto.header.workOrderNumber + ' · ' + blankToDash(workOrder.Status), blankToDash(workOrder.Subject)));
        }
        if (po != null) {
            dto.activity.add(activity('Builder PO Context', dto.header.poNumber + ' · ' + blankToDash(po.Status__c), blankToDash(po.Takeoff_Status__c)));
        }
        if (aquaCheck != null) {
            dto.activity.add(activity('Aqua Check Ticket', aquaCheck.Name + ' · ' + blankToDash(String.valueOf(aquaCheck.Scheduled_Date__c)), 'Lot ' + blankToDash(aquaCheck.Lot__r == null ? null : aquaCheck.Lot__r.Name)));
        }
        if (aquaPickup != null) {
            dto.activity.add(activity('Aqua Pickup Ticket', aquaPickup.Name + ' · ' + blankToDash(String.valueOf(aquaPickup.Scheduled_Date__c)), 'Lot ' + blankToDash(aquaPickup.Lot__r == null ? null : aquaPickup.Lot__r.Name)));
        }
        return dto;
    }

    private static TypeDecision resolveType(ServiceAppointment appointment, WorkOrder workOrder) {
        String woType = workOrder == null ? null : workOrder.Work_Order_Type__c;
        String woStatus = workOrder == null ? null : workOrder.Status;
        String recordType = workOrder == null || workOrder.RecordType == null ? null : workOrder.RecordType.DeveloperName;
        String workTypeName = workOrder != null && workOrder.WorkType != null
            ? workOrder.WorkType.Name
            : (appointment.WorkType == null ? null : appointment.WorkType.Name);
        String subject = appointment == null ? null : appointment.Subject;

        if (equalsIgnoreCase(woType, 'Aqua Check') || equalsIgnoreCase(workTypeName, 'Aqua Check') || startsWithIgnoreCase(subject, 'Aqua Check')) {
            return new TypeDecision('aquaCheck', 'Aqua Check', sourceLabel(woType, workTypeName, subject, 'Aqua Check', 'Work Order Type', 'Work Type', 'Subject'));
        }
        if (equalsIgnoreCase(woType, 'Aqua Pickup') || equalsIgnoreCase(workTypeName, 'Aqua Pickup') || startsWithIgnoreCase(subject, 'Aqua Pickup')) {
            return new TypeDecision('aquaPickup', 'Aqua Pickup', sourceLabel(woType, workTypeName, subject, 'Aqua Pickup', 'Work Order Type', 'Work Type', 'Subject'));
        }
        if (equalsIgnoreCase(workTypeName, 'Field Manager Takeoff') || startsWithIgnoreCase(subject, 'Takeoff')) {
            return new TypeDecision('takeoff', 'Takeoff', sourceLabel(workTypeName, workTypeName, subject, 'Takeoff', 'Work Type', 'Work Type', 'Subject'));
        }
        if (equalsIgnoreCase(woStatus, 'Site Readiness') || startsWithIgnoreCase(subject, 'Site Readiness')
            || (equalsIgnoreCase(workTypeName, 'Field Manager 48-Hour Site Visit') && startsWithIgnoreCase(subject, 'Site Readiness'))) {
            return new TypeDecision('siteReadiness', 'Site Readiness', firstNonBlank(
                equalsIgnoreCase(woStatus, 'Site Readiness') ? 'Work Order Status' : null,
                equalsIgnoreCase(workTypeName, 'Field Manager 48-Hour Site Visit') ? 'Work Type + Subject' : null,
                startsWithIgnoreCase(subject, 'Site Readiness') ? 'Subject' : null
            ));
        }
        if (equalsIgnoreCase(woStatus, 'FM/QI Review') || startsWithIgnoreCase(subject, 'FM Review')) {
            return new TypeDecision('fmReview', 'FM Review', firstNonBlank(
                equalsIgnoreCase(woStatus, 'FM/QI Review') ? 'Work Order Status' : null,
                startsWithIgnoreCase(subject, 'FM Review') ? 'Subject' : null,
                null
            ));
        }
        if (equalsIgnoreCase(workTypeName, 'Site Visit') || equalsIgnoreCase(woStatus, 'Site Visit Scheduled') || startsWithIgnoreCase(subject, 'Site Visit')) {
            return new TypeDecision('siteVisit', 'Site Visit', firstNonBlank(
                equalsIgnoreCase(workTypeName, 'Site Visit') ? 'Work Type' : null,
                equalsIgnoreCase(woStatus, 'Site Visit Scheduled') ? 'Work Order Status' : null,
                startsWithIgnoreCase(subject, 'Site Visit') ? 'Subject' : null
            ));
        }
        if (equalsIgnoreCase(woType, 'Customer Success') || equalsIgnoreCase(recordType, 'Customer_Care')) {
            return new TypeDecision('customerSuccess', 'Customer Success', equalsIgnoreCase(woType, 'Customer Success') ? 'Work Order Type' : 'Record Type');
        }
        if (equalsIgnoreCase(woType, 'Production Install') || equalsIgnoreCase(workTypeName, 'Production Install') || equalsIgnoreCase(recordType, 'Production_Install')) {
            return new TypeDecision('productionInstall', 'Production Install', firstNonBlank(
                equalsIgnoreCase(woType, 'Production Install') ? 'Work Order Type' : null,
                equalsIgnoreCase(workTypeName, 'Production Install') ? 'Work Type' : null,
                equalsIgnoreCase(recordType, 'Production_Install') ? 'Record Type' : null
            ));
        }
        return new TypeDecision('generic', 'Service Appointment', 'Fallback');
    }

    private static List<KpiDto> buildKpis(HeaderDto header, WorkOrder workOrder, Purchase_Order__c po, Crew__c crew, WEX_GPS_Position__c gps, Aqua_Watering_Schedule__c aquaSchedule) {
        List<KpiDto> rows = new List<KpiDto>();
        rows.add(kpi('Appointment Type', header.appointmentType, header.appointmentTypeSource, 'purple'));
        rows.add(kpi('Status', header.status, header.scheduledWindow, 'blue'));
        rows.add(kpi('Crew', crew == null ? header.assignedResource : crew.Name, crew == null ? 'AssignedResource only' : 'Crew__c mapped from ServiceResource', crew == null ? 'amber' : 'green'));
        rows.add(kpi('Work Order', header.workOrderNumber, header.workOrderSubject, workOrder == null ? 'amber' : 'blue'));
        rows.add(kpi(contextKpiLabel(header), primaryContextValue(header, workOrder, po), primaryContextDetail(header, workOrder, po), 'aqua'));
        if (header.appointmentTypeKey == 'aquaCheck' || header.appointmentTypeKey == 'aquaPickup') {
            rows.add(kpi('Watering Schedule', aquaSchedule == null ? 'Not linked' : aquaSchedule.Run_Frequency__c, aquaSchedule == null ? 'No live Aqua schedule row linked here' : scheduleDetail(aquaSchedule), aquaSchedule == null ? 'amber' : 'blue'));
        } else if (po != null) {
            rows.add(kpi('PO Bridge', blankToDash(po.Takeoff_Status__c), blankToDash(po.Status__c), 'purple'));
        }
        return rows;
    }

    private static List<RowDto> buildOverviewRows(HeaderDto header, WorkOrder workOrder) {
        List<RowDto> rows = new List<RowDto>();
        rows.add(row('Appointment Type', header.appointmentType, header.appointmentTypeSource));
        rows.add(row('Appointment Number', header.appointmentNumber, 'Standard ServiceAppointment'));
        rows.add(row('Status', header.status, header.scheduledWindow));
        rows.add(row('Service Territory', header.serviceTerritory, 'Standard FSL territory'));
        rows.add(row('Assigned Resource', header.assignedResource, 'Primary AssignedResource row'));
        rows.add(row('Field Manager', header.fieldManager, workOrder == null ? 'No parent WorkOrder linked' : 'Parent WorkOrder owner'));
        return rows;
    }

    private static List<RowDto> buildTypeRows(TypeDecision decision, HeaderDto header, WorkOrder workOrder, Purchase_Order__c po,
                                              Aqua_Check_Ticket__c aquaCheck, Aqua_Pickup_Ticket__c aquaPickup,
                                              Aqua_Watering_Schedule__c aquaSchedule) {
        List<RowDto> rows = new List<RowDto>();
        if (decision.key == 'productionInstall') {
            rows.add(row('Builder', header.builderName, 'Production install stays on the builder backbone'));
            rows.add(row('Community', header.communityName, 'Builder community context'));
            rows.add(row('Lot', header.lotName, 'Install lot context'));
            rows.add(row('Install Readiness', workOrder == null ? 'Unknown' : blankToDash(workOrder.Status), 'Parent WorkOrder status drives execution'));
        } else if (decision.key == 'takeoff') {
            rows.add(row('Builder', header.builderName, 'Builder-side takeoff context'));
            rows.add(row('Lot', header.lotName, 'Lot package under review'));
            rows.add(row('Takeoff Status', po == null ? 'Not linked' : blankToDash(po.Takeoff_Status__c), po == null ? 'No Builder PO linked yet' : blankToDash(po.Status__c)));
            rows.add(row('Due Window', header.scheduledWindow, 'Use the scheduled appointment window as the live due target'));
        } else if (decision.key == 'aquaCheck') {
            rows.add(row('Aqua Check Ticket', aquaCheck == null ? 'Not resolved' : aquaCheck.Name, 'Linked from the live appointment subject when available'));
            rows.add(row('Lot', inferLotName(aquaCheck, aquaPickup), 'Aqua lot context'));
            rows.add(row('Scheduled Check Date', aquaCheck == null ? 'Not available' : blankToDash(String.valueOf(aquaCheck.Scheduled_Date__c)), 'Live Aqua check queue date'));
            rows.add(row('Watering Schedule', aquaSchedule == null ? 'Not linked' : aquaSchedule.Run_Frequency__c, aquaSchedule == null ? 'No live watering row linked here' : scheduleDetail(aquaSchedule)));
        } else if (decision.key == 'aquaPickup') {
            rows.add(row('Aqua Pickup Ticket', aquaPickup == null ? 'Not resolved' : aquaPickup.Name, 'Linked from the live appointment subject when available'));
            rows.add(row('Lot', inferLotName(aquaCheck, aquaPickup), 'Aqua lot context'));
            rows.add(row('Scheduled Pickup Date', aquaPickup == null ? 'Not available' : blankToDash(String.valueOf(aquaPickup.Scheduled_Date__c)), 'Live Aqua pickup queue date'));
            rows.add(row('Assigned Tech', aquaPickup == null || aquaPickup.Assigned_To__r == null ? header.assignedResource : aquaPickup.Assigned_To__r.Name, 'Aqua ticket assignee when available'));
        } else if (decision.key == 'siteReadiness') {
            rows.add(row('Readiness Status', workOrder == null ? 'Unknown' : blankToDash(workOrder.Status), 'Live parent WorkOrder status'));
            rows.add(row('Builder', header.builderName, header.builderName == 'Not linked' ? 'Builder bridge not linked on this readiness row' : 'Builder project context'));
            rows.add(row('Lot', header.lotName, header.lotName == 'Not linked' ? 'Lot not linked on the parent bridge' : 'Readiness visit lot'));
            rows.add(row('Downstream Work', header.workOrderNumber, header.workOrderSubject));
        } else if (decision.key == 'fmReview') {
            rows.add(row('Review Status', workOrder == null ? 'Unknown' : blankToDash(workOrder.Status), 'Live quality review state'));
            rows.add(row('Field Manager', header.fieldManager, 'Owner of the review pass'));
            rows.add(row('Builder Lot', header.lotName, header.builderName == 'Not linked' ? 'No builder bridge linked' : header.builderName + ' · ' + header.communityName));
            rows.add(row('Downstream Handoff', header.workOrderNumber, 'Closeout stays on the standard backbone'));
        } else if (decision.key == 'siteVisit') {
            rows.add(row('Homeowner / Account', workOrder == null || workOrder.Account == null ? 'Not linked' : workOrder.Account.Name, 'Customer-success visit context'));
            rows.add(row('Contact', workOrder == null || workOrder.Contact == null ? 'Not linked' : workOrder.Contact.Name, workOrder == null || workOrder.Contact == null ? 'No contact linked' : blankToDash(workOrder.Contact.Phone)));
            rows.add(row('Case / Issue', workOrder == null || workOrder.Case == null ? 'Not linked' : workOrder.Case.CaseNumber, workOrder == null || workOrder.Case == null ? 'No case linked' : blankToDash(workOrder.Case.Subject)));
            rows.add(row('Visit Status', workOrder == null ? 'Unknown' : blankToDash(workOrder.Status), 'Downstream field visit state'));
        } else if (decision.key == 'customerSuccess') {
            rows.add(row('Homeowner / Account', workOrder == null || workOrder.Account == null ? 'Not linked' : workOrder.Account.Name, 'Customer-success work order context'));
            rows.add(row('Contact', workOrder == null || workOrder.Contact == null ? 'Not linked' : workOrder.Contact.Name, workOrder == null || workOrder.Contact == null ? 'No contact linked' : blankToDash(workOrder.Contact.Email)));
            rows.add(row('Case / Issue', workOrder == null || workOrder.Case == null ? 'Not linked' : workOrder.Case.CaseNumber, workOrder == null || workOrder.Case == null ? 'No case linked' : blankToDash(workOrder.Case.Subject)));
            rows.add(row('Field Handoff', header.workOrderNumber, 'Customer Success hands off to field execution on the standard backbone'));
        } else {
            rows.add(row('Primary Subject', header.workOrderSubject, 'No specific LOVING branch matched this appointment'));
            rows.add(row('Work Order', header.workOrderNumber, 'Parent standard WorkOrder'));
            rows.add(row('Territory', header.serviceTerritory, 'Standard FSL territory'));
            rows.add(row('Assigned Resource', header.assignedResource, 'Primary dispatch owner'));
        }
        return rows;
    }

    private static List<RowDto> buildRouteRows(TypeDecision decision, HeaderDto header, Crew__c crew, WEX_GPS_Position__c gps,
                                               WorkOrder workOrder, Aqua_Check_Ticket__c aquaCheck, Aqua_Pickup_Ticket__c aquaPickup) {
        List<RowDto> rows = new List<RowDto>();
        rows.add(row('Assigned Resource', header.assignedResource, 'Primary AssignedResource row'));
        rows.add(row('Crew', crew == null ? 'Not mapped' : crew.Name, crew == null ? 'Crew__c not linked from ServiceResource' : blankToDash(crew.Foreman__r == null ? null : crew.Foreman__r.Name)));
        rows.add(row('Vehicle', crew == null || crew.Vehicle__r == null ? 'Unassigned' : crew.Vehicle__r.Name, 'Salesforce Crew__c.Vehicle__c is the source of truth'));
        rows.add(row('GPS Vehicle', gps == null || gps.Vehicle__r == null ? 'Not resolved' : gps.Vehicle__r.Name, 'Latest WEX_GPS_Position__c vehicle match'));

        if (decision.key == 'takeoff') {
            rows.add(row('Takeoff Due Window', header.scheduledWindow, 'Use this appointment window as the active takeoff target'));
        } else if (decision.key == 'aquaCheck') {
            rows.add(row('Check Ticket Assignee', aquaCheck == null || aquaCheck.Assigned_To__r == null ? header.assignedResource : aquaCheck.Assigned_To__r.Name, 'Aqua queue owner'));
        } else if (decision.key == 'aquaPickup') {
            rows.add(row('Pickup Ticket Assignee', aquaPickup == null || aquaPickup.Assigned_To__r == null ? header.assignedResource : aquaPickup.Assigned_To__r.Name, 'Aqua queue owner'));
        } else if (decision.key == 'siteVisit' || decision.key == 'customerSuccess') {
            rows.add(row('Customer Visit Window', header.scheduledWindow, 'Keep the homeowner visit window close to the route context'));
        } else if (decision.key == 'siteReadiness' || decision.key == 'fmReview') {
            rows.add(row('Field Review Window', header.scheduledWindow, 'Manager review route context'));
        } else if (workOrder != null) {
            rows.add(row('Field Manager', header.fieldManager, 'WorkOrder owner'));
        }
        return rows;
    }

    private static List<RowDto> buildContextRows(TypeDecision decision, HeaderDto header, WorkOrder workOrder, Purchase_Order__c po,
                                                 Aqua_Check_Ticket__c aquaCheck, Aqua_Pickup_Ticket__c aquaPickup,
                                                 Aqua_Watering_Schedule__c aquaSchedule) {
        List<RowDto> rows = new List<RowDto>();
        if (decision.key == 'productionInstall' || decision.key == 'takeoff' || decision.key == 'siteReadiness' || decision.key == 'fmReview') {
            rows.add(row('Builder', header.builderName, 'From linked Builder PO when available'));
            rows.add(row('Community', header.communityName, 'From linked Builder PO when available'));
            rows.add(row('Lot', header.lotName, 'From linked Builder PO when available'));
            rows.add(row('Builder PO', header.poNumber, 'Primary builder-side PO record'));
            rows.add(row('Parent Work Order', header.workOrderNumber, header.workOrderSubject));
        } else if (decision.key == 'aquaCheck') {
            rows.add(row('Aqua Check Ticket', aquaCheck == null ? 'Not resolved' : aquaCheck.Name, 'Ticket resolved from the live appointment subject when available'));
            rows.add(row('Lot', inferLotName(aquaCheck, aquaPickup), 'Live Aqua lot'));
            rows.add(row('Billing Reason', aquaCheck == null ? 'Not captured' : blankToDash(aquaCheck.Billing_Reason_Code__c), 'Blank means routine check flow'));
            rows.add(row('Check Number', aquaCheck == null ? 'Not captured' : blankToDash(String.valueOf(aquaCheck.Check_Number__c)), 'Check cadence on the Aqua ticket'));
            rows.add(row('Schedule Program', aquaSchedule == null ? 'Not linked' : scheduleDetail(aquaSchedule), 'Watering schedule stays truthful to live org data'));
        } else if (decision.key == 'aquaPickup') {
            rows.add(row('Aqua Pickup Ticket', aquaPickup == null ? 'Not resolved' : aquaPickup.Name, 'Ticket resolved from the live appointment subject when available'));
            rows.add(row('Lot', inferLotName(aquaCheck, aquaPickup), 'Live Aqua lot'));
            rows.add(row('Assigned Tech', aquaPickup == null || aquaPickup.Assigned_To__r == null ? header.assignedResource : aquaPickup.Assigned_To__r.Name, 'Pickup queue owner'));
            rows.add(row('Scheduled Pickup Date', aquaPickup == null ? 'Not available' : blankToDash(String.valueOf(aquaPickup.Scheduled_Date__c)), 'Live pickup queue date'));
            rows.add(row('Parent Work Order', header.workOrderNumber, header.workOrderSubject));
        } else if (decision.key == 'siteVisit' || decision.key == 'customerSuccess') {
            rows.add(row('Account', workOrder == null || workOrder.Account == null ? 'Not linked' : workOrder.Account.Name, 'Primary customer account'));
            rows.add(row('Contact', workOrder == null || workOrder.Contact == null ? 'Not linked' : workOrder.Contact.Name, workOrder == null || workOrder.Contact == null ? 'No contact linked' : firstNonBlank(workOrder.Contact.Email, workOrder.Contact.Phone, 'Contact linked')));
            rows.add(row('Case', workOrder == null || workOrder.Case == null ? 'Not linked' : workOrder.Case.CaseNumber, workOrder == null || workOrder.Case == null ? 'No case linked' : blankToDash(workOrder.Case.Subject)));
            rows.add(row('Visit / Issue Status', workOrder == null ? 'Unknown' : blankToDash(workOrder.Status), 'Customer-success field execution state'));
            rows.add(row('Parent Work Order', header.workOrderNumber, header.workOrderSubject));
        } else {
            rows.add(row('Parent Work Order', header.workOrderNumber, header.workOrderSubject));
            rows.add(row('Appointment Type', header.appointmentType, header.appointmentTypeSource));
            rows.add(row('Assigned Resource', header.assignedResource, 'Primary dispatch owner'));
            rows.add(row('Field Manager', header.fieldManager, 'Owner when linked'));
        }
        return rows;
    }

    private static List<RowDto> buildProofRows(TypeDecision decision, HeaderDto header, WorkOrder workOrder, Purchase_Order__c po,
                                               Aqua_Check_Ticket__c aquaCheck, Aqua_Pickup_Ticket__c aquaPickup,
                                               Aqua_Watering_Schedule__c aquaSchedule, Integer fileCount, Integer photoCount, Integer noteCount) {
        List<RowDto> rows = new List<RowDto>();
        if (workOrder != null) {
            rows.add(row('Work Order Status', blankToDash(workOrder.Status), 'WorkOrder.Status'));
            rows.add(row('QI Status', blankToDash((String) workOrder.get('QI_Status__c')), 'WorkOrder.QI_Status__c'));
            rows.add(row('Files', String.valueOf(fileCount), 'ContentDocumentLink count on the linked WorkOrder'));
            rows.add(row('Photos', String.valueOf(photoCount), 'Photo__c count on the linked WorkOrder'));
            rows.add(row('Notes', String.valueOf(noteCount), 'Note count on the linked WorkOrder'));
            rows.add(row(
                'Invoice Amount',
                workOrder.get('Invoice_Amount__c') == null ? '—' : '$' + String.valueOf(workOrder.get('Invoice_Amount__c')),
                'WorkOrder.Invoice_Amount__c'
            ));
        }
        if (decision.key == 'takeoff' && po != null) {
            rows.add(row('Takeoff Status', blankToDash(po.Takeoff_Status__c), 'Purchase_Order__c.Takeoff_Status__c'));
            rows.add(row('Builder PO Status', blankToDash(po.Status__c), 'Purchase_Order__c.Status__c'));
        } else if (decision.key == 'aquaCheck') {
            rows.add(row('Billing Reason Code', aquaCheck == null ? '—' : blankToDash(aquaCheck.Billing_Reason_Code__c), 'Aqua_Check_Ticket__c.Billing_Reason_Code__c'));
            if (aquaSchedule != null) {
                rows.add(row('Watering Schedule', scheduleDetail(aquaSchedule), 'Aqua_Watering_Schedule__c'));
            }
        } else if (decision.key == 'aquaPickup' && aquaPickup != null) {
            rows.add(row('Scheduled Pickup Date', blankToDash(String.valueOf(aquaPickup.Scheduled_Date__c)), 'Aqua_Pickup_Ticket__c.Scheduled_Date__c'));
        } else if ((decision.key == 'siteVisit' || decision.key == 'customerSuccess') && workOrder != null && workOrder.Case != null) {
            rows.add(row('Case Status', blankToDash(workOrder.Case.Status), 'Case.Status'));
        }
        return rows;
    }

    private static Aqua_Check_Ticket__c loadAquaCheck(TypeDecision decision, String trailingToken) {
        if (decision.key != 'aquaCheck' || String.isBlank(trailingToken)) {
            return null;
        }
        List<Aqua_Check_Ticket__c> rows = [
            SELECT Id, Name, Lot__r.Name, Assigned_To__r.Name, Billing_Reason_Code__c,
                   Scheduled_Date__c, Check_Number__c, Final_Run_Time_Min__c, Community__c
            FROM Aqua_Check_Ticket__c
            WHERE Id = :trailingToken
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Aqua_Pickup_Ticket__c loadAquaPickup(TypeDecision decision, String trailingToken) {
        if (decision.key != 'aquaPickup' || String.isBlank(trailingToken)) {
            return null;
        }
        List<Aqua_Pickup_Ticket__c> rows = [
            SELECT Id, Name, Lot__r.Name, Assigned_To__r.Name, Scheduled_Date__c, Community__c
            FROM Aqua_Pickup_Ticket__c
            WHERE Id = :trailingToken
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Aqua_Watering_Schedule__c loadAquaSchedule(Aqua_Check_Ticket__c aquaCheck, Aqua_Pickup_Ticket__c aquaPickup) {
        Id communityId = aquaCheck != null ? aquaCheck.Community__c : (aquaPickup != null ? aquaPickup.Community__c : null);
        if (communityId == null) {
            return null;
        }
        String monthName = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).format('MMMM');
        List<Aqua_Watering_Schedule__c> rows = [
            SELECT Id, Community__c, Month__c, Effective_Year__c, Run_Time_Pct__c, Run_Frequency__c, Run_Duration_Min__c
            FROM Aqua_Watering_Schedule__c
            WHERE Community__c = :communityId
              AND Month__c = :monthName
            ORDER BY Effective_Year__c DESC, LastModifiedDate DESC
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            return rows[0];
        }
        rows = [
            SELECT Id, Community__c, Month__c, Effective_Year__c, Run_Time_Pct__c, Run_Frequency__c, Run_Duration_Min__c
            FROM Aqua_Watering_Schedule__c
            WHERE Community__c = :communityId
            ORDER BY Effective_Year__c DESC, LastModifiedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static String primaryContextValue(HeaderDto header, WorkOrder workOrder, Purchase_Order__c po) {
        if (header.appointmentTypeKey == 'customerSuccess' || header.appointmentTypeKey == 'siteVisit') {
            return workOrder != null && workOrder.Account != null ? workOrder.Account.Name : 'Customer context not linked';
        }
        if (header.appointmentTypeKey == 'aquaCheck' || header.appointmentTypeKey == 'aquaPickup') {
            return header.lotName;
        }
        return header.builderName;
    }

    private static String primaryContextDetail(HeaderDto header, WorkOrder workOrder, Purchase_Order__c po) {
        if (header.appointmentTypeKey == 'customerSuccess' || header.appointmentTypeKey == 'siteVisit') {
            return workOrder != null && workOrder.Contact != null ? blankToDash(workOrder.Contact.Name) : 'Homeowner/contact not linked';
        }
        if (header.appointmentTypeKey == 'aquaCheck' || header.appointmentTypeKey == 'aquaPickup') {
            return header.communityName != 'Not linked' ? header.communityName : 'Aqua lot context';
        }
        return po == null ? 'No Builder PO linked yet' : header.communityName + ' · ' + header.lotName;
    }

    private static String contextKpiLabel(HeaderDto header) {
        if (header == null) return 'Linked Context';
        if (header.appointmentTypeKey == 'customerSuccess') return 'Customer Context';
        if (header.appointmentTypeKey == 'siteVisit') return 'Readiness Context';
        if (header.appointmentTypeKey == 'aquaCheck' || header.appointmentTypeKey == 'aquaPickup') return 'Watering Context';
        return 'Builder Context';
    }

    private static String scheduleDetail(Aqua_Watering_Schedule__c schedule) {
        if (schedule == null) return 'No live Aqua schedule';
        return blankToDash(schedule.Run_Frequency__c) + ' · ' +
            blankToDash(String.valueOf(schedule.Run_Duration_Min__c)) + ' min · ' +
            blankToDash(String.valueOf(schedule.Run_Time_Pct__c)) + '%';
    }

    private static String inferLotName(Aqua_Check_Ticket__c aquaCheck, Aqua_Pickup_Ticket__c aquaPickup) {
        if (aquaCheck != null && aquaCheck.Lot__r != null) return aquaCheck.Lot__r.Name;
        if (aquaPickup != null && aquaPickup.Lot__r != null) return aquaPickup.Lot__r.Name;
        return 'Not linked';
    }

    private static String trailingSubjectToken(String subject) {
        if (String.isBlank(subject) || !subject.contains('|')) return null;
        List<String> tokens = subject.split('\\|');
        if (tokens.isEmpty()) return null;
        String candidate = tokens[tokens.size() - 1].trim();
        if (candidate.length() == 15 || candidate.length() == 18) {
            return candidate;
        }
        return null;
    }

    private static String sourceLabel(String woType, String workTypeName, String subject, String expectedValue,
                                      String woLabel, String workTypeLabel, String subjectLabel) {
        if (equalsIgnoreCase(woType, expectedValue)) return woLabel;
        if (equalsIgnoreCase(workTypeName, expectedValue) || (expectedValue == 'Takeoff' && equalsIgnoreCase(workTypeName, 'Field Manager Takeoff'))) {
            return workTypeLabel;
        }
        if (startsWithIgnoreCase(subject, expectedValue)) return subjectLabel;
        return 'Fallback';
    }

    private static String formatWindow(ServiceAppointment appointment) {
        if (appointment == null || appointment.SchedStartTime == null) return 'Not scheduled';
        String startLabel = appointment.SchedStartTime.format('M/d/yyyy h:mm a');
        if (appointment.SchedEndTime == null) return startLabel;
        return startLabel + ' – ' + appointment.SchedEndTime.format('h:mm a');
    }

    private static KpiDto kpi(String label, String value, String detail, String tone) {
        KpiDto dto = new KpiDto();
        dto.label = label;
        dto.value = blankToDash(value);
        dto.detail = blankToDash(detail);
        dto.tone = tone;
        return dto;
    }

    private static RowDto row(String label, String value, String note) {
        RowDto dto = new RowDto();
        dto.label = label;
        dto.value = blankToDash(value);
        dto.note = blankToDash(note);
        return dto;
    }

    private static ActivityDto activity(String label, String detail, String whenLabel) {
        ActivityDto dto = new ActivityDto();
        dto.label = label;
        dto.detail = blankToDash(detail);
        dto.whenLabel = blankToDash(whenLabel);
        return dto;
    }

    private static String fullAddress(String street, String city, String state, String postalCode) {
        List<String> parts = new List<String>();
        if (!String.isBlank(street)) parts.add(street);
        String cityLine = '';
        if (!String.isBlank(city)) cityLine += city;
        if (!String.isBlank(state)) cityLine += (String.isBlank(cityLine) ? '' : ', ') + state;
        if (!String.isBlank(postalCode)) cityLine += (String.isBlank(cityLine) ? '' : ' ') + postalCode;
        if (!String.isBlank(cityLine)) parts.add(cityLine);
        return parts.isEmpty() ? 'Address not available' : String.join(parts, ' · ');
    }

    private static Boolean equalsIgnoreCase(String left, String right) {
        return left != null && right != null && left.trim().toLowerCase() == right.trim().toLowerCase();
    }

    private static Boolean startsWithIgnoreCase(String value, String prefix) {
        return value != null && prefix != null && value.trim().toLowerCase().startsWith(prefix.trim().toLowerCase());
    }

    private static String blankToDash(String input) {
        return String.isBlank(input) ? '—' : input;
    }

    private static String firstNonBlank(String a, String b, String c) {
        if (!String.isBlank(a)) return a;
        if (!String.isBlank(b)) return b;
        if (!String.isBlank(c)) return c;
        return '—';
    }
}