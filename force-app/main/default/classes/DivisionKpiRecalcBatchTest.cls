@IsTest
private class DivisionKpiRecalcBatchTest {

    private static final Id PARENT_RT = Schema.SObjectType.Account
        .getRecordTypeInfosByDeveloperName().get('Builder_Parent').getRecordTypeId();
    private static final Id DIVISION_RT = Schema.SObjectType.Account
        .getRecordTypeInfosByDeveloperName().get('Builder_Market').getRecordTypeId();

    @TestSetup
    static void makeData() {
        Account parent = new Account(Name = 'Test Corp', RecordTypeId = PARENT_RT);
        insert parent;

        Account div = new Account(
            Name = 'Test Division', RecordTypeId = DIVISION_RT,
            ParentId = parent.Id, Account_Status__c = 'Active', Market__c = 'Greenville'
        );
        insert div;

        // Open WO linked to division
        Work_Order__c wo = new Work_Order__c(
            Builder_Market_Account__c = div.Id,
            Status__c = 'Scheduled'
        );
        insert wo;

        // Two completed WOs in the trailing-30-day window for On-Time %:
        //   on-time: finished 5 days ago, promised 4 days ago (finish <= promise)
        //   late:    finished 2 days ago, promised 10 days ago (finish >  promise)
        // → 1 of 2 on time = 50.00%. Both Closed so they don't affect Open_WO_Count.
        List<Work_Order__c> completed = new List<Work_Order__c>{
            new Work_Order__c(
                Builder_Market_Account__c = div.Id,
                Status__c = 'Closed',
                Field_Complete_Date__c = DateTime.now().addDays(-5),
                Scheduled_End_DateTime__c = DateTime.now().addDays(-4)
            ),
            new Work_Order__c(
                Builder_Market_Account__c = div.Id,
                Status__c = 'Closed',
                Field_Complete_Date__c = DateTime.now().addDays(-2),
                Scheduled_End_DateTime__c = DateTime.now().addDays(-10)
            )
        };
        insert completed;

        // Paid T12M invoice exercising both adjustment types:
        //   Adjusted_Revenue = 10000 - 1000 = 9000
        //   Adjusted_Cost    = 7000  - 500  = 6500
        //   GP%              = (9000 - 6500) / 9000 * 100 = 27.78
        Invoice__c inv = new Invoice__c(
            Back_Charge__c = false,
            Temp_Irrigation_Billed__c = false,
            Status__c = 'Paid',
            Date_Paid__c = Date.today().addDays(-10),
            Total_Revenue__c = 10000,
            Customer_Revenue_Adjustment__c = 1000,
            Total_Cost__c = 7000,
            Internal_Cost_Recovery__c = 500,
            Builder_Market_Account__c = div.Id
        );
        insert inv;

        Community__c comm = new Community__c(
            Name = 'Test Community',
            Builder_Account__c = div.Id,
            Active__c = true,
            Aqua_Customer__c = false,
            Temp_Irrigation_Included__c = false,
            Aqua_Included__c = false,
            Lawn_Care_Customer__c = false,
            Aqua_Active__c = false
        );
        insert comm;
    }

    @IsTest
    static void batch_populatesKpiFields() {
        Test.startTest();
        DivisionKpiRecalcBatch.run();
        Test.stopTest();

        Account div = [
            SELECT Division_Revenue_T12M__c, Division_GP_Pct__c,
                   Open_WO_Count__c, Active_Communities_Count__c, On_Time_Completion_Pct__c
            FROM Account
            WHERE RecordType.DeveloperName = 'Builder_Market'
              AND Name = 'Test Division'
            LIMIT 1
        ];
        System.assertEquals(9000, div.Division_Revenue_T12M__c, 'Revenue should be adjusted revenue (10000-1000)');
        System.assertEquals(27.78, div.Division_GP_Pct__c, 'GP% from adjusted rev/cost: (9000-6500)/9000*100');
        System.assertEquals(1, (Integer) div.Open_WO_Count__c, 'One open WO expected');
        System.assertEquals(1, (Integer) div.Active_Communities_Count__c, 'One active community expected');
        System.assertEquals(50.00, div.On_Time_Completion_Pct__c, 'One of two completed WOs on time = 50%');
    }

    @IsTest
    static void batch_zeroData_setsCounts() {
        Id parentId = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Builder_Parent' LIMIT 1].Id;
        Account zeroDiv = new Account(
            Name = 'Empty Division', RecordTypeId = DIVISION_RT,
            ParentId = parentId, Account_Status__c = 'Active', Market__c = 'Asheville'
        );
        insert zeroDiv;

        Test.startTest();
        DivisionKpiRecalcBatch.run();
        Test.stopTest();

        Account div = [
            SELECT Division_Revenue_T12M__c, Open_WO_Count__c, Open_NFI_Count__c
            FROM Account WHERE Id = :zeroDiv.Id
        ];
        System.assertEquals(null, div.Division_Revenue_T12M__c, 'No invoices — revenue should stay null');
        System.assertEquals(0, (Integer) div.Open_WO_Count__c, 'No WOs — count should be 0');
        System.assertEquals(0, (Integer) div.Open_NFI_Count__c, 'No NFI WOs — count should be 0');
    }
}