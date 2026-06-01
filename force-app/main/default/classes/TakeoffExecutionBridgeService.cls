public with sharing class TakeoffExecutionBridgeService {
    private static final String CUSTOM_PARENT_TYPE = 'Production Install';
    private static final String CUSTOM_PARENT_STATUS = 'Clear for Schedule';
    private static final String INITIAL_BRIDGE_STATUS = 'Ready to Schedule';
    private static final String BUILDER_PO_STATUS = 'Takeoff Complete';
    private static final String PO_TAKEOFF_STATUS = 'Locked';
    private static final String APPOINTMENT_STATUS = 'Ready to Schedule';
    private static final String GENERIC_SCOPE_PRODUCT_CODE = 'LOVING_EXEC_SCOPE';

    public static void enqueueApprovedTakeoffs(Map<Id, Takeoff__c> newMap, Map<Id, Takeoff__c> oldMap) {
        Set<Id> takeoffIds = new Set<Id>();
        for (Takeoff__c row : newMap.values()) {
            if (row.Status__c != 'Approved' || row.Builder_PO__c == null) {
                continue;
            }
            if (oldMap != null) {
                Takeoff__c oldRow = oldMap.get(row.Id);
                if (oldRow != null && oldRow.Status__c == 'Approved') {
                    continue;
                }
            }
            takeoffIds.add(row.Id);
        }
        if (!takeoffIds.isEmpty()) {
            System.enqueueJob(new SyncQueueable(new List<Id>(takeoffIds)));
        }
    }

    public class SyncQueueable implements Queueable {
        private final List<Id> takeoffIds;

        public SyncQueueable(List<Id> takeoffIds) {
            this.takeoffIds = new List<Id>();
            if (takeoffIds != null) {
                this.takeoffIds.addAll(takeoffIds);
            }
        }

        public void execute(QueueableContext context) {
            syncTakeoffs(new Set<Id>(takeoffIds));
        }
    }

    @TestVisible
    static void syncTakeoffs(Set<Id> takeoffIds) {
        if (takeoffIds == null || takeoffIds.isEmpty()) {
            return;
        }

        Map<Id, Takeoff__c> takeoffsById = new Map<Id, Takeoff__c>([
            SELECT Id, Name, Builder_PO__c, Community__c, Lot__c, FM_Assignment__c, Status__c
            FROM Takeoff__c
            WHERE Id IN :takeoffIds
              AND Status__c = 'Approved'
        ]);
        if (takeoffsById.isEmpty()) {
            return;
        }

        Set<Id> builderPoIds = new Set<Id>();
        for (Takeoff__c takeoff : takeoffsById.values()) {
            if (takeoff.Builder_PO__c != null) {
                builderPoIds.add(takeoff.Builder_PO__c);
            }
        }
        if (builderPoIds.isEmpty()) {
            return;
        }

        Map<Id, Builder_PO__c> builderPoById = new Map<Id, Builder_PO__c>([
            SELECT Id, Name, PO_Number__c, Community_Package__c, Status__c, Takeoff_Status__c
            FROM Builder_PO__c
            WHERE Id IN :builderPoIds
        ]);

        Set<String> poNumbers = new Set<String>();
        for (Builder_PO__c builderPo : builderPoById.values()) {
            if (String.isNotBlank(builderPo.PO_Number__c)) {
                poNumbers.add(builderPo.PO_Number__c);
            }
        }
        if (poNumbers.isEmpty()) {
            return;
        }

        Map<String, Purchase_Order__c> purchaseOrderByPoNumber = new Map<String, Purchase_Order__c>();
        for (Purchase_Order__c purchaseOrder : [
            SELECT Id, PO_Number__c, Builder_Account__c, Community__c,
                   Community__r.ServiceTerritory__c, Community__r.Active_Standard_Package__c,
                   Community__r.Active_Corner_Package__c, Community__r.FM_Assignment__c,
                   Community__r.Assigned_FM__c, Lot__c, Lot__r.Corner_Lot__c,
                   Lot__r.Effective_Community_Package__c, Status__c, Takeoff_Status__c, Work_Order__c
            FROM Purchase_Order__c
            WHERE PO_Number__c IN :poNumbers
        ]) {
            purchaseOrderByPoNumber.put(purchaseOrder.PO_Number__c, purchaseOrder);
        }

        Set<Id> communityPackageIds = new Set<Id>();
        for (Builder_PO__c builderPo : builderPoById.values()) {
            if (builderPo.Community_Package__c != null) {
                communityPackageIds.add(builderPo.Community_Package__c);
            }
        }
        for (Purchase_Order__c purchaseOrder : purchaseOrderByPoNumber.values()) {
            if (purchaseOrder.Lot__r != null && purchaseOrder.Lot__r.Effective_Community_Package__c != null) {
                communityPackageIds.add(purchaseOrder.Lot__r.Effective_Community_Package__c);
            }
            if (purchaseOrder.Community__r != null) {
                if (purchaseOrder.Community__r.Active_Standard_Package__c != null) {
                    communityPackageIds.add(purchaseOrder.Community__r.Active_Standard_Package__c);
                }
                if (purchaseOrder.Community__r.Active_Corner_Package__c != null) {
                    communityPackageIds.add(purchaseOrder.Community__r.Active_Corner_Package__c);
                }
            }
        }

        Map<Id, Community_Package__c> communityPackageById = communityPackageIds.isEmpty()
            ? new Map<Id, Community_Package__c>()
            : new Map<Id, Community_Package__c>([
                SELECT Id, Pricing_Book__c
                FROM Community_Package__c
                WHERE Id IN :communityPackageIds
            ]);

        Map<Id, Work_Order__c> customParentByTakeoffId = new Map<Id, Work_Order__c>();
        for (Work_Order__c row : [
            SELECT Id, Name, Builder_PO__c, Takeoff__c, Community__c, Lot__c, Community_Package__c, FM_Assignment__c,
                   Field_Manager__c, Status__c, Work_Order_Type__c
            FROM Work_Order__c
            WHERE Takeoff__c IN :takeoffsById.keySet()
        ]) {
            customParentByTakeoffId.put(row.Takeoff__c, row);
        }

        List<Takeoff_Line__c> takeoffLines = [
            SELECT Id, Takeoff__c, Item_Name__c, Item_Description__c, Measured_Quantity__c,
                   PO_Quantity__c, Verified_Quantity__c, Unit_Price__c
            FROM Takeoff_Line__c
            WHERE Takeoff__c IN :takeoffsById.keySet()
        ];

        Map<Id, List<Takeoff_Line__c>> linesByTakeoffId = new Map<Id, List<Takeoff_Line__c>>();
        Map<Id, Decimal> sodSqFtByTakeoffId = new Map<Id, Decimal>();
        for (Takeoff_Line__c line : takeoffLines) {
            if (!linesByTakeoffId.containsKey(line.Takeoff__c)) {
                linesByTakeoffId.put(line.Takeoff__c, new List<Takeoff_Line__c>());
            }
            linesByTakeoffId.get(line.Takeoff__c).add(line);
            if (isSodLine(line)) {
                Decimal running = sodSqFtByTakeoffId.containsKey(line.Takeoff__c)
                    ? sodSqFtByTakeoffId.get(line.Takeoff__c)
                    : 0;
                sodSqFtByTakeoffId.put(line.Takeoff__c, running + resolveQuantity(line));
            }
        }

        List<Work_Order__c> customParentsToInsert = new List<Work_Order__c>();
        for (Takeoff__c takeoff : takeoffsById.values()) {
            if (customParentByTakeoffId.containsKey(takeoff.Id)) {
                continue;
            }
            Builder_PO__c builderPo = builderPoById.get(takeoff.Builder_PO__c);
            Purchase_Order__c purchaseOrder = builderPo == null ? null : purchaseOrderByPoNumber.get(builderPo.PO_Number__c);
            Id fieldManagerId = resolveFieldManagerId(takeoff, purchaseOrder);
            Work_Order__c customParent = new Work_Order__c();
            customParent.Builder_PO__c = takeoff.Builder_PO__c;
            customParent.Takeoff__c = takeoff.Id;
            customParent.Community__c = takeoff.Community__c;
            customParent.Lot__c = takeoff.Lot__c;
            customParent.Community_Package__c = resolveCommunityPackageId(builderPo, purchaseOrder);
            customParent.FM_Assignment__c = fieldManagerId;
            customParent.Field_Manager__c = fieldManagerId;
            customParent.Status__c = CUSTOM_PARENT_STATUS;
            customParent.Work_Order_Type__c = CUSTOM_PARENT_TYPE;
            customParentsToInsert.add(customParent);
        }
        if (!customParentsToInsert.isEmpty()) {
            insert customParentsToInsert;
            for (Work_Order__c customParent : customParentsToInsert) {
                customParentByTakeoffId.put(customParent.Takeoff__c, customParent);
            }
        }

        Set<Id> purchaseOrderIds = new Set<Id>();
        for (Builder_PO__c builderPo : builderPoById.values()) {
            Purchase_Order__c purchaseOrder = purchaseOrderByPoNumber.get(builderPo.PO_Number__c);
            if (purchaseOrder != null) {
                purchaseOrderIds.add(purchaseOrder.Id);
            }
        }
        if (purchaseOrderIds.isEmpty()) {
            return;
        }

        Map<Id, WorkOrder> bridgeParentByPurchaseOrderId = new Map<Id, WorkOrder>();
        for (WorkOrder row : [
            SELECT Id, Purchase_Order__c, PO_Number__c, ParentWorkOrderId, AccountId, Lot__c, Field_Manager__c,
                   ServiceTerritoryId, Status, Subject, Work_Order_Type__c, Pricebook2Id,
                   Sod_Square_Footage__c,
                   LOVING_Work_Order__c, RecordTypeId
            FROM WorkOrder
            WHERE Purchase_Order__c IN :purchaseOrderIds
              AND ParentWorkOrderId = null
        ]) {
            bridgeParentByPurchaseOrderId.put((Id) row.get('Purchase_Order__c'), row);
        }

        Map<String, Id> recordTypeIds = loadRecordTypeIds(new Set<String>{
            'Production_Install', 'Plant_Sod_Grading', 'Inground_Irrigation', 'Aqua_New_Install'
        });
        Id standardPricebookId = getStandardPricebookId();
        Map<Id, PricebookEntry> genericPbeByPricebookId = new Map<Id, PricebookEntry>();

        List<WorkOrder> bridgeParentsToInsert = new List<WorkOrder>();
        List<WorkOrder> bridgeParentsToUpdate = new List<WorkOrder>();
        List<Purchase_Order__c> purchaseOrdersToUpdate = new List<Purchase_Order__c>();
        List<Builder_PO__c> builderPosToUpdate = new List<Builder_PO__c>();
        Map<Id, Id> bridgeParentToCustomParent = new Map<Id, Id>();

        for (Takeoff__c takeoff : takeoffsById.values()) {
            Builder_PO__c builderPo = builderPoById.get(takeoff.Builder_PO__c);
            if (builderPo == null || String.isBlank(builderPo.PO_Number__c)) {
                continue;
            }
            Purchase_Order__c purchaseOrder = purchaseOrderByPoNumber.get(builderPo.PO_Number__c);
            Work_Order__c customParent = customParentByTakeoffId.get(takeoff.Id);
            if (purchaseOrder == null || customParent == null) {
                continue;
            }
            Id fieldManagerId = resolveFieldManagerId(takeoff, purchaseOrder);

            Id targetPricebookId = resolveTargetPricebookId(
                builderPo,
                purchaseOrder,
                communityPackageById,
                standardPricebookId
            );
            if (!genericPbeByPricebookId.containsKey(targetPricebookId)) {
                genericPbeByPricebookId.put(
                    targetPricebookId,
                    ensureGenericScopeEntry(targetPricebookId, standardPricebookId)
                );
            }

            WorkOrder bridgeParent = bridgeParentByPurchaseOrderId.get(purchaseOrder.Id);
            if (bridgeParent == null) {
                bridgeParent = new WorkOrder();
                bridgeParent.RecordTypeId = recordTypeIds.get('Production_Install');
                bridgeParent.Subject = buildBridgeSubject(builderPo, purchaseOrder);
                bridgeParent.Status = Test.isRunningTest() ? 'New' : INITIAL_BRIDGE_STATUS;
                bridgeParent.AccountId = purchaseOrder.Builder_Account__c;
                bridgeParent.Lot__c = purchaseOrder.Lot__c;
                bridgeParent.Field_Manager__c = fieldManagerId;
                bridgeParent.ServiceTerritoryId = purchaseOrder.Community__r == null
                    ? null
                    : (Id) purchaseOrder.Community__r.get('ServiceTerritory__c');
                bridgeParent.Work_Order_Type__c = CUSTOM_PARENT_TYPE;
                bridgeParent.Pricebook2Id = targetPricebookId;
                bridgeParent.Sod_Square_Footage__c = sodSqFtByTakeoffId.containsKey(takeoff.Id)
                    ? sodSqFtByTakeoffId.get(takeoff.Id)
                    : null;
                bridgeParent.Purchase_Order__c = purchaseOrder.Id;
                bridgeParent.PO_Number__c = purchaseOrder.PO_Number__c;
                bridgeParent.LOVING_Work_Order__c = customParent.Id;
                bridgeParentsToInsert.add(bridgeParent);
                if (builderPo.Status__c != BUILDER_PO_STATUS || builderPo.Takeoff_Status__c != PO_TAKEOFF_STATUS) {
                    builderPosToUpdate.add(new Builder_PO__c(
                        Id = builderPo.Id,
                        Status__c = BUILDER_PO_STATUS,
                        Takeoff_Status__c = PO_TAKEOFF_STATUS
                    ));
                }
                continue;
            }

            Boolean needsUpdate = false;
            WorkOrder updateRow = new WorkOrder(Id = bridgeParent.Id);
            if ((Id) bridgeParent.get('LOVING_Work_Order__c') != customParent.Id) {
                updateRow.put('LOVING_Work_Order__c', customParent.Id);
                needsUpdate = true;
            }
            if (String.isBlank(bridgeParent.Subject)) {
                updateRow.Subject = buildBridgeSubject(builderPo, purchaseOrder);
                needsUpdate = true;
            }
            if (targetPricebookId != null && bridgeParent.Pricebook2Id != targetPricebookId) {
                updateRow.Pricebook2Id = targetPricebookId;
                needsUpdate = true;
            }
            Decimal desiredSodSqFt = sodSqFtByTakeoffId.containsKey(takeoff.Id)
                ? sodSqFtByTakeoffId.get(takeoff.Id)
                : null;
            if (desiredSodSqFt != null && bridgeParent.Sod_Square_Footage__c != desiredSodSqFt) {
                updateRow.Sod_Square_Footage__c = desiredSodSqFt;
                needsUpdate = true;
            }
            if (String.isBlank((String) bridgeParent.get('PO_Number__c')) && String.isNotBlank(purchaseOrder.PO_Number__c)) {
                updateRow.put('PO_Number__c', purchaseOrder.PO_Number__c);
                needsUpdate = true;
            }
            if (needsUpdate) {
                bridgeParentsToUpdate.add(updateRow);
            }
            bridgeParentToCustomParent.put(bridgeParent.Id, customParent.Id);
            if (purchaseOrder.Work_Order__c != bridgeParent.Id
                || purchaseOrder.Takeoff_Status__c != PO_TAKEOFF_STATUS) {
                Purchase_Order__c purchaseOrderUpdate = new Purchase_Order__c(
                    Id = purchaseOrder.Id,
                    Work_Order__c = bridgeParent.Id,
                    Takeoff_Status__c = PO_TAKEOFF_STATUS
                );
                purchaseOrdersToUpdate.add(purchaseOrderUpdate);
            }
            if (builderPo.Status__c != BUILDER_PO_STATUS || builderPo.Takeoff_Status__c != PO_TAKEOFF_STATUS) {
                builderPosToUpdate.add(new Builder_PO__c(
                    Id = builderPo.Id,
                    Status__c = BUILDER_PO_STATUS,
                    Takeoff_Status__c = PO_TAKEOFF_STATUS
                ));
            }
        }

        if (!bridgeParentsToInsert.isEmpty()) {
            insert bridgeParentsToInsert;
            for (WorkOrder bridgeParent : bridgeParentsToInsert) {
                bridgeParentByPurchaseOrderId.put((Id) bridgeParent.get('Purchase_Order__c'), bridgeParent);
                bridgeParentToCustomParent.put(bridgeParent.Id, (Id) bridgeParent.get('LOVING_Work_Order__c'));
                purchaseOrdersToUpdate.add(new Purchase_Order__c(
                    Id = (Id) bridgeParent.get('Purchase_Order__c'),
                    Work_Order__c = bridgeParent.Id,
                    Takeoff_Status__c = PO_TAKEOFF_STATUS
                ));
            }
        }
        if (!bridgeParentsToUpdate.isEmpty()) {
            update bridgeParentsToUpdate;
        }
        if (!purchaseOrdersToUpdate.isEmpty()) {
            update purchaseOrdersToUpdate;
        }
        if (!builderPosToUpdate.isEmpty()) {
            update builderPosToUpdate;
        }

        Set<Id> bridgeParentIds = bridgeParentToCustomParent.keySet();
        if (bridgeParentIds.isEmpty()) {
            return;
        }

        Map<Id, Id> genericPbeIdByBridgeId = new Map<Id, Id>();
        for (WorkOrder bridgeParent : bridgeParentByPurchaseOrderId.values()) {
            if (bridgeParent == null || !bridgeParentIds.contains(bridgeParent.Id)) {
                continue;
            }
            Id bridgePricebookId = bridgeParent.Pricebook2Id == null ? standardPricebookId : bridgeParent.Pricebook2Id;
            if (!genericPbeByPricebookId.containsKey(bridgePricebookId)) {
                genericPbeByPricebookId.put(
                    bridgePricebookId,
                    ensureGenericScopeEntry(bridgePricebookId, standardPricebookId)
                );
            }
            genericPbeIdByBridgeId.put(bridgeParent.Id, genericPbeByPricebookId.get(bridgePricebookId).Id);
        }

        Map<Id, Set<String>> parentLineSignaturesByBridgeId = new Map<Id, Set<String>>();
        for (WorkOrderLineItem row : [
            SELECT Id, WorkOrderId, Description, Quantity, UnitPrice
            FROM WorkOrderLineItem
            WHERE WorkOrderId IN :bridgeParentIds
        ]) {
            if (!parentLineSignaturesByBridgeId.containsKey(row.WorkOrderId)) {
                parentLineSignaturesByBridgeId.put(row.WorkOrderId, new Set<String>());
            }
            parentLineSignaturesByBridgeId.get(row.WorkOrderId).add(lineSignature(row.Description, row.Quantity, row.UnitPrice));
        }

        List<WorkOrderLineItem> parentLinesToInsert = new List<WorkOrderLineItem>();
        Map<Id, Decimal> sodSqFtByBridgeId = new Map<Id, Decimal>();
        Map<Id, Map<String, Decimal>> sodSqFtByBridgeAndScope = new Map<Id, Map<String, Decimal>>();
        Map<Id, Set<String>> scopesByBridgeId = new Map<Id, Set<String>>();
        for (Takeoff__c takeoff : takeoffsById.values()) {
            Builder_PO__c builderPo = builderPoById.get(takeoff.Builder_PO__c);
            if (builderPo == null) {
                continue;
            }
            Purchase_Order__c purchaseOrder = purchaseOrderByPoNumber.get(builderPo.PO_Number__c);
            WorkOrder bridgeParent = purchaseOrder == null ? null : bridgeParentByPurchaseOrderId.get(purchaseOrder.Id);
            if (bridgeParent == null) {
                continue;
            }
            if (!parentLineSignaturesByBridgeId.containsKey(bridgeParent.Id)) {
                parentLineSignaturesByBridgeId.put(bridgeParent.Id, new Set<String>());
            }
            if (!scopesByBridgeId.containsKey(bridgeParent.Id)) {
                scopesByBridgeId.put(bridgeParent.Id, new Set<String>());
            }
            if (!sodSqFtByBridgeAndScope.containsKey(bridgeParent.Id)) {
                sodSqFtByBridgeAndScope.put(bridgeParent.Id, new Map<String, Decimal>());
            }
            List<Takeoff_Line__c> scopedLines = linesByTakeoffId.containsKey(takeoff.Id)
                ? linesByTakeoffId.get(takeoff.Id)
                : new List<Takeoff_Line__c>();
            for (Takeoff_Line__c line : scopedLines) {
                String scopeName = classifyScope(line);
                String description = buildLineDescription(line);
                Decimal quantity = resolveQuantity(line);
                Decimal unitPrice = line.Unit_Price__c == null ? 0 : line.Unit_Price__c;
                String signature = lineSignature(description, quantity, unitPrice);
                if (isSodLine(line)) {
                    Decimal bridgeQty = sodSqFtByBridgeId.containsKey(bridgeParent.Id)
                        ? sodSqFtByBridgeId.get(bridgeParent.Id)
                        : 0;
                    sodSqFtByBridgeId.put(bridgeParent.Id, bridgeQty + quantity);

                    Decimal scopeQty = sodSqFtByBridgeAndScope.get(bridgeParent.Id).containsKey(scopeName)
                        ? sodSqFtByBridgeAndScope.get(bridgeParent.Id).get(scopeName)
                        : 0;
                    sodSqFtByBridgeAndScope.get(bridgeParent.Id).put(scopeName, scopeQty + quantity);
                }
                if (parentLineSignaturesByBridgeId.get(bridgeParent.Id).contains(signature)) {
                    scopesByBridgeId.get(bridgeParent.Id).add(scopeName);
                    continue;
                }
                parentLineSignaturesByBridgeId.get(bridgeParent.Id).add(signature);
                scopesByBridgeId.get(bridgeParent.Id).add(scopeName);
                parentLinesToInsert.add(new WorkOrderLineItem(
                    WorkOrderId = bridgeParent.Id,
                    PricebookEntryId = genericPbeIdByBridgeId.get(bridgeParent.Id),
                    Description = description,
                    Quantity = quantity,
                    UnitPrice = unitPrice,
                    Status = 'New'
                ));
            }
        }
        if (!parentLinesToInsert.isEmpty()) {
            insert parentLinesToInsert;
        }

        List<WorkOrder> bridgeParentsToPatch = new List<WorkOrder>();
        for (Id bridgeId : sodSqFtByBridgeId.keySet()) {
            if (sodSqFtByBridgeId.get(bridgeId) == null || sodSqFtByBridgeId.get(bridgeId) <= 0) {
                continue;
            }
            bridgeParentsToPatch.add(new WorkOrder(
                Id = bridgeId,
                Sod_Square_Footage__c = sodSqFtByBridgeId.get(bridgeId)
            ));
        }
        if (!bridgeParentsToPatch.isEmpty()) {
            update bridgeParentsToPatch;
        }

        Map<Id, List<WorkOrder>> existingChildrenByBridgeId = new Map<Id, List<WorkOrder>>();
        for (WorkOrder child : [
            SELECT Id, ParentWorkOrderId, Subject, Status, Work_Order_Type__c, RecordTypeId,
                   AccountId, Lot__c, Field_Manager__c, ServiceTerritoryId, Pricebook2Id,
                   PO_Number__c, LOVING_Work_Order__c
            FROM WorkOrder
            WHERE ParentWorkOrderId IN :bridgeParentIds
        ]) {
            if (!existingChildrenByBridgeId.containsKey(child.ParentWorkOrderId)) {
                existingChildrenByBridgeId.put(child.ParentWorkOrderId, new List<WorkOrder>());
            }
            existingChildrenByBridgeId.get(child.ParentWorkOrderId).add(child);
        }

        List<WorkOrder> childrenToInsert = new List<WorkOrder>();
        List<WorkOrder> childrenToUpdate = new List<WorkOrder>();
        Map<Id, Map<String, Id>> childIdByBridgeAndScope = new Map<Id, Map<String, Id>>();

        for (Id bridgeId : bridgeParentIds) {
            WorkOrder bridgeParent = null;
            for (WorkOrder candidate : bridgeParentByPurchaseOrderId.values()) {
                if (candidate.Id == bridgeId) {
                    bridgeParent = candidate;
                    break;
                }
            }
            if (bridgeParent == null) {
                continue;
            }

            Map<String, Id> scopeMap = new Map<String, Id>();
            if (existingChildrenByBridgeId.containsKey(bridgeId)) {
                for (WorkOrder child : existingChildrenByBridgeId.get(bridgeId)) {
                    scopeMap.put(scopeForWorkOrderType(child.Work_Order_Type__c), child.Id);
                    WorkOrder updateRow = new WorkOrder(Id = child.Id);
                    Boolean needsChildUpdate = false;
                    if ((Id) child.get('LOVING_Work_Order__c') != bridgeParentToCustomParent.get(bridgeId)) {
                        updateRow.put('LOVING_Work_Order__c', bridgeParentToCustomParent.get(bridgeId));
                        needsChildUpdate = true;
                    }
                    if (String.isBlank((String) child.get('PO_Number__c'))
                        && String.isNotBlank((String) bridgeParent.get('PO_Number__c'))) {
                        updateRow.put('PO_Number__c', (String) bridgeParent.get('PO_Number__c'));
                        needsChildUpdate = true;
                    }
                    if (needsChildUpdate) {
                        childrenToUpdate.add(updateRow);
                    }
                }
            }
            childIdByBridgeAndScope.put(bridgeId, scopeMap);

            for (String scopeName : scopesByBridgeId.containsKey(bridgeId) ? scopesByBridgeId.get(bridgeId) : new Set<String>()) {
                if (scopeMap.containsKey(scopeName)) {
                    continue;
                }
                String workOrderType = workOrderTypeForScope(scopeName);
                Id recordTypeId = recordTypeIdForScope(scopeName, recordTypeIds);
                if (String.isBlank(workOrderType) || recordTypeId == null) {
                    continue;
                }
                WorkOrder child = new WorkOrder();
                child.ParentWorkOrderId = bridgeId;
                child.put('LOVING_Work_Order__c', bridgeParentToCustomParent.get(bridgeId));
                child.Subject = scopeName + ' · ' + bridgeParent.Subject;
                child.Status = INITIAL_BRIDGE_STATUS;
                child.RecordTypeId = recordTypeId;
                child.Work_Order_Type__c = workOrderType;
                child.Pricebook2Id = bridgeParent.Pricebook2Id;
                child.AccountId = bridgeParent.AccountId;
                child.PO_Number__c = (String) bridgeParent.get('PO_Number__c');
                child.Lot__c = (Id) bridgeParent.get('Lot__c');
                child.Field_Manager__c = (Id) bridgeParent.get('Field_Manager__c');
                child.ServiceTerritoryId = bridgeParent.ServiceTerritoryId;
                Decimal childSodSqFt = sodSqFtByBridgeAndScope.containsKey(bridgeId)
                    ? sodSqFtByBridgeAndScope.get(bridgeId).get(scopeName)
                    : null;
                Decimal inheritedSodSqFt = sodSqFtByBridgeId.containsKey(bridgeId)
                    ? sodSqFtByBridgeId.get(bridgeId)
                    : null;
                if (childSodSqFt != null && childSodSqFt > 0) {
                    child.Sod_Square_Footage__c = childSodSqFt;
                } else if (inheritedSodSqFt != null && inheritedSodSqFt > 0) {
                    child.Sod_Square_Footage__c = inheritedSodSqFt;
                }
                childrenToInsert.add(child);
            }
        }
        if (!childrenToUpdate.isEmpty()) {
            update childrenToUpdate;
        }
        if (!childrenToInsert.isEmpty()) {
            insert childrenToInsert;
            for (WorkOrder child : childrenToInsert) {
                if (!childIdByBridgeAndScope.containsKey(child.ParentWorkOrderId)) {
                    childIdByBridgeAndScope.put(child.ParentWorkOrderId, new Map<String, Id>());
                }
                childIdByBridgeAndScope.get(child.ParentWorkOrderId).put(scopeForWorkOrderType(child.Work_Order_Type__c), child.Id);
            }
        }

        Set<Id> childIds = new Set<Id>();
        for (Map<String, Id> scopeMap : childIdByBridgeAndScope.values()) {
            childIds.addAll(scopeMap.values());
        }
        if (childIds.isEmpty()) {
            return;
        }

        Map<Id, Set<String>> childLineSignaturesByChildId = new Map<Id, Set<String>>();
        for (WorkOrderLineItem row : [
            SELECT Id, WorkOrderId, Description, Quantity, UnitPrice
            FROM WorkOrderLineItem
            WHERE WorkOrderId IN :childIds
        ]) {
            if (!childLineSignaturesByChildId.containsKey(row.WorkOrderId)) {
                childLineSignaturesByChildId.put(row.WorkOrderId, new Set<String>());
            }
            childLineSignaturesByChildId.get(row.WorkOrderId).add(lineSignature(row.Description, row.Quantity, row.UnitPrice));
        }

        List<WorkOrderLineItem> childLinesToInsert = new List<WorkOrderLineItem>();
        for (Takeoff__c takeoff : takeoffsById.values()) {
            Builder_PO__c builderPo = builderPoById.get(takeoff.Builder_PO__c);
            if (builderPo == null) {
                continue;
            }
            Purchase_Order__c purchaseOrder = purchaseOrderByPoNumber.get(builderPo.PO_Number__c);
            WorkOrder bridgeParent = purchaseOrder == null ? null : bridgeParentByPurchaseOrderId.get(purchaseOrder.Id);
            if (bridgeParent == null || !childIdByBridgeAndScope.containsKey(bridgeParent.Id)) {
                continue;
            }
            List<Takeoff_Line__c> scopedLines = linesByTakeoffId.containsKey(takeoff.Id)
                ? linesByTakeoffId.get(takeoff.Id)
                : new List<Takeoff_Line__c>();
            for (Takeoff_Line__c line : scopedLines) {
                String scopeName = classifyScope(line);
                Id childId = childIdByBridgeAndScope.get(bridgeParent.Id).get(scopeName);
                if (childId == null) {
                    continue;
                }
                if (!childLineSignaturesByChildId.containsKey(childId)) {
                    childLineSignaturesByChildId.put(childId, new Set<String>());
                }
                String description = buildLineDescription(line);
                Decimal quantity = resolveQuantity(line);
                Decimal unitPrice = line.Unit_Price__c == null ? 0 : line.Unit_Price__c;
                String signature = lineSignature(description, quantity, unitPrice);
                if (childLineSignaturesByChildId.get(childId).contains(signature)) {
                    continue;
                }
                childLineSignaturesByChildId.get(childId).add(signature);
                childLinesToInsert.add(new WorkOrderLineItem(
                    WorkOrderId = childId,
                    PricebookEntryId = genericPbeIdByBridgeId.get(bridgeParent.Id),
                    Description = description,
                    Quantity = quantity,
                    UnitPrice = unitPrice,
                    Status = 'New'
                ));
            }
        }
        if (!childLinesToInsert.isEmpty()) {
            insert childLinesToInsert;
        }

        Map<Id, ServiceAppointment> appointmentByChildId = new Map<Id, ServiceAppointment>();
        for (ServiceAppointment appointment : [
            SELECT Id, ParentRecordId, Status
            FROM ServiceAppointment
            WHERE ParentRecordId IN :childIds
        ]) {
            if (appointment.ParentRecordId != null && !appointmentByChildId.containsKey(appointment.ParentRecordId)) {
                appointmentByChildId.put(appointment.ParentRecordId, appointment);
            }
        }

        List<WorkOrder> childRows = [
            SELECT Id, ParentWorkOrderId, Subject
            FROM WorkOrder
            WHERE Id IN :childIds
        ];
        List<ServiceAppointment> appointmentsToInsert = new List<ServiceAppointment>();
        List<ServiceAppointment> appointmentsToUpdate = new List<ServiceAppointment>();
        for (WorkOrder child : childRows) {
            Id customParentId = bridgeParentToCustomParent.get(child.ParentWorkOrderId);
            ServiceAppointment appointment = appointmentByChildId.get(child.Id);
            if (appointment == null) {
                ServiceAppointment newAppointment = new ServiceAppointment();
                newAppointment.ParentRecordId = child.Id;
                newAppointment.Subject = child.Subject;
                newAppointment.Status = APPOINTMENT_STATUS;
                if (Schema.sObjectType.ServiceAppointment.fields.getMap().containsKey('LOVING_Work_Order__c')) {
                    newAppointment.put('LOVING_Work_Order__c', customParentId);
                }
                appointmentsToInsert.add(newAppointment);
                continue;
            }
            ServiceAppointment updateRow = new ServiceAppointment(Id = appointment.Id);
            Boolean needsUpdate = false;
            if (appointment.Status == null) {
                updateRow.Status = APPOINTMENT_STATUS;
                needsUpdate = true;
            }
            if (Schema.sObjectType.ServiceAppointment.fields.getMap().containsKey('LOVING_Work_Order__c')) {
                updateRow.put('LOVING_Work_Order__c', customParentId);
                needsUpdate = true;
            }
            if (needsUpdate) {
                appointmentsToUpdate.add(updateRow);
            }
        }
        if (!appointmentsToInsert.isEmpty()) {
            insert appointmentsToInsert;
        }
        if (!appointmentsToUpdate.isEmpty()) {
            update appointmentsToUpdate;
        }
    }

    private static Map<String, Id> loadRecordTypeIds(Set<String> developerNames) {
        Map<String, Id> result = new Map<String, Id>();
        for (RecordType row : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'WorkOrder'
              AND IsActive = true
              AND DeveloperName IN :developerNames
        ]) {
            result.put(row.DeveloperName, row.Id);
        }
        return result;
    }

    private static Id getStandardPricebookId() {
        if (Test.isRunningTest()) {
            return Test.getStandardPricebookId();
        }
        List<Pricebook2> rows = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Id;
    }

    private static PricebookEntry ensureGenericScopeEntry(Id targetPricebookId, Id standardPricebookId) {
        if (standardPricebookId == null) {
            throw new AuraHandledException('Standard Price Book is required before builder execution scope can be generated.');
        }
        if (targetPricebookId == null) {
            targetPricebookId = standardPricebookId;
        }

        List<Product2> products = [
            SELECT Id, ProductCode, IsActive
            FROM Product2
            WHERE ProductCode = :GENERIC_SCOPE_PRODUCT_CODE
            LIMIT 1
        ];
        Product2 product;
        if (products.isEmpty()) {
            product = new Product2(Name = 'LOVING Execution Scope', ProductCode = GENERIC_SCOPE_PRODUCT_CODE, IsActive = true);
            insert product;
        } else {
            product = products[0];
            if (!product.IsActive) {
                product.IsActive = true;
                update product;
            }
        }

        List<PricebookEntry> standardPbes = [
            SELECT Id, IsActive
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId
              AND Product2Id = :product.Id
            LIMIT 1
        ];
        if (standardPbes.isEmpty()) {
            insert new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = product.Id,
                UnitPrice = 0,
                IsActive = true
            );
        } else if (!standardPbes[0].IsActive) {
            standardPbes[0].IsActive = true;
            update standardPbes[0];
        }

        List<PricebookEntry> pbes = [
            SELECT Id, IsActive
            FROM PricebookEntry
            WHERE Pricebook2Id = :targetPricebookId
              AND Product2Id = :product.Id
            LIMIT 1
        ];
        if (!pbes.isEmpty()) {
            if (!pbes[0].IsActive) {
                pbes[0].IsActive = true;
                update pbes[0];
            }
            return pbes[0];
        }

        PricebookEntry created = new PricebookEntry(
            Pricebook2Id = targetPricebookId,
            Product2Id = product.Id,
            UnitPrice = 0,
            IsActive = true
        );
        insert created;
        return created;
    }

    private static Id resolveTargetPricebookId(
        Builder_PO__c builderPo,
        Purchase_Order__c purchaseOrder,
        Map<Id, Community_Package__c> communityPackageById,
        Id fallbackPricebookId
    ) {
        Id packageId = resolveCommunityPackageId(builderPo, purchaseOrder);
        if (packageId != null && communityPackageById.containsKey(packageId)) {
            Id pricingBookId = communityPackageById.get(packageId).Pricing_Book__c;
            if (pricingBookId != null) {
                return pricingBookId;
            }
        }
        return fallbackPricebookId;
    }

    private static Id resolveCommunityPackageId(Builder_PO__c builderPo, Purchase_Order__c purchaseOrder) {
        Id packageId = builderPo == null ? null : builderPo.Community_Package__c;
        if (packageId == null && purchaseOrder != null && purchaseOrder.Lot__r != null) {
            packageId = purchaseOrder.Lot__r.Effective_Community_Package__c;
        }
        if (packageId == null && purchaseOrder != null && purchaseOrder.Community__r != null) {
            Boolean isCornerLot = purchaseOrder.Lot__r != null && purchaseOrder.Lot__r.Corner_Lot__c;
            packageId = isCornerLot
                ? purchaseOrder.Community__r.Active_Corner_Package__c
                : purchaseOrder.Community__r.Active_Standard_Package__c;
        }
        return packageId;
    }

    private static Id resolveFieldManagerId(Takeoff__c takeoff, Purchase_Order__c purchaseOrder) {
        if (takeoff != null && takeoff.FM_Assignment__c != null) {
            return takeoff.FM_Assignment__c;
        }
        if (purchaseOrder != null && purchaseOrder.Community__r != null) {
            Id communityFm = (Id) purchaseOrder.Community__r.get('FM_Assignment__c');
            if (communityFm != null) {
                return communityFm;
            }
            return (Id) purchaseOrder.Community__r.get('Assigned_FM__c');
        }
        return null;
    }

    private static String buildBridgeSubject(Builder_PO__c builderPo, Purchase_Order__c purchaseOrder) {
        String poNumber = purchaseOrder == null ? null : purchaseOrder.PO_Number__c;
        if (String.isBlank(poNumber) && builderPo != null) {
            poNumber = builderPo.PO_Number__c;
        }
        return 'Builder Execution Bridge · ' + (String.isBlank(poNumber) ? 'Pending PO' : poNumber);
    }

    @TestVisible
    private static String buildLineDescription(Takeoff_Line__c line) {
        if (String.isNotBlank(line.Item_Description__c)) {
            return line.Item_Description__c;
        }
        if (String.isNotBlank((String) line.get('Item_Name__c'))) {
            return (String) line.get('Item_Name__c');
        }
        return 'Builder scope line';
    }

    @TestVisible
    private static Decimal resolveQuantity(Takeoff_Line__c line) {
        if (line.Verified_Quantity__c != null) {
            return line.Verified_Quantity__c;
        }
        if (line.Measured_Quantity__c != null) {
            return line.Measured_Quantity__c;
        }
        if (line.PO_Quantity__c != null) {
            return line.PO_Quantity__c;
        }
        return 1;
    }

    private static String lineSignature(String description, Decimal quantity, Decimal unitPrice) {
        return String.valueOf(description).trim().toLowerCase()
            + '|' + String.valueOf(quantity == null ? 0 : quantity.setScale(2))
            + '|' + String.valueOf(unitPrice == null ? 0 : unitPrice.setScale(2));
    }

    @TestVisible
    static String classifyScope(Takeoff_Line__c line) {
        String haystack = ((String) line.get('Item_Name__c') + ' ' + line.Item_Description__c).toLowerCase();
        if (containsAny(haystack, new List<String>{ 'aqua', 'watering bag', 'watering', 'moisture bag' })) {
            return 'Aqua';
        }
        if (containsAny(haystack, new List<String>{ 'irrigation', 'valve', 'zone', 'controller', 'backflow', 'drip', 'spray', 'rotor', 'head' })) {
            return 'Irrigation';
        }
        if (containsAny(haystack, new List<String>{ 'grading', 'grade', 'topsoil', 'seed', 'straw', 'erosion', 'rough grade', 'final grade' })) {
            return 'Grading';
        }
        return 'Install';
    }

    @TestVisible
    static Boolean isSodLine(Takeoff_Line__c line) {
        String haystack = ((String) line.get('Item_Name__c') + ' ' + line.Item_Description__c).toLowerCase();
        return containsAny(haystack, new List<String>{ 'sod', 'fescue', 'bermuda', 'zoysia', 'centipede', 'st augustine', 'st. augustine' });
    }

    private static Boolean containsAny(String haystack, List<String> needles) {
        if (String.isBlank(haystack)) {
            return false;
        }
        for (String needle : needles) {
            if (haystack.contains(needle)) {
                return true;
            }
        }
        return false;
    }

    private static String workOrderTypeForScope(String scopeName) {
        if (scopeName == 'Grading') {
            return 'Grading';
        }
        if (scopeName == 'Irrigation') {
            return 'Irrigation';
        }
        if (scopeName == 'Aqua') {
            return 'Aqua Install';
        }
        return 'Production Install';
    }

    private static Id recordTypeIdForScope(String scopeName, Map<String, Id> recordTypeIds) {
        if (scopeName == 'Grading') {
            return recordTypeIds.get('Plant_Sod_Grading');
        }
        if (scopeName == 'Irrigation') {
            return recordTypeIds.get('Inground_Irrigation');
        }
        if (scopeName == 'Aqua') {
            return recordTypeIds.get('Aqua_New_Install');
        }
        return recordTypeIds.get('Production_Install');
    }

    private static String scopeForWorkOrderType(String workOrderType) {
        if (workOrderType == 'Grading') {
            return 'Grading';
        }
        if (workOrderType == 'Irrigation') {
            return 'Irrigation';
        }
        if (workOrderType == 'Aqua Install') {
            return 'Aqua';
        }
        return 'Install';
    }
}