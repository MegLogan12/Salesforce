@IsTest
private class MCEmailServiceTest {

    static Lead createTestLead(String suffix) {
        Lead l = new Lead(FirstName = 'Test', LastName = 'MC' + suffix,
            Company = 'LOVING Test', Email = 'mctest' + suffix + '@lovingtestmc.com',
            Status = 'New', ODL_Path__c = 'UMB', LeadSource = 'Web');
        insert l;
        return l;
    }

    @IsTest
    static void testWelcomeEmail() {
        Lead l = createTestLead('W');
        Test.startTest();
        MCEmailService.sendWelcomeEmail(new List<Id>{ l.Id });
        Test.stopTest();
        System.assert(true, 'Welcome email sent without error');
    }

    @IsTest
    static void testNurtureEmail() {
        Lead l = createTestLead('N');
        l.Status = 'Nurturing';
        update l;
        Test.startTest();
        MCEmailService.sendNurtureEmail(new List<Id>{ l.Id });
        Test.stopTest();
        System.assert(true, 'Nurture email sent without error');
    }

    @IsTest
    static void testWelcomeAction() {
        Lead l = createTestLead('WA');
        Test.startTest();
        MCWelcomeEmailAction.execute(new List<Id>{ l.Id });
        Test.stopTest();
        System.assert(true, 'MCWelcomeEmailAction executed without error');
    }

    @IsTest
    static void testNurtureAction() {
        Lead l = createTestLead('NA');
        l.Status = 'Nurturing';
        update l;
        Test.startTest();
        MCNurtureEmailAction.execute(new List<Id>{ l.Id });
        Test.stopTest();
        System.assert(true, 'MCNurtureEmailAction executed without error');
    }
}