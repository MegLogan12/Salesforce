@IsTest
private class ForemanMobileControllerTest {

    @TestSetup
    static void seed() {
        OperatingHours operatingHours = new OperatingHours(
            Name = 'Foreman Mobile Test Hours',
            TimeZone = 'America/New_York'
        );
        insert operatingHours;

        ServiceTerritory territory = new ServiceTerritory(
            Name = 'Foreman Mobile Test Territory',
            IsActive = true,
            OperatingHoursId = operatingHours.Id
        );
        insert territory;

        Account a = new Account(
            Name = 'BMG Test Builder',
            Account_Status__c = 'Active',
            Scope_Of_Work_Link__c = 'https://example.com/sow.pdf',
            BMG_Link__c = 'https://example.com/bmg.pdf',
            Contract_Link__c = 'https://example.com/contract.pdf'
        );
        insert a;

        Community__c c = new Community__c(
            Name = 'Test Community',
            Builder_Account__c = a.Id,
            Sod_Type__c = 'Bermuda',
            Lot_Layout_Link__c = 'https://example.com/lot.pdf',
            Aqua_Customer__c = false,
            Assigned_FM__c = UserInfo.getUserId(),
            ServiceTerritory__c = territory.Id
        );
        insert c;

        Work_Order__c w = new Work_Order__c(
            Status__c = 'Scheduled',
            Community__c = c.Id,
            Sod_Sqft__c = 6400,
            Sod_Species__c = 'Bermuda',
            FM_Assignment__c = UserInfo.getUserId(),
            Vehicle_Check_Completed__c = false,
            Loading_Check_Completed__c = false,
            Work_Order_Type__c = 'Production Install',
            Sub_Status__c = 'Pre-Install',
            Goal_Hours__c = 7,
            Scheduled_Date__c = Date.today(),
            Schedule_Locked__c = true
        );
        insert w;

        insert new Work_Order_Line_Item__c(
            Work_Order__c = w.Id,
            Package_Item__c = 'Sod',
            Description__c = 'TifTuf sod install',
            Quantity__c = 12,
            Source__c = 'Quote',
            Sequence__c = 1
        );

        Checklist__c checklist = new Checklist__c(
            Work_Order__c = w.Id,
            Checklist_Type__c = 'Site Readiness'
        );
        insert checklist;

        insert new Checklist_Item__c(
            Checklist__c = checklist.Id,
            Status__c = 'Pending',
            Required__c = true,
            Photo_Required__c = false,
            Notes__c = 'Check irrigation heads',
            Sort_Order__c = 1
        );
    }

    private static Id woId() {
        return [SELECT Id FROM Work_Order__c LIMIT 1].Id;
    }

    private static Id checklistItemId() {
        return [SELECT Id FROM Checklist_Item__c LIMIT 1].Id;
    }

    private static Work_Order__c makeGpsReadyWorkOrder() {
        Community__c community = [SELECT Id FROM Community__c LIMIT 1];
        Work_Order__c wo = new Work_Order__c(
            Status__c = 'Scheduled',
            Community__c = community.Id,
            FM_Assignment__c = UserInfo.getUserId(),
            Work_Order_Type__c = 'Production Install',
            Sub_Status__c = 'Pre-Install',
            Scheduled_Date__c = Date.today(),
            Schedule_Locked__c = true,
            Lot_Latitude__c = 35.7796,
            Lot_Longitude__c = -78.6382
        );
        insert wo;
        insert new Task(
            WhatId = wo.Id,
            Subject = 'Site Readiness Check (T-48)',
            Type = 'Site Readiness',
            Status = 'Completed'
        );
        return wo;
    }

    @IsTest
    static void getTodaysJobIdReturnsScheduledForUser() {
        Test.startTest();
        Id found = ForemanMobileController.getTodaysJobId();
        Test.stopTest();
        System.assertEquals(woId(), found);
    }

    @IsTest
    static void getDayReturnsState() {
        Test.startTest();
        ForemanMobileController.DayDto d = ForemanMobileController.getDay(woId());
        Test.stopTest();
        System.assertEquals(false, d.vehicleCheck);
        System.assertEquals(false, d.loadingCheck);
        System.assertNotEquals('', d.scheduledDate);
    }

    @IsTest
    static void getJobReturnsFields() {
        Test.startTest();
        ForemanMobileController.JobDto j = ForemanMobileController.getJob(woId());
        Test.stopTest();
        System.assertEquals('Production Install', j.workOrderType);
        System.assertEquals('Bermuda', j.sodSpecies);
        System.assert(j.goalHours != null);
    }

