@IsTest
private class HomeownerAccountPageControllerTest {
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
        System.assert(!nonBuilderRts.isEmpty(), 'A non-builder Account record type is required for homeowner page tests.');
        return nonBuilderRts[0].Id;
    }

    @IsTest
    static void testGetPageData() {
        Account acct = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Hartwell',
            PersonEmail = 'sarah@example.com',
            PersonMobilePhone = '555-1212',
            Type = 'Home Owner',
            ODL_Household_Display_Name__c = 'Hartwell Household'
        );
        insert acct;

        Opportunity opp = new Opportunity(
            Name = 'UMB Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acct.Id,
            ContactId = acct.PersonContactId,
            Type = 'UpgradeMyBackyard'
        );
        insert opp;

        Case c = new Case(
            AccountId = acct.Id,
            Subject = 'Warranty Review',
            Status = 'New',
            Origin = 'Phone'
        );
        insert c;

        Event evt = new Event(
            WhatId = acct.Id,
            WhoId = acct.PersonContactId,
            Subject = 'Call',
            Type = 'Call',
            ActivityDateTime = System.now().addDays(1),
            DurationInMinutes = 30,
            Description = 'Call summary:' + '\n' + 'Review design notes'
        );
        insert evt;

        Test.startTest();
        HomeownerAccountPageController.PageData data = HomeownerAccountPageController.getPageData(acct.Id);
        Test.stopTest();

        System.assertEquals(acct.Id, data.accountRecord.Id);
        System.assertEquals(1, data.kpis.openOpportunities);
        System.assertEquals(1, data.kpis.openCases);
        System.assertEquals(1, data.kpis.scheduledInteractions);
        System.assertEquals(1, data.opportunities.size());
        System.assertEquals('UMB Test Opportunity', data.opportunities[0].label);
        System.assertEquals(1, data.interactions.size());
        System.assertEquals('Call', data.interactions[0].interactionType);
        System.assertEquals('Call', data.interactions[0].subjectText);
        System.assertEquals('Hartwell', data.contactDisplay);
        System.assertEquals('Hartwell Household', data.householdDisplayName);
        System.assertEquals('UMB Test Opportunity', data.propertyContext.projectLabel);
    }

    @IsTest
    static void testCreateScheduledInteraction() {
        Account acct = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Brooks',
            PersonEmail = 'jamie@example.com',
            Type = 'Home Owner'
        );
        insert acct;

        Test.startTest();
        HomeownerAccountPageController.ScheduledInteractionResult result = HomeownerAccountPageController.createScheduledInteraction(
            acct.Id,
            'onsite',
            System.now().addDays(2),
            45,
            'Review patio layout and scope.'
        );
        Test.stopTest();

        acct = [SELECT Id, PersonContactId FROM Account WHERE Id = :acct.Id];
        Event created = [
            SELECT Id, Subject, Type, Location, Description, WhatId, WhoId, DurationInMinutes
            FROM Event
            WHERE Id = :result.eventId
        ];
        System.assertEquals(acct.Id, created.WhatId);
        System.assertEquals(acct.PersonContactId, created.WhoId);
        System.assertEquals(45, created.DurationInMinutes);
        System.assertEquals('Onsite Visit', created.Subject);
        System.assert(created.Description.contains('Visit notes'));
        System.assertEquals(true, result.confirmationSent);
    }

    @IsTest
    static void testCreateScheduledInteractionUsesSecondaryContactFallback() {
        Account acct = new Account(
            Name = 'Smith Household',
            Type = 'Home Owner'
        );
        insert acct;

        Contact spouse = new Contact(
            LastName = 'Smith',
            FirstName = 'Jane',
            Email = 'jane.smith@example.com',
            AccountId = acct.Id
        );
        insert spouse;

        acct.ODL_Secondary_Contact__c = spouse.Id;
        update acct;

        Test.startTest();
        HomeownerAccountPageController.ScheduledInteractionResult result = HomeownerAccountPageController.createScheduledInteraction(
            acct.Id,
            'virtual',
            System.now().addDays(1),
            30,
            'Review concept board with spouse.'
        );
        Test.stopTest();

        Event created = [
            SELECT Id, WhoId, Subject, Type, Location
            FROM Event
            WHERE Id = :result.eventId
        ];
        System.assertEquals(spouse.Id, created.WhoId);
        System.assertEquals('Virtual Visit', created.Subject);
        System.assertEquals(true, result.confirmationSent);
    }

    @IsTest
    static void testGetPageDataIncludesTasksWorkOrdersAndMissingData() {
        Account acct = new Account(
            RecordTypeId = firstNonBuilderAccountRecordTypeId(),
            Name = 'Missing Data Household',
            Type = 'Commercial'
        );
        insert acct;
        Contact contactRow = new Contact(
            LastName = 'Missing Data Household',
            Email = 'missing-data-household@example.com',
            AccountId = acct.Id
        );
        insert contactRow;

        OperatingHours hours = new OperatingHours(Name = 'Homeowner Page Test Hours', TimeZone = 'America/New_York');
        insert hours;

        ServiceTerritory territory = new ServiceTerritory(
            Name = 'Homeowner Page Test Territory',
            OperatingHoursId = hours.Id,
            IsActive = true
        );
        insert territory;

        WorkType workType = new WorkType(
            Name = 'Homeowner Page Test WorkType',
            EstimatedDuration = 60,
            DurationType = 'Minutes'
        );
        insert workType;

        Opportunity opp = new Opportunity(
            Name = 'Custom Design Build Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 25000,
            AccountId = acct.Id,
            ContactId = contactRow.Id,
            Type = 'Design Build'
        );
        insert opp;

        Task oppFollowUp = new Task(
            WhatId = opp.Id,
            Subject = 'Follow up on renderings',
            ActivityDate = Date.today().addDays(2),
            Status = 'Open'
        );
        insert oppFollowUp;

        WorkOrder wo = new WorkOrder(
            AccountId = acct.Id,
            Subject = 'Backyard Build',
            Status = 'New',
            RecordTypeId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId(),
            Work_Order_Type__c = 'Production Install',
            ServiceTerritoryId = territory.Id
        );
        insert wo;

        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Subject = 'Backyard Build Visit',
            Status = 'Scheduled',
            WorkTypeId = workType.Id,
            ServiceTerritoryId = territory.Id,
            EarliestStartTime = System.now().addDays(4),
            Duration = 120,
            DurationType = 'Minutes',
            SchedStartTime = System.now().addDays(4),
            SchedEndTime = System.now().addDays(4).addHours(2)
        );
        insert sa;

        Task acctTask = new Task(
            WhatId = acct.Id,
            Subject = 'Call homeowner about permit timing',
            ActivityDate = Date.today().addDays(1),
            Status = 'Completed',
            TaskSubtype = 'Call',
            Description = 'Need permit status update before site visit.'
        );
        insert acctTask;

        Homeowner_Property__c propertyRow = new Homeowner_Property__c(
            Name = '4217 Test Court',
            Homeowner_Account__c = acct.Id,
            Opportunity__c = opp.Id
        );
        insert propertyRow;

        Design_Review__c designReview = new Design_Review__c(
            Opportunity__c = opp.Id,
            Status__c = 'Approved'
        );
        insert designReview;

        Payment_Milestone__c milestone = new Payment_Milestone__c(
            Opportunity__c = opp.Id,
            Type__c = 'Deposit',
            Status__c = 'Sent',
            Amount__c = 12500,
            Due_Date__c = Date.today().addDays(5)
        );
        insert milestone;

        EmailMessage oppEmail = new EmailMessage(
            Subject = 'Outdoor Living proposal',
            FromAddress = 'sales@thelovingcompanies.com',
            ToAddress = 'homeowner@example.com',
            TextBody = 'Proposal is ready.',
            MessageDate = System.now().addHours(-2),
            Status = '1',
            Incoming = false,
            RelatedToId = opp.Id
        );
        insert oppEmail;

        ContentVersion contentVersion = new ContentVersion(
            Title = 'Backyard Before',
            PathOnClient = 'backyard-before.jpg',
            VersionData = Blob.valueOf('image-bytes')
        );
        insert contentVersion;
        contentVersion = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id];
        insert new ContentDocumentLink(
            LinkedEntityId = acct.Id,
            ContentDocumentId = contentVersion.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        ContentNote noteRow = new ContentNote(
            Title = 'Welcome Call Notes',
            Content = Blob.valueOf('Captured homeowner questions and design notes.')
        );
        insert noteRow;
        insert new ContentDocumentLink(
            LinkedEntityId = opp.Id,
            ContentDocumentId = noteRow.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        HomeownerAccountPageController.PageData data = HomeownerAccountPageController.getPageData(acct.Id);
        Test.stopTest();

        System.assertEquals(1, data.opportunities.size());
        System.assertEquals('Design Build', data.opportunities[0].subtext);
        System.assertEquals(String.valueOf(oppFollowUp.ActivityDate), data.opportunities[0].secondaryText);
        System.assertEquals(1, data.workOrders.size());
        System.assert(data.workOrders[0].relatedLabel.startsWith('SA '));
        System.assert(data.workOrders[0].actionLabel.contains(String.valueOf(sa.SchedStartTime.year())));
        System.assert(data.interactions.size() >= 1);
        Boolean foundOpportunityEmail = false;
        for (HomeownerAccountPageController.RowData interactionRow : data.interactions) {
            if (interactionRow.subjectText == 'Outdoor Living proposal' && interactionRow.interactionType == 'Email') {
                foundOpportunityEmail = true;
                break;
            }
        }
        System.assertEquals(true, foundOpportunityEmail);
        System.assertEquals('Custom Design Build Opportunity', data.propertyContext.projectLabel);
        System.assertEquals('4217 Test Court', data.propertyContext.propertyLabel);
        System.assertEquals('Design Build', data.propertyContext.packageName);
        System.assertEquals(1, data.designReviews.size());
        System.assertEquals('Approved', data.designReviews[0].status);
        System.assertEquals(1, data.paymentMilestones.size());
        System.assertEquals('Deposit', data.paymentMilestones[0].label);
        System.assertEquals(1, data.files.size());
        System.assertEquals(1, data.notes.size());
        System.assertEquals('Welcome Call Notes', data.notes[0].label);
        System.assertEquals(0, data.kpis.openTasks);

        System.assertEquals(0, data.missingData.size());
    }

    @IsTest
    static void testActiveWorkOrdersResolveByContactAndDeduplicate() {
        Account homeowner = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Dedup',
            PersonEmail = 'dedup@example.com',
            Type = 'Home Owner'
        );
        insert homeowner;

        Account builder = new Account(Name = 'Builder Anchor');
        insert builder;

        OperatingHours hours = new OperatingHours(Name = 'Work Order Contact Test Hours', TimeZone = 'America/New_York');
        insert hours;

        ServiceTerritory territory = new ServiceTerritory(
            Name = 'Work Order Contact Test Territory',
            OperatingHoursId = hours.Id,
            IsActive = true
        );
        insert territory;

        Opportunity opp = new Opportunity(
            Name = 'Dedup UMB Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            AccountId = homeowner.Id,
            Type = 'UMB'
        );
        insert opp;

        WorkOrder wo = new WorkOrder(
            AccountId = homeowner.Id,
            ContactId = homeowner.PersonContactId,
            Subject = 'Homeowner-facing install',
            Status = 'New',
            Work_Order_Type__c = 'Production Install',
            RecordTypeId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId(),
            ServiceTerritoryId = territory.Id
        );
        if (WorkOrder.SObjectType.getDescribe().fields.getMap().containsKey('Opportunity__c')) {
            wo.put('Opportunity__c', opp.Id);
        }
        insert wo;

        WorkOrder unrelated = new WorkOrder(
            AccountId = builder.Id,
            Subject = 'Builder only install',
            Status = 'New',
            Work_Order_Type__c = 'Production Install',
            RecordTypeId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId(),
            ServiceTerritoryId = territory.Id
        );
        insert unrelated;

        Test.startTest();
        HomeownerAccountPageController.PageData data = HomeownerAccountPageController.getPageData(homeowner.Id);
        Test.stopTest();

        System.assertEquals(1, data.workOrders.size());
        System.assertEquals(wo.Id, data.workOrders[0].id);
        System.assert(
            data.workOrders[0].relationshipSource == 'ContactId' ||
            data.workOrders[0].relationshipSource == 'Opportunity__c'
        );
        System.assertEquals('Homeowner-facing install', data.workOrders[0].label);
        System.assertEquals(1, data.kpis.openWorkOrders);
    }

    @IsTest
    static void testActiveWorkOrdersOpportunityPathAndAccountFallback() {
        Account homeowner = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Fallback',
            PersonEmail = 'fallback@example.com',
            Type = 'Home Owner'
        );
        insert homeowner;

        OperatingHours hours = new OperatingHours(Name = 'Work Order Fallback Test Hours', TimeZone = 'America/New_York');
        insert hours;

        ServiceTerritory territory = new ServiceTerritory(
            Name = 'Work Order Fallback Test Territory',
            OperatingHoursId = hours.Id,
            IsActive = true
        );
        insert territory;

        Opportunity opp = new Opportunity(
            Name = 'Opportunity-linked Work',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = homeowner.Id,
            Type = 'New Business'
        );
        insert opp;

        WorkOrder accountFallback = new WorkOrder(
            AccountId = homeowner.Id,
            Subject = 'Account fallback work order',
            Status = 'New',
            Work_Order_Type__c = 'Customer Care',
            RecordTypeId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Customer_Care').getRecordTypeId(),
            ServiceTerritoryId = territory.Id
        );
        insert accountFallback;

        WorkOrder opportunityLinked;
        if (WorkOrder.SObjectType.getDescribe().fields.getMap().containsKey('Opportunity__c')) {
            opportunityLinked = new WorkOrder(
                AccountId = homeowner.Id,
                Subject = 'Opportunity linked work order',
                Status = 'New',
                Work_Order_Type__c = 'Production Install',
                RecordTypeId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId(),
                ServiceTerritoryId = territory.Id
            );
            opportunityLinked.put('Opportunity__c', opp.Id);
            insert opportunityLinked;
        }

        Test.startTest();
        HomeownerAccountPageController.PageData data = HomeownerAccountPageController.getPageData(homeowner.Id);
        Test.stopTest();

        Set<Id> returnedIds = new Set<Id>();
        Map<Id, String> sourceById = new Map<Id, String>();
        for (HomeownerAccountPageController.RowData row : data.workOrders) {
            returnedIds.add(row.id);
            sourceById.put(row.id, row.relationshipSource);
        }

        System.assert(returnedIds.contains(accountFallback.Id));
        System.assertEquals('AccountId', sourceById.get(accountFallback.Id));

        if (opportunityLinked != null) {
            System.assert(returnedIds.contains(opportunityLinked.Id));
            System.assertEquals('Opportunity__c', sourceById.get(opportunityLinked.Id));
        }
    }

    @IsTest
    static void testCreateScheduledInteractionCallVirtualAndErrors() {
        Account acct = new Account(
            Name = 'Schedule Test Builder'
        );
        insert acct;

        Test.startTest();
        HomeownerAccountPageController.ScheduledInteractionResult callResult = HomeownerAccountPageController.createScheduledInteraction(
            acct.Id,
            'call',
            System.now().addDays(1),
            null,
            'Confirm appointment window'
        );
        HomeownerAccountPageController.ScheduledInteractionResult virtualResult = HomeownerAccountPageController.createScheduledInteraction(
            acct.Id,
            'virtual',
            System.now().addDays(3),
            60,
            'Review design mockups'
        );
        Test.stopTest();

        Map<Id, Event> eventsById = new Map<Id, Event>([
            SELECT Id, Subject, Type, Location, Description, WhoId, DurationInMinutes
            FROM Event
            WHERE Id IN :new Set<Id>{ callResult.eventId, virtualResult.eventId }
        ]);

        Event callEvent = eventsById.get(callResult.eventId);
        System.assertEquals('Call', callEvent.Subject);
        System.assertEquals('Call', callEvent.Type);
        System.assertEquals(null, callEvent.WhoId);
        System.assertEquals(30, callEvent.DurationInMinutes);
        System.assert(callEvent.Description.contains('Call summary'));

        Event virtualEvent = eventsById.get(virtualResult.eventId);
        System.assertEquals('Virtual Visit', virtualEvent.Subject);
        System.assertEquals('Meeting', virtualEvent.Type);
        System.assertEquals('Virtual', virtualEvent.Location);
        System.assert(virtualEvent.Description.contains('Visit notes'));
        System.assertEquals(false, callResult.confirmationSent);
        System.assertEquals(false, virtualResult.confirmationSent);

        Boolean missingAccountThrown = false;
        try {
            HomeownerAccountPageController.getPageData(null);
        } catch (AuraHandledException ex) {
            missingAccountThrown = true;
        }
        System.assertEquals(true, missingAccountThrown, 'Expected missing account Id exception.');

        Boolean unsupportedTypeThrown = false;
        try {
            HomeownerAccountPageController.createScheduledInteraction(
                acct.Id,
                'other',
                System.now().addDays(2),
                15,
                'Unsupported'
            );
        } catch (AuraHandledException ex) {
            unsupportedTypeThrown = true;
        }
        System.assertEquals(true, unsupportedTypeThrown, 'Expected unsupported interaction type exception.');
    }
}