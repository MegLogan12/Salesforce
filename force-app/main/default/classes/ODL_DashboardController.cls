public with sharing class ODL_DashboardController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCooMetrics() {
        AggregateResult[] oppByLob = [
            SELECT ODL_Path__c lob, COUNT(Id) cnt, SUM(Amount) total
            FROM Opportunity
            WHERE StageName NOT IN ('Closed Won', 'Closed Lost')
                AND ODL_Path__c != null
            GROUP BY ODL_Path__c
        ];

        List<Map<String, Object>> lobMetrics = new List<Map<String, Object>>();
        Decimal totalPipeline = 0;
        for (AggregateResult ar : oppByLob) {
            Decimal total = ar.get('total') != null ? (Decimal)ar.get('total') : 0;
            totalPipeline += total;
            lobMetrics.add(new Map<String, Object>{
                'lob'   => ar.get('lob'),
                'count' => ar.get('cnt'),
                'total' => total
            });
        }

        List<Task> overdueTasks = [
            SELECT Id, Subject, ActivityDate, WhatId, What.Name, OwnerId, Owner.Name
            FROM Task
            WHERE Status != 'Completed' AND ActivityDate < :Date.today()
            ORDER BY ActivityDate ASC
            LIMIT 20
        ];

        List<Opportunity> atRiskOpps = [
            SELECT Id, Name, StageName, Amount, LastActivityDate, ODL_Path__c,
                   AccountId, Account.Name
            FROM Opportunity
            WHERE StageName NOT IN ('Closed Won', 'Closed Lost')
              AND LastActivityDate < :Date.today().addDays(-5)
            ORDER BY LastActivityDate ASC NULLS FIRST
            LIMIT 20
        ];

        return new Map<String, Object>{
            'totalPipeline'   => totalPipeline,
            'lobMetrics'      => lobMetrics,
            'overdueCount'    => overdueTasks.size(),
            'atRiskOpps'      => atRiskOpps,
            'atRiskCount'     => atRiskOpps.size()
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCampaignMetrics() {
        List<Campaign> campaigns = [
            SELECT Id, Name, Type, Status, Description, NumberOfLeads, NumberOfConvertedLeads,
                   NumberOfContacts, NumberOfOpportunities,
                   ExpectedRevenue, OwnerId, Owner.Name
            FROM Campaign
            WHERE IsActive = true
            ORDER BY StartDate DESC NULLS LAST
            LIMIT 50
        ];

        Integer activeCount = campaigns.size();
        Integer totalMembers = 0;
        Decimal totalRevenue = 0;
        Integer totalLeads = 0;
        Integer convertedLeads = 0;
        for (Campaign c : campaigns) {
            totalMembers += c.NumberOfLeads != null ? c.NumberOfLeads : 0;
            totalRevenue += c.ExpectedRevenue != null ? c.ExpectedRevenue : 0;
            totalLeads += c.NumberOfLeads != null ? c.NumberOfLeads : 0;
            convertedLeads += c.NumberOfConvertedLeads != null ? c.NumberOfConvertedLeads : 0;
        }

        Integer voucherPending = [
            SELECT COUNT()
            FROM Voucher__c
            WHERE Status__c = 'Builder Invoice Pending'
        ];

        Set<Id> campaignIds = new Set<Id>();
        for (Campaign c : campaigns) {
            campaignIds.add(c.Id);
        }

        List<Map<String, Object>> campaignMembers = new List<Map<String, Object>>();
        if (!campaignIds.isEmpty()) {
            for (CampaignMember cm : [
                SELECT Id, Name, Status, CampaignId, Campaign.Name
                FROM CampaignMember
                WHERE CampaignId IN :campaignIds
                ORDER BY Campaign.Name, Name
                LIMIT 100
            ]) {
                campaignMembers.add(new Map<String, Object>{
                    'Id'           => cm.Id,
                    'Name'         => cm.Name,
                    'Status'       => cm.Status,
                    'campaignName' => cm.Campaign != null ? cm.Campaign.Name : null
                });
            }
        }

        return new Map<String, Object>{
            'campaigns'       => campaigns,
            'activeCount'     => activeCount,
            'totalMembers'    => totalMembers,
            'totalRevenue'    => totalRevenue,
            'totalLeads'      => totalLeads,
            'convertedLeads'  => convertedLeads,
            'voucherPending'  => voucherPending,
            'campaignMembers' => campaignMembers
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWarrantyCase(Id caseId) {
        Case c = [
            SELECT Id, CaseNumber, AccountId, Account.Name, Status, Priority,
                   Type, Subject, Description, CreatedDate
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        return new Map<String, Object>{
            'caseRecord' => c
        };
    }
}