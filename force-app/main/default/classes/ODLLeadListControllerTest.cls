@IsTest
private class ODLLeadListControllerTest {
    @IsTest
    static void testWorkspaceDataIncludesLeadActivityAndFollowUp() {
        Lead leadRow = new Lead(
            LastName = 'Workspace Lead',
            Company = 'Homeowner',
            Status = 'New',
            LeadSource = 'Lennar Voucher',
            Lead_Type__c = 'Homeowner',
            Email = 'leadworkspace@test.example'
        );
        insert leadRow;

        insert new Task(
            WhoId = leadRow.Id,
            Subject = 'Email proposal',
            ActivityDate = Date.today(),
            Status = 'Completed',
            TaskSubtype = 'Email'
        );

        insert new Task(
            WhoId = leadRow.Id,
            Subject = 'Call homeowner',
            ActivityDate = Date.today().addDays(1),
            Status = 'Open'
        );

        Test.startTest();
        ODLLeadListController.WorkspaceData data = ODLLeadListController.getWorkspaceData();
        Test.stopTest();

        System.assertNotEquals(0, data.rows.size());
        ODLLeadListController.WorkspaceRow matched;
        for (ODLLeadListController.WorkspaceRow row : data.rows) {
            if (row.id == leadRow.Id) {
                matched = row;
                break;
            }
        }
        System.assertNotEquals(null, matched);
        System.assertEquals('UpgradeMyBackyard', matched.odPath);
        System.assertEquals('Sent Email - Initial', matched.lastAction);
        System.assertEquals('Call homeowner', matched.followUpTask);
    }

    @IsTest
    static void testWorkspaceDataClassifiesLawnCare() {
        Lead leadRow = new Lead(
            LastName = 'Lawn Care Lead',
            Company = 'Homeowner',
            Status = 'New',
            LeadSource = 'Website',
            Service_Flag_Lawn_Care__c = true
        );
        insert leadRow;

        Test.startTest();
        ODLLeadListController.WorkspaceData data = ODLLeadListController.getWorkspaceData();
        Test.stopTest();

        ODLLeadListController.WorkspaceRow matched;
        for (ODLLeadListController.WorkspaceRow row : data.rows) {
            if (row.id == leadRow.Id) {
                matched = row;
                break;
            }
        }
        System.assertNotEquals(null, matched);
        System.assertEquals('Lawn Care', matched.odPath);
        System.assertEquals('Lawn Care', matched.interest);
    }

    @IsTest
    static void testWorkspaceDataExcludesConvertedLeads() {
        Lead leadRow = new Lead(
            LastName = 'Converted Household Lead',
            Company = 'Homeowner',
            Status = 'New',
            LeadSource = 'Lennar Voucher',
            Lead_Type__c = 'Homeowner'
        );
        insert leadRow;

        Account acct = new Account(
            Name = 'Converted Household Lead Household',
            Type = 'Homeowner'
        );
        insert acct;

        Contact contactRow = new Contact(
            LastName = 'Converted Household Lead',
            AccountId = acct.Id
        );
        insert contactRow;

        Database.LeadConvert convertRequest = new Database.LeadConvert();
        convertRequest.setLeadId(leadRow.Id);
        convertRequest.setConvertedStatus([
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel);
        convertRequest.setAccountId(acct.Id);
        convertRequest.setContactId(contactRow.Id);
        convertRequest.setDoNotCreateOpportunity(true);
        Database.convertLead(convertRequest);

        Test.startTest();
        ODLLeadListController.WorkspaceData data = ODLLeadListController.getWorkspaceData();
        Test.stopTest();

        for (ODLLeadListController.WorkspaceRow row : data.rows) {
            System.assertNotEquals(leadRow.Id, row.id, 'Converted leads should not remain in the first-wave lead workspace.');
        }
    }
}