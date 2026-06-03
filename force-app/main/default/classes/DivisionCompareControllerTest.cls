@IsTest(SeeAllData=false)
private class DivisionCompareControllerTest {

    @IsTest
    static void getCompare_returnsViewForValidMetric() {
        // Create a parent builder-market account and two child divisions.
        Account parent = new Account(Name = 'Parent Builder');
        insert parent;
        Account d1 = new Account(Name = 'Div Alpha', ParentId = parent.Id);
        Account d2 = new Account(Name = 'Div Beta',  ParentId = parent.Id);
        insert new List<Account>{ d1, d2 };

        Test.startTest();
        DivisionCompareController.CompareView view =
            DivisionCompareController.getCompare(parent.Id, 'Division_Revenue_T12M__c');
        Test.stopTest();

        // If KPI fields exist in this org the view is unblocked; otherwise blocked.
        // Either way the view object must be non-null and internally consistent.
        System.assertNotEquals(null, view, 'View must not be null');
        System.assertNotEquals(null, view.rows, 'Rows list must not be null');
        if (!view.blocked) {
            System.assertEquals(null, view.blockerReason, 'No blocker reason when unblocked');
            System.assertEquals(2, view.rows.size(), 'Two child divisions expected');
            for (DivisionCompareController.DivisionRow r : view.rows) {
                System.assert(r.rank >= 1 && r.rank <= 2, 'Rank in range');
                System.assertEquals('Division_Revenue_T12M__c', r.metricLabel, 'Metric label set');
            }
        } else {
            System.assert(
                view.blockerReason.containsIgnoreCase('KPI'),
                'Blocker reason should mention KPI: ' + view.blockerReason
            );
            System.assertEquals(0, view.rows.size(), 'No rows when blocked');
        }
    }

    @IsTest
    static void getCompare_throwsOnInvalidMetric() {
        // Verify that an unrecognised metric name is rejected with AuraHandledException.
        // Only reachable when KPI fields exist (otherwise blocked before metric validation).
        if (!DivisionCompareController.kpiFieldsExist()) {
            return; // skip — blocked path tested separately
        }
        Account parent = new Account(Name = 'Parent Builder');
        insert parent;

        Test.startTest();
        Boolean threw = false;
        try {
            DivisionCompareController.getCompare(parent.Id, 'Revenue_MTD__c');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected AuraHandledException for invalid metric');
    }

    @IsTest
    static void compareView_innerClassesConstructable() {
        DivisionCompareController.CompareView cv = new DivisionCompareController.CompareView();
        cv.blocked       = false;
        cv.blockerReason = null;
        cv.rows          = new List<DivisionCompareController.DivisionRow>();

        DivisionCompareController.DivisionRow dr = new DivisionCompareController.DivisionRow();
        dr.divisionId  = null;
        dr.name        = 'Test Division';
        dr.region      = 'West';
        dr.metricLabel = 'Division_Revenue_T12M__c';
        dr.metricValue = 99999.99;
        dr.rank        = 1;

        cv.rows.add(dr);

        System.assertEquals(1,               cv.rows.size(),           'One row added');
        System.assertEquals('Test Division', cv.rows[0].name,          'Name mismatch');
        System.assertEquals('West',          cv.rows[0].region,        'Region mismatch');
        System.assertEquals(1,               cv.rows[0].rank,          'Rank mismatch');
        System.assertEquals(99999.99,        cv.rows[0].metricValue,   'MetricValue mismatch');
    }

    @IsTest
    static void buildRows_assignsRankAndCoversComparator() {
        // Exercises buildRows and DivisionRowComparator via @TestVisible.
        // Division_Region__c is a standard-ish field present on all orgs; metricValue
        // will be null for most test accounts, exercising the null-handling comparator path.
        Account a1 = new Account(Name = 'Div Alpha');
        Account a2 = new Account(Name = 'Div Beta');
        insert new List<Account>{ a1, a2 };

        List<Account> accts = [SELECT Id, Name, Division_Region__c FROM Account
                               WHERE Id IN (:a1.Id, :a2.Id) ORDER BY Name];

        Test.startTest();
        List<DivisionCompareController.DivisionRow> rows =
            DivisionCompareController.buildRows(accts, 'Division_Region__c');
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Expected 2 rows');
        for (DivisionCompareController.DivisionRow r : rows) {
            System.assert(r.rank >= 1 && r.rank <= 2, 'Rank should be 1 or 2');
            System.assertEquals('Division_Region__c', r.metricLabel, 'Metric label set');
        }
    }
}
