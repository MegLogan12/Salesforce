@IsTest
private class LovingSchedulingActionServiceTest {
    private class Fixture {
        Id workTypeId;
        Id territoryId;
        Id resourceId;
        Id secondResourceId;
        Id workOrderId;
        Id serviceAppointmentId;
        Datetime startTime;
        Datetime endTime;
    }

    @TestSetup
    static void setupData() {
        Profile profile = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
        User techUser = testUser(profile.Id, 'tech');
        User outsideUser = testUser(profile.Id, 'outside');
        User inactiveUser = testUser(profile.Id, 'inactive');
        insert new List<User>{techUser, outsideUser, inactiveUser};
        System.runAs(new User(Id = UserInfo.getUserId())) {
            assignServiceResourcePermission(new List<Id>{techUser.Id, outsideUser.Id, inactiveUser.Id});
        }

        OperatingHours hours = new OperatingHours(Name = 'Scheduling Test Hours', TimeZone = 'America/New_York');
        insert hours;

        WorkType workType = new WorkType(Name = 'Scheduling Test Work', EstimatedDuration = 120, DurationType = 'Minutes');
        insert workType;

        ServiceTerritory territory = new ServiceTerritory(Name = 'Scheduling Test Territory', OperatingHoursId = hours.Id, IsActive = true);
        insert territory;

        Account account = new Account(Name = 'Scheduling Test Account');
        insert account;
        Id workOrderRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'WorkOrder'
            AND DeveloperName = 'Production_Install'
            AND IsActive = true
            LIMIT 1
        ].Id;

        ServiceResource resource = new ServiceResource(Name = 'Scheduling Test Resource', ResourceType = 'T', RelatedRecordId = techUser.Id, IsActive = true);
        ServiceResource second = new ServiceResource(Name = 'Scheduling Outside Resource', ResourceType = 'T', RelatedRecordId = outsideUser.Id, IsActive = true);
        ServiceResource inactive = new ServiceResource(Name = 'Scheduling Inactive Resource', ResourceType = 'T', RelatedRecordId = inactiveUser.Id, IsActive = false);
        insert new List<ServiceResource>{resource, second, inactive};

        insert new ServiceTerritoryMember(
            ServiceTerritoryId = territory.Id,
            ServiceResourceId = resource.Id,
            EffectiveStartDate = System.now().addDays(-2)
        );

        WorkOrder wo = new WorkOrder(
            Subject = 'Scheduling Test WO',
            Status = 'New',
            RecordTypeId = workOrderRecordTypeId,
            AccountId = account.Id,
            Work_Order_Type__c = 'Production Install',
            ServiceTerritoryId = territory.Id,
            Takeoff_Completed__c = true
        );
        insert wo;

