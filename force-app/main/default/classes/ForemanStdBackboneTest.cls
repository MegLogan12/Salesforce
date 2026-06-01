@isTest
private class ForemanStdBackboneTest {

    @isTest
    static void testStandardServiceAppointmentWorkOrderAndWoliAreReturned() {
        Account accountRow = new Account(Name = 'FM Standard Account');
        insert accountRow;

        Product2 product = new Product2(Name = 'FM Standard Product', ProductCode = 'FM-STD-1', IsActive = true);
        insert product;

        Id standardPricebookId = Test.getStandardPricebookId();
        insert new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 15,
            IsActive = true
        );
        PricebookEntry pbe = [
            SELECT Id, Product2Id, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId
            AND Product2Id = :product.Id
            LIMIT 1
        ];

        Order orderRow = new Order(
            AccountId = accountRow.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert orderRow;

        OrderItem oi = new OrderItem(
            OrderId = orderRow.Id,
            Product2Id = product.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 15,
            Description = 'Parsed pilot scope line'
        );
        insert oi;

        Id workOrderRtId;
        Map<String, Schema.RecordTypeInfo> rtByDev = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName();
        if (rtByDev.containsKey('Production_Install')) {
            workOrderRtId = rtByDev.get('Production_Install').getRecordTypeId();
        }

        WorkOrder wo = new WorkOrder(
            RecordTypeId = workOrderRtId,
            Subject = 'FM Standard Pilot WorkOrder',
            Status = 'New',
            AccountId = accountRow.Id,
            Pricebook2Id = standardPricebookId,
            Work_Order_Type__c = 'Production Install'
        );
        insert wo;

        WorkOrderLineItem woli = new WorkOrderLineItem(
            WorkOrderId = wo.Id,
            OrderId = orderRow.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 15,
            Description = 'Executable scope line',
            Status = 'New'
        );
        insert woli;

        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Status = 'None',
            Subject = 'FM Standard Pilot Appointment',
            EarliestStartTime = Datetime.now(),
            DueDate = Datetime.now(),
            SchedStartTime = Datetime.now(),
            SchedEndTime = Datetime.now().addHours(2),
            Duration = 120
        );
        insert sa;
        sa = [SELECT Id, AppointmentNumber FROM ServiceAppointment WHERE Id = :sa.Id LIMIT 1];

        Test.startTest();
        ForemanMobileController.JobDto job = ForemanMobileController.getJob(sa.Id);
        ForemanMobileController.MobileContextDto ctx = ForemanMobileController.getMobileContext(sa.Id);
        Test.stopTest();

        System.assertEquals(wo.Id, job.id, 'Standard WorkOrder should resolve through the ServiceAppointment context.');
        System.assertEquals(sa.AppointmentNumber, job.appointmentNumber, 'Appointment metadata should be surfaced.');
        System.assertEquals('Production Install', job.workOrderType, 'Standard WorkOrder type should flow into the DTO.');
        System.assertEquals(1, ctx.lineItems.size(), 'Foreman context should expose WorkOrderLineItem scope.');
        System.assertEquals('WorkOrderLineItem', ctx.lineItems[0].source, 'Scope should be sourced from standard WorkOrderLineItem.');
        System.assertEquals('Executable scope line', ctx.lineItems[0].description, 'WOLI description should be visible.');
        System.assertEquals(null, job.builderName, 'Standard Foreman path should not expose builder contact metadata.');
    }
}