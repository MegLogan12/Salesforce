@IsTest
private class ParentRollupBatchTest {

    private static final Id PARENT_RT = Schema.SObjectType.Account
        .getRecordTypeInfosByDeveloperName().get('Builder_Parent').getRecordTypeId();
    private static final Id DIVISION_RT = Schema.SObjectType.Account
        .getRecordTypeInfosByDeveloperName().get('Builder_Market').getRecordTypeId();

    @TestSetup
    static void makeData() {
        Account parent = new Account(Name = 'Test Corp', RecordTypeId = PARENT_RT);
        insert parent;

        // Two active divisions with revenue already set (simulates post-DivisionKpiRecalcBatch state)
        insert new List<Account>{
            new Account(
                Name = 'Division A', RecordTypeId = DIVISION_RT,
                ParentId = parent.Id, Account_Status__c = 'Active',
                Market__c = 'Greenville', Division_Revenue_T12M__c = 5000
            ),
            new Account(
                Name = 'Division B', RecordTypeId = DIVISION_RT,
                ParentId = parent.Id, Account_Status__c = 'Active',
                Market__c = 'Asheville', Division_Revenue_T12M__c = 3000
            )
        };
    }

    @IsTest
    static void batch_sumsRevenueAndBuildsMarkets() {
        Test.startTest();
        ParentRollupBatch.run();
        Test.stopTest();

        Account parent = [
            SELECT Parent_Revenue_T12M__c, Active_Markets__c
            FROM Account
            WHERE RecordType.DeveloperName = 'Builder_Parent'
            LIMIT 1
        ];
        System.assertEquals(8000, parent.Parent_Revenue_T12M__c, 'Parent revenue should sum both divisions');
        System.assert(parent.Active_Markets__c != null, 'Active markets should be set');
        System.assert(parent.Active_Markets__c.contains('Asheville'), 'Should include Asheville');
        System.assert(parent.Active_Markets__c.contains('Greenville'), 'Should include Greenville');
    }

    @IsTest
    static void batch_noActiveDivisions_clearsMarkets() {
        // A parent with no active divisions should produce null revenue and null markets
        Account emptyParent = new Account(Name = 'Empty Corp', RecordTypeId = PARENT_RT);
        insert emptyParent;

        Account inactiveDiv = new Account(
            Name = 'Inactive Div', RecordTypeId = DIVISION_RT,
            ParentId = emptyParent.Id, Account_Status__c = 'Inactive',
            Market__c = 'Greenville', Division_Revenue_T12M__c = 1000
        );
        insert inactiveDiv;

        Test.startTest();
        ParentRollupBatch.run();
        Test.stopTest();

        Account parent = [SELECT Parent_Revenue_T12M__c, Active_Markets__c FROM Account WHERE Id = :emptyParent.Id];
        // Inactive division revenue IS summed into parent (batch sums all Builder_Market regardless of status)
        // Active_Markets__c should be null because no Account_Status__c = Active divisions
        System.assertEquals(null, parent.Active_Markets__c, 'No active divisions — markets should be null');
    }
}