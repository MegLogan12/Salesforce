public with sharing class LovingWOWorkspaceController {

    public class WorkspaceDto {
        @AuraEnabled public HeaderDto header;
        @AuraEnabled public List<KpiDto> kpis;
        @AuraEnabled public List<LineItemDto> lineItems;
        @AuraEnabled public List<ChildWorkOrderDto> childWorkOrders;
        @AuraEnabled public List<ChildAppointmentDto> childAppointments;
        @AuraEnabled public List<AppointmentDto> relatedAppointments;
        @AuraEnabled public List<TakeoffLineDto> takeoffLines;
        @AuraEnabled public List<ChecklistItemDto> checklistItems;
        @AuraEnabled public List<CheckDto> readinessChecks;
        @AuraEnabled public List<RowDto> blockerRows;
        @AuraEnabled public List<RowDto> reportRows;
        @AuraEnabled public List<RowDto> summaryRows;
        @AuraEnabled public List<RowDto> rollupRows;
        @AuraEnabled public List<RowDto> takeoffRows;
        @AuraEnabled public List<RowDto> recordsRows;
        @AuraEnabled public List<RowDto> handoffRows;
        @AuraEnabled public List<RowDto> closeoutRows;
        @AuraEnabled public List<RowDto> overlayRows;
        @AuraEnabled public List<ActivityDto> activity;
        @AuraEnabled public TakeoffChecklistDto takeoffChecklist;
        @AuraEnabled public List<OptionDto> takeoffStatusOptions;
        @AuraEnabled public List<OptionDto> checklistItemStatusOptions;
        @AuraEnabled public List<OptionDto> takeoffLineScopeOptions;
        @AuraEnabled public Id takeoffId;
        @AuraEnabled public Boolean takeoffChecklistMissing;
    }

    public class HeaderDto {
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String workType;
        @AuraEnabled public String builderName;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String poNumber;
        @AuraEnabled public Id parentWorkOrderId;
        @AuraEnabled public String parentWorkOrderNumber;
        @AuraEnabled public String rootWorkOrderNumber;
        @AuraEnabled public String serviceTerritory;
        @AuraEnabled public String fieldManager;
        @AuraEnabled public Id serviceAppointmentId;
        @AuraEnabled public String serviceAppointmentNumber;
        @AuraEnabled public String serviceAppointmentStatus;
        @AuraEnabled public String serviceAppointmentStart;
        @AuraEnabled public String address;
        @AuraEnabled public String qiStatus;
        @AuraEnabled public String billingState;
        @AuraEnabled public String customerCareState;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Decimal totalCost;
        @AuraEnabled public Decimal grossProfit;
        @AuraEnabled public Integer photoCount;
        @AuraEnabled public Integer childWorkOrderCount;
        @AuraEnabled public Integer childAppointmentCount;
        @AuraEnabled public Boolean isParent;
        @AuraEnabled public Boolean isChild;
    }

    public class KpiDto {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String detail;
        @AuraEnabled public String tone;
    }

    public class LineItemDto {
        @AuraEnabled public String description;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String unit;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal extendedPrice;
        @AuraEnabled public String status;
        @AuraEnabled public String executionScope;
        @AuraEnabled public String reviewStatus;
        @AuraEnabled public String substitutionState;
        @AuraEnabled public String variance;
    }

    public class ChildWorkOrderDto {
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String qiStatus;
        @AuraEnabled public String workType;
        @AuraEnabled public String subject;
        @AuraEnabled public Integer serviceAppointmentCount;
        @AuraEnabled public Integer lineItemCount;
        @AuraEnabled public String blockerState;
    }

    public class ChildAppointmentDto {
        @AuraEnabled public Id serviceAppointmentId;
        @AuraEnabled public String appointmentNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String workType;
        @AuraEnabled public String scheduledWindow;
        @AuraEnabled public String assignedResource;
    }

    public class AppointmentDto {
        @AuraEnabled public Id serviceAppointmentId;
        @AuraEnabled public String appointmentNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String scheduledWindow;
        @AuraEnabled public String serviceTerritory;
        @AuraEnabled public String assignedResource;
    }

    public class TakeoffLineDto {
        @AuraEnabled public Id takeoffLineId;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal orderedQuantity;
        @AuraEnabled public Decimal verifiedQuantity;
        @AuraEnabled public Decimal measuredQuantity;
        @AuraEnabled public String unit;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public String reviewStatus;
        @AuraEnabled public String determination;
        @AuraEnabled public String substitutionState;
        @AuraEnabled public String variance;
        @AuraEnabled public String notes;
        @AuraEnabled public String executionScope;
        @AuraEnabled public String routeState;
    }

    public class TakeoffChecklistDto {
        @AuraEnabled public Id checklistId;
        @AuraEnabled public String checklistType;
        @AuraEnabled public String status;
        @AuraEnabled public String completedBy;
        @AuraEnabled public String completedDate;
        @AuraEnabled public String templateName;
    }

    public class ChecklistItemDto {
        @AuraEnabled public Id checklistItemId;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Boolean photoRequired;
        @AuraEnabled public String notes;
        @AuraEnabled public Decimal sortOrder;
    }

    public class OptionDto {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class CreateChildrenResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public List<Id> childWorkOrderIds;
        @AuraEnabled public Integer childCount;
        @AuraEnabled public Integer childLineItemCount;
    }

    public class CheckDto {
        @AuraEnabled public String label;
        @AuraEnabled public String detail;
        @AuraEnabled public Boolean passed;
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

    @AuraEnabled(cacheable=true)
    public static WorkspaceDto getWorkspace(Id workOrderId) {
        WorkspaceDto dto = new WorkspaceDto();
        dto.header = new HeaderDto();
        dto.kpis = new List<KpiDto>();
        dto.lineItems = new List<LineItemDto>();
        dto.childWorkOrders = new List<ChildWorkOrderDto>();
        dto.childAppointments = new List<ChildAppointmentDto>();
        dto.relatedAppointments = new List<AppointmentDto>();
        dto.takeoffLines = new List<TakeoffLineDto>();
        dto.checklistItems = new List<ChecklistItemDto>();
        dto.readinessChecks = new List<CheckDto>();
        dto.blockerRows = new List<RowDto>();
        dto.reportRows = new List<RowDto>();
        dto.summaryRows = new List<RowDto>();
        dto.rollupRows = new List<RowDto>();
        dto.takeoffRows = new List<RowDto>();
        dto.recordsRows = new List<RowDto>();
        dto.handoffRows = new List<RowDto>();
        dto.closeoutRows = new List<RowDto>();
        dto.overlayRows = new List<RowDto>();
        dto.activity = new List<ActivityDto>();
        dto.takeoffChecklist = new TakeoffChecklistDto();
        dto.takeoffStatusOptions = new List<OptionDto>();
        dto.checklistItemStatusOptions = new List<OptionDto>();
        dto.takeoffLineScopeOptions = new List<OptionDto>();
        dto.takeoffChecklistMissing = false;
        if (workOrderId == null) {
            return dto;
        }

        WorkOrder workOrder = [
            SELECT Id, WorkOrderNumber, Subject, Description, Status, CreatedDate, LastModifiedDate,
                   ParentWorkOrderId, RootWorkOrderId,
                   Work_Order_Type__c, Field_Manager__c, Field_Manager__r.Name,
                   Invoice_Amount__c, QI_Status__c, Total_Cost__c, ClosingCare_Status__c,
                   Street, City, State, PostalCode,
                   ServiceTerritoryId, ServiceTerritory.Name
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        Id bridgeWorkOrderId = workOrder.ParentWorkOrderId == null ? workOrderId : workOrder.ParentWorkOrderId;

        Purchase_Order__c po = null;
        List<Purchase_Order__c> pos = [
            SELECT Id, Name, PO_Number__c, Status__c, Takeoff_Status__c, Estimated_Start_Date__c,
                   Package_BMG_Status__c,
                   Builder_Account__r.Name, Division_Account__r.Name,
                   Community__r.Name, Lot__r.Name, Total_Amount__c, Work_Order__c
            FROM Purchase_Order__c
            WHERE Work_Order__c = :bridgeWorkOrderId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!pos.isEmpty()) {
            po = pos[0];
        }

        Builder_PO__c builderPo = null;
        if (po != null && !String.isBlank(po.PO_Number__c)) {
            List<Builder_PO__c> builderPos = [
                SELECT Id, PO_Number__c, Status__c, Takeoff_Status__c, Exception_Reason__c, Notes__c
                FROM Builder_PO__c
                WHERE PO_Number__c = :po.PO_Number__c
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (!builderPos.isEmpty()) {
                builderPo = builderPos[0];
            }
        }

        WorkOrder parentWorkOrder = null;
        WorkOrder rootWorkOrder = null;
        if (workOrder.ParentWorkOrderId != null) {
            List<WorkOrder> parentRows = [
                SELECT Id, WorkOrderNumber, Subject, Status, Work_Order_Type__c
                FROM WorkOrder
                WHERE Id = :workOrder.ParentWorkOrderId
                LIMIT 1
            ];
            if (!parentRows.isEmpty()) {
                parentWorkOrder = parentRows[0];
            }
        }
        if (workOrder.RootWorkOrderId != null && workOrder.RootWorkOrderId != workOrder.Id) {
            List<WorkOrder> rootRows = [
                SELECT Id, WorkOrderNumber
                FROM WorkOrder
                WHERE Id = :workOrder.RootWorkOrderId
                LIMIT 1
            ];
            if (!rootRows.isEmpty()) {
                rootWorkOrder = rootRows[0];
            }
        }

        ServiceAppointment appointment = null;
        List<ServiceAppointment> appointments = [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, SchedEndTime, EarliestStartTime, CreatedDate
            FROM ServiceAppointment
            WHERE ParentRecordId = :workOrderId
            ORDER BY SchedStartTime DESC NULLS LAST, CreatedDate DESC
            LIMIT 1
        ];
        if (!appointments.isEmpty()) {
            appointment = appointments[0];
        }

        Map<Id, String> assignedByAppointmentId = new Map<Id, String>();
        if (!appointments.isEmpty()) {
            Set<Id> appointmentIds = new Set<Id>();
            for (ServiceAppointment row : appointments) {
                appointmentIds.add(row.Id);
            }
            for (AssignedResource row : [
                SELECT ServiceAppointmentId, ServiceResource.Name
                FROM AssignedResource
                WHERE ServiceAppointmentId IN :appointmentIds
                ORDER BY CreatedDate ASC
            ]) {
                if (!assignedByAppointmentId.containsKey(row.ServiceAppointmentId)) {
                    assignedByAppointmentId.put(row.ServiceAppointmentId, row.ServiceResource == null ? 'Unassigned' : row.ServiceResource.Name);
                }
            }
        }

        AssignedResource assigned = null;
        if (appointment != null) {
            List<AssignedResource> assignedRows = [
                SELECT Id, ServiceResourceId, ServiceResource.Name
                FROM AssignedResource
                WHERE ServiceAppointmentId = :appointment.Id
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!assignedRows.isEmpty()) {
                assigned = assignedRows[0];
            }
        }

        List<WorkOrderLineItem> lineItems = [
            SELECT Id, Description, Quantity, UnitPrice, Status, Source_Takeoff_Line__c
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :workOrderId
            ORDER BY CreatedDate ASC
            LIMIT 100
        ];

        List<WorkOrder> childWorkOrders = [
            SELECT Id, WorkOrderNumber, Status, Subject, Work_Order_Type__c, QI_Status__c
            FROM WorkOrder
            WHERE ParentWorkOrderId = :workOrderId
            ORDER BY CreatedDate ASC
            LIMIT 100
        ];

        Integer fileCount = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :workOrderId];
        Integer noteCount = [SELECT COUNT() FROM Note WHERE ParentId = :workOrderId];
        Integer photoCount = [SELECT COUNT() FROM Photo__c WHERE Work_Order__c = :workOrderId];
        Integer appointmentCount = [SELECT COUNT() FROM ServiceAppointment WHERE ParentRecordId = :workOrderId];
        Decimal totalPrice = 0;

        Set<Id> sourceTakeoffLineIds = new Set<Id>();
        for (WorkOrderLineItem line : lineItems) {
            if ((Id) line.get('Source_Takeoff_Line__c') != null) {
                sourceTakeoffLineIds.add((Id) line.get('Source_Takeoff_Line__c'));
            }
            if (line.Quantity != null && line.UnitPrice != null) {
                totalPrice += line.Quantity * line.UnitPrice;
            }
        }
        Map<Id, Takeoff_Line__c> takeoffLineById = sourceTakeoffLineIds.isEmpty()
            ? new Map<Id, Takeoff_Line__c>()
            : new Map<Id, Takeoff_Line__c>([
                SELECT Id, Unit__c, Execution_Scope__c, Determination__c, Material_Substitution__c, Substitution__c, Variance__c
                FROM Takeoff_Line__c
                WHERE Id IN :sourceTakeoffLineIds
            ]);

        dto.header.workOrderId = workOrder.Id;
        dto.header.workOrderNumber = workOrder.WorkOrderNumber;
        dto.header.subject = String.isBlank(workOrder.Subject) ? 'Builder Work Order' : workOrder.Subject;
        dto.header.status = workOrder.Status;
        dto.header.workType = workOrder.Work_Order_Type__c;
        dto.header.builderName = po == null || po.Builder_Account__r == null ? 'Not linked' : po.Builder_Account__r.Name;
        dto.header.communityName = po == null || po.Community__r == null ? 'Not linked' : po.Community__r.Name;
        dto.header.lotName = po == null || po.Lot__r == null ? 'Not linked' : po.Lot__r.Name;
        dto.header.poNumber = po == null ? 'Not linked' : po.PO_Number__c;
        dto.header.parentWorkOrderId = parentWorkOrder == null ? null : parentWorkOrder.Id;
        dto.header.parentWorkOrderNumber = parentWorkOrder == null ? null : parentWorkOrder.WorkOrderNumber;
        dto.header.rootWorkOrderNumber = rootWorkOrder == null ? dto.header.workOrderNumber : rootWorkOrder.WorkOrderNumber;
        dto.header.serviceTerritory = workOrder.ServiceTerritory == null ? 'Unassigned' : workOrder.ServiceTerritory.Name;
        dto.header.fieldManager = workOrder.Field_Manager__r == null ? 'Unassigned' : workOrder.Field_Manager__r.Name;
        dto.header.serviceAppointmentId = appointment == null ? null : appointment.Id;
        dto.header.serviceAppointmentNumber = appointment == null ? 'Not created' : appointment.AppointmentNumber;
        dto.header.serviceAppointmentStatus = appointment == null ? 'Not created' : appointment.Status;
        dto.header.serviceAppointmentStart = appointment == null || appointment.SchedStartTime == null ? 'Not scheduled' : appointment.SchedStartTime.format('M/d/yyyy h:mm a');
        dto.header.address = fullAddress(workOrder.Street, workOrder.City, workOrder.State, workOrder.PostalCode);
        dto.header.qiStatus = blankToDash((String) workOrder.get('QI_Status__c'));
        dto.header.billingState = billingStateFor(workOrder.Status, (Decimal) workOrder.get('Invoice_Amount__c'));
        dto.header.customerCareState = blankToDash((String) workOrder.get('ClosingCare_Status__c'));
        dto.header.totalPrice = totalPrice;
        dto.header.totalCost = (Decimal) workOrder.get('Total_Cost__c');
        dto.header.grossProfit = dto.header.totalCost == null ? null : totalPrice - dto.header.totalCost;
        dto.header.photoCount = photoCount;
        dto.header.childWorkOrderCount = childWorkOrders.size();
        dto.header.childAppointmentCount = 0;
        dto.header.isParent = workOrder.ParentWorkOrderId == null;
        dto.header.isChild = workOrder.ParentWorkOrderId != null;

        dto.kpis.add(kpi(dto.header.isParent ? 'Master Status' : 'Execution Status', blankToDash(workOrder.Status), workOrder.Work_Order_Type__c, workOrder.ServiceTerritory == null ? 'amber' : 'green'));
        dto.kpis.add(kpi('Child WorkOrders', String.valueOf(childWorkOrders.size()), dto.header.isParent ? 'Execution children on this lot' : 'Execution child record', childWorkOrders.isEmpty() ? 'amber' : 'purple'));
        dto.kpis.add(kpi('Child Appointments', String.valueOf(dto.header.isParent ? dto.header.childAppointmentCount : appointmentCount), dto.header.isParent ? 'Appointments linked under child WorkOrders' : 'Appointments linked to this execution record', appointment == null ? 'amber' : 'blue'));
        dto.kpis.add(kpi('Scope Lines', String.valueOf(lineItems.size()), 'Linked scope lines', lineItems.isEmpty() ? 'amber' : 'green'));
        dto.kpis.add(kpi('Files', String.valueOf(fileCount), 'Linked files', fileCount == 0 ? 'amber' : 'blue'));
        dto.kpis.add(kpi('Photos', String.valueOf(photoCount), 'Linked photos', photoCount == 0 ? 'amber' : 'blue'));
        dto.kpis.add(kpi('Notes', String.valueOf(noteCount), 'Linked notes', noteCount == 0 ? 'amber' : 'blue'));

        dto.summaryRows.add(row('Work Order Number', dto.header.workOrderNumber, 'WorkOrder.WorkOrderNumber'));
        dto.summaryRows.add(row('Lot', dto.header.lotName, 'Linked through Purchase_Order__c.Lot__r'));
        dto.summaryRows.add(row('Builder', dto.header.builderName, 'Linked through Purchase_Order__c.Builder_Account__r'));
        dto.summaryRows.add(row('Community', dto.header.communityName, 'Linked through Purchase_Order__c.Community__r'));
        dto.summaryRows.add(row('Site Address', dto.header.address, 'WorkOrder address fields'));
        dto.summaryRows.add(row('Work Type', blankToDash(dto.header.workType), 'WorkOrder.Work_Order_Type__c'));
        dto.summaryRows.add(row(dto.header.isParent ? 'Master Status' : 'Execution Status', blankToDash(workOrder.Status), 'WorkOrder.Status'));
        dto.summaryRows.add(row('Billing State', dto.header.billingState, 'Derived from WorkOrder.Status and Invoice_Amount__c'));
        dto.summaryRows.add(row('QI Outcome', dto.header.qiStatus, 'WorkOrder.QI_Status__c'));
        dto.summaryRows.add(row('Customer Success State', dto.header.customerCareState, 'WorkOrder.ClosingCare_Status__c'));
        dto.summaryRows.add(row('Builder PO', dto.header.poNumber, 'Linked Purchase_Order__c'));
        if (dto.header.isChild) {
            dto.summaryRows.add(row('Parent WorkOrder', parentWorkOrder == null ? 'Not linked' : parentWorkOrder.WorkOrderNumber, parentWorkOrder == null ? null : blankToDash(parentWorkOrder.Subject)));
        }

        dto.rollupRows.add(row('Root WorkOrder', dto.header.rootWorkOrderNumber, 'WorkOrder.RootWorkOrderId'));
        dto.rollupRows.add(row('Parent WorkOrder', workOrder.ParentWorkOrderId == null ? 'Parent record' : blankToDash(parentWorkOrder == null ? String.valueOf(workOrder.ParentWorkOrderId) : parentWorkOrder.WorkOrderNumber), 'WorkOrder.ParentWorkOrderId'));
        dto.rollupRows.add(row('Direct Child WorkOrders', String.valueOf(childWorkOrders.size()), 'Standard child WorkOrders'));
        dto.rollupRows.add(row('Related ServiceAppointments', String.valueOf(appointmentCount), 'ServiceAppointment.ParentRecordId on this record'));
        dto.rollupRows.add(row('Total Scope Price', currencyOrDash(totalPrice), 'Derived from WorkOrderLineItem quantity x unit price'));
        dto.rollupRows.add(row('Total Cost', currencyOrDash((Decimal) workOrder.get('Total_Cost__c')), 'WorkOrder.Total_Cost__c'));
        dto.rollupRows.add(row('Gross Profit', currencyOrDash(dto.header.grossProfit), 'Derived from total scope price minus WorkOrder.Total_Cost__c'));
        dto.rollupRows.add(row('Invoice Amount', currencyOrDash((Decimal) workOrder.get('Invoice_Amount__c')), 'WorkOrder.Invoice_Amount__c'));
        dto.rollupRows.add(row('Files', String.valueOf(fileCount), 'ContentDocumentLink count'));
        dto.rollupRows.add(row('Photos', String.valueOf(photoCount), 'Photo__c count'));
        dto.rollupRows.add(row('Notes', String.valueOf(noteCount), 'Note count'));
        if (po != null) {
            dto.rollupRows.add(row('Package Validation', blankToDash(po.Package_BMG_Status__c), 'Purchase_Order__c.Package_BMG_Status__c'));
        }

        for (ServiceAppointment currentAppointment : appointments) {
            AppointmentDto item = new AppointmentDto();
            item.serviceAppointmentId = currentAppointment.Id;
            item.appointmentNumber = blankToDash(currentAppointment.AppointmentNumber);
            item.status = blankToDash(currentAppointment.Status);
            item.scheduledWindow = formatWindow(currentAppointment.SchedStartTime, currentAppointment.SchedEndTime);
            item.serviceTerritory = dto.header.serviceTerritory;
            item.assignedResource = assignedByAppointmentId.containsKey(currentAppointment.Id) ? assignedByAppointmentId.get(currentAppointment.Id) : 'Unassigned';
            dto.relatedAppointments.add(item);
        }

        for (WorkOrderLineItem line : lineItems) {
            LineItemDto item = new LineItemDto();
            item.description = blankToDash(line.Description);
            item.quantity = line.Quantity;
            Takeoff_Line__c sourceTakeoffLine = takeoffLineById.get((Id) line.get('Source_Takeoff_Line__c'));
            item.unit = sourceTakeoffLine == null ? '—' : blankToDash(sourceTakeoffLine.Unit__c);
            item.unitPrice = line.UnitPrice;
            item.extendedPrice = line.Quantity == null || line.UnitPrice == null ? null : line.Quantity * line.UnitPrice;
            item.status = blankToDash(line.Status);
            item.executionScope = sourceTakeoffLine == null ? '—' : blankToDash((String) sourceTakeoffLine.get('Execution_Scope__c'));
            item.reviewStatus = sourceTakeoffLine == null ? '—' : blankToDash(sourceTakeoffLine.Determination__c);
            item.substitutionState = sourceTakeoffLine == null ? '—' : ((sourceTakeoffLine.Material_Substitution__c == true || sourceTakeoffLine.Substitution__c == true) ? 'Yes' : 'No');
            item.variance = sourceTakeoffLine == null || sourceTakeoffLine.Variance__c == null ? '—' : String.valueOf(sourceTakeoffLine.Variance__c);
            dto.lineItems.add(item);
        }

        for (WorkOrder child : childWorkOrders) {
            ChildWorkOrderDto item = new ChildWorkOrderDto();
            item.workOrderId = child.Id;
            item.workOrderNumber = child.WorkOrderNumber;
            item.status = blankToDash(child.Status);
            item.qiStatus = blankToDash((String) child.get('QI_Status__c'));
            item.workType = blankToDash((String) child.get('Work_Order_Type__c'));
            item.subject = blankToDash(child.Subject);
            item.serviceAppointmentCount = 0;
            item.lineItemCount = 0;
            item.blockerState = '—';
            dto.childWorkOrders.add(item);
        }

        if (!dto.childWorkOrders.isEmpty()) {
            Set<Id> childIds = new Set<Id>();
            for (ChildWorkOrderDto childDto : dto.childWorkOrders) {
                childIds.add(childDto.workOrderId);
            }
            Map<Id, Integer> saCountsByWorkOrder = new Map<Id, Integer>();
            Map<Id, String> assignedByChildAppointmentId = new Map<Id, String>();
            for (AggregateResult row : [
                SELECT ParentRecordId parentId, COUNT(Id) total
                FROM ServiceAppointment
                WHERE ParentRecordId IN :childIds
                GROUP BY ParentRecordId
            ]) {
                saCountsByWorkOrder.put((Id) row.get('parentId'), (Integer) row.get('total'));
            }

            Map<Id, Integer> lineCountsByWorkOrder = new Map<Id, Integer>();
            for (AggregateResult row : [
                SELECT WorkOrderId workOrderId, COUNT(Id) total
                FROM WorkOrderLineItem
                WHERE WorkOrderId IN :childIds
                GROUP BY WorkOrderId
            ]) {
                lineCountsByWorkOrder.put((Id) row.get('workOrderId'), (Integer) row.get('total'));
            }

            for (ChildWorkOrderDto childDto : dto.childWorkOrders) {
                childDto.serviceAppointmentCount = saCountsByWorkOrder.containsKey(childDto.workOrderId) ? saCountsByWorkOrder.get(childDto.workOrderId) : 0;
                childDto.lineItemCount = lineCountsByWorkOrder.containsKey(childDto.workOrderId) ? lineCountsByWorkOrder.get(childDto.workOrderId) : 0;
                if (childDto.lineItemCount == 0) {
                    childDto.blockerState = 'No scope lines';
                } else if (childDto.serviceAppointmentCount == 0) {
                    childDto.blockerState = 'No appointment';
                } else {
                    childDto.blockerState = 'Clear';
                }
            }

            Map<Id, WorkOrder> childWorkOrdersById = new Map<Id, WorkOrder>([
                SELECT Id, WorkOrderNumber, Work_Order_Type__c
                FROM WorkOrder
                WHERE Id IN :childIds
            ]);
            Set<Id> childAppointmentIds = new Set<Id>();
            List<ServiceAppointment> childAppointmentRows = [
                SELECT Id, AppointmentNumber, Status, SchedStartTime, SchedEndTime, ParentRecordId
                FROM ServiceAppointment
                WHERE ParentRecordId IN :childIds
                ORDER BY SchedStartTime ASC NULLS LAST, CreatedDate ASC
            ];
            for (ServiceAppointment childAppointment : childAppointmentRows) {
                childAppointmentIds.add(childAppointment.Id);
            }
            if (!childAppointmentIds.isEmpty()) {
                for (AssignedResource assignedChild : [
                    SELECT ServiceAppointmentId, ServiceResource.Name
                    FROM AssignedResource
                    WHERE ServiceAppointmentId IN :childAppointmentIds
                    ORDER BY CreatedDate ASC
                ]) {
                    if (!assignedByChildAppointmentId.containsKey(assignedChild.ServiceAppointmentId)) {
                        assignedByChildAppointmentId.put(
                            assignedChild.ServiceAppointmentId,
                            assignedChild.ServiceResource == null ? 'Unassigned' : assignedChild.ServiceResource.Name
                        );
                    }
                }
            }
            dto.header.childAppointmentCount = childAppointmentRows.size();
            dto.kpis[1].value = String.valueOf(dto.header.childWorkOrderCount);
            dto.kpis[2].value = String.valueOf(dto.header.childAppointmentCount);
            for (ServiceAppointment childAppointment : childAppointmentRows) {
                WorkOrder childParent = childWorkOrdersById.get(childAppointment.ParentRecordId);
                ChildAppointmentDto item = new ChildAppointmentDto();
                item.serviceAppointmentId = childAppointment.Id;
                item.appointmentNumber = blankToDash(childAppointment.AppointmentNumber);
                item.status = blankToDash(childAppointment.Status);
                item.workOrderNumber = childParent == null ? 'Unknown' : blankToDash(childParent.WorkOrderNumber);
                item.workType = childParent == null ? 'Unknown' : blankToDash((String) childParent.get('Work_Order_Type__c'));
                item.scheduledWindow = formatWindow(childAppointment.SchedStartTime, childAppointment.SchedEndTime);
                item.assignedResource = assignedByChildAppointmentId.containsKey(childAppointment.Id) ? assignedByChildAppointmentId.get(childAppointment.Id) : 'Unassigned';
                dto.childAppointments.add(item);
            }
        }

        Takeoff__c takeoff = null;
        if (po != null) {
            List<Takeoff__c> takeoffRows = [
                SELECT Id, Name, Status__c, FM_Assignment__r.Name, Scheduled_Date__c,
                       Checklist_Complete__c, Photo_Count__c, Photos_Count__c,
                       Mismatch_Found__c, Mismatch_Notes__c, CS_Approved__c,
                       Notes__c, NFI_Reason__c
                FROM Takeoff__c
                WHERE Purchase_Order__c = :po.Id
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!takeoffRows.isEmpty()) {
                takeoff = takeoffRows[0];
            }
        }
        if (takeoff != null) {
            dto.takeoffId = takeoff.Id;
            dto.takeoffStatusOptions = picklistOptions(Takeoff__c.Status__c.getDescribe());
            dto.checklistItemStatusOptions = picklistOptions(Checklist_Item__c.Status__c.getDescribe());
            dto.takeoffLineScopeOptions = picklistOptions(Takeoff_Line__c.Execution_Scope__c.getDescribe());
            Map<String, Id> activeScopeRecordTypeIds = activeWorkOrderRecordTypeIdByDeveloperName(new Set<String>{
                workOrderRecordTypeDeveloperNameForExecutionScope('Install'),
                workOrderRecordTypeDeveloperNameForExecutionScope('Grading'),
                workOrderRecordTypeDeveloperNameForExecutionScope('Irrigation'),
                workOrderRecordTypeDeveloperNameForExecutionScope('Aqua')
            });

            Decimal headerPhotoCountValue = (Decimal) takeoff.get('Photo_Count__c');
            if (headerPhotoCountValue == null) {
                headerPhotoCountValue = (Decimal) takeoff.get('Photos_Count__c');
            }
            Boolean mismatchFound = (Boolean) takeoff.get('Mismatch_Found__c');
            Boolean customerSuccessReviewRequired = mismatchFound == true && ((Boolean) takeoff.get('CS_Approved__c')) != true;

            dto.takeoffRows.add(row('Takeoff', takeoff.Name, null));
            dto.takeoffRows.add(row('Parent WorkOrder', dto.header.workOrderNumber, 'WorkOrder.WorkOrderNumber'));
            dto.takeoffRows.add(row('Lot', dto.header.lotName, 'Purchase_Order__c.Lot__r.Name'));
            dto.takeoffRows.add(row('Builder', dto.header.builderName, 'Purchase_Order__c.Builder_Account__r.Name'));
            dto.takeoffRows.add(row('Community', dto.header.communityName, 'Purchase_Order__c.Community__r.Name'));
            dto.takeoffRows.add(row('Takeoff Review Status', blankToDash(takeoff.Status__c), 'Takeoff__c.Status__c'));
            dto.takeoffRows.add(row('Package Match State', po == null ? '—' : blankToDash(po.Package_BMG_Status__c), 'Purchase_Order__c.Package_BMG_Status__c'));
            dto.takeoffRows.add(row('Field Manager', takeoff.FM_Assignment__r == null ? 'Unassigned' : takeoff.FM_Assignment__r.Name, null));
            dto.takeoffRows.add(row('Scheduled Date', takeoff.get('Scheduled_Date__c') == null ? 'Not scheduled' : String.valueOf((Date) takeoff.get('Scheduled_Date__c')), null));
            dto.takeoffRows.add(row('FM Completion State', ((Boolean) takeoff.get('Checklist_Complete__c')) == true ? 'Complete' : 'Open', 'Takeoff__c.Checklist_Complete__c'));
            dto.takeoffRows.add(row('Required Photo Proof', headerPhotoCountValue == null ? '0' : String.valueOf(Integer.valueOf(headerPhotoCountValue)), 'Takeoff photo count'));
            dto.takeoffRows.add(row('Return Required', (takeoff.Status__c == 'Returned' || mismatchFound == true) ? 'Yes' : 'No', 'Derived from Takeoff status and mismatch state'));
            dto.takeoffRows.add(row('Return Reason', String.isBlank((String) takeoff.get('NFI_Reason__c')) ? blankToDash((String) takeoff.get('Mismatch_Notes__c')) : (String) takeoff.get('NFI_Reason__c'), 'Takeoff__c.NFI_Reason__c / Mismatch_Notes__c'));
            dto.takeoffRows.add(row('Customer Success Review Required', customerSuccessReviewRequired ? 'Yes' : 'No', 'Derived from mismatch and CS approval state'));
            dto.takeoffRows.add(row('Customer Success Review State', mismatchFound == true ? (((Boolean) takeoff.get('CS_Approved__c')) == true ? 'Approved' : 'Pending Review') : 'Not required', 'Derived from Takeoff__c.Mismatch_Found__c and CS_Approved__c'));
            dto.takeoffRows.add(row('Variance / Substitution Present', hasVarianceOrSubstitution(takeoff.Id) ? 'Yes' : 'No', 'Derived from Takeoff_Line__c variance and substitution fields'));

            List<Checklist__c> takeoffChecklists = [
                SELECT Id, Name, Checklist_Type__c, Status__c, Completed_By__r.Name, Completed_Date__c, Checklist_Template__r.Name
                FROM Checklist__c
                WHERE Takeoff__c = :takeoff.Id
                  AND Checklist_Type__c = 'Takeoff'
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!takeoffChecklists.isEmpty()) {
                Checklist__c checklist = takeoffChecklists[0];
                dto.takeoffChecklist.checklistId = checklist.Id;
                dto.takeoffChecklist.checklistType = blankToDash(checklist.Checklist_Type__c);
                dto.takeoffChecklist.status = blankToDash(checklist.Status__c);
                dto.takeoffChecklist.completedBy = checklist.Completed_By__r == null ? '—' : checklist.Completed_By__r.Name;
                dto.takeoffChecklist.completedDate = checklist.Completed_Date__c == null ? '—' : checklist.Completed_Date__c.format('M/d/yyyy h:mm a');
                dto.takeoffChecklist.templateName = checklist.Checklist_Template__r == null ? '—' : checklist.Checklist_Template__r.Name;

                for (Checklist_Item__c itemRow : [
                    SELECT Id, Name, Status__c, Required__c, Photo_Required__c, Notes__c, Sort_Order__c,
                           Template_Item__r.Item_Description__c
                    FROM Checklist_Item__c
                    WHERE Checklist__c = :checklist.Id
                    ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC
                ]) {
                    ChecklistItemDto item = new ChecklistItemDto();
                    item.checklistItemId = itemRow.Id;
                    item.label = itemRow.Template_Item__r == null ? blankToDash(itemRow.Name) : blankToDash(itemRow.Template_Item__r.Item_Description__c);
                    item.status = blankToDash(itemRow.Status__c);
                    item.required = itemRow.Required__c;
                    item.photoRequired = itemRow.Photo_Required__c;
                    item.notes = blankToDash(itemRow.Notes__c);
                    item.sortOrder = itemRow.Sort_Order__c;
                    dto.checklistItems.add(item);
                }
            } else {
                dto.takeoffChecklistMissing = true;
            }

            Integer routedLineCount = 0;
            Integer reviewLineCount = 0;
            Integer unroutedLineCount = 0;
            for (Takeoff_Line__c line : [
                SELECT Id, Item_Description__c, PO_Quantity__c, Verified_Quantity__c, Measured_Quantity__c,
                       Unit__c, Unit_Price__c, Determination__c, Material_Substitution__c, Substitution__c,
                       Substitution_Notes__c, Variance__c, Notes__c, Execution_Scope__c
                FROM Takeoff_Line__c
                WHERE Takeoff__c = :takeoff.Id
                ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC
            ]) {
                TakeoffLineDto item = new TakeoffLineDto();
                item.takeoffLineId = line.Id;
                item.description = blankToDash(line.Item_Description__c);
                item.orderedQuantity = line.PO_Quantity__c;
                item.verifiedQuantity = line.Verified_Quantity__c;
                item.measuredQuantity = line.Measured_Quantity__c;
                item.unit = blankToDash(line.Unit__c);
                item.unitPrice = line.Unit_Price__c;
                item.reviewStatus = blankToDash(line.Determination__c);
                item.determination = blankToDash(line.Determination__c);
                item.substitutionState = (line.Material_Substitution__c == true || line.Substitution__c == true) ? 'Yes' : 'No';
                item.variance = line.Variance__c == null ? '—' : String.valueOf(line.Variance__c);
                item.notes = String.isBlank(line.Substitution_Notes__c) ? blankToDash(line.Notes__c) : line.Substitution_Notes__c;
                item.executionScope = blankToDash((String) line.get('Execution_Scope__c'));
                item.routeState = routingStateForExecutionScope((String) line.get('Execution_Scope__c'), activeScopeRecordTypeIds);
                if (isRoutedState(item.routeState)) {
                    routedLineCount++;
                } else if (item.routeState == 'Review Hold') {
                    reviewLineCount++;
                } else {
                    unroutedLineCount++;
                }
                dto.takeoffLines.add(item);
            }
            dto.takeoffRows.add(row('Lines Routed', String.valueOf(routedLineCount), 'Takeoff lines with an active child scope route'));
            dto.takeoffRows.add(row('Lines Held for Review', String.valueOf(reviewLineCount), 'Takeoff lines marked Other / Review or tied to inactive routing'));
            dto.takeoffRows.add(row('Lines Unrouted', String.valueOf(unroutedLineCount), 'Takeoff lines missing execution scope classification'));
            dto.takeoffRows.add(row('Child WorkOrders Created from Routing', String.valueOf(childWorkOrders.size()), 'Direct children currently linked to this parent WorkOrder'));
            dto.takeoffRows.add(row('Scope Review State', reviewLineCount > 0 || unroutedLineCount > 0 ? 'Review Required' : 'Ready to Route', 'Derived from Takeoff_Line__c.Execution_Scope__c'));
        }

        dto.recordsRows.add(row('Files', String.valueOf(fileCount), 'ContentDocumentLink count on this WorkOrder'));
        dto.recordsRows.add(row('Photos', String.valueOf(photoCount), 'Photo__c count on this WorkOrder'));
        dto.recordsRows.add(row('Notes', String.valueOf(noteCount), 'Standard Note count on this WorkOrder'));
        dto.recordsRows.add(row('Primary ServiceAppointment', dto.header.serviceAppointmentNumber, dto.header.serviceAppointmentStatus));
        dto.recordsRows.add(row('QI Outcome', dto.header.qiStatus, 'WorkOrder.QI_Status__c'));
        dto.recordsRows.add(row('Billing State', dto.header.billingState, 'Derived from WorkOrder.Invoice_Amount__c'));

        dto.handoffRows.add(row('Appointment', dto.header.serviceAppointmentNumber, 'Standard ServiceAppointment linked by ParentRecordId'));
        dto.handoffRows.add(row('Appointment Status', dto.header.serviceAppointmentStatus, dto.header.serviceAppointmentStart));
        dto.handoffRows.add(row('Assigned Resource', assigned == null || assigned.ServiceResource == null ? 'Unassigned' : assigned.ServiceResource.Name, 'AssignedResource primary row'));
        dto.handoffRows.add(row('Service Territory', dto.header.serviceTerritory, 'Standard FSL territory'));

        dto.readinessChecks.add(check('Builder PO linked', po != null ? po.PO_Number__c : 'No Builder PO linked yet', po != null));
        dto.readinessChecks.add(check('Takeoff ready', po != null && po.Takeoff_Status__c == 'Approved' ? 'Approved' : (po == null ? 'No Builder PO linked yet' : blankToDash(po.Takeoff_Status__c)), po != null && po.Takeoff_Status__c == 'Approved'));
        dto.readinessChecks.add(check('Service Appointment created', appointment == null ? 'No ServiceAppointment linked yet' : appointment.AppointmentNumber, appointment != null));
        dto.readinessChecks.add(check('Assigned Resource mapped', assigned == null || assigned.ServiceResource == null ? 'No AssignedResource linked yet' : assigned.ServiceResource.Name, assigned != null && assigned.ServiceResource != null));
        dto.readinessChecks.add(check('Standard WorkOrder items created', !lineItems.isEmpty() ? String.valueOf(lineItems.size()) + ' line items linked' : '0 line items linked', !lineItems.isEmpty()));

        if (po != null && po.Package_BMG_Status__c != 'Matched' && po.Package_BMG_Status__c != 'Not Required') {
            dto.blockerRows.add(row(
                'Customer Success review required',
                blankToDash(po.Package_BMG_Status__c),
                builderPo != null && !String.isBlank(builderPo.Exception_Reason__c)
                    ? builderPo.Exception_Reason__c
                    : 'Package mismatch or missing package is blocking direct takeoff approval.'
            ));
        }
        Integer takeoffReviewCount = 0;
        Integer takeoffUnroutedCount = 0;
        for (TakeoffLineDto takeoffLine : dto.takeoffLines) {
            if (takeoffLine.routeState == 'Review Hold') {
                takeoffReviewCount++;
            } else if (takeoffLine.routeState == 'Unrouted') {
                takeoffUnroutedCount++;
            }
        }
        if (takeoffReviewCount > 0) {
            dto.blockerRows.add(row(
                'Takeoff lines held for review',
                String.valueOf(takeoffReviewCount),
                'Execution scope is set to Other / Review or is not yet mapped to an active child WorkOrder type.'
            ));
        }
        if (takeoffUnroutedCount > 0) {
            dto.blockerRows.add(row(
                'Takeoff lines missing routing',
                String.valueOf(takeoffUnroutedCount),
                'Execution scope is blank on one or more Takeoff_Line__c records.'
            ));
        }
        if (builderPo != null && !String.isBlank(builderPo.Exception_Reason__c)) {
            dto.blockerRows.add(row(
                'Builder PO exception',
                builderPo.Exception_Reason__c,
                blankToDash(builderPo.Status__c)
            ));
        }
        if (dto.blockerRows.isEmpty()) {
            dto.blockerRows.add(row('No active blocker', 'No active blocker for this WorkOrder', 'Linked Builder PO and package review are not currently blocking execution.'));
        }

        dto.closeoutRows.add(row('Current Status', blankToDash(workOrder.Status), 'Standard WorkOrder status'));
        dto.closeoutRows.add(row('QI Status', blankToDash((String) workOrder.get('QI_Status__c')), 'WorkOrder.QI_Status__c'));
        dto.closeoutRows.add(row('Customer Success State', dto.header.customerCareState, 'WorkOrder.ClosingCare_Status__c'));
        dto.closeoutRows.add(row('Total Scope Price', currencyOrDash(totalPrice), 'Derived from WorkOrderLineItem quantity x unit price'));
        dto.closeoutRows.add(row('Total Cost', currencyOrDash((Decimal) workOrder.get('Total_Cost__c')), 'WorkOrder.Total_Cost__c'));
        dto.closeoutRows.add(row('Gross Profit', currencyOrDash(dto.header.grossProfit), 'Derived from total scope price minus WorkOrder.Total_Cost__c'));
        dto.closeoutRows.add(row(
            'Invoice Amount',
            currencyOrDash((Decimal) workOrder.get('Invoice_Amount__c')),
            'WorkOrder.Invoice_Amount__c'
        ));

        dto.activity.add(activity('Work Order Created', blankToDash(workOrder.Subject), workOrder.CreatedDate == null ? 'Unknown' : workOrder.CreatedDate.format('M/d/yyyy h:mm a')));
        if (appointment != null) {
            dto.activity.add(activity('Service Appointment Linked', appointment.AppointmentNumber + ' · ' + appointment.Status, appointment.CreatedDate == null ? 'Unknown' : appointment.CreatedDate.format('M/d/yyyy h:mm a')));
        }
        if (po != null && po.Estimated_Start_Date__c != null) {
            dto.activity.add(activity('Estimated Start Date', String.valueOf(po.Estimated_Start_Date__c), 'From linked Builder PO'));
        }
        return dto;
    }

    @AuraEnabled
    public static CreateChildrenResult createExecutionChildren(Id workOrderId) {
        CreateChildrenResult result = new CreateChildrenResult();
        result.success = false;
        result.childWorkOrderIds = new List<Id>();
        result.childCount = 0;
        result.childLineItemCount = 0;

        if (workOrderId == null) {
            result.message = 'WorkOrder Id is required.';
            return result;
        }

        WorkOrder parent = [
            SELECT Id, WorkOrderNumber, Status, Subject, RecordTypeId, WorkTypeId, Pricebook2Id,
                   AccountId, Lot__c, Field_Manager__c, ServiceTerritoryId, ParentWorkOrderId,
                   Sod_Square_Footage__c,
                   Work_Order_Type__c
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        if (parent.ParentWorkOrderId != null) {
            result.message = 'Child WorkOrders can only be created from a parent standard WorkOrder.';
            return result;
        }

        List<WorkOrder> existingChildren = [
            SELECT Id, WorkOrderNumber, Work_Order_Type__c
            FROM WorkOrder
            WHERE ParentWorkOrderId = :parent.Id
            ORDER BY CreatedDate ASC
        ];
        Map<String, WorkOrder> existingChildrenByType = new Map<String, WorkOrder>();
        for (WorkOrder child : existingChildren) {
            result.childWorkOrderIds.add(child.Id);
            existingChildrenByType.put(child.Work_Order_Type__c, child);
        }

        List<WorkOrderLineItem> parentLines = [
            SELECT Id, Description, Quantity, UnitPrice, Status, PricebookEntryId, OrderId, Source_Takeoff_Line__c
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :parent.Id
            ORDER BY CreatedDate ASC
        ];

        Set<Id> sourceTakeoffLineIds = new Set<Id>();
        for (WorkOrderLineItem parentLine : parentLines) {
            if ((Id) parentLine.get('Source_Takeoff_Line__c') != null) {
                sourceTakeoffLineIds.add((Id) parentLine.get('Source_Takeoff_Line__c'));
            }
        }

        Map<Id, String> scopeByTakeoffLineId = new Map<Id, String>();
        if (!sourceTakeoffLineIds.isEmpty()) {
            for (Takeoff_Line__c takeoffLine : [
                SELECT Id, Execution_Scope__c
                FROM Takeoff_Line__c
                WHERE Id IN :sourceTakeoffLineIds
            ]) {
                scopeByTakeoffLineId.put(takeoffLine.Id, (String) takeoffLine.get('Execution_Scope__c'));
            }
        }

        Map<String, List<WorkOrderLineItem>> parentLinesByScope = new Map<String, List<WorkOrderLineItem>>();
        Integer reviewLineCount = 0;
        Integer missingScopeCount = 0;
        for (WorkOrderLineItem parentLine : parentLines) {
            Id sourceTakeoffLineId = (Id) parentLine.get('Source_Takeoff_Line__c');
            String executionScope = sourceTakeoffLineId == null ? null : scopeByTakeoffLineId.get(sourceTakeoffLineId);
            if (String.isBlank(executionScope) || executionScope == 'Other / Review') {
                if (String.isBlank(executionScope)) {
                    missingScopeCount++;
                } else {
                    reviewLineCount++;
                }
                continue;
            }
            if (!parentLinesByScope.containsKey(executionScope)) {
                parentLinesByScope.put(executionScope, new List<WorkOrderLineItem>());
            }
            parentLinesByScope.get(executionScope).add(parentLine);
        }

        Set<String> scopeRecordTypeDeveloperNames = new Set<String>();
        for (String executionScope : parentLinesByScope.keySet()) {
            String recordTypeDeveloperName = workOrderRecordTypeDeveloperNameForExecutionScope(executionScope);
            if (!String.isBlank(recordTypeDeveloperName)) {
                scopeRecordTypeDeveloperNames.add(recordTypeDeveloperName);
            }
        }
        Map<String, Id> activeScopeRecordTypeIds = activeWorkOrderRecordTypeIdByDeveloperName(scopeRecordTypeDeveloperNames);

        List<WorkOrder> childrenToInsert = new List<WorkOrder>();
        Map<String, WorkOrder> childByScope = new Map<String, WorkOrder>();
        for (String executionScope : parentLinesByScope.keySet()) {
            String childType = workOrderTypeForExecutionScope(executionScope);
            String recordTypeDeveloperName = workOrderRecordTypeDeveloperNameForExecutionScope(executionScope);
            Id childRecordTypeId = String.isBlank(recordTypeDeveloperName) ? null : activeScopeRecordTypeIds.get(recordTypeDeveloperName);
            if (String.isBlank(childType) || childRecordTypeId == null) {
                reviewLineCount += parentLinesByScope.get(executionScope).size();
                continue;
            }
            if (existingChildrenByType.containsKey(childType)) {
                childByScope.put(executionScope, existingChildrenByType.get(childType));
                continue;
            }

            WorkOrder child = new WorkOrder();
            child.ParentWorkOrderId = parent.Id;
            child.Subject = executionScope + ' · ' + blankToDash(parent.Subject);
            child.Status = parent.Status;
            child.RecordTypeId = childRecordTypeId;
            child.WorkTypeId = parent.WorkTypeId;
            child.Pricebook2Id = parent.Pricebook2Id;
            child.AccountId = parent.AccountId;
            child.Lot__c = (Id) parent.get('Lot__c');
            child.Field_Manager__c = (Id) parent.get('Field_Manager__c');
            child.ServiceTerritoryId = parent.ServiceTerritoryId;
            child.Work_Order_Type__c = childType;
            if (executionScope == 'Install') {
                child.Sod_Square_Footage__c = (Decimal) parent.get('Sod_Square_Footage__c');
            }
            childrenToInsert.add(child);
            childByScope.put(executionScope, child);
        }
        if (!childrenToInsert.isEmpty()) {
            insert childrenToInsert;
            for (WorkOrder child : childrenToInsert) {
                result.childWorkOrderIds.add(child.Id);
            }
        }

        Set<Id> routedChildIds = new Set<Id>(result.childWorkOrderIds);
        Map<Id, Id> expectedChildIdBySourceLineId = new Map<Id, Id>();
        Map<Id, WorkOrderLineItem> parentLineBySourceLineId = new Map<Id, WorkOrderLineItem>();
        for (String executionScope : parentLinesByScope.keySet()) {
            WorkOrder child = childByScope.get(executionScope);
            if (child == null || child.Id == null) {
                continue;
            }
            for (WorkOrderLineItem parentLine : parentLinesByScope.get(executionScope)) {
                Id sourceTakeoffLineId = (Id) parentLine.get('Source_Takeoff_Line__c');
                if (sourceTakeoffLineId == null) {
                    continue;
                }
                expectedChildIdBySourceLineId.put(sourceTakeoffLineId, child.Id);
                parentLineBySourceLineId.put(sourceTakeoffLineId, parentLine);
            }
        }

        Map<Id, List<WorkOrderLineItem>> existingChildLinesBySourceLineId = new Map<Id, List<WorkOrderLineItem>>();
        if (!routedChildIds.isEmpty()) {
            for (WorkOrderLineItem existingChildLine : [
                SELECT Id, WorkOrderId, Description, Quantity, UnitPrice, Status, PricebookEntryId, OrderId, Source_Takeoff_Line__c
                FROM WorkOrderLineItem
                WHERE WorkOrderId IN :routedChildIds
                  AND Source_Takeoff_Line__c != null
            ]) {
                Id sourceTakeoffLineId = (Id) existingChildLine.get('Source_Takeoff_Line__c');
                if (!existingChildLinesBySourceLineId.containsKey(sourceTakeoffLineId)) {
                    existingChildLinesBySourceLineId.put(sourceTakeoffLineId, new List<WorkOrderLineItem>());
                }
                existingChildLinesBySourceLineId.get(sourceTakeoffLineId).add(existingChildLine);
            }
        }

        List<WorkOrderLineItem> childLinesToInsert = new List<WorkOrderLineItem>();
        List<WorkOrderLineItem> childLinesToUpdate = new List<WorkOrderLineItem>();
        List<WorkOrderLineItem> childLinesToDelete = new List<WorkOrderLineItem>();
        Set<Id> handledSourceLineIds = new Set<Id>();
        Integer movedChildLineCount = 0;

        for (Id sourceTakeoffLineId : expectedChildIdBySourceLineId.keySet()) {
            handledSourceLineIds.add(sourceTakeoffLineId);
            Id expectedChildId = expectedChildIdBySourceLineId.get(sourceTakeoffLineId);
            List<WorkOrderLineItem> existingChildLines = existingChildLinesBySourceLineId.get(sourceTakeoffLineId);
            if (existingChildLines != null && !existingChildLines.isEmpty()) {
                Boolean matchedExpectedChild = false;
                for (WorkOrderLineItem existingChildLine : existingChildLines) {
                    if (!matchedExpectedChild && existingChildLine.WorkOrderId == expectedChildId) {
                        matchedExpectedChild = true;
                        continue;
                    }
                    if (!matchedExpectedChild) {
                        existingChildLine.WorkOrderId = expectedChildId;
                        childLinesToUpdate.add(existingChildLine);
                        matchedExpectedChild = true;
                        movedChildLineCount++;
                    } else {
                        childLinesToDelete.add(existingChildLine);
                    }
                }
                if (matchedExpectedChild) {
                    continue;
                }
            }

            WorkOrderLineItem parentLine = parentLineBySourceLineId.get(sourceTakeoffLineId);
            if (parentLine == null) {
                continue;
            }
            WorkOrderLineItem childLine = new WorkOrderLineItem();
            childLine.WorkOrderId = expectedChildId;
            childLine.Description = parentLine.Description;
            childLine.Quantity = parentLine.Quantity;
            childLine.UnitPrice = parentLine.UnitPrice;
            childLine.Status = parentLine.Status;
            childLine.PricebookEntryId = parentLine.PricebookEntryId;
            childLine.OrderId = parentLine.OrderId;
            childLine.Source_Takeoff_Line__c = sourceTakeoffLineId;
            childLinesToInsert.add(childLine);
        }

        for (Id sourceTakeoffLineId : existingChildLinesBySourceLineId.keySet()) {
            if (handledSourceLineIds.contains(sourceTakeoffLineId)) {
                continue;
            }
            childLinesToDelete.addAll(existingChildLinesBySourceLineId.get(sourceTakeoffLineId));
        }

        if (!childLinesToUpdate.isEmpty()) {
            update childLinesToUpdate;
        }
        if (!childLinesToDelete.isEmpty()) {
            delete childLinesToDelete;
        }
        if (!childLinesToInsert.isEmpty()) {
            insert childLinesToInsert;
        }

        result.success = true;
        result.childCount = result.childWorkOrderIds.size();
        result.childLineItemCount = childLinesToInsert.size() + childLinesToUpdate.size();
        result.message = 'Execution children synced from real Takeoff_Line__c scope classification. '
            + 'Children: ' + String.valueOf(result.childCount)
            + '. Child scope lines inserted or moved: ' + String.valueOf(result.childLineItemCount)
            + '. Child scope lines removed: ' + String.valueOf(childLinesToDelete.size())
            + '. Review lines not routed: ' + String.valueOf(reviewLineCount)
            + '. Missing scope lines not routed: ' + String.valueOf(missingScopeCount) + '.';
        return result;
    }

    @AuraEnabled
    public static String ensureTakeoffChecklist(Id workOrderId) {
        if (workOrderId == null) {
            return 'WorkOrder Id is required.';
        }

        WorkOrder workOrder = [
            SELECT Id, ParentWorkOrderId
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];
        Id bridgeWorkOrderId = workOrder.ParentWorkOrderId == null ? workOrder.Id : workOrder.ParentWorkOrderId;

        List<Purchase_Order__c> pos = [
            SELECT Id
            FROM Purchase_Order__c
            WHERE Work_Order__c = :bridgeWorkOrderId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (pos.isEmpty()) {
            return 'No linked Purchase Order bridge exists for this WorkOrder.';
        }

        List<Takeoff__c> takeoffs = [
            SELECT Id, Name
            FROM Takeoff__c
            WHERE Purchase_Order__c = :pos[0].Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (takeoffs.isEmpty()) {
            return 'No linked Takeoff exists for this WorkOrder bridge.';
        }

        Takeoff__c takeoff = takeoffs[0];
        List<Checklist__c> existing = [
            SELECT Id
            FROM Checklist__c
            WHERE Takeoff__c = :takeoff.Id
              AND Checklist_Type__c = 'Takeoff'
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return 'Takeoff checklist already exists.';
        }

        Checklist_Template__c template;
        List<Checklist_Template__c> templates = [
            SELECT Id, Name
            FROM Checklist_Template__c
            WHERE Checklist_Type__c = 'Takeoff'
              AND Active__c = true
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (!templates.isEmpty()) {
            template = templates[0];
        } else {
            template = new Checklist_Template__c(
                Checklist_Type__c = 'Takeoff',
                Active__c = true
            );
            insert template;

            List<Checklist_Template_Item__c> templateItems = new List<Checklist_Template_Item__c>{
                new Checklist_Template_Item__c(Checklist_Template__c = template.Id, Item_Description__c = 'Site Access Verified', Required__c = true, Sort_Order__c = 10),
                new Checklist_Template_Item__c(Checklist_Template__c = template.Id, Item_Description__c = 'Lot Readiness Verified', Required__c = true, Sort_Order__c = 20),
                new Checklist_Template_Item__c(Checklist_Template__c = template.Id, Item_Description__c = 'Scope Verified', Required__c = true, Sort_Order__c = 30),
                new Checklist_Template_Item__c(Checklist_Template__c = template.Id, Item_Description__c = 'Photo Proof Attached', Required__c = true, Sort_Order__c = 40),
                new Checklist_Template_Item__c(Checklist_Template__c = template.Id, Item_Description__c = 'Field Manager Verification Complete', Required__c = true, Sort_Order__c = 50)
            };
            insert templateItems;
        }

        List<Checklist_Template_Item__c> templateItems = [
            SELECT Id, Item_Description__c, Required__c, Sort_Order__c
            FROM Checklist_Template_Item__c
            WHERE Checklist_Template__c = :template.Id
            ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC
        ];

        Checklist__c checklist = new Checklist__c(
            Checklist_Type__c = 'Takeoff',
            Status__c = 'Open',
            Takeoff__c = takeoff.Id,
            Checklist_Template__c = template.Id
        );
        insert checklist;

        List<Checklist_Item__c> checklistItems = new List<Checklist_Item__c>();
        for (Checklist_Template_Item__c templateItem : templateItems) {
            checklistItems.add(new Checklist_Item__c(
                Checklist__c = checklist.Id,
                Template_Item__c = templateItem.Id,
                Status__c = 'Pending',
                Required__c = templateItem.Required__c,
                Photo_Required__c = templateItem.Item_Description__c == 'Photo Proof Attached',
                Sort_Order__c = templateItem.Sort_Order__c
            ));
        }
        if (!checklistItems.isEmpty()) {
            insert checklistItems;
        }

        return 'Takeoff checklist created.';
    }

    @AuraEnabled
    public static String updateTakeoffReview(
        Id takeoffId,
        String takeoffStatus,
        Boolean mismatchFound,
        String mismatchNotes,
        Boolean csApproved,
        String takeoffNotes,
        String returnReason
    ) {
        if (takeoffId == null) {
            return 'Takeoff Id is required.';
        }
        Takeoff__c takeoff = [
            SELECT Id, Status__c, Mismatch_Found__c, Mismatch_Notes__c, CS_Approved__c, Notes__c, NFI_Reason__c
            FROM Takeoff__c
            WHERE Id = :takeoffId
            LIMIT 1
        ];
        takeoff.Status__c = String.isBlank(takeoffStatus) ? takeoff.Status__c : takeoffStatus;
        takeoff.Mismatch_Found__c = mismatchFound;
        takeoff.Mismatch_Notes__c = mismatchNotes;
        takeoff.CS_Approved__c = csApproved;
        takeoff.Notes__c = takeoffNotes;
        takeoff.NFI_Reason__c = returnReason;
        update takeoff;
        return 'Takeoff review updated.';
    }

    @AuraEnabled
    public static String updateChecklistItem(Id checklistItemId, String status, String notes) {
        if (checklistItemId == null) {
            return 'Checklist Item Id is required.';
        }

        Checklist_Item__c checklistItem = [
            SELECT Id, Checklist__c, Status__c, Notes__c
            FROM Checklist_Item__c
            WHERE Id = :checklistItemId
            LIMIT 1
        ];
        checklistItem.Status__c = status;
        checklistItem.Notes__c = notes;
        checklistItem.Completed_Date__c = status == 'Complete' ? System.now() : null;
        update checklistItem;

        Checklist__c checklist = [
            SELECT Id, Takeoff__c, Status__c
            FROM Checklist__c
            WHERE Id = :checklistItem.Checklist__c
            LIMIT 1
        ];

        Boolean allRequiredClosed = true;
        for (Checklist_Item__c item : [
            SELECT Status__c, Required__c
            FROM Checklist_Item__c
            WHERE Checklist__c = :checklist.Id
        ]) {
            if (item.Required__c && item.Status__c != 'Complete' && item.Status__c != 'N/A') {
                allRequiredClosed = false;
                break;
            }
        }

        checklist.Status__c = allRequiredClosed ? 'Completed' : 'In Progress';
        if (allRequiredClosed) {
            checklist.Completed_By__c = UserInfo.getUserId();
            checklist.Completed_Date__c = System.now();
        } else {
            checklist.Completed_By__c = null;
            checklist.Completed_Date__c = null;
        }
        update checklist;

        if (checklist.Takeoff__c != null) {
            update new Takeoff__c(
                Id = checklist.Takeoff__c,
                Checklist_Complete__c = allRequiredClosed
            );
        }

        return 'Checklist item updated.';
    }

    @AuraEnabled
    public static String updateTakeoffLineScope(Id takeoffLineId, String executionScope) {
        if (takeoffLineId == null) {
            return 'Takeoff line Id is required.';
        }
        Takeoff_Line__c takeoffLine = [
            SELECT Id, Execution_Scope__c
            FROM Takeoff_Line__c
            WHERE Id = :takeoffLineId
            LIMIT 1
        ];
        takeoffLine.Execution_Scope__c = executionScope;
        update takeoffLine;
        return 'Takeoff line execution scope updated.';
    }

    private static KpiDto kpi(String label, String value, String detail, String tone) {
        KpiDto dto = new KpiDto();
        dto.label = label;
        dto.value = blankToDash(value);
        dto.detail = blankToDash(detail);
        dto.tone = tone;
        return dto;
    }

    private static CheckDto check(String label, String detail, Boolean passed) {
        CheckDto dto = new CheckDto();
        dto.label = label;
        dto.detail = blankToDash(detail);
        dto.passed = passed;
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

    private static List<OptionDto> picklistOptions(Schema.DescribeFieldResult describeResult) {
        List<OptionDto> options = new List<OptionDto>();
        for (Schema.PicklistEntry entry : describeResult.getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            OptionDto option = new OptionDto();
            option.label = entry.getLabel();
            option.value = entry.getValue();
            options.add(option);
        }
        return options;
    }

    private static String workOrderTypeForExecutionScope(String executionScope) {
        if (executionScope == 'Install') {
            return 'Production Install';
        }
        if (executionScope == 'Grading') {
            return 'Grading';
        }
        if (executionScope == 'Irrigation') {
            return 'Irrigation';
        }
        if (executionScope == 'Aqua') {
            return 'Aqua Install';
        }
        return null;
    }

    private static String workOrderRecordTypeDeveloperNameForExecutionScope(String executionScope) {
        if (executionScope == 'Install') {
            return 'Production_Install';
        }
        if (executionScope == 'Grading') {
            return 'Plant_Sod_Grading';
        }
        if (executionScope == 'Irrigation') {
            return 'Inground_Irrigation';
        }
        if (executionScope == 'Aqua') {
            return 'Aqua_New_Install';
        }
        return null;
    }

    private static Map<String, Id> activeWorkOrderRecordTypeIdByDeveloperName(Set<String> developerNames) {
        Map<String, Id> recordTypeIdsByDeveloperName = new Map<String, Id>();
        Set<String> filteredDeveloperNames = new Set<String>();
        for (String developerName : developerNames) {
            if (!String.isBlank(developerName)) {
                filteredDeveloperNames.add(developerName);
            }
        }
        if (filteredDeveloperNames.isEmpty()) {
            return recordTypeIdsByDeveloperName;
        }
        for (RecordType recordType : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'WorkOrder'
              AND DeveloperName IN :filteredDeveloperNames
              AND IsActive = true
        ]) {
            recordTypeIdsByDeveloperName.put(recordType.DeveloperName, recordType.Id);
        }
        return recordTypeIdsByDeveloperName;
    }

    private static String routingStateForExecutionScope(String executionScope, Map<String, Id> activeRecordTypeIdsByDeveloperName) {
        if (String.isBlank(executionScope)) {
            return 'Unrouted';
        }
        if (executionScope == 'Other / Review') {
            return 'Review Hold';
        }
        String workOrderType = workOrderTypeForExecutionScope(executionScope);
        String recordTypeDeveloperName = workOrderRecordTypeDeveloperNameForExecutionScope(executionScope);
        if (String.isBlank(workOrderType) || String.isBlank(recordTypeDeveloperName)) {
            return 'Review Hold';
        }
        return activeRecordTypeIdsByDeveloperName.containsKey(recordTypeDeveloperName) ? workOrderType : 'Review Hold';
    }

    private static Boolean isRoutedState(String routeState) {
        return routeState != 'Unrouted' && routeState != 'Review Hold';
    }

    private static String currencyOrDash(Decimal value) {
        return value == null ? '—' : '$' + String.valueOf(value.setScale(2));
    }

    private static String billingStateFor(String status, Decimal invoiceAmount) {
        if (status == 'Invoiced') {
            return 'Invoiced';
        }
        if (invoiceAmount != null) {
            return 'Invoice amount recorded';
        }
        return 'Open';
    }

    private static Boolean hasVarianceOrSubstitution(Id takeoffId) {
        if (takeoffId == null) {
            return false;
        }
        return [
            SELECT COUNT()
            FROM Takeoff_Line__c
            WHERE Takeoff__c = :takeoffId
              AND (
                Variance__c != null
                OR Material_Substitution__c = true
                OR Substitution__c = true
              )
        ] > 0;
    }

    private static String formatWindow(Datetime startTime, Datetime endTime) {
        if (startTime == null && endTime == null) {
            return 'Not scheduled';
        }
        if (startTime != null && endTime != null) {
            return startTime.format('M/d/yyyy h:mm a') + ' - ' + endTime.format('h:mm a');
        }
        return startTime != null ? startTime.format('M/d/yyyy h:mm a') : endTime.format('M/d/yyyy h:mm a');
    }

    private static String fullAddress(String street, String city, String state, String postalCode) {
        List<String> parts = new List<String>();
        if (!String.isBlank(street)) parts.add(street);
        String cityLine = '';
        if (!String.isBlank(city)) cityLine += city;
        if (!String.isBlank(state)) cityLine += (String.isBlank(cityLine) ? '' : ', ') + state;
        if (!String.isBlank(postalCode)) cityLine += (String.isBlank(cityLine) ? '' : ' ') + postalCode;
        if (!String.isBlank(cityLine)) parts.add(cityLine);
        return parts.isEmpty() ? '—' : String.join(parts, ' · ');
    }

    private static String blankToDash(String input) {
        return String.isBlank(input) ? '—' : input;
    }
}