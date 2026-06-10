@IsTest
private class LotRecordControllerTest {

    @IsTest
    static void getHeaderHandlesNull() {
        LotRecordController.LotHeader h = LotRecordController.getHeader(null);
        System.assertNotEquals(null, h);
    }

    @IsTest
    static void getScopeHandlesNull() {
        LotRecordController.LotScope s = LotRecordController.getScope(null);
        System.assertNotEquals(null, s);
    }

    @IsTest
    static void getWorkOrdersHandlesNull() {
        List<LotRecordController.WoRow> rows = LotRecordController.getWorkOrders(null);
        System.assertEquals(0, rows.size());
    }

    @IsTest
    static void getFinishJobsHandlesNull() {
        List<LotRecordController.FjRow> rows = LotRecordController.getFinishJobs(null);
        System.assertEquals(0, rows.size());
    }

    @IsTest
    static void buildHeaderFromConstructedLot() {
        Lot__c lot = new Lot__c(
            Name = 'TL-001',
            Address__c = '100 Main',
            Phase__c = 'Phase 1',
            Status__c = 'Available',
            Pipeline_Bucket__c = '90+ days',
            Has_Open_FJ__c = false,
            Builder_PO_Number__c = 'PO-1',
            Install_Date__c = Date.today().addDays(30)
        );
        Test.startTest();
        LotRecordController.LotHeader h = LotRecordController.buildHeader(lot);
        Test.stopTest();
        System.assertEquals('TL-001', h.lotName);
        System.assertEquals('100 Main', h.address);
        System.assertEquals('Phase 1', h.phase);
        System.assertEquals('Available', h.status);
        System.assertEquals(false, h.hasOpenFJ);
        System.assertEquals('PO-1', h.builderPONumber);
        System.assertEquals(30, h.daysUntilInstall);
    }

    @IsTest
    static void buildHeaderHandlesNullDates() {
        Lot__c lot = new Lot__c(Name = 'TL-2', Install_Date__c = null);
        Test.startTest();
        LotRecordController.LotHeader h = LotRecordController.buildHeader(lot);
        Test.stopTest();
        System.assertEquals(null, h.daysUntilInstall);
    }

    @IsTest
    static void buildScopeFromConstructedLot() {
        Lot__c lot = new Lot__c(
            Name = 'TL-2',
            Sod_SF__c = 5000,
            Trees__c = 4,
            Shrubs__c = 12,
            Plant_Package__c = 'Premium',
            Aqua_Add_On__c = 1500,
            Spec_Type__c = 'Average'
        );
        Test.startTest();
        LotRecordController.LotScope s = LotRecordController.buildScope(lot);
        Test.stopTest();
        System.assertEquals(5000, s.sodSqft);
        System.assertEquals(4, s.trees);
        System.assertEquals(12, s.shrubs);
        System.assertEquals('Premium', s.plantPackage);
        System.assertEquals(1500, s.aquaAddOn);
        System.assertEquals('Average', s.specType);
    }

    @IsTest
    static void buildScopeHandlesNullCounts() {
        Lot__c lot = new Lot__c(Name = 'TL-3');
        Test.startTest();
        LotRecordController.LotScope s = LotRecordController.buildScope(lot);
        Test.stopTest();
        System.assertEquals(0, s.trees);
        System.assertEquals(0, s.shrubs);
    }

    @IsTest
    static void buildWoRowFromConstructedWorkOrder() {
        WorkOrder wo = new WorkOrder();
        wo.Subject = 'Test';
        wo.Job_Type__c = 'Install';
        wo.Status = 'Scheduled';
        wo.Requested_Install_Date__c = Date.today();
        Test.startTest();
        LotRecordController.WoRow r = LotRecordController.buildWoRow(wo);
        Test.stopTest();
        System.assertEquals('Install', r.jobType);
        System.assertEquals('Scheduled', r.status);
        System.assertEquals('', r.foreman);
    }

    @IsTest
    static void getHeaderWithFakeIdRunsQueryReturnsEmpty() {
        // Use a fake but valid Lot__c Id to exercise SOQL path
        Id fakeId = null;
        try { fakeId = Id.valueOf(Schema.Lot__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000'); } catch (Exception e) { return; }
        if (fakeId != null) {
            Test.startTest();
            LotRecordController.LotHeader h = LotRecordController.getHeader(fakeId);
            Test.stopTest();
            System.assertNotEquals(null, h);
        }
    }

    @IsTest
    static void getScopeWithFakeIdRunsQuery() {
        Id fakeId = null;
        try { fakeId = Id.valueOf(Schema.Lot__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000'); } catch (Exception e) { return; }
        if (fakeId != null) {
            Test.startTest();
            LotRecordController.LotScope s = LotRecordController.getScope(fakeId);
            Test.stopTest();
            System.assertNotEquals(null, s);
        }
    }

    @IsTest
    static void getWorkOrdersWithFakeIdRunsQuery() {
        Id fakeId = null;
        try { fakeId = Id.valueOf(Schema.Lot__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000'); } catch (Exception e) { return; }
        if (fakeId != null) {
            Test.startTest();
            List<LotRecordController.WoRow> rows = LotRecordController.getWorkOrders(fakeId);
            Test.stopTest();
            System.assertNotEquals(null, rows);
        }
    }

    @IsTest
    static void getFinishJobsWithFakeIdRunsQuery() {
        Id fakeId = null;
        try { fakeId = Id.valueOf(Schema.Lot__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000'); } catch (Exception e) { return; }
        if (fakeId != null) {
            Test.startTest();
            List<LotRecordController.FjRow> rows = LotRecordController.getFinishJobs(fakeId);
            Test.stopTest();
            System.assertNotEquals(null, rows);
        }
    }

    @IsTest
    static void buildFjRowFromConstructedWorkOrder() {
        WorkOrder wo = new WorkOrder();
        wo.Subject = 'Test FJ';
        wo.Job_Type__c = 'Finish Job';
        wo.Status = 'Scheduled';
        Test.startTest();
        LotRecordController.FjRow r = LotRecordController.buildFjRow(wo);
        Test.stopTest();
        System.assertEquals('Finish Job', r.jobType);
        System.assertEquals('Scheduled', r.status);
    }
}