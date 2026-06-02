@isTest
private class ODLOpportunityServiceTest {

    @isTest
    static void testNullOppReturnsFalse() {
        System.assertEquals(false, ODLOpportunityService.isOdlOpportunity(null), 'Null opp should return false.');
    }

    @isTest
    static void testRecordTypeUMBReturnsTrue() {
        // Build a mock opp with RecordType stub — avoids DML
        Opportunity opp = new Opportunity(
            Name      = 'Test UMB',
            StageName = 'New',
            CloseDate = Date.today()
        );
        // Inject RecordType via the canonical check by querying after insert
        Id umbRtId = RecordTypeHelper.getOpportunityRT('UMB');
        if (umbRtId == null) {
            // RecordType not in org — skip gracefully
            System.debug('UMB RecordType not found; skipping RecordType assertion.');
            return;
        }
        opp.RecordTypeId = umbRtId;
        insert opp;
        Opportunity queried = [SELECT Id, Type, LeadSource, BMG_Package__c, RecordType.DeveloperName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(true, ODLOpportunityService.isOdlOpportunity(queried), 'UMB RecordType should return true.');
    }

    @isTest
    static void testRecordTypeDesignBuildReturnsTrue() {
        Id dbRtId = RecordTypeHelper.getOpportunityRT('Design_Build');
        if (dbRtId == null) {
            System.debug('Design_Build RecordType not found; skipping.');
            return;
        }
        Opportunity opp = new Opportunity(
            Name         = 'Test DB',
            StageName    = 'New',
            CloseDate    = Date.today(),
            RecordTypeId = dbRtId
        );
        insert opp;
        Opportunity queried = [SELECT Id, Type, LeadSource, BMG_Package__c, RecordType.DeveloperName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(true, ODLOpportunityService.isOdlOpportunity(queried), 'Design_Build RecordType should return true.');
    }

    @isTest
    static void testFallbackToTypeHeuristic() {
        // No RecordType set — relies on Type heuristic
        Opportunity opp = new Opportunity(
            Name      = 'Test Heuristic',
            StageName = 'New',
            CloseDate = Date.today(),
            Type      = 'UpgradeMyBackyard'
        );
        System.assertEquals(true, ODLOpportunityService.isOdlOpportunity(opp), 'Type=UpgradeMyBackyard without RecordType should return true via heuristic.');
    }

    @isTest
    static void testFallbackToLeadSourceHeuristic() {
        Opportunity opp = new Opportunity(
            Name       = 'Test LeadSource',
            StageName  = 'New',
            CloseDate  = Date.today(),
            LeadSource = 'Lennar Voucher'
        );
        System.assertEquals(true, ODLOpportunityService.isOdlOpportunity(opp), 'LeadSource=Lennar Voucher without RecordType should return true via heuristic.');
    }

    @isTest
    static void testNonOdlOppReturnsFalse() {
        Opportunity opp = new Opportunity(
            Name      = 'Non ODL',
            StageName = 'New',
            CloseDate = Date.today(),
            Type      = 'Other'
        );
        System.assertEquals(false, ODLOpportunityService.isOdlOpportunity(opp), 'Non-ODL opp should return false.');
    }
}
