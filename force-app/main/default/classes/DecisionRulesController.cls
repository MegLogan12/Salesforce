/**
 * DecisionRulesController
 * Read/write access to the editable scheduling Decision Rules (Decision_Rule__c)
 * surfaced on the Field Services Console "Decision Rules" tab.
 *
 * - Weight rules (Rule_Type__c = 'Weight') carry a Weight_Pct__c; active weight
 *   rows must total exactly 100% before a save is accepted.
 * - Optimization rules (Rule_Type__c = 'Optimization') carry a Setting__c and an
 *   Active__c toggle; toggling one off removes that constraint from future runs.
 *
 * Writes are gated by the LOVING_Edit_Scheduling_Rules custom permission. Users
 * without it can read the tab but every write throws. The optimizer
 * (AutoScheduleService / FSL policy) reads the active rules at run time, so a
 * saved change affects every future proposal.
 */
public with sharing class DecisionRulesController {

    @TestVisible private static final String EDIT_PERM = 'LOVING_Edit_Scheduling_Rules';

    /** A single editable rule row. */
    public class RuleDto {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  ruleType;   // 'Weight' | 'Optimization'
        @AuraEnabled public String  name;
        @AuraEnabled public String  favors;     // weight rules
        @AuraEnabled public Decimal weightPct;  // weight rules
        @AuraEnabled public String  setting;    // optimization rules
        @AuraEnabled public String  appliesTo;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Integer sortOrder;
    }

    /** Read payload: the rules plus whether the running user may edit. */
    public class RulesBundle {
        @AuraEnabled public Boolean       canEdit;
        @AuraEnabled public List<RuleDto> rules;
        public RulesBundle() { this.rules = new List<RuleDto>(); }
    }

    // ─── READ ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static RulesBundle getRules() {
        RulesBundle bundle = new RulesBundle();
        try {
            bundle.canEdit = canEdit();
            for (Decision_Rule__c r : [
                SELECT Id, Name, Rule_Type__c, Favors__c, Weight_Pct__c,
                       Setting__c, Applies_To__c, Active__c, Sort_Order__c
                FROM Decision_Rule__c
                WITH SECURITY_ENFORCED
                ORDER BY Rule_Type__c, Sort_Order__c NULLS LAST, Name
            ]) {
                bundle.rules.add(toDto(r));
            }
        } catch (Exception e) {
            ErrorLogService.log('DecisionRulesController', 'getRules', null, e.getMessage());
            throw new AuraHandledException('Could not load decision rules. ' + e.getMessage());
        }
        return bundle;
    }

    // ─── SAVE (upsert + delete removed) ──────────────────────────────────────

    @AuraEnabled
    public static RulesBundle saveRules(String rulesJson) {
        assertCanEdit();

        List<RuleDto> incoming;
        try {
            incoming = (List<RuleDto>) JSON.deserialize(rulesJson, List<RuleDto>.class);
        } catch (Exception e) {
            throw new AuraHandledException('Could not read the rules to save. Please retry.');
        }
        if (incoming == null) { incoming = new List<RuleDto>(); }

        // Enforce: active Weight rows must total exactly 100%.
        Decimal weightTotal = 0;
        for (RuleDto d : incoming) {
            if (d.ruleType == 'Weight' && d.active != false) {
                weightTotal += (d.weightPct == null ? 0 : d.weightPct);
            }
        }
        if (weightTotal != 100) {
            throw new AuraHandledException(
                'Weights must total exactly 100% before saving (currently '
                + weightTotal.stripTrailingZeros() + '%).');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            List<Decision_Rule__c> toUpsert = new List<Decision_Rule__c>();
            Set<Id> keepIds = new Set<Id>();
            Integer order = 0;
            for (RuleDto d : incoming) {
                Decision_Rule__c r = new Decision_Rule__c();
                if (d.id != null) { r.Id = d.id; keepIds.add(d.id); }
                r.Name          = String.isBlank(d.name) ? 'Rule' : d.name.left(80);
                r.Rule_Type__c  = d.ruleType;
                r.Favors__c     = d.favors;
                r.Weight_Pct__c = d.weightPct;
                r.Setting__c    = d.setting;
                r.Applies_To__c = String.isBlank(d.appliesTo) ? 'All crews' : d.appliesTo;
                r.Active__c     = d.active != false;
                r.Sort_Order__c = (d.sortOrder != null) ? d.sortOrder : order;
                toUpsert.add(r);
                order++;
            }

            // Delete rows the user removed in the UI.
            List<Decision_Rule__c> toDelete = new List<Decision_Rule__c>();
            for (Decision_Rule__c existing : [
                SELECT Id FROM Decision_Rule__c WITH SECURITY_ENFORCED
            ]) {
                if (!keepIds.contains(existing.Id)) { toDelete.add(existing); }
            }

            if (!toUpsert.isEmpty()) { upsert toUpsert; }
            if (!toDelete.isEmpty()) { delete toDelete; }
        } catch (Exception e) {
            Database.rollback(sp);
            ErrorLogService.log('DecisionRulesController', 'saveRules', null, e.getMessage());
            throw new AuraHandledException('Could not save decision rules. ' + e.getMessage());
        }
        return getRulesFresh();
    }

    // ─── DELETE one ───────────────────────────────────────────────────────────

    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        assertCanEdit();
        try {
            delete [SELECT Id FROM Decision_Rule__c WHERE Id = :ruleId WITH SECURITY_ENFORCED];
        } catch (Exception e) {
            ErrorLogService.log('DecisionRulesController', 'deleteRule', ruleId, e.getMessage());
            throw new AuraHandledException('Could not delete the rule. ' + e.getMessage());
        }
    }

    // ─── helpers ───────────────────────────────────────────────────────────

    private static Boolean canEdit() {
        return FeatureManagement.checkPermission(EDIT_PERM);
    }

    private static void assertCanEdit() {
        if (!canEdit()) {
            throw new AuraHandledException(
                'You do not have permission to edit scheduling decision rules.');
        }
    }

    /** Same as getRules but not cacheable — returned after a write. */
    private static RulesBundle getRulesFresh() {
        RulesBundle bundle = new RulesBundle();
        bundle.canEdit = canEdit();
        for (Decision_Rule__c r : [
            SELECT Id, Name, Rule_Type__c, Favors__c, Weight_Pct__c,
                   Setting__c, Applies_To__c, Active__c, Sort_Order__c
            FROM Decision_Rule__c
            WITH SECURITY_ENFORCED
            ORDER BY Rule_Type__c, Sort_Order__c NULLS LAST, Name
        ]) {
            bundle.rules.add(toDto(r));
        }
        return bundle;
    }

    private static RuleDto toDto(Decision_Rule__c r) {
        RuleDto d   = new RuleDto();
        d.id        = r.Id;
        d.ruleType  = r.Rule_Type__c;
        d.name      = r.Name;
        d.favors    = r.Favors__c;
        d.weightPct = r.Weight_Pct__c;
        d.setting   = r.Setting__c;
        d.appliesTo = r.Applies_To__c;
        d.active    = r.Active__c;
        d.sortOrder = (r.Sort_Order__c == null) ? null : Integer.valueOf(r.Sort_Order__c);
        return d;
    }
}
