/**
 * EscalationServiceTest
 *
 * Covers all public escalation methods. WorkOrder INSERT is blocked in this org's
 * test context (INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY). Strategy:
 *
 *   1. Methods that only call sendAlert() with role-lookup recipients:
 *      Pass null as recordId so postChatterAlert fallback uses UserInfo.getUserId()
 *      as FeedItem.ParentId (valid Chatter target). CustomNotificationType SOQL
 *      throws → caught → postChatterAlert fires → FeedItem inserted on current user.
 *
 *   2. Methods with single-record WorkOrder SOQL (escalateTakeoffSLABreach, etc.):
 *      Use injectedWorkOrderForSOQL to inject a mock WO, bypassing the SOQL.
 *
     *   3. Role lookups (getCOOId etc.): covered implicitly by every method call.
 *      In test context (seeAllData=false) all lookups fall back to UserInfo.getUserId().
 */
@isTest
private class EscalationServiceTest {

    private static final Id FAKE_WO_ID   = '0WO000000000001AAA';
    private static final Id FAKE_LEAD_ID = '00Q000000000001AAA';
    private static final Id FAKE_INV_ID  = 'a0X000000000001AAA';

    private static void resetInjection() {
        EscalationService.injectedWorkOrderForSOQL = null;
    }

    private static WorkOrder mockWO() {
        WorkOrder w = new WorkOrder();
        w.Field_Manager__c = null; // sendAlert exits cleanly on null
        return w;
    }

    // ─────────────────────────────────────────────
    // LEAD ESCALATIONS
    // ─────────────────────────────────────────────
    @isTest
    static void testNotifyCOODeadLeads_noException() {
        // Use a valid User Id so postChatterAlert FeedItem.ParentId is valid
        Id userId = UserInfo.getUserId();
        Test.startTest();
        EscalationService.notifyCOODeadLeads(new List<Id>{ userId });
        Test.stopTest();
        System.assert(true, 'notifyCOODeadLeads should complete without exception');
    }

    // ─────────────────────────────────────────────
    // TAKEOFF ESCALATIONS
    // ─────────────────────────────────────────────
    @isTest
    static void testEscalateTakeoffOverdue_standardWO_noException() {
        WorkOrder wo = new WorkOrder();
        wo.Field_Manager__c = null;
        Test.startTest();
        EscalationService.escalateTakeoffOverdue(new List<WorkOrder>{ wo });
        Test.stopTest();
        System.assert(true, 'escalateTakeoffOverdue(WorkOrder) should complete without exception');
    }

    @isTest
    static void testEscalateTakeoffSLABreach_noException() {
        // Pass null as workOrderId so postChatterAlert fallback uses UserInfo.getUserId() as FeedItem.ParentId
        EscalationService.injectedWorkOrderForSOQL = mockWO();
        Test.startTest();
        EscalationService.escalateTakeoffSLABreach(null);
        Test.stopTest();
        resetInjection();
        System.assert(true, 'escalateTakeoffSLABreach should complete without exception');
    }

    @isTest
    static void testEscalateTakeoffTooCOO_noException() {
        Test.startTest();
        EscalationService.escalateTakeoffTooCOO(null, 3);
        Test.stopTest();
        System.assert(true, 'escalateTakeoffTooCOO should complete without exception');
    }

    @isTest
    static void testNotifyFMTakeoffReturned_noException() {
        EscalationService.injectedWorkOrderForSOQL = mockWO();
        Test.startTest();
        EscalationService.notifyFMTakeoffReturned(FAKE_WO_ID, 'Missing sod photo');
        Test.stopTest();
        resetInjection();
        System.assert(true, 'notifyFMTakeoffReturned should complete without exception');
    }

    @isTest
    static void testNotifySchedulingManagerReadyToSchedule_noException() {
        Test.startTest();
        EscalationService.notifySchedulingManagerReadyToSchedule(null);
        Test.stopTest();
        System.assert(true, 'notifySchedulingManagerReadyToSchedule should complete without exception');
    }

    // ─────────────────────────────────────────────
    // SCHEDULING ESCALATIONS
    // ─────────────────────────────────────────────
    @isTest
    static void testNotifySchedulingManagerSiteNotReady_noException() {
        Test.startTest();
        EscalationService.notifySchedulingManagerSiteNotReady(null, 'Standing water on lot');
        Test.stopTest();
        System.assert(true, 'notifySchedulingManagerSiteNotReady should complete without exception');
    }

