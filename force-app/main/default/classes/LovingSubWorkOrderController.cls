/**
 * LovingSubWorkOrderController
 *
 * Apex controller for the lovingSubWorkOrderPage LWC.
 * Routes to type-specific service (FJ / Warranty / Customer Care) and
 * returns a SubWorkOrderPageDTO.
 *
 * @group Work Order Page
 */
public with sharing class LovingSubWorkOrderController {

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static SubWorkOrderPageDTO getSubWorkOrderPageData(Id workOrderId) {
        if (workOrderId == null) {
            throw new AuraHandledException('workOrderId is required');
        }

        Work_Order__c wo = queryWorkOrder(workOrderId);

        if (wo == null) {
            throw new AuraHandledException('Work Order not found: ' + workOrderId);
        }

        String woType = wo.Work_Order_Type__c;

        SubWorkOrderPageDTO dto;

        if (woType == 'Finished Job' || wo.Is_Finish_Job__c == true) {
            dto = LovingFinishedJobService.buildPageData(wo);
        } else if (woType == 'Warranty') {
            dto = LovingWarrantyService.buildPageData(wo);
        } else if (woType == 'Customer Care' || woType == 'Site Visit') {
            dto = LovingCustomerCareWorkOrderService.buildPageData(wo);
        } else {
            // Fallback: return empty FJ DTO with warning
            SubWorkOrderPageDTO fallback = new SubWorkOrderPageDTO();
            fallback.warnings = new List<SubWorkOrderPageDTO.WarningDTO>();
            SubWorkOrderPageDTO.WarningDTO w = new SubWorkOrderPageDTO.WarningDTO();
            w.key      = 'UNSUPPORTED_TYPE';
            w.message  = 'Work Order type "' + woType + '" is not a supported sub-work-order type.';
            w.severity = 'error';
            fallback.warnings.add(w);
            dto = fallback;
        }
        enrichWithServiceAppointment(dto, workOrderId);
        enrichRichStructures(dto, wo);
        return dto;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SOQL
    // ─────────────────────────────────────────────────────────────────────────

    private static Work_Order__c queryWorkOrder(Id workOrderId) {
        List<Work_Order__c> results = [
            SELECT
                Id, Name, Work_Order_Type__c, Status__c, Pipeline_Stage__c, Sub_Status__c,
                Job_Health__c, Billable_Type__c, Repair_Scope__c, Notes__c, Closeout_Notes__c,
                Schedule_Locked__c, Scheduled_Date__c,
                Field_Manager__c, Crew__c, Stop_Sequence__c, Foreman__c,
                Parent_Work_Order__c, Parent_Account__c, Community__c, Lot__c,
                Builder_PO__c, Takeoff__c, Invoice_Generated__c, Closing_Invoice__c,
                Construction_Manager__c, Territory__c,
                Source__c, Request_Received_Date__c,
                Is_Finish_Job__c, Is_Warranty__c,
                FJ_Reason_Code__c, FJ_Reason_Detail__c,
                FJ_Created_By_FM__c, FJ_Original_Foreman__c,
                FJ_Created_By_FM__r.Name,
                FJ_Original_Foreman__r.Name,
                Warranty_Coverage_Status__c, Warranty_Coverage_Type__c,
                Warranty_Start_Date__c, Warranty_End_Date__c,
                Warranty_Voided_Reason__c, Warranty_Determination__c,
                EPO_Status__c, EPO_Sent_Date__c, EPO_Received_Date__c,
                EPO_Days_Outstanding__c, EPO_SLA_Tier__c, EPO_SLA_Breach__c,
                /* Relationship traversal */
                Field_Manager__r.Name,
                Foreman__r.Name,
                Construction_Manager__r.Name,
                Community__r.Name,
                Lot__r.Name,
                /* Parent WO summary (1-level deep only) */
                Parent_Work_Order__r.Id,
                Parent_Work_Order__r.Name,
                Parent_Work_Order__r.Status__c,
                Parent_Work_Order__r.Builder_PO__c,
                Parent_Work_Order__r.Takeoff__c,
                Parent_Work_Order__r.Scheduled_Date__c,
                Parent_Work_Order__r.Field_Manager__r.Name,
                Parent_Work_Order__r.Community__r.Name,
                Parent_Work_Order__r.Lot__r.Name
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0];
    }

    private static void enrichWithServiceAppointment(SubWorkOrderPageDTO dto, Id workOrderId) {
        if (dto == null || workOrderId == null) {
            return;
        }
        List<ServiceAppointment> appointments = [
            SELECT Id, AppointmentNumber
            FROM ServiceAppointment
            WHERE ParentRecordId = :workOrderId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (appointments.isEmpty()) {
            return;
        }
        ServiceAppointment appointment = appointments[0];
        if (dto.header == null) {
            dto.header = new SubWorkOrderPageDTO.HeaderDTO();
        }
        dto.header.serviceAppointmentId = appointment.Id;
        dto.header.serviceAppointmentNumber = appointment.AppointmentNumber;

        if (dto.scheduleSummary == null) {
            dto.scheduleSummary = new SubWorkOrderPageDTO.ScheduleSummaryDTO();
        }
        dto.scheduleSummary.serviceAppointmentId = appointment.Id;
        dto.scheduleSummary.serviceAppointmentNumber = appointment.AppointmentNumber;
    }

    private static void enrichRichStructures(SubWorkOrderPageDTO dto, Work_Order__c wo) {
        if (dto == null || wo == null) {
            return;
        }
        Set<Id> relatedWorkOrderIds = relatedWorkOrderIds(wo);
        dto.takeoffLines = buildTakeoffLines(wo, relatedWorkOrderIds);
        dto.aquaTickets = buildAquaTickets(relatedWorkOrderIds);
        dto.workOrderLineItems = buildWorkOrderLineItems(relatedWorkOrderIds);
        dto.siteVisits = buildSiteVisits(wo, relatedWorkOrderIds);
        dto.healthChecks = buildHealthChecks(relatedWorkOrderIds);
        dto.invoicePreview = buildInvoicePreview(wo, relatedWorkOrderIds);
    }

    private static Set<Id> relatedWorkOrderIds(Work_Order__c wo) {
        Set<Id> ids = new Set<Id>();
        if (wo.Id != null) {
            ids.add(wo.Id);
        }
        if (wo.Parent_Work_Order__c != null) {
            ids.add(wo.Parent_Work_Order__c);
        }
        return ids;
    }

    private static List<SubWorkOrderPageDTO.TakeoffLineDTO> buildTakeoffLines(
        Work_Order__c wo,
        Set<Id> relatedWorkOrderIds
    ) {
        List<SubWorkOrderPageDTO.TakeoffLineDTO> out = new List<SubWorkOrderPageDTO.TakeoffLineDTO>();
        Set<Id> takeoffIds = new Set<Id>();
        if (wo.Takeoff__c != null) {
            takeoffIds.add(wo.Takeoff__c);
        }
        if (wo.Parent_Work_Order__r != null && wo.Parent_Work_Order__r.Takeoff__c != null) {
            takeoffIds.add(wo.Parent_Work_Order__r.Takeoff__c);
        }

        Set<Id> builderPoIds = new Set<Id>();
        if (wo.Builder_PO__c != null) {
            builderPoIds.add(wo.Builder_PO__c);
        }
        if (wo.Parent_Work_Order__r != null && wo.Parent_Work_Order__r.Builder_PO__c != null) {
            builderPoIds.add(wo.Parent_Work_Order__r.Builder_PO__c);
        }

        if (!relatedWorkOrderIds.isEmpty() || !builderPoIds.isEmpty()) {
            for (Takeoff__c takeoff : [
                SELECT Id
                FROM Takeoff__c
                WHERE Id IN :takeoffIds
                   OR Work_Order__c IN :relatedWorkOrderIds
                   OR Builder_PO__c IN :builderPoIds
                LIMIT 50
            ]) {
                takeoffIds.add(takeoff.Id);
            }
        }
        if (takeoffIds.isEmpty()) {
            return out;
        }

        for (Takeoff_Line__c line : [
            SELECT Id, Name, Takeoff__c, Item_Name__c, Item_Description__c, Material_Code__c,
                   PO_Quantity__c, Measured_Quantity__c, Verified_Quantity__c, Variance__c,
                   Execution_Scope__c, Determination__c, Unit__c,
                   Unit_Price__c, Sort_Order__c, Notes__c
            FROM Takeoff_Line__c
            WHERE Takeoff__c IN :takeoffIds
            ORDER BY Sort_Order__c NULLS LAST, Name
            LIMIT 500
        ]) {
            SubWorkOrderPageDTO.TakeoffLineDTO row = new SubWorkOrderPageDTO.TakeoffLineDTO();
            row.id = line.Id;
            row.takeoffId = line.Takeoff__c;
            row.name = line.Name;
            row.itemName = line.Item_Name__c;
            row.materialCode = line.Material_Code__c;
            row.description = line.Item_Description__c;
            row.poQuantity = line.PO_Quantity__c;
            row.measuredQuantity = line.Measured_Quantity__c;
            row.verifiedQuantity = line.Verified_Quantity__c;
            row.variance = line.Variance__c;
            row.executionScope = line.Execution_Scope__c;
            row.determination = line.Determination__c;
            row.unit = line.Unit__c;
            row.unitPrice = line.Unit_Price__c;
            row.sortOrder = line.Sort_Order__c == null ? null : line.Sort_Order__c.intValue();
            row.notes = line.Notes__c;
            out.add(row);
        }
        return out;
    }

    private static List<SubWorkOrderPageDTO.WorkOrderLineDTO> buildWorkOrderLineItems(Set<Id> relatedWorkOrderIds) {
        List<SubWorkOrderPageDTO.WorkOrderLineDTO> out = new List<SubWorkOrderPageDTO.WorkOrderLineDTO>();
        if (relatedWorkOrderIds == null || relatedWorkOrderIds.isEmpty()) {
            return out;
        }
        Map<String, Schema.SObjectField> fields =
            Schema.SObjectType.Work_Order_Line_Item__c.fields.getMap();
        if (!fields.containsKey('Work_Order__c')) {
            return out;
        }

        List<String> selectedFields = existingFields(fields, new List<String>{
            'Id', 'Name', 'Package_Item__c', 'Description__c', 'Quantity__c',
            'Unit_Of_Measure__c', 'Unit_Price__c', 'Total_Price__c', 'Unit_Cost__c',
            'Goal_Minutes__c', 'Actual_Minutes__c', 'Goal_Headcount__c', 'Source__c',
            'Billable_or_Warranty__c', 'Inventory_Required__c', 'Is_Manual__c',
            'Sequence__c', 'Notes__c', 'Takeoff_Line__c'
        });
        String queryText = 'SELECT ' + String.join(selectedFields, ',') +
            ' FROM Work_Order_Line_Item__c' +
            ' WHERE Work_Order__c IN :relatedWorkOrderIds' +
            ' ORDER BY Sequence__c NULLS LAST, Name LIMIT 500';

        for (SObject sob : Database.query(queryText)) {
            SubWorkOrderPageDTO.WorkOrderLineDTO row = new SubWorkOrderPageDTO.WorkOrderLineDTO();
            row.id = stringValue(sob, fields, 'Id');
            row.name = stringValue(sob, fields, 'Name');
            row.packageItem = stringValue(sob, fields, 'Package_Item__c');
            row.description = stringValue(sob, fields, 'Description__c');
            row.quantity = decimalValue(sob, fields, 'Quantity__c');
            row.unitOfMeasure = stringValue(sob, fields, 'Unit_Of_Measure__c');
            row.unitPrice = decimalValue(sob, fields, 'Unit_Price__c');
            row.totalPrice = decimalValue(sob, fields, 'Total_Price__c');
            row.unitCost = decimalValue(sob, fields, 'Unit_Cost__c');
            row.goalMinutes = decimalValue(sob, fields, 'Goal_Minutes__c');
            row.actualMinutes = decimalValue(sob, fields, 'Actual_Minutes__c');
            row.goalHeadcount = decimalValue(sob, fields, 'Goal_Headcount__c');
            row.source = stringValue(sob, fields, 'Source__c');
            row.billableOrWarranty = stringValue(sob, fields, 'Billable_or_Warranty__c');
            row.inventoryRequired = booleanValue(sob, fields, 'Inventory_Required__c');
            row.isManual = booleanValue(sob, fields, 'Is_Manual__c');
            row.sequence = integerValue(sob, fields, 'Sequence__c');
            row.notes = stringValue(sob, fields, 'Notes__c');
            row.takeoffLineId = stringValue(sob, fields, 'Takeoff_Line__c');
            out.add(row);
        }
        return out;
    }

    private static List<SubWorkOrderPageDTO.AquaTicketDTO> buildAquaTickets(Set<Id> relatedWorkOrderIds) {
        List<SubWorkOrderPageDTO.AquaTicketDTO> out = new List<SubWorkOrderPageDTO.AquaTicketDTO>();
        if (relatedWorkOrderIds == null || relatedWorkOrderIds.isEmpty()) {
            return out;
        }

        for (Aqua_Install_Ticket__c ticket : [
            SELECT Id, Name, Status__c, Scheduled_Date__c, Closed_Date__c,
                   FM_Assignment__r.Name, Tech__r.Name, Heads_Count__c, Aqua_Flags_Required__c,
                   Measuring_Cups_Required__c, Controller_Count__c, Closeout_Notes__c,
                   Close_Notes__c, Device_Installed__c, Timer_Tested__c, Coverage_Verified__c,
                   Inventory_Recorded__c, Photos_Uploaded__c
            FROM Aqua_Install_Ticket__c
            WHERE LOVING_Work_Order__c IN :relatedWorkOrderIds
               OR Work_Order__c IN :relatedWorkOrderIds
            ORDER BY Scheduled_Date__c DESC NULLS LAST, LastModifiedDate DESC
            LIMIT 100
        ]) {
            SubWorkOrderPageDTO.AquaTicketDTO row = new SubWorkOrderPageDTO.AquaTicketDTO();
            row.id = ticket.Id;
            row.ticketType = 'Install';
            row.name = ticket.Name;
            row.status = ticket.Status__c;
            row.scheduledDate = ticket.Scheduled_Date__c;
            row.closedDate = ticket.Closed_Date__c;
            row.assignedToName = ticket.FM_Assignment__r == null ? null : ticket.FM_Assignment__r.Name;
            row.techName = ticket.Tech__r == null ? null : ticket.Tech__r.Name;
            row.headsCount = ticket.Heads_Count__c;
            row.flagsCount = ticket.Aqua_Flags_Required__c;
            row.measuringCups = ticket.Measuring_Cups_Required__c;
            row.controllerCount = ticket.Controller_Count__c;
            row.notes = String.isNotBlank(ticket.Closeout_Notes__c) ? ticket.Closeout_Notes__c : ticket.Close_Notes__c;
            row.deviceInstalled = ticket.Device_Installed__c;
            row.timerTested = ticket.Timer_Tested__c;
            row.coverageVerified = ticket.Coverage_Verified__c;
            row.inventoryRecorded = ticket.Inventory_Recorded__c;
            row.photosUploaded = ticket.Photos_Uploaded__c;
            out.add(row);
        }

        for (Aqua_Check_Ticket__c ticket : [
            SELECT Id, Name, Status__c, Scheduled_Date__c, Closed_Date__c,
                   Assigned_To__r.Name, Final_Run_Time_Min__c, Billing_Reason_Code__c,
                   Check_Notes__c, Device_Present__c, Device_Functioning__c,
                   Turf_Condition_Score__c, Landscape_Score__c
            FROM Aqua_Check_Ticket__c
            WHERE LOVING_Work_Order__c IN :relatedWorkOrderIds
            ORDER BY Scheduled_Date__c DESC NULLS LAST, LastModifiedDate DESC
            LIMIT 100
        ]) {
            SubWorkOrderPageDTO.AquaTicketDTO row = new SubWorkOrderPageDTO.AquaTicketDTO();
            row.id = ticket.Id;
            row.ticketType = 'Check';
            row.name = ticket.Name;
            row.status = ticket.Status__c;
            row.scheduledDate = ticket.Scheduled_Date__c;
            row.closedDate = ticket.Closed_Date__c;
            row.assignedToName = ticket.Assigned_To__r == null ? null : ticket.Assigned_To__r.Name;
            row.finalRunTimeMin = ticket.Final_Run_Time_Min__c;
            row.billingReasonCode = ticket.Billing_Reason_Code__c;
            row.notes = ticket.Check_Notes__c;
            row.deviceInstalled = ticket.Device_Present__c;
            row.timerTested = ticket.Device_Functioning__c;
            out.add(row);
        }
        return out;
    }

    private static List<SubWorkOrderPageDTO.SiteVisitDTO> buildSiteVisits(
        Work_Order__c wo,
        Set<Id> relatedWorkOrderIds
    ) {
        List<SubWorkOrderPageDTO.SiteVisitDTO> out = new List<SubWorkOrderPageDTO.SiteVisitDTO>();
        Set<Id> parentIds = new Set<Id>();
        if (wo.Id != null) {
            parentIds.add(wo.Id);
        }
        if (wo.Parent_Work_Order__c != null) {
            parentIds.add(wo.Parent_Work_Order__c);
        }
        for (Work_Order__c visit : [
            SELECT Id, Name, Status__c, Sub_Status__c, Scheduled_Date__c,
                   Scheduled_Start_DateTime__c, Scheduled_End_DateTime__c,
                   Field_Manager__r.Name, Foreman__r.Name, Crew__c, Job_Health__c, Notes__c
            FROM Work_Order__c
            WHERE (Id IN :relatedWorkOrderIds OR Parent_Work_Order__c IN :parentIds)
              AND Work_Order_Type__c = 'Site Visit'
            ORDER BY Scheduled_Date__c DESC NULLS LAST, LastModifiedDate DESC
            LIMIT 100
        ]) {
            SubWorkOrderPageDTO.SiteVisitDTO row = new SubWorkOrderPageDTO.SiteVisitDTO();
            row.id = visit.Id;
            row.name = visit.Name;
            row.status = visit.Status__c;
            row.subStatus = visit.Sub_Status__c;
            row.scheduledDate = visit.Scheduled_Date__c;
            row.scheduledStart = visit.Scheduled_Start_DateTime__c;
            row.scheduledEnd = visit.Scheduled_End_DateTime__c;
            row.fmName = visit.Field_Manager__r == null ? null : visit.Field_Manager__r.Name;
            row.foremanName = visit.Foreman__r == null ? null : visit.Foreman__r.Name;
            row.crewName = visit.Crew__c;
            row.jobHealth = visit.Job_Health__c;
            row.notes = visit.Notes__c;
            out.add(row);
        }
        return out;
    }

    private static List<SubWorkOrderPageDTO.HealthCheckDTO> buildHealthChecks(Set<Id> relatedWorkOrderIds) {
        List<SubWorkOrderPageDTO.HealthCheckDTO> out = new List<SubWorkOrderPageDTO.HealthCheckDTO>();
        if (relatedWorkOrderIds == null || relatedWorkOrderIds.isEmpty()) {
            return out;
        }
        for (Health_Check_Log__c log : [
            SELECT Id, Check_Date__c, Check_Time__c, Result__c, Decision__c,
                   Recorded_By__r.Name, Notes__c
            FROM Health_Check_Log__c
            WHERE LOVING_Work_Order__c IN :relatedWorkOrderIds
            ORDER BY Check_Time__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 100
        ]) {
            SubWorkOrderPageDTO.HealthCheckDTO row = new SubWorkOrderPageDTO.HealthCheckDTO();
            row.id = log.Id;
            row.checkDate = log.Check_Date__c;
            row.checkTime = log.Check_Time__c;
            row.result = log.Result__c;
            row.decision = log.Decision__c;
            row.recordedByName = log.Recorded_By__r == null ? null : log.Recorded_By__r.Name;
            row.notes = log.Notes__c;
            out.add(row);
        }
        return out;
    }

    private static SubWorkOrderPageDTO.InvoicePreviewDTO buildInvoicePreview(
        Work_Order__c wo,
        Set<Id> relatedWorkOrderIds
    ) {
        SubWorkOrderPageDTO.InvoicePreviewDTO preview = new SubWorkOrderPageDTO.InvoicePreviewDTO();
        preview.lines = new List<SubWorkOrderPageDTO.InvoiceLineDTO>();
        preview.invoiceGenerated = wo.Invoice_Generated__c == true;

        Set<Id> invoiceIds = new Set<Id>();
        if (wo.Closing_Invoice__c != null) {
            invoiceIds.add(wo.Closing_Invoice__c);
        }
        List<Invoice__c> invoices = [
            SELECT Id, Name, Status__c, Payment_Status__c, Invoice_Date__c, Due_Date__c,
                   Total_Revenue__c, Total_Cost__c, GP_Percent__c, GP_Status__c,
                   GP_Approval_Status__c, Amount_Paid__c, Balance_Due__c
            FROM Invoice__c
            WHERE Id IN :invoiceIds
               OR LOVING_Work_Order__c IN :relatedWorkOrderIds
               OR Work_Order__c IN :relatedWorkOrderIds
            ORDER BY Invoice_Date__c DESC NULLS LAST, LastModifiedDate DESC
            LIMIT 1
        ];
        if (invoices.isEmpty()) {
            return preview;
        }

        Invoice__c invoice = invoices[0];
        preview.invoiceGenerated = true;
        preview.invoiceId = invoice.Id;
        preview.invoiceNumber = invoice.Name;
        preview.status = invoice.Status__c;
        preview.paymentStatus = invoice.Payment_Status__c;
        preview.invoiceDate = invoice.Invoice_Date__c;
        preview.dueDate = invoice.Due_Date__c;
        preview.totalRevenue = invoice.Total_Revenue__c;
        preview.totalCost = invoice.Total_Cost__c;
        preview.grossMargin = invoice.Total_Revenue__c == null || invoice.Total_Cost__c == null
            ? null
            : invoice.Total_Revenue__c - invoice.Total_Cost__c;
        preview.grossMarginPct = invoice.GP_Percent__c;
        preview.amountPaid = invoice.Amount_Paid__c;
        preview.balanceDue = invoice.Balance_Due__c;
        preview.gpStatus = invoice.GP_Status__c;
        preview.gpApprovalStatus = invoice.GP_Approval_Status__c;

        for (Invoice_Line_Item__c line : [
            SELECT Id, Name, Description__c, Quantity__c, Unit__c, Unit_Price__c,
                   Unit_Cost__c, Line_Total__c, Line_Cost__c, Gross_Margin__c,
                   Gross_Margin_Pct__c, Billable__c, Sort_Order__c
            FROM Invoice_Line_Item__c
            WHERE Invoice__c = :invoice.Id
            ORDER BY Sort_Order__c NULLS LAST, Name
            LIMIT 200
        ]) {
            SubWorkOrderPageDTO.InvoiceLineDTO row = new SubWorkOrderPageDTO.InvoiceLineDTO();
            row.id = line.Id;
            row.name = line.Name;
            row.description = line.Description__c;
            row.quantity = line.Quantity__c;
            row.unit = line.Unit__c;
            row.unitPrice = line.Unit_Price__c;
            row.unitCost = line.Unit_Cost__c;
            row.lineTotal = line.Line_Total__c;
            row.lineCost = line.Line_Cost__c;
            row.grossMargin = line.Gross_Margin__c;
            row.grossMarginPct = line.Gross_Margin_Pct__c;
            row.billable = line.Billable__c;
            row.sortOrder = line.Sort_Order__c == null ? null : line.Sort_Order__c.intValue();
            preview.lines.add(row);
        }
        return preview;
    }

    private static List<String> existingFields(
        Map<String, Schema.SObjectField> fields,
        List<String> requested
    ) {
        List<String> out = new List<String>();
        for (String fieldName : requested) {
            if (fields.containsKey(fieldName)) {
                out.add(fieldName);
            }
        }
        return out;
    }

    private static String stringValue(SObject sob, Map<String, Schema.SObjectField> fields, String fieldName) {
        if (!fields.containsKey(fieldName)) {
            return null;
        }
        Object value = sob.get(fieldName);
        return value == null ? null : String.valueOf(value);
    }

    private static Decimal decimalValue(SObject sob, Map<String, Schema.SObjectField> fields, String fieldName) {
        if (!fields.containsKey(fieldName)) {
            return null;
        }
        Object value = sob.get(fieldName);
        return value == null ? null : (Decimal) value;
    }

    private static Boolean booleanValue(SObject sob, Map<String, Schema.SObjectField> fields, String fieldName) {
        if (!fields.containsKey(fieldName)) {
            return null;
        }
        Object value = sob.get(fieldName);
        return value == null ? null : (Boolean) value;
    }

    private static Integer integerValue(SObject sob, Map<String, Schema.SObjectField> fields, String fieldName) {
        Decimal value = decimalValue(sob, fields, fieldName);
        return value == null ? null : value.intValue();
    }
}