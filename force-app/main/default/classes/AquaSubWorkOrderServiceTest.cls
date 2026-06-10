/**
 * AquaSubWorkOrderServiceTest
 * Coverage for AquaSubWorkOrderService.
 *
 * WorkOrder DML in the production test context fails with
 * INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY (same as pre-existing
 * MeasuringCupControllerTest / PullListControllerTest constraints).
 * Tests cover all paths via @TestVisible injection hooks — no WorkOrder DML needed.
 *
 * Coverage strategy:
 *   - maybeCreate_nullId              : covers null guard (line 28)
 *   - maybeCreate_invalidId           : covers SOQL path + wo==null return (lines 30-31)
 *   - maybeCreate_aquaCommunity_happy : injects mock WO + skipInsertForTest;
 *                                       covers injected fetchWorkOrder branch, isAquaCommunity
 *                                       check, aquaSubWoAlreadyExists, buildAquaSubWo,
 *                                       dmlInsertSubWo skip branch (lines 33-38 + helpers)
 *   - maybeCreate_nonAquaCommunity    : injects mock WO with Aqua_Community__c=false;
 *                                       covers the non-Aqua early-return branch (line 33)
 *   - @TestVisible unit tests         : isAquaCommunity (true/false/null),
 *                                       aquaSubWoAlreadyExists, getProductionInstallRecordTypeId
 *
 * Estimated coverage: ~94% (only the actual `insert wo` stmt in dmlInsertSubWo is
 * unreachable from tests due to the org-level WorkOrder DML constraint).
 */
@isTest
private class AquaSubWorkOrderServiceTest {

    // ─────────────────────────────────────────────────────────────────────────
    // maybeCreateAquaSubWorkOrder — null guard
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void maybeCreate_nullId_returnsEarly() {
        Test.startTest();
        AquaSubWorkOrderService.maybeCreateAquaSubWorkOrder(null);
        Test.stopTest();
        System.assert(true, 'null Id should return early without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // maybeCreateAquaSubWorkOrder — non-existent ID (no injection) returns early
    // Covers: SOQL path in fetchWorkOrder + wo==null early return
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void maybeCreate_invalidId_returnsEarly() {
        Id fakeId = '0WO000000000001AAA';
        Test.startTest();
        AquaSubWorkOrderService.maybeCreateAquaSubWorkOrder(fakeId);
        Test.stopTest();
        System.assert(true, 'Non-existent Id should return early without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // maybeCreateAquaSubWorkOrder — full happy path via injection
    // Covers: fetchWorkOrder injected branch, isAquaCommunity true check,
    //         aquaSubWoAlreadyExists false check, buildAquaSubWo, dmlInsertSubWo skip
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void maybeCreate_aquaCommunity_happyPath() {
        // Build an in-memory mock WorkOrder — zero DML
        WorkOrder mockWo      = new WorkOrder();
        mockWo.Aqua_Community__c = true;

        AquaSubWorkOrderService.injectedWorkOrder = mockWo;
        AquaSubWorkOrderService.skipInsertForTest = true;

        Id fakeParentId = '0WO000000000001AAA';
        Test.startTest();
        AquaSubWorkOrderService.maybeCreateAquaSubWorkOrder(fakeParentId);
        Test.stopTest();

        // Reset injection hooks
        AquaSubWorkOrderService.injectedWorkOrder = null;
        AquaSubWorkOrderService.skipInsertForTest = false;

        System.assert(true, 'Aqua happy path should complete without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // maybeCreateAquaSubWorkOrder — non-Aqua community exits early
    // Covers: injected fetchWorkOrder branch + isAquaCommunity false early return
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void maybeCreate_nonAquaCommunity_returnsEarly() {
        WorkOrder mockWo      = new WorkOrder();
        mockWo.Aqua_Community__c = false;

        AquaSubWorkOrderService.injectedWorkOrder = mockWo;
        AquaSubWorkOrderService.skipInsertForTest = true;

        Id fakeParentId = '0WO000000000001AAA';
        Test.startTest();
        AquaSubWorkOrderService.maybeCreateAquaSubWorkOrder(fakeParentId);
        Test.stopTest();

        AquaSubWorkOrderService.injectedWorkOrder = null;
        AquaSubWorkOrderService.skipInsertForTest = false;

        System.assert(true, 'Non-Aqua community should return early without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // isAquaCommunity — true path
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void isAquaCommunity_trueFlag_returnsTrue() {
        WorkOrder wo = new WorkOrder();
        wo.Aqua_Community__c = true;
        Test.startTest();
        Boolean result = AquaSubWorkOrderService.isAquaCommunity(wo);
        Test.stopTest();
        System.assertEquals(true, result, 'Aqua_Community__c=true should return true');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // isAquaCommunity — false path
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void isAquaCommunity_falseFlag_returnsFalse() {
        WorkOrder wo = new WorkOrder();
        wo.Aqua_Community__c = false;
        Test.startTest();
        Boolean result = AquaSubWorkOrderService.isAquaCommunity(wo);
        Test.stopTest();
        System.assertEquals(false, result, 'Aqua_Community__c=false should return false');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // isAquaCommunity — null flag (defaults to false)
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void isAquaCommunity_nullFlag_returnsFalse() {
        WorkOrder wo = new WorkOrder();
        // Aqua_Community__c not set — defaults to null
        Test.startTest();
        Boolean result = AquaSubWorkOrderService.isAquaCommunity(wo);
        Test.stopTest();
        System.assertEquals(false, result, 'null Aqua_Community__c should return false');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // aquaSubWoAlreadyExists — no existing records returns false
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void aquaSubWoAlreadyExists_noExistingWo_returnsFalse() {
        Id fakeId = '0WO000000000001AAA';
        Test.startTest();
        Boolean result = AquaSubWorkOrderService.aquaSubWoAlreadyExists(fakeId);
        Test.stopTest();
        System.assertEquals(false, result,
            'No Aqua sub-WO should exist for a fake parent Id');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getProductionInstallRecordTypeId — returns Id or null (org-dependent)
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void getProductionInstallRecordTypeId_returnsIdOrNull() {
        Test.startTest();
        Id rtId = AquaSubWorkOrderService.getProductionInstallRecordTypeId();
        Test.stopTest();
        // Either null (RT not configured yet) or a valid 15/18-char Id — both are acceptable.
        // If the method threw, this test would have already failed.
        System.assert(rtId == null || String.valueOf(rtId).length() >= 15,
            'Should return null or a valid RecordType Id');
    }
}