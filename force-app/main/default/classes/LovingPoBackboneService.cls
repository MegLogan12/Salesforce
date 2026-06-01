public with sharing class LovingPoBackboneService {

    public class BackboneResult {
        @AuraEnabled public Id purchaseOrderId;
        @AuraEnabled public Id builderPoId;
        @AuraEnabled public Id orderId;
        @AuraEnabled public Id takeoffId;
        @AuraEnabled public Id reviewTaskId;
        @AuraEnabled public Integer orderItemCount;
        @AuraEnabled public Integer takeoffLineCount;
        @AuraEnabled public Integer discrepancyLineCount;
        @AuraEnabled public Boolean usedHeaderFallback;
        @AuraEnabled public List<String> warnings;

        public BackboneResult() {
            warnings = new List<String>();
            usedHeaderFallback = false;
            orderItemCount = 0;
            takeoffLineCount = 0;
            discrepancyLineCount = 0;
        }
    }

    public class TakeoffApprovalRequest {
        @InvocableVariable(required=true)
        public Id takeoffId;
    }

    public class TakeoffApprovalResult {
        @InvocableVariable public Id takeoffId;
        @InvocableVariable public Integer createdWorkOrderLineItemCount;
        @InvocableVariable public String message;
    }

    private class LineContext {
        public PO_Line_Item__c poLine;
        public OrderItem orderItem;

        public LineContext(PO_Line_Item__c poLine, OrderItem orderItem) {
            this.poLine = poLine;
            this.orderItem = orderItem;
        }
    }

    @AuraEnabled
    public static BackboneResult ensureBackbone(Id purchaseOrderId) {
        if (purchaseOrderId == null) {
            throw new AuraHandledException('Purchase Order Id is required.');
        }

        Purchase_Order__c po = [
            SELECT Id, PO_Number__c, Builder_Account__c, Division_Account__c, Community__c, Lot__c,
                   Item__c, Quantity__c, Total_Amount__c, Status__c, Package_BMG_Status__c,
                   Requested_Install_Date__c, Estimated_Start_Date__c, Notes__c, Work_Order__c
            FROM Purchase_Order__c
            WHERE Id = :purchaseOrderId
            LIMIT 1
        ];

        Builder_PO__c builderPo = loadBuilderPo(po);
        return ensureBackboneInternal(po, builderPo);
    }

    @AuraEnabled
    public static BackboneResult ensureBackboneFromBuilderPo(Id builderPoId) {
        if (builderPoId == null) {
            throw new AuraHandledException('Builder PO Id is required.');
        }

        Builder_PO__c builderPo = [
            SELECT Id, PO_Number__c, Builder_Account__c, Division_Account__c, Community__c, Lot__c,
                   PO_Received_Date__c, Requested_Install_Date__c, Estimated_Start_Date__c, Notes__c,
                   Builder_Work_Order_Number__c
            FROM Builder_PO__c
            WHERE Id = :builderPoId
            LIMIT 1
        ];

        Purchase_Order__c po = loadMatchedPurchaseOrder(builderPo);
        return ensureBackboneInternal(po, builderPo);
    }

    @InvocableMethod(label='Generate Work Order Line Items from Approved Takeoff')
    public static List<TakeoffApprovalResult> generateWorkOrderLineItemsFromApprovedTakeoff(List<TakeoffApprovalRequest> requests) {
        List<TakeoffApprovalResult> results = new List<TakeoffApprovalResult>();
        if (requests == null) {
            return results;
        }
        for (TakeoffApprovalRequest request : requests) {
            TakeoffApprovalResult result = new TakeoffApprovalResult();
            result.takeoffId = request == null ? null : request.takeoffId;
            try {
                result.createdWorkOrderLineItemCount = materializeApprovedWorkScope(request.takeoffId);
                result.message = 'OK';
            } catch (Exception e) {
                result.createdWorkOrderLineItemCount = 0;
                result.message = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    @AuraEnabled
    public static Id approveTakeoffForPilot(Id takeoffId, String notes) {
        if (takeoffId == null) {
            throw new AuraHandledException('Takeoff Id is required.');
        }
        update new Takeoff__c(
            Id = takeoffId,
            Status__c = 'Approved',
            Notes__c = notes
        );
        return takeoffId;
    }

    @AuraEnabled
    public static Id approveFirstTakeoffLineForPilot(Id takeoffId, String notes) {
        if (takeoffId == null) {
            throw new AuraHandledException('Takeoff Id is required.');
        }
        List<Takeoff_Line__c> rows = [
            SELECT Id, Notes__c, Review_Status__c
            FROM Takeoff_Line__c
            WHERE Takeoff__c = :takeoffId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('No Takeoff Lines were found for the requested Takeoff.');
        }
        Takeoff_Line__c line = rows[0];
        line.Review_Status__c = 'Approved';
        line.Notes__c = notes;
        update line;
        return line.Id;
    }

    public static Integer materializeApprovedWorkScope(Id takeoffId) {
        if (takeoffId == null) {
            throw new AuraHandledException('Takeoff Id is required.');
        }

        Takeoff__c takeoff = [
            SELECT Id, Status__c, Purchase_Order__c, Source_Order__c
            FROM Takeoff__c
            WHERE Id = :takeoffId
            LIMIT 1
        ];
        if (takeoff.Status__c != 'Approved') {
            throw new AuraHandledException('Takeoff must be Approved before executable Work Order Line Items can be generated.');
        }
        if (takeoff.Purchase_Order__c == null) {
            throw new AuraHandledException('Takeoff is missing the source Purchase Order link.');
        }

        Purchase_Order__c po = [
            SELECT Id, Work_Order__c, PO_Number__c, Quantity__c, Total_Amount__c
            FROM Purchase_Order__c
            WHERE Id = :takeoff.Purchase_Order__c
            LIMIT 1
        ];
        if (po.Work_Order__c == null) {
            throw new AuraHandledException('Purchase Order must be linked to a standard WorkOrder before executable scope can be generated.');
        }

        List<Takeoff_Line__c> takeoffLines = [
            SELECT Id, Source_Order_Item__c, Item_Description__c, Unit_Price__c,
                   PO_Quantity__c, Verified_Quantity__c, Measured_Quantity__c, Review_Status__c
            FROM Takeoff_Line__c
            WHERE Takeoff__c = :takeoffId
              AND Source_Order_Item__c != null
              AND Review_Status__c = 'Approved'
            ORDER BY Sort_Order__c ASC, CreatedDate ASC
        ];

        Set<Id> orderItemIds = new Set<Id>();
        for (Takeoff_Line__c line : takeoffLines) {
            orderItemIds.add(line.Source_Order_Item__c);
        }

        if (takeoffLines.isEmpty() && takeoff.Source_Order__c != null) {
            for (OrderItem sourceItem : [
                SELECT Id, OrderId, Product2Id, PricebookEntryId, Quantity, UnitPrice, Description
                FROM OrderItem
                WHERE OrderId = :takeoff.Source_Order__c
                ORDER BY CreatedDate ASC
            ]) {
                orderItemIds.add(sourceItem.Id);
            }
        }
        if (orderItemIds.isEmpty()) {
            return ensureGenericFallbackWorkScope(po);
        }

        Map<Id, OrderItem> orderItemsById = new Map<Id, OrderItem>([
            SELECT Id, OrderId, Product2Id, PricebookEntryId, Quantity, UnitPrice, Description
            FROM OrderItem
            WHERE Id IN :orderItemIds
        ]);

        Set<Id> pricebookEntryIds = new Set<Id>();
        for (OrderItem sourceItem : orderItemsById.values()) {
            if (sourceItem.PricebookEntryId != null) {
                pricebookEntryIds.add(sourceItem.PricebookEntryId);
            }
        }
        Map<Id, PricebookEntry> pbeById = pricebookEntryIds.isEmpty()
            ? new Map<Id, PricebookEntry>()
            : new Map<Id, PricebookEntry>([
                SELECT Id, Pricebook2Id
                FROM PricebookEntry
                WHERE Id IN :pricebookEntryIds
            ]);

        WorkOrder parentWorkOrder = [
            SELECT Id, Pricebook2Id
            FROM WorkOrder
            WHERE Id = :po.Work_Order__c
            LIMIT 1
        ];
        Id requiredPricebookId;
        for (PricebookEntry pbe : pbeById.values()) {
            requiredPricebookId = pbe.Pricebook2Id;
            break;
        }
        if (requiredPricebookId != null && parentWorkOrder.Pricebook2Id != requiredPricebookId) {
            parentWorkOrder.Pricebook2Id = requiredPricebookId;
            update parentWorkOrder;
        }

        Map<Id, WorkOrderLineItem> existingByTakeoffLineId = new Map<Id, WorkOrderLineItem>();
        Set<String> existingScopeKeys = new Set<String>();
        for (WorkOrderLineItem row : [
            SELECT Id, Source_Takeoff_Line__c, OrderId, PricebookEntryId, Description, Quantity, UnitPrice
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :po.Work_Order__c
        ]) {
            if (row.Source_Takeoff_Line__c != null) {
                existingByTakeoffLineId.put(row.Source_Takeoff_Line__c, row);
            }
            existingScopeKeys.add(scopeKey(row.OrderId, row.PricebookEntryId, row.Description, row.Quantity, row.UnitPrice));
        }

        List<WorkOrderLineItem> toInsert = new List<WorkOrderLineItem>();
        for (Takeoff_Line__c line : takeoffLines) {
            if (existingByTakeoffLineId.containsKey(line.Id)) {
                continue;
            }

            OrderItem sourceItem = orderItemsById.get(line.Source_Order_Item__c);
            if (sourceItem == null) {
                continue;
            }

            Decimal finalQty = line.Verified_Quantity__c;
            if (finalQty == null) {
                finalQty = line.Measured_Quantity__c;
            }
            if (finalQty == null) {
                finalQty = line.PO_Quantity__c;
            }
            if (finalQty == null) {
                finalQty = sourceItem.Quantity;
            }

            WorkOrderLineItem row = new WorkOrderLineItem();
            row.WorkOrderId = po.Work_Order__c;
            row.Source_Takeoff_Line__c = line.Id;
            row.OrderId = sourceItem.OrderId;
            row.PricebookEntryId = sourceItem.PricebookEntryId;
            row.Description = String.isBlank(line.Item_Description__c) ? sourceItem.Description : line.Item_Description__c;
            row.Quantity = finalQty;
            row.UnitPrice = line.Unit_Price__c != null ? line.Unit_Price__c : sourceItem.UnitPrice;
            row.Status = 'New';
            String scopeSignature = scopeKey(row.OrderId, row.PricebookEntryId, row.Description, row.Quantity, row.UnitPrice);
            if (existingScopeKeys.contains(scopeSignature)) {
                continue;
            }
            existingScopeKeys.add(scopeSignature);
            toInsert.add(row);
        }

        if (toInsert.isEmpty() && !orderItemsById.isEmpty()) {
            for (OrderItem sourceItem : orderItemsById.values()) {
                if (sourceItem.PricebookEntryId == null) {
                    continue;
                }
                WorkOrderLineItem fallbackRow = new WorkOrderLineItem();
                fallbackRow.WorkOrderId = po.Work_Order__c;
                fallbackRow.OrderId = sourceItem.OrderId;
                fallbackRow.PricebookEntryId = sourceItem.PricebookEntryId;
                fallbackRow.Description = String.isBlank(sourceItem.Description)
                    ? 'PO scope item'
                    : sourceItem.Description;
                fallbackRow.Quantity = sourceItem.Quantity;
                fallbackRow.UnitPrice = sourceItem.UnitPrice;
                fallbackRow.Status = 'New';
                String scopeSignature = scopeKey(
                    fallbackRow.OrderId,
                    fallbackRow.PricebookEntryId,
                    fallbackRow.Description,
                    fallbackRow.Quantity,
                    fallbackRow.UnitPrice
                );
                if (existingScopeKeys.contains(scopeSignature)) {
                    continue;
                }
                existingScopeKeys.add(scopeSignature);
                toInsert.add(fallbackRow);
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
        return toInsert.size();
    }

    private static Integer ensureGenericFallbackWorkScope(Purchase_Order__c po) {
        if (po == null || po.Work_Order__c == null) {
            return 0;
        }

        Decimal quantity = (po.Quantity__c == null || po.Quantity__c <= 0) ? 1 : po.Quantity__c;
        Decimal unitPrice;
        if (po.Total_Amount__c != null && quantity > 0) {
            unitPrice = po.Total_Amount__c / quantity;
        }
        String description = 'Fallback scope from ' + (String.isBlank(po.PO_Number__c) ? 'source PO' : po.PO_Number__c);
        Id standardPricebookId = getStandardPricebookId();
        if (standardPricebookId == null) {
            return 0;
        }
        PricebookEntry fallbackPbe = ensureFallbackScopePricebookEntry(standardPricebookId, unitPrice == null ? 0 : unitPrice);
        if (fallbackPbe == null) {
            return 0;
        }

        for (WorkOrderLineItem existing : [
            SELECT Id, Description, Quantity, PricebookEntryId
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :po.Work_Order__c
        ]) {
            if (existing.Description == description
                && existing.Quantity == quantity
                && existing.PricebookEntryId == fallbackPbe.Id) {
                return 0;
            }
        }

        WorkOrder parentWorkOrder = [
            SELECT Id, Pricebook2Id
            FROM WorkOrder
            WHERE Id = :po.Work_Order__c
            LIMIT 1
        ];
        if (parentWorkOrder.Pricebook2Id != standardPricebookId) {
            parentWorkOrder.Pricebook2Id = standardPricebookId;
            update parentWorkOrder;
        }

        insert new WorkOrderLineItem(
            WorkOrderId = po.Work_Order__c,
            PricebookEntryId = fallbackPbe.Id,
            Description = description,
            Quantity = quantity,
            UnitPrice = unitPrice,
            Status = 'New'
        );
        return 1;
    }

    private static PricebookEntry ensureFallbackScopePricebookEntry(Id pricebookId, Decimal unitPrice) {
        List<PricebookEntry> existing = [
            SELECT Id, Pricebook2Id, Product2Id, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :pricebookId
              AND Product2.ProductCode = 'LOVING_FALLBACK_SCOPE'
              AND IsActive = true
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }

        Product2 product;
        List<Product2> products = [
            SELECT Id, Name, ProductCode, IsActive
            FROM Product2
            WHERE ProductCode = 'LOVING_FALLBACK_SCOPE'
            LIMIT 1
        ];
        if (products.isEmpty()) {
            product = new Product2(
                Name = 'LOVING Fallback Scope',
                ProductCode = 'LOVING_FALLBACK_SCOPE',
                IsActive = true
            );
            insert product;
        } else {
            product = products[0];
            if (product.IsActive != true) {
                product.IsActive = true;
                update product;
            }
        }

        PricebookEntry created = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = product.Id,
            UnitPrice = unitPrice,
            IsActive = true
        );
        insert created;
        return created;
    }

    private static BackboneResult ensureBackboneInternal(Purchase_Order__c po, Builder_PO__c builderPo) {
        BackboneResult result = new BackboneResult();
        result.purchaseOrderId = po == null ? null : po.Id;
        result.builderPoId = builderPo.Id;

        Id pricebookId = getStandardPricebookId();
        Order targetOrder = loadOrCreateOrder(po, builderPo, pricebookId);
        result.orderId = targetOrder.Id;

        List<PO_Line_Item__c> poLines = po == null ? new List<PO_Line_Item__c>() : loadOrSeedPoLines(po, result);
        if (po == null) {
            result.warnings.add('No staged Purchase_Order__c record matched this Builder PO, so no OrderItem or Takeoff Line records were created.');
        }

        List<LineContext> lineContexts = po == null
            ? new List<LineContext>()
            : loadOrCreateOrderItems(targetOrder, po, poLines, pricebookId, result);
        result.orderItemCount = lineContexts.size();

        Takeoff__c takeoff = loadOrCreateTakeoff(po, builderPo, targetOrder.Id);
        result.takeoffId = takeoff.Id;

        result.takeoffLineCount = loadOrCreateTakeoffLines(takeoff.Id, lineContexts);
        result.discrepancyLineCount = countDiscrepancyLines(takeoff.Id);
        if (result.discrepancyLineCount > 0) {
            result.reviewTaskId = ensureDiscrepancyReviewTask(builderPo, targetOrder, takeoff.Id, result.discrepancyLineCount);
            if (result.reviewTaskId != null) {
                result.warnings.add('Discrepancy review task created for takeoff review.');
            }
        }
        return result;
    }

    private static Builder_PO__c loadBuilderPo(Purchase_Order__c po) {
        if (String.isBlank(po.PO_Number__c)) {
            throw new AuraHandledException('PO Number is required before the backbone can be created.');
        }

        List<Builder_PO__c> builderPos = [
            SELECT Id, PO_Number__c, Builder_Account__c, Division_Account__c, Community__c, Lot__c,
                   PO_Received_Date__c, Requested_Install_Date__c, Estimated_Start_Date__c, Notes__c,
                   Builder_Work_Order_Number__c
            FROM Builder_PO__c
            WHERE PO_Number__c = :po.PO_Number__c
            ORDER BY CreatedDate DESC
            LIMIT 2
        ];
        if (builderPos.isEmpty()) {
            throw new AuraHandledException('No source Purchase Order intake record was found for PO Number ' + po.PO_Number__c + '.');
        }
        if (builderPos.size() > 1) {
            throw new AuraHandledException('Multiple source Purchase Order intake records match PO Number ' + po.PO_Number__c + '. Resolve the duplicate before continuing.');
        }
        return builderPos[0];
    }

    private static Purchase_Order__c loadMatchedPurchaseOrder(Builder_PO__c builderPo) {
        if (String.isBlank(builderPo.PO_Number__c)) {
            return null;
        }

        List<Purchase_Order__c> rows = [
            SELECT Id, PO_Number__c, Builder_Account__c, Division_Account__c, Community__c, Lot__c,
                   Item__c, Quantity__c, Total_Amount__c, Status__c, Package_BMG_Status__c,
                   Requested_Install_Date__c, Estimated_Start_Date__c, Notes__c, Work_Order__c
            FROM Purchase_Order__c
            WHERE PO_Number__c = :builderPo.PO_Number__c
            ORDER BY CreatedDate DESC
            LIMIT 2
        ];
        if (rows.isEmpty()) {
            return null;
        }
        if (rows.size() > 1) {
            throw new AuraHandledException('Multiple staged Purchase_Order__c records match Builder PO ' + builderPo.PO_Number__c + '. Resolve the duplicate before piloting.');
        }
        return rows[0];
    }

    private static Order loadOrCreateOrder(Purchase_Order__c po, Builder_PO__c builderPo, Id pricebookId) {
        Id accountId = builderPo.Division_Account__c != null
            ? builderPo.Division_Account__c
            : (po == null ? null : po.Division_Account__c);
        if (accountId == null) {
            throw new AuraHandledException('Division Account is required before a standard Order can be created.');
        }

        List<Order> existing = [
            SELECT Id, AccountId, Pricebook2Id, OrderReferenceNumber, Builder_PO__c, Community__c, Lot__c
            FROM Order
            WHERE AccountId = :accountId
              AND OrderReferenceNumber = :builderPo.PO_Number__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            Order orderToUpdate = existing[0];
            Boolean needsUpdate = false;
            if (orderToUpdate.Pricebook2Id == null && pricebookId != null) {
                orderToUpdate.Pricebook2Id = pricebookId;
                needsUpdate = true;
            }
            if (orderToUpdate.Builder_PO__c != builderPo.Id) {
                orderToUpdate.Builder_PO__c = builderPo.Id;
                needsUpdate = true;
            }
            if (orderToUpdate.Community__c == null && builderPo.Community__c != null) {
                orderToUpdate.Community__c = builderPo.Community__c;
                needsUpdate = true;
            }
            if (orderToUpdate.Lot__c == null && builderPo.Lot__c != null) {
                orderToUpdate.Lot__c = builderPo.Lot__c;
                needsUpdate = true;
            }
            if (needsUpdate) {
                update orderToUpdate;
            }
            return orderToUpdate;
        }

        Order created = new Order();
        created.AccountId = accountId;
        created.EffectiveDate = builderPo.PO_Received_Date__c != null ? builderPo.PO_Received_Date__c : Date.today();
        created.Status = 'Draft';
        created.Description = 'Source PO ' + builderPo.PO_Number__c;
        created.OrderReferenceNumber = builderPo.PO_Number__c;
        created.Builder_PO__c = builderPo.Id;
        created.Community__c = builderPo.Community__c;
        created.Lot__c = builderPo.Lot__c;
        if (pricebookId != null) {
            created.Pricebook2Id = pricebookId;
        }
        insert created;
        return created;
    }

    private static List<PO_Line_Item__c> loadOrSeedPoLines(Purchase_Order__c po, BackboneResult result) {
        List<PO_Line_Item__c> lines = [
            SELECT Id, Item__c, Line_Description__c, Quantity__c, Unit__c, Unit_Price__c,
                   Work_Type__c, Package_Match__c, Match_Notes__c, Source_Line_Number__c
            FROM PO_Line_Item__c
            WHERE Purchase_Order__c = :po.Id
            ORDER BY Source_Line_Number__c ASC NULLS LAST, CreatedDate ASC
        ];
        if (!lines.isEmpty()) {
            return lines;
        }

        if (po.Item__c == null || po.Quantity__c == null) {
            result.warnings.add('No PO line records or legacy Item/Quantity header values were available, so no OrderItem or Takeoff Line records were created.');
            return lines;
        }

        Product2 product = [
            SELECT Id, Name
            FROM Product2
            WHERE Id = :po.Item__c
            LIMIT 1
        ];

        PO_Line_Item__c fallbackLine = new PO_Line_Item__c(
            Purchase_Order__c = po.Id,
            Item__c = po.Item__c,
            Line_Description__c = product.Name,
            Quantity__c = po.Quantity__c,
            Unit_Price__c = (po.Total_Amount__c != null && po.Quantity__c != 0)
                ? (po.Total_Amount__c / po.Quantity__c)
                : null,
            Work_Type__c = 'Other',
            Source_Line_Number__c = 1,
            Package_Match__c = 'Pending'
        );
        insert fallbackLine;

        result.usedHeaderFallback = true;
        lines.add(fallbackLine);
        return lines;
    }

    private static List<LineContext> loadOrCreateOrderItems(Order targetOrder, Purchase_Order__c po, List<PO_Line_Item__c> poLines, Id pricebookId, BackboneResult result) {
        Map<String, OrderItem> existingByKey = new Map<String, OrderItem>();
        for (OrderItem item : [
            SELECT Id, OrderId, Product2Id, Description, Quantity, UnitPrice, PricebookEntryId
            FROM OrderItem
            WHERE OrderId = :targetOrder.Id
        ]) {
            existingByKey.put(lineKey(item.Product2Id, item.Description, item.Quantity, item.UnitPrice), item);
        }

        Set<Id> productIds = new Set<Id>();
        for (PO_Line_Item__c line : poLines) {
            if (line.Item__c != null) {
                productIds.add(line.Item__c);
            }
        }
        Map<Id, PricebookEntry> pbeByProductId = loadPricebookEntries(pricebookId, productIds);

        List<OrderItem> toInsert = new List<OrderItem>();
        List<LineContext> contexts = new List<LineContext>();

        for (PO_Line_Item__c line : poLines) {
            if (line.Item__c == null) {
                result.warnings.add('PO line ' + String.valueOf(line.Source_Line_Number__c) + ' is missing Product2 mapping, so no standard OrderItem was created.');
                continue;
            }
            if (line.Quantity__c == null) {
                result.warnings.add('PO line ' + String.valueOf(line.Source_Line_Number__c) + ' is missing quantity, so no standard OrderItem was created.');
                continue;
            }

            PricebookEntry pbe = pbeByProductId.get(line.Item__c);
            if (pbe == null) {
                result.warnings.add('No active PricebookEntry was found for Product ' + line.Item__c + ', so the line could not be moved into a standard OrderItem.');
                continue;
            }

            String description = line.Line_Description__c;
            Decimal unitPrice = line.Unit_Price__c != null ? line.Unit_Price__c : pbe.UnitPrice;
            String key = lineKey(line.Item__c, description, line.Quantity__c, unitPrice);
            OrderItem existing = existingByKey.get(key);
            if (existing != null) {
                contexts.add(new LineContext(line, existing));
                continue;
            }

            OrderItem created = new OrderItem();
            created.OrderId = targetOrder.Id;
            created.Product2Id = line.Item__c;
            created.PricebookEntryId = pbe.Id;
            created.Quantity = line.Quantity__c;
            created.UnitPrice = unitPrice;
            created.Description = description;
            created.Raw_PO_Line_Text__c = description;
            created.Source_UOM__c = line.Unit__c;
            toInsert.add(created);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
            for (OrderItem item : toInsert) {
                existingByKey.put(lineKey(item.Product2Id, item.Description, item.Quantity, item.UnitPrice), item);
            }
        }

        for (PO_Line_Item__c line : poLines) {
            if (line.Item__c == null || line.Quantity__c == null) {
                continue;
            }
            Decimal unitPrice = line.Unit_Price__c;
            if (unitPrice == null && pbeByProductId.containsKey(line.Item__c)) {
                unitPrice = pbeByProductId.get(line.Item__c).UnitPrice;
            }
            String key = lineKey(line.Item__c, line.Line_Description__c, line.Quantity__c, unitPrice);
            OrderItem item = existingByKey.get(key);
            if (item != null) {
                contexts.add(new LineContext(line, item));
            }
        }
        return contexts;
    }

    private static Takeoff__c loadOrCreateTakeoff(Purchase_Order__c po, Builder_PO__c builderPo, Id orderId) {
        List<Takeoff__c> existing = [
            SELECT Id, Builder_PO__c, Purchase_Order__c, Source_Order__c, Community__c, Lot__c, Status__c
            FROM Takeoff__c
            WHERE Builder_PO__c = :builderPo.Id
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            Takeoff__c takeoff = existing[0];
            Boolean needsUpdate = false;
            if (po != null && takeoff.Purchase_Order__c != po.Id) {
                takeoff.Purchase_Order__c = po.Id;
                needsUpdate = true;
            }
            if (takeoff.Source_Order__c != orderId) {
                takeoff.Source_Order__c = orderId;
                needsUpdate = true;
            }
            if (takeoff.Community__c == null && builderPo.Community__c != null) {
                takeoff.Community__c = builderPo.Community__c;
                needsUpdate = true;
            }
            if (takeoff.Lot__c == null && builderPo.Lot__c != null) {
                takeoff.Lot__c = builderPo.Lot__c;
                needsUpdate = true;
            }
            if (needsUpdate) {
                update takeoff;
            }
            return takeoff;
        }

        Takeoff__c created = new Takeoff__c(
            Builder_PO__c = builderPo.Id,
            Purchase_Order__c = po == null ? null : po.Id,
            Source_Order__c = orderId,
            Community__c = builderPo.Community__c,
            Lot__c = builderPo.Lot__c,
            Status__c = 'Draft'
        );
        insert created;
        return created;
    }

    private static Integer loadOrCreateTakeoffLines(Id takeoffId, List<LineContext> lineContexts) {
        if (lineContexts.isEmpty()) {
            return 0;
        }

        Set<Id> orderItemIds = new Set<Id>();
        for (LineContext context : lineContexts) {
            orderItemIds.add(context.orderItem.Id);
        }

        Map<Id, Takeoff_Line__c> existingByOrderItemId = new Map<Id, Takeoff_Line__c>();
        for (Takeoff_Line__c line : [
            SELECT Id, Source_Order_Item__c
            FROM Takeoff_Line__c
            WHERE Takeoff__c = :takeoffId
              AND Source_Order_Item__c IN :orderItemIds
        ]) {
            existingByOrderItemId.put(line.Source_Order_Item__c, line);
        }

        Set<Id> productIds = new Set<Id>();
        for (LineContext context : lineContexts) {
            if (context.orderItem.Product2Id != null) {
                productIds.add(context.orderItem.Product2Id);
            }
        }
        Map<Id, Product2> productsById = productIds.isEmpty()
            ? new Map<Id, Product2>()
            : new Map<Id, Product2>([
                SELECT Id, Name, ProductCode
                FROM Product2
                WHERE Id IN :productIds
            ]);

        List<Takeoff_Line__c> toInsert = new List<Takeoff_Line__c>();
        for (LineContext context : lineContexts) {
            if (existingByOrderItemId.containsKey(context.orderItem.Id)) {
                continue;
            }

            Product2 product = productsById.get(context.orderItem.Product2Id);
            Takeoff_Line__c line = new Takeoff_Line__c();
            line.Takeoff__c = takeoffId;
            line.Source_Order_Item__c = context.orderItem.Id;
            line.Item_Name__c = product != null ? product.Name : context.poLine.Line_Description__c;
            line.Item_Description__c = String.isBlank(context.poLine.Line_Description__c)
                ? context.orderItem.Description
                : context.poLine.Line_Description__c;
            line.Unit__c = mapUnitToTakeoff(context.poLine.Unit__c);
            line.PO_Quantity__c = context.poLine.Quantity__c;
            line.PO_Qty__c = context.poLine.Quantity__c;
            line.Verified_Quantity__c = context.poLine.Quantity__c;
            line.Verified_Qty__c = context.poLine.Quantity__c;
            line.Unit_Price__c = context.poLine.Unit_Price__c != null ? context.poLine.Unit_Price__c : context.orderItem.UnitPrice;
            line.Material_Code__c = product != null ? product.ProductCode : null;
            line.Sort_Order__c = context.poLine.Source_Line_Number__c;
            line.Determination__c = mapPackageMatchToDetermination(context.poLine.Package_Match__c);
            line.Notes__c = context.poLine.Match_Notes__c;
            line.Review_Status__c = mapPackageMatchToReviewStatus(context.poLine.Package_Match__c);
            toInsert.add(line);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
        return existingByOrderItemId.size() + toInsert.size();
    }

    private static Integer countDiscrepancyLines(Id takeoffId) {
        return [
            SELECT COUNT()
            FROM Takeoff_Line__c
            WHERE Takeoff__c = :takeoffId
              AND Review_Status__c = 'Discrepancy'
        ];
    }

    private static Id ensureDiscrepancyReviewTask(Builder_PO__c builderPo, Order orderRow, Id takeoffId, Integer discrepancyCount) {
        String subject = 'UAT/Review - Takeoff discrepancy - ' + builderPo.PO_Number__c;
        List<Task> existing = [
            SELECT Id
            FROM Task
            WHERE Subject = :subject
              AND Status != 'Completed'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Id ownerId = resolveDiscrepancyOwnerId();
        if (ownerId == null) {
            return null;
        }

        Task reviewTask = new Task(
            OwnerId = ownerId,
            Subject = subject,
            Status = 'Not Started',
            Priority = 'High',
            WhatId = orderRow.Id,
            Description =
                'Takeoff discrepancy review is required before field scope can be released.' + '\n'
                + 'Builder PO: ' + builderPo.Id + '\n'
                + 'Order: ' + orderRow.Id + '\n'
                + 'Takeoff: ' + takeoffId + '\n'
                + 'Discrepancy Lines: ' + discrepancyCount + '\n'
                + 'Original PO values remain preserved on the source records.'
        );
        insert reviewTask;
        return reviewTask.Id;
    }

    private static Id resolveDiscrepancyOwnerId() {
        List<User> ericaUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = true
              AND FirstName = 'Erica'
            ORDER BY LastName ASC, CreatedDate ASC
            LIMIT 2
        ];
        if (ericaUsers.size() == 1) {
            return ericaUsers[0].Id;
        }

        List<Group> takeoffQueues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
              AND DeveloperName = 'Takeoff_Queue'
            LIMIT 1
        ];
        return takeoffQueues.isEmpty() ? null : takeoffQueues[0].Id;
    }

    private static Map<Id, PricebookEntry> loadPricebookEntries(Id pricebookId, Set<Id> productIds) {
        Map<Id, PricebookEntry> pbeByProductId = new Map<Id, PricebookEntry>();
        if (productIds.isEmpty()) {
            return pbeByProductId;
        }

        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, UnitPrice, Pricebook2Id
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
              AND IsActive = true
              AND Pricebook2Id = :pricebookId
        ];
        if (entries.isEmpty()) {
            entries = [
                SELECT Id, Product2Id, UnitPrice, Pricebook2Id
                FROM PricebookEntry
                WHERE Product2Id IN :productIds
                  AND IsActive = true
                  AND Pricebook2.IsStandard = true
            ];
        }
        for (PricebookEntry entry : entries) {
            if (!pbeByProductId.containsKey(entry.Product2Id)) {
                pbeByProductId.put(entry.Product2Id, entry);
            }
        }
        return pbeByProductId;
    }

    private static Id getStandardPricebookId() {
        if (Test.isRunningTest()) {
            return Test.getStandardPricebookId();
        }
        List<Pricebook2> books = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];
        return books.isEmpty() ? null : books[0].Id;
    }

    private static String lineKey(Id productId, String description, Decimal quantity, Decimal unitPrice) {
        return String.valueOf(productId) + '|' +
            String.valueOf(description) + '|' +
            String.valueOf(quantity) + '|' +
            String.valueOf(unitPrice);
    }

    private static String scopeKey(Id orderId, Id pricebookEntryId, String description, Decimal quantity, Decimal unitPrice) {
        return String.valueOf(orderId) + '|' +
            String.valueOf(pricebookEntryId) + '|' +
            String.valueOf(description) + '|' +
            String.valueOf(quantity) + '|' +
            String.valueOf(unitPrice);
    }

    private static String mapPackageMatchToDetermination(String packageMatch) {
        if (packageMatch == 'Matched' || String.isBlank(packageMatch)) {
            return 'Match';
        }
        if (packageMatch == 'Pending') {
            return 'Exception';
        }
        if (packageMatch == 'Extra') {
            return 'Substitution';
        }
        return 'Variance';
    }

    private static String mapUnitToTakeoff(String poLineUnit) {
        if (String.isBlank(poLineUnit)) {
            return null;
        }
        Map<String, String> mapping = new Map<String, String>{
            'Sqft' => 'Sq Ft',
            'Each' => 'Each'
        };
        return mapping.containsKey(poLineUnit) ? mapping.get(poLineUnit) : null;
    }

    private static String mapPackageMatchToReviewStatus(String packageMatch) {
        if (packageMatch == 'Matched' || String.isBlank(packageMatch)) {
            return 'Proposed';
        }
        return 'Discrepancy';
    }
}