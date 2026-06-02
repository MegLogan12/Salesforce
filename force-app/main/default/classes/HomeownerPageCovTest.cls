@IsTest
private class HomeownerPageCovTest {
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
            Type = 'UMB'
        );
        insert opp;

        insert new Case(
            AccountId = acct.Id,
            Subject = 'Warranty Review',
            Status = 'New',
            Origin = 'Phone'
        );

        insert new Event(
            WhatId = acct.Id,
            WhoId = acct.PersonContactId,
            Subject = 'Call',
            Type = 'Call',
            ActivityDateTime = System.now().addDays(1),
            DurationInMinutes = 30,
            Description = 'Call summary:\nReview design notes'
        );

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
    static void testCreateScheduledInteractionPaths() {
        Account acct = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            LastName = 'Brooks',
            PersonEmail = 'jamie@example.com',
            Type = 'Home Owner'
        );
        insert acct;
        acct = [SELECT Id, PersonContactId FROM Account WHERE Id = :acct.Id];

        Test.startTest();
        HomeownerAccountPageController.ScheduledInteractionResult onsiteResult = HomeownerAccountPageController.createScheduledInteraction(
            acct.Id,
            'onsite',
            System.now().addDays(2),
            45,
            'Review patio layout and scope.'
        );
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
            SELECT Id, Subject, Type, Location, Description, WhatId, WhoId, DurationInMinutes
            FROM Event
            WHERE Id IN :new Set<Id>{ onsiteResult.eventId, callResult.eventId, virtualResult.eventId }
        ]);

        System.assertEquals('Onsite Visit', eventsById.get(onsiteResult.eventId).Subject);
        System.assertEquals(45, eventsById.get(onsiteResult.eventId).DurationInMinutes);
        System.assertEquals(acct.PersonContactId, eventsById.get(onsiteResult.eventId).WhoId);
        System.assertEquals('Call', eventsById.get(callResult.eventId).Subject);
        System.assertEquals(30, eventsById.get(callResult.eventId).DurationInMinutes);
        System.assertEquals('Virtual Visit', eventsById.get(virtualResult.eventId).Subject);
        System.assertEquals('Virtual', eventsById.get(virtualResult.eventId).Location);
    }

    @IsTest
    static void testSecondaryContactFallbackAndErrors() {
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
        Boolean missingAccountThrown = false;
        try {
            HomeownerAccountPageController.getPageData(null);
        } catch (AuraHandledException ex) {
            missingAccountThrown = true;
        }
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
        Test.stopTest();

        Event created = [SELECT Id, WhoId, Subject FROM Event WHERE Id = :result.eventId];
        System.assertEquals(spouse.Id, created.WhoId);
        System.assertEquals('Virtual Visit', created.Subject);
        System.assertEquals(true, missingAccountThrown);
        System.assertEquals(true, unsupportedTypeThrown);
    }

    @IsTest
    static void testWorkOrderResolutionPaths() {
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

        insert new WorkOrder(
            AccountId = builder.Id,
            Subject = 'Builder only install',
            Status = 'New',
            Work_Order_Type__c = 'Production Install',
            RecordTypeId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId(),
            ServiceTerritoryId = territory.Id
        );

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

        System.assert(returnedIds.contains(wo.Id));
        System.assert(returnedIds.contains(accountFallback.Id));
        System.assertEquals('AccountId', sourceById.get(accountFallback.Id));
        if (opportunityLinked != null) {
            System.assert(returnedIds.contains(opportunityLinked.Id));
            System.assertEquals('Opportunity__c', sourceById.get(opportunityLinked.Id));
        }
    }
}