/**
 * CommunitiesViewController
 * Backend for the lovingCommunitiesView LWC.
 * Returns all Community__c records with minimal safe fields.
 */
public with sharing class CommunitiesViewController {

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class CommunityRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String builderAccountName;
        @AuraEnabled public String createdDateLabel;
    }

    // ── Main query ────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<CommunityRow> getCommunities() {
        try {
            List<CommunityRow> rows = new List<CommunityRow>();
            for (Community__c c : [
                SELECT Id, Name, Builder_Account__c,
                       Builder_Account__r.Name, CreatedDate
                FROM Community__c
                ORDER BY Name
                LIMIT 200
            ]) {
                CommunityRow r = new CommunityRow();
                r.id                 = c.Id;
                r.name               = c.Name;
                r.builderAccountName = (c.Builder_Account__r != null && c.Builder_Account__r.Name != null)
                    ? c.Builder_Account__r.Name
                    : '';
                r.createdDateLabel   = c.CreatedDate != null
                    ? c.CreatedDate.format('M/d/yyyy')
                    : '';
                rows.add(r);
            }
            return rows;

        } catch (Exception e) {
            throw new AuraHandledException('Unable to load communities: ' + e.getMessage());
        }
    }
}
