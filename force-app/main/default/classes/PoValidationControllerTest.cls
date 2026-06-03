@IsTest(SeeAllData=false)
private class PoValidationControllerTest {

    // PO_Validated__c and Price_Variance_Pct__c are formula fields — cannot set via DML.
    // Division_Account__c is a required lookup on Builder_PO__c — create a test Account first.
    // After insert, re-query to get formula-computed values before passing to buildView.

    private static Id divisionAccountId;

    private static Id getDivisionAccount() {
        if (divisionAccountId == null) {
            Account a = new Account(Name = 'Test Division Account');
            insert a;
            divisionAccountId = a.Id;
        }
        return divisionAccountId;
    }

    private static Builder_PO__c makepo(Decimal poAmt, Decimal pbTotal,
                                        String priceResult, Decimal nfiCount) {
        Builder_PO__c po = new Builder_PO__c(
            Division_Account__c   = getDivisionAccount(),
            PO_Amount__c          = poAmt,
            Price_Book_Total__c   = pbTotal,
            Price_Check_Result__c = priceResult,
            NFI_Count__c          = nfiCount
        );
        insert po;
        return [
            SELECT Id, Name, PO_Number__c, Status__c, PO_Validated__c,
                   PO_Amount__c, Price_Book_Total__c, Price_Check_Result__c,
                   Qty_Check_Result__c, Price_Variance_Pct__c,
                   NFI_Count__c, NFI_Reason__c,
                   Builder_Division__c, Builder_Division__r.Name,
                   Community__c, Community__r.Name
            FROM Builder_PO__c WHERE Id = :po.Id
        ];
    }

    @IsTest
    static void passingPO_priceAndQtyPass() {
        Builder_PO__c po = makepo(50000, 50000, 'Pass', 0);

        Test.startTest();
        PoValidationController.PoView view = PoValidationController.buildView(po);
        Test.stopTest();

        System.assertEquals(2,    view.checks.size(),    'Expected 2 check results');
        System.assertEquals(true, view.checks[0].passed, 'Price check: Pass when Price_Check_Result__c = Pass');
        System.assertEquals(true, view.checks[1].passed, 'Qty check: Pass when NFI_Count__c = 0');
        System.assertEquals('0',  view.checks[1].actual, 'NFI actual should be 0');
    }

    @IsTest
    static void failingPrice_priceCheckFails() {
        Builder_PO__c po = makepo(55000, 50000, 'Fail', 0);

        Test.startTest();
        PoValidationController.PoView view = PoValidationController.buildView(po);
        Test.stopTest();

        System.assertEquals(false, view.checks[0].passed, 'Price check should fail');
        System.assertEquals(true,  view.checks[1].passed, 'Qty check should still pass');
    }

    @IsTest
    static void failingQty_nfiCheckFails() {
        Builder_PO__c po = makepo(50000, 50000, 'Pass', 3);

        Test.startTest();
        PoValidationController.PoView view = PoValidationController.buildView(po);
        Test.stopTest();

        System.assertEquals(true,  view.checks[0].passed, 'Price check should pass');
        System.assertEquals(false, view.checks[1].passed, 'Qty check should fail with NFI > 0');
        System.assertEquals('3',   view.checks[1].actual, 'NFI actual should be 3');
    }
}
