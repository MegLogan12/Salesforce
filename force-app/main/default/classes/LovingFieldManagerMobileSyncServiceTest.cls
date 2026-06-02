@IsTest
private class LovingFieldManagerMobileSyncServiceTest {

    @TestSetup
    static void setupData() {
        Account account = new Account(Name = 'FM Mobile Sync Account');
        insert account;

        Community__c community = new Community__c(Name = 'FM Mobile Sync Community', Builder_Account__c = account.Id, FM_Assignment__c = UserInfo.getUserId());
        insert community;

        Lot__c lot = new Lot__c(Name = 'Lot 12', Community__c = community.Id);
        insert lot;

        OperatingHours hours = new OperatingHours(Name = 'FM Mobile Sync Hours', TimeZone = 'America/New_York');
        insert hours;
        ServiceTerritory territory = new ServiceTerritory(Name = 'FM Mobile Sync Territory', OperatingHoursId = hours.Id, IsActive = true);
        insert territory;

        update new Community__c(Id = community.Id, ServiceTerritory__c = territory.Id);

        ServiceResource resource = new ServiceResource(Name = 'FM Mobile Sync Resource', ResourceType = 'T', RelatedRecordId = UserInfo.getUserId(), IsActive = true);
        insert resource;
        insert new ServiceTerritoryMember(
            ServiceTerritoryId = territory.Id,
            ServiceResourceId = resource.Id,
            EffectiveStartDate = System.now().addDays(-2)
        );
    }

    private static Community__c community() {
        return [SELECT Id, Builder_Account__c FROM Community__c WHERE Name = 'FM Mobile Sync Community' LIMIT 1];
    }

    private static Lot__c lot() {
        return [SELECT Id FROM Lot__c WHERE Name = 'Lot 12' LIMIT 1];
    }

    @IsTest
    static void takeoffSyncCreatesWorkOrderAndAppointment() {
        Community__c c = community();
        Lot__c l = lot();

        insert new Takeoff__c(
            Community__c = c.Id,
            Lot__c = l.Id,
            Status__c = 'In Progress',
            FM_Assignment__c = UserInfo.getUserId(),
            Scheduled_Date__c = Date.today(),
            Notes__c = 'Takeoff mobile test'
        );

        WorkOrder wo = [
            SELECT Id, Subject, Field_Manager__c, Lot__c
            FROM WorkOrder
            WHERE Subject LIKE 'Takeoff |%'
            LIMIT 1
        ];
        System.assertEquals(UserInfo.getUserId(), wo.Field_Manager__c);

        ServiceAppointment sa = [
            SELECT Id, ParentRecordId, Status, Subject
            FROM ServiceAppointment
            WHERE ParentRecordId = :wo.Id
            LIMIT 1
        ];
        System.assertEquals('Scheduled', sa.Status);
        System.assertEquals(true, sa.Subject.startsWith('Takeoff |'));
        System.assertEquals(1, [SELECT COUNT() FROM AssignedResource WHERE ServiceAppointmentId = :sa.Id]);
    }

    @IsTest
    static void aquaPickupSyncCreatesMissingWorkTypeAndAppointment() {
        Community__c c = community();
        Lot__c l = lot();

        insert new Aqua_Pickup_Ticket__c(
            Lot__c = l.Id,
            Assigned_To__c = UserInfo.getUserId(),
            Status__c = 'Open',
            Scheduled_Date__c = Date.today().addDays(1)
        );

        WorkType wt = [SELECT Id, Name FROM WorkType WHERE Name = 'Aqua Pickup' LIMIT 1];
        System.assertEquals('Aqua Pickup', wt.Name);

        WorkOrder wo = [
            SELECT Id, Subject, Field_Manager__c, WorkTypeId, Work_Order_Type__c
            FROM WorkOrder
            WHERE Subject LIKE 'Aqua Pickup |%'
            LIMIT 1
        ];
        System.assertEquals(UserInfo.getUserId(), wo.Field_Manager__c);
        System.assertEquals('Aqua Pickup', wo.Work_Order_Type__c);
        System.assertEquals(wt.Id, wo.WorkTypeId);

        ServiceAppointment sa = [
            SELECT Id, ParentRecordId, WorkTypeId
            FROM ServiceAppointment
            WHERE ParentRecordId = :wo.Id
            LIMIT 1
        ];
        System.assertEquals(wt.Id, sa.WorkTypeId);
    }

