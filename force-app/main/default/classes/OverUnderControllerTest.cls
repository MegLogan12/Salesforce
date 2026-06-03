@IsTest(SeeAllData=true)
private class OverUnderControllerTest {

    // WorkOrder.GrandTotal and WorkOrderLineItem.TotalPrice are formula fields — not settable.
    // Tests call @TestVisible buildView() directly with in-memory stubs using writable fields.
    // SeeAllData=true so the getReport integration test can query a real production WorkOrder.
    // No @TestSetup — incompatible with SeeAllData=true.

    private static WorkOrder makeWo(Decimal plants, Decimal trees, Decimal sod, Decimal mulch) {
        WorkOrder wo = new WorkOrder();
        wo.Plant_Quantity__c     = plants;
        wo.Tree_Quantity__c      = trees;
        wo.Sod_Square_Footage__c = sod;
        wo.Mulch_CY__c           = mulch;
        return wo;
    }

    @IsTest
    static void summaryCalculation_happyPath() {
        WorkOrder wo = makeWo(50, 10, 200, 5);

        WorkOrderLineItem w1 = new WorkOrderLineItem();
        w1.Quantity  = 10;
        w1.UnitPrice = 400;

        WorkOrderLineItem w2 = new WorkOrderLineItem();
        w2.Quantity  = 5;
        w2.UnitPrice = 500;

        Test.startTest();
        OverUnderController.OverUnderView view = OverUnderController.buildView(wo, new List<WorkOrderLineItem>{ w1, w2 });
        Test.stopTest();

        System.assertEquals(2,    view.lines.size(),            'Expected two line rows');
        System.assertEquals(4000, view.lines[0].billedAmt,      'Line 0 amt: 10 * 400');
        System.assertEquals(2500, view.lines[1].billedAmt,      'Line 1 amt: 5 * 500');
        System.assertEquals(6500, view.summary.totalBilled,     'Total billed = sum of lines');
        System.assertEquals(50,   view.summary.fieldPlants,     'Plant qty mismatch');
        System.assertEquals(10,   view.summary.fieldTrees,      'Tree qty mismatch');
        System.assertEquals(200,  view.summary.fieldSodSqFt,    'Sod sqft mismatch');
        System.assertEquals(5,    view.summary.fieldMulchCY,    'Mulch CY mismatch');
        System.assertEquals(0,    view.summary.grossVariancePct, 'Variance placeholder = 0');
    }

    @IsTest
    static void summaryCalculation_emptyLines() {
        WorkOrder wo = makeWo(0, 0, 0, 0);

        Test.startTest();
        OverUnderController.OverUnderView view = OverUnderController.buildView(wo, new List<WorkOrderLineItem>());
        Test.stopTest();

        System.assertEquals(0, view.lines.size(),              'No lines expected');
        System.assertEquals(0, view.summary.totalBilled,       'Total billed should be 0');
        System.assertEquals(0, view.summary.grossVariancePct,  'Variance should be 0');
    }

    @IsTest
    static void getReport_realWorkOrder_returnsView() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder LIMIT 1];
        if (wos.isEmpty()) return;

        Test.startTest();
        OverUnderController.OverUnderView view = OverUnderController.getReport(wos[0].Id);
        Test.stopTest();

        System.assertNotEquals(null, view, 'View should not be null');
        System.assertNotEquals(null, view.summary, 'Summary should be populated');
    }

    @IsTest
    static void lineRow_nullProduct_defaultsLabel() {
        WorkOrder wo = makeWo(1, 0, 0, 0);

        WorkOrderLineItem w = new WorkOrderLineItem();
        w.Quantity  = 1;
        w.UnitPrice = 500;

        Test.startTest();
        OverUnderController.OverUnderView view = OverUnderController.buildView(wo, new List<WorkOrderLineItem>{ w });
        Test.stopTest();

        System.assertEquals('(No Product)', view.lines[0].productName, 'Null product should default label');
        System.assertEquals(1,   view.lines[0].billedQty, 'Qty mismatch');
        System.assertEquals(500, view.lines[0].billedAmt, 'Amt: 1 * 500');
    }
}
