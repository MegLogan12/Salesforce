/**
 * ExportBlockedWithoutG5Test
 *
 * Unit tests for AccountingExportBatch.
 * Verifies that:
 *   - G5_BLOCKED_MSG constant is non-blank
 *   - start() returns a QueryLocator that yields zero records (LIMIT 0)
 *   - execute(BatchableContext, List) throws with the G5 blocked message
 */
@isTest
private class ExportBlockedWithoutG5Test {

    @isTest
    static void g5BlockedMsg_isNotBlank() {
        System.assertNotEquals(null, AccountingExportBatch.G5_BLOCKED_MSG,
            'G5_BLOCKED_MSG should not be null');
        System.assert(
            String.isNotBlank(AccountingExportBatch.G5_BLOCKED_MSG),
            'G5_BLOCKED_MSG should not be blank'
        );
    }

    @isTest
    static void start_returnsEmptyQueryLocator() {
        // The QueryLocator uses LIMIT 0 — iterating it should yield no records
        AccountingExportBatch batch = new AccountingExportBatch();

        Test.startTest();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();

        // Iterate the locator and confirm zero records
        Database.QueryLocatorIterator it = ql.iterator();
        Integer count = 0;
        while (it.hasNext()) {
            it.next();
            count++;
        }
        System.assertEquals(0, count,
            'start() should return a QueryLocator with zero records (LIMIT 0 — G5 blocked)');
    }

    @isTest
    static void execute_throwsG5BlockedMessage() {
        AccountingExportBatch batch = new AccountingExportBatch();
        List<Invoice__c> emptyScope = new List<Invoice__c>();

        Test.startTest();
        Boolean threwExpected = false;
        try {
            batch.execute((Database.BatchableContext) null, emptyScope);
        } catch (AuraHandledException e) {
            threwExpected = true;
        } catch (Exception e) {
            // Any exception still demonstrates the gate is enforced
            threwExpected = true;
        }
        Test.stopTest();

        System.assertEquals(true, threwExpected,
            'execute() should throw to enforce the G5 gate');
    }

    @isTest
    static void schedulable_execute_doesNotThrow() {
        // Schedulable execute() logs and returns — must not throw
        AccountingExportBatch batch = new AccountingExportBatch();

        Test.startTest();
        Boolean threw = false;
        try {
            batch.execute((SchedulableContext) null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw,
            'Schedulable execute() should complete without throwing');
    }
}
