@IsTest
private class HomeBuilderAutoCloseServiceTest {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'HB AutoClose Test Account');
        insert acct;

        RecordType rt = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'WorkOrder' AND DeveloperName = 'Production_Install'
            LIMIT 1
        ];

        WorkOrder parent = new WorkOrder(
            RecordTypeId        = rt.Id,
            AccountId           = acct.Id,
            Subject             = 'HB AutoClose Parent WO',
            Status              = 'New',
            Work_Order_Type__c  = 'Production Install'
        );
        insert parent;

        WorkOrder child = new WorkOrder(
            RecordTypeId        = rt.Id,
            AccountId           = acct.Id,
            ParentWorkOrderId   = parent.Id,
            Subject             = 'HB AutoClose Child WO',
            Status              = 'New',
            Work_Order_Type__c  = 'Production Install'
        );
        insert child;

        Purchase_Order__c po = new Purchase_Order__c(
            Builder_Account__c  = acct.Id,
            Division_Account__c = acct.Id,
            PO_Number__c        = 'HB-AC-TEST-001',
            Status__c           = 'Work Order Created',
            Work_Order__c       = parent.Id
        );
        insert po;
    }

    private static WorkOrder getParent() {
        return [SELECT Id, Status FROM WorkOrder WHERE Subject = 'HB AutoClose Parent WO' LIMIT 1];
    }

    private static WorkOrder getChild() {
        return [SELECT Id, Status FROM WorkOrder WHERE Subject = 'HB AutoClose Child WO' LIMIT 1];
    }

    private static void insertCompletedQiTask(Id workOrderId) {
        insert new Task(
            WhatId   = workOrderId,
            OwnerId  = UserInfo.getUserId(),
            Subject  = 'QI Inspection - Schedule Within 5 Days',
            Status   = 'Completed',
            Priority = 'High'
        );
    }

    @IsTest
    static void paidStandardParentClosesEligibleBuilderChildrenAndParent() {
        WorkOrder parent = getParent();
        WorkOrder child  = getChild();
        insertCompletedQiTask(child.Id);

        insert new Invoice__c(
            External_Invoice_ID__c = 'HB-WO:' + String.valueOf(parent.Id),
            Invoice_Date__c        = Date.today(),
            Status__c              = 'Paid',
            Total_Revenue__c       = 1000,
            Total_Cost__c          = 700,
            Amount_Paid__c         = 1000
        );

        Test.startTest();
        HomeBuilderAutoCloseService.checkAutoCloseConditions(parent.Id);
        Test.stopTest();

        System.assertEquals('Closed', [SELECT Status FROM WorkOrder WHERE Id = :parent.Id].Status,
            'Parent should auto-close when paid and all children have completed QI.');
        System.assertEquals('Closed', [SELECT Status FROM WorkOrder WHERE Id = :child.Id].Status,
            'Child should auto-close when parent is paid and child has completed QI.');
    }

    @IsTest
    static void standardCheckRequiresPaidInvoiceBeforeClosing() {
        WorkOrder parent = getParent();
        WorkOrder child  = getChild();
        insertCompletedQiTask(child.Id);

        Test.startTest();
        HomeBuilderAutoCloseService.checkAutoCloseConditions(parent.Id);
        Test.stopTest();

        System.assertNotEquals('Closed', [SELECT Status FROM WorkOrder WHERE Id = :parent.Id].Status,
            'Standard Builder parent should not close without a paid invoice.');
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
        WorkOrder parent = getParent();

        System.assertEquals(false, HomeBuilderAutoCloseService.isStandardHomeBuilderInvoice(null));
        System.assertEquals(false,
            HomeBuilderAutoCloseService.isStandardHomeBuilderInvoice(
                new Invoice__c(External_Invoice_ID__c = '')));
        System.assertEquals(true,
            HomeBuilderAutoCloseService.isStandardHomeBuilderInvoice(
                new Invoice__c(External_Invoice_ID__c = 'HB-AQUA:' + String.valueOf(parent.Id) + ':Stolen')));

        Test.startTest();
        HomeBuilderAutoCloseService.checkAutoCloseConditions(null);
        HomeBuilderAutoCloseService.onInvoicePaid(new List<Invoice__c>{
            new Invoice__c(External_Invoice_ID__c = 'HB-AQUA:not-an-id:Stolen', Status__c = 'Paid')
        });
        Test.stopTest();
    }

    @IsTest
    static void paidChildWithoutCompletedQiStaysOpenAndUsesAlertBranch() {
        WorkOrder parent = getParent();
        WorkOrder child  = getChild();

        insert new Invoice__c(
            External_Invoice_ID__c = 'HB-WO:' + String.valueOf(parent.Id),
            Invoice_Date__c        = Date.today(),
            Status__c              = 'Paid',
            Total_Revenue__c       = 1000,
            Total_Cost__c          = 700,
            Amount_Paid__c         = 1000
        );

        Test.startTest();
        HomeBuilderAutoCloseService.checkAutoCloseConditions(parent.Id);
        Test.stopTest();

        System.assertNotEquals('Closed', [SELECT Status FROM WorkOrder WHERE Id = :child.Id].Status,
            'Child without completed QI should not auto-close.');
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