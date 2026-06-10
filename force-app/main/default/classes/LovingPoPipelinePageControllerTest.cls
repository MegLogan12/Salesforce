@isTest
private class LovingPoPipelinePageControllerTest {
    @isTest
    static void rendersStageColumnsAndCards() {
        Account builder = new Account(Name = 'VF Test Builder');
        insert builder;
        Account division = new Account(Name = 'VF Test Division');
        insert division;

        Purchase_Order__c po = new Purchase_Order__c(
            Builder_Account__c = builder.Id,
            Division_Account__c = division.Id,
            Community_Name__c = 'VF Community',
            Total_Amount__c = 5000,
            Status__c = 'Pending CS Review',
            Pipeline_Stage__c = 'CSM Review',
            Package_BMG_Status__c = 'Missing Package',
            Requested_Install_Date__c = Date.today().addDays(45)
        );
        insert po;

        Test.startTest();
        LovingPoPipelinePageController controller = new LovingPoPipelinePageController();
        Test.stopTest();

        System.assertEquals(9, controller.stages.size(), 'Should render all launch pipeline stages');
        System.assertEquals(1, controller.openCount, 'Should count the test PO');
        System.assertEquals(1, controller.reviewCount, 'CSM Review stage should count the test PO');
        System.assertEquals('$5.0k', controller.totalValueLabel, 'Total value should be formatted');
    }
}