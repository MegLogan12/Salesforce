public with sharing class ODLCampaignListController {
    public class RowData {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public String status;
        @AuraEnabled public String builderAccount;
        @AuraEnabled public String builderAccountUrl;
        @AuraEnabled public Integer memberCount;
        @AuraEnabled public Integer leadCount;
        @AuraEnabled public Integer opportunityCount;
        @AuraEnabled public Decimal revenue;
        @AuraEnabled public Integer voucherCount;
    }

    public class PageData {
        @AuraEnabled public Integer activeCount;
        @AuraEnabled public Integer submittedCount;
        @AuraEnabled public Integer validatedCount;
        @AuraEnabled public Integer reservedCount;
        @AuraEnabled public Integer appliedCount;
        @AuraEnabled public Integer builderInvoicePendingCount;
        @AuraEnabled public Integer builderInvoicedCount;
        @AuraEnabled public Integer paidByBuilderCount;
        @AuraEnabled public Integer rejectedOrExpiredCount;
        @AuraEnabled public List<RowData> rows;
    }

    @AuraEnabled(cacheable=true)
    public static PageData getPageData() {
        PageData data = new PageData();
        data.rows = new List<RowData>();
        data.activeCount = 0;
        data.submittedCount = 0;
        data.validatedCount = 0;
        data.reservedCount = 0;
        data.appliedCount = 0;
        data.builderInvoicePendingCount = 0;
        data.builderInvoicedCount = 0;
        data.paidByBuilderCount = 0;
        data.rejectedOrExpiredCount = 0;

        List<Campaign> campaigns = [
            SELECT Id, Name, Type, Status, IsActive, NumberOfLeads, NumberOfOpportunities,
                   AmountAllOpportunities, Builder_Account__c, Builder_Account__r.Name,
                   NumberOfContacts, NumberOfResponses
            FROM Campaign
            ORDER BY LastModifiedDate DESC
            LIMIT 50
        ];

        Set<Id> campaignIds = new Set<Id>();
        for (Campaign row : campaigns) {
            campaignIds.add(row.Id);
            if (row.IsActive) {
                data.activeCount = data.activeCount == null ? 1 : data.activeCount + 1;
            }
        }

        Map<Id, Integer> memberCountByCampaign = new Map<Id, Integer>();
        if (!campaignIds.isEmpty()) {
            for (AggregateResult result : [
                SELECT CampaignId campaignId, COUNT(Id) memberCount
                FROM CampaignMember
                WHERE CampaignId IN :campaignIds
                GROUP BY CampaignId
            ]) {
                memberCountByCampaign.put((Id) result.get('campaignId'), (Integer) result.get('memberCount'));
            }

            Map<Id, Integer> voucherCountByCampaign = new Map<Id, Integer>();
            for (AggregateResult result : [
                SELECT Campaign__c campaignId, Status__c statusValue, COUNT(Id) rowCount
                FROM Voucher__c
                WHERE Campaign__c IN :campaignIds
                GROUP BY Campaign__c, Status__c
            ]) {
                Id campaignId = (Id) result.get('campaignId');
                String statusValue = (String) result.get('statusValue');
                Integer rowCount = (Integer) result.get('rowCount');
                if (campaignId == null) {
                    continue;
                }
                voucherCountByCampaign.put(campaignId, (voucherCountByCampaign.containsKey(campaignId) ? voucherCountByCampaign.get(campaignId) : 0) + rowCount);
                if (statusValue == 'Submitted') data.submittedCount += rowCount;
                else if (statusValue == 'Validated') data.validatedCount += rowCount;
                else if (statusValue == 'Reserved') data.reservedCount += rowCount;
                else if (statusValue == 'Applied to Quote') data.appliedCount += rowCount;
                else if (statusValue == 'Builder Invoice Pending') data.builderInvoicePendingCount += rowCount;
                else if (statusValue == 'Builder Invoiced') data.builderInvoicedCount += rowCount;
                else if (statusValue == 'Paid by Builder') data.paidByBuilderCount += rowCount;
                else if (statusValue == 'Rejected' || statusValue == 'Expired' || statusValue == 'Rejected / Expired') data.rejectedOrExpiredCount += rowCount;
            }

            for (Campaign row : campaigns) {
                RowData out = new RowData();
                out.id = row.Id;
                out.url = '/' + row.Id;
                out.name = row.Name;
                out.type = row.Type;
                out.status = row.Status;
                out.builderAccount = row.Builder_Account__r == null ? null : row.Builder_Account__r.Name;
                out.builderAccountUrl = row.Builder_Account__c == null ? null : '/' + row.Builder_Account__c;
                out.memberCount = memberCountByCampaign.containsKey(row.Id) ? memberCountByCampaign.get(row.Id) : 0;
                out.leadCount = row.NumberOfLeads == null ? 0 : row.NumberOfLeads;
                out.opportunityCount = row.NumberOfOpportunities == null ? 0 : row.NumberOfOpportunities;
                out.revenue = row.AmountAllOpportunities;
                out.voucherCount = voucherCountByCampaign.containsKey(row.Id) ? voucherCountByCampaign.get(row.Id) : 0;
                data.rows.add(out);
            }
            return data;
        }
        return data;
    }
}