@IsTest
private class McLovinEmployeeAgentControllerTest {

    @IsTest
    static void analyzesAndCreatesBuilderAccountProfile() {
        Account builderParent = new Account(
            Name = 'Lennar Homes',
            RecordTypeId = RecordTypeHelper.getAccountRT('Builder_Parent')
        );
        insert builderParent;
        Account builderAccount = new Account(
            Name = 'Lennar Homes – Charlotte',
            ParentId = builderParent.Id,
            RecordTypeId = RecordTypeHelper.getAccountRT('Builder_Market'),
            Type = 'Builder Market'
        );
        insert builderAccount;

        Community__c community = new Community__c(
            Name = 'MillBridge',
            Builder_Account__c = builderAccount.Id
        );
        insert community;

        String intakeText =
            'Scope of Work\n' +
            'Division: The Loving Group - Charlotte\n' +
            'Lennar Homes Charlotte\n' +
            'Contact: John Smith\n' +
            'john.smith@lennar.com\n' +
            '(704) 555-1111\n' +
            '2409 Abundance Lane\n' +
            'Waxhaw, NC 28173\n' +
            'Community: MillBridge\n' +
            'Lot 45\n';

        Test.startTest();
        Id draftId = McLovinEmployeeAgentController.startDraft('Document', intakeText);
        McLovinEmployeeIntakeService.AnalysisResult analysis =
            McLovinEmployeeAgentController.analyzeRequest(draftId, 'Document', intakeText);
        McLovinEmployeeIntakeService.SaveResult saveResult =
            McLovinEmployeeAgentController.saveRequest(draftId, '{}', true);
        Test.stopTest();

        System.assertEquals('Builder Scope', analysis.classification);
        System.assertEquals('Account', analysis.suggestedPrimaryObject);
        System.assertEquals('Use Existing And Add New Account', analysis.suggestedAction);
        System.assertEquals(builderAccount.Id, saveResult.primaryRecordId);
        System.assertEquals('Saved', saveResult.status);

        Account acct = [
            SELECT Id, Name, Type
            FROM Account
            WHERE Id = :saveResult.primaryRecordId
        ];
        System.assertEquals('Lennar Homes – Charlotte', acct.Name);
        System.assertEquals('Builder Market', acct.Type);
    }

    @IsTest(SeeAllData=true)
    static void analyzesAndCreatesServiceCase() {
        Group intakeQueue = [
            SELECT Id, DeveloperName
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = 'Customer_Success_Intake'
            LIMIT 1
        ];

        String intakeText =
            'Customer Care Service Issue\n' +
            'Routing Lane: Customer Care Closeout\n' +
            'Requested By: Jane Doe\n' +
            'jane.doe@example.com\n' +
            '704-555-2323\n' +
            '101 Main Street\n' +
            'Charlotte, NC 28202\n' +
            'The irrigation zone is not turning on.\n';

        Test.startTest();
        Id draftId = McLovinEmployeeAgentController.startDraft('Email', intakeText);
        McLovinEmployeeIntakeService.AnalysisResult analysis =
            McLovinEmployeeAgentController.analyzeRequest(draftId, 'Email', intakeText);
        McLovinEmployeeIntakeService.SaveResult saveResult =
            McLovinEmployeeAgentController.saveRequest(draftId, '{"caseSubject":"Irrigation zone issue"}', true);
        Test.stopTest();

        System.assertEquals('Service Case', analysis.classification);
        System.assertEquals('Case', analysis.suggestedPrimaryObject);
        Case c = [SELECT Id, Subject, Origin, OwnerId FROM Case WHERE Id = :saveResult.primaryRecordId];
        System.assertEquals('Irrigation zone issue', c.Subject);
        System.assertEquals('Web', c.Origin);
        System.assertEquals(intakeQueue.Id, c.OwnerId);
    }