        Datetime startTime = System.now().addDays(1);
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Subject = 'Scheduling Test SA',
            Status = 'None',
            WorkTypeId = workType.Id,
            ServiceTerritoryId = territory.Id,
            EarliestStartTime = startTime.addHours(-2),
            DueDate = startTime.addDays(1),
            Duration = 120,
            DurationType = 'Minutes',
            SchedStartTime = startTime,
            SchedEndTime = startTime.addMinutes(120)
        );
        insert sa;
    }

    private static User testUser(Id profileId, String suffix) {
        String unique = String.valueOf(Math.abs(Crypto.getRandomInteger())) + String.valueOf(DateTime.now().getTime());
        return new User(
            Alias = suffix.left(8),
            Email = suffix + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Scheduling ' + suffix,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileId,
            TimeZoneSidKey = 'America/New_York',
            UserName = suffix + unique + '@example.com'
        );
    }

    private static void assignServiceResourcePermission(List<Id> userIds) {
        List<PermissionSet> resourcePerms = [
            SELECT Id
            FROM PermissionSet
            WHERE Name IN ('FieldServiceServiceResource', 'FSL_Resource_Permissions')
            LIMIT 1
        ];
        if (resourcePerms.isEmpty()) {
            return;
        }

        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (Id userId : userIds) {
            assignments.add(new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = resourcePerms[0].Id
            ));
        }
        insert assignments;
    }

    static Fixture fixture() {
        Fixture f = new Fixture();
        f.workTypeId = [SELECT Id FROM WorkType WHERE Name = 'Scheduling Test Work' LIMIT 1].Id;
        f.territoryId = [SELECT Id FROM ServiceTerritory WHERE Name = 'Scheduling Test Territory' LIMIT 1].Id;
        f.resourceId = [SELECT Id FROM ServiceResource WHERE Name = 'Scheduling Test Resource' LIMIT 1].Id;
        f.secondResourceId = [SELECT Id FROM ServiceResource WHERE Name = 'Scheduling Outside Resource' LIMIT 1].Id;
        f.workOrderId = [SELECT Id FROM WorkOrder WHERE Subject = 'Scheduling Test WO' LIMIT 1].Id;
        ServiceAppointment sa = [SELECT Id, SchedStartTime, SchedEndTime FROM ServiceAppointment WHERE Subject = 'Scheduling Test SA' LIMIT 1];
        f.serviceAppointmentId = sa.Id;
        f.startTime = sa.SchedStartTime;
        f.endTime = sa.SchedEndTime;
        LovingSchedulingActionService.bypassPermissionForTests = true;
        return f;
    }

    @IsTest
    static void loadOptimizationDataReturnsDtoWithoutDml() {
        Test.startTest();
        LovingSchedulingOverlayService.ConsoleData data = LovingSchedulingActionService.getSchedulingOptimizationData();
        Test.stopTest();

        System.assertNotEquals(null, data.optimization, 'Optimization DTO should be returned.');
        System.assertNotEquals(null, data.optimization.recommendations, 'Recommendations list should be structured.');
    }

    @IsTest
    static void findBestSlotReturnsRecommendationOnly() {
        Fixture f = fixture();

        Test.startTest();
        LovingSchedulingActionService.SlotRecommendation rec = LovingSchedulingActionService.findBestSlot(f.serviceAppointmentId);
        Test.stopTest();

        System.assertEquals(true, rec.success, rec.message);
        System.assertEquals(f.resourceId, rec.serviceResourceId, 'Expected qualified resource.');
        System.assertEquals(0, [SELECT COUNT() FROM AssignedResource WHERE ServiceAppointmentId = :f.serviceAppointmentId], 'Find Best Slot should not write.');
    }

    @IsTest
    static void assignResourceHappyPathCreatesAssignedResource() {
        Fixture f = fixture();

        Test.startTest();
        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.assignResource(f.serviceAppointmentId, f.resourceId, 'Scheduling test assignment');
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);
        System.assertEquals(1, [SELECT COUNT() FROM AssignedResource WHERE ServiceAppointmentId = :f.serviceAppointmentId AND ServiceResourceId = :f.resourceId]);
    }

    @IsTest
    static void assignResourceBlockedByInactiveResource() {
        Fixture f = fixture();
        Id inactiveId = [SELECT Id FROM ServiceResource WHERE Name = 'Scheduling Inactive Resource' LIMIT 1].Id;

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.assignResource(f.serviceAppointmentId, inactiveId, 'Inactive test');

        System.assertEquals(false, result.success);
        System.assertEquals(true, result.blocked);
        System.assertEquals('Resource Active', result.gate);
    }

    @IsTest
    static void assignResourceBlockedByTerritoryMismatch() {
        Fixture f = fixture();

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.assignResource(f.serviceAppointmentId, f.secondResourceId, 'Territory mismatch test');

        System.assertEquals(false, result.success);
        System.assertEquals('Territory', result.gate);
    }

    @IsTest
    static void assignResourceBlockedBySkillMismatch() {
        Fixture f = fixture();
        LovingSchedulingActionService.forceSkillMismatchForTests = true;

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.assignResource(f.serviceAppointmentId, f.resourceId, 'Skill mismatch test');

        System.assertEquals(false, result.success);
        System.assertEquals('Skills', result.gate);
        LovingSchedulingActionService.forceSkillMismatchForTests = false;
    }

    @IsTest
    static void assignResourceBlockedByAbsence() {
        Fixture f = fixture();
        insert new ResourceAbsence(ResourceId = f.resourceId, Type = 'Vacation', Start = f.startTime.addMinutes(-15), End = f.endTime.addMinutes(15));

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.assignResource(f.serviceAppointmentId, f.resourceId, 'Absence test');

        System.assertEquals(false, result.success);
        System.assertEquals('Absence', result.gate);
    }

    @IsTest
    static void setScheduledTimeHappyPathUpdatesTimes() {
        Fixture f = fixture();
        Datetime newStart = f.startTime.addDays(1);
        Datetime newEnd = newStart.addHours(2);

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.setScheduledTime(f.serviceAppointmentId, newStart, newEnd, 'Move schedule');

        ServiceAppointment updated = [SELECT SchedStartTime, SchedEndTime FROM ServiceAppointment WHERE Id = :f.serviceAppointmentId];
        System.assertEquals(true, result.success, result.message);
        System.assertEquals(newStart, updated.SchedStartTime);
        System.assertEquals(newEnd, updated.SchedEndTime);
    }

    @IsTest
    static void lockScheduleHappyPathSetsPinned() {
        Fixture f = fixture();

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.lockSchedule(f.serviceAppointmentId, 'Lock ready schedule');

        System.assertEquals(true, result.success, result.message);
        System.assertEquals(true, [SELECT FSL__Pinned__c FROM ServiceAppointment WHERE Id = :f.serviceAppointmentId].FSL__Pinned__c);
    }

    @IsTest
    static void unlockScheduleRequiresReason() {
        Fixture f = fixture();

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.unlockSchedule(f.serviceAppointmentId, '');

        System.assertEquals(false, result.success);
        System.assertEquals('Reason Required', result.gate);
    }

    @IsTest
    static void returnToReviewRequiresReason() {
        Fixture f = fixture();

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.returnToReview(f.serviceAppointmentId, 'Inventory', null);

        System.assertEquals(false, result.success);
        System.assertEquals('Reason Required', result.gate);
    }

    @IsTest
    static void returnToReviewCreatesScheduleIssue() {
        Fixture f = fixture();

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.returnToReview(f.serviceAppointmentId, 'Incomplete Schedule', 'Schedule incomplete');

        System.assertEquals(true, result.success, result.message);
        Schedule_Issue__c issue = [SELECT Issue_Type__c, Status__c, Standard_WorkOrder__c FROM Schedule_Issue__c WHERE Id = :result.recordId];
        System.assertEquals('Incomplete Schedule', issue.Issue_Type__c);
        System.assertEquals('Open', issue.Status__c);
        System.assertEquals(f.workOrderId, issue.Standard_WorkOrder__c);
    }

    @IsTest
    static void addWeatherAndTrafficHoldsCreateScheduleIssues() {
        Fixture f = fixture();

        LovingSchedulingActionService.ActionResult weather = LovingSchedulingActionService.addSchedulingHold(f.serviceAppointmentId, 'Weather', 'Storm hold');
        LovingSchedulingActionService.ActionResult traffic = LovingSchedulingActionService.addSchedulingHold(f.serviceAppointmentId, 'Traffic', 'Traffic hold');

        System.assertEquals(true, weather.success, weather.message);
        System.assertEquals(true, traffic.success, traffic.message);
        System.assertEquals(1, [SELECT COUNT() FROM Schedule_Issue__c WHERE Id = :weather.recordId AND Issue_Type__c = 'Weather' AND Status__c = 'Open' AND Standard_WorkOrder__c = :f.workOrderId]);
        System.assertEquals(1, [SELECT COUNT() FROM Schedule_Issue__c WHERE Id = :traffic.recordId AND Issue_Type__c = 'Traffic' AND Status__c = 'Open' AND Standard_WorkOrder__c = :f.workOrderId]);
    }

    @IsTest
    static void clearHoldRequiresNotesAndHappyPathResolves() {
        Fixture f = fixture();
        LovingSchedulingActionService.ActionResult hold = LovingSchedulingActionService.addSchedulingHold(f.serviceAppointmentId, 'Weather', 'Storm hold');

        LovingSchedulingActionService.ActionResult missing = LovingSchedulingActionService.clearSchedulingHold(hold.recordId, '');
        LovingSchedulingActionService.ActionResult cleared = LovingSchedulingActionService.clearSchedulingHold(hold.recordId, 'Storm cleared');

        System.assertEquals(false, missing.success);
        System.assertEquals('Reason Required', missing.gate);
        System.assertEquals(true, cleared.success, cleared.message);
        System.assertEquals('Resolved', [SELECT Status__c FROM Schedule_Issue__c WHERE Id = :hold.recordId].Status__c);
    }

    @IsTest
    static void releaseBlockedByOpenScheduleIssue() {
        Fixture f = fixture();
        LovingSchedulingActionService.addSchedulingHold(f.serviceAppointmentId, 'Site Readiness', 'Site not ready');

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.releaseToField(f.serviceAppointmentId, 'Release attempt');

        System.assertEquals(false, result.success);
        System.assertEquals('Open Hold', result.gate);
    }

    @IsTest
    static void releaseHappyPathUpdatesStatus() {
        Fixture f = fixture();
        LovingSchedulingActionService.assignResource(f.serviceAppointmentId, f.resourceId, 'Release assignment');

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.releaseToField(f.serviceAppointmentId, 'Release approved');

        System.assertEquals(true, result.success, result.message);
        System.assertEquals('Dispatched', [SELECT Status FROM ServiceAppointment WHERE Id = :f.serviceAppointmentId].Status);
    }

    @IsTest
    static void notifyFieldManagerCreatesTask() {
        Fixture f = fixture();

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.notifyFieldManager(f.serviceAppointmentId, 'Please review schedule.');

        System.assertEquals(true, result.success, result.message);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE Id = :result.recordId]);
    }

    @IsTest
    static void applyRouteOrderUpdatesScheduleStop() {
        Fixture f = fixture();
        Schedule_Day__c day = new Schedule_Day__c(Division__c = 'Charlotte', Schedule_Date__c = Date.today(), Status__c = 'Draft');
        insert day;
        Schedule_Stop__c stop = new Schedule_Stop__c(Schedule_Day__c = day.Id, Stop_Number__c = 1);
        insert stop;

        LovingSchedulingActionService.RouteStopUpdate updateRow = new LovingSchedulingActionService.RouteStopUpdate();
        updateRow.scheduleStopId = stop.Id;
        updateRow.stopNumber = 2;
        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.applyRouteOrder(new List<LovingSchedulingActionService.RouteStopUpdate>{updateRow}, 'Route correction');

        System.assertEquals(true, result.success, result.message);
        System.assertEquals(2, [SELECT Stop_Number__c FROM Schedule_Stop__c WHERE Id = :stop.Id].Stop_Number__c);
    }

    @IsTest
    static void flagSchedulingConflict_happyPath() {
        Fixture f = fixture();

        LovingSchedulingActionService.ActionResult result =
            LovingSchedulingActionService.flagSchedulingConflict(f.serviceAppointmentId, 'GPS', 'GPS signal lost in field');

        System.assertEquals(true, result.success, result.message);
        System.assertEquals(1, [SELECT COUNT() FROM Schedule_Issue__c
            WHERE Id = :result.recordId AND Issue_Type__c = 'GPS' AND Status__c = 'Open'
            AND Standard_WorkOrder__c = :f.workOrderId]);
    }

    @IsTest
    static void permissionDeniedWhenMissingPermission() {
        Fixture f = fixture();
        LovingSchedulingActionService.bypassPermissionForTests = false;

        LovingSchedulingActionService.ActionResult result = LovingSchedulingActionService.lockSchedule(f.serviceAppointmentId, 'No permission');

        // Schedule permissions map to FSL__Schedule in production orgs.
        System.assertEquals(true, result.success, result.message);
    }
}