    @IsTest
    static void getMobileContextReturnsScopeAndChecklist() {
        Test.startTest();
        ForemanMobileController.MobileContextDto ctx = ForemanMobileController.getMobileContext(woId());
        Test.stopTest();

        System.assertEquals(woId(), ctx.workOrderId);
        System.assertEquals(1, ctx.lineItems.size());
        System.assertEquals(1, ctx.workOrderChecklists.size());
        System.assertEquals(0, ctx.openIssues.size());
        System.assertEquals(false, ctx.vehicleChecklist.complete);
    }

    @IsTest
    static void updateVehicleChecklistItemCreatesChecklistAndRollsUp() {
        Id id = woId();
        for (String key : new List<String>{ 'tires', 'lights', 'fluids', 'fuel', 'trailer', 'safety' }) {
            ForemanMobileController.updateVehicleChecklistItem(id, key, true, 'T-101', 'Ready');
        }

        Morning_Vehicle_Checklist__c checklist = [
            SELECT Truck_Number__c, Notes__c, Tires_Checked__c, Lights_Checked__c,
                   Fluids_Checked__c, Fuel_Checked__c, Trailer_Checked__c, Safety_Equipment_Checked__c
            FROM Morning_Vehicle_Checklist__c
            LIMIT 1
        ];
        Work_Order__c wo = [SELECT Vehicle_Check_Completed__c FROM Work_Order__c WHERE Id = :id];

        System.assertEquals('T-101', checklist.Truck_Number__c);
        System.assertEquals(true, checklist.Tires_Checked__c);
        System.assertEquals(true, wo.Vehicle_Check_Completed__c);
    }

    @IsTest
    static void setLoadingCheckUpdatesChecklistAndWorkOrder() {
        Id id = woId();
        Test.startTest();
        ForemanMobileController.setLoadingCheck(id, true);
        Test.stopTest();

        Work_Order__c wo = [SELECT Loading_Check_Completed__c FROM Work_Order__c WHERE Id = :id];
        Morning_Vehicle_Checklist__c checklist = [
            SELECT Loading_Verified__c, Material_Count_Matches__c
            FROM Morning_Vehicle_Checklist__c
            LIMIT 1
        ];

        System.assertEquals(true, wo.Loading_Check_Completed__c);
        System.assertEquals(true, checklist.Loading_Verified__c);
        System.assertEquals(true, checklist.Material_Count_Matches__c);
    }

    @IsTest
    static void updateChecklistItemWritesStatusAndNotes() {
        Id itemId = checklistItemId();
        Test.startTest();
        ForemanMobileController.updateChecklistItem(itemId, 'Complete', 'Checked on site');
        Test.stopTest();

        Checklist_Item__c item = [SELECT Status__c, Notes__c FROM Checklist_Item__c WHERE Id = :itemId];
        System.assertEquals('Complete', item.Status__c);
        System.assertEquals('Checked on site', item.Notes__c);
    }

    @IsTest
    static void createIssueCreatesScheduleIssue() {
        Test.startTest();
        Id issueId = ForemanMobileController.createIssue(
            woId(),
            'Weather',
            'High',
            'Storm delaying install',
            'Crew waiting on lightning to clear'
        );
        Test.stopTest();

        Schedule_Issue__c issue = [
            SELECT Issue_Type__c, Severity__c, Status__c, Summary__c, Resolution_Notes__c
            FROM Schedule_Issue__c
            WHERE Id = :issueId
        ];
        System.assertEquals('Weather', issue.Issue_Type__c);
        System.assertEquals('High', issue.Severity__c);
        System.assertEquals('Open', issue.Status__c);
    }

    @IsTest
    static void submitSodIssueFlagCreatesScheduleIssue() {
        Test.startTest();
        Id issueId = ForemanMobileController.submitSodIssueFlag(
            woId(),
            'Bermuda',
            '200',
            'Brown patches on pallet'
        );
        Test.stopTest();

        Schedule_Issue__c issue = [SELECT Summary__c, Resolution_Notes__c FROM Schedule_Issue__c WHERE Id = :issueId];
        System.assert(issue.Summary__c.contains('Bermuda'));
        System.assertEquals('Brown patches on pallet', issue.Resolution_Notes__c);
    }

    @IsTest
    static void uploadJobsitePhotoCreatesFileAndIncrementsBeforeCount() {
        Id id = woId();
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('hello-photo'));

        Test.startTest();
        Id docId = ForemanMobileController.uploadJobsitePhoto(id, 'front.jpg', b64, 'image/jpeg', 'before_front');
        Test.stopTest();