    @IsTest
    static void invocableActionsRun() {
        String intakeText =
            'Jane Doe\n' +
            'jane.doe@example.com\n' +
            '123 Market Street\n' +
            'Charlotte, NC 28202\n' +
            'Need a backyard consultation.\n';

        Id draftId = McLovinEmployeeAgentController.startDraft('Text', intakeText);

        McLovinEmployeeAgentActions.AnalyzeInput analyzeInput = new McLovinEmployeeAgentActions.AnalyzeInput();
        analyzeInput.requestId = draftId;
        analyzeInput.sourceType = 'Text';
        analyzeInput.intakeText = intakeText;

        Test.startTest();
        List<McLovinEmployeeAgentActions.AnalyzeOutput> analyzeOutputs =
            McLovinEmployeeAgentActions.analyze(new List<McLovinEmployeeAgentActions.AnalyzeInput>{ analyzeInput });

        McLovinEmployeeAgentSaveAction.SaveInput saveInput = new McLovinEmployeeAgentSaveAction.SaveInput();
        saveInput.requestId = draftId;
        saveInput.overridesJson = '{"lastName":"Doe","householdName":"Doe Household","opportunityName":"Doe Household - Intake"}';
        saveInput.confirmed = true;
        List<McLovinEmployeeAgentSaveAction.SaveOutput> saveOutputs =
            McLovinEmployeeAgentSaveAction.save(new List<McLovinEmployeeAgentSaveAction.SaveInput>{ saveInput });
        Test.stopTest();

        System.assertEquals(1, analyzeOutputs.size());
        System.assertEquals(1, saveOutputs.size());
        System.assertEquals('Saved', saveOutputs[0].status);
        System.assertNotEquals(null, saveOutputs[0].primaryRecordId);
    }

    @IsTest
    static void analyzesSpreadsheetBuilderRowsWithoutUsingLovingDivision() {
        Account builderParent = new Account(
            Name = 'DR Horton',
            RecordTypeId = RecordTypeHelper.getAccountRT('Builder_Parent')
        );
        insert builderParent;
        Account builderAccount = new Account(
            Name = 'DR Horton – Asheville',
            ParentId = builderParent.Id,
            RecordTypeId = RecordTypeHelper.getAccountRT('Builder_Market'),
            Type = 'Builder Market'
        );
        insert builderAccount;

        Community__c community = new Community__c(
            Name = 'Rydele Heights',
            Builder_Account__c = builderAccount.Id
        );
        insert community;

        String intakeText =
            'Division: The Loving Group - Asheville\n' +
            'Customer: DR Horton Homes Asheville - Rydele Heights\n' +
            'Address: 627 Country Oak Dr\n' +
            'City: Asheville, NC 28804\n' +
            'WO Type: Builder Services\n' +
            'Lot 40\n' +
            'Community: Rydele Heights\n';

        Test.startTest();
        Id draftId = McLovinEmployeeAgentController.startDraft('Spreadsheet', intakeText);
        McLovinEmployeeIntakeService.AnalysisResult analysis =
            McLovinEmployeeAgentController.analyzeRequest(draftId, 'Spreadsheet', intakeText);
        Test.stopTest();

        System.assertEquals('Spreadsheet Batch', analysis.classification);
        System.assertEquals('DR Horton – Asheville', (String) analysis.extractedData.get('normalizedBuilderAccountName'));
        System.assertEquals('Rydele Heights', (String) analysis.extractedData.get('communityName'));
        System.assertEquals('The Loving Group - Asheville', (String) analysis.extractedData.get('divisionName'));
        for (McLovinEmployeeIntakeService.RecordCandidate candidate : analysis.candidates) {
            System.assert(!candidate.label.contains('The Loving Group'));
        }
        System.assertEquals(builderAccount.Id, analysis.candidates[0].recordId);
    }

    @IsTest(SeeAllData=true)
    static void parsesScopeAndCreatesWorkOrderLineItems() {
        WorkOrder workOrderRecord = [
            SELECT Id
            FROM WorkOrder
            LIMIT 1
        ];
        Integer existingLineCount = [SELECT COUNT() FROM WorkOrderLineItem WHERE WorkOrderId = :workOrderRecord.Id];

        String intakeText =
            'Scope of Work:\n' +
            '2 ea Countertop, Grill Deluxe\n' +
            '18 tons #67 Stone\n' +
            'Install irrigation controller\n';

        Test.startTest();
        Id draftId = McLovinEmployeeAgentController.startDraft('Document', intakeText);
        McLovinEmployeeIntakeService.AnalysisResult analysis =
            McLovinEmployeeAgentController.analyzeRequest(draftId, 'Document', intakeText);
        McLovinEmployeeIntakeService.SaveResult saveResult =
            McLovinEmployeeAgentController.saveRequest(draftId, '{"companyName":"Lennar Homes – Charlotte","workOrderId":"' + workOrderRecord.Id + '"}', true);
        Test.stopTest();

        List<Object> parsedItems = (List<Object>) analysis.extractedData.get('parsedScopeItems');
        System.assert(parsedItems != null && !parsedItems.isEmpty(), 'Expected parsed scope items from the job description.');

        Integer totalLineCount = [SELECT COUNT() FROM WorkOrderLineItem WHERE WorkOrderId = :workOrderRecord.Id];
        System.assertEquals(existingLineCount + 3, totalLineCount, 'Expected 3 new Work Order line items to be created.');
        System.assert(saveResult.message.contains('Work Order line item'), 'Save message should mention created line items.');
    }

