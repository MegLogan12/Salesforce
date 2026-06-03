public with sharing class PoValidationController {

    public class PoView {
        @AuraEnabled public String  poId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  poNumber;
        @AuraEnabled public String  status;
        @AuraEnabled public Boolean poValidated;
        @AuraEnabled public Decimal poAmount;
        @AuraEnabled public Decimal priceBookTotal;
        @AuraEnabled public Decimal priceVariancePct;
        @AuraEnabled public Decimal nfiCount;
        @AuraEnabled public String  nfiReason;
        @AuraEnabled public String  builderDivisionName;
        @AuraEnabled public String  communityName;
        @AuraEnabled public List<CheckResult> checks;
    }

    public class CheckResult {
        @AuraEnabled public String  label;
        @AuraEnabled public String  expected;
        @AuraEnabled public String  actual;
        @AuraEnabled public Boolean passed;
        @AuraEnabled public Decimal variancePct;
    }

    @AuraEnabled(cacheable=true)
    public static PoView getPoRecord(Id recordId) {
        if (!Schema.sObjectType.Builder_PO__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Builder PO');
        }

        Builder_PO__c po = [
            SELECT Id, Name, PO_Number__c, Status__c, PO_Validated__c,
                   PO_Amount__c, Price_Book_Total__c, Price_Check_Result__c,
                   Qty_Check_Result__c, Price_Variance_Pct__c,
                   NFI_Count__c, NFI_Reason__c,
                   Builder_Division__c, Builder_Division__r.Name,
                   Community__c, Community__r.Name
            FROM Builder_PO__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        return buildView(po);
    }

    @TestVisible
    private static PoView buildView(Builder_PO__c po) {
        PoView v = new PoView();
        v.poId              = po.Id;
        v.name              = po.Name;
        v.poNumber          = po.PO_Number__c;
        v.status            = po.Status__c;
        v.poValidated       = po.PO_Validated__c == true;
        v.poAmount          = po.PO_Amount__c        != null ? po.PO_Amount__c        : 0;
        v.priceBookTotal    = po.Price_Book_Total__c != null ? po.Price_Book_Total__c : 0;
        v.priceVariancePct  = po.Price_Variance_Pct__c != null ? po.Price_Variance_Pct__c : 0;
        v.nfiCount          = po.NFI_Count__c   != null ? po.NFI_Count__c   : 0;
        v.nfiReason         = po.NFI_Reason__c;
        v.builderDivisionName = (po.Builder_Division__r != null) ? po.Builder_Division__r.Name : null;
        v.communityName       = (po.Community__r       != null) ? po.Community__r.Name       : null;

        v.checks = new List<CheckResult>();

        // Price check: PO_Amount__c vs Price_Book_Total__c
        CheckResult price = new CheckResult();
        price.label      = 'Price Check';
        price.expected   = String.valueOf(v.priceBookTotal);
        price.actual     = String.valueOf(v.poAmount);
        price.passed     = po.Price_Check_Result__c == 'Pass';
        price.variancePct = v.priceVariancePct;
        v.checks.add(price);

        // Qty check: NFI_Count__c == 0 means no not-found items
        CheckResult qty = new CheckResult();
        qty.label    = 'Qty Check';
        qty.expected = '0';
        qty.actual   = String.valueOf(v.nfiCount);
        qty.passed   = (v.nfiCount == 0);
        qty.variancePct = null;
        v.checks.add(qty);

        return v;
    }
}
