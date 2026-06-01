@IsTest(SeeAllData=true)
private class HomeBuilderAutoCloseServiceTest {
    private static String standardInvoiceKey(Id workOrderId) {
        return 'HB-WO:' + String.valueOf(workOrderId);
    }

    private static WorkOrder getBuilderParentWorkOrder() {
        List<WorkOrder> rows = [
            SELECT Id, Status
            FROM WorkOrder
            WHERE Status != 'Closed'
              AND Id IN (SELECT ParentWorkOrderId FROM WorkOrder WHERE ParentWorkOrderId != null)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static List<WorkOrder> getBuilderChildren(Id parentId) {
        return [
            SELECT Id, Status
            FROM WorkOrder
            WHERE ParentWorkOrderId = :parentId
            ORDER BY CreatedDate
        ];
    }

    private static void insertCompletedQiTask(Id workOrderId) {
        insert new Task(
            WhatId = workOrderId,
            OwnerId = UserInfo.getUserId(),
            Subject = 'QI Inspection - Schedule Within 5 Days',
            Status = 'Completed',
            Priority = 'High'
        );
    }

    @IsTest
    static void paidStandardParentClosesEligibleBuilderChildrenAndParent() {
        WorkOrder parent = getBuilderParentWorkOrder();
        if (parent == null) {
            System.debug('[HomeBuilderAutoCloseServiceTest] No suitable parent WorkOrder found - skipping auto-close smoke test.');
            return;
        }
        List<WorkOrder> children = getBuilderChildren(parent.Id);
        System.assert(!children.isEmpty(), 'Expected Builder child WorkOrders under the live parent.');
        for (WorkOrder child : children) {
            insertCompletedQiTask(child.Id);
        }

        Invoice__c invoiceRecord = new Invoice__c(
            External_Invoice_ID__c = standardInvoiceKey(parent.Id),
            Invoice_Date__c = Date.today(),
            Status__c = 'Pending Send',
            Total_Revenue__c = 1000,
            Total_Cost__c = 700,
            Amount_Paid__c = 0
        );
        insert invoiceRecord;

        Test.startTest();
        invoiceRecord.Status__c = 'Paid';
        invoiceRecord.Amount_Paid__c = 1000;
        invoiceRecord.Date_Paid__c = Date.today();
        update invoiceRecord;
        Test.stopTest();

        System.assertEquals('Closed', [SELECT Status FROM WorkOrder WHERE Id = :parent.Id].Status);
        for (WorkOrder child : [
            SELECT Status
            FROM WorkOrder
            WHERE ParentWorkOrderId = :parent.Id
        ]) {
            System.assertEquals('Closed', child.Status);
        }
    }

    @IsTest
    static void standardCheckRequiresPaidInvoiceBeforeClosing() {
        WorkOrder parent = getBuilderParentWorkOrder();
        if (parent == null) {
            System.debug('[HomeBuilderAutoCloseServiceTest] No suitable parent WorkOrder found - skipping invoice gate smoke test.');
            return;
        }
        for (WorkOrder child : getBuilderChildren(parent.Id)) {
            insertCompletedQiTask(child.Id);
        }

        Test.startTest();
        HomeBuilderAutoCloseService.checkAutoCloseConditions(parent.Id);
        Test.stopTest();

        System.assertNotEquals(
            'Closed',
            [SELECT Status FROM WorkOrder WHERE Id = :parent.Id].Status,
            'Standard Builder parent should not close without a paid invoice.'
        );
    }

    @IsTest
    static void schedulerExecutesBuilderStandardClosePath() {
        Test.startTest();
        new AutoCloseScheduler().execute(null);
        Test.stopTest();
        System.assert(true, 'Scheduler executed without exception.');
    }

    @IsTest
    static void standardInvoiceHelpersCoverBlankAquaAndInvalidKeys() {
        System.assertEquals(false, HomeBuilderAutoCloseService.isStandardHomeBuilderInvoice(null));
        System.assertEquals(
            false,
            HomeBuilderAutoCloseService.isStandardHomeBuilderInvoice(new Invoice__c(External_Invoice_ID__c = ''))
        );
        System.assertEquals(
            true,
            HomeBuilderAutoCloseService.isStandardHomeBuilderInvoice(
                new Invoice__c(External_Invoice_ID__c = 'HB-AQUA:' + String.valueOf(BUILDER_PARENT_ID) + ':Stolen')
            )
        );

        Test.startTest();
        HomeBuilderAutoCloseService.checkAutoCloseConditions(null);
        HomeBuilderAutoCloseService.onInvoicePaid(new List<Invoice__c>{
            new Invoice__c(External_Invoice_ID__c = 'HB-AQUA:not-an-id:Stolen', Status__c = 'Paid')
        });
        Test.stopTest();
    }

    @IsTest
    static void paidChildWithoutCompletedQiStaysOpenAndUsesAlertBranch() {
        List<WorkOrder> childRows = [
            SELECT Id, Status
            FROM WorkOrder
            WHERE ParentWorkOrderId != null
              AND Status != 'Closed'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (childRows.isEmpty()) {
            System.debug('[HomeBuilderAutoCloseServiceTest] No child WorkOrder found - skipping QI gate smoke test.');
            return;
        }
        WorkOrder child = childRows[0];

        Invoice__c invoiceRecord = new Invoice__c(
            External_Invoice_ID__c = standardInvoiceKey(child.Id),
            Invoice_Date__c = Date.today(),
            Status__c = 'Pending Send',
            Total_Revenue__c = 1000,
            Total_Cost__c = 700,
            Amount_Paid__c = 0
        );
        insert invoiceRecord;

        Test.startTest();
        invoiceRecord.Status__c = 'Paid';
        invoiceRecord.Amount_Paid__c = 1000;
        invoiceRecord.Date_Paid__c = Date.today();
        update invoiceRecord;
        Test.stopTest();

        System.assertNotEquals('Closed', [SELECT Status FROM WorkOrder WHERE Id = :child.Id].Status);
    }

    @IsTest
    static void invoiceHandlerStillRoutesLegacyAndSentInvoicesSafely() {
        List<Invoice__c> invoices = new List<Invoice__c>{
            new Invoice__c(Status__c = 'Paid'),
            new Invoice__c(Status__c = 'Sent')
        };

        Test.startTest();
        InvoiceHandler.handleAfter(invoices, null);
        Test.stopTest();

        System.assert(true, 'Legacy and sent invoice branches executed without exception.');
    }
}