    @IsTest
    static void asksForPoAndBuilderRoutingFields() {
        String intakeText =
            'Purchase Order\n' +
            'Builder: Ryan Homes Charlotte\n' +
            'PO # PO-2048\n' +
            'Scope of Work\n' +
            'Install landscape package\n';

        Test.startTest();
        Id draftId = McLovinEmployeeAgentController.startDraft('Document', intakeText);
        McLovinEmployeeIntakeService.AnalysisResult analysis =
            McLovinEmployeeAgentController.analyzeRequest(draftId, 'Document', intakeText);
        Test.stopTest();

        System.assertEquals('Builder Scope', analysis.classification);
        System.assertEquals('PO-2048', (String) analysis.extractedData.get('purchaseOrderNumber'));

        Set<String> missingApis = new Set<String>();
        for (McLovinEmployeeIntakeService.MissingField field : analysis.missingFields) {
            missingApis.add(field.apiName);
        }

        System.assert(missingApis.contains('communityName'), 'Builder PO flow should ask for community.');
        System.assert(!missingApis.contains('purchaseOrderNumber'), 'PO number was provided and should not be asked again.');
    }

    @IsTest
    static void asksForOptionalWorkOrderWhenScopeLinesExist() {
        String intakeText =
            'Scope of Work:\n' +
            '4 ea Palm shrubs\n' +
            '2 tons river rock\n';

        Test.startTest();
        Id draftId = McLovinEmployeeAgentController.startDraft('Document', intakeText);
        McLovinEmployeeIntakeService.AnalysisResult analysis =
            McLovinEmployeeAgentController.analyzeRequest(draftId, 'Document', intakeText);
        Test.stopTest();

        Boolean foundWorkOrderPrompt = false;
        for (McLovinEmployeeIntakeService.MissingField field : analysis.missingFields) {
            if (field.apiName == 'workOrderId') {
                foundWorkOrderPrompt = true;
                break;
            }
        }
        System.assert(foundWorkOrderPrompt, 'Parsed scope lines should prompt for an optional Work Order Id.');
    }

    @IsTest(SeeAllData=true)
    static void routesWarrantyCaseToWarrantyQueue() {
        Group intakeQueue = [
            SELECT Id, DeveloperName
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = 'Customer_Success_Intake'
            LIMIT 1
        ];

        String intakeText =
            'Warranty Case Intake\n' +
            'Routing Lane: Warranty\n' +
            'Case Type: Warranty\n' +
            'Customer / Builder: Lennar Homes Charlotte\n' +
            'Contact: Jane Doe\n' +
            'jane.doe@example.com\n' +
            'Issue Summary: Sod failure in rear yard\n';

        Test.startTest();
        Id draftId = McLovinEmployeeAgentController.startDraft('Document', intakeText);
        McLovinEmployeeIntakeService.AnalysisResult analysis =
            McLovinEmployeeAgentController.analyzeRequest(draftId, 'Document', intakeText);
        McLovinEmployeeIntakeService.SaveResult saveResult =
            McLovinEmployeeAgentController.saveRequest(draftId, '{}', true);
        Test.stopTest();

        System.assertEquals('Service Case', analysis.classification);
        System.assertEquals('Warranty', (String) analysis.extractedData.get('routingLane'));

        Case createdCase = [
            SELECT Id, OwnerId, Subject
            FROM Case
            WHERE Id = :saveResult.primaryRecordId
        ];
        System.assertEquals(intakeQueue.Id, createdCase.OwnerId);
        System.assert(createdCase.Subject.contains('Warranty'));
    }
}