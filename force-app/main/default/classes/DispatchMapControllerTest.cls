@IsTest
private class DispatchMapControllerTest {

    @TestSetup
    static void makeData() {
        // FSL managed-package constraints in this org:
        //   - WorkOrder triggers require SeeAllData=true (WorkOrderFieldManagerMobileSync)
        //   - ServiceAppointment with SchedStartTime requires >=1 ServiceTerritory visible
        //   - ServiceResource.RelatedRecordId (User) enforces a unique T-type-per-user constraint
        //     so we create an isolated test user rather than using UserInfo.getUserId()
        // Using Account as SA parent avoids the WorkOrder trigger entirely.

        OperatingHours oh = new OperatingHours(
            Name     = 'Dispatch Test OH',
            TimeZone = 'America/New_York'
        );
        insert oh;

        ServiceTerritory st = new ServiceTerritory(
            Name             = 'Dispatch Test Territory',
            IsActive         = true,
            OperatingHoursId = oh.Id
        );
        insert st;

        Account acct = new Account(Name = 'Dispatch Test Account');
        insert acct;

        Datetime tStart1 = Datetime.newInstance(Date.today(), Time.newInstance(9,  0, 0, 0));
        Datetime tEnd1   = Datetime.newInstance(Date.today(), Time.newInstance(10, 0, 0, 0));
        Datetime tStart2 = Datetime.newInstance(Date.today(), Time.newInstance(11, 0, 0, 0));
        Datetime tEnd2   = Datetime.newInstance(Date.today(), Time.newInstance(12, 0, 0, 0));

        ServiceAppointment sa1 = new ServiceAppointment(
            ParentRecordId = acct.Id,
            SchedStartTime = tStart1,
            SchedEndTime   = tEnd1,
            Duration       = 60,
            DurationType   = 'Minutes',
            Street         = '100 Main St',
            City           = 'Charlotte',
            State          = 'NC',
            Latitude       = 35.154,
            Longitude      = -80.852
        );
        ServiceAppointment sa2 = new ServiceAppointment(
            ParentRecordId = acct.Id,
            SchedStartTime = tStart2,
            SchedEndTime   = tEnd2,
            Duration       = 60,
            DurationType   = 'Minutes',
            Street         = '200 Oak Ave',
            City           = 'Charlotte',
            State          = 'NC',
            Latitude       = 35.162,
            Longitude      = -80.841
        );
        insert new List<ServiceAppointment>{ sa1, sa2 };

        // Create an isolated test user so T-type SR doesn't collide with
        // the running user's existing ServiceResource (DUPLICATE_VALUE constraint).
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Username         = 'dispatchtest.' + System.currentTimeMillis() + '@testloving.invalid',
            Email            = 'dispatchtest@testloving.invalid',
            LastName         = 'DriverZ',
            Alias            = 'drvz',
            ProfileId        = p.Id,
            TimeZoneSidKey   = 'America/New_York',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        ServiceResource srT = new ServiceResource(
            Name            = 'Test Driver Z',
            RelatedRecordId = testUser.Id,
            ResourceType    = 'T',
            IsActive        = true
        );
        insert srT;

        // FSL requires the SR to be a territory member before it can be assigned to an SA.
        insert new ServiceTerritoryMember(
            ServiceTerritoryId = st.Id,
            ServiceResourceId  = srT.Id,
            TerritoryType      = 'P',
            EffectiveStartDate = Date.today().addDays(-1)
        );

        insert new List<AssignedResource>{
            new AssignedResource(ServiceAppointmentId = sa1.Id, ServiceResourceId = srT.Id),
            new AssignedResource(ServiceAppointmentId = sa2.Id, ServiceResourceId = srT.Id)
        };
    }

    @IsTest
    static void testGetTodayDispatch_withData() {
        Test.startTest();
        List<DispatchMapController.TruckPin> pins = DispatchMapController.getTodayDispatch();
        Test.stopTest();

        System.assertNotEquals(null, pins, 'Result must not be null');
        System.assert(pins.size() >= 1, 'Expected at least one pin from test data');

        DispatchMapController.TruckPin first = pins[0];
        System.assertNotEquals(null, first.appointmentNumber, 'Pin must have appointment number');
        System.assertEquals('Charlotte', first.city, 'Pin city should be Charlotte');
    }

    @IsTest
    static void testGetTodayDispatch_driverAssignment() {
        Test.startTest();
        List<DispatchMapController.TruckPin> pins = DispatchMapController.getTodayDispatch();
        Test.stopTest();

        Boolean foundDriver = false;
        for (DispatchMapController.TruckPin p : pins) {
            if (p.driverName != null && p.driverName.contains('Test Driver Z')) {
                foundDriver = true;
            }
        }
        System.assert(foundDriver, 'At least one pin should have Test Driver Z as driverName');
    }

    @IsTest
    static void testGetTodayDispatch_returnsListNotNull() {
        Test.startTest();
        List<DispatchMapController.TruckPin> pins = DispatchMapController.getTodayDispatch();
        Test.stopTest();

        System.assertNotEquals(null, pins, 'getTodayDispatch must never return null');
    }
}