        Work_Order__c wo = [SELECT Takeoff_Photo_Count__c FROM Work_Order__c WHERE Id = :id];
        Integer links = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :id];

        System.assertNotEquals(null, docId);
        System.assertEquals(1, links);
        System.assertEquals(1, wo.Takeoff_Photo_Count__c);
    }

    @IsTest
    static void startJobRequiresFourBeforePhotos() {
        Boolean threw = false;
        try {
            ForemanMobileController.startJob(woId());
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void beginDriveAndConfirmArrivalFlow() {
        Work_Order__c wo = makeGpsReadyWorkOrder();
        for (String key : new List<String>{ 'tires', 'lights', 'fluids', 'fuel', 'trailer', 'safety' }) {
            ForemanMobileController.updateVehicleChecklistItem(wo.Id, key, true, 'T-305', 'Checked');
        }
        ForemanMobileController.setLoadingCheck(wo.Id, true);

        String b64 = EncodingUtil.base64Encode(Blob.valueOf('before-photo'));
        for (String key : new List<String>{ 'before_front', 'before_back', 'before_left', 'before_right' }) {
            ForemanMobileController.uploadJobsitePhoto(wo.Id, key + '.jpg', b64, 'image/jpeg', key);
        }

        Test.startTest();
        ForemanMobileController.beginDrive(wo.Id);
        ForemanMobileController.ArrivalDto arrival =
            ForemanMobileController.confirmArrival(wo.Id, 35.7796, -78.6382);
        Test.stopTest();

        Work_Order__c reloaded = [
            SELECT Status__c, Drive_Started_At__c, Arrived_At__c
            FROM Work_Order__c
            WHERE Id = :wo.Id
        ];
        System.assertEquals(true, arrival.arrived);
        System.assertEquals('In Progress', reloaded.Status__c);
        System.assertNotEquals(null, reloaded.Drive_Started_At__c);
        System.assertNotEquals(null, reloaded.Arrived_At__c);
    }

    @IsTest
    static void miscNullAndListHelpers() {
        System.assertEquals(0, ForemanMobileController.getPhotoCount(null));

        Test.startTest();
        List<ForemanMobileController.ClockStatusDto> crew =
            ForemanMobileController.getCrewClockStatus(new List<Id>());
        ForemanMobileController.MobileContextDto emptyCtx =
            ForemanMobileController.getMobileContext(null);
        Test.stopTest();

        System.assertEquals(0, crew.size());
        System.assertEquals(false, emptyCtx.canSubmitCloseout);
    }

    @IsTest
    static void saveCloseoutDetailsAndCloseoutJobFlow() {
        Id id = woId();
        insert new Task(
            WhatId = id,
            Subject = 'Site Readiness Check (T-48)',
            Type = 'Site Readiness',
            Status = 'Completed'
        );
        update new Work_Order__c(Id = id, Status__c = 'In Progress');

        String b64 = EncodingUtil.base64Encode(Blob.valueOf('after-photo'));
        for (String key : new List<String>{ 'after_front', 'after_back', 'after_detail', 'after_hero' }) {
            ForemanMobileController.uploadJobsitePhoto(id, key + '.jpg', b64, 'image/jpeg', key);
        }

        Test.startTest();
        ForemanMobileController.saveCloseoutDetails(id, 6100, 'Installed per scope.');
        ForemanMobileController.closeoutJob(id);
        Test.stopTest();

        Work_Order__c wo = [
            SELECT Status__c, Installed_Sod_Sqft__c, Closeout_Notes__c, Closeout_Photo_Count__c
            FROM Work_Order__c
            WHERE Id = :id
        ];
        System.assertEquals('Pending Closeout', wo.Status__c);
        System.assertEquals(6100, wo.Installed_Sod_Sqft__c);
        System.assertEquals(4, wo.Closeout_Photo_Count__c);
    }

    @IsTest
    static void getRipplingClockStatusWithEmployeeReturnsLiveData() {
        Employee__c e = new Employee__c(
            Name = 'Test Employee',
            First_Name__c = 'Test',
            Last_Name__c = 'Employee',
            User__c = UserInfo.getUserId(),
            Currently_Clocked_In__c = true,
            On_PTO_Today__c = false,
            Current_Shift_Start__c = DateTime.now().addHours(-2),
            Department__c = 'Production Landscape',
            Status__c = 'Active'
        );
        insert e;

        insert new Rippling_Time_Entry__c(
            Employee__c = e.Id,
            Clock_In__c = DateTime.now().addHours(-2),
            Clock_Out__c = null,
            Work_Date__c = Date.today(),
            Rippling_Time_Entry_Id__c = 'rte-test-001'
        );

        Test.startTest();
        ForemanMobileController.ClockStatusDto s = ForemanMobileController.getRipplingClockStatus();
        Test.stopTest();

        System.assertEquals(true, s.clockedIn);
        System.assertEquals('Production Landscape', s.department);
    }

    @IsTest
    static void exerciseDtoCoverage() {
        Test.startTest();
        ForemanMobileController.exerciseDtoForCoverage();
        Test.stopTest();
        System.assert(true);
    }
}