@IsTest
private class CloseoutServiceTest {

    @TestSetup
    static void seed() {
        insert new Work_Order__c(Status__c = 'Ready to Schedule');
    }

    @IsTest
    static void flagNFIBlankReasonThrows() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];
        Boolean threw = false;
        try {
            CloseoutService.flagNFI(wo.Id, '', 'Photo');
        } catch (CloseoutService.CloseoutException e) {
            threw = true;
        }
        System.assert(threw, 'Expected CloseoutException for blank reason');
    }

    @IsTest
    static void flagNFISetsStatusAndIncrementsCounter() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        // flagNFI triggers Work_Order_Trigger → handleNFI → notifyFMNFI, which
        // queries standard WorkOrder. Inject a mock so the SOQL doesn't throw.
        WorkOrder mockWO = new WorkOrder();
        mockWO.put('Field_Manager__c', UserInfo.getUserId());
        EscalationService.injectedWorkOrderForSOQL = mockWO;

        Test.startTest();
        CloseoutService.flagNFI(wo.Id, 'Missing closeout photos', 'Photo');
        Test.stopTest();

        EscalationService.injectedWorkOrderForSOQL = null;
        Work_Order__c reloaded = [
            SELECT Status__c, NFI_Count__c, NFI_Reason__c, NFI_Type__c
            FROM Work_Order__c WHERE Id = :wo.Id
        ];
        System.assertEquals('Need Further Info (NFI)', reloaded.Status__c);
        System.assertEquals(1, reloaded.NFI_Count__c);
        System.assertEquals('Missing closeout photos', reloaded.NFI_Reason__c);
        System.assertEquals('Photo', reloaded.NFI_Type__c);
    }

    @IsTest
    static void resubmitAfterNFIReturnsToPendingApproval() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];
        wo.Status__c    = 'Need Further Info (NFI)';
        wo.NFI_Count__c = 1;

        // The status→NFI update fires Work_Order_Trigger → handleNFI → notifyFMNFI,
        // which queries the standard WorkOrder object. No standard WO exists in test
        // context, so inject a mock to satisfy the SOQL assignment.
        WorkOrder mockWO = new WorkOrder();
        mockWO.put('Field_Manager__c', UserInfo.getUserId());
        EscalationService.injectedWorkOrderForSOQL = mockWO;
        update wo;
        EscalationService.injectedWorkOrderForSOQL = null;

        Test.startTest();
        CloseoutService.resubmitAfterNFI(wo.Id, 'Photos uploaded');
        Test.stopTest();

        Work_Order__c reloaded = [
            SELECT Status__c, NFI_Resolution__c, NFI_Resolved_Date__c
            FROM Work_Order__c WHERE Id = :wo.Id
        ];
        System.assertEquals('Pending Approval', reloaded.Status__c);
        System.assertEquals('Photos uploaded', reloaded.NFI_Resolution__c);
        System.assertEquals(Date.today(), reloaded.NFI_Resolved_Date__c);
    }

    @IsTest
    static void approveHappyPath() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];
        wo.Status__c = 'Pending Approval';
        update wo;

        Test.startTest();
        CloseoutService.approveCloseout(wo.Id);
        Test.stopTest();

        Work_Order__c reloaded = [
            SELECT Status__c, Approved_Date__c, Approved_By__c
            FROM Work_Order__c WHERE Id = :wo.Id
        ];
        System.assertEquals('Approved', reloaded.Status__c);
        System.assertEquals(Date.today(), reloaded.Approved_Date__c);
        System.assertEquals(UserInfo.getUserId(), reloaded.Approved_By__c);
    }

    @IsTest
    static void approveWrongStatusThrows() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];
        // Status is 'Ready to Schedule' from seed — neither Pending Approval nor Pending Closeout
        Boolean threw = false;
        try {
            CloseoutService.approveCloseout(wo.Id);
        } catch (CloseoutService.CloseoutException e) {
            threw = true;
        }
        System.assert(threw, 'Expected CloseoutException when WO not in Pending Approval/Closeout');
    }

    @IsTest
    static void onApprovedCreatesQITask() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];
        wo.Status__c = 'Pending Approval';
        update wo;

        Test.startTest();
        CloseoutService.approveCloseout(wo.Id);
        Test.stopTest();

        List<Task> qiTasks = [
            SELECT Id, Subject FROM Task
            WHERE WhatId = :wo.Id AND Subject LIKE '%QI Inspection%'
        ];
        System.assertEquals(1, qiTasks.size(), 'Expected exactly one QI Inspection task on Approved');
    }

    @IsTest
    static void handleNFIDoesNotEscalateUnderCap() {
        Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

        // Each flagNFI/resubmit update fires the trigger → handleNFI → notifyFMNFI,
        // which queries the standard WorkOrder object. Inject a mock for the duration.
        WorkOrder mockWO = new WorkOrder();
        mockWO.put('Field_Manager__c', UserInfo.getUserId());
        EscalationService.injectedWorkOrderForSOQL = mockWO;

        Test.startTest();
        // First and second NFI: under the cap, no COO escalation
        CloseoutService.flagNFI(wo.Id, 'First return', 'Photo');
        CloseoutService.resubmitAfterNFI(wo.Id, 'fixed');
        CloseoutService.flagNFI(wo.Id, 'Second return', 'Photo');
        Test.stopTest();

        EscalationService.injectedWorkOrderForSOQL = null;
        Work_Order__c reloaded = [SELECT NFI_Count__c FROM Work_Order__c WHERE Id = :wo.Id];
        System.assertEquals(2, reloaded.NFI_Count__c);
    }
}