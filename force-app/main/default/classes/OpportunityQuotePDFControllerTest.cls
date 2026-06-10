@isTest
private class OpportunityQuotePDFControllerTest {
    
    @testSetup
    static void setup() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Customer',
            BillingStreet = '123 Main St',
            BillingCity = 'Anytown',
            BillingState = 'CA',
            BillingPostalCode = '12345'
        );
        insert testAccount;
        
        // Create test Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Backyard Project',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Timeline__c = 'ASAP (0-2 months)',
            Budget__c = 'Under $5,000',
            Desired_Backyard_Outcome__c = 'Create an outdoor entertainment space',
            Selected_Requirements__c = 'Paver Patio;Fire Pit;Grilling Island',
            Extra_Enhancements__c = 'Custom stone work and lighting',
            Price_Range_Min__c = 30000,
            Price_Range_Max__c = 45000,
            Monthly_Estimate__c = 500,
            Financing_Option__c = 'Financing Requested'
        );
        insert testOpp;
    }
    
    @isTest
    static void testPDFControllerInitialization() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
        OpportunityQuotePDFController controller = new OpportunityQuotePDFController(stdController);
        Test.stopTest();
        
        System.assertNotEquals(null, controller, 'Controller should be initialized');
    }
    
    @isTest
    static void testGetFormattedFeatures() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
        OpportunityQuotePDFController controller = new OpportunityQuotePDFController(stdController);
        String formattedFeatures = controller.getFormattedFeatures();
        Test.stopTest();
        
        System.assert(formattedFeatures.contains('<ul'), 'Should contain HTML list');
        System.assert(formattedFeatures.contains('Paver Patio'), 'Should contain feature name');
    }
    
    @isTest
    static void testGenerateAndAttachQuotePDF() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        String contentDocumentId = OpportunityQuotePDFController.generateAndAttachQuotePDF(testOpp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, contentDocumentId, 'Content Document should be created');
        
        // Verify ContentVersion was created
        List<ContentVersion> cvList = [
            SELECT Id, Title 
            FROM ContentVersion 
            WHERE FirstPublishLocationId = :testOpp.Id
        ];
        System.assertEquals(1, cvList.size(), 'One ContentVersion should be created');
        System.assert(cvList[0].Title.startsWith('Quote_'), 'File name should start with Quote_');
    }
    
    @isTest
    static void testGenerateAndAttachQuotePDFError() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OpportunityQuotePDFController.generateAndAttachQuotePDF(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw AuraHandledException for null ID');
    }
    
    @isTest
    static void testPDFPageRendering() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        PageReference pageRef = new PageReference('/apex/OpportunityQuotePDF');
        pageRef.getParameters().put('id', testOpp.Id);
        Test.setCurrentPage(pageRef);
        
        ApexPages.StandardController stdController = new ApexPages.StandardController(testOpp);
        OpportunityQuotePDFController controller = new OpportunityQuotePDFController(stdController);
        Test.stopTest();
        
        System.assertNotEquals(null, controller, 'Controller should render successfully');
    }
}