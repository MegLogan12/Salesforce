@IsTest
private class ODLEmailViewControllerTest {
    @IsTest
    static void testEmailSummaryAndDetailForOpportunity() {
        Account accountRow = new Account(Name = 'ODL Email Account');
        insert accountRow;

        Contact contactRow = new Contact(LastName = 'Email Contact', AccountId = accountRow.Id, Email = 'homeowner@example.com');
        insert contactRow;

        Opportunity opp = new Opportunity(
            Name = 'ODL Email Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = accountRow.Id
        );
        insert opp;
        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = contactRow.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );

        EmailMessage emailRow = new EmailMessage(
            Subject = 'Outdoor Living proposal',
            FromAddress = 'sales@thelovingcompanies.com',
            ToAddress = 'homeowner@example.com',
            TextBody = 'Here is your latest Outdoor Living proposal.',
            MessageDate = System.now(),
            Status = '1',
            Incoming = false,
            RelatedToId = opp.Id
        );
        insert emailRow;

        Test.startTest();
        ODLEmailViewController.EmailSummary summary = ODLEmailViewController.getEmailSummary(opp.Id);
        List<ODLEmailViewController.EmailRow> rows = ODLEmailViewController.getRelatedEmails(opp.Id, 20, 0);
        ODLEmailViewController.EmailDetail detail = ODLEmailViewController.getEmailDetail(emailRow.Id);
        Test.stopTest();

