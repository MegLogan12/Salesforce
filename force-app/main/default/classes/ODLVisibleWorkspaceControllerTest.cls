@IsTest
private class ODLVisibleWorkspaceControllerTest {
    @IsTest
    static void testVisibleWorkspacePages() {
        Account builder = new Account(Name = 'ODL Builder');
        insert builder;

        Account homeowner = new Account(Name = 'ODL Homeowner', Type = 'Homeowner');
        insert homeowner;

        Contact contactRow = new Contact(
            LastName = 'Homeowner Contact',
            AccountId = homeowner.Id,
            Email = 'odl-homeowner@example.com'
        );
        insert contactRow;

        Product2 productRow = new Product2(
            Name = 'Standard Grilling Island',
            Family = 'Outdoor Living',
            IsActive = true
        );
        insert productRow;

        Id standardPricebookId = Test.getStandardPricebookId();
        insert new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = productRow.Id,
            UnitPrice = 5000,
            IsActive = true
        );

        Campaign campaignRow = new Campaign(
            Name = 'ODL Voucher Campaign',
            Type = 'Builder-Sponsored Voucher',
            Status = 'In Progress',
            Builder_Account__c = builder.Id,
            Offer_Description__c = 'Standard Grilling Island'
        );
        insert campaignRow;

        Community__c communityRow = new Community__c(
            Name = 'ODL Visible Workspace Community',
            Builder_Account__c = builder.Id,
            Active__c = true,
            BMG_Package_Code__c = 'ODL-VISIBLE'
        );
        insert communityRow;

        Lot__c lotRow = new Lot__c(
            Name = 'ODL-VISIBLE-LOT-001',
            Community__c = communityRow.Id,
            Street_Address__c = '4217 Test Court'
        );
        insert lotRow;

        Opportunity oppRow = new Opportunity(
            Name = 'ODL Opportunity',
            AccountId = homeowner.Id,
            StageName = 'Contract Signed',
            CloseDate = Date.today().addDays(20),
            Type = 'UpgradeMyBackyard',
            BMG_Package__c = 'Retreat',
            Community__c = communityRow.Id,
            Pricebook2Id = standardPricebookId
        );
        insert oppRow;

        Quote quoteRow = new Quote(
            Name = 'ODL Quote',
            OpportunityId = oppRow.Id,
            Pricebook2Id = standardPricebookId,
            Status = 'Draft'
        );
        insert quoteRow;

        Voucher__c voucherRow = new Voucher__c(
            Voucher_Code__c = 'ODL-VISIBLE-001',
            Status__c = 'Applied to Quote',
            Voucher_Type__c = 'Standard Grilling Island',
            Voucher_Entitlement__c = 'Standard Grilling Island',
            Builder_Account__c = builder.Id,
            Community__c = communityRow.Id,
            Lot__c = lotRow.Id,
            Campaign__c = campaignRow.Id,
            Contact__c = contactRow.Id,
            Reserved_Opportunity__c = oppRow.Id,
            Redeemed_Quote__c = quoteRow.Id,
            Eligible_Product__c = productRow.Id,
            Builder_Invoice_Status__c = 'Pending'
        );
        Database.SaveResult voucherInsert = Database.insert(voucherRow, false);
        if (!voucherInsert.isSuccess()) {
            System.assert(false, 'Voucher insert failed: ' + voucherInsert.getErrors()[0].getMessage());
        }

        quoteRow.Voucher__c = voucherRow.Id;
        quoteRow.Voucher_Credit_Amount__c = 5000;
        update quoteRow;

        Design_Review__c designReviewRow = new Design_Review__c(
            Opportunity__c = oppRow.Id,
            Status__c = 'Approved'
        );
        try {
            insert designReviewRow;
        } catch (DmlException ex) {
            System.assert(false, 'Design Review insert failed: ' + ex.getMessage());
        }

        Homeowner_Property__c propertyRow = new Homeowner_Property__c(
            Name = '4217 Test Court',
            Homeowner_Account__c = homeowner.Id,
            Community__c = communityRow.Id,
            Opportunity__c = oppRow.Id
        );
        try {
            insert propertyRow;
        } catch (DmlException ex) {
            System.assert(false, 'Homeowner Property insert failed: ' + ex.getMessage());
        }

        Payment_Milestone__c milestoneRow = new Payment_Milestone__c(
            Opportunity__c = oppRow.Id,
            Quote__c = quoteRow.Id,
            Voucher__c = voucherRow.Id,
            Type__c = 'Deposit',
            Status__c = 'Sent',
            Amount__c = 5000,
            Due_Date__c = Date.today().addDays(5),
            Paid_Date__c = null
        );
        try {
            insert milestoneRow;
        } catch (DmlException ex) {
            System.assert(false, 'Payment Milestone insert failed: ' + ex.getMessage());
        }

