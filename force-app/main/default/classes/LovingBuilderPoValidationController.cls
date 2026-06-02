public with sharing class LovingBuilderPoValidationController {
    private static final Decimal PRICE_TOLERANCE_PCT = 2;
    private static final Decimal QTY_TOLERANCE_PCT = 5;

    public class ActionResult {
        @AuraEnabled public Boolean passed;
        @AuraEnabled public String message;
        @AuraEnabled public String newStatus;
    }

    public class ValidationSnapshot {
        @AuraEnabled public String priceCheckResult;
        @AuraEnabled public String qtyCheckResult;
        @AuraEnabled public Boolean poValidated;
        @AuraEnabled public Decimal priceBookTotal;
        @AuraEnabled public List<LineSnapshot> poLines;
    }

    public class LineSnapshot {
        @AuraEnabled public Id id;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal packageQuantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal priceBookPrice;
        @AuraEnabled public String workType;
        @AuraEnabled public String lineResult;
    }

    @AuraEnabled(cacheable=true)
    public static ValidationSnapshot getBuilderPoValidationSnapshot(Id builderPoId) {
        ValidationSnapshot snapshot = new ValidationSnapshot();
        snapshot.poLines = new List<LineSnapshot>();
        if (builderPoId == null) {
            return snapshot;
        }

        List<Builder_PO__c> pos = [
            SELECT Price_Check_Result__c, Qty_Check_Result__c, PO_Validated__c, Price_Book_Total__c
            FROM Builder_PO__c
            WHERE Id = :builderPoId
            LIMIT 1
        ];
        if (pos.isEmpty()) {
            return snapshot;
        }
        Builder_PO__c po = pos[0];
        snapshot.priceCheckResult = po.Price_Check_Result__c;
        snapshot.qtyCheckResult = po.Qty_Check_Result__c;
        snapshot.poValidated = po.PO_Validated__c;
        snapshot.priceBookTotal = po.Price_Book_Total__c;

        for (Builder_PO_Line__c line : [
            SELECT Id, Line_Description__c, Quantity_Ordered__c, Package_Qty__c, Unit_Price__c,
                   Price_Book_Price__c, Service_Line__c, Line_Result__c
            FROM Builder_PO_Line__c
            WHERE Builder_PO__c = :builderPoId
            ORDER BY CreatedDate ASC
        ]) {
            LineSnapshot dto = new LineSnapshot();
            dto.id = line.Id;
            dto.description = line.Line_Description__c;
            dto.quantity = line.Quantity_Ordered__c;
            dto.packageQuantity = line.Package_Qty__c;
            dto.unitPrice = line.Unit_Price__c;
            dto.priceBookPrice = line.Price_Book_Price__c;
            dto.workType = line.Service_Line__c;
            dto.lineResult = line.Line_Result__c;
            snapshot.poLines.add(dto);
        }
        return snapshot;
    }

    @AuraEnabled
    public static ActionResult revalidateBuilderPo(Id poId, Id builderPoId) {
        ActionResult result = new ActionResult();
        try {
            Builder_PO__c builderPo = resolveBuilderPo(poId, builderPoId);
            if (builderPo == null) {
                result.passed = false;
                result.message = 'No Builder PO record was found for validation.';
                return result;
            }

            List<Builder_PO_Line__c> lines = [
                SELECT Quantity_Ordered__c, Package_Qty__c, Unit_Price__c, Price_Book_Price__c
                FROM Builder_PO_Line__c
                WHERE Builder_PO__c = :builderPo.Id
            ];
            if (lines.isEmpty()) {
                builderPo.Price_Check_Result__c = 'Not Run';
                builderPo.Qty_Check_Result__c = 'Not Run';
                builderPo.Status__c = 'Pending CS Review';
                builderPo.Mismatch_Type__c = null;
                update builderPo;
                result.passed = false;
                result.newStatus = 'Pending CS Review';
                result.message = 'Validation needs Builder PO Lines before CS approval.';
                return result;
            }

            Boolean pricePass = true;
            Boolean qtyPass = true;
            Decimal priceBookTotal = 0;
            for (Builder_PO_Line__c line : lines) {
                Decimal priceVariance = percentVariance(line.Unit_Price__c, line.Price_Book_Price__c);
                Decimal qtyVariance = percentVariance(line.Quantity_Ordered__c, line.Package_Qty__c);
                if (priceVariance.abs() > PRICE_TOLERANCE_PCT) {
                    pricePass = false;
                }
                if (qtyVariance.abs() > QTY_TOLERANCE_PCT) {
                    qtyPass = false;
                }
                priceBookTotal += (line.Package_Qty__c == null ? 0 : line.Package_Qty__c) *
                    (line.Price_Book_Price__c == null ? 0 : line.Price_Book_Price__c);
            }

            builderPo.Price_Book_Total__c = priceBookTotal;
            builderPo.Price_Check_Result__c = pricePass ? 'Pass' : 'Fail';
            builderPo.Qty_Check_Result__c = qtyPass ? 'Pass' : 'Fail';
            builderPo.Status__c = pricePass && qtyPass ? 'Verified' : 'Mismatch Review';
            builderPo.Mismatch_Type__c = pricePass ? (qtyPass ? null : 'Scope Variance') : 'Price Variance';
            builderPo.Mismatch_Notes__c = pricePass && qtyPass
                ? null
                : 'Auto-routed by Builder PO validation. Price tolerance: 2%. Quantity tolerance: 5%.';
            update builderPo;

            result.passed = pricePass && qtyPass;
            result.newStatus = builderPo.Status__c;
            result.message = result.passed
                ? 'Builder PO validation passed on price and quantity.'
                : 'Builder PO validation found a price or quantity mismatch.';
        } catch (Exception e) {
            result.passed = false;
            result.message = e.getMessage();
        }
        return result;
    }

    private static Builder_PO__c resolveBuilderPo(Id poId, Id builderPoId) {
        if (builderPoId != null) {
            List<Builder_PO__c> rows = [
                SELECT Id, PO_Number__c, Builder_Division__c, Community__c, Lot__c, Requested_Install_Date__c,
                       Status__c, Price_Book_Total__c, Price_Check_Result__c, Qty_Check_Result__c,
                       Mismatch_Type__c, Mismatch_Notes__c
                FROM Builder_PO__c
                WHERE Id = :builderPoId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        if (poId == null) {
            return null;
        }
        List<Purchase_Order__c> poRows = [
            SELECT PO_Number__c
            FROM Purchase_Order__c
            WHERE Id = :poId
            LIMIT 1
        ];
        if (poRows.isEmpty() || String.isBlank(poRows[0].PO_Number__c)) {
            return null;
        }
        List<Builder_PO__c> builderRows = [
            SELECT Id, PO_Number__c, Builder_Division__c, Community__c, Lot__c, Requested_Install_Date__c,
                   Status__c, Price_Book_Total__c, Price_Check_Result__c, Qty_Check_Result__c,
                   Mismatch_Type__c, Mismatch_Notes__c
            FROM Builder_PO__c
            WHERE PO_Number__c = :poRows[0].PO_Number__c
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return builderRows.isEmpty() ? null : builderRows[0];
    }

    private static Decimal percentVariance(Decimal actual, Decimal expected) {
        Decimal safeExpected = expected == null ? 0 : expected;
        if (safeExpected == 0) {
            return 0;
        }
        return (((actual == null ? 0 : actual) - safeExpected) / safeExpected) * 100;
    }
}