        System.assertEquals(true, summary.sourceAvailable);
        System.assert(summary.totalEmails > 0);
        Boolean foundOpportunityEmail = false;
        for (ODLEmailViewController.EmailRow row : rows) {
            if (row.id == emailRow.Id) {
                foundOpportunityEmail = true;
                break;
            }
        }
        System.assert(foundOpportunityEmail, 'Opportunity timeline should include the EmailMessage record.');
        System.assertEquals('Outdoor Living proposal', detail.subject);
    }

    @IsTest
    static void testTaskFallbackAndFollowUpTask() {
        Lead leadRow = new Lead(
            LastName = 'Lead Email',
            Company = 'ODL',
            Status = 'New',
            LeadSource = 'Lennar Voucher',
            Community_Name__c = 'Test Community'
        );
        insert leadRow;

        Task taskRow = new Task(
            Subject = 'Email: Initial homeowner follow-up',
            Status = 'Completed',
            ActivityDate = Date.today(),
            WhoId = leadRow.Id,
            TaskSubtype = 'Email',
            Description = 'Logged email body preview.'
        );
        insert taskRow;

        Test.startTest();
        List<ODLEmailViewController.EmailRow> rows = ODLEmailViewController.getRelatedEmails(leadRow.Id, 20, 0);
        ODLEmailViewController.EmailDetail detail = ODLEmailViewController.getEmailDetail(taskRow.Id);
        ODLEmailViewController.FollowUpResult result = ODLEmailViewController.createFollowUpTask(
            leadRow.Id,
            taskRow.Id,
            'Follow up with homeowner',
            Date.today().addDays(2),
            UserInfo.getUserId()
        );
        Test.stopTest();

        System.assertEquals('Task', rows[0].objectApiName);
        System.assertEquals('Logged Email', rows[0].direction);
        System.assertEquals('Email: Initial homeowner follow-up', detail.subject);
        System.assertNotEquals(null, result.taskId);
        Task insertedTask = [SELECT Id, Subject, WhoId, ActivityDate FROM Task WHERE Id = :result.taskId];
        System.assertEquals(leadRow.Id, insertedTask.WhoId);
        System.assertEquals('Follow up with homeowner', insertedTask.Subject);
    }

    @IsTest
    static void testAccountAndCaseEmailRelationships() {
        Account accountRow = new Account(Name = 'ODL Household Account');
        insert accountRow;

        Contact contactRow = new Contact(
            LastName = 'Household Contact',
            AccountId = accountRow.Id,
            Email = 'household@example.com'
        );
        insert contactRow;

        Case caseRow = new Case(
            Subject = 'Warranty follow-up',
            Status = 'New',
            Origin = 'Email',
            AccountId = accountRow.Id,
            ContactId = contactRow.Id
        );
        insert caseRow;

        EmailMessage caseEmail = new EmailMessage(
            Subject = 'Warranty details',
            FromAddress = 'support@thelovingcompanies.com',
            ToAddress = 'household@example.com',
            TextBody = 'Attached are the next steps for warranty review.',
            MessageDate = System.now(),
            Status = '1',
            Incoming = false,
            ParentId = caseRow.Id,
            RelatedToId = accountRow.Id
        );
        insert caseEmail;

        Test.startTest();
        ODLEmailViewController.EmailSummary accountSummary = ODLEmailViewController.getEmailSummary(accountRow.Id);
        List<ODLEmailViewController.EmailRow> accountRows = ODLEmailViewController.getRelatedEmails(accountRow.Id, 10, 0);
        List<ODLEmailViewController.EmailRow> contactRows = ODLEmailViewController.getRelatedEmails(contactRow.Id, 10, 0);
        ODLEmailViewController.EmailSummary caseSummary = ODLEmailViewController.getEmailSummary(caseRow.Id);
        List<ODLEmailViewController.EmailRow> caseRows = ODLEmailViewController.getRelatedEmails(caseRow.Id, 10, 0);
        Test.stopTest();

        System.assert(accountSummary.totalEmails > 0);
        System.assert(caseSummary.totalEmails > 0);
        Boolean foundCaseEmail = false;
        for (ODLEmailViewController.EmailRow row : caseRows) {
            if (row.id == caseEmail.Id) {
                foundCaseEmail = true;
                break;
            }
        }
        System.assert(foundCaseEmail, 'Case timeline should include the EmailMessage record.');
        System.assertNotEquals(null, accountRows[0].relatedRecordLabel);
        System.assert(contactRows.size() > 0);
    }

    @IsTest
    static void testCampaignRelatedLoggedEmailFallback() {
        Campaign campaignRow = new Campaign(Name = 'ODL Spring Launch', IsActive = true);
        insert campaignRow;

        Account accountRow = new Account(Name = 'Campaign Household');
        insert accountRow;

        Contact contactRow = new Contact(
            LastName = 'Campaign Contact',
            AccountId = accountRow.Id,
            Email = 'campaign@example.com'
        );
        insert contactRow;

        insert new CampaignMember(CampaignId = campaignRow.Id, ContactId = contactRow.Id, Status = 'Sent');

        Task taskRow = new Task(
            Subject = 'Email: Campaign follow-up',
            Status = 'Completed',
            ActivityDate = Date.today(),
            WhoId = contactRow.Id,
            WhatId = campaignRow.Id,
            TaskSubtype = 'Email',
            Description = 'Followed up on voucher campaign response.'
        );
        insert taskRow;

        Test.startTest();
        List<ODLEmailViewController.EmailRow> rows = ODLEmailViewController.getRelatedEmails(campaignRow.Id, 10, 0);
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('Logged Email', rows[0].direction);
        System.assertEquals(taskRow.Id, rows[0].id);
    }

    @IsTest
    static void testAccountTargetsIncludeSecondaryHouseholdContact() {
        Account accountRow = new Account(Name = 'Smith Household');
        insert accountRow;

        Contact spouse = new Contact(
            LastName = 'Smith',
            FirstName = 'Jane',
            AccountId = accountRow.Id,
            Email = 'jane.smith@example.com'
        );
        insert spouse;

        accountRow.ODL_Secondary_Contact__c = spouse.Id;
        update accountRow;

        Task spouseTask = new Task(
            Subject = 'Email: spouse follow-up',
            Status = 'Completed',
            ActivityDate = Date.today(),
            WhoId = spouse.Id,
            WhatId = accountRow.Id,
            TaskSubtype = 'Email',
            Description = 'Household spouse reply captured.'
        );
        insert spouseTask;

        Test.startTest();
        List<ODLEmailViewController.EmailRow> accountRows = ODLEmailViewController.getRelatedEmails(accountRow.Id, 10, 0);
        Test.stopTest();

        Boolean foundSpouseTask = false;
        for (ODLEmailViewController.EmailRow row : accountRows) {
            if (row.id == spouseTask.Id) {
                foundSpouseTask = true;
                break;
            }
        }
        System.assertEquals(true, foundSpouseTask);
    }

    @TestSetup
    static void setupBuilderEmailTraversalFixture() {
        Id builderParentRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Builder_Parent').getRecordTypeId();
        Id builderMarketRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Builder_Market').getRecordTypeId();
        Id productionInstallRtId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId();

        Account builderParent = new Account(
            Name = 'Builder Parent Email Test',
            RecordTypeId = builderParentRtId
        );
        insert builderParent;

        Account builderDivision = new Account(
            Name = 'Builder Division Email Test',
            RecordTypeId = builderMarketRtId,
            ParentId = builderParent.Id
        );
        insert builderDivision;

        Contact builderContact = new Contact(
            LastName = 'Builder Contact',
            AccountId = builderDivision.Id,
            Email = 'builder-contact@example.com'
        );
        insert builderContact;

        Community__c communityRow = new Community__c(
            Name = 'Builder Email Community',
            Builder_Account__c = builderDivision.Id,
            Active__c = true,
            BMG_Package_Code__c = 'EMAIL-PKG'
        );
        insert communityRow;

        Lot__c lotRow = new Lot__c(
            Name = 'Lot 101',
            Community__c = communityRow.Id,
            Street_Address__c = '101 Builder Email Lane',
            Lot_Latitude__c = 35.2271,
            Lot_Longitude__c = -80.8431
        );
        insert lotRow;

        OperatingHours hours = new OperatingHours(Name = 'Email Test Hours', TimeZone = 'America/New_York');
        insert hours;

        ServiceTerritory territory = new ServiceTerritory(Name = 'Email Test Territory', OperatingHoursId = hours.Id, IsActive = true);
        insert territory;

        WorkType workType = new WorkType(Name = 'Email Test WorkType', EstimatedDuration = 120, DurationType = 'Minutes');
        insert workType;

        Account homeownerAccount = new Account(Name = 'Quote Coverage Homeowner');
        insert homeownerAccount;

        Opportunity opportunityRow = new Opportunity(
            Name = 'Builder Email Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = homeownerAccount.Id,
            Community__c = communityRow.Id
        );
        insert opportunityRow;

        Quote quoteRow = new Quote(
            Name = 'Builder Email Quote',
            OpportunityId = opportunityRow.Id
        );
        insert quoteRow;

        WorkOrder workOrderRow = new WorkOrder(
            RecordTypeId = productionInstallRtId,
            Subject = 'Builder Email Work Order',
            Status = 'New',
            AccountId = builderDivision.Id,
            ContactId = builderContact.Id,
            Lot__c = lotRow.Id,
            Lot_Number__c = lotRow.Name,
            Work_Order_Type__c = 'Production Install',
            ServiceTerritoryId = territory.Id
        );
        insert workOrderRow;

        Datetime startTime = System.now().addDays(1);
        ServiceAppointment appointmentRow = new ServiceAppointment(
            ParentRecordId = workOrderRow.Id,
            Subject = 'Builder Email Service Appointment',
            EarliestStartTime = startTime,
            DueDate = startTime.addDays(1),
            Status = 'None',
            WorkTypeId = workType.Id,
            ServiceTerritoryId = territory.Id,
            Duration = 120,
            DurationType = 'Minutes',
            SchedStartTime = startTime,
            SchedEndTime = startTime.addHours(2)
        );
        insert appointmentRow;

        EmailMessage communityEmail = new EmailMessage(
            Subject = 'Community scope update',
            FromAddress = 'pm@thelovingcompanies.com',
            ToAddress = 'builder-contact@example.com',
            TextBody = 'Community and lot scope confirmed.',
            MessageDate = System.now(),
            Status = '1',
            Incoming = false,
            RelatedToId = workOrderRow.Id
        );
        insert communityEmail;

        insert new EmailMessage(
            Subject = 'Quote follow-up',
            FromAddress = 'sales@thelovingcompanies.com',
            ToAddress = 'builder-contact@example.com',
            TextBody = 'Quote follow-up sent to the homeowner account.',
            MessageDate = System.now().addMinutes(-5),
            Status = '1',
            Incoming = false,
            RelatedToId = opportunityRow.Id
        );
    }

    @IsTest
    static void testBuilderHierarchyTraversalForAccountsAndCommunity() {
        Account builderParent = [SELECT Id FROM Account WHERE Name = 'Builder Parent Email Test' LIMIT 1];
        Account builderDivision = [SELECT Id FROM Account WHERE Name = 'Builder Division Email Test' LIMIT 1];
        Community__c communityRow = [SELECT Id FROM Community__c WHERE Name = 'Builder Email Community' LIMIT 1];

        Test.startTest();
        List<ODLEmailViewController.EmailRow> builderParentRows = ODLEmailViewController.getRelatedEmails(builderParent.Id, 20, 0);
        List<ODLEmailViewController.EmailRow> builderDivisionRows = ODLEmailViewController.getRelatedEmails(builderDivision.Id, 20, 0);
        List<ODLEmailViewController.EmailRow> communityRows = ODLEmailViewController.getRelatedEmails(communityRow.Id, 20, 0);
        Test.stopTest();

        System.assert(!builderParentRows.isEmpty(), 'Builder parent should return related email rows.');
        System.assert(!builderDivisionRows.isEmpty(), 'Builder division should return related email rows.');
        System.assert(!communityRows.isEmpty(), 'Community should return related email rows.');
    }

    @IsTest
    static void testBuilderHierarchyTraversalForLotWorkOrderAndServiceAppointment() {
        Lot__c lotRow = [SELECT Id FROM Lot__c WHERE Name = 'Lot 101' LIMIT 1];
        WorkOrder workOrderRow = [SELECT Id FROM WorkOrder WHERE Subject = 'Builder Email Work Order' LIMIT 1];
        ServiceAppointment appointmentRow = [SELECT Id FROM ServiceAppointment WHERE Subject = 'Builder Email Service Appointment' LIMIT 1];
        EmailMessage communityEmail = [SELECT Id FROM EmailMessage WHERE Subject = 'Community scope update' LIMIT 1];

        Test.startTest();
        List<ODLEmailViewController.EmailRow> lotRows = ODLEmailViewController.getRelatedEmails(lotRow.Id, 20, 0);
        List<ODLEmailViewController.EmailRow> workOrderRows = ODLEmailViewController.getRelatedEmails(workOrderRow.Id, 20, 0);
        List<ODLEmailViewController.EmailRow> appointmentRows = ODLEmailViewController.getRelatedEmails(appointmentRow.Id, 20, 0);
        ODLEmailViewController.EmailSummary appointmentSummary = ODLEmailViewController.getEmailSummary(appointmentRow.Id);
        Test.stopTest();

        System.assert(!lotRows.isEmpty(), 'Lot should return related email rows.');
        System.assert(!workOrderRows.isEmpty(), 'Work order should return related email rows.');
        System.assert(!appointmentRows.isEmpty(), 'Service appointment should return related email rows.');
        Boolean foundAppointmentEmail = false;
        for (ODLEmailViewController.EmailRow row : appointmentRows) {
            if (row.id == communityEmail.Id) {
                foundAppointmentEmail = true;
                break;
            }
        }
        System.assert(foundAppointmentEmail, 'Service appointment timeline should include the WorkOrder EmailMessage record.');
        System.assertEquals(true, appointmentSummary.sourceAvailable);
        System.assert(appointmentSummary.totalEmails > 0);
    }

    @IsTest
    static void testBuilderQuoteTraversalAndWorkOrderFollowUpTask() {
        Quote quoteRow = [SELECT Id FROM Quote WHERE Name = 'Builder Email Quote' LIMIT 1];
        WorkOrder workOrderRow = [SELECT Id FROM WorkOrder WHERE Subject = 'Builder Email Work Order' LIMIT 1];
        EmailMessage communityEmail = [SELECT Id FROM EmailMessage WHERE Subject = 'Community scope update' LIMIT 1];

        Test.startTest();
        List<ODLEmailViewController.EmailRow> quoteRows = ODLEmailViewController.getRelatedEmails(quoteRow.Id, 20, 0);
        ODLEmailViewController.FollowUpResult workOrderFollowUp = ODLEmailViewController.createFollowUpTask(
            workOrderRow.Id,
            communityEmail.Id,
            null,
            Date.today().addDays(3),
            UserInfo.getUserId()
        );
        Test.stopTest();

        System.assert(!quoteRows.isEmpty(), 'Quote should return related email rows.');
        System.assertNotEquals(null, workOrderFollowUp.taskId);
        System.assertEquals(workOrderRow.Id, [SELECT WhatId FROM Task WHERE Id = :workOrderFollowUp.taskId].WhatId);
    }
}