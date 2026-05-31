/**
 * WorkOrderPipelineControllerTest
 * Phase 4 fix: updated to use Work_Order__c (custom object) now that the
 * controller correctly queries Work_Order__c instead of standard WorkOrder.
 */
@IsTest
private class WorkOrderPipelineControllerTest {

    @IsTest
    static void getPipelineReturns10Columns() {
        Test.startTest();
        List<WorkOrderPipelineController.StageColumn> cols = WorkOrderPipelineController.getPipeline();
        Test.stopTest();
        System.assertEquals(10, cols.size());
    }

    @IsTest
    static void buildCardFromWorkOrder() {
        Work_Order__c wo = new Work_Order__c();
        wo.Notes__c = 'Test scope';
        Test.startTest();
        WorkOrderPipelineController.WoCard c = WorkOrderPipelineController.buildCard(wo);
        Test.stopTest();
        System.assertNotEquals(null, c);
        System.assertEquals('Test scope', c.scope);
    }

    @IsTest
    static void computeCardClassClosedReturnsGreen() {
        Work_Order__c wo = new Work_Order__c();
        wo.Status__c = 'Closed';
        System.assertEquals('wo-card-green', WorkOrderPipelineController.computeCardClass(wo));
    }

    @IsTest
    static void computeCardClassApprovedReturnsGreen() {
        Work_Order__c wo = new Work_Order__c();
        wo.Status__c = 'Approved';
        System.assertEquals('wo-card-green', WorkOrderPipelineController.computeCardClass(wo));
    }

    @IsTest
    static void computeCardClassReturnedReturnsRed() {
        Work_Order__c wo = new Work_Order__c();
        wo.Takeoff_Status__c = 'Returned';
        System.assertEquals('wo-card-red', WorkOrderPipelineController.computeCardClass(wo));
    }

    @IsTest
    static void computeCardClass30DayNoTakeoffAmber() {
        Work_Order__c wo = new Work_Order__c();
        wo.Pipeline_Bucket__c = '30 Days';
        wo.Takeoff_Status__c = 'Not Started';
        System.assertEquals('wo-card-amber', WorkOrderPipelineController.computeCardClass(wo));
    }

    @IsTest
    static void computeCardClass30DayNullTakeoffAmber() {
        Work_Order__c wo = new Work_Order__c();
        wo.Pipeline_Bucket__c = '30 Days';
        wo.Takeoff_Status__c = null;
        System.assertEquals('wo-card-amber', WorkOrderPipelineController.computeCardClass(wo));
    }

    @IsTest
    static void mapStageHandlesStatusValues() {
        Work_Order__c wo = new Work_Order__c();

        wo.Status__c = 'Closed';
        System.assertEquals('Closed', WorkOrderPipelineController.mapStage(wo));

        wo.Status__c = 'Approved';
        System.assertEquals('Closed', WorkOrderPipelineController.mapStage(wo));

        wo.Status__c = 'In Progress';
        System.assertEquals('In Progress', WorkOrderPipelineController.mapStage(wo));

        wo.Status__c = 'Pending Closeout';
        System.assertEquals('QI', WorkOrderPipelineController.mapStage(wo));

        wo.Status__c = 'Pending Approval';
        System.assertEquals('QI', WorkOrderPipelineController.mapStage(wo));

        wo.Status__c = 'Scheduled';
        System.assertEquals('Scheduled', WorkOrderPipelineController.mapStage(wo));

        wo.Status__c = 'Invoiced';
        System.assertEquals('Invoiced', WorkOrderPipelineController.mapStage(wo));

        wo.Status__c = 'Ready for Invoice';
        System.assertEquals('Ready to Invoice', WorkOrderPipelineController.mapStage(wo));

        wo.Status__c = 'Takeoff Complete';
        System.assertEquals('Takeoff Complete', WorkOrderPipelineController.mapStage(wo));

        wo.Status__c = 'Clear for Schedule';
        System.assertEquals('Site Ready', WorkOrderPipelineController.mapStage(wo));
    }

    @IsTest
    static void mapStageBucketValues() {
        Work_Order__c wo = new Work_Order__c();
        wo.Status__c = 'Pending Takeoff';

        wo.Pipeline_Bucket__c = '90+ Days';
        System.assertEquals('Pending Scheduling', WorkOrderPipelineController.mapStage(wo));

        wo.Pipeline_Bucket__c = '60+ Days';
        System.assertEquals('Pending Scheduling', WorkOrderPipelineController.mapStage(wo));

        wo.Pipeline_Bucket__c = '30 Days';
        System.assertEquals('Pending Scheduling', WorkOrderPipelineController.mapStage(wo));

        wo.Pipeline_Bucket__c = 'Ready to Schedule';
        System.assertEquals('Takeoff Complete', WorkOrderPipelineController.mapStage(wo));

        wo.Pipeline_Bucket__c = 'Takeoff In Progress';
        System.assertEquals('Takeoff Complete', WorkOrderPipelineController.mapStage(wo));

        wo.Status__c = null;
        wo.Pipeline_Bucket__c = 'Clear to Schedule';
        System.assertEquals('Site Ready', WorkOrderPipelineController.mapStage(wo));
    }

    @IsTest
    static void mapStageDefaultsToNew() {
        Work_Order__c wo = new Work_Order__c();
        wo.Status__c = null;
        wo.Pipeline_Bucket__c = null;
        System.assertEquals('New', WorkOrderPipelineController.mapStage(wo));
    }

    @IsTest
    static void buildCardDaysUntilStartNull() {
        Work_Order__c wo = new Work_Order__c();
        wo.Requested_Install_Date__c = null;
        WorkOrderPipelineController.WoCard c = WorkOrderPipelineController.buildCard(wo);
        System.assertEquals(null, c.daysUntilStart);
    }

    @IsTest
    static void buildCardDaysUntilStartPopulated() {
        Work_Order__c wo = new Work_Order__c();
        wo.Requested_Install_Date__c = Date.today().addDays(10);
        WorkOrderPipelineController.WoCard c = WorkOrderPipelineController.buildCard(wo);
        System.assertEquals(10, c.daysUntilStart);
    }
}