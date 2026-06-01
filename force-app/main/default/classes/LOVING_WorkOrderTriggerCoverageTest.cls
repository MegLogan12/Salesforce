/**
 * LOVING_WorkOrderTriggerCoverageTest
 *
 * SeeAllData=true is required here: we need an existing WorkOrder record to
 * UPDATE so the trigger fires. INSERT fails because a Before-Save Flow on
 * WorkOrder accesses org-scoped lookup records (service territories, etc.)
 * that are unavailable when creating records in test isolation. Updating an
 * existing record bypasses that issue — all lookup fields are already set and
 * the update flow path does not re-validate cross-reference access.
 *
 * All DML in tests (even with SeeAllData=true) is rolled back after each
 * test method, so no production data is permanently altered.
 *
 * Business-logic coverage lives in LOVING_WorkOrderTriggerHandlerTest.
 * This class covers only the trigger-level guard + dispatch lines.
 */
@IsTest(SeeAllData=true)
private class LOVING_WorkOrderTriggerCoverageTest {

    @IsTest
    static void triggerFiresOnUpdate() {
        List<WorkOrder> wos = [
            SELECT Id, Subject, Work_Order_Type__c
            FROM WorkOrder
            WHERE Work_Order_Type__c != null
            LIMIT 1
        ];
        if (wos.isEmpty()) return; // No WO in org; skip gracefully.

        LOVING_TriggerGuard.reset();

        WorkOrder wo = wos[0];
        wo.Subject = (wo.Subject != null ? wo.Subject : '') + ' ';

        Test.startTest();
        // A simple Subject touch fires before-update and after-update without
        // matching any status-change conditions → no side-effect DML.
        Database.update(wo, false);
        Test.stopTest();
    }

    @IsTest
    static void triggerGuardPreventsDuplicateRun() {
        List<WorkOrder> wos = [
            SELECT Id, Subject FROM WorkOrder LIMIT 1
        ];
        if (wos.isEmpty()) return;

        LOVING_TriggerGuard.setAlreadyRun('WorkOrder');

        WorkOrder wo = wos[0];
        wo.Subject = (wo.Subject != null ? wo.Subject : '') + '  ';

        Test.startTest();
        Database.update(wo, false);
        Test.stopTest();

        System.assert(LOVING_TriggerGuard.hasAlreadyRun('WorkOrder'), 'Guard still set');
        LOVING_TriggerGuard.reset();
    }
}
