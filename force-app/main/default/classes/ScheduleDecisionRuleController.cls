/**
 * ScheduleDecisionRuleController
 * Live Schedule_Decision_Rule__c data for the Scheduling Console Decision Rules tab.
 *
 * - getActiveRules(): legacy read of the Automation rules (condition/response),
 *   consumed by the read-only Decision Rules view. Unchanged behavior.
 * - getEditableRules() / saveEditableRules() / deleteRule(): the editable Weight
 *   and Optimization rule sets per the approved mockup. Active Weight rows must
 *   total exactly 100% before a save is accepted. Writes are gated by the
 *   LOVING_Edit_Scheduling_Rules custom permission; without it the tab is
 *   read-only. The optimizer reads the active rules at run time, so a saved
 *   change affects every future proposal.
 */
public with sharing class ScheduleDecisionRuleController {

    @TestVisible private static final String EDIT_PERM = 'LOVING_Edit_Scheduling_Rules';

    // ─── Legacy read (Automation rules) — used by the live console ────────────

    @AuraEnabled(cacheable=true)
    public static List<DecisionRuleDto> getActiveRules() {
        try {
            List<DecisionRuleDto> out = new List<DecisionRuleDto>();
            for (Schedule_Decision_Rule__c r : [
                SELECT Id, Name, Condition__c, Source__c, System_Response__c,
                       Human_in_Loop__c, Sort_Order__c, Active__c
                FROM Schedule_Decision_Rule__c
                WHERE Active__c = true
                  AND (Rule_Type__c = 'Automation' OR Rule_Type__c = null)
                ORDER BY Sort_Order__c NULLS LAST, Name
            ]) {
                DecisionRuleDto d = new DecisionRuleDto();
                d.id            = r.Id;
                d.name          = r.Name;
                d.condition     = r.Condition__c;
                d.source        = r.Source__c;
                d.systemAction  = r.System_Response__c;
                d.requiresHuman = r.Human_in_Loop__c == true ? 'Yes' : 'No';
                d.rowCss        = r.Human_in_Loop__c == true ? 'warn-row' : '';
                d.humanCss      = r.Human_in_Loop__c == true ? 'chip chip-amber' : 'chip chip-green';
                out.add(d);
            }
            return out;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load decision rules: ' + e.getMessage());
        }
    }

    public class DecisionRuleDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String condition;
        @AuraEnabled public String source;
        @AuraEnabled public String systemAction;
        @AuraEnabled public String requiresHuman;
        @AuraEnabled public String rowCss;
        @AuraEnabled public String humanCss;
    }

    // ─── Editable Weight + Optimization rules ────────────────────────────────

    public class EditableRuleDto {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  ruleType;   // 'Weight' | 'Optimization'
        @AuraEnabled public String  name;
        @AuraEnabled public String  favors;
        @AuraEnabled public Decimal weightPct;
        @AuraEnabled public String  setting;
        @AuraEnabled public String  appliesTo;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Integer sortOrder;
    }

    public class EditableRulesBundle {
        @AuraEnabled public Boolean canEdit;
        @AuraEnabled public List<EditableRuleDto> rules;
        public EditableRulesBundle() { this.rules = new List<EditableRuleDto>(); }
    }

    @AuraEnabled(cacheable=true)
    public static EditableRulesBundle getEditableRules() {
        try {
            return buildEditableBundle();
        } catch (QueryException e) {
            // User lacks field/object read access — show an empty, read-only tab
            // rather than an error wall (build prompt §12).
            EditableRulesBundle empty = new EditableRulesBundle();
            empty.canEdit = false;
            return empty;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load editable rules: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static EditableRulesBundle saveEditableRules(String rulesJson) {
        assertCanEdit();

        List<EditableRuleDto> incoming;
        try {
            incoming = (List<EditableRuleDto>) JSON.deserialize(rulesJson, List<EditableRuleDto>.class);
        } catch (Exception e) {
            throw new AuraHandledException('Could not read the rules to save. Please retry.');
        }
        if (incoming == null) { incoming = new List<EditableRuleDto>(); }

        // Active Weight rows must total exactly 100%.
        Decimal weightTotal = 0;
        for (EditableRuleDto d : incoming) {
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
            List<Schedule_Decision_Rule__c> toUpsert = new List<Schedule_Decision_Rule__c>();
            Set<Id> keepIds = new Set<Id>();
            Integer order = 0;
            for (EditableRuleDto d : incoming) {
                Schedule_Decision_Rule__c r = new Schedule_Decision_Rule__c();
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

            // Delete only Weight/Optimization rows the user removed — never touch Automation rules.
            List<Schedule_Decision_Rule__c> toDelete = new List<Schedule_Decision_Rule__c>();
            for (Schedule_Decision_Rule__c existing : [
                SELECT Id FROM Schedule_Decision_Rule__c
                WHERE Rule_Type__c IN ('Weight', 'Optimization')
                WITH SECURITY_ENFORCED
            ]) {
                if (!keepIds.contains(existing.Id)) { toDelete.add(existing); }
            }

            if (!toUpsert.isEmpty()) { upsert toUpsert; }
            if (!toDelete.isEmpty()) { delete toDelete; }
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException('Could not save decision rules: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Could not save decision rules: ' + e.getMessage());
        }
        return buildEditableBundle();
    }

    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        assertCanEdit();
        try {
            delete [SELECT Id FROM Schedule_Decision_Rule__c WHERE Id = :ruleId WITH SECURITY_ENFORCED];
        } catch (Exception e) {
            throw new AuraHandledException('Could not delete the rule: ' + e.getMessage());
        }
    }

    // ─── helpers ─────────────────────────────────────────────────────────────

    private static EditableRulesBundle buildEditableBundle() {
        EditableRulesBundle bundle = new EditableRulesBundle();
        bundle.canEdit = canEdit();
        for (Schedule_Decision_Rule__c r : [
            SELECT Id, Name, Rule_Type__c, Favors__c, Weight_Pct__c,
                   Setting__c, Applies_To__c, Active__c, Sort_Order__c
            FROM Schedule_Decision_Rule__c
            WHERE Rule_Type__c IN ('Weight', 'Optimization')
            WITH SECURITY_ENFORCED
            ORDER BY Rule_Type__c, Sort_Order__c NULLS LAST, Name
        ]) {
            EditableRuleDto d = new EditableRuleDto();
            d.id        = r.Id;
            d.ruleType  = r.Rule_Type__c;
            d.name      = r.Name;
            d.favors    = r.Favors__c;
            d.weightPct = r.Weight_Pct__c;
            d.setting   = r.Setting__c;
            d.appliesTo = r.Applies_To__c;
            d.active    = r.Active__c;
            d.sortOrder = (r.Sort_Order__c == null) ? null : Integer.valueOf(r.Sort_Order__c);
            bundle.rules.add(d);
        }
        return bundle;
    }

    private static Boolean canEdit() {
        return FeatureManagement.checkPermission(EDIT_PERM);
    }

    private static void assertCanEdit() {
        if (!canEdit()) {
            throw new AuraHandledException(
                'You do not have permission to edit scheduling decision rules.');
        }
    }
}
