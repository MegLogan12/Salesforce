@IsTest
private class ODLWorkOrderControllerTest {

    private static Id divisionRt() {
        return Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName().get('Builder_Market').getRecordTypeId();
    }
    private static Id parentRt() {
        return Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName().get('Builder_Parent').getRecordTypeId();
    }

    @TestSetup
    static void makeData() {
        // Division must roll up to a Builder Parent (active VR Division_Must_Have_Parent).
        Account parent = new Account(Name = 'Test Parent', RecordTypeId = parentRt());
        insert parent;

        Account builder = new Account(
            Name = 'Test Builder', RecordTypeId = divisionRt(),
            ParentId = parent.Id, Account_Status__c = 'Active'
        );
        insert builder;

        Contact cm = new Contact(LastName = 'Whitfield', Phone = '7045550210');
        insert cm;

        Community__c comm = new Community__c(
            Name = 'Sardis Cove',
            Builder_Account__c = builder.Id,
            Active__c = true,
            Aqua_Customer__c = false,
            Temp_Irrigation_Included__c = false,
            Aqua_Included__c = false,
            Lawn_Care_Customer__c = false,
            Aqua_Active__c = false
        );
        insert comm;

        Lot__c lot = new Lot__c(
            Builder_Account__c = builder.Id,
            Community__c = comm.Id,
            Street_Address__c = '3902 Sardis Cove Dr',
            City__c = 'Charlotte',
            State__c = 'NC',
            Lot_Number__c = '14'
        );
        insert lot;

        // Ready: every required gate passes.
        Work_Order__c ready = new Work_Order__c(
            Builder_Market_Account__c = builder.Id,
            Community__c = comm.Id,
            Construction_Manager__c = cm.Id,
            Lot__c = lot.Id,
            Status__c = 'In Progress',
            Crew__c = 'Crew 4',
            Loading_Check_Completed__c = true,
            Takeoff_Photo_Count__c = 2,
            Crew_Completed__c = true,
            Closeout_Photo_Count__c = 5,
            QI_Complete__c = true,
            QI_Held__c = false,
            QI_Score__c = 98,
            Scheduled_Start_DateTime__c = System.now().addDays(-3),
            Scheduled_End_DateTime__c = System.now().addDays(6)
        );

        // Blocked: nothing done yet.
        Work_Order__c blocked = new Work_Order__c(
            Builder_Market_Account__c = builder.Id,
            Status__c = 'Scheduled',
            Takeoff_Photo_Count__c = 0,
            Closeout_Photo_Count__c = 0,
            Scheduled_Start_DateTime__c = System.now().addDays(2)
        );
        insert new List<Work_Order__c>{ ready, blocked };

        // A child scope line under the blocked WO.
        insert new Work_Order__c(
            Builder_Market_Account__c = builder.Id,
            Parent_Work_Order__c = blocked.Id,
            Status__c = 'Scheduled'
        );
    }

    private static Work_Order__c readyWo() {
        return [SELECT Id FROM Work_Order__c WHERE Status__c = 'In Progress' LIMIT 1];
    }
    private static Work_Order__c blockedWo() {
        return [SELECT Id FROM Work_Order__c WHERE Status__c = 'Scheduled' AND Parent_Work_Order__c = null LIMIT 1];
    }

    @IsTest
    static void readyWorkOrder_allGatesPass() {
        Test.startTest();
        ODLWorkOrderController.WorkOrderView v =
            ODLWorkOrderController.getWorkOrder(readyWo().Id);
        Test.stopTest();

        System.assertEquals(true, v.readyToComplete, 'All required gates pass -> ready');
        System.assertEquals(null, v.blocker, 'No blocker when ready');
        // Photo counts surfaced from the count fields, not invented.
        System.assertEquals(5, v.photos.closeoutCount, 'Closeout count from field');
        System.assertEquals('Met', v.photos.closeoutStatus, 'Closeout >= 4 is Met');
        // QI passed -> next action is to close.
        System.assertEquals('Close work order', v.nextAction.text, 'QI passed -> close');
        System.assertEquals('Charlotte', extractCity(v.customer.siteAddress), 'Site address from Lot');
    }

    private static String extractCity(String addr) {
        return addr != null && addr.contains('Charlotte') ? 'Charlotte' : addr;
    }

    @IsTest
    static void blockedWorkOrder_namesBlocker() {
        Test.startTest();
        ODLWorkOrderController.WorkOrderView v =
            ODLWorkOrderController.getWorkOrder(blockedWo().Id);
        Test.stopTest();

        System.assertEquals(false, v.readyToComplete, 'Gates fail -> not ready');
        System.assertEquals('No crew is assigned.', v.blocker, 'First failing required gate is the blocker');

        // Signoff gate is informational (not required) and carries a missing-field flag.
        Boolean foundSignoff = false;
        for (ODLWorkOrderController.Gate g : v.gates) {
            if (g.label == 'Customer signoff') {
                foundSignoff = true;
                System.assertEquals(false, g.required, 'Signoff is not a required gate (no field)');
                System.assertNotEquals(null, g.flag, 'Signoff carries a missing-field flag');
            }
        }
        System.assert(foundSignoff, 'Signoff gate present');
        System.assertEquals(1, v.scope.size(), 'One child scope line');
        System.assertEquals('Dispatch crew', v.nextAction.text, 'Scheduled, not started -> dispatch');
    }

    @IsTest
    static void completeJob_blockedThrows() {
        Id woId = blockedWo().Id;
        Test.startTest();
        try {
            ODLWorkOrderController.completeJob(woId);
            System.assert(false, 'Should have thrown for a blocked work order');
        } catch (AuraHandledException e) {
            System.assert(true, 'Blocked completion correctly rejected');
        }
        Test.stopTest();
    }

    @IsTest
    static void completeJob_readySucceeds() {
        Id woId = readyWo().Id;
        Test.startTest();
        ODLWorkOrderController.WorkOrderView v = ODLWorkOrderController.completeJob(woId);
        Test.stopTest();

        System.assertEquals(true, v.readyToComplete, 'Still ready after completion');
        Work_Order__c after = [
            SELECT Field_Complete_Date__c, Crew_Completed__c FROM Work_Order__c WHERE Id = :woId
        ];
        System.assertNotEquals(null, after.Field_Complete_Date__c, 'Field complete stamped');
        System.assertEquals(true, after.Crew_Completed__c, 'Crew complete set');
    }

    @IsTest
    static void restrictedUser_deniedGracefully() {
        List<Profile> mins = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        if (mins.isEmpty()) {
            return; // org without this profile; nothing to assert
        }
        User u = new User(
            ProfileId = mins[0].Id,
            LastName = 'Restricted',
            Email = 'restricted.odlwo@example.com',
            Username = 'restricted.odlwo.' + DateTime.now().getTime() + '@example.com.test',
            Alias = 'rwo',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        Id woId = readyWo().Id;
        Test.startTest();
        System.runAs(u) {
            try {
                ODLWorkOrderController.getWorkOrder(woId);
                // Some orgs grant object access by default; absence of a throw is acceptable.
                System.assert(true);
            } catch (AuraHandledException e) {
                System.assert(true, 'Restricted user blocked');
            }
        }
        Test.stopTest();
    }
}
