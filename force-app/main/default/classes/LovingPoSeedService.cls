public with sharing class LovingPoSeedService {
    private static final String PILOT_SCOPE_PRODUCT_CODE = 'LOVING_PI_SOD_SCOPE';
    private static final String PILOT_SCOPE_PRODUCT_NAME = 'LOVING Production Install Sod Scope';
    private static final String PROD_INSTALL_WORK_TYPE = 'Production Install';
    private static final String DEFAULT_UOM = 'Sqft';
    private static final String DEFAULT_LINE_DESCRIPTION = 'Production Install · Sod';

    public class CloneResult {
        @AuraEnabled public Id purchaseOrderId;
        @AuraEnabled public Id builderPoId;
        @AuraEnabled public Integer poLineCount;
        @AuraEnabled public Boolean usedHeaderFallback;
    }

    @AuraEnabled
    public static CloneResult clonePurchaseOrderForPilot(Id sourcePurchaseOrderId, String newPoNumber, Date estimatedStartDate) {
        if (sourcePurchaseOrderId == null) {
            throw new AuraHandledException('Source Purchase Order Id is required.');
        }
        if (String.isBlank(newPoNumber)) {
            throw new AuraHandledException('New PO number is required.');
        }

        Purchase_Order__c sourcePo = [
            SELECT Id, PO_Number__c, Builder_Account__c, Division_Account__c, Community__c, Community_Name__c, Lot__c,
                   Item__c, Quantity__c, Total_Amount__c, Status__c, Pipeline_Stage__c, Package_BMG_Status__c,
                   Requested_Install_Date__c, Estimated_Start_Date__c, Notes__c
            FROM Purchase_Order__c
            WHERE Id = :sourcePurchaseOrderId
            LIMIT 1
        ];
        Builder_PO__c sourceBuilderPo = [
            SELECT Id, PO_Number__c, Status__c, Builder_Account__c, Division_Account__c, Community__c, Lot__c,
                   PO_Received_Date__c, Requested_Install_Date__c, Estimated_Start_Date__c, Notes__c,
                   Builder_Work_Order_Number__c
            FROM Builder_PO__c
            WHERE PO_Number__c = :sourcePo.PO_Number__c
            LIMIT 1
        ];
        List<PO_Line_Item__c> sourceLines = [
            SELECT Id, Item__c, Line_Description__c, Quantity__c, Unit__c, Unit_Price__c,
                   Work_Type__c, Package_Match__c, Match_Notes__c, Source_Line_Number__c
            FROM PO_Line_Item__c
            WHERE Purchase_Order__c = :sourcePo.Id
            ORDER BY Source_Line_Number__c ASC NULLS LAST, CreatedDate ASC
        ];
        List<PO_Line_Item__c> templateLines = buildTemplateLines(sourcePo, sourceLines);

        Id headerItemId = sourcePo.Item__c;
        if (headerItemId == null && !templateLines.isEmpty()) {
            headerItemId = templateLines[0].Item__c;
        }

        Purchase_Order__c clonedPo = new Purchase_Order__c(
            Builder_Account__c = sourcePo.Builder_Account__c,
            Division_Account__c = sourcePo.Division_Account__c,
            PO_Number__c = newPoNumber,
            Community__c = sourcePo.Community__c,
            Community_Name__c = sourcePo.Community_Name__c,
            Lot__c = sourcePo.Lot__c,
            Item__c = headerItemId,
            Quantity__c = sourcePo.Quantity__c,
            Total_Amount__c = sourcePo.Total_Amount__c,
            Status__c = 'Pending CS Review',
            Pipeline_Stage__c = 'Validate',
            Package_BMG_Status__c = sourcePo.Package_BMG_Status__c,
            Requested_Install_Date__c = sourcePo.Requested_Install_Date__c,
            Estimated_Start_Date__c = estimatedStartDate == null ? sourcePo.Estimated_Start_Date__c : estimatedStartDate,
            Notes__c = sourcePo.Notes__c
        );
        insert clonedPo;

        Builder_PO__c clonedBuilderPo = new Builder_PO__c(
            PO_Number__c = newPoNumber,
            Status__c = sourceBuilderPo.Status__c,
            Builder_Account__c = sourceBuilderPo.Builder_Account__c,
            Division_Account__c = sourceBuilderPo.Division_Account__c,
            Community__c = sourceBuilderPo.Community__c,
            Lot__c = sourceBuilderPo.Lot__c,
            PO_Received_Date__c = sourceBuilderPo.PO_Received_Date__c,
            Requested_Install_Date__c = sourceBuilderPo.Requested_Install_Date__c,
            Estimated_Start_Date__c = estimatedStartDate == null ? sourceBuilderPo.Estimated_Start_Date__c : estimatedStartDate,
            Notes__c = sourceBuilderPo.Notes__c,
            Builder_Work_Order_Number__c = sourceBuilderPo.Builder_Work_Order_Number__c
        );
        insert clonedBuilderPo;

        List<PO_Line_Item__c> clonedLines = new List<PO_Line_Item__c>();
        for (PO_Line_Item__c sourceLine : templateLines) {
            clonedLines.add(new PO_Line_Item__c(
                Purchase_Order__c = clonedPo.Id,
                Item__c = sourceLine.Item__c,
                Line_Description__c = sourceLine.Line_Description__c,
                Quantity__c = sourceLine.Quantity__c,
                Unit__c = sourceLine.Unit__c,
                Unit_Price__c = sourceLine.Unit_Price__c,
                Work_Type__c = sourceLine.Work_Type__c,
                Package_Match__c = sourceLine.Package_Match__c,
                Match_Notes__c = sourceLine.Match_Notes__c,
                Source_Line_Number__c = sourceLine.Source_Line_Number__c
            ));
        }
        if (!clonedLines.isEmpty()) {
            insert clonedLines;
        }

        CloneResult result = new CloneResult();
        result.purchaseOrderId = clonedPo.Id;
        result.builderPoId = clonedBuilderPo.Id;
        result.poLineCount = clonedLines.size();
        result.usedHeaderFallback = clonedLines.isEmpty();
        return result;
    }

    private static List<PO_Line_Item__c> buildTemplateLines(Purchase_Order__c sourcePo, List<PO_Line_Item__c> sourceLines) {
        if (!sourceLines.isEmpty()) {
            return sourceLines;
        }

        List<PO_Line_Item__c> orderBackfilledLines = buildLinesFromStandardOrderItems(sourcePo);
        if (!orderBackfilledLines.isEmpty()) {
            return orderBackfilledLines;
        }

        List<PO_Line_Item__c> seededLines = buildLineFromAuthoritativePoHeader(sourcePo);
        return seededLines;
    }

    private static List<PO_Line_Item__c> buildLinesFromStandardOrderItems(Purchase_Order__c sourcePo) {
        if (sourcePo == null || String.isBlank(sourcePo.PO_Number__c)) {
            return new List<PO_Line_Item__c>();
        }

        List<Order> sourceOrders = [
            SELECT Id
            FROM Order
            WHERE OrderReferenceNumber = :sourcePo.PO_Number__c
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (sourceOrders.isEmpty()) {
            return new List<PO_Line_Item__c>();
        }

        List<PO_Line_Item__c> rows = new List<PO_Line_Item__c>();
        Integer index = 1;
        for (OrderItem sourceItem : [
            SELECT Product2Id, Quantity, UnitPrice, Description
            FROM OrderItem
            WHERE OrderId = :sourceOrders[0].Id
            ORDER BY CreatedDate ASC
        ]) {
            if (sourceItem.Product2Id == null || sourceItem.Quantity == null) {
                continue;
            }
            rows.add(new PO_Line_Item__c(
                Item__c = sourceItem.Product2Id,
                Line_Description__c = String.isBlank(sourceItem.Description) ? DEFAULT_LINE_DESCRIPTION : sourceItem.Description,
                Quantity__c = sourceItem.Quantity,
                Unit__c = DEFAULT_UOM,
                Unit_Price__c = sourceItem.UnitPrice,
                Work_Type__c = PROD_INSTALL_WORK_TYPE,
                Package_Match__c = 'Matched',
                Match_Notes__c = 'Seeded from existing OrderItem source for pilot clone.',
                Source_Line_Number__c = index
            ));
            index++;
        }
        return rows;
    }

    private static List<PO_Line_Item__c> buildLineFromAuthoritativePoHeader(Purchase_Order__c sourcePo) {
        if (sourcePo == null || sourcePo.Quantity__c == null || sourcePo.Quantity__c <= 0) {
            return new List<PO_Line_Item__c>();
        }

        Id productId = sourcePo.Item__c;
        if (productId == null) {
            productId = ensurePilotScopeProduct();
        }

        Decimal unitPrice;
        if (sourcePo.Total_Amount__c != null && sourcePo.Quantity__c != 0) {
            unitPrice = sourcePo.Total_Amount__c / sourcePo.Quantity__c;
        }

        return new List<PO_Line_Item__c>{
            new PO_Line_Item__c(
                Item__c = productId,
                Line_Description__c = DEFAULT_LINE_DESCRIPTION,
                Quantity__c = sourcePo.Quantity__c,
                Unit__c = DEFAULT_UOM,
                Unit_Price__c = unitPrice,
                Work_Type__c = PROD_INSTALL_WORK_TYPE,
                Package_Match__c = 'Matched',
                Match_Notes__c = 'Seeded from PO header because the source template had no staged PO lines.',
                Source_Line_Number__c = 1
            )
        };
    }

    private static Id ensurePilotScopeProduct() {
        Product2 product;
        List<Product2> products = [
            SELECT Id, IsActive
            FROM Product2
            WHERE ProductCode = :PILOT_SCOPE_PRODUCT_CODE
            LIMIT 1
        ];
        if (products.isEmpty()) {
            product = new Product2(
                Name = PILOT_SCOPE_PRODUCT_NAME,
                ProductCode = PILOT_SCOPE_PRODUCT_CODE,
                Family = PROD_INSTALL_WORK_TYPE,
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

        Id standardPricebookId = Test.isRunningTest() ? Test.getStandardPricebookId() : getStandardPricebookId();
        if (standardPricebookId != null) {
            List<PricebookEntry> entries = [
                SELECT Id
                FROM PricebookEntry
                WHERE Pricebook2Id = :standardPricebookId
                  AND Product2Id = :product.Id
                  AND IsActive = true
                LIMIT 1
            ];
            if (entries.isEmpty()) {
                insert new PricebookEntry(
                    Pricebook2Id = standardPricebookId,
                    Product2Id = product.Id,
                    UnitPrice = 0,
                    IsActive = true
                );
            }
        }
        return product.Id;
    }

    private static Id getStandardPricebookId() {
        List<Pricebook2> rows = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Id;
    }
}