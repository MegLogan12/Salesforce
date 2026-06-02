@IsTest
private class BuilderPricingControllerTest {

    private static Account makeAccount() {
        Account a = new Account(Name = 'Test Builder');
        insert a;
        return a;
    }

    private static Builder_Pricing_Book__c makeBook(Id acctId) {
        Builder_Pricing_Book__c b = new Builder_Pricing_Book__c(
            Name               = 'Test Book',
            Builder_Account__c = acctId,
            Status__c          = 'Draft',
            Effective_Date__c  = Date.today()
        );
        insert b;
        return b;
    }

    @IsTest
    static void testGetPricingBooksEmpty() {
        Account a = makeAccount();
        Test.startTest();
        List<BuilderPricingController.PricingBookDTO> books =
            BuilderPricingController.getPricingBooks(a.Id);
        Test.stopTest();
        System.assertEquals(0, books.size());
    }

    @IsTest
    static void testCreateAndGetBook() {
        Account a = makeAccount();
        Test.startTest();
        String bookId = BuilderPricingController.createPricingBook(a.Id, 'DR Horton 2026', String.valueOf(Date.today()));
        List<BuilderPricingController.PricingBookDTO> books =
            BuilderPricingController.getPricingBooks(a.Id);
        Test.stopTest();
        System.assertNotEquals(null, bookId);
        System.assertEquals(1, books.size());
        System.assertEquals('DR Horton 2026', books[0].name);
    }

    @IsTest
    static void testActivateBook() {
        Account a = makeAccount();
        Builder_Pricing_Book__c b = makeBook(a.Id);
        Test.startTest();
        BuilderPricingController.activatePricingBook(b.Id);
        BuilderPricingController.PricingBookDTO dto =
            BuilderPricingController.getActiveBook(a.Id);
        Test.stopTest();
        System.assertNotEquals(null, dto);
        System.assertEquals('Active', dto.status);
        System.assert(dto.isActive, 'Expected isActive to be true');
    }

    @IsTest
    static void testDeactivateBook() {
        Account a = makeAccount();
        Builder_Pricing_Book__c b = makeBook(a.Id);
        b.Status__c = 'Active';
        update b;
        Test.startTest();
        BuilderPricingController.deactivatePricingBook(b.Id);
        BuilderPricingController.PricingBookDTO dto =
            BuilderPricingController.getActiveBook(a.Id);
        Test.stopTest();
        System.assertEquals(null, dto);
    }

    @IsTest
    static void testSaveAndDeleteLine() {
        Account a = makeAccount();
        Builder_Pricing_Book__c b = makeBook(a.Id);
        Test.startTest();
        String lineId = BuilderPricingController.savePricingLine(
            b.Id, null, 'Sod Install', 'PRD-001', 2.50, 'sq ft', String.valueOf(Date.today())
        );
        List<BuilderPricingController.PricingBookDTO> books =
            BuilderPricingController.getPricingBooks(a.Id);
        System.assertEquals(1, books[0].lines.size());
        System.assertEquals('Sod Install', books[0].lines[0].itemDescription);

        BuilderPricingController.deletePricingLine(lineId);
        books = BuilderPricingController.getPricingBooks(a.Id);
        Test.stopTest();
        System.assertEquals(0, books[0].lines.size());
    }

    @IsTest
    static void testSaveBulkLines() {
        Account a = makeAccount();
        Builder_Pricing_Book__c b = makeBook(a.Id);
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'itemDescription' => 'Mulch',
                'bmgCode'         => 'MLH-001',
                'unit'            => 'cubic yd',
                'unitPrice'       => 45.00
            },
            new Map<String, Object>{
                'itemDescription' => 'Edging',
                'bmgCode'         => 'EDG-001',
                'unit'            => 'linear ft',
                'unitPrice'       => 1.25
            }
        };
        Test.startTest();
        BuilderPricingController.saveBulkLines(b.Id, rows);
        List<BuilderPricingController.PricingBookDTO> books =
            BuilderPricingController.getPricingBooks(a.Id);
        Test.stopTest();
        System.assertEquals(2, books[0].lines.size());
    }

    @IsTest
    static void testGetActiveBooksNullAccount() {
        Test.startTest();
        List<BuilderPricingController.PricingBookDTO> books =
            BuilderPricingController.getPricingBooks(null);
        BuilderPricingController.PricingBookDTO active =
            BuilderPricingController.getActiveBook(null);
        Test.stopTest();
        System.assertEquals(0, books.size());
        System.assertEquals(null, active);
    }

    @IsTest
    static void testCreateBookNullAccount() {
        Test.startTest();
        try {
            BuilderPricingController.createPricingBook(null, 'Book', null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveLineBlankDescription() {
        Account a = makeAccount();
        Builder_Pricing_Book__c b = makeBook(a.Id);
        Test.startTest();
        try {
            BuilderPricingController.savePricingLine(b.Id, null, '', null, 0, null, null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}