        Change_Order__c changeRow = new Change_Order__c(
            Opportunity__c = oppRow.Id,
            Voucher__c = voucherRow.Id
        );
        try {
            insert changeRow;
        } catch (DmlException ex) {
            System.assert(false, 'Change Order insert failed: ' + ex.getMessage());
        }

        WorkOrder workOrderRow = new WorkOrder(
            Subject = 'ODL Work Order',
            Status = 'New',
            AccountId = homeowner.Id,
            RecordTypeId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId(),
            Work_Order_Type__c = 'Production Install',
            Scheduled_Date__c = Date.today().addDays(10)
        );
        try {
            insert workOrderRow;
        } catch (DmlException ex) {
            System.assert(false, 'Work Order insert failed: ' + ex.getMessage());
        }

        Case caseRow = new Case(
            Subject = 'ODL Warranty Case',
            Status = 'New',
            Origin = 'Phone',
            AccountId = homeowner.Id,
            ContactId = contactRow.Id,
            Type = 'Problem'
        );
        try {
            insert caseRow;
        } catch (DmlException ex) {
            System.assert(false, 'Case insert failed: ' + ex.getMessage());
        }

        Warranty_Record__c warrantyRow = new Warranty_Record__c(
            Homeowner_Account__c = homeowner.Id,
            WorkOrder__c = workOrderRow.Id,
            Case__c = caseRow.Id,
            Status__c = 'Open'
        );
        try {
            insert warrantyRow;
        } catch (DmlException ex) {
            System.assert(false, 'Warranty Record insert failed: ' + ex.getMessage());
        }

        insert new Task(
            WhatId = voucherRow.Id,
            Subject = 'Review voucher',
            ActivityDate = Date.today(),
            Status = 'Completed'
        );

        Test.startTest();
        ODLVisibleWorkspaceController.PageData voucherPage = ODLVisibleWorkspaceController.getPageData(voucherRow.Id);
        ODLVisibleWorkspaceController.PageData campaignPage = ODLVisibleWorkspaceController.getPageData(campaignRow.Id);
        ODLVisibleWorkspaceController.PageData quotePage = ODLVisibleWorkspaceController.getPageData(quoteRow.Id);
        ODLVisibleWorkspaceController.PageData workOrderPage = ODLVisibleWorkspaceController.getPageData(workOrderRow.Id);
        ODLVisibleWorkspaceController.PageData designReviewPage = ODLVisibleWorkspaceController.getPageData(designReviewRow.Id);
        ODLVisibleWorkspaceController.PageData propertyPage = ODLVisibleWorkspaceController.getPageData(propertyRow.Id);
        ODLVisibleWorkspaceController.PageData milestonePage = ODLVisibleWorkspaceController.getPageData(milestoneRow.Id);
        ODLVisibleWorkspaceController.PageData changePage = ODLVisibleWorkspaceController.getPageData(changeRow.Id);
        ODLVisibleWorkspaceController.PageData warrantyPage = ODLVisibleWorkspaceController.getPageData(warrantyRow.Id);
        ODLVisibleWorkspaceController.PageData casePage = ODLVisibleWorkspaceController.getPageData(caseRow.Id);
        Test.stopTest();

        System.assertEquals('ODL-VISIBLE-001', voucherPage.title);
        System.assertEquals('Campaign', campaignPage.objectApiName);
        System.assertEquals('Quote', quotePage.objectApiName);
        System.assertEquals('WorkOrder', workOrderPage.objectApiName);
        System.assertEquals('Design_Review__c', designReviewPage.objectApiName);
        System.assertEquals('Homeowner_Property__c', propertyPage.objectApiName);
        System.assertEquals('Payment_Milestone__c', milestonePage.objectApiName);
        System.assertEquals('Change_Order__c', changePage.objectApiName);
        System.assertEquals('Warranty_Record__c', warrantyPage.objectApiName);
        System.assertEquals('Case', casePage.objectApiName);
        System.assert(voucherPage.sections.size() > 0);
        System.assert(campaignPage.sections.size() > 0);
        System.assert(quotePage.sections.size() > 0);
        System.assert(workOrderPage.sections.size() > 0);
        System.assert(designReviewPage.sections.size() > 0);
        System.assert(propertyPage.sections.size() > 0);
        System.assert(milestonePage.sections.size() > 0);
        System.assert(changePage.sections.size() > 0);
        System.assert(warrantyPage.sections.size() > 0);
        System.assert(casePage.sections.size() > 0);
    }
}