@IsTest(SeeAllData=false)
private class PoValidationControllerTest {

    private static Builder_PO__c makepo(Decimal poAmt, Decimal pbTotal, Decimal variancePct,
                                        String priceResult, Decimal nfiCount) {
        Builder_PO__c po = new Builder_PO__c(
            PO_Amount__c        = poAmt,
            Price_Book_Total__c = pbTotal,
            Price_Variance_Pct__c = variancePct,
            Price_Check_Result__c = priceResult,
            NFI_Count__c        = nfiCount,
            PO_Validated__c     = (priceResult == 'Pass' && nfiCount == 0)
        );
        insert po;
        return po;
    }

    @IsTest
    static void passingPO_bothChecksPass() {
        Builder_PO__c po = makepo(50000, 50000, 0, 'Pass', 0);

        Test.startTest();
        PoValidationController.PoView view = PoValidationController.buildView(po);
        Test.stopTest();

        System.assertEquals(true,  view.poValidated,              'PO should be validated');
        System.assertEquals(2,     view.checks.size(),            'Expected 2 check results');
        System.assertEquals(true,  view.checks[0].passed,         'Price check should pass');
        System.assertEquals(true,  view.checks[1].passed,         'Qty check should pass');
        System.assertEquals('0',   view.checks[1].actual,         'NFI actual should be 0');
    }

    @IsTest
    static void failingPrice_priceCheckFails() {
        Builder_PO__c po = makepo(55000, 50000, 10, 'Fail', 0);

        Test.startTest();
        PoValidationController.PoView view = PoValidationController.buildView(po);
        Test.stopTest();

        System.assertEquals(false, view.checks[0].passed,    'Price check should fail');
        System.assertEquals(10,    view.checks[0].variancePct, 'Variance pct mismatch');
        System.assertEquals(true,  view.checks[1].passed,    'Qty check should still pass');
        System.assertEquals(false, view.poValidated,         'PO should not be validated');
    }

    @IsTest
    static void failingQty_nfiCheckFails() {
        Builder_PO__c po = makepo(50000, 50000, 0, 'Pass', 3);

        Test.startTest();
        PoValidationController.PoView view = PoValidationController.buildView(po);
        Test.stopTest();

        System.assertEquals(true,  view.checks[0].passed,  'Price check should pass');
        System.assertEquals(false, view.checks[1].passed,  'Qty check should fail with NFI > 0');
        System.assertEquals('3',   view.checks[1].actual,  'NFI actual should be 3');
        System.assertEquals(false, view.poValidated,       'PO should not be validated when NFI > 0');
    }
}
