@IsTest
private class LovingAcctCommLotWorkbenchTest {
    @TestSetup
    static void setupData() {
        Map<String, Id> accountRecordTypes = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName IN ('Builder_Parent', 'Builder_Market')
        ]) {
            accountRecordTypes.put(rt.DeveloperName, rt.Id);
        }

        Account parent = new Account(
            Name = 'UAT Workbench Parent Builder',
            RecordTypeId = accountRecordTypes.get('Builder_Parent')
        );
        insert parent;

        Account division = new Account(
            Name = 'UAT Workbench Charlotte Division',
            ParentId = parent.Id,
            RecordTypeId = accountRecordTypes.get('Builder_Market')
        );
        insert division;

        Community__c community = new Community__c(
            Name = 'UAT Workbench Community',
            Builder_Account__c = division.Id,
            Active__c = true,
            BMG_Package_Code__c = 'UAT-PKG'
        );
        insert community;

        Lot__c lot = new Lot__c(
            Name = 'UAT-LOT-101',
            Community__c = community.Id,
            Street_Address__c = '101 UAT Workbench Way',
            Lot_Latitude__c = 35.2271,
            Lot_Longitude__c = -80.8431
        );
        insert lot;

        // PO and WorkOrder lookup filters vary by production record type.
        // The workbench must still render a clean empty state when those related rows are absent.
    }

    @IsTest
    static void returnsParentDivisionCommunityAndLotHierarchy() {
        Test.startTest();
        LovingAcctCommLotWorkbenchSvc.WorkbenchData data =
            LovingAcctCommLotWorkbenchCtrl.getWorkbenchData('{"activeOnly":true}');
        Test.stopTest();

        System.assert(data.parents.size() > 0, 'Parent builders should be returned.');
        System.assert(data.divisions.size() > 0, 'Division accounts should be returned.');
        System.assert(data.communities.size() > 0, 'Communities should be returned.');
        System.assert(data.lots.size() > 0, 'Lots should be returned.');
        System.assertEquals(6, data.kpis.size(), 'KPI row should be populated from live-structure DTOs.');
        System.assert(data.audit.size() > 0, 'Metadata audit rows should be included.');
    }

    @IsTest
    static void parentActionsBlockTransactions() {
        LovingAcctCommLotWorkbenchSvc.WorkbenchData data =
            LovingAcctCommLotWorkbenchCtrl.getWorkbenchData(null);

        Boolean foundBlockedNewPo = false;
        for (LovingAcctCommLotWorkbenchSvc.ActionDTO action : data.parentActions) {
            if (action.key == 'newPoBlocked') {
                foundBlockedNewPo = true;
                System.assertEquals(false, action.enabled, 'Parent account PO creation must be blocked.');
                System.assert(action.disabledReason.contains('rollup only'), 'Blocked parent action should explain why.');
            }
        }
        System.assert(foundBlockedNewPo, 'Parent actions should include a blocked New PO action.');
    }

    @IsTest
    static void packageSummaryFallsBackWhenPoStatusIsAbsent() {
        Community__c community = [SELECT Id FROM Community__c WHERE Name = 'UAT Workbench Community' LIMIT 1];
        Lot__c lot = [SELECT Id FROM Lot__c WHERE Name = 'UAT-LOT-101' LIMIT 1];

        LovingAcctCommLotWorkbenchSvc.PackageSummaryDTO communitySummary =
            LovingAcctCommLotWorkbenchCtrl.getPackageMatchSummary(community.Id);
        LovingAcctCommLotWorkbenchSvc.PackageSummaryDTO lotSummary =
            LovingAcctCommLotWorkbenchCtrl.getPackageMatchSummary(lot.Id);

        System.assertEquals('Not Configured', communitySummary.status, 'Community summary should explain when no package status exists.');
        System.assertEquals('Not Configured', lotSummary.status, 'Lot summary should explain when no package status exists.');
    }

    @IsTest
    static void searchAndEmptyStateDoNotCrash() {
        LovingAcctCommLotWorkbenchSvc.WorkbenchData noRows =
            LovingAcctCommLotWorkbenchCtrl.searchHierarchy('Definitely No Matching Builder 98765');

        System.assertEquals(0, noRows.parents.size(), 'No matching parent records should return an empty array.');
        System.assertNotEquals(null, noRows.divisions, 'Division array should still be initialized.');
        System.assertNotEquals(null, noRows.communities, 'Community array should still be initialized.');
        System.assertNotEquals(null, noRows.lots, 'Lot array should still be initialized.');
    }

    @IsTest
    static void summaryMethodsReturnAllowedActions() {
        Account parent = [SELECT Id FROM Account WHERE Name = 'UAT Workbench Parent Builder' LIMIT 1];
        Account division = [SELECT Id FROM Account WHERE Name = 'UAT Workbench Charlotte Division' LIMIT 1];
        Community__c community = [SELECT Id FROM Community__c WHERE Name = 'UAT Workbench Community' LIMIT 1];
        Lot__c lot = [SELECT Id FROM Lot__c WHERE Name = 'UAT-LOT-101' LIMIT 1];

        System.assertEquals('parent', LovingAcctCommLotWorkbenchCtrl.getParentSummary(parent.Id).type);
        System.assertEquals('division', LovingAcctCommLotWorkbenchCtrl.getDivisionSummary(division.Id).type);
        System.assertEquals('community', LovingAcctCommLotWorkbenchCtrl.getCommunitySummary(community.Id).type);
        System.assertEquals('lot', LovingAcctCommLotWorkbenchCtrl.getLotSummary(lot.Id).type);
    }
}