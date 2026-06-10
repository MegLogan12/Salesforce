@IsTest
private class LovingFmWorkspaceControllerTest {

    @TestSetup
    static void setupData() {
        Profile profile = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
        User fmUser = new User(
            Alias = 'fmgr',
            Email = 'fieldmanager' + DateTime.now().getTime() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'FieldManager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'fieldmanager' + DateTime.now().getTime() + '@example.com'
        );
        insert fmUser;

        Account account = new Account(Name = 'FM Workspace Account');
        if (Schema.SObjectType.Account.fields.getMap().containsKey('Account_Status__c')) account.put('Account_Status__c', 'Active');
        if (Schema.SObjectType.Account.fields.getMap().containsKey('Scope_Of_Work_Link__c')) account.put('Scope_Of_Work_Link__c', 'https://drive.example.com/sow');
        if (Schema.SObjectType.Account.fields.getMap().containsKey('BMG_Link__c')) account.put('BMG_Link__c', 'https://drive.example.com/bmg');
        if (Schema.SObjectType.Account.fields.getMap().containsKey('Contract_Link__c')) account.put('Contract_Link__c', 'https://drive.example.com/contract');
        insert account;

        Product2 product = new Product2(Name = 'FM Workspace Product', ProductCode = 'FM-WS-1', IsActive = true);
        insert product;
        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            UnitPrice = 15,
            IsActive = true
        );
        insert entry;

        OperatingHours hours = new OperatingHours(Name = 'FM Workspace Hours', TimeZone = 'America/New_York');
        insert hours;
        ServiceTerritory territory = new ServiceTerritory(Name = 'FM Workspace Territory', OperatingHoursId = hours.Id, IsActive = true);
        insert territory;
        WorkType workType = new WorkType(Name = 'FM Workspace WorkType', EstimatedDuration = 90, DurationType = 'Minutes');
        insert workType;

        Id installRt = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId();
        WorkOrder scheduledWo = new WorkOrder(
            RecordTypeId = installRt,
            Subject = 'FM Scheduled Install',
            Status = 'New',
            AccountId = account.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Work_Order_Type__c = 'Production Install',
            Takeoff_Completed__c = true,
            Field_Manager__c = fmUser.Id,
            Lot_Number__c = '21'
        );
        insert scheduledWo;

        Datetime startTime = Datetime.newInstance(Date.today(), Time.newInstance(9, 0, 0, 0));
        ServiceAppointment appointment = new ServiceAppointment(
            ParentRecordId = scheduledWo.Id,
            Subject = 'FM Scheduled Appointment',
            Status = 'Scheduled',
            WorkTypeId = workType.Id,
            ServiceTerritoryId = territory.Id,
            Duration = 90,
            DurationType = 'Minutes',
            SchedStartTime = startTime,
            SchedEndTime = startTime.addMinutes(90)
        );
        insert appointment;

        insert new WorkOrderLineItem(
            WorkOrderId = scheduledWo.Id,
            PricebookEntryId = entry.Id,
            Description = 'Install scope',
            Quantity = 12,
            UnitPrice = 15,
            Status = 'New'
        );

        insert new Schedule_Issue__c(
            Status__c = 'Open',
            Issue_Type__c = 'Other',
            Summary__c = 'Blocked gate',
            Standard_WorkOrder__c = scheduledWo.Id
        );

        WorkOrder readinessWo = new WorkOrder(
            RecordTypeId = installRt,
            Subject = 'FM Site Readiness',
            Status = 'Site Readiness',
            AccountId = account.Id,
            Work_Order_Type__c = 'Production Install',
            Takeoff_Completed__c = true,
            Field_Manager__c = fmUser.Id,
            Lot_Number__c = '22'
        );
        insert readinessWo;

        insert new Takeoff__c(
            Status__c = 'In Progress',
            FM_Assignment__c = fmUser.Id,
            Scheduled_Date__c = Date.today()
        );

        insert new Aqua_Check_Ticket__c(
            Assigned_To__c = fmUser.Id,
            Status__c = 'Open',
            Scheduled_Date__c = Date.today()
        );

        insert new Aqua_Pickup_Ticket__c(
            Assigned_To__c = fmUser.Id,
            Status__c = 'Open',
            Scheduled_Date__c = Date.today().addDays(1)
        );
    }

    private static User fmUser() {
        return [SELECT Id FROM User WHERE LastName = 'FieldManager' LIMIT 1];
    }

    @IsTest
    static void getWorkspaceDataReturnsFieldManagerQueues() {
        Test.startTest();
        System.runAs(fmUser()) {
            LovingFieldManagerWorkspaceController.WorkspaceData data =
                LovingFieldManagerWorkspaceController.getWorkspaceData();

            System.assertNotEquals(null, data);
            System.assertEquals(true, data.metrics.size() >= 6);
            System.assert(data.scheduleRows.size() >= 4, 'Expected at least 4 schedule rows (1 appointment, 1 site-readiness WO, 2 Aqua); got ' + data.scheduleRows.size());
            System.assertEquals(1, data.takeoffRows.size());
            System.assert(data.siteReadinessRows.size() >= 1, 'Expected at least 1 site-readiness row; got ' + data.siteReadinessRows.size());
            System.assertEquals(2, data.aquaRows.size());
            System.assert(data.foremanRows.size() >= 2, 'Expected at least 2 foreman rows (1 per test WO); got ' + data.foremanRows.size());
            System.assertEquals(0, data.approvalRows.size());

            Boolean foundAppointment = false;
            for (LovingFieldManagerWorkspaceController.RowDto row : data.scheduleRows) {
                if (row.source == 'ServiceAppointment') {
                    foundAppointment = true;
                    System.assertEquals('Production Install', row.workType);
                    System.assertEquals(1, row.lineItemCount);
                    System.assertEquals(1, row.issueCount);
                }
            }
            System.assertEquals(true, foundAppointment, 'Standard Service Appointment row should be present.');
        }
        Test.stopTest();
    }

    @IsTest
    static void getWorkspaceDataAddsWarningsWhenNoOwnedRecords() {
        Profile profile = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
        User blankUser = new User(
            Alias = 'fmgr2',
            Email = 'fieldmanagerblank' + DateTime.now().getTime() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'FieldManagerBlank',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'fieldmanagerblank' + DateTime.now().getTime() + '@example.com'
        );
        insert blankUser;

        System.runAs(blankUser) {
            LovingFieldManagerWorkspaceController.WorkspaceData data =
                LovingFieldManagerWorkspaceController.getWorkspaceData();
            System.assertEquals(0, data.scheduleRows.size());
            System.assertEquals(true, data.warnings.size() >= 1);
        }
    }
}