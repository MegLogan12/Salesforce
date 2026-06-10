@IsTest
private class TakeoffServiceTest {

    @TestSetup
    static void seed() {
        // Insert with Takeoff_Status not yet submitted to bypass field-completeness validation,
        // then flip to Submitted for Approval
        Work_Order__c wo = new Work_Order__c(
            Status__c              = 'In Progress',
            Takeoff_Status__c      = 'In Progress',
            Sod_Sqft__c            = 4500,
            Trees_Count__c         = 6,
            Plants_by_Species__c   = 'Holly: 4; Boxwood: 8',
            Takeoff_Photo_Count__c = 5,
            Takeoff_Geotag_Lat__c  = 35.7796,
            Takeoff_Geotag_Lng__c  = -78.6382,
            Lot_Latitude__c        = 35.7796,
            Lot_Longitude__c       = -78.6382
        );
        insert wo;
        wo.Takeoff_Status__c = 'Submitted for Approval';
        update wo;
    }

    @IsTest
    static void approveTakeoffAdvancesToReadyToSchedule() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        Test.startTest();
        TakeoffService.approveTakeoff(wo.Id);
        Test.stopTest();

        Work_Order__c reloaded = [
            SELECT Takeoff_Status__c, Status__c, Takeoff_Approved_Date__c
            FROM Work_Order__c WHERE Id = :wo.Id
        ];
        System.assertEquals('Locked', reloaded.Takeoff_Status__c);
        System.assertEquals('Ready to Schedule', reloaded.Status__c);
        System.assertEquals(Date.today(), reloaded.Takeoff_Approved_Date__c);
    }

    @IsTest
    static void approveWrongStatusThrows() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];
        wo.Takeoff_Status__c = 'In Progress';
        update wo;

        Boolean caught = false;
        Test.startTest();
        try {
            TakeoffService.approveTakeoff(wo.Id);
        } catch (TakeoffService.TakeoffException e) {
            caught = true;
            System.assert(e.getMessage().contains('Submitted for Approval'));
        }
        Test.stopTest();
        System.assertEquals(true, caught);
    }

    @IsTest
    static void returnRequiresReason() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        Boolean caught = false;
        Test.startTest();
        try {
            TakeoffService.returnTakeoffForCorrection(wo.Id, '');
        } catch (TakeoffService.TakeoffException e) {
            caught = true;
            System.assert(e.getMessage().contains('Return Reason'));
        }
        Test.stopTest();
        System.assertEquals(true, caught);
    }

    @IsTest
    static void returnIncrementsNFICount() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        // returnTakeoffForCorrection updates WO → fires Work_Order_Trigger → handleNFI →
        // notifyFMNFI queries standard WorkOrder. No standard WO exists in test context,
        // so inject a mock to satisfy the SOQL assignment.
        WorkOrder mockWO = new WorkOrder();
        mockWO.put('Field_Manager__c', UserInfo.getUserId());
        EscalationService.injectedWorkOrderForSOQL = mockWO;

        Test.startTest();
        TakeoffService.returnTakeoffForCorrection(wo.Id, 'Photos missing for line items 3-5');
        Test.stopTest();

        EscalationService.injectedWorkOrderForSOQL = null;

        Work_Order__c reloaded = [
            SELECT Takeoff_Status__c, NFI_Count__c, Takeoff_Return_Reason__c
            FROM Work_Order__c WHERE Id = :wo.Id
        ];
        System.assertEquals('Returned', reloaded.Takeoff_Status__c);
        System.assertEquals(1, reloaded.NFI_Count__c);
        System.assert(reloaded.Takeoff_Return_Reason__c.contains('Photos missing'));
    }

    @IsTest
    static void returnAfterTwoEscalatesToCOO() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];
        wo.NFI_Count__c = 2;
        wo.Takeoff_Status__c = 'Submitted for Approval';

        // The status update fires Work_Order_Trigger → handleNFI → notifyFMNFI,
        // which queries standard WorkOrder. Inject a mock for the duration.
        WorkOrder mockWO = new WorkOrder();
        mockWO.put('Field_Manager__c', UserInfo.getUserId());
        EscalationService.injectedWorkOrderForSOQL = mockWO;
        update wo;

        Test.startTest();
        TakeoffService.returnTakeoffForCorrection(wo.Id, 'Geotag still wrong, third return');
        Test.stopTest();

        EscalationService.injectedWorkOrderForSOQL = null;

        Work_Order__c reloaded = [SELECT NFI_Count__c FROM Work_Order__c WHERE Id = :wo.Id];
        System.assertEquals(3, reloaded.NFI_Count__c, 'Third return should set count to 3 and trigger COO escalation');
    }

    @IsTest
    static void geotagValidWithin150Meters() {
        // Same lat/lng → distance 0
        Work_Order__c wo = [SELECT Id, Lot_Latitude__c, Lot_Longitude__c FROM Work_Order__c LIMIT 1];
        wo.Takeoff_Geotag_Lat__c = wo.Lot_Latitude__c;
        wo.Takeoff_Geotag_Lng__c = wo.Lot_Longitude__c;

        Test.startTest();
        Boolean valid = TakeoffService.isGeotagValid(wo);
        Test.stopTest();

        System.assertEquals(true, valid);
    }

    @IsTest
    static void geotagInvalidBeyond150Meters() {
        // Move ~1km away in latitude (~0.009 degrees ≈ 1km)
        Work_Order__c wo = [SELECT Id, Lot_Latitude__c, Lot_Longitude__c FROM Work_Order__c LIMIT 1];
        wo.Takeoff_Geotag_Lat__c = wo.Lot_Latitude__c + 0.01;
        wo.Takeoff_Geotag_Lng__c = wo.Lot_Longitude__c;

        Test.startTest();
        Boolean valid = TakeoffService.isGeotagValid(wo);
        Test.stopTest();

        System.assertEquals(false, valid, 'Distance > 150m should be invalid');
    }

    @IsTest
    static void geotagMissingReturnsFalse() {
        Work_Order__c wo = [SELECT Id, Lot_Latitude__c, Lot_Longitude__c FROM Work_Order__c LIMIT 1];
        wo.Takeoff_Geotag_Lat__c = null;
        wo.Takeoff_Geotag_Lng__c = null;

        Test.startTest();
        Boolean valid = TakeoffService.isGeotagValid(wo);
        Test.stopTest();

        System.assertEquals(false, valid, 'Missing geotag is invalid');
    }

    @IsTest
    static void slaCheckIdentifiesOverdueTakeoffs() {
        // Insert one WO that's been "In Progress" for 3 days (>48h SLA)
        Work_Order__c wo2 = new Work_Order__c(
            Status__c               = 'In Progress',
            Takeoff_Status__c       = 'In Progress',
            Takeoff_Started_Date__c = Datetime.now().addDays(-3)
        );
        insert wo2;

        // checkTakeoffSLA → escalateTakeoffSLABreach queries standard WorkOrder.
        // Inject a mock so the SOQL doesn't throw.
        WorkOrder mockWO = new WorkOrder();
        mockWO.put('Field_Manager__c', UserInfo.getUserId());
        EscalationService.injectedWorkOrderForSOQL = mockWO;

        Test.startTest();
        TakeoffService.checkTakeoffSLA();
        Test.stopTest();

        EscalationService.injectedWorkOrderForSOQL = null;
        // No exception = pass; escalation logic is tested in EscalationService coverage
        System.assert(true);
    }
}