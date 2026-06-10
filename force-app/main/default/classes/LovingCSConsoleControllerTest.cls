@IsTest
private class LovingCSConsoleControllerTest {
    @IsTest
    static void returnsConsolePayloadWithRealCaseData() {
        Account accountRecord = new Account(Name = 'Console Test Builder');
        insert accountRecord;

        Contact contactRecord = new Contact(
            FirstName = 'Console',
            LastName = 'Tester',
            AccountId = accountRecord.Id
        );
        insert contactRecord;

        Case caseRecord = new Case(
            Subject = 'Same-day builder issue',
            Status = 'New',
            Origin = 'Phone',
            Priority = 'High',
            AccountId = accountRecord.Id,
            ContactId = contactRecord.Id
        );
        insert caseRecord;

        Test.startTest();
        Map<String, Object> payload = LovingCustomerSuccessConsoleController.getConsoleData();
        Test.stopTest();

        System.assertNotEquals(null, payload, 'Payload should be returned.');
        System.assert(payload.containsKey('features'), 'Feature audit should be included.');
        System.assert(payload.containsKey('metrics'), 'Metrics should be included.');
        System.assert(payload.containsKey('recordsByTab'), 'Tab records should be included.');
        System.assert(payload.containsKey('sourceMap'), 'Source map should be included.');
        System.assert(payload.containsKey('buttonMatrix'), 'Button matrix should be included.');

        Map<String, Object> metrics = (Map<String, Object>)payload.get('metrics');
        System.assert(((Integer)metrics.get('openCases')) >= 1, 'Open case count should include the test case.');

        Map<String, Object> recordsByTab = (Map<String, Object>)payload.get('recordsByTab');
        System.assert(recordsByTab.containsKey('cases'), 'Cases tab rows should be included.');
    }
}