    @IsTest
    static void aquaCheckSyncCreatesAppointment() {
        Lot__c l = lot();

        insert new Aqua_Check_Ticket__c(
            Lot__c = l.Id,
            Assigned_To__c = UserInfo.getUserId(),
            Status__c = 'Open',
            Scheduled_Date__c = Date.today()
        );

        WorkOrder wo = [
            SELECT Id, Subject, Work_Order_Type__c
            FROM WorkOrder
            WHERE Subject LIKE 'Aqua Check |%'
            LIMIT 1
        ];
        System.assertEquals('Aqua Check', wo.Work_Order_Type__c);
        System.assertEquals(1, [SELECT COUNT() FROM ServiceAppointment WHERE ParentRecordId = :wo.Id]);
    }

    @IsTest
    static void workOrderSyncCreatesSiteReadinessAppointment() {
        Community__c c = community();
        ServiceTerritory territory = [SELECT Id FROM ServiceTerritory WHERE Name = 'FM Mobile Sync Territory' LIMIT 1];
        Id prodRt = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId();

        WorkOrder wo = new WorkOrder(
            RecordTypeId = prodRt,
            Subject = 'WO Site Readiness',
            Status = 'Site Readiness',
            AccountId = c.Builder_Account__c,
            Lot__c = lot().Id,
            Field_Manager__c = UserInfo.getUserId(),
            Work_Order_Type__c = 'Production Install',
            ServiceTerritoryId = territory.Id,
            Site_Readiness_Date__c = Date.today().addDays(2)
        );
        insert wo;

        ServiceAppointment sa = [
            SELECT Id, ParentRecordId, Subject, WorkType.Name, ServiceTerritoryId
            FROM ServiceAppointment
            WHERE ParentRecordId = :wo.Id
            LIMIT 1
        ];
        System.assertEquals('Field Manager 48-Hour Site Visit', sa.WorkType.Name);
        System.assertEquals(territory.Id, sa.ServiceTerritoryId);
        System.assertEquals(true, sa.Subject.startsWith('Site Readiness |'));
    }

    @IsTest
    static void workOrderSyncCreatesFmReviewAppointment() {
        Community__c c = community();
        ServiceTerritory territory = [SELECT Id FROM ServiceTerritory WHERE Name = 'FM Mobile Sync Territory' LIMIT 1];
        Id prodRt = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId();

        WorkOrder wo = new WorkOrder(
            RecordTypeId = prodRt,
            Subject = 'WO FM Review',
            Status = 'FM/QI Review',
            AccountId = c.Builder_Account__c,
            Lot__c = lot().Id,
            Field_Manager__c = UserInfo.getUserId(),
            Work_Order_Type__c = 'Production Install',
            ServiceTerritoryId = territory.Id
        );
        insert wo;

        ServiceAppointment sa = [
            SELECT Id, ParentRecordId, Subject, WorkType.Name
            FROM ServiceAppointment
            WHERE ParentRecordId = :wo.Id
            LIMIT 1
        ];
        System.assertEquals('Field Manager Quality Inspection', sa.WorkType.Name);
        System.assertEquals(true, sa.Subject.startsWith('FM Review |'));
    }

    @IsTest
    static void backfillOpenQueuesCreatesRowsForExistingRecords() {
        Community__c c = community();
        Lot__c l = lot();

        insert new Takeoff__c(
            Community__c = c.Id,
            Lot__c = l.Id,
            Status__c = 'Draft',
            FM_Assignment__c = UserInfo.getUserId(),
            Scheduled_Date__c = Date.today().addDays(3)
        );

        Test.startTest();
        LovingFieldManagerMobileSyncService.backfillOpenQueues();
        Test.stopTest();

        System.assert([SELECT COUNT() FROM WorkOrder WHERE Subject LIKE 'Takeoff |%'] > 0);
    }
}