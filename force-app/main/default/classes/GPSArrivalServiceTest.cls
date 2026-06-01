@IsTest
private class GPSArrivalServiceTest {

    private static Work_Order__c makeLockedWorkOrder(Decimal lat, Decimal lng) {
        OperatingHours oh = new OperatingHours(Name = 'GPS Test Hours', TimeZone = 'America/New_York');
        insert oh;
        ServiceTerritory st = new ServiceTerritory(Name = 'GPS Test Territory', IsActive = true, OperatingHoursId = oh.Id);
        insert st;
        Account a = new Account(
            Name = 'GPS Test Builder',
            Account_Status__c = 'Active',
            Scope_Of_Work_Link__c = 'https://example.com/sow.pdf',
            BMG_Link__c = 'https://example.com/bmg.pdf',
            Contract_Link__c = 'https://example.com/contract.pdf'
        );
        insert a;
        Community__c c = new Community__c(Name = 'GPS Test Community', Builder_Account__c = a.Id, ServiceTerritory__c = st.Id, Aqua_Customer__c = false);
        insert c;
        Work_Order__c wo = new Work_Order__c(
            Status__c = 'Scheduled',
            Community__c = c.Id,
            FM_Assignment__c = UserInfo.getUserId(),
            Work_Order_Type__c = 'Production Install',
            Scheduled_Date__c = Date.today(),
            Schedule_Locked__c = true,
            Vehicle_Check_Completed__c = true,
            Loading_Check_Completed__c = true,
            Lot_Latitude__c = lat,
            Lot_Longitude__c = lng
        );
        insert wo;
        return wo;
    }

    @IsTest
    static void beginDriveSetsDriveStartedAt() {
        Work_Order__c wo = makeLockedWorkOrder(35.7796, -78.6382);
        Test.startTest();
        GPSArrivalService.beginDrive(wo.Id);
        Test.stopTest();
        wo = [SELECT Drive_Started_At__c FROM Work_Order__c WHERE Id = :wo.Id];
        System.assertNotEquals(null, wo.Drive_Started_At__c, 'Drive_Started_At__c should be set after beginDrive');
    }

    @IsTest
    static void beginDriveThrowsIfAlreadyStarted() {
        Work_Order__c wo = makeLockedWorkOrder(35.7796, -78.6382);
        GPSArrivalService.beginDrive(wo.Id);
        Boolean threw = false;
        Test.startTest();
        try {
            GPSArrivalService.beginDrive(wo.Id);
        } catch (GPSArrivalService.GPSException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Should throw GPSException when drive already started');
    }

    @IsTest
    static void beginDriveThrowsIfChecklistIncomplete() {
        Work_Order__c wo = makeLockedWorkOrder(35.7796, -78.6382);
        update new Work_Order__c(Id = wo.Id, Vehicle_Check_Completed__c = false);
        Boolean threw = false;
        try {
            GPSArrivalService.beginDrive(wo.Id);
        } catch (GPSArrivalService.GPSException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void processPingWithinGeofenceConfirmsArrival() {
        Work_Order__c wo = makeLockedWorkOrder(35.7796, -78.6382);
        Test.startTest();
        GPSArrivalService.PingResult result = GPSArrivalService.processPing(wo.Id, 35.7796, -78.6382);
        Test.stopTest();
        System.assertEquals(true, result.arrived, 'Same coordinates should confirm arrival');
        System.assertEquals('arrived', result.status);
        wo = [SELECT Status__c, Arrived_At__c FROM Work_Order__c WHERE Id = :wo.Id];
        System.assertEquals('In Progress', wo.Status__c);
        System.assertNotEquals(null, wo.Arrived_At__c);
    }

    @IsTest
    static void processPingOutsideGeofenceDoesNotConfirmArrival() {
        Work_Order__c wo = makeLockedWorkOrder(35.7796, -78.6382);
        // Charlotte to Raleigh - roughly 250km apart
        Test.startTest();
        GPSArrivalService.PingResult result = GPSArrivalService.processPing(wo.Id, 35.2271, -80.8431);
        Test.stopTest();
        System.assertEquals(false, result.arrived, 'Far coordinates should not confirm arrival');
        System.assertEquals('en_route', result.status);
        System.assert(result.distanceMeters > 150, 'Distance should exceed geofence radius');
    }

    @IsTest
    static void processPingWithNoLotCoordinatesReturnsNoGeofence() {
        Work_Order__c wo = makeLockedWorkOrder(null, null);
        Test.startTest();
        GPSArrivalService.PingResult result = GPSArrivalService.processPing(wo.Id, 35.7796, -78.6382);
        Test.stopTest();
        System.assertEquals(false, result.arrived);
        System.assertEquals('no_geofence', result.status);
    }

    @IsTest
    static void processPingIdempotentOnSecondArrival() {
        Work_Order__c wo = makeLockedWorkOrder(35.7796, -78.6382);
        GPSArrivalService.processPing(wo.Id, 35.7796, -78.6382);
        Datetime firstArrival = [SELECT Arrived_At__c FROM Work_Order__c WHERE Id = :wo.Id].Arrived_At__c;
        Test.startTest();
        GPSArrivalService.PingResult result = GPSArrivalService.processPing(wo.Id, 35.7796, -78.6382);
        Test.stopTest();
        System.assertEquals(true, result.arrived);
        Datetime secondArrival = [SELECT Arrived_At__c FROM Work_Order__c WHERE Id = :wo.Id].Arrived_At__c;
        System.assertEquals(firstArrival, secondArrival, 'Arrived_At__c should not be overwritten on repeat ping');
    }
}