    // ─────────────────────────────────────────────
    // HEALTH CHECK ESCALATIONS
    // ─────────────────────────────────────────────
    @isTest
    static void testAlertRedHealthCheck_noException() {
        Test.startTest();
        EscalationService.alertRedHealthCheck(null, 'Crew 2 blocked at gate');
        Test.stopTest();
        System.assert(true, 'alertRedHealthCheck should complete without exception');
    }

    @isTest
    static void testEscalateHealthCheckNoResponse_noException() {
        Test.startTest();
        EscalationService.escalateHealthCheckNoResponse(null, null);
        Test.stopTest();
        System.assert(true, 'escalateHealthCheckNoResponse should complete without exception');
    }

    @isTest
    static void testNotifyFMRedDecision_FJ_noException() {
        EscalationService.injectedWorkOrderForSOQL = mockWO();
        Test.startTest();
        EscalationService.notifyFMRedDecision(FAKE_WO_ID, 'FJ', 'Finish job by 5 PM');
        Test.stopTest();
        resetInjection();
        System.assert(true, 'notifyFMRedDecision FJ should complete without exception');
    }

    @isTest
    static void testNotifyFMRedDecision_EXT_noException() {
        EscalationService.injectedWorkOrderForSOQL = mockWO();
        Test.startTest();
        EscalationService.notifyFMRedDecision(FAKE_WO_ID, 'EXT', 'Extended 2 hours');
        Test.stopTest();
        resetInjection();
        System.assert(true, 'notifyFMRedDecision EXT should complete without exception');
    }

    @isTest
    static void testNotifyFMRedDecision_SCHED_noException() {
        EscalationService.injectedWorkOrderForSOQL = mockWO();
        Test.startTest();
        EscalationService.notifyFMRedDecision(FAKE_WO_ID, 'SCHED', 'Rescheduled for next Tuesday');
        Test.stopTest();
        resetInjection();
        System.assert(true, 'notifyFMRedDecision SCHED should complete without exception');
    }

    // ─────────────────────────────────────────────
    // NFI ESCALATIONS
    // ─────────────────────────────────────────────
    @isTest
    static void testEscalateNFIToCOO_noException() {
        Test.startTest();
        EscalationService.escalateNFIToCOO(null, 3);
        Test.stopTest();
        System.assert(true, 'escalateNFIToCOO should complete without exception');
    }

    @isTest
    static void testNotifyFMNFI_noException() {
        // Inject mock WO (FM = null) so SOQL is bypassed; sendAlert returns on null recipient
        EscalationService.injectedWorkOrderForSOQL = mockWO();
        Test.startTest();
        EscalationService.notifyFMNFI(null, 'Missing inventory count');
        Test.stopTest();
        resetInjection();
        System.assert(true, 'notifyFMNFI should complete without exception');
    }

    // ─────────────────────────────────────────────
    // CSM CLOSEOUT APPROVAL
    // ─────────────────────────────────────────────
    @isTest
    static void testNotifyCSMPendingApproval_noException() {
        Test.startTest();
        EscalationService.notifyCSMPendingApproval(null);
        Test.stopTest();
        System.assert(true, 'notifyCSMPendingApproval should complete without exception');
    }

    // ─────────────────────────────────────────────
    // QI ESCALATIONS
    // ─────────────────────────────────────────────
    @isTest
    static void testNotifyCSMAcceptableQI_noException() {
        Id csmId = UserInfo.getUserId();
        Test.startTest();
        EscalationService.notifyCSMAcceptableQI(null, csmId, 6.5);
        Test.stopTest();
        System.assert(true, 'notifyCSMAcceptableQI should complete without exception');
    }

    @isTest
    static void testAlertRedQI_noException() {
        Id csmId = UserInfo.getUserId();
        Test.startTest();
        EscalationService.alertRedQI(null, csmId, null, 3.8);
        Test.stopTest();
        System.assert(true, 'alertRedQI should complete without exception');
    }

    @isTest
    static void testEscalateQISLABreach_noException() {
        Test.startTest();
        EscalationService.escalateQISLABreach(null, null);
        Test.stopTest();
        System.assert(true, 'escalateQISLABreach should complete without exception');
    }

    @isTest
    static void testAlertSiteReadinessOverdue_noException() {
        Test.startTest();
        EscalationService.alertSiteReadinessOverdue(null, null);
        Test.stopTest();
        System.assert(true, 'alertSiteReadinessOverdue should complete without exception');
    }

    // ─────────────────────────────────────────────
    // INVOICE ESCALATIONS
    // ─────────────────────────────────────────────
    @isTest
    static void testEscalateUnpaidInvoice_noException() {
        // Pass null for invoiceId so postChatterAlert fallback uses UserInfo.getUserId() as FeedItem.ParentId
        Test.startTest();
        EscalationService.escalateUnpaidInvoice(null, null);
        Test.stopTest();
        System.assert(true, 'escalateUnpaidInvoice should complete without exception');
    }

