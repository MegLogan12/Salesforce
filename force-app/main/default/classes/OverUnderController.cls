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
            SELECT Id, GrandTotal, Plant_Quantity__c, Tree_Quantity__c,
                   Sod_Square_Footage__c, Mulch_CY__c
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        List<WorkOrderLineItem> wolis = [
            SELECT Product2.Name, Quantity, TotalPrice
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
            Decimal qty = w.Quantity  != null ? w.Quantity   : 0;
            Decimal amt = w.TotalPrice != null ? w.TotalPrice : 0;
            view.lines.add(new LineRow(name, qty, amt));
            totalBilledAmt += amt;
        }

        Summary s = new Summary();
        s.totalBilled   = wo.GrandTotal            != null ? wo.GrandTotal            : 0;
        s.fieldPlants   = wo.Plant_Quantity__c     != null ? wo.Plant_Quantity__c     : 0;
        s.fieldTrees    = wo.Tree_Quantity__c      != null ? wo.Tree_Quantity__c      : 0;
        s.fieldSodSqFt  = wo.Sod_Square_Footage__c != null ? wo.Sod_Square_Footage__c : 0;
        s.fieldMulchCY  = wo.Mulch_CY__c           != null ? wo.Mulch_CY__c           : 0;

        // variance: (billed - field total billed) / billed * 100
        if (s.totalBilled != 0) {
            s.grossVariancePct = ((s.totalBilled - totalBilledAmt) / s.totalBilled * 100).setScale(2);
        } else {
            s.grossVariancePct = 0;
        }

        view.summary = s;
        return view;
    }
}
