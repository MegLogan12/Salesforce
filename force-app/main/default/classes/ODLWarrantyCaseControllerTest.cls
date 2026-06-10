@IsTest
private class ODLWarrantyCaseControllerTest {
    @IsTest
    static void returnsCaseWarrantyControlDataWithoutFakingCoverage() {
        Account acct = new Account(Name = 'Warranty Test Household');
        insert acct;

        Contact contact = new Contact(FirstName = 'Robin', LastName = 'Warranty', AccountId = acct.Id);
        insert contact;

        Case c = new Case(
            AccountId = acct.Id,
            ContactId = contact.Id,
            Subject = 'Paver settling near fire feature',
            Status = 'New',
            Origin = 'Phone',
            Priority = 'Medium',
            Reason = 'New problem'
        );
        insert c;

        Task t = new Task(WhatId = c.Id, Subject = 'Review warranty claim', Status = 'Not Started', Priority = 'Normal');
        insert t;

        Test.startTest();
        ODLWarrantyCaseController.WarrantyCaseData data = ODLWarrantyCaseController.getWarrantyCaseData(c.Id);
        Test.stopTest();

        System.assertEquals(c.Id, data.caseId);
        System.assertEquals('Paver settling near fire feature', data.subject);
        System.assertEquals('Pending Determination', data.coverageState);
        System.assertEquals(false, data.decisionEnabled);
        System.assert(data.decisionDisabledReason.contains('No Case coverage determination field'));
        System.assert(!data.highlights.isEmpty(), 'Highlights should render from real Case values.');
        System.assert(!data.evidence.isEmpty(), 'Evidence panel should render even when counts are zero.');
        System.assert(!data.resolutionPath.isEmpty(), 'Resolution paths should render locked before determination.');
        System.assert(!data.auditGaps.isEmpty(), 'Missing warranty model fields must be visible as gaps.');
        System.assertEquals(1, data.taskCount);
    }

    @IsTest
    static void rejectsMissingRecordId() {
        Test.startTest();
        try {
            ODLWarrantyCaseController.getWarrantyCaseData(null);
            System.assert(false, 'Expected missing id exception.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}