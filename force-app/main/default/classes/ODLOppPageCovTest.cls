@IsTest(SeeAllData=true)
private class ODLOppPageCovTest {
    @IsTest
    static void testUpgradeAndLiveOpportunityPaths() {
        Account accountRow = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Opportunity Test',
            PersonEmail = 'opp@test.example',
            Type = 'Home Owner'
        );
        insert accountRow;

        Opportunity opp = new Opportunity(
            Name = 'Voucher Backyard Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(20),
            AccountId = accountRow.Id,
            ContactId = accountRow.PersonContactId,
            Type = 'UpgradeMyBackyard',
            BMG_Package__c = 'Entertainer'
        );
        insert opp;

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Call homeowner',
            ActivityDate = Date.today().addDays(2),
            Status = 'Open'
        );

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Email proposal',
            ActivityDate = Date.today(),
            Status = 'Completed',
            TaskSubtype = 'Email',
            Description = 'Proposal sent.'
        );

        insert new EmailMessage(
            Subject = 'Proposal ready',
            FromAddress = 'sales@thelovingcompanies.com',
            ToAddress = 'opp@test.example',
            TextBody = 'Proposal ready for review.',
            MessageDate = System.now(),
            Status = '1',
            Incoming = false,
            RelatedToId = opp.Id
        );

        insert new Design_Review__c(
            Opportunity__c = opp.Id,
            Status__c = 'Approved'
        );

        insert new Payment_Milestone__c(
            Opportunity__c = opp.Id,
            Type__c = 'Deposit',
            Status__c = 'Sent',
            Amount__c = 15000,
            Due_Date__c = Date.today().addDays(5)
        );

        insert new Homeowner_Property__c(
            Name = '4217 Opportunity Court',
            Homeowner_Account__c = accountRow.Id,
            Opportunity__c = opp.Id
        );

        ContentVersion contentVersion = new ContentVersion(
            Title = 'Opportunity Photo',
            PathOnClient = 'opportunity-photo.jpg',
            VersionData = Blob.valueOf('file-bytes')
        );
        insert contentVersion;
        contentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id];
        insert new ContentDocumentLink(
            LinkedEntityId = opp.Id,
            ContentDocumentId = contentVersion.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        List<Opportunity> liveOpps = [
            SELECT Id
            FROM Opportunity
            WHERE Name = 'NextDay ODL Opp'
            LIMIT 1
        ];

        Test.startTest();
        ODLOpportunityRecordController.PageData testData = ODLOpportunityRecordController.getPageData(opp.Id);
        Test.stopTest();

        System.assertEquals(opp.Id, testData.opportunityRecord.Id);
        System.assertEquals('Upgrade My Backyard', testData.projectPath);
        System.assert(testData.stagePath.size() > 0);
        System.assertEquals('Sent Email - Initial', testData.lastAction);
        System.assertEquals('Call homeowner', testData.nextFollowUpSubject);
        System.assertEquals(1, testData.designReviews.size());
        System.assertEquals(1, testData.paymentMilestones.size());
        System.assertEquals(1, testData.files.size());
        System.assertNotEquals(null, testData.propertyRecord);
        System.assert(testData.interactions.size() >= 1);

        if (!liveOpps.isEmpty()) {
            ODLOpportunityRecordController.PageData liveData = ODLOpportunityRecordController.getPageData(liveOpps[0].Id);
            System.assertEquals(liveOpps[0].Id, liveData.opportunityRecord.Id);
            System.assertNotEquals(null, liveData.accountName);
        }
    }
}