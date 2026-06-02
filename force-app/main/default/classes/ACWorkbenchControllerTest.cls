@IsTest
private class ACWorkbenchControllerTest {
    @TestSetup
    static void setupData() {
        Id parentRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Builder_Parent')?.getRecordTypeId();
        Id divisionRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Builder_Market')?.getRecordTypeId();

        Account parent = new Account(
            Name = 'ACW Parent Builder',
            Type = 'Home Builder',
            Account_Status__c = 'Active',
            BillingCity = 'Charlotte',
            BillingState = 'NC',
            RecordTypeId = parentRtId
        );
        insert parent;

        Account division = new Account(
            Name = 'ACW Division Charlotte',
            Type = 'Division Builder',
            ParentId = parent.Id,
            Account_Status__c = 'Active',
            Division_Phone__c = '704-555-0100',
            Construction_Mgr_Name__c = 'Test CM',
            Construction_Mgr_Phone__c = '704-555-0199',
            Scheduling_Contact_Name__c = 'Test Scheduler',
            RecordTypeId = divisionRtId
        );
        insert division;

        Community__c community = new Community__c(
            Name = 'ACW Test Community',
            Active__c = true,
            Builder_Account__c = division.Id,
            FM_Assignment__c = UserInfo.getUserId(),
            Community_Status__c = 'Active',
            Number_Of_Lots__c = 2,
            Active_Lot_Count__c = 2,
            Closed_Lot_Count__c = 0,
            Aqua_Customer__c = true,
            Community_Address__c = '100 Builder Way',
            Community_City__c = 'Charlotte',
            Community_State__c = 'NC',
            BMG_Package_Code__c = 'STD',
            Phases__c = '1',
            First_Lot_Install_Date__c = Date.today(),
            Last_Lot_Install_Date__c = Date.today().addDays(14),
            Avg_Sod_Roll_Coverage__c = 450
        );
        insert community;

        insert new Lot__c(
            Name = 'ACW-Lot-001',
            Lot_Number__c = '001',
            Community__c = community.Id,
            Builder_Account__c = division.Id,
            Builder_Division__c = division.Id,
            Street_Address__c = '101 Builder Way',
            Requested_Install_Date__c = Date.today().addDays(7),
            Pipeline_Bucket__c = 'Scheduled',
            Lot_Status__c = 'Open',
            Eight11_Task_Status__c = 'Cleared',
            Spec_Type__c = 'Average',
            Builder_PO_Number__c = 'PO-ACW-001',
            Phase__c = 'Phase 1',
            Sod_Sf__c = 4200,
            Aqua_Installed__c = true,
            Latitude__c = 35.111,
            Longitude__c = -81.111
        );
    }

    @IsTest
    static void getWorkbenchData_returnsInitializedLists() {
        Test.startTest();
        AccountCommunityLotWorkbenchController.WorkbenchPageDTO dto =
            AccountCommunityLotWorkbenchController.getWorkbenchData();
        Test.stopTest();

        System.assertNotEquals(null, dto, 'Workbench DTO should be returned.');
        System.assertNotEquals(null, dto.builders, 'Builders list should be initialized.');
        System.assertNotEquals(null, dto.divisions, 'Divisions list should be initialized.');
        System.assertNotEquals(null, dto.communities, 'Communities list should be initialized.');
        System.assertNotEquals(null, dto.lots, 'Lots list should be initialized.');
        System.assert(!dto.communities.isEmpty(), 'Synthetic community should be mapped.');
        System.assert(!dto.lots.isEmpty(), 'Synthetic lot should be mapped.');
    }
}