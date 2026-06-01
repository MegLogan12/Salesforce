@IsTest
private class ODLOpportunityCloseControllerTest {

    private static RecordType umbRt() {
        return [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'UMB' LIMIT 1];
    }

    private static RecordType dbRt() {
        return [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Design_Build' LIMIT 1];
    }

    private static Account makeAccount(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    @IsTest
    static void testGetClosePageData_nullThrows() {
        Boolean threw = false;
        try {
            ODLOpportunityCloseController.getClosePageData(null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assert(threw, 'Should throw AuraHandledException for null Id');
    }

    @IsTest
    static void testGetClosePageData_umbOpp_blocked() {
        Account a = makeAccount('Close Blocked Account');
        Opportunity opp = new Opportunity(
            Name = 'Close Blocked Opp',
            AccountId = a.Id,
            StageName = 'Consult Scheduled',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = umbRt().Id,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityCloseController.ClosePageData result =
            ODLOpportunityCloseController.getClosePageData(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return ClosePageData');
        System.assertEquals('UMB', result.recordTypeName);
        System.assertEquals(true, result.isUmb);
        System.assertEquals(false, result.readiness.woReady);
        System.assertEquals(false, result.readiness.quoteAccepted);
        System.assertEquals('Blocked', result.readiness.readinessBadge);
        System.assertNotEquals(null, result.readiness.blockerLine);
        System.assertNotEquals(null, result.paymentSchedule);
        System.assertEquals(false, result.paymentSchedule.hasVoucher);
    }

    @IsTest
    static void testGetClosePageData_umbOpp_woReady() {
        Account a = makeAccount('WO Ready Close Account');
        Opportunity opp = new Opportunity(
            Name = 'WO Ready Close Opp',
            AccountId = a.Id,
            StageName = 'Quote Accepted',
            CloseDate = Date.today().addDays(10),
            RecordTypeId = umbRt().Id,
            Amount = 25000,
            Deposit_Due__c = 5000,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Signed',
            Deposit_Paid__c = true,
            Deposit_Paid_Date__c = Date.today().addDays(-1)
        );
        insert opp;

        Test.startTest();
        ODLOpportunityCloseController.ClosePageData result =
            ODLOpportunityCloseController.getClosePageData(opp.Id);
        Test.stopTest();

        System.assertEquals(true, result.readiness.woReady);
        System.assertEquals('WO Ready', result.readiness.readinessBadge);
        System.assertEquals('badge badge-green', result.readiness.badgeClass);
        System.assertEquals(null, result.readiness.blockerLine);

        ODLOpportunityCloseController.PaymentSchedule ps = result.paymentSchedule;
        System.assertEquals(25000, ps.contractTotal);
        System.assertEquals(0, ps.voucherCredit);
        System.assertEquals(25000, ps.customerBalance);
        System.assertEquals(5000, ps.depositDue);
        System.assertEquals(true, ps.depositIsPaid);
        System.assertEquals(20000, ps.remainingBalance);
        System.assertEquals('$25,000', ps.formattedContractTotal);
        System.assertEquals('$5,000', ps.formattedDepositDue);
        System.assertEquals('$20,000', ps.formattedRemainingBalance);
    }

    @IsTest
    static void testGetClosePageData_designBuildOpp() {
        Account a = makeAccount('DB Close Account');
        Opportunity opp = new Opportunity(
            Name = 'DB Close Opp',
            AccountId = a.Id,
            StageName = 'Proposal Presented',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = dbRt().Id,
            Amount = 75000,
            Quote_Status__c = 'Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityCloseController.ClosePageData result =
            ODLOpportunityCloseController.getClosePageData(opp.Id);
        Test.stopTest();

        System.assertEquals('Design_Build', result.recordTypeName);
        System.assertEquals(false, result.isUmb);
        System.assertEquals(false, result.readiness.quoteAccepted);
        System.assertEquals(false, result.readiness.woReady);
        System.assertEquals(75000, result.paymentSchedule.contractTotal);
        System.assertEquals('$75,000', result.paymentSchedule.formattedContractTotal);
    }

    @IsTest
    static void testGetClosePageData_blockedOnContract() {
        Account a = makeAccount('Contract Blocked Account');
        Opportunity opp = new Opportunity(
            Name = 'Contract Blocked Opp',
            AccountId = a.Id,
            StageName = 'Quote Accepted',
            CloseDate = Date.today().addDays(14),
            RecordTypeId = umbRt().Id,
            Amount = 18000,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Sent',
            Deposit_Paid__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityCloseController.ClosePageData result =
            ODLOpportunityCloseController.getClosePageData(opp.Id);
        Test.stopTest();

        System.assertEquals(true, result.readiness.quoteAccepted);
        System.assertEquals(false, result.readiness.contractSigned);
        System.assertEquals(false, result.readiness.woReady);
        System.assertEquals('Blocked', result.readiness.readinessBadge);
        System.assert(
            result.readiness.blockerLine.toLowerCase().contains('contract'),
            'Blocker line should mention contract: ' + result.readiness.blockerLine
        );
    }

    @IsTest
    static void testGetClosePageData_blockedOnDeposit() {
        Account a = makeAccount('Deposit Blocked Account');
        Opportunity opp = new Opportunity(
            Name = 'Deposit Blocked Opp',
            AccountId = a.Id,
            StageName = 'Quote Accepted',
            CloseDate = Date.today().addDays(7),
            RecordTypeId = umbRt().Id,
            Amount = 22000,
            Deposit_Due__c = 4400,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Signed',
            Deposit_Paid__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityCloseController.ClosePageData result =
            ODLOpportunityCloseController.getClosePageData(opp.Id);
        Test.stopTest();

        System.assertEquals(true, result.readiness.quoteAccepted);
        System.assertEquals(true, result.readiness.contractSigned);
        System.assertEquals(false, result.readiness.depositPaid);
        System.assertEquals(false, result.readiness.woReady);
        System.assertEquals('badge badge-amber', result.readiness.badgeClass);
        System.assert(
            result.readiness.blockerLine.toLowerCase().contains('deposit'),
            'Blocker line should mention deposit: ' + result.readiness.blockerLine
        );
        System.assertEquals(22000, result.paymentSchedule.remainingBalance, 'Remaining = full balance when deposit not paid');
    }

    @IsTest
    static void testMarkClosedWon_failsWhenNotReady() {
        Account a = makeAccount('Mark Won Not Ready Account');
        Opportunity opp = new Opportunity(
            Name = 'Mark Won Not Ready Opp',
            AccountId = a.Id,
            StageName = 'Quote Sent',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = umbRt().Id,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false
        );
        insert opp;

        Test.startTest();
        Boolean threw = false;
        try {
            ODLOpportunityCloseController.markClosedWon(opp.Id);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when gates are not complete');
        Opportunity result = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Quote Sent', result.StageName, 'Stage should not have changed');
    }

    @IsTest
    static void testMarkClosedWon_successWhenReady() {
        Account a = makeAccount('Mark Won Ready Account');
        Opportunity opp = new Opportunity(
            Name = 'Mark Won Ready Opp',
            AccountId = a.Id,
            StageName = 'Quote Accepted',
            CloseDate = Date.today().addDays(10),
            RecordTypeId = umbRt().Id,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Signed',
            Deposit_Paid__c = true
        );
        insert opp;

        Test.startTest();
        ODLOpportunityCloseController.markClosedWon(opp.Id);
        Test.stopTest();

        Opportunity result = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Closed Won', result.StageName, 'Stage should be Closed Won');
    }

    @IsTest
    static void testMarkClosedWon_failsWhenAlreadyClosed() {
        Account a = makeAccount('Already Won Account');
        Opportunity opp = new Opportunity(
            Name = 'Already Won Opp',
            AccountId = a.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            RecordTypeId = umbRt().Id,
            Quote_Status__c = 'Accepted',
            Contract_Status__c = 'Signed',
            Deposit_Paid__c = true
        );
        insert opp;

        Test.startTest();
        Boolean threw = false;
        try {
            ODLOpportunityCloseController.markClosedWon(opp.Id);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when already Closed Won');
    }

    @IsTest
    static void testFormatCurrency_largeAmount() {
        Account a = makeAccount('Format Test Account');
        Opportunity opp = new Opportunity(
            Name = 'Format Test Opp',
            AccountId = a.Id,
            StageName = 'Consult Scheduled',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = umbRt().Id,
            Amount = 123456.78,
            Deposit_Due__c = 12345,
            Quote_Status__c = 'Not Sent',
            Contract_Status__c = 'Not Sent',
            Deposit_Paid__c = false
        );
        insert opp;

        Test.startTest();
        ODLOpportunityCloseController.ClosePageData result =
            ODLOpportunityCloseController.getClosePageData(opp.Id);
        Test.stopTest();

        System.assertEquals('$123,457', result.paymentSchedule.formattedContractTotal);
        System.assertEquals('$12,345', result.paymentSchedule.formattedDepositDue);
    }
}
