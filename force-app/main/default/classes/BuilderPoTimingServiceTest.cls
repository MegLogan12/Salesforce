@IsTest
private class BuilderPoTimingServiceTest {

    // ── Test Data ─────────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        // Insert timing rules via the seeder (runs inside test context - no callouts)
        // We insert them directly to avoid DML of the seeder in each test
        insert new List<Builder_PO_Timing_Rule__c>{
            new Builder_PO_Timing_Rule__c(
                Name = 'DR Horton Charlotte', Parent_Builder_Name__c = 'DR Horton',
                Division_Builder_Name__c = 'DR Horton Charlotte', Division_Code__c = 'CLT',
                Division_Name__c = 'Charlotte', Min_Days_Before_Start__c = 120,
                Max_Days_Before_Start__c = 180, Business_Days__c = false, Active__c = true),
            new Builder_PO_Timing_Rule__c(
                Name = 'DR Horton Asheville', Parent_Builder_Name__c = 'DR Horton',
                Division_Builder_Name__c = 'DR Horton Asheville', Division_Code__c = 'ASH',
                Division_Name__c = 'Asheville', Min_Days_Before_Start__c = 150,
                Max_Days_Before_Start__c = 180, Business_Days__c = false, Active__c = true),
            new Builder_PO_Timing_Rule__c(
                Name = 'Lennar Charlotte', Parent_Builder_Name__c = 'Lennar',
                Division_Builder_Name__c = 'Lennar Charlotte', Division_Code__c = 'CLT',
                Division_Name__c = 'Charlotte', Min_Days_Before_Start__c = 10,
                Max_Days_Before_Start__c = 10, Business_Days__c = true, Active__c = true),
            new Builder_PO_Timing_Rule__c(
                Name = 'Lennar Greenville', Parent_Builder_Name__c = 'Lennar',
                Division_Builder_Name__c = 'Lennar Greenville', Division_Code__c = 'GRVL',
                Division_Name__c = 'Greenville', Min_Days_Before_Start__c = 10,
                Max_Days_Before_Start__c = 10, Business_Days__c = true, Active__c = true)
        };
    }

    // ── 1. DR Horton Charlotte 120-180 calendar days ──────────────────────────

    @IsTest
    static void drHortonCharlotte_inWindow_returnsInExpectedWindow() {
        Builder_PO_Timing_Rule__c rule = [SELECT Id, Min_Days_Before_Start__c,
            Max_Days_Before_Start__c, Business_Days__c FROM Builder_PO_Timing_Rule__c
            WHERE Name = 'DR Horton Charlotte' LIMIT 1];

        Builder_PO__c po = new Builder_PO__c(
            Builder_Name__c        = 'DR Horton',
            Division_Code__c       = 'CLT',
            PO_Release_Date__c     = Date.today(),
            Estimated_Start_Date__c = Date.today().addDays(150)
        );

        Test.startTest();
        String status = BuilderPoTimingService.calculateTimingStatus(po, rule);
        Test.stopTest();

        System.assertEquals('In Expected Window', status);
    }

    // ── 2. DR Horton Asheville 150-180 calendar days ──────────────────────────

    @IsTest
    static void drHortonAsheville_rule_mapsToAshevilleByNameAndDiv() {
        Test.startTest();
        Builder_PO_Timing_Rule__c rule = BuilderPoTimingService.findTimingRule(
            'DR Horton', 'ASH', null, null);
        Test.stopTest();

        System.assertNotEquals(null, rule);
        System.assertEquals('DR Horton Asheville', rule.Division_Builder_Name__c);
        System.assertEquals(150, Integer.valueOf(rule.Min_Days_Before_Start__c));
    }

    // ── 3. Lennar Charlotte uses business-day calculation ─────────────────────

    @IsTest
    static void lennarCharlotte_businessDays_returnsCorrectStatus() {
        Builder_PO_Timing_Rule__c rule = [SELECT Id, Min_Days_Before_Start__c,
            Max_Days_Before_Start__c, Business_Days__c FROM Builder_PO_Timing_Rule__c
            WHERE Name = 'Lennar Charlotte' LIMIT 1];

        System.assertEquals(true, rule.Business_Days__c);

        // 10 business days from a Monday = 2 calendar weeks
        Date monday = Date.today();
        while (monday.toStartOfWeek().daysBetween(monday) != 1) {
            monday = monday.addDays(1);
        }

        Builder_PO__c po = new Builder_PO__c(
            Builder_Name__c         = 'Lennar',
            Division_Code__c        = 'CLT',
            PO_Release_Date__c      = monday,
            Estimated_Start_Date__c = monday.addDays(14) // 10 business days
        );

        Test.startTest();
        String status = BuilderPoTimingService.calculateTimingStatus(po, rule);
        Test.stopTest();

        System.assertEquals('In Expected Window', status);
    }

    // ── 4. Lennar Greenville maps to Greenville rule ──────────────────────────

    @IsTest
    static void lennarGreenville_findsByNameAndDiv() {
        Test.startTest();
        Builder_PO_Timing_Rule__c rule = BuilderPoTimingService.findTimingRule(
            'Lennar', 'GRVL', null, null);
        Test.stopTest();

        System.assertNotEquals(null, rule);
        System.assertEquals('Lennar Greenville', rule.Division_Builder_Name__c);
    }

    // ── 5. Unknown builder returns Missing Rule ───────────────────────────────

    @IsTest
    static void unknownBuilder_returnsNull_timingStatusIsMissingRule() {
        Builder_PO__c po = new Builder_PO__c(
            Builder_Name__c         = 'Unknown Builder XYZ',
            PO_Release_Date__c      = Date.today(),
            Estimated_Start_Date__c = Date.today().addDays(60)
        );

        Test.startTest();
        Builder_PO_Timing_Rule__c rule = BuilderPoTimingService.findTimingRule(
            'Unknown Builder XYZ', null, null, null);
        String status = BuilderPoTimingService.calculateTimingStatus(po, rule);
        Test.stopTest();

        System.assertEquals(null, rule);
        System.assertEquals('Missing Rule', status);
    }

    // ── 6. Missing dates returns Missing Dates ────────────────────────────────

    @IsTest
    static void missingDates_returnsMissingDates() {
        Builder_PO_Timing_Rule__c rule = [SELECT Id, Min_Days_Before_Start__c,
            Max_Days_Before_Start__c, Business_Days__c FROM Builder_PO_Timing_Rule__c
            WHERE Name = 'DR Horton Charlotte' LIMIT 1];

        Builder_PO__c po = new Builder_PO__c(); // no dates

        Test.startTest();
        String status = BuilderPoTimingService.calculateTimingStatus(po, rule);
        Test.stopTest();

        System.assertEquals('Missing Dates', status);
    }

    // ── 7. In expected window ────────────────────────────────────────────────

    @IsTest
    static void inWindow_returnsInExpectedWindow() {
        Builder_PO_Timing_Rule__c rule = new Builder_PO_Timing_Rule__c(
            Min_Days_Before_Start__c = 30,
            Max_Days_Before_Start__c = 60,
            Business_Days__c = false
        );
        Builder_PO__c po = new Builder_PO__c(
            PO_Release_Date__c      = Date.today(),
            Estimated_Start_Date__c = Date.today().addDays(45)
        );

        Test.startTest();
        String status = BuilderPoTimingService.calculateTimingStatus(po, rule);
        Test.stopTest();

        System.assertEquals('In Expected Window', status);
    }

    // ── 8. Below min days = Late ──────────────────────────────────────────────

    @IsTest
    static void belowMinDays_returnsLate() {
        Builder_PO_Timing_Rule__c rule = new Builder_PO_Timing_Rule__c(
            Min_Days_Before_Start__c = 30,
            Max_Days_Before_Start__c = 60,
            Business_Days__c = false
        );
        Builder_PO__c po = new Builder_PO__c(
            PO_Release_Date__c      = Date.today(),
            Estimated_Start_Date__c = Date.today().addDays(10)
        );

        Test.startTest();
        String status = BuilderPoTimingService.calculateTimingStatus(po, rule);
        Test.stopTest();

        System.assertEquals('Late', status);
    }

    // ── 9. Above max days = Too Early ─────────────────────────────────────────

    @IsTest
    static void aboveMaxDays_returnsTooEarly() {
        Builder_PO_Timing_Rule__c rule = new Builder_PO_Timing_Rule__c(
            Min_Days_Before_Start__c = 30,
            Max_Days_Before_Start__c = 60,
            Business_Days__c = false
        );
        Builder_PO__c po = new Builder_PO__c(
            PO_Release_Date__c      = Date.today(),
            Estimated_Start_Date__c = Date.today().addDays(90)
        );

        Test.startTest();
        String status = BuilderPoTimingService.calculateTimingStatus(po, rule);
        Test.stopTest();

        System.assertEquals('Too Early', status);
    }

    // ── 10. > 90 days -> 90+ Days ──────────────────────────────────────────────

    @IsTest
    static void ninetyPlusDays_returnsBucket() {
        Builder_PO__c po = new Builder_PO__c(
            Pipeline_Stage__c       = '90+ Days',
            Estimated_Start_Date__c = Date.today().addDays(120)
        );

        Test.startTest();
        String stage = BuilderPoTimingService.calculatePipelineStage(po);
        Test.stopTest();

        System.assertEquals('90+ Days', stage);
    }

    // ── 11. 61-90 days -> 60+ Days ────────────────────────────────────────────

    @IsTest
    static void sixtyPlusDays_returnsBucket() {
        Builder_PO__c po = new Builder_PO__c(
            Pipeline_Stage__c       = '60+ Days',
            Estimated_Start_Date__c = Date.today().addDays(75)
        );

        Test.startTest();
        String stage = BuilderPoTimingService.calculatePipelineStage(po);
        Test.stopTest();

        System.assertEquals('60+ Days', stage);
    }

    // ── 12. 31-60 days -> 31 Days ─────────────────────────────────────────────

    @IsTest
    static void thirtyOneDays_returnsBucket() {
        Builder_PO__c po = new Builder_PO__c(
            Pipeline_Stage__c       = '31 Days',
            Estimated_Start_Date__c = Date.today().addDays(45)
        );

        Test.startTest();
        String stage = BuilderPoTimingService.calculatePipelineStage(po);
        Test.stopTest();

        System.assertEquals('31 Days', stage);
    }

    // ── 13. <= 30 days -> Pending Takeoff ─────────────────────────────────────

    @IsTest
    static void thirtyOrFewerDays_returnsPendingTakeoff() {
        Builder_PO__c po = new Builder_PO__c(
            Pipeline_Stage__c       = '31 Days',
            Estimated_Start_Date__c = Date.today().addDays(15)
        );

        Test.startTest();
        String stage = BuilderPoTimingService.calculatePipelineStage(po);
        Test.stopTest();

        System.assertEquals('Pending Takeoff', stage);
    }

    // ── 14. Takeoff approved + 811 cleared -> Clear for Schedule ─────────────

    @IsTest
    static void takeoffApprovedAnd811Cleared_returnsReadyToSchedule() {
        Builder_PO__c po = new Builder_PO__c(
            Pipeline_Stage__c       = 'Takeoff Scheduled',
            Takeoff_Status__c       = 'Approved',
            Eight11_Task_Status__c  = 'Cleared',
            Estimated_Start_Date__c = Date.today().addDays(15)
        );

        Test.startTest();
        String stage = BuilderPoTimingService.calculatePipelineStage(po);
        Test.stopTest();

        System.assertEquals('Clear for Schedule', stage);
    }

    // ── 15. Scheduled job does not move backward into bucket ──────────────────

    @IsTest
    static void scheduledJob_doesNotMoveToBucket() {
        // Record is at Scheduled (order 7) - engine must not move it back
        Builder_PO__c po = new Builder_PO__c(
            Pipeline_Stage__c       = 'Scheduled',
            Schedule_Locked__c      = true,
            Estimated_Start_Date__c = Date.today().addDays(120) // >90 days
        );

        Test.startTest();
        String stage = BuilderPoTimingService.calculatePipelineStage(po);
        Test.stopTest();

        System.assertEquals('Scheduled', stage);
    }

    // ── 16. Paid + QI Complete -> Closed ──────────────────────────────────────

    @IsTest
    static void paidAndQiComplete_returnsClosed() {
        Builder_PO__c po = new Builder_PO__c(
            Pipeline_Stage__c = 'Paid',
            QI_Complete__c    = true,
            Paid__c           = true
        );

        Test.startTest();
        String stage = BuilderPoTimingService.calculatePipelineStage(po);
        Test.stopTest();

        System.assertEquals('Closed', stage);
    }

    @IsTest
    static void recalculateBuilderPOs_populatesRuleTimingAndPipelineFields() {
        Account parentBuilder = new Account(Name = 'DR Horton Test Parent');
        Account division = new Account(Name = 'DR Horton Charlotte Test Division');
        insert new List<Account>{ parentBuilder, division };

        Builder_PO__c po = new Builder_PO__c(
            Builder_Name__c         = 'DR Horton',
            Parent_Account__c      = parentBuilder.Id,
            Division_Account__c    = division.Id,
            Division_Code__c       = 'CLT',
            PO_Release_Date__c     = Date.today(),
            Estimated_Start_Date__c = Date.today().addDays(150)
        );

        Test.startTest();
        List<Builder_PO__c> recalculated = BuilderPoTimingService.recalculateBuilderPOs(
            new List<Builder_PO__c>{ po }
        );
        Test.stopTest();

        System.assertEquals(1, recalculated.size());
        System.assertEquals('Charlotte', recalculated[0].Division_Name__c);
        System.assertNotEquals(null, recalculated[0].Timing_Rule__c);
        System.assertEquals('In Expected Window', recalculated[0].Timing_Status__c);
        System.assertEquals(150, Integer.valueOf(recalculated[0].Days_From_PO_To_Start__c));
        System.assertEquals('90+ Days', recalculated[0].Pipeline_Stage__c);
        System.assertNotEquals(null, recalculated[0].Pipeline_Bucket_Last_Calculated__c);
    }

    @IsTest
    static void syncStageToWorkOrders_handlesStandardWorkOrderQueryPath() {
        Account division = new Account(Name = 'Builder PO Division for WO Sync');
        insert division;

        Builder_PO__c po = new Builder_PO__c(
            Division_Account__c = division.Id,
            Pipeline_Bucket__c = 'Pending Takeoff'
        );
        insert po;

        Test.startTest();
        BuilderPoTimingService.syncStageToWorkOrders(new List<Builder_PO__c>{ po });
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT()
            FROM WorkOrder
            WHERE Builder_PO__c = :po.Id
        ]);
    }

    // ── Division code helpers ─────────────────────────────────────────────────

    @IsTest
    static void normalizeDivisionCode_clt_returnsCharlotte() {
        System.assertEquals('Charlotte', BuilderPoTimingService.normalizeDivisionCode('CLT'));
    }

    @IsTest
    static void normalizeDivisionCode_grvl_returnsGreenville() {
        System.assertEquals('Greenville', BuilderPoTimingService.normalizeDivisionCode('GRVL'));
    }

    @IsTest
    static void normalizeDivisionCode_unknown_returnsNull() {
        System.assertEquals(null, BuilderPoTimingService.normalizeDivisionCode('XXX'));
    }
}