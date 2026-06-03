@IsTest(SeeAllData=false)
private class DivisionCompareControllerTest {

    @IsTest
    static void blockedWhenKpiFieldsAbsent() {
        // KPI fields (Revenue_MTD__c, On_Time_Pct__c, GP_Pct__c) do not exist on Account yet.
        // getCompare must return a blocked view until the COO batch prerequisite is deployed.
        Test.startTest();
        DivisionCompareController.CompareView view =
            DivisionCompareController.getCompare(null, 'Revenue_MTD__c');
        Test.stopTest();

        System.assertEquals(true, view.blocked, 'View should be blocked when KPI fields are absent');
        System.assertNotEquals(null, view.blockerReason, 'Blocker reason should be set');
        System.assert(
            view.blockerReason.containsIgnoreCase('KPI'),
            'Blocker reason should mention KPI: ' + view.blockerReason
        );
        System.assertEquals(0, view.rows.size(), 'No rows expected when blocked');
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
        dr.metricLabel = 'Revenue_MTD__c';
        dr.metricValue = 99999.99;
        dr.rank        = 1;

        cv.rows.add(dr);

        System.assertEquals(1,             cv.rows.size(),         'One row added');
        System.assertEquals('Test Division', cv.rows[0].name,      'Name mismatch');
        System.assertEquals('West',          cv.rows[0].region,    'Region mismatch');
        System.assertEquals(1,               cv.rows[0].rank,      'Rank mismatch');
        System.assertEquals(99999.99,        cv.rows[0].metricValue, 'MetricValue mismatch');
    }

    @IsTest
    static void kpiFieldsExist_returnsFalseWhenAbsent() {
        // Directly exercise the @TestVisible helper; confirms KPI fields are not on Account.
        Test.startTest();
        Boolean exists = DivisionCompareController.kpiFieldsExist();
        Test.stopTest();

        System.assertEquals(false, exists, 'KPI fields should not yet exist on Account');
    }
}
