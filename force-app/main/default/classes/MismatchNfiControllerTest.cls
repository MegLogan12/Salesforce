@IsTest(SeeAllData=false)
private class MismatchNfiControllerTest {

    private static Account getDivisionAccount() {
        Account a = new Account(Name = 'Test Division Co');
        insert a;
        return a;
    }

    @IsTest
    static void getMismatchSummary_countsCorrect() {
        Account divAcct = getDivisionAccount();

        Builder_PO__c priceFail = new Builder_PO__c(
            Division_Account__c   = divAcct.Id,
            Price_Check_Result__c = 'Fail',
            NFI_Count__c          = 0,
            PO_Amount__c          = 10000,
            Price_Book_Total__c   = 12000,
            Status__c             = 'Pending Review'
        );
        Builder_PO__c qtyFail = new Builder_PO__c(
            Division_Account__c   = divAcct.Id,
            Price_Check_Result__c = 'Pass',
            NFI_Count__c          = 3,
            NFI_Reason__c         = 'Missing items on manifest',
            PO_Amount__c          = 8000,
            Price_Book_Total__c   = 8000,
            Status__c             = 'Pending Review'
        );
        Builder_PO__c bothFail = new Builder_PO__c(
            Division_Account__c   = divAcct.Id,
            Price_Check_Result__c = 'Fail',
            NFI_Count__c          = 2,
            NFI_Reason__c         = 'Price and qty both off',
            PO_Amount__c          = 5000,
            Price_Book_Total__c   = 7000,
            Status__c             = 'Pending Review'
        );
        insert new List<Builder_PO__c>{ priceFail, qtyFail, bothFail };

        List<Builder_PO__c> pos = [
            SELECT Id, Builder_Account__c, Builder_Account__r.Name,
                   Community__c, Community__r.Name, Division_Account__c,
                   Division_Account__r.Name, PO_Amount__c, Price_Book_Total__c,
                   Price_Check_Result__c, Qty_Check_Result__c, NFI_Count__c,
                   NFI_Reason__c, Status__c, CreatedDate
            FROM Builder_PO__c
            WHERE Division_Account__c = :divAcct.Id
        ];

        Test.startTest();
        MismatchNfiController.MismatchView view = MismatchNfiController.buildView(pos);
        Test.stopTest();

        System.assertEquals(3, view.totalOpen,  'totalOpen should be 3');
        System.assertEquals(1, view.priceCount, 'priceCount should be 1');
        System.assertEquals(1, view.qtyCount,   'qtyCount should be 1');
        System.assertEquals(1, view.bothCount,  'bothCount should be 1');
        System.assertEquals(3, view.rows.size(), 'rows list should have 3 entries');
    }

    @IsTest
    static void priceFailRow_typeIsPrice() {
        Account divAcct = getDivisionAccount();

        Builder_PO__c priceFail = new Builder_PO__c(
            Division_Account__c   = divAcct.Id,
            Price_Check_Result__c = 'Fail',
            NFI_Count__c          = 0,
            PO_Amount__c          = 10000,
            Price_Book_Total__c   = 12000,
            Status__c             = 'Pending Review'
        );
        insert priceFail;

        Builder_PO__c po = [
            SELECT Id, Builder_Account__c, Builder_Account__r.Name,
                   Community__c, Community__r.Name, Division_Account__c,
                   Division_Account__r.Name, PO_Amount__c, Price_Book_Total__c,
                   Price_Check_Result__c, Qty_Check_Result__c, NFI_Count__c,
                   NFI_Reason__c, Status__c, CreatedDate
            FROM Builder_PO__c
            WHERE Id = :priceFail.Id
            LIMIT 1
        ];

        Test.startTest();
        MismatchNfiController.MismatchView view =
            MismatchNfiController.buildView(new List<Builder_PO__c>{ po });
        Test.stopTest();

        System.assertEquals(1, view.rows.size(), 'Should return 1 row');
        MismatchNfiController.PoRow row = view.rows[0];
        System.assertEquals('Price', row.mismatchType, 'mismatchType should be Price');
        System.assertEquals(10000, row.poAmount, 'poAmount should match');
    }

    @IsTest
    static void nfiFailRow_typeIsQty() {
        Account divAcct = getDivisionAccount();

        Builder_PO__c qtyFail = new Builder_PO__c(
            Division_Account__c   = divAcct.Id,
            Price_Check_Result__c = 'Pass',
            NFI_Count__c          = 3,
            NFI_Reason__c         = 'Missing items on manifest',
            PO_Amount__c          = 8000,
            Price_Book_Total__c   = 8000,
            Status__c             = 'Pending Review'
        );
        insert qtyFail;

        Builder_PO__c po = [
            SELECT Id, Builder_Account__c, Builder_Account__r.Name,
                   Community__c, Community__r.Name, Division_Account__c,
                   Division_Account__r.Name, PO_Amount__c, Price_Book_Total__c,
                   Price_Check_Result__c, Qty_Check_Result__c, NFI_Count__c,
                   NFI_Reason__c, Status__c, CreatedDate
            FROM Builder_PO__c
            WHERE Id = :qtyFail.Id
            LIMIT 1
        ];

        Test.startTest();
        MismatchNfiController.MismatchView view =
            MismatchNfiController.buildView(new List<Builder_PO__c>{ po });
        Test.stopTest();

        System.assertEquals(1, view.rows.size(), 'Should return 1 row');
        MismatchNfiController.PoRow row = view.rows[0];
        System.assertEquals('Qty', row.mismatchType, 'mismatchType should be Qty');
        System.assertEquals(3, row.nfiCount, 'nfiCount should be 3');
        System.assertEquals('Missing items on manifest', row.nfiReason, 'nfiReason should match');
    }
}
