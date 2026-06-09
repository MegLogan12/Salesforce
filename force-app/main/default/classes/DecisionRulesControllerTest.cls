/**
 * DecisionRulesControllerTest
 * Covers read, the rules-admin write gate, the 100%-weight rule, persistence,
 * and delete for DecisionRulesController.
 */
@isTest
private class DecisionRulesControllerTest {

    // ── helpers ───────────────────────────────────────────────────────────

    /**
     * Creates a user and (optionally) grants the rules-admin permission set.
     * User + PermissionSetAssignment are setup-object DML, so they run inside
     * System.runAs to avoid MIXED_DML with the Decision_Rule__c DML the tests do.
     */
    private static User makeUser(String alias, Boolean rulesAdmin) {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            String uniq = alias + System.now().getTime();
            u = new User(
                Alias             = alias.left(8),
                Email             = uniq + '@loving.test',
                Username          = uniq + '@loving.test.example',
                LastName          = 'Tester',
                ProfileId         = p.Id,
                TimeZoneSidKey    = 'America/New_York',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
            insert u;
            if (rulesAdmin) {
                PermissionSet ps = [
                    SELECT Id FROM PermissionSet
                    WHERE Name = 'LOVING_Scheduling_Rules_Admin' LIMIT 1
                ];
                insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
            }
        }
        return u;
    }

    /** Two weight rows (60 + 40 = 100) plus one optimization rule. */
    private static String validRulesJson() {
        List<DecisionRulesController.RuleDto> rules =
            new List<DecisionRulesController.RuleDto>();

        DecisionRulesController.RuleDto w1 = new DecisionRulesController.RuleDto();
        w1.ruleType = 'Weight'; w1.name = 'Drive time'; w1.favors = 'Minimize drive time';
        w1.weightPct = 60; w1.appliesTo = 'All crews'; w1.active = true; w1.sortOrder = 0;
        rules.add(w1);

        DecisionRulesController.RuleDto w2 = new DecisionRulesController.RuleDto();
        w2.ruleType = 'Weight'; w2.name = 'Skill match'; w2.favors = 'Best skill match';
        w2.weightPct = 40; w2.appliesTo = 'All crews'; w2.active = true; w2.sortOrder = 1;
        rules.add(w2);

        DecisionRulesController.RuleDto o1 = new DecisionRulesController.RuleDto();
        o1.ruleType = 'Optimization'; o1.name = 'Stop cap'; o1.setting = 'Max 8 stops per crew';
        o1.appliesTo = 'All crews'; o1.active = true; o1.sortOrder = 0;
        rules.add(o1);

        return JSON.serialize(rules);
    }

    // ── tests ─────────────────────────────────────────────────────────────

    @isTest
    static void adminCanSaveAndRead() {
        User admin = makeUser('radmin', true);

        DecisionRulesController.RulesBundle saved;
        System.runAs(admin) {
            Test.startTest();
            saved = DecisionRulesController.saveRules(validRulesJson());
            Test.stopTest();
        }

        System.assertEquals(true, saved.canEdit, 'Admin should be able to edit');
        System.assertEquals(3, saved.rules.size(), 'All three rules should persist');
        System.assertEquals(3, [SELECT COUNT() FROM Decision_Rule__c],
            'Records should be in the database');
    }

    @isTest
    static void saveRejectedWhenWeightsNot100() {
        User admin = makeUser('rbad', true);

        // Two weight rows totalling 90, not 100.
        List<DecisionRulesController.RuleDto> rules =
            new List<DecisionRulesController.RuleDto>();
        DecisionRulesController.RuleDto w1 = new DecisionRulesController.RuleDto();
        w1.ruleType = 'Weight'; w1.name = 'A'; w1.weightPct = 50; w1.active = true;
        rules.add(w1);
        DecisionRulesController.RuleDto w2 = new DecisionRulesController.RuleDto();
        w2.ruleType = 'Weight'; w2.name = 'B'; w2.weightPct = 40; w2.active = true;
        rules.add(w2);

        Boolean threw = false;
        System.runAs(admin) {
            Test.startTest();
            try {
                DecisionRulesController.saveRules(JSON.serialize(rules));
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
        }
        System.assertEquals(true, threw, 'Save should be rejected when weights != 100%');
        System.assertEquals(0, [SELECT COUNT() FROM Decision_Rule__c],
            'Nothing should persist when validation fails');
    }

    @isTest
    static void nonAdminCannotWrite() {
        User plain = makeUser('rplain', false);

        Boolean saveThrew = false;
        Boolean deleteThrew = false;
        System.runAs(plain) {
            Test.startTest();
            try {
                DecisionRulesController.saveRules(validRulesJson());
            } catch (AuraHandledException e) { saveThrew = true; }
            try {
                DecisionRulesController.deleteRule(null);
            } catch (AuraHandledException e) { deleteThrew = true; }
            Test.stopTest();
        }
        System.assertEquals(true, saveThrew, 'Non-admin save must throw');
        System.assertEquals(true, deleteThrew, 'Non-admin delete must throw');
    }

    @isTest
    static void adminCanDeleteAndReadRemaining() {
        User admin = makeUser('rdel', true);

        System.runAs(admin) {
            DecisionRulesController.saveRules(validRulesJson());
        }
        Decision_Rule__c first = [SELECT Id FROM Decision_Rule__c LIMIT 1];

        DecisionRulesController.RulesBundle bundle;
        System.runAs(admin) {
            Test.startTest();
            DecisionRulesController.deleteRule(first.Id);
            bundle = DecisionRulesController.getRules();
            Test.stopTest();
        }
        System.assertEquals(2, bundle.rules.size(), 'One rule should have been deleted');
        System.assertEquals(true, bundle.canEdit, 'Admin reads with canEdit true');
    }

    @isTest
    static void readReflectsNoEditForPlainUser() {
        // Seed records as an admin, then read as a plain user.
        User admin = makeUser('rseed', true);
        System.runAs(admin) { DecisionRulesController.saveRules(validRulesJson()); }

        User plain = makeUser('rread', false);

        DecisionRulesController.RulesBundle bundle;
        System.runAs(plain) {
            Test.startTest();
            bundle = DecisionRulesController.getRules();
            Test.stopTest();
        }
        System.assertEquals(false, bundle.canEdit,
            'Plain user should read the tab as read-only');
    }
}
