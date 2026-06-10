@IsTest
private class LovingBuilderPoValidationControllerTest {
    private static Builder_PO__c makeBuilderPo(String suffix) {
        Account builder = new Account(Name = 'Builder PO Validation ' + suffix);
        insert builder;
        Community__c community = new Community__c(Name = 'Validation Community ' + suffix, Builder_Account__c = builder.Id);
        insert community;
        Lot__c lot = new Lot__c(Name = 'Validation Lot ' + suffix, Community__c = community.Id, Lot_Number__c = suffix, Lot_Status__c = 'Open');
        insert lot;
        Builder_PO__c po = new Builder_PO__c(
            PO_Number__c = 'VAL-' + suffix,
            Builder_Account__c = builder.Id,
            Builder_Division__c = builder.Id,
            Division_Account__c = builder.Id,
            Community__c = community.Id,
            Lot__c = lot.Id,
            Requested_Install_Date__c = Date.today().addDays(45),
            Status__c = 'Pending CS Review'
        );
        insert po;
        return po;
    }

    @IsTest
    static void validationPassesCleanLines() {
        Builder_PO__c po = makeBuilderPo('PASS');
        insert new Builder_PO_Line__c(
            Builder_PO__c = po.Id,
            Line_Description__c = 'Bermuda Sod Install',
            Service_Line__c = 'Landscape Install',
            Quantity_Ordered__c = 100,
            Package_Qty__c = 100,
            Unit_Price__c = 3,
            Price_Book_Price__c = 3
        );

        Test.startTest();
        LovingBuilderPoValidationController.ActionResult result =
            LovingBuilderPoValidationController.revalidateBuilderPo(null, po.Id);
        Test.stopTest();

        po = [SELECT Status__c, Price_Check_Result__c, Qty_Check_Result__c, PO_Validated__c FROM Builder_PO__c WHERE Id = :po.Id];
        System.assertEquals(true, result.passed, result.message);
        System.assertEquals('Verified', po.Status__c);
        System.assertEquals('Pass', po.Price_Check_Result__c);
        System.assertEquals('Pass', po.Qty_Check_Result__c);
        System.assertEquals(true, po.PO_Validated__c);
    }

    @IsTest
    static void validationFlagsMismatchedLinesAndNoLineRows() {
        Builder_PO__c noLinePo = makeBuilderPo('EMPTY');
        LovingBuilderPoValidationController.ActionResult emptyResult =
            LovingBuilderPoValidationController.revalidateBuilderPo(null, noLinePo.Id);
        System.assertEquals(false, emptyResult.passed);
        System.assertEquals('Pending CS Review', emptyResult.newStatus);

        Builder_PO__c mismatchPo = makeBuilderPo('FAIL');
        insert new Builder_PO_Line__c(
            Builder_PO__c = mismatchPo.Id,
            Line_Description__c = 'Irrigation',
            Service_Line__c = 'Irrigation',
            Quantity_Ordered__c = 120,
            Package_Qty__c = 100,
            Unit_Price__c = 5,
            Price_Book_Price__c = 3
        );

        Test.startTest();
        LovingBuilderPoValidationController.ActionResult mismatchResult =
            LovingBuilderPoValidationController.revalidateBuilderPo(null, mismatchPo.Id);
        Test.stopTest();

        mismatchPo = [SELECT Status__c, Price_Check_Result__c, Qty_Check_Result__c, Mismatch_Type__c FROM Builder_PO__c WHERE Id = :mismatchPo.Id];
        System.assertEquals(false, mismatchResult.passed, mismatchResult.message);
        System.assertEquals('Mismatch Review', mismatchPo.Status__c);
        System.assertEquals('Fail', mismatchPo.Price_Check_Result__c);
        System.assertEquals('Fail', mismatchPo.Qty_Check_Result__c);
        System.assertEquals('Price Variance', mismatchPo.Mismatch_Type__c);
    }

    @IsTest
    static void handlesMissingAndPurchaseOrderResolution() {
        LovingBuilderPoValidationController.ActionResult missingResult =
            LovingBuilderPoValidationController.revalidateBuilderPo(null, null);
        System.assertEquals(false, missingResult.passed);

        Builder_PO__c builderPo = makeBuilderPo('MATCH');
        Purchase_Order__c purchaseOrder = new Purchase_Order__c(
            Name = 'PO Resolution Test',
            PO_Number__c = builderPo.PO_Number__c,
            Division_Account__c = builderPo.Builder_Division__c
        );
        insert purchaseOrder;
        insert new Builder_PO_Line__c(
            Builder_PO__c = builderPo.Id,
            Line_Description__c = 'Final Grading',
            Service_Line__c = 'Grading',
            Quantity_Ordered__c = 10,
            Package_Qty__c = 10,
            Unit_Price__c = 2,
            Price_Book_Price__c = 2
        );

        Test.startTest();
        LovingBuilderPoValidationController.ActionResult result =
            LovingBuilderPoValidationController.revalidateBuilderPo(purchaseOrder.Id, null);
        Test.stopTest();

        System.assertEquals(true, result.passed, result.message);
        System.assertEquals('Verified', result.newStatus);
    }

    @IsTest
    static void snapshotReturnsValidationAndLineRows() {
        Builder_PO__c builderPo = makeBuilderPo('SNAP');
        insert new Builder_PO_Line__c(
            Builder_PO__c = builderPo.Id,
            Line_Description__c = 'Landscape Package',
            Service_Line__c = 'Landscape Install',
            Quantity_Ordered__c = 25,
            Package_Qty__c = 25,
            Unit_Price__c = 4,
            Price_Book_Price__c = 4
        );

        LovingBuilderPoValidationController.revalidateBuilderPo(null, builderPo.Id);

        Test.startTest();
        LovingBuilderPoValidationController.ValidationSnapshot snapshot =
            LovingBuilderPoValidationController.getBuilderPoValidationSnapshot(builderPo.Id);
        Test.stopTest();

        System.assertEquals('Pass', snapshot.priceCheckResult);
        System.assertEquals('Pass', snapshot.qtyCheckResult);
        System.assertEquals(true, snapshot.poValidated);
        System.assertEquals(1, snapshot.poLines.size());
        System.assertEquals('Landscape Package', snapshot.poLines[0].description);
        System.assertEquals('Landscape Install', snapshot.poLines[0].workType);
    }
}