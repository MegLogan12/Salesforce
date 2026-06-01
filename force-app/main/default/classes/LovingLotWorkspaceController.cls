public with sharing class LovingLotWorkspaceController {
    public class OptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class LotListRowDTO {
        @AuraEnabled public Id lotId;
        @AuraEnabled public String lotLabel;
        @AuraEnabled public String lotNumber;
        @AuraEnabled public String communityName;
        @AuraEnabled public String builderDivisionName;
        @AuraEnabled public String fmName;
        @AuraEnabled public String address;
        @AuraEnabled public Date requestedInstallDate;
        @AuraEnabled public String requestedInstallDisplay;
        @AuraEnabled public String pipelineBucket;
        @AuraEnabled public String pipelineClass;
        @AuraEnabled public String lotStatus;
        @AuraEnabled public String lotStatusClass;
        @AuraEnabled public String eight11Status;
        @AuraEnabled public String eight11Class;
        @AuraEnabled public String takeoffStatus;
        @AuraEnabled public String takeoffClass;
        @AuraEnabled public String aquaStatus;
        @AuraEnabled public String aquaClass;
        @AuraEnabled public String poNumber;
        @AuraEnabled public Decimal poAmount;
        @AuraEnabled public String poAmountDisplay;
        @AuraEnabled public String specType;
        @AuraEnabled public Integer workOrderCount;
        @AuraEnabled public Integer photoCount;
    }

    public class ColumnDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public String classKey;
        @AuraEnabled public Boolean numeric;
    }

    public class LotsWorkspaceDTO {
        @AuraEnabled public String objectLabel;
        @AuraEnabled public String objectPluralLabel;
        @AuraEnabled public Integer accountCount;
        @AuraEnabled public Integer communityCount;
        @AuraEnabled public Integer lotCount;
        @AuraEnabled public Integer activeLotCount;
        @AuraEnabled public List<ColumnDTO> columns;
        @AuraEnabled public List<OptionDTO> pipelineOptions;
        @AuraEnabled public List<OptionDTO> builderOptions;
        @AuraEnabled public List<OptionDTO> fmOptions;
        @AuraEnabled public List<LotListRowDTO> rows;
    }

    public class DetailFieldDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String type;
        @AuraEnabled public String link;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String source;
        @AuraEnabled public Boolean editable;
        @AuraEnabled public List<OptionDTO> options;
    }

    public class TimelineItemDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String dateLabel;
        @AuraEnabled public String statusClass;
        @AuraEnabled public Boolean complete;
    }

    public class RelatedCountDTO {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
    }

    public class WorkOrderRowDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String workOrderType;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public String requestedInstallDisplay;
        @AuraEnabled public String fieldManagerName;
    }

    public class LotDetailDTO {
        @AuraEnabled public Id lotId;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public String objectPluralLabel;
        @AuraEnabled public String poObjectLabel;
        @AuraEnabled public String lotName;
        @AuraEnabled public String lotRecordLabel;
        @AuraEnabled public String communityName;
        @AuraEnabled public Id communityId;
        @AuraEnabled public String parentBuilderName;
        @AuraEnabled public String divisionName;
        @AuraEnabled public String fmName;
        @AuraEnabled public String pipelineBucket;
        @AuraEnabled public String pipelineClass;
        @AuraEnabled public String lotStatus;
        @AuraEnabled public String lotStatusClass;
        @AuraEnabled public String scheduledCloseDisplay;
        @AuraEnabled public String installBanner;
        @AuraEnabled public Integer workOrderCount;
        @AuraEnabled public Integer photoCount;
        @AuraEnabled public String lotLayoutLink;
        @AuraEnabled public String mapsLink;
        @AuraEnabled public String latestPoNumber;
        @AuraEnabled public String latestPoStatus;
        @AuraEnabled public String latestPoAmountDisplay;
        @AuraEnabled public String latestPoEstimatedStartDisplay;
        @AuraEnabled public String latestPoEight11Status;
        @AuraEnabled public String latestTakeoffStatus;
        @AuraEnabled public List<DetailFieldDTO> poSummaryFields;
        @AuraEnabled public List<DetailFieldDTO> lotInformationLeft;
        @AuraEnabled public List<DetailFieldDTO> lotInformationRight;
        @AuraEnabled public List<DetailFieldDTO> propertyDetailsLeft;
        @AuraEnabled public List<DetailFieldDTO> propertyDetailsRight;
        @AuraEnabled public List<DetailFieldDTO> pipelineTaskRows;
        @AuraEnabled public List<TimelineItemDTO> timeline;
        @AuraEnabled public List<String> hierarchy;
        @AuraEnabled public List<RelatedCountDTO> relatedCounts;
        @AuraEnabled public List<WorkOrderRowDTO> workOrders;
    }

    private class LotContext {
        Builder_PO__c po;
        Takeoff__c takeoff;
        WorkOrder latestWorkOrder;
        String latestServiceAppointmentStatus;
        Integer workOrderCount = 0;
        Integer photoCount = 0;
        List<WorkOrder> workOrders = new List<WorkOrder>();
    }

    @AuraEnabled(cacheable=true)
    public static LotsWorkspaceDTO getLotsWorkspace() {
        LotsWorkspaceDTO dto = new LotsWorkspaceDTO();
        dto.objectLabel = Lot__c.SObjectType.getDescribe().getLabel();
        dto.objectPluralLabel = Lot__c.SObjectType.getDescribe().getLabelPlural();
        dto.columns = lotListColumns();
        dto.pipelineOptions = new List<OptionDTO>{ option('All', 'All') };
        dto.builderOptions = new List<OptionDTO>{ option('All builders', 'all') };
        dto.fmOptions = new List<OptionDTO>{ option('All FMs', 'all') };
        dto.rows = new List<LotListRowDTO>();

        dto.accountCount = [SELECT COUNT() FROM Account WHERE Type IN ('Home Builder', 'Division Builder')];
        dto.communityCount = [SELECT COUNT() FROM Community__c];
        dto.lotCount = [SELECT COUNT() FROM Lot__c];
        dto.activeLotCount = [SELECT COUNT() FROM Lot__c WHERE Lot_Status__c != 'Closed'];

        List<Lot__c> lots = [
            SELECT Id, Name, Lot_Number__c, Lot_Status__c, Status__c, Pipeline_Bucket__c,
                   Community__c, Community__r.Name, Community__r.Builder_Account__r.Name,
                   Community__r.Assigned_FM__r.Name, Community__r.Aqua_Customer__c,
                   Street_Address__c, Requested_Install_Date__c, PO_Received_Date__c,
                   Frame_Complete_Date__c, Final_Inspection_Date__c, Closing_Date__c,
                   Lawn_Care_Start_Date__c, Aqua_Add_On__c, Aqua_Installed__c,
                   Eight11_Task_Status__c, Builder_PO_Number__c, Spec_Type__c,
                   Sod_SF__c, Trees__c, Shrubs__c, Plant_Package__c, Phase__c,
                   Lot_Latitude__c, Lot_Longitude__c, Parent_Builder_Account__c
            FROM Lot__c
            WHERE Community__c != null
            ORDER BY LastModifiedDate DESC, Name
            LIMIT 3000
        ];

        Map<Id, LotContext> contextByLot = buildContexts(lots);
        Set<String> builderNames = new Set<String>();
        Set<String> fmNames = new Set<String>();
        Set<String> pipelineValues = new Set<String>();

        for (Lot__c lot : lots) {
            LotContext context = contextByLot.get(lot.Id);
            Builder_PO__c po = context == null ? null : context.po;
            Takeoff__c takeoff = context == null ? null : context.takeoff;

            LotListRowDTO row = new LotListRowDTO();
            row.lotId = lot.Id;
            row.lotLabel = String.isBlank(lot.Lot_Number__c) ? lot.Name : 'L-' + lot.Lot_Number__c;
            row.lotNumber = lot.Lot_Number__c;
            row.communityName = lot.Community__r == null ? null : lot.Community__r.Name;
            row.builderDivisionName = lot.Community__r != null && lot.Community__r.Builder_Account__r != null
                ? lot.Community__r.Builder_Account__r.Name
                : null;
            row.fmName = lot.Community__r != null && lot.Community__r.Assigned_FM__r != null
                ? lot.Community__r.Assigned_FM__r.Name
                : null;
            row.address = lot.Street_Address__c;
            row.requestedInstallDate = lot.Requested_Install_Date__c;
            row.requestedInstallDisplay = formatDate(lot.Requested_Install_Date__c);
            row.pipelineBucket = derivePipelineBucket(lot, po, takeoff, context == null ? null : context.latestWorkOrder, context == null ? null : context.latestServiceAppointmentStatus);
            row.pipelineClass = pipelineClass(row.pipelineBucket);
            row.lotStatus = canonicalLotStatus(lot);
            row.lotStatusClass = lotStatusClass(row.lotStatus);
            row.eight11Status = String.isBlank(lot.Eight11_Task_Status__c) ? 'Not Filed' : lot.Eight11_Task_Status__c;
            row.eight11Class = statusPillClass(row.eight11Status, 'eight11');
            row.takeoffStatus = deriveTakeoffStatus(po, takeoff);
            row.takeoffClass = statusPillClass(row.takeoffStatus, 'takeoff');
            row.aquaStatus = deriveAquaStatus(lot);
            row.aquaClass = statusPillClass(row.aquaStatus, 'aqua');
            row.poNumber = firstNonBlank(lot.Builder_PO_Number__c, po == null ? null : po.PO_Number__c);
            row.poAmount = po == null ? null : po.PO_Amount__c;
            row.poAmountDisplay = formatCurrency(row.poAmount);
            row.specType = String.isBlank(lot.Spec_Type__c) ? '-' : lot.Spec_Type__c;
            row.workOrderCount = context == null ? 0 : context.workOrderCount;
            row.photoCount = context == null ? 0 : context.photoCount;
            dto.rows.add(row);

            if (String.isNotBlank(row.pipelineBucket)) pipelineValues.add(row.pipelineBucket);
            if (String.isNotBlank(row.builderDivisionName)) builderNames.add(row.builderDivisionName);
            if (String.isNotBlank(row.fmName)) fmNames.add(row.fmName);
        }

        for (OptionDTO pipelineOption : pipelinePicklistOptions()) {
            if (pipelineValues.contains(pipelineOption.value)) {
                dto.pipelineOptions.add(pipelineOption);
                pipelineValues.remove(pipelineOption.value);
            }
        }
        List<String> extraPipelines = new List<String>(pipelineValues);
        extraPipelines.sort();
        for (String value : extraPipelines) dto.pipelineOptions.add(option(value, value));
        List<String> sortedBuilders = new List<String>(builderNames);
        sortedBuilders.sort();
        for (String name : sortedBuilders) dto.builderOptions.add(option(name, name));
        List<String> sortedFms = new List<String>(fmNames);
        sortedFms.sort();
        for (String name : sortedFms) dto.fmOptions.add(option(name, name));
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static LotDetailDTO getLotDetail(Id lotId) {
        LotDetailDTO dto = emptyDetail();
        if (lotId == null) return dto;

        List<Lot__c> lots = [
            SELECT Id, Name, Lot_Number__c, Lot_Status__c, Status__c, Pipeline_Bucket__c,
                   Community__c, Community__r.Name, Community__r.Builder_Account__r.Name,
                   Community__r.Assigned_FM__r.Name, Community__r.Aqua_Customer__c,
                   Community__r.Lot_Layout_Link__c, Street_Address__c, Requested_Install_Date__c,
                   PO_Received_Date__c, Frame_Complete_Date__c, Final_Inspection_Date__c,
                   Closing_Date__c, Lawn_Care_Start_Date__c, Aqua_Add_On__c,
                   Aqua_Installed__c, Eight11_Task_Status__c, Builder_PO_Number__c,
                   Spec_Type__c, Sod_SF__c, Trees__c, Shrubs__c, Plant_Package__c,
                   Phase__c, Lot_Latitude__c, Lot_Longitude__c, Parent_Builder_Account__c
            FROM Lot__c
            WHERE Id = :lotId
            LIMIT 1
        ];
        if (lots.isEmpty()) return dto;

        Lot__c lot = lots[0];
        LotContext context = buildContexts(lots).get(lot.Id);
        Builder_PO__c po = context == null ? null : context.po;
        Takeoff__c takeoff = context == null ? null : context.takeoff;
        WorkOrder latestWo = context == null ? null : context.latestWorkOrder;

        dto.lotId = lot.Id;
        dto.objectLabel = Lot__c.SObjectType.getDescribe().getLabel();
        dto.objectPluralLabel = Lot__c.SObjectType.getDescribe().getLabelPlural();
        dto.poObjectLabel = Builder_PO__c.SObjectType.getDescribe().getLabel();
        dto.lotName = buildLotTitle(lot);
        dto.lotRecordLabel = lot.Name;
        dto.communityName = lot.Community__r == null ? null : lot.Community__r.Name;
        dto.communityId = lot.Community__c;
        dto.parentBuilderName = lot.Parent_Builder_Account__c;
        dto.divisionName = lot.Community__r != null && lot.Community__r.Builder_Account__r != null
            ? lot.Community__r.Builder_Account__r.Name
            : null;
        dto.fmName = lot.Community__r != null && lot.Community__r.Assigned_FM__r != null
            ? lot.Community__r.Assigned_FM__r.Name
            : null;
        dto.pipelineBucket = derivePipelineBucket(lot, po, takeoff, latestWo, context == null ? null : context.latestServiceAppointmentStatus);
        dto.pipelineClass = pipelineClass(dto.pipelineBucket);
        dto.lotStatus = canonicalLotStatus(lot);
        dto.lotStatusClass = lotStatusClass(dto.lotStatus);
        dto.scheduledCloseDisplay = formatDate(lot.Closing_Date__c);
        dto.installBanner = buildInstallBanner(lot, po, takeoff, latestWo);
        dto.workOrderCount = context == null ? 0 : context.workOrderCount;
        dto.photoCount = context == null ? 0 : context.photoCount;
        dto.lotLayoutLink = lot.Community__r == null ? null : lot.Community__r.Lot_Layout_Link__c;
        dto.mapsLink = buildMapsLink(lot.Street_Address__c, lot.Lot_Latitude__c, lot.Lot_Longitude__c);
        dto.latestPoNumber = po == null ? firstNonBlank(lot.Builder_PO_Number__c, null) : po.PO_Number__c;
        dto.latestPoStatus = po == null ? null : po.Status__c;
        dto.latestPoAmountDisplay = po == null ? null : formatCurrency(po.PO_Amount__c);
        dto.latestPoEstimatedStartDisplay = po == null ? null : formatDate(po.Estimated_Start_Date__c);
        dto.latestPoEight11Status = firstNonBlank(po == null ? null : po.Eight11_Task_Status__c, lot.Eight11_Task_Status__c);
        dto.latestTakeoffStatus = deriveTakeoffStatus(po, takeoff);

        addLotFields(dto, lot, po, takeoff);
        addPoSummaryFields(dto, lot, po, takeoff);

        addHierarchyNode(dto.hierarchy, dto.parentBuilderName);
        addHierarchyNode(dto.hierarchy, dto.divisionName);
        addHierarchyNode(dto.hierarchy, dto.communityName);
        addHierarchyNode(dto.hierarchy, buildLotChip(lot));
        dto.relatedCounts.add(related('Work Orders', dto.workOrderCount));
        dto.relatedCounts.add(related('Photos', dto.photoCount));
        dto.relatedCounts.add(related('Aqua', deriveAquaStatus(lot) == 'N/A' ? 0 : 1));
        dto.relatedCounts.add(related('Takeoffs', takeoff == null ? 0 : 1));

        if (context != null) {
            for (WorkOrder wo : context.workOrders) {
                WorkOrderRowDTO row = new WorkOrderRowDTO();
                row.id = wo.Id;
                row.workOrderNumber = wo.WorkOrderNumber;
                row.subject = wo.Subject;
                row.workOrderType = (String) wo.get('Work_Order_Type__c');
                row.status = wo.Status;
                row.statusClass = statusPillClass(wo.Status, 'workorder');
                row.requestedInstallDisplay = formatDate((Date) wo.get('Proposed_Schedule_Date__c'));
                row.fieldManagerName = wo.Field_Manager__r == null ? null : wo.Field_Manager__r.Name;
                dto.workOrders.add(row);
            }
        }

        addTimeline(dto.timeline, 'PO received', lot.PO_Received_Date__c, lot.PO_Received_Date__c != null);
        addTimeline(dto.timeline, 'Frame complete', lot.Frame_Complete_Date__c, lot.Frame_Complete_Date__c != null);
        addTimeline(dto.timeline, '811 cleared', lot.Eight11_Task_Status__c == 'Cleared' ? 'Cleared' : null, lot.Eight11_Task_Status__c == 'Cleared');
        addTimeline(dto.timeline, 'Takeoff approved', takeoff == null ? null : formatDateTime(takeoff.Approved_Date__c), takeoff != null && takeoff.Status__c == 'Approved');
        addTimeline(dto.timeline, 'Final inspection', lot.Final_Inspection_Date__c, lot.Final_Inspection_Date__c != null);
        addTimeline(dto.timeline, 'Installed', lot.Requested_Install_Date__c, dto.lotStatus == 'Installed' || latestWo != null);
        addTimeline(dto.timeline, 'Lawn care begins', lot.Lawn_Care_Start_Date__c, lot.Lawn_Care_Start_Date__c != null && lot.Lawn_Care_Start_Date__c <= Date.today());
        addTimeline(dto.timeline, 'Closing', lot.Closing_Date__c, lot.Closing_Date__c != null && lot.Closing_Date__c <= Date.today());

        return dto;
    }

    private static LotDetailDTO emptyDetail() {
        LotDetailDTO dto = new LotDetailDTO();
        dto.lotInformationLeft = new List<DetailFieldDTO>();
        dto.lotInformationRight = new List<DetailFieldDTO>();
        dto.poSummaryFields = new List<DetailFieldDTO>();
        dto.propertyDetailsLeft = new List<DetailFieldDTO>();
        dto.propertyDetailsRight = new List<DetailFieldDTO>();
        dto.pipelineTaskRows = new List<DetailFieldDTO>();
        dto.timeline = new List<TimelineItemDTO>();
        dto.hierarchy = new List<String>();
        dto.relatedCounts = new List<RelatedCountDTO>();
        dto.workOrders = new List<WorkOrderRowDTO>();
        return dto;
    }

    private static void addLotFields(LotDetailDTO dto, Lot__c lot, Builder_PO__c po, Takeoff__c takeoff) {
        dto.lotInformationLeft.add(field(fieldLabel(Lot__c.Name), lot.Name, 'text', null, 'Lot__c', 'Name', 'Lot record name', false));
        dto.lotInformationLeft.add(field(fieldLabel(Lot__c.Community__c), dto.communityName, 'link', dto.communityId == null ? null : '/lightning/r/Community__c/' + dto.communityId + '/view', 'Lot__c', 'Community__c', 'Lot lookup', true, picklistOptions(null)));
        dto.lotInformationLeft.add(field(fieldLabel(Lot__c.Parent_Builder_Account__c), dto.parentBuilderName, 'text', null, 'Lot__c', 'Parent_Builder_Account__c', 'Formula / inherited builder rollup', false));
        dto.lotInformationLeft.add(field(fieldLabel(Lot__c.Street_Address__c), lot.Street_Address__c, 'text', null, 'Lot__c', 'Street_Address__c', 'Lot field', true));
        dto.lotInformationLeft.add(field(fieldLabel(Lot__c.Lot_Status__c), canonicalLotStatus(lot), 'picklist', null, 'Lot__c', 'Lot_Status__c', 'Lot field', true, picklistOptions(Lot__c.Lot_Status__c.getDescribe())));
        dto.lotInformationLeft.add(field(fieldLabel(Lot__c.Status__c), lot.Status__c, 'picklist', null, 'Lot__c', 'Status__c', 'Lot field', true, picklistOptions(Lot__c.Status__c.getDescribe())));
        dto.lotInformationLeft.add(field(fieldLabel(Lot__c.Builder_PO_Number__c), firstNonBlank(lot.Builder_PO_Number__c, po == null ? null : po.PO_Number__c), 'text', null, 'Lot__c', 'Builder_PO_Number__c', po == null ? 'Lot field' : 'Latest Builder PO fallback', true));

        dto.lotInformationRight.add(field(fieldLabel(Lot__c.Lot_Number__c), lot.Lot_Number__c, 'text', null, 'Lot__c', 'Lot_Number__c', 'Lot field', true));
        dto.lotInformationRight.add(field(fieldLabel(Community__c.Builder_Account__c), dto.divisionName, 'text', null, 'Community__c', 'Builder_Account__c', 'Inherited from Community', false));
        dto.lotInformationRight.add(field(fieldLabel(Lot__c.Phase__c), lot.Phase__c, 'text', null, 'Lot__c', 'Phase__c', 'Lot field', true));
        dto.lotInformationRight.add(field('GPS', coordinateLabel(lot.Lot_Latitude__c, lot.Lot_Longitude__c), 'text', null, 'Lot__c', 'Lot_Latitude__c', 'Derived from Lot latitude and longitude', false));
        dto.lotInformationRight.add(field(fieldLabel(Lot__c.Spec_Type__c), lot.Spec_Type__c, 'picklist', null, 'Lot__c', 'Spec_Type__c', 'Lot field', true, picklistOptions(Lot__c.Spec_Type__c.getDescribe())));
        dto.lotInformationRight.add(field(fieldLabel(Lot__c.Requested_Install_Date__c), formatDate(lot.Requested_Install_Date__c), 'date', null, 'Lot__c', 'Requested_Install_Date__c', 'Lot field', true));

        dto.propertyDetailsLeft.add(field(fieldLabel(Lot__c.Sod_SF__c), lot.Sod_SF__c == null ? null : formatWhole(lot.Sod_SF__c) + ' sf', 'number', null, 'Lot__c', 'Sod_SF__c', 'Lot field', true));
        dto.propertyDetailsLeft.add(field(fieldLabel(Lot__c.Trees__c), quantityLabel(lot.Trees__c == null ? null : Integer.valueOf(lot.Trees__c), 'tree'), 'number', null, 'Lot__c', 'Trees__c', 'Lot field', true));
        dto.propertyDetailsLeft.add(field(fieldLabel(Takeoff__c.Mulch_Measured_CY__c), takeoff == null || takeoff.Mulch_Measured_CY__c == null ? null : formatWhole(takeoff.Mulch_Measured_CY__c) + ' cy', 'number', null, 'Takeoff__c', 'Mulch_Measured_CY__c', 'Latest Takeoff measurement', false));
        dto.propertyDetailsLeft.add(field(fieldLabel(Lot__c.Aqua_Add_On__c), lot.Aqua_Add_On__c == null ? deriveAquaStatus(lot) : formatCurrency(lot.Aqua_Add_On__c), 'currency', null, 'Lot__c', 'Aqua_Add_On__c', 'Lot field', true));

        dto.propertyDetailsRight.add(field(fieldLabel(Lot__c.Plant_Package__c), lot.Plant_Package__c, 'text', null, 'Lot__c', 'Plant_Package__c', 'Lot field', true));
        dto.propertyDetailsRight.add(field(fieldLabel(Lot__c.Shrubs__c), quantityLabel(lot.Shrubs__c == null ? null : Integer.valueOf(lot.Shrubs__c), 'shrub'), 'number', null, 'Lot__c', 'Shrubs__c', 'Lot field', true));
        dto.propertyDetailsRight.add(field(fieldLabel(Takeoff__c.Sod_Measured_Sqft__c), takeoff == null || takeoff.Sod_Measured_Sqft__c == null ? null : formatWhole(takeoff.Sod_Measured_Sqft__c) + ' sf', 'number', null, 'Takeoff__c', 'Sod_Measured_Sqft__c', 'Latest Takeoff measurement', false));
        dto.propertyDetailsRight.add(field('Aqua Service', deriveAquaStatus(lot), 'text', null, 'Derived', 'Aqua status', 'Derived from Aqua fields and Community', false));

        dto.pipelineTaskRows.add(field(fieldLabel(Lot__c.Pipeline_Bucket__c), dto.pipelineBucket, 'picklist', null, 'Lot__c', 'Pipeline_Bucket__c', 'Latest derived bucket, editable stored field when set directly', true, picklistOptions(Lot__c.Pipeline_Bucket__c.getDescribe())));
        dto.pipelineTaskRows.add(field(fieldLabel(Lot__c.Eight11_Task_Status__c), String.isBlank(lot.Eight11_Task_Status__c) ? 'Not Filed' : lot.Eight11_Task_Status__c, 'picklist', null, 'Lot__c', 'Eight11_Task_Status__c', 'Lot field', true, picklistOptions(Lot__c.Eight11_Task_Status__c.getDescribe())));
        dto.pipelineTaskRows.add(field(fieldLabel(Builder_PO__c.Takeoff_Status__c), deriveTakeoffStatus(po, takeoff), 'text', null, po == null ? 'Takeoff__c' : 'Builder_PO__c', po == null ? 'Status__c' : 'Takeoff_Status__c', 'Latest PO/Takeoff status', false));
        dto.pipelineTaskRows.add(field(fieldLabel(Builder_PO__c.Status__c), po == null ? null : po.Status__c, 'text', null, 'Builder_PO__c', 'Status__c', 'Latest Builder PO', false));
        dto.pipelineTaskRows.add(field(fieldLabel(Builder_PO__c.Estimated_Start_Date__c), po == null ? null : formatDate(po.Estimated_Start_Date__c), 'date', null, 'Builder_PO__c', 'Estimated_Start_Date__c', 'Latest Builder PO', false));
        dto.pipelineTaskRows.add(field(fieldLabel(Takeoff__c.Scheduled_Date__c), takeoff == null ? null : formatDate(takeoff.Scheduled_Date__c), 'date', null, 'Takeoff__c', 'Scheduled_Date__c', 'Latest Takeoff', false));
    }

    private static void addPoSummaryFields(LotDetailDTO dto, Lot__c lot, Builder_PO__c po, Takeoff__c takeoff) {
        dto.poSummaryFields.add(field(fieldLabel(Builder_PO__c.PO_Number__c), dto.latestPoNumber, 'text', null, 'Builder_PO__c', 'PO_Number__c', 'Latest Builder PO', false));
        dto.poSummaryFields.add(field(fieldLabel(Builder_PO__c.Status__c), dto.latestPoStatus, 'text', null, 'Builder_PO__c', 'Status__c', 'Latest Builder PO', false));
        dto.poSummaryFields.add(field(fieldLabel(Builder_PO__c.PO_Amount__c), dto.latestPoAmountDisplay, 'currency', null, 'Builder_PO__c', 'PO_Amount__c', 'Latest Builder PO', false));
        dto.poSummaryFields.add(field(fieldLabel(Builder_PO__c.Estimated_Start_Date__c), dto.latestPoEstimatedStartDisplay, 'date', null, 'Builder_PO__c', 'Estimated_Start_Date__c', 'Latest Builder PO', false));
        dto.poSummaryFields.add(field(fieldLabel(Builder_PO__c.Takeoff_Status__c), dto.latestTakeoffStatus, 'text', null, 'Builder_PO__c', 'Takeoff_Status__c', 'Latest Builder PO', false));
        dto.poSummaryFields.add(field(fieldLabel(Lot__c.Eight11_Task_Status__c), dto.latestPoEight11Status, 'text', null, 'Lot__c', 'Eight11_Task_Status__c', 'Lot field / latest PO', false));
    }

    private static Map<Id, LotContext> buildContexts(List<Lot__c> lots) {
        Map<Id, LotContext> result = new Map<Id, LotContext>();
        if (lots == null || lots.isEmpty()) return result;

        Set<Id> lotIds = new Set<Id>();
        Set<String> lotNumbers = new Set<String>();
        Map<String, Id> lotIdByNumber = new Map<String, Id>();
        for (Lot__c lot : lots) {
            result.put(lot.Id, new LotContext());
            lotIds.add(lot.Id);
            if (String.isNotBlank(lot.Lot_Number__c)) {
                lotNumbers.add(lot.Lot_Number__c);
                lotIdByNumber.put(lot.Lot_Number__c, lot.Id);
            }
        }

        Set<String> poNumbers = new Set<String>();
        Map<String, Id> lotIdByPoNumber = new Map<String, Id>();
        Map<Id, Id> lotIdByWorkOrderId = new Map<Id, Id>();
        for (Builder_PO__c po : [
            SELECT Id, PO_Number__c, Lot__c, Status__c, Takeoff_Status__c, Eight11_Task_Status__c,
                   Estimated_Start_Date__c, PO_Amount__c, LastModifiedDate
            FROM Builder_PO__c
            WHERE Lot__c IN :lotIds
            ORDER BY LastModifiedDate DESC
        ]) {
            LotContext ctx = result.get(po.Lot__c);
            if (ctx != null && ctx.po == null) ctx.po = po;
            if (String.isNotBlank(po.PO_Number__c)) {
                poNumbers.add(po.PO_Number__c);
                lotIdByPoNumber.put(po.PO_Number__c, po.Lot__c);
            }
        }

        for (Takeoff__c takeoff : [
            SELECT Id, Builder_PO__c, Lot__c, Status__c, Scheduled_Date__c, Checklist_Complete__c,
                   Photo_Count__c, Photos_Count__c, Approved_Date__c, Submitted_Date__c,
                   Completed_Date__c, Sod_Measured_Sqft__c, Mulch_Measured_CY__c,
                   Trees_Count__c, Plants_Count__c, LastModifiedDate
            FROM Takeoff__c
            WHERE Lot__c IN :lotIds
            ORDER BY LastModifiedDate DESC
        ]) {
            LotContext ctx = result.get(takeoff.Lot__c);
            if (ctx == null) continue;
            if (ctx.takeoff == null) ctx.takeoff = takeoff;
            Integer photos = 0;
            if (takeoff.Photo_Count__c != null) photos = Math.max(photos, Integer.valueOf(takeoff.Photo_Count__c));
            if (takeoff.Photos_Count__c != null) photos = Math.max(photos, Integer.valueOf(takeoff.Photos_Count__c));
            ctx.photoCount = Math.max(ctx.photoCount, photos);
        }

        if (!poNumbers.isEmpty() || !lotNumbers.isEmpty()) {
            for (WorkOrder wo : [
                SELECT Id, WorkOrderNumber, Subject, Status, Work_Order_Type__c, Field_Manager__r.Name,
                       Proposed_Schedule_Date__c, PO_Number__c, Lot_Number__c, LastModifiedDate
                FROM WorkOrder
                WHERE PO_Number__c IN :poNumbers OR Lot_Number__c IN :lotNumbers
                ORDER BY LastModifiedDate DESC
                LIMIT 5000
            ]) {
                Id lotId = null;
                if (String.isNotBlank(wo.PO_Number__c) && lotIdByPoNumber.containsKey(wo.PO_Number__c)) {
                    lotId = lotIdByPoNumber.get(wo.PO_Number__c);
                } else if (String.isNotBlank(wo.Lot_Number__c) && lotIdByNumber.containsKey(wo.Lot_Number__c)) {
                    lotId = lotIdByNumber.get(wo.Lot_Number__c);
                }
                if (lotId == null || !result.containsKey(lotId)) continue;
                LotContext ctx = result.get(lotId);
                ctx.workOrderCount++;
                if (ctx.latestWorkOrder == null) ctx.latestWorkOrder = wo;
                if (ctx.workOrders.size() < 20) ctx.workOrders.add(wo);
                lotIdByWorkOrderId.put(wo.Id, lotId);
            }
        }

        if (!lotIdByWorkOrderId.isEmpty()) {
            for (ServiceAppointment appt : [
                SELECT Id, ParentRecordId, Status, LastModifiedDate
                FROM ServiceAppointment
                WHERE ParentRecordId IN :lotIdByWorkOrderId.keySet()
                ORDER BY LastModifiedDate DESC
                LIMIT 5000
            ]) {
                Id lotId = lotIdByWorkOrderId.get(appt.ParentRecordId);
                LotContext ctx = result.get(lotId);
                if (ctx != null && String.isBlank(ctx.latestServiceAppointmentStatus)) {
                    ctx.latestServiceAppointmentStatus = appt.Status;
                }
            }
        }

        return result;
    }

    private static OptionDTO option(String label, String value) {
        OptionDTO dto = new OptionDTO();
        dto.label = label;
        dto.value = value;
        return dto;
    }

    private static ColumnDTO column(String key, String label, String type, String classKey, Boolean numeric) {
        ColumnDTO dto = new ColumnDTO();
        dto.key = key;
        dto.label = label;
        dto.type = type;
        dto.classKey = classKey;
        dto.numeric = numeric == true;
        return dto;
    }

    private static List<ColumnDTO> lotListColumns() {
        return new List<ColumnDTO>{
            column('lotLabel', fieldLabel(Lot__c.Lot_Number__c), 'link', null, false),
            column('communityName', fieldLabel(Lot__c.Community__c), 'text', null, false),
            column('builderDivisionName', fieldLabel(Community__c.Builder_Account__c), 'text', null, false),
            column('fmName', fieldLabel(Community__c.Assigned_FM__c), 'text', null, false),
            column('address', fieldLabel(Lot__c.Street_Address__c), 'text', null, false),
            column('requestedInstallDisplay', fieldLabel(Lot__c.Requested_Install_Date__c), 'text', null, false),
            column('pipelineBucket', fieldLabel(Lot__c.Pipeline_Bucket__c), 'chip', 'pipelineClass', false),
            column('lotStatus', fieldLabel(Lot__c.Lot_Status__c), 'chip', 'lotStatusClass', false),
            column('eight11Status', fieldLabel(Lot__c.Eight11_Task_Status__c), 'chip', 'eight11Class', false),
            column('takeoffStatus', fieldLabel(Builder_PO__c.Takeoff_Status__c), 'chip', 'takeoffClass', false),
            column('aquaStatus', fieldLabel(Lot__c.Aqua_Add_On__c), 'chip', 'aquaClass', false),
            column('poNumber', fieldLabel(Builder_PO__c.PO_Number__c), 'text', null, false),
            column('poAmountDisplay', fieldLabel(Builder_PO__c.PO_Amount__c), 'text', null, true),
            column('specType', fieldLabel(Lot__c.Spec_Type__c), 'chip', null, false)
        };
    }

    private static List<OptionDTO> pipelinePicklistOptions() {
        List<OptionDTO> results = new List<OptionDTO>();
        for (Schema.PicklistEntry entry : Lot__c.Pipeline_Bucket__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) continue;
            String value = normalizePipeline(entry.getValue());
            if (String.isNotBlank(value)) results.add(option(entry.getLabel(), value));
        }
        return results;
    }

    private static void addHierarchyNode(List<String> hierarchy, String value) {
        if (String.isNotBlank(value)) hierarchy.add(value);
    }

    private static RelatedCountDTO related(String label, Integer count) {
        RelatedCountDTO dto = new RelatedCountDTO();
        dto.label = label;
        dto.count = count;
        return dto;
    }

    private static DetailFieldDTO field(String label, String value, String type, String link, String objectApiName, String fieldApiName, String source, Boolean editable) {
        return field(label, value, type, link, objectApiName, fieldApiName, source, editable, null);
    }

    private static DetailFieldDTO field(String label, String value, String type, String link, String objectApiName, String fieldApiName, String source, Boolean editable, List<OptionDTO> options) {
        DetailFieldDTO dto = new DetailFieldDTO();
        dto.label = label;
        dto.value = String.isBlank(value) ? '-' : value;
        dto.type = type;
        dto.link = link;
        dto.objectApiName = objectApiName;
        dto.fieldApiName = fieldApiName;
        dto.source = source;
        dto.editable = editable == true && isFieldUpdateable(objectApiName, fieldApiName);
        dto.options = options;
        return dto;
    }

    private static List<OptionDTO> picklistOptions(Schema.DescribeFieldResult describeField) {
        List<OptionDTO> results = new List<OptionDTO>();
        if (describeField == null) return results;
        for (Schema.PicklistEntry entry : describeField.getPicklistValues()) {
            if (entry.isActive()) results.add(option(entry.getLabel(), entry.getValue()));
        }
        return results;
    }

    private static String fieldLabel(Schema.SObjectField sobjectField) {
        return sobjectField.getDescribe().getLabel();
    }

    private static Boolean isFieldUpdateable(String objectApiName, String fieldApiName) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) return false;
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null) return false;
        Schema.SObjectField objectField = objectType.getDescribe().fields.getMap().get(fieldApiName);
        return objectField != null && objectField.getDescribe().isUpdateable();
    }

    private static String buildLotTitle(Lot__c lot) {
        if (String.isBlank(lot.Lot_Number__c)) return lot.Name;
        String communityName = lot.Community__r == null ? '' : lot.Community__r.Name;
        return 'Lot ' + lot.Lot_Number__c + ' - ' + communityName;
    }

    private static String buildLotChip(Lot__c lot) {
        return String.isBlank(lot.Lot_Number__c) ? lot.Name : 'Lot ' + lot.Lot_Number__c;
    }

    private static String canonicalLotStatus(Lot__c lot) {
        if (String.isNotBlank(lot.Lot_Status__c)) return lot.Lot_Status__c;
        if (String.isNotBlank(lot.Status__c)) return lot.Status__c;
        return 'Open';
    }

    private static String deriveAquaStatus(Lot__c lot) {
        if (lot.Aqua_Installed__c == true) return 'Installed';
        if (lot.Aqua_Add_On__c != null && lot.Aqua_Add_On__c > 0) return 'Auto';
        if (lot.Community__r != null && lot.Community__r.Aqua_Customer__c == true) return 'Auto';
        return 'N/A';
    }

    private static String deriveTakeoffStatus(Builder_PO__c po, Takeoff__c takeoff) {
        if (po != null && String.isNotBlank(po.Takeoff_Status__c)) return po.Takeoff_Status__c;
        if (takeoff != null) {
            if (takeoff.Scheduled_Date__c != null) return 'Scheduled ' + formatDate(takeoff.Scheduled_Date__c);
            if (String.isNotBlank(takeoff.Status__c)) return takeoff.Status__c;
        }
        return 'Not Started';
    }

    private static String derivePipelineBucket(Lot__c lot, Builder_PO__c po, Takeoff__c takeoff, WorkOrder latestWo, String latestServiceAppointmentStatus) {
        String lotStage = normalizePipeline(lot.Lot_Status__c);
        if (isPipelineStage(lotStage)) return lotStage;
        if (String.isNotBlank(lot.Pipeline_Bucket__c)) return normalizePipeline(lot.Pipeline_Bucket__c);
        String lotStatus = canonicalLotStatus(lot);
        if (lotStatus == 'Closed') return 'Closed';
        String serviceAppointmentBucket = pipelineFromServiceAppointmentStatus(latestServiceAppointmentStatus);
        if (String.isNotBlank(serviceAppointmentBucket)) return serviceAppointmentBucket;
        if (latestWo != null) {
            if (latestWo.Status == 'In Progress' || latestWo.Status == 'Dispatched') return 'In Progress';
            if (latestWo.Status == 'Ready to Schedule' || latestWo.Status == 'Scheduled') return 'Scheduled';
            if (latestWo.Status == 'Pending Closeout') return 'QI';
        }
        if (po != null) {
            if (po.Status__c == 'Scheduled') return 'Scheduled';
            if ((po.Takeoff_Status__c == 'Approved' || po.Takeoff_Status__c == 'Locked') && po.Eight11_Task_Status__c == 'Cleared') return 'Site Ready';
            if (po.Takeoff_Status__c == 'Approved' || po.Takeoff_Status__c == 'Locked') return 'Takeoff Complete';
            if (po.Takeoff_Status__c == 'Scheduled' || po.Takeoff_Status__c == 'In Progress' || po.Takeoff_Status__c == 'Submitted' || po.Takeoff_Status__c == 'Submitted for Approval') return 'Pending Scheduling';
        }
        if (takeoff != null && (takeoff.Status__c == 'Approved' || takeoff.Status__c == 'Locked' || takeoff.Status__c == 'Complete' || takeoff.Status__c == 'Completed')) {
            return lot.Eight11_Task_Status__c == 'Cleared' ? 'Site Ready' : 'Takeoff Complete';
        }
        if (takeoff != null && takeoff.Scheduled_Date__c != null) return 'Pending Scheduling';
        if (takeoff != null && takeoff.Status__c == 'In Progress') return 'Pending Scheduling';
        if (lot.Requested_Install_Date__c != null) {
            Integer days = Date.today().daysBetween(lot.Requested_Install_Date__c);
            if (days > 90) return 'New';
            return 'Pending Scheduling';
        }
        return 'New';
    }

    private static String normalizePipeline(String rawValue) {
        if (String.isBlank(rawValue)) return rawValue;
        if (rawValue == 'New') return 'New';
        if (rawValue == 'Pending Scheduling') return 'Pending Scheduling';
        if (rawValue == 'Scheduled') return 'Scheduled';
        if (rawValue == 'Takeoff Complete') return 'Takeoff Complete';
        if (rawValue == 'Site Ready') return 'Site Ready';
        if (rawValue == 'In Progress') return 'In Progress';
        if (rawValue == 'QI') return 'QI';
        if (rawValue == 'Closed') return 'Closed';
        if (rawValue == 'Ready to Invoice') return 'Ready to Invoice';
        if (rawValue == 'Invoiced') return 'Invoiced';
        if (rawValue == '90+ Days') return 'New';
        if (rawValue == '60+ Days') return 'Pending Scheduling';
        if (rawValue == '31 Days' || rawValue == '30 Days' || rawValue == '15 Days') return 'Pending Scheduling';
        if (rawValue == 'Clear to Schedule' || rawValue == 'Ready to Schedule' || rawValue == 'Clear for Schedule') return 'Site Ready';
        if (rawValue == 'In Production' || rawValue == 'Active Today') return 'In Progress';
        if (rawValue == 'Pending Takeoff' || rawValue == 'Under Construction' || rawValue == 'Takeoff Scheduled') return 'Pending Scheduling';
        if (rawValue == 'Installed' || rawValue == 'Pending Closeout') return 'QI';
        return rawValue;
    }

    private static Boolean isPipelineStage(String value) {
        return value == 'New'
            || value == 'Pending Scheduling'
            || value == 'Scheduled'
            || value == 'Takeoff Complete'
            || value == 'Site Ready'
            || value == 'In Progress'
            || value == 'QI'
            || value == 'Closed'
            || value == 'Ready to Invoice'
            || value == 'Invoiced';
    }

    private static String pipelineFromServiceAppointmentStatus(String status) {
        if (String.isBlank(status)) return null;
        if (status == 'None' || status == 'New' || status == 'Open') return 'Scheduled';
        if (status == 'Scheduled' || status == 'Dispatched') return 'Scheduled';
        if (status == 'In Progress' || status == 'On Site') return 'In Progress';
        if (status == 'Cannot Complete' || status == 'Canceled' || status == 'Cancelled') return 'QI';
        if (status == 'Completed') return 'QI';
        return null;
    }

    private static String pipelineClass(String bucket) {
        if (bucket == 'New') return 'pb-new';
        if (bucket == 'Pending Scheduling') return 'pb-pending';
        if (bucket == 'Scheduled') return 'pb-sched';
        if (bucket == 'Takeoff Complete') return 'pb-takeoff';
        if (bucket == 'Site Ready') return 'pb-clear';
        if (bucket == 'In Progress') return 'pb-active';
        if (bucket == 'QI') return 'pb-qi';
        if (bucket == 'Closed') return 'pb-closed';
        if (bucket == 'Ready to Invoice') return 'pb-invoice';
        if (bucket == 'Invoiced') return 'pb-invoiced';
        return 'pb-new';
    }

    private static String lotStatusClass(String status) {
        if (status == 'Installed' || status == 'Closed') return 'cg';
        if (status == 'In Production') return 'cb2';
        if (status == 'Under Construction') return 'ca';
        return 'cgr';
    }

    private static String statusPillClass(String status, String kind) {
        if (String.isBlank(status) || status == '-' || status == 'N/A' || status == 'Not Started') return 'cgr';
        if (kind == 'eight11') {
            if (status == 'Cleared' || status == 'Marked' || status == 'Not Needed') return 'cg';
            if (status == 'Filed' || status == 'Pending Locate') return 'cb2';
            if (status == 'Not Filed' || status == 'On Hold') return 'cr';
        }
        if (kind == 'takeoff') {
            if (status == 'Locked' || status == 'Approved') return 'cg';
            if (status.startsWith('Scheduled') || status == 'In Progress' || status == 'Submitted' || status == 'Submitted for Approval') return 'cp';
            if (status == 'Returned') return 'cr';
        }
        if (kind == 'aqua') {
            if (status == 'Installed') return 'cg';
            if (status == 'Auto') return 'cb2';
        }
        if (kind == 'workorder') {
            if (status == 'In Progress' || status == 'Dispatched') return 'cb2';
            if (status == 'Scheduled' || status == 'Ready to Schedule') return 'cg';
            if (status == 'Pending Closeout') return 'ca';
        }
        return 'cgr';
    }

    private static String buildInstallBanner(Lot__c lot, Builder_PO__c po, Takeoff__c takeoff, WorkOrder latestWo) {
        List<String> parts = new List<String>();
        if (latestWo != null) parts.add('Latest work order ' + latestWo.WorkOrderNumber + ' is ' + latestWo.Status);
        if (po != null && po.PO_Amount__c != null) parts.add('PO value ' + formatCurrency(po.PO_Amount__c));
        if (lot.Sod_SF__c != null) parts.add(formatWhole(lot.Sod_SF__c) + ' sf sod');
        if (takeoff != null && String.isNotBlank(takeoff.Status__c)) parts.add('Takeoff ' + takeoff.Status__c);
        if (deriveAquaStatus(lot) != 'N/A') parts.add('Aqua ' + deriveAquaStatus(lot).toLowerCase());
        return parts.isEmpty() ? 'No active execution note on this lot yet.' : String.join(parts, ' | ');
    }

    private static void addTimeline(List<TimelineItemDTO> items, String label, Date dateValue, Boolean complete) {
        addTimeline(items, label, formatDate(dateValue), complete);
    }

    private static void addTimeline(List<TimelineItemDTO> items, String label, String dateLabel, Boolean complete) {
        TimelineItemDTO dto = new TimelineItemDTO();
        dto.label = label;
        dto.dateLabel = String.isBlank(dateLabel) ? '-' : dateLabel;
        dto.complete = complete == true;
        dto.statusClass = dto.complete ? 'done' : 'future';
        items.add(dto);
    }

    private static String coordinateLabel(Decimal lat, Decimal lng) {
        if (lat == null || lng == null) return '-';
        return String.valueOf(lat) + ', ' + String.valueOf(lng);
    }

    private static String formatDate(Date value) {
        if (value == null) return '-';
        return value.format();
    }

    private static String formatDateTime(Datetime value) {
        if (value == null) return '-';
        return value.format();
    }

    private static String formatCurrency(Decimal value) {
        if (value == null) return '-';
        Decimal scaled = value.setScale(0);
        return '$' + String.valueOf(scaled).replace('.0', '');
    }

    private static String formatWhole(Decimal value) {
        if (value == null) return '-';
        Decimal scaled = value.setScale(0);
        return String.valueOf(scaled).replace('.0', '');
    }

    private static String quantityLabel(Integer qty, String noun) {
        if (qty == null) return '-';
        String suffix = qty == 1 ? noun : noun + 's';
        return qty + ' ' + suffix;
    }

    private static String buildMapsLink(String address, Decimal lat, Decimal lng) {
        if (lat != null && lng != null) return 'https://maps.google.com/?q=' + lat + ',' + lng;
        if (String.isBlank(address)) return null;
        return 'https://maps.google.com/?q=' + EncodingUtil.urlEncode(address, 'UTF-8');
    }

    private static String firstNonBlank(String firstValue, String secondValue) {
        if (String.isNotBlank(firstValue)) return firstValue;
        if (String.isNotBlank(secondValue)) return secondValue;
        return null;
    }

    private static String nullToDash(String value) {
        return String.isBlank(value) ? '-' : value;
    }
}