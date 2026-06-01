@isTest
private class ForemanStdBackboneTest {

    @isTest
    static void testStandardServiceAppointmentWorkOrderAndWoliAreReturned() {
        Work_Order__c wo = new Work_Order__c(
            Work_Order_Type__c = 'Production Install',
            Status__c           = 'In Progress'
        );
        insert wo;

        Work_Order_Line_Item__c woli = new Work_Order_Line_Item__c(
            Work_Order__c = wo.Id,
            Description__c = 'Executable scope line',
            Source__c      = 'WorkOrderLineItem',
            Quantity__c    = 5
        );
        insert woli;

        Test.startTest();
        ForemanMobileController.JobDto job =
            ForemanMobileController.getJob(wo.Id);
        ForemanMobileController.MobileContextDto ctx =
            ForemanMobileController.getMobileContext(wo.Id);
        Test.stopTest();

        System.assertEquals(wo.Id, job.id,
            'Work_Order__c should resolve through the job context.');
        System.assertEquals('Production Install', job.workOrderType,
            'Work order type should flow into the DTO.');
        System.assertEquals(1, ctx.lineItems.size(),
            'Foreman context should expose Work_Order_Line_Item__c scope.');
        System.assertEquals('WorkOrderLineItem', ctx.lineItems[0].source,
            'Scope source field should be preserved.');
        System.assertEquals('Executable scope line', ctx.lineItems[0].description,
            'Line item description should be visible.');
        System.assertEquals(null, job.builderName,
            'WO without community link should not expose builder name.');
    }
}
