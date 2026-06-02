@IsTest
private class UMBRedesignServiceTest {

    private static final String PNG_B64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

    private class GeminiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"candidates":[{"content":{"parts":[{"inlineData":{"data":"' + PNG_B64 + '"}}]}}]}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'LOVING_UMB_Design_Options' LIMIT 1];
        if ([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :ps.Id] == 0) {
            insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = ps.Id);
        }

        Opportunity opp = new Opportunity(Name = 'Redesign Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        insert opp;

        insert new UMB_Design_Option__c(Name = 'Entertainer', Opportunity__c = opp.Id,
            Tier__c = 'Entertainer', Sort_Order__c = 2);

        // Real-style catalog: multiple ai-render-eligible products per category in the Entertainer tier.
        Id pbId = Test.getStandardPricebookId();
        List<Product2> prods = new List<Product2>();
        Map<String, Integer> cats = new Map<String, Integer>{
            'Hardscape' => 2, 'Outdoor Living' => 2, 'Planting' => 3, 'Lighting' => 2
        };
        for (String cat : cats.keySet()) {
            for (Integer i = 0; i < cats.get(cat); i++) {
                prods.add(new Product2(Name = cat + ' Product ' + i, IsActive = true,
                    Family = cat, ProductCode = cat + i));
            }
        }
        insert prods;
        for (Product2 p : prods) {
            p.put('final_package_tier__c', 'Entertainer');
            p.put('category__c', p.Family);
            p.put('ai_render_eligible__c', true);
        }
        update prods;

        List<PricebookEntry> pbes = new List<PricebookEntry>();
        for (Product2 p : prods) {
            pbes.add(new PricebookEntry(Pricebook2Id = pbId, Product2Id = p.Id, UnitPrice = 1000, IsActive = true));
        }
        insert pbes;
    }

    @IsTest
    static void testRedesignPopulatesRealProducts() {
        UMB_Design_Option__c opt = [SELECT Id FROM UMB_Design_Option__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new GeminiMock());
        Test.startTest();
        UMBRedesignService.redesign(opt.Id);
        Test.stopTest();

        List<UMB_Design_Element__c> els = [
            SELECT Category__c, Product__c, Placement__c, Unit_Price__c
            FROM UMB_Design_Element__c WHERE Design_Option__c = :opt.Id
        ];
        System.assert(!els.isEmpty(), 'Redesign should create real product elements');
        for (UMB_Design_Element__c e : els) {
            System.assertNotEquals(null, e.Product__c, 'Each element ties to a real Product2');
        }
        UMB_Design_Option__c after = [SELECT Price__c FROM UMB_Design_Option__c WHERE Id = :opt.Id];
        System.assert(after.Price__c > 0, 'Price should be summed from real catalog prices');
    }

    @IsTest
    static void testHeartedSurvivesRedesign() {
        UMB_Design_Option__c opt = [SELECT Id FROM UMB_Design_Option__c LIMIT 1];
        Product2 grill = [SELECT Id, Name FROM Product2 WHERE category__c = 'Outdoor Living' LIMIT 1];
        UMB_Design_Element__c hearted = new UMB_Design_Element__c(
            Design_Option__c = opt.Id, Product__c = grill.Id, Category__c = 'Outdoor Living',
            Name = grill.Name, Is_Hearted__c = true, Placement__c = 'at the edge of the patio', Unit_Price__c = 1000);
        insert hearted;

        Test.setMock(HttpCalloutMock.class, new GeminiMock());
        Test.startTest();
        UMBRedesignService.redesign(opt.Id);
        Test.stopTest();

        List<UMB_Design_Element__c> survivors = [
            SELECT Id FROM UMB_Design_Element__c
            WHERE Design_Option__c = :opt.Id AND Product__c = :grill.Id AND Is_Hearted__c = true
        ];
        System.assertEquals(1, survivors.size(), 'Hearted grill should survive the redesign');
    }

    @IsTest
    static void testToggleHeart() {
        UMB_Design_Option__c opt = [SELECT Id FROM UMB_Design_Option__c LIMIT 1];
        Product2 p = [SELECT Id, Name FROM Product2 LIMIT 1];
        UMB_Design_Element__c el = new UMB_Design_Element__c(
            Design_Option__c = opt.Id, Product__c = p.Id, Category__c = 'Hardscape', Name = p.Name);
        insert el;
        Test.startTest();
        UMBRedesignService.toggleHeart(el.Id, true);
        Test.stopTest();
        System.assertEquals(true, [SELECT Is_Hearted__c FROM UMB_Design_Element__c WHERE Id = :el.Id].Is_Hearted__c);
    }
}