/**
 * LeadHandler
 * Handles all Lead trigger logic for Stages 1 and 2.
 *
 * Stage 1 — Lead: New → Working
 *   - Enforces Lead_Type__c is set before save
 *   - Validates required fields per scenario
 *   - Sets Status = 'New' on insert
 *   - Enforces Dead_Reason__c when Status = 'Dead'
 *   - Notifies COO when Awaiting Decision > 30 days (async)
 *
 * Stage 2 — Lead Converted
 *   - Routes conversion to LeadConversionService based on Lead_Type__c
 */
public with sharing class LeadHandler {


    // ─────────────────────────────────────────────
    // UTILITY: Get Excluded Lead Sources from Label
    // ─────────────────────────────────────────────
    private static Set<String> getExcludedLeadSources() {
        Set<String> result = new Set<String>();

        if (String.isNotBlank(Label.EXCLUDED_LEADSOURCES_IN_TRIGGER)) {
            for (String src : Label.EXCLUDED_LEADSOURCES_IN_TRIGGER.split(';')) {
                result.add(src.trim());
            }
        }
        return result;
    }

    // ─────────────────────────────────────────────
    // BEFORE TRIGGER
    // ─────────────────────────────────────────────
    public static void handleBefore(List<Lead> newList, Map<Id, Lead> oldMap) {
        for (Lead l : newList) {

            Set<String> excludedSources = getExcludedLeadSources();

            // Skip excluded Lead Sources
            if (excludedSources.contains(l.LeadSource)) {
                continue;
            }

            Lead old = (oldMap != null && oldMap.containsKey(l.Id)) ? oldMap.get(l.Id) : null;

            // Stage 1: enforce Lead Type on insert
            if (old == null) {
                if (String.isBlank(l.Lead_Type__c)) {
                    l.addError('Lead Type is required. Select "Net New Builder" or "Existing Builder New Community" before saving.');
                }
                // Preserve an explicitly-set Dead status so Dead_Reason validation below can fire.
                // For any other status (or no status), default to New.
                if (l.Status != 'Dead') l.Status = 'New';
            }

            // Require Dead_Reason__c when Status = Dead.
            // Use record-level addError — calling addError on a blank field reference is a silent no-op.
            if (l.Status == 'Dead' && String.isBlank(l.Dead_Reason__c)) {
                l.addError('Dead Reason is required when marking a Lead as Dead.');
            }

            // Scenario C: require parent account links
            if (l.Lead_Type__c == 'Existing Builder New Community') {
                if (l.Builder_Parent_Account__c == null) {
                    l.Builder_Parent_Account__c.addError('Builder Parent Account is required for Scenario C (Existing Builder).');
                }
                // Builder Market Account is required only for regional/national builders.
                // Local builders (no Market) use the Builder Parent Account directly.
                if (l.Builder_Market_Account__c == null && String.isNotBlank(l.Market__c)) {
                    l.Builder_Market_Account__c.addError('Builder Market Account is required for regional builders in Scenario C. Leave Market blank and only set Builder Parent Account for local builders.');
                }
            }

            // Required fields — Community Name required for builder leads only
            if (String.isBlank(l.Community_Name__c) && l.Lead_Type__c != 'Homeowner') {
                l.Community_Name__c.addError('Community Name is required on all Leads.');
            }
            // Market is optional for Net New Builder and Homeowner leads
            if (String.isBlank(l.Market__c) && l.Lead_Type__c != 'Net New Builder' && l.Lead_Type__c != 'Homeowner') {
                l.addError('Market is required for ' + l.Lead_Type__c + ' leads.');
            }
            if (String.isBlank(l.LeadSource)) {
                l.LeadSource.addError('Lead Source is required.');
            }
        }
    }

    // ─────────────────────────────────────────────
    // AFTER TRIGGER
    // ─────────────────────────────────────────────
    public static void handleAfter(List<Lead> newList, Map<Id, Lead> oldMap) {
        List<Id> deadLeadIds        = new List<Id>();
        List<Id> convertedLeadIds   = new List<Id>();
        List<Id> awaitingLeadIds    = new List<Id>();
        Set<String> excludedSources = getExcludedLeadSources();

        for (Lead l : newList) {
            Lead old = (oldMap != null && oldMap.containsKey(l.Id)) ? oldMap.get(l.Id) : null;

            // Homeowner conversions always route regardless of LeadSource exclusion.
            // Excluded sources block builder-side notifications and validation;
            // they must not prevent account record type assignment on homeowner conversion.
            if (l.Lead_Type__c == 'Homeowner' && l.IsConverted && (old == null || !old.IsConverted)) {
                convertedLeadIds.add(l.Id);
                continue;
            }

            // Skip all other processing for excluded Lead Sources
            if (excludedSources.contains(l.LeadSource)) {
                continue;
            }

            // Notify COO on Dead
            if (l.Status == 'Dead' && (old == null || old.Status != 'Dead')) {
                deadLeadIds.add(l.Id);
            }

            // Route conversion (Stage 2) for non-excluded sources
            if (l.IsConverted && (old == null || !old.IsConverted)) {
                convertedLeadIds.add(l.Id);
            }

            // Flag Awaiting Decision > 30 days via async job
            if (l.Status == 'Awaiting Decision' && (old == null || old.Status != 'Awaiting Decision')) {
                awaitingLeadIds.add(l.Id);
            }
        }

        if (!deadLeadIds.isEmpty()) {
            LeadNotificationService.notifyCOODeadLeads(deadLeadIds);
        }
        if (!convertedLeadIds.isEmpty()) {
            LeadConversionService.routeConversion(convertedLeadIds);
        }
        if (!awaitingLeadIds.isEmpty()) {
            LeadEscalationScheduler.scheduleAwaitingDecisionCheck(awaitingLeadIds);
        }
    }
}