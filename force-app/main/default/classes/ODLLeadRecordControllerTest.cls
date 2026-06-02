@IsTest
private class ODLLeadRecordControllerTest {
    @IsTest
    static void testGetPageDataForUpgradeMyBackyardLead() {
        Lead leadRow = new Lead(
            LastName = 'Record Lead',
            Company = 'Homeowner',
            Status = 'Qualified',
            LeadSource = 'Lennar Voucher',
            Lead_Type__c = 'Homeowner',
            Email = 'leadrecord@test.example',
            Community_Name__c = 'Homeowner Web Form',
            SMS_Consent__c = true
        );
        insert leadRow;

        insert new Task(
            WhoId = leadRow.Id,
            Subject = 'Voicemail follow-up',
            ActivityDate = Date.today(),
            Status = 'Completed',
            TaskSubtype = 'Call'
        );

        insert new Task(
            WhoId = leadRow.Id,
            Subject = 'Send intake link',
            ActivityDate = Date.today().addDays(1),
            Status = 'Open'
        );

        Campaign campaignRow = new Campaign(Name = 'Lead Record Campaign', IsActive = true);
        insert campaignRow;
        insert new CampaignMember(CampaignId = campaignRow.Id, LeadId = leadRow.Id, Status = 'Sent');

        Test.startTest();
        ODLLeadRecordController.PageData data = ODLLeadRecordController.getPageData(leadRow.Id);
        Test.stopTest();

        System.assertEquals('UpgradeMyBackyard', data.odPath);
        System.assert(data.statusPath.size() >= 3);
        System.assertEquals('Left Voicemail - Follow-Up', data.lastAction);
        System.assertEquals('Send intake link', data.nextFollowUpSubject);
        System.assertNotEquals(null, data.latestCampaign);
        System.assertEquals(0, data.serviceInterests.size());
        System.assert(data.missingData.contains('No service interest fields are populated on this lead.'));
    }

    @IsTest
    static void testGetPageDataForLawnCareLead() {
        Lead leadRow = new Lead(
            LastName = 'Record Lawn Lead',
            Company = 'Homeowner',
            Status = 'New',
            LeadSource = 'Website',
            Service_Flag_Lawn_Care__c = true
        );
        insert leadRow;

        Test.startTest();
        ODLLeadRecordController.PageData data = ODLLeadRecordController.getPageData(leadRow.Id);
        Test.stopTest();

        System.assertEquals('Lawn Care', data.odPath);
        System.assertEquals('No action logged', data.lastAction);
        System.assertEquals('No follow-up task', data.nextFollowUpSubject);
    }

    @IsTest
    static void testGetPageDataForConvertedLeadWithVoucher() {
        Lead leadRow = new Lead(
            LastName = 'Converted Record Lead',
            Company = 'Homeowner',
            Status = 'Qualified',
            LeadSource = 'Website',
            Lead_Type__c = 'Homeowner',
            Email = 'leadconverted@test.example',
            Community_Name__c = 'Design Build Interest',
            Service_Flag_Irrigation__c = true
        );
        insert leadRow;

        Account voucherBuilder = new Account(Name = 'Lead Test Builder');
        insert voucherBuilder;

        Boolean voucherCreated = false;
        try {
            insert new Voucher__c(
                Voucher_Code__c = 'TEST-VOUCHER-001',
                Status__c = 'Draft',
                Voucher_Type__c = 'Other',
                Builder_Account__c = voucherBuilder.Id,
                Homeowner_Lead__c = leadRow.Id
            );
            voucherCreated = true;
        } catch (DmlException ex) {
            System.debug('[ODLLeadRecordControllerTest] Voucher creation skipped due to org validation rule: ' + ex.getMessage());
        }

        Database.LeadConvert convertRequest = new Database.LeadConvert();
        convertRequest.setLeadId(leadRow.Id);
        convertRequest.setConvertedStatus([
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel);
        Database.LeadConvertResult convertResult = Database.convertLead(convertRequest);
        System.assert(convertResult.isSuccess());

        Test.startTest();
        ODLLeadRecordController.PageData data = ODLLeadRecordController.getPageData(leadRow.Id);
        Test.stopTest();

        System.assertEquals('Design Build', data.odPath);
        System.assert(data.statusPath.contains('Converted'));
        System.assertEquals('No action logged', data.lastAction);
        System.assertEquals(1, data.serviceInterests.size());
        System.assertNotEquals(null, data.convertedAccountUrl);
        System.assertNotEquals(null, data.convertedAccountName);
        if (voucherCreated) {
            System.assertNotEquals(null, data.voucherRecord);
            System.assertEquals('TEST-VOUCHER-001', data.voucherRecord.label);
            System.assertEquals('Draft', data.voucherRecord.status);
            System.assertEquals('Other', data.voucherRecord.subtext);
        }
    }

    @IsTest
    static void testGetPageDataUsesEventInteraction() {
        Lead leadRow = new Lead(
            LastName = 'Event Lead',
            Company = 'Homeowner',
            Status = 'Qualified',
            LeadSource = 'Website',
            Lead_Type__c = 'Homeowner',
            Community_Name__c = 'Custom Design Build',
            Email = 'eventlead@test.example'
        );
        insert leadRow;

        insert new Event(
            WhoId = leadRow.Id,
            Subject = 'Presentation call',
            Type = 'Call',
            ActivityDateTime = System.now().addHours(-1),
            DurationInMinutes = 30
        );

        Test.startTest();
        ODLLeadRecordController.PageData data = ODLLeadRecordController.getPageData(leadRow.Id);
        Test.stopTest();

        System.assertEquals('Design Build', data.odPath);
        System.assertEquals('Call Complete - Presentation', data.lastAction);
        System.assertEquals(false, data.lastActionWasVoicemail);
        System.assertEquals(1, data.interactions.size());
    }
}