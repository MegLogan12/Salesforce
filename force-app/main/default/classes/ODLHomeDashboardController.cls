public with sharing class ODLHomeDashboardController {
    public class DashboardData {
        @AuraEnabled public Integer accountCount;
        @AuraEnabled public Integer leadCount;
        @AuraEnabled public Integer opportunityCount;
        @AuraEnabled public Integer campaignCount;
        @AuraEnabled public Integer voucherCount;
        @AuraEnabled public Integer quoteCount;
        @AuraEnabled public Integer workOrderCount;
        @AuraEnabled public Integer serviceAppointmentCount;
        @AuraEnabled public Integer warrantyCount;
        @AuraEnabled public List<QuickRow> opportunityRows;
        @AuraEnabled public List<QuickRow> voucherRows;
    }

    public class QuickRow {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String sublabel;
        @AuraEnabled public String url;
    }

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        DashboardData data = new DashboardData();
        data.accountCount = [SELECT Count() FROM Account WHERE PersonContactId != null];
        data.leadCount = [SELECT Count() FROM Lead];
        data.opportunityCount = [SELECT Count() FROM Opportunity WHERE RecordType.DeveloperName IN ('UMB', 'Design_Build')];
        data.campaignCount = [SELECT Count() FROM Campaign];
        data.voucherCount = [SELECT Count() FROM Voucher__c];
        data.quoteCount = [SELECT Count() FROM Quote];
        data.workOrderCount = [SELECT Count() FROM WorkOrder];
        data.serviceAppointmentCount = [SELECT Count() FROM ServiceAppointment];
        data.warrantyCount = [SELECT Count() FROM Warranty_Record__c];
        data.opportunityRows = new List<QuickRow>();
        data.voucherRows = new List<QuickRow>();

        for (Opportunity opp : [
            SELECT Id, Name, StageName, Account.Name
            FROM Opportunity
            WHERE RecordType.DeveloperName IN ('UMB', 'Design_Build')
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ]) {
            data.opportunityRows.add(buildOpportunityRow(opp));
        }

        for (Voucher__c voucher : [
            SELECT Id, Name, Voucher_Code__c, Status__c
            FROM Voucher__c
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ]) {
            data.voucherRows.add(buildVoucherRow(voucher));
        }

        return data;
    }

    @TestVisible
    private static QuickRow buildOpportunityRow(Opportunity opp) {
        QuickRow row = new QuickRow();
        row.id = opp.Id;
        row.label = opp.Name;
        row.sublabel = String.join(
            new List<String>{
                opp.Account != null ? opp.Account.Name : null,
                opp.StageName
            },
            ' · '
        );
        row.url = '/lightning/r/Opportunity/' + opp.Id + '/view';
        return row;
    }

    @TestVisible
    private static QuickRow buildVoucherRow(Voucher__c voucher) {
        QuickRow row = new QuickRow();
        row.id = voucher.Id;
        row.label = String.isBlank(voucher.Voucher_Code__c) ? voucher.Name : voucher.Voucher_Code__c;
        row.sublabel = voucher.Status__c;
        row.url = '/lightning/r/Voucher__c/' + voucher.Id + '/view';
        return row;
    }
}