@IsTest
private class ErrorLogServiceTest {

    @IsTest
    static void logCreatesErrorLogRecord() {
        Test.startTest();
        ErrorLogService.log('TestClass', 'testMethod', null, 'Something went wrong');
        Test.stopTest();

        Error_Log__c err = [
            SELECT Class_Name__c, Method_Name__c, Message__c, User__c, Logged_At__c
            FROM Error_Log__c LIMIT 1
        ];
        System.assertEquals('TestClass', err.Class_Name__c);
        System.assertEquals('testMethod', err.Method_Name__c);
        System.assertEquals('Something went wrong', err.Message__c);
        System.assertEquals(UserInfo.getUserId(), err.User__c);
        System.assertNotEquals(null, err.Logged_At__c);
    }

    @IsTest
    static void logWithRecordId() {
        Id recordId = (Id) '0WO000000000001AAA';

        Test.startTest();
        ErrorLogService.log('SomeService', 'someMethod', recordId, 'Boom');
        Test.stopTest();

        Error_Log__c err = [SELECT Record_Id__c FROM Error_Log__c LIMIT 1];
        System.assertEquals(recordId, (Id)err.Record_Id__c);
    }

    @IsTest
    static void logTruncatesLongMessage() {
        String longMsg = 'X'.repeat(40000);
        Test.startTest();
        ErrorLogService.log('Class', 'method', null, longMsg);
        Test.stopTest();

        Error_Log__c err = [SELECT Message__c FROM Error_Log__c LIMIT 1];
        System.assertEquals(32768, err.Message__c.length(), 'Message truncated to 32768 chars');
    }
}