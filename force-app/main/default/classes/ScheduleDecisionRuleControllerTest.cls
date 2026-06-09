@IsTest(SeeAllData=false)
private class ScheduleDecisionRuleControllerTest {

    @IsTest
    static void getActiveRules_returnsLiveActive_filtersInactive_branchesCss() {
        System.runAs(LovingTestContext.minimalAdmin()) {
            insert new List<Schedule_Decision_Rule__c>{
                new Schedule_Decision_Rule__c(Name='RA', Condition__c='Human required', Source__c='Test', System_Response__c='Needs review', Human_in_Loop__c=true,  Sort_Order__c=1,  Active__c=true),
                new Schedule_Decision_Rule__c(Name='RB', Condition__c='Auto-proceed',   Source__c='Test', System_Response__c='Proceed',      Human_in_Loop__c=false, Sort_Order__c=2,  Active__c=true),
                new Schedule_Decision_Rule__c(Name='RC', Condition__c='Inactive',      Source__c='Test', System_Response__c='Skip',         Human_in_Loop__c=true,  Sort_Order__c=99, Active__c=false)
            };
        }
        Test.startTest();
        List<ScheduleDecisionRuleController.DecisionRuleDto> result =
            ScheduleDecisionRuleController.getActiveRules();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(2, result.size(), 'Inactive rule must be excluded');
        Boolean fHuman=false, fAuto=false;
        for (ScheduleDecisionRuleController.DecisionRuleDto d : result) {
            System.assertNotEquals(null, d.id);
            System.assertNotEquals(null, d.source);
            System.assertNotEquals(null, d.name);
            System.assertNotEquals(null, d.condition);
            System.assertNotEquals(null, d.systemAction);
            if (d.requiresHuman == 'Yes') {
                fHuman = true;
                System.assertEquals('warn-row', d.rowCss);
                System.assertEquals('chip chip-amber', d.humanCss);
            }
            if (d.requiresHuman == 'No') {
                fAuto = true;
                System.assertEquals('', d.rowCss);
                System.assertEquals('chip chip-green', d.humanCss);
            }
        }
        System.assert(fHuman, 'Human-in-loop path covered');
        System.assert(fAuto, 'Automatic path covered');
    }

    @IsTest
    static void dtoSettersAndGetters_directConstruct() {
        ScheduleDecisionRuleController.DecisionRuleDto d = new ScheduleDecisionRuleController.DecisionRuleDto();
        d.id = null;
        d.name = 'X';
        d.condition = 'cond';
        d.source = 'src';
        d.systemAction = 'sys';
        d.requiresHuman = 'No';
        d.rowCss = '';
        d.humanCss = 'chip';
        System.assertEquals('X', d.name);
        System.assertEquals('cond', d.condition);
        System.assertEquals('No', d.requiresHuman);
    }

    // ── Editable Weight/Optimization rules ──────────────────────────────────

    /** Creates a user and (optionally) grants the rules-admin permission set,
     *  isolating setup-object DML from the Schedule_Decision_Rule__c DML. */
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
        List<ScheduleDecisionRuleController.EditableRuleDto> rules =
            new List<ScheduleDecisionRuleController.EditableRuleDto>();

        ScheduleDecisionRuleController.EditableRuleDto w1 = new ScheduleDecisionRuleController.EditableRuleDto();
        w1.ruleType = 'Weight'; w1.name = 'Drive time'; w1.favors = 'Minimize drive time';
        w1.weightPct = 60; w1.appliesTo = 'All crews'; w1.active = true; w1.sortOrder = 0;
        rules.add(w1);

        ScheduleDecisionRuleController.EditableRuleDto w2 = new ScheduleDecisionRuleController.EditableRuleDto();
        w2.ruleType = 'Weight'; w2.name = 'Skill match'; w2.favors = 'Best skill match';
        w2.weightPct = 40; w2.appliesTo = 'All crews'; w2.active = true; w2.sortOrder = 1;
        rules.add(w2);

