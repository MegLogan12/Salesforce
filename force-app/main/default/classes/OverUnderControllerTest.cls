@IsTest(SeeAllData=false)
private class OverUnderControllerTest {

    // Build a bare WorkOrder stub — cannot INSERT WorkOrder in this org due to Flow restriction.
    // We exercise buildView() directly via @TestVisible to get class-body coverage.

    private static WorkOrder makeWo(Decimal grandTotal, Decimal plants, Decimal trees, Decimal sod, Decimal mulch) {
        WorkOrder wo = new WorkOrder();
        wo.GrandTotal            = grandTotal;
        wo.Plant_Quantity__c     = plants;
        wo.Tree_Quantity__c      = trees;
        wo.Sod_Square_Footage__c = sod;
        wo.Mulch_CY__c           = mulch;
        return wo;
    }

    @IsTest
    static void summaryCalculation_happyPath() {
        WorkOrder wo = makeWo(10000, 50, 10, 200, 5);

        WorkOrderLineItem w1 = new WorkOrderLineItem();
        w1.Quantity   = 10;
        w1.TotalPrice = 4000;

        WorkOrderLineItem w2 = new WorkOrderLineItem();
        w2.Quantity   = 5;
        w2.TotalPrice = 2500;

        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>{ w1, w2 };

        Test.startTest();
        OverUnderController.OverUnderView view = OverUnderController.buildView(wo, wolis);
        Test.stopTest();

        System.assertEquals(2, view.lines.size(), 'Expected two line rows');
        System.assertEquals(10000, view.summary.totalBilled, 'GrandTotal mismatch');
        System.assertEquals(50,    view.summary.fieldPlants,  'Plant qty mismatch');
        System.assertEquals(10,    view.summary.fieldTrees,   'Tree qty mismatch');
        System.assertEquals(200,   view.summary.fieldSodSqFt, 'Sod sqft mismatch');
        System.assertEquals(5,     view.summary.fieldMulchCY, 'Mulch CY mismatch');
        // variance = (10000 - 6500) / 10000 * 100 = 35.00
        System.assertEquals(35.00, view.summary.grossVariancePct, 'Variance pct mismatch');
    }

    @IsTest
    static void summaryCalculation_zeroBilled_noVariance() {
        WorkOrder wo = makeWo(0, 0, 0, 0, 0);
        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();

        Test.startTest();
        OverUnderController.OverUnderView view = OverUnderController.buildView(wo, wolis);
        Test.stopTest();

        System.assertEquals(0, view.lines.size(),              'No lines expected');
        System.assertEquals(0, view.summary.totalBilled,       'Total billed should be 0');
        System.assertEquals(0, view.summary.grossVariancePct,  'Variance should be 0 when billed is 0');
    }

    @IsTest
    static void lineRow_nullProduct_defaultsLabel() {
        WorkOrder wo = makeWo(500, 1, 0, 0, 0);

        // WorkOrderLineItem with no Product2 relationship populated
        WorkOrderLineItem w = new WorkOrderLineItem();
        w.Quantity   = 1;
        w.TotalPrice = 500;
        // Product2 is null — controller must handle gracefully

        Test.startTest();
        OverUnderController.OverUnderView view = OverUnderController.buildView(wo, new List<WorkOrderLineItem>{ w });
        Test.stopTest();

        System.assertEquals('(No Product)', view.lines[0].productName, 'Null product should default label');
        System.assertEquals(1,   view.lines[0].billedQty, 'Qty mismatch');
        System.assertEquals(500, view.lines[0].billedAmt, 'Amt mismatch');
    }
}
