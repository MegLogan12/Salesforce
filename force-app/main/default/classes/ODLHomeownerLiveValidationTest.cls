@IsTest(SeeAllData=true)
private class ODLHomeownerLiveValidationTest {
    @IsTest
    static void testHomeownerAndOpportunityControllersOnLiveData() {
        Homeowner_Property__c propertyRow = [
            SELECT Id, Homeowner_Account__c, Opportunity__c
            FROM Homeowner_Property__c
            WHERE Homeowner_Account__c != null
            AND Opportunity__c != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        Test.startTest();
        HomeownerAccountPageController.PageData homeownerPage =
            HomeownerAccountPageController.getPageData(propertyRow.Homeowner_Account__c);
        ODLOpportunityRecordController.PageData opportunityPage =
            ODLOpportunityRecordController.getPageData(propertyRow.Opportunity__c);
        Test.stopTest();

        System.assertEquals(propertyRow.Homeowner_Account__c, homeownerPage.accountRecord.Id);
        System.assertEquals(propertyRow.Opportunity__c, opportunityPage.opportunityRecord.Id);
        System.assertNotEquals(null, homeownerPage.kpis);
        System.assertNotEquals(null, opportunityPage.stagePath);
    }

    @IsTest
    static void testVisibleWorkspacePagesOnLiveData() {
        List<Voucher__c> voucherRows = [
            SELECT Id
            FROM Voucher__c
            WHERE Campaign__c != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        List<Campaign> campaignRows = [
            SELECT Id
            FROM Campaign
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        List<Quote> quoteRows = [
            SELECT Id
            FROM Quote
            WHERE OpportunityId != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        List<WorkOrder> workOrderRows = [
            SELECT Id
            FROM WorkOrder
            WHERE AccountId != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        List<Design_Review__c> designReviewRows = [
            SELECT Id
            FROM Design_Review__c
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        List<Homeowner_Property__c> propertyRows = [
            SELECT Id
            FROM Homeowner_Property__c
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        List<Payment_Milestone__c> milestoneRows = [
            SELECT Id
            FROM Payment_Milestone__c
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        List<Change_Order__c> changeOrderRows = [
            SELECT Id
            FROM Change_Order__c
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        List<Warranty_Record__c> warrantyRows = [
            SELECT Id
            FROM Warranty_Record__c
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        List<Case> caseRows = [
            SELECT Id
            FROM Case
            WHERE AccountId != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        Test.startTest();
        List<ODLVisibleWorkspaceController.PageData> pages = new List<ODLVisibleWorkspaceController.PageData>();
        if (!voucherRows.isEmpty()) {
            pages.add(ODLVisibleWorkspaceController.getPageData(voucherRows[0].Id));
        }
        if (!campaignRows.isEmpty()) {
            pages.add(ODLVisibleWorkspaceController.getPageData(campaignRows[0].Id));
        }
        if (!quoteRows.isEmpty()) {
            pages.add(ODLVisibleWorkspaceController.getPageData(quoteRows[0].Id));
        }
        if (!workOrderRows.isEmpty()) {
            pages.add(ODLVisibleWorkspaceController.getPageData(workOrderRows[0].Id));
        }
        if (!designReviewRows.isEmpty()) {
            pages.add(ODLVisibleWorkspaceController.getPageData(designReviewRows[0].Id));
        }
        if (!propertyRows.isEmpty()) {
            pages.add(ODLVisibleWorkspaceController.getPageData(propertyRows[0].Id));
        }
        if (!milestoneRows.isEmpty()) {
            pages.add(ODLVisibleWorkspaceController.getPageData(milestoneRows[0].Id));
        }
        if (!changeOrderRows.isEmpty()) {
            pages.add(ODLVisibleWorkspaceController.getPageData(changeOrderRows[0].Id));
        }
        if (!warrantyRows.isEmpty()) {
            pages.add(ODLVisibleWorkspaceController.getPageData(warrantyRows[0].Id));
        }
        if (!caseRows.isEmpty()) {
            pages.add(ODLVisibleWorkspaceController.getPageData(caseRows[0].Id));
        }
        Test.stopTest();

        Integer pageIndex = 0;
        if (!voucherRows.isEmpty()) {
            System.assertEquals('Voucher__c', pages[pageIndex].objectApiName);
            pageIndex++;
        }
        if (!campaignRows.isEmpty()) {
            System.assertEquals('Campaign', pages[pageIndex++].objectApiName);
        }
        if (!quoteRows.isEmpty()) {
            System.assertEquals('Quote', pages[pageIndex++].objectApiName);
        }
        if (!workOrderRows.isEmpty()) {
            System.assertEquals('WorkOrder', pages[pageIndex++].objectApiName);
        }
        if (!designReviewRows.isEmpty()) {
            System.assertEquals('Design_Review__c', pages[pageIndex++].objectApiName);
        }
        if (!propertyRows.isEmpty()) {
            System.assertEquals('Homeowner_Property__c', pages[pageIndex++].objectApiName);
        }
        if (!milestoneRows.isEmpty()) {
            System.assertEquals('Payment_Milestone__c', pages[pageIndex++].objectApiName);
        }
        if (!changeOrderRows.isEmpty()) {
            System.assertEquals('Change_Order__c', pages[pageIndex++].objectApiName);
        }
        if (!warrantyRows.isEmpty()) {
            System.assertEquals('Warranty_Record__c', pages[pageIndex++].objectApiName);
        }
        if (!caseRows.isEmpty()) {
            System.assertEquals('Case', pages[pageIndex].objectApiName);
        }
    }
}