        ScheduleDecisionRuleController.EditableRuleDto o1 = new ScheduleDecisionRuleController.EditableRuleDto();
        o1.ruleType = 'Optimization'; o1.name = 'Stop cap'; o1.setting = 'Max 8 stops per crew';
        o1.appliesTo = 'All crews'; o1.active = true; o1.sortOrder = 0;
        rules.add(o1);

        return JSON.serialize(rules);
    }

    @IsTest
    static void editableRules_adminSavesReadsAndDeletes() {
        User admin = makeUser('redadm', true);

        ScheduleDecisionRuleController.EditableRulesBundle saved;
        System.runAs(admin) {
            Test.startTest();
            saved = ScheduleDecisionRuleController.saveEditableRules(validRulesJson());
            Test.stopTest();
        }
        System.assertEquals(true, saved.canEdit, 'Admin can edit');
        System.assertEquals(3, saved.rules.size(), 'All three editable rules persist');
        System.assertEquals(3, [SELECT COUNT() FROM Schedule_Decision_Rule__c
            WHERE Rule_Type__c IN ('Weight','Optimization')]);

        Schedule_Decision_Rule__c first = [SELECT Id FROM Schedule_Decision_Rule__c
            WHERE Rule_Type__c IN ('Weight','Optimization') LIMIT 1];
        ScheduleDecisionRuleController.EditableRulesBundle afterDelete;
        System.runAs(admin) {
            ScheduleDecisionRuleController.deleteRule(first.Id);
            afterDelete = ScheduleDecisionRuleController.getEditableRules();
        }
        System.assertEquals(2, afterDelete.rules.size(), 'One editable rule deleted');
    }

    @IsTest
    static void editableRules_rejectsWhenNot100() {
        User admin = makeUser('redbad', true);

        List<ScheduleDecisionRuleController.EditableRuleDto> rules =
            new List<ScheduleDecisionRuleController.EditableRuleDto>();
        ScheduleDecisionRuleController.EditableRuleDto w1 = new ScheduleDecisionRuleController.EditableRuleDto();
        w1.ruleType = 'Weight'; w1.name = 'A'; w1.weightPct = 50; w1.active = true;
        rules.add(w1);
        ScheduleDecisionRuleController.EditableRuleDto w2 = new ScheduleDecisionRuleController.EditableRuleDto();
        w2.ruleType = 'Weight'; w2.name = 'B'; w2.weightPct = 40; w2.active = true;
        rules.add(w2);

        Boolean threw = false;
        System.runAs(admin) {
            Test.startTest();
            try {
                ScheduleDecisionRuleController.saveEditableRules(JSON.serialize(rules));
            } catch (AuraHandledException e) { threw = true; }
            Test.stopTest();
        }
        System.assertEquals(true, threw, 'Save rejected when weights != 100%');
        System.assertEquals(0, [SELECT COUNT() FROM Schedule_Decision_Rule__c
            WHERE Rule_Type__c IN ('Weight','Optimization')]);
    }

    @IsTest
    static void editableRules_nonAdminCannotWrite() {
        User plain = makeUser('redpln', false);
        Boolean saveThrew = false, deleteThrew = false;
        System.runAs(plain) {
            Test.startTest();
            try { ScheduleDecisionRuleController.saveEditableRules(validRulesJson()); }
            catch (AuraHandledException e) { saveThrew = true; }
            try { ScheduleDecisionRuleController.deleteRule(null); }
            catch (AuraHandledException e) { deleteThrew = true; }
            Test.stopTest();
        }
        System.assertEquals(true, saveThrew, 'Non-admin save must throw');
        System.assertEquals(true, deleteThrew, 'Non-admin delete must throw');
    }

    @IsTest
    static void editableRules_readOnlyForNonAdmin() {
        User admin = makeUser('redsd', true);
        System.runAs(admin) { ScheduleDecisionRuleController.saveEditableRules(validRulesJson()); }

        User plain = makeUser('redro', false);
        ScheduleDecisionRuleController.EditableRulesBundle bundle;
        System.runAs(plain) {
            Test.startTest();
            bundle = ScheduleDecisionRuleController.getEditableRules();
            Test.stopTest();
        }
        System.assertEquals(false, bundle.canEdit, 'Plain user reads tab read-only');
    }
}
