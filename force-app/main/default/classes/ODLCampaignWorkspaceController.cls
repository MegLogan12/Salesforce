public with sharing class ODLCampaignWorkspaceController {
    public class CampaignRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String startDate;
        @AuraEnabled public String endDate;
        @AuraEnabled public Integer numberOfLeads;
        @AuraEnabled public Integer numberOfContacts;
    }

    @AuraEnabled(cacheable=true)
    public static List<CampaignRow> getCampaigns() {
        List<CampaignRow> rows = new List<CampaignRow>();
        for (Campaign c : [
            SELECT Id, Name, Status, StartDate, EndDate, NumberOfLeads, NumberOfContacts
            FROM Campaign
            ORDER BY StartDate DESC NULLS LAST, CreatedDate DESC
            LIMIT 200
        ]) {
            CampaignRow row = new CampaignRow();
            row.id = c.Id;
            row.name = c.Name;
            row.status = c.Status;
            row.startDate = c.StartDate != null ? String.valueOf(c.StartDate) : null;
            row.endDate = c.EndDate != null ? String.valueOf(c.EndDate) : null;
            row.numberOfLeads = c.NumberOfLeads;
            row.numberOfContacts = c.NumberOfContacts;
            rows.add(row);
        }
        return rows;
    }
}