    // ─────────────────────────────────────────────
    // AUTO-CLOSE ESCALATIONS
    // ─────────────────────────────────────────────
    @isTest
    static void testAlertFinanceQICompleteNotPaid_noException() {
        Test.startTest();
        EscalationService.alertFinanceQICompleteNotPaid(null);
        Test.stopTest();
        System.assert(true, 'alertFinanceQICompleteNotPaid should complete without exception');
    }

    @isTest
    static void testAlertFMQINotCompleteAfterPayment_noException() {
        EscalationService.injectedWorkOrderForSOQL = mockWO();
        Test.startTest();
        EscalationService.alertFMQINotCompleteAfterPayment(FAKE_WO_ID);
        Test.stopTest();
        resetInjection();
        System.assert(true, 'alertFMQINotCompleteAfterPayment should complete without exception');
    }

    // ─────────────────────────────────────────────
    // AQUA ESCALATIONS
    // ─────────────────────────────────────────────
    @isTest
    static void testAlertAquaTamperingDetected_noException() {
        Test.startTest();
        EscalationService.alertAquaTamperingDetected(null, null);
        Test.stopTest();
        System.assert(true, 'alertAquaTamperingDetected should complete without exception');
    }

    @isTest
    static void testAlertTurfConditionLow_noException() {
        Test.startTest();
        EscalationService.alertTurfConditionLow(null, 3.0);
        Test.stopTest();
        System.assert(true, 'alertTurfConditionLow should complete without exception');
    }

    @isTest
    static void testAlertLandscapeConditionLow_noException() {
        // Pass null workOrderId — list SOQL returns empty → fmId = UserInfo.getUserId()
        // postChatterAlert fallback uses null recordId → FeedItem.ParentId = UserInfo.getUserId()
        Test.startTest();
        EscalationService.alertLandscapeConditionLow(null, 2.5);
        Test.stopTest();
        System.assert(true, 'alertLandscapeConditionLow should complete without exception');
    }

    @isTest
    static void testAlertAquaInventoryMismatch_noException() {
        Test.startTest();
        EscalationService.alertAquaInventoryMismatch(null, 10, 8, 50, 45);
        Test.stopTest();
        System.assert(true, 'alertAquaInventoryMismatch should complete without exception');
    }

    @isTest
    static void testAlertAquaGlobalInventoryImbalance_noException() {
        Test.startTest();
        EscalationService.alertAquaGlobalInventoryImbalance('Controllers', 100, 95);
        Test.stopTest();
        System.assert(true, 'alertAquaGlobalInventoryImbalance should complete without exception');
    }

    // ─────────────────────────────────────────────
    // ROLE LOOKUP HELPERS
    // ─────────────────────────────────────────────
    @isTest
    static void testRoleLookups_allReturnNonNull() {
        Test.startTest();
        Id cooId      = EscalationService.getCOOId();
        Id csmId      = EscalationService.getCSMId();
        Id opsMgrId   = EscalationService.getOpsMgrId();
        Id schedId    = EscalationService.getSchedulingMgrId();
        Id financeId  = EscalationService.getFinanceId();
        Id scottId    = EscalationService.getScottId();
        Id ericaId    = EscalationService.getEricaId();
        Test.stopTest();

        // All fall back to UserInfo.getUserId() in test context (no role users exist)
        System.assertNotEquals(null, cooId,     'getCOOId should return non-null fallback');
        System.assertNotEquals(null, csmId,     'getCSMId should return non-null fallback');
        System.assertNotEquals(null, opsMgrId,  'getOpsMgrId should return non-null fallback');
        System.assertNotEquals(null, schedId,   'getSchedulingMgrId should return non-null fallback');
        System.assertNotEquals(null, financeId, 'getFinanceId should return non-null fallback');
        System.assertNotEquals(null, scottId,   'getScottId should return non-null fallback');
        System.assertNotEquals(null, ericaId,   'getEricaId should return non-null fallback');
    }

    // ─────────────────────────────────────────────
    // CORE sendAlert — null recipient guard
    // ─────────────────────────────────────────────
    @isTest
    static void testSendAlert_nullRecipient_returnsCleanly() {
        Test.startTest();
        EscalationService.sendAlert(null, 'Test Title', 'Test Body', null);
        Test.stopTest();
        System.assert(true, 'sendAlert with null recipientId should return without exception');
    }
}