public with sharing class ODLLeadOpportunityAttributionBackfill implements Database.Batchable<SObject>, Database.Stateful {
    private static final Set<String> ATTRIBUTION_SOURCES = new Set<String>{
        'Website',
        'Web - Design Form',
        'Web - Consultation Form',
        'Google',
        'Social Media',
        'External Referral',
        'Employee Referral',
        'Homebuilder Event',
        'Lennar Voucher',
        'Inbound Call'
    };

    @TestVisible private Integer repairedCount = 0;
    @TestVisible private Integer skippedCount = 0;

    public static Id enqueue() {
        return Database.executeBatch(new ODLLeadOpportunityAttributionBackfill(), 100);
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, ConvertedContactId, LeadSource, CreatedDate, ConvertedDate
            FROM Lead
            WHERE IsConverted = true
            AND ConvertedOpportunityId = null
            AND ConvertedContactId != null
            AND LeadSource IN :ATTRIBUTION_SOURCES
        ]);
    }

    public void execute(Database.BatchableContext context, List<Lead> scope) {
        Set<Id> contactIds = new Set<Id>();
        Set<Id> leadIds = new Set<Id>();
        for (Lead leadRow : scope) {
            contactIds.add(leadRow.ConvertedContactId);
            leadIds.add(leadRow.Id);
        }
        if (contactIds.isEmpty()) {
            return;
        }

        Map<Id, Id> campaignByLead = latestCampaignByLead(leadIds);
        List<Opportunity> candidateOpps = [
            SELECT Id, ContactId, LeadSource, CreatedDate, CampaignId, Source_Lead__c
            FROM Opportunity
            WHERE ContactId IN :contactIds
            AND Source_Lead__c = null
            ORDER BY CreatedDate ASC
        ];

        Map<Id, Opportunity> usedOpps = new Map<Id, Opportunity>();
        List<Opportunity> updates = new List<Opportunity>();
        for (Lead leadRow : scope) {
            Opportunity match = bestMatch(leadRow, candidateOpps, usedOpps.keySet());
            if (match == null) {
                skippedCount++;
                continue;
            }
            usedOpps.put(match.Id, match);
            Opportunity updateRow = new Opportunity(
                Id = match.Id,
                Source_Lead__c = leadRow.Id
            );
            Id campaignId = campaignByLead.get(leadRow.Id);
            if (match.CampaignId == null && campaignId != null) {
                updateRow.CampaignId = campaignId;
            }
            updates.add(updateRow);
        }

        if (!updates.isEmpty()) {
            update updates;
            repairedCount += updates.size();
        }
    }

    public void finish(Database.BatchableContext context) {
        System.debug(LoggingLevel.INFO, 'ODL lead opportunity attribution backfill repaired=' + repairedCount + ' skipped=' + skippedCount);
    }

    private static Opportunity bestMatch(Lead leadRow, List<Opportunity> candidates, Set<Id> usedIds) {
        Opportunity best;
        Long bestDiff;
        Datetime lowWatermark = leadRow.CreatedDate.addMinutes(-5);
        Datetime highWatermark = leadRow.ConvertedDate != null
            ? Datetime.newInstance(leadRow.ConvertedDate, Time.newInstance(23, 59, 59, 999)).addDays(7)
            : leadRow.CreatedDate.addDays(7);
        Datetime targetDate = leadRow.ConvertedDate != null
            ? Datetime.newInstance(leadRow.ConvertedDate, Time.newInstance(12, 0, 0, 0))
            : leadRow.CreatedDate;

        for (Opportunity oppRow : candidates) {
            if (usedIds.contains(oppRow.Id) || oppRow.ContactId != leadRow.ConvertedContactId) {
                continue;
            }
            if (oppRow.CreatedDate < lowWatermark || oppRow.CreatedDate > highWatermark) {
                continue;
            }
            Boolean sameSource = String.isBlank(leadRow.LeadSource)
                || String.isBlank(oppRow.LeadSource)
                || oppRow.LeadSource == leadRow.LeadSource;
            if (!sameSource) {
                continue;
            }
            Long diff = Math.abs(oppRow.CreatedDate.getTime() - targetDate.getTime());
            if (best == null || diff < bestDiff) {
                best = oppRow;
                bestDiff = diff;
            }
        }
        return best;
    }

    private static Map<Id, Id> latestCampaignByLead(Set<Id> leadIds) {
        Map<Id, Id> out = new Map<Id, Id>();
        if (leadIds.isEmpty()) {
            return out;
        }
        for (CampaignMember member : [
            SELECT LeadId, CampaignId, CreatedDate
            FROM CampaignMember
            WHERE LeadId IN :leadIds
            ORDER BY CreatedDate DESC
        ]) {
            if (member.LeadId != null && !out.containsKey(member.LeadId)) {
                out.put(member.LeadId, member.CampaignId);
            }
        }
        return out;
    }
}