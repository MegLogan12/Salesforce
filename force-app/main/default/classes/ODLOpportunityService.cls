/**
 * ODLOpportunityService
 * Shared canonical signal for identifying ODL opportunities post-conversion.
 *
 * The canonical post-conversion check is: RecordType.DeveloperName IN ('UMB', 'Design_Build').
 * At insert time or when RecordType is not yet set, falls back to the legacy
 * Type + LeadSource + BMG heuristic for migration safety.
 */
public without sharing class ODLOpportunityService {

    private static final Set<String> ODL_RECORD_TYPES = new Set<String>{
        'UMB',
        'Design_Build'
    };

    private static final Set<String> ODL_TYPES = new Set<String>{
        'UpgradeMyBackyard',
        'Design Build',
        'UMB'
    };

    private static final Set<String> ODL_LEAD_SOURCES = new Set<String>{
        'Lennar Voucher',
        'Web - Design Form',
        'Web - Consultation Form',
        'UMB Builder Pop Up',
        'Homebuilder Event',
        'Website'
    };

    /**
     * Canonical ODL opportunity check.
     *
     * If the opportunity has a RecordType set (post-conversion), use it.
     * If not (insert time or pre-backfill), fall back to the Type + LeadSource + BMG heuristic.
     *
     * @param opp  Opportunity record — must include RecordType.DeveloperName if available,
     *             plus Type, LeadSource, and BMG_Package__c for fallback.
     * @return true if this opportunity belongs to the ODL channel.
     */
    public static Boolean isOdlOpportunity(Opportunity opp) {
        if (opp == null) {
            return false;
        }

        // Primary check: RecordType is set (post-conversion, canonical)
        if (opp.RecordType != null && opp.RecordType.DeveloperName != null) {
            return ODL_RECORD_TYPES.contains(opp.RecordType.DeveloperName);
        }

        // Fallback: Type + LeadSource + BMG heuristic (insert-time or pre-backfill migration safety)
        if (!String.isBlank(opp.Type) && ODL_TYPES.contains(opp.Type)) {
            return true;
        }
        if (!String.isBlank(opp.LeadSource) && ODL_LEAD_SOURCES.contains(opp.LeadSource)) {
            return true;
        }
        return !String.isBlank(opp.BMG_Package__c);
    }
}
