public with sharing class OverUnderController {

    public class OverUnderView {
        @AuraEnabled public Summary summary;
        @AuraEnabled public List<LineRow> lines;
    }

    public class LineRow {
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal billedQty;
        @AuraEnabled public Decimal billedAmt;

        public LineRow(String productName, Decimal billedQty, Decimal billedAmt) {
            this.productName = productName;
            this.billedQty   = billedQty;
            this.billedAmt   = billedAmt;
        }
    }

    public class Summary {
        @AuraEnabled public Decimal totalBilled;
        @AuraEnabled public Decimal fieldPlants;
        @AuraEnabled public Decimal fieldTrees;
        @AuraEnabled public Decimal fieldSodSqFt;
        @AuraEnabled public Decimal fieldMulchCY;
        @AuraEnabled public Decimal grossVariancePct;
    }

    @AuraEnabled(cacheable=true)
    public static OverUnderView getReport(Id workOrderId) {
        if (!Schema.sObjectType.WorkOrder.isAccessible()) {
            throw new AuraHandledException('Insufficient access to WorkOrder');
        }
        if (!Schema.sObjectType.WorkOrderLineItem.isAccessible()) {
            throw new AuraHandledException('Insufficient access to WorkOrderLineItem');
        }

        WorkOrder wo = [
            SELECT Id, Plant_Quantity__c, Tree_Quantity__c,
                   Sod_Square_Footage__c, Mulch_CY__c
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        List<WorkOrderLineItem> wolis = [
            SELECT Product2.Name, Quantity, UnitPrice
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :workOrderId
        ];

        return buildView(wo, wolis);
    }

    @TestVisible
    private static OverUnderView buildView(WorkOrder wo, List<WorkOrderLineItem> wolis) {
        OverUnderView view = new OverUnderView();
        view.lines = new List<LineRow>();

        Decimal totalBilledAmt = 0;
        for (WorkOrderLineItem w : wolis) {
            String name = (w.Product2 != null && w.Product2.Name != null) ? w.Product2.Name : '(No Product)';
            Decimal qty = w.Quantity  != null ? w.Quantity  : 0;
            Decimal up  = w.UnitPrice != null ? w.UnitPrice : 0;
            Decimal amt = qty * up;
            view.lines.add(new LineRow(name, qty, amt));
            totalBilledAmt += amt;
        }

        Summary s = new Summary();
        s.totalBilled   = totalBilledAmt;
        s.fieldPlants   = wo.Plant_Quantity__c     != null ? wo.Plant_Quantity__c     : 0;
        s.fieldTrees    = wo.Tree_Quantity__c      != null ? wo.Tree_Quantity__c      : 0;
        s.fieldSodSqFt  = wo.Sod_Square_Footage__c != null ? wo.Sod_Square_Footage__c : 0;
        s.fieldMulchCY  = wo.Mulch_CY__c           != null ? wo.Mulch_CY__c           : 0;

        // Variance between line-item billed amounts and field-installed counts requires
        // a unit-mapping batch (future work). Pct is placeholder until that batch runs.
        s.grossVariancePct = 0;

        view.summary = s;
        return view;
    }
}
