@IsTest
private class UMBDesignOptionControllerTest {

    @TestSetup
    static void setup() {
        // Grant the running user FLS on the new object/fields so WITH SECURITY_ENFORCED passes.
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'LOVING_UMB_Design_Options' LIMIT 1];
        List<PermissionSetAssignment> already = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :ps.Id
        ];
        if (already.isEmpty()) {
            insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = ps.Id);
        }

        Opportunity opp = new Opportunity(
            Name = 'Test UMB Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        List<UMB_Design_Option__c> options = new List<UMB_Design_Option__c>{
            new UMB_Design_Option__c(Name = 'Retreat', Opportunity__c = opp.Id, Tier__c = 'Retreat',
                Price__c = 18500, Sort_Order__c = 1, Features__c = 'Patio\nPlanting refresh'),
            new UMB_Design_Option__c(Name = 'Entertainer', Opportunity__c = opp.Id, Tier__c = 'Entertainer',
                Price__c = 34000, Sort_Order__c = 2, Features__c = 'Paver patio\nGrill island'),
            new UMB_Design_Option__c(Name = 'Signature', Opportunity__c = opp.Id, Tier__c = 'Signature',
                Price__c = 58000, Sort_Order__c = 3, Features__c = 'Full transformation')
        };
        insert options;
    }

    // Re-run as the current user so the @TestSetup permission-set assignment refreshes FLS
    // for WITH SECURITY_ENFORCED queries.
    private static User currentUser() {
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    }

    @IsTest
    static void testGetDesignOptions() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<UMB_Design_Option__c> result;
        Test.startTest();
        System.runAs(currentUser()) {
            result = UMBDesignOptionController.getDesignOptions(opp.Id);
        }
        Test.stopTest();
        System.assertEquals(3, result.size(), 'Should return three design options');
        System.assertEquals('Retreat', result[0].Tier__c, 'First option should be Retreat by sort order');
    }

    @IsTest
    static void testSelectDesignOption() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        UMB_Design_Option__c entertainer = [SELECT Id FROM UMB_Design_Option__c WHERE Tier__c = 'Entertainer' LIMIT 1];

        Test.startTest();
        System.runAs(currentUser()) {
            UMBDesignOptionController.selectDesignOption(entertainer.Id, opp.Id);
        }
        Test.stopTest();

        UMB_Design_Option__c chosen = [SELECT Is_Selected__c FROM UMB_Design_Option__c WHERE Id = :entertainer.Id];
        System.assertEquals(true, chosen.Is_Selected__c, 'Chosen option should be selected');

        Integer selectedCount = [SELECT COUNT() FROM UMB_Design_Option__c WHERE Opportunity__c = :opp.Id AND Is_Selected__c = true];
        System.assertEquals(1, selectedCount, 'Only one option may be selected');

        Opportunity updated = [SELECT Selected_Package__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Entertainer', updated.Selected_Package__c, 'Opportunity should sync to chosen tier');
    }

    @IsTest
    static void testEmptyState() {
        Opportunity empty = new Opportunity(Name = 'No Designs', StageName = 'Prospecting', CloseDate = Date.today());
        insert empty;
        List<UMB_Design_Option__c> result;
        Test.startTest();
        System.runAs(currentUser()) {
            result = UMBDesignOptionController.getDesignOptions(empty.Id);
        }
        Test.stopTest();
        System.assertEquals(0, result.size(), 'No options should return empty list');
    }
}