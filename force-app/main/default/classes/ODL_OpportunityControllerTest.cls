@IsTest
private class ODL_OpportunityControllerTest {
    private static Id firstNonBuilderAccountRecordTypeId() {
        List<RecordType> nonBuilderRts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
              AND IsActive = true
              AND DeveloperName NOT IN ('Builder_Parent', 'Builder_Market')
            ORDER BY DeveloperName
            LIMIT 1
        ];
        System.assert(!nonBuilderRts.isEmpty(), 'A non-builder Account record type is required for ODL opportunity controller tests.');
        return nonBuilderRts[0].Id;
    }

    @IsTest
    static void testGetLawnCareRecordSuppressesLawnCareOpenItemsForUmb() {
        Account accountRow = new Account(
            RecordTypeId = firstNonBuilderAccountRecordTypeId(),
            Name = 'UMB Household',
            Type = 'Commercial',
            Phone = '704-555-1000'
        );
        insert accountRow;

        Contact contactRow = new Contact(
            LastName = 'UMB Household',
            Email = 'umb-household@example.com',
            AccountId = accountRow.Id
        );
        insert contactRow;

        Opportunity opp = new Opportunity(
            Name = 'UMB Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            AccountId = accountRow.Id,
            ContactId = contactRow.Id,
            Type = 'UpgradeMyBackyard'
        );
        insert opp;

        insert new Task(
            WhatId = opp.Id,
            Subject = 'UMB follow-up',
            ActivityDate = Date.today().addDays(2),
            Status = 'Completed'
        );

        Test.startTest();
        Map<String, Object> payload = ODL_OpportunityController.getLawnCareRecord(opp.Id);
        Test.stopTest();

        Opportunity resultOpp = (Opportunity) payload.get('opp');
        List<String> openItems = (List<String>) payload.get('openItems');

        System.assertEquals(opp.Id, resultOpp.Id);
        System.assertEquals('UpgradeMyBackyard', resultOpp.Type);
        System.assertEquals(0, openItems.size(), 'Non-Lawn-Care opportunities should not receive Lawn Care missing-data prompts.');
    }

    @IsTest
    static void testGetOpportunityListAndOtherRecordReaders() {
        Account accountRow = new Account(
            RecordTypeId = firstNonBuilderAccountRecordTypeId(),
            Name = 'Controller Reader Household',
            Type = 'Commercial',
            Phone = '704-555-3000'
        );
        insert accountRow;

        Contact contactRow = new Contact(
            LastName = 'Controller Reader',
            Email = 'controller-reader@example.com',
            AccountId = accountRow.Id
        );
        insert contactRow;

        Opportunity umbOpp = new Opportunity(
            Name = 'Controller UMB Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = accountRow.Id,
            ContactId = contactRow.Id,
            Type = 'UpgradeMyBackyard',
            ODL_Path__c = 'UMB'
        );
        insert umbOpp;

        Opportunity customBuildOpp = new Opportunity(
            Name = 'Controller Custom Build Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(12),
            AccountId = accountRow.Id,
            ContactId = contactRow.Id,
            Type = 'Design Build',
            ODL_Path__c = 'Custom Build'
        );
        insert customBuildOpp;

        insert new Task(
            WhatId = umbOpp.Id,
            Subject = 'UMB call',
            ActivityDate = Date.today().addDays(1),
            Status = 'Open'
        );

        insert new Task(
            WhatId = customBuildOpp.Id,
            Subject = 'Custom build follow-up',
            ActivityDate = Date.today().addDays(2),
            Status = 'Open'
        );

        Test.startTest();
        List<Opportunity> umbList = ODL_OpportunityController.getOpportunityList('UMB');
        List<Opportunity> allList = ODL_OpportunityController.getOpportunityList(null);
        Map<String, Object> umbPayload = ODL_OpportunityController.getUmbRecord(umbOpp.Id);
        Map<String, Object> customPayload = ODL_OpportunityController.getCustomBuildRecord(customBuildOpp.Id);
        Test.stopTest();

        System.assertEquals(1, umbList.size(), 'The filtered opportunity list should return only matching ODL path records.');
        System.assert(allList.size() >= 2, 'The unfiltered list should return the inserted opportunities.');
        System.assertEquals(umbOpp.Id, ((Opportunity) umbPayload.get('opp')).Id);
        System.assert(((List<Task>) umbPayload.get('tasks')).size() > 0);
        System.assertEquals(customBuildOpp.Id, ((Opportunity) customPayload.get('opp')).Id);
        System.assert(((List<Task>) customPayload.get('tasks')).size() > 0);
    }

    @IsTest
    static void testGetLawnCareRecordIncludesNotesFilesAndOpenItems() {
        Account accountRow = new Account(
            RecordTypeId = firstNonBuilderAccountRecordTypeId(),
            Name = 'Lawn Care Household',
            Type = 'Commercial',
            Phone = '704-555-2000'
        );
        insert accountRow;

        Contact contactRow = new Contact(
            LastName = 'Lawn Care Household',
            Email = 'lawn-care-household@example.com',
            AccountId = accountRow.Id
        );
        insert contactRow;

        Opportunity opp = new Opportunity(
            Name = 'Lawn Care Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(20),
            AccountId = accountRow.Id,
            ContactId = contactRow.Id,
            Type = 'Lawn Care'
        );
        insert opp;

        insert new Task(
            WhatId = opp.Id,
            Subject = 'Create quote',
            ActivityDate = Date.today().addDays(3),
            Status = 'Not Started'
        );

        ContentVersion fileVersion = new ContentVersion(
            Title = 'Service Contract',
            PathOnClient = 'service-contract.pdf',
            VersionData = Blob.valueOf('file-bytes')
        );
        insert fileVersion;
        fileVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :fileVersion.Id];
        insert new ContentDocumentLink(
            LinkedEntityId = opp.Id,
            ContentDocumentId = fileVersion.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        ContentNote noteRow = new ContentNote(
            Title = 'Consultation Notes',
            Content = Blob.valueOf('Discussed weekly service and billing cadence.')
        );
        insert noteRow;
        insert new ContentDocumentLink(
            LinkedEntityId = opp.Id,
            ContentDocumentId = noteRow.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        Map<String, Object> payload = ODL_OpportunityController.getLawnCareRecord(opp.Id);
        Test.stopTest();

        List<ODL_OpportunityController.RowData> files = (List<ODL_OpportunityController.RowData>) payload.get('files');
        List<ODL_OpportunityController.RowData> notes = (List<ODL_OpportunityController.RowData>) payload.get('notes');
        List<String> openItems = (List<String>) payload.get('openItems');

        System.assertEquals(1, files.size(), 'Regular files should be returned for Lawn Care opportunities.');
        System.assertEquals(1, notes.size(), 'Salesforce notes should be returned separately from files.');
        System.assertEquals('Consultation Notes', notes[0].label);
        System.assert(openItems.contains('No property is linked to this Lawn Care opportunity.'));
        System.assert(openItems.contains('No services are selected on this Lawn Care opportunity.'));
        System.assert(openItems.contains('No billing frequency is captured on this Lawn Care opportunity.'));
        System.assert(openItems.contains('No monthly billing amount is captured on this Lawn Care opportunity.'));
    }
}