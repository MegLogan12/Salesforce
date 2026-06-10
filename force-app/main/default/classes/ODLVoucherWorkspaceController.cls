public with sharing class ODLVoucherWorkspaceController {
    public class VoucherRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String voucherCode;
        @AuraEnabled public String status;
        @AuraEnabled public String voucherType;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String accountName;
    }

    @AuraEnabled(cacheable=true)
    public static List<VoucherRow> getVouchers() {
        List<VoucherRow> rows = new List<VoucherRow>();
        if (!Schema.getGlobalDescribe().containsKey('Voucher__c')) {
            return rows;
        }
        List<SObject> voucherRows = Database.query(
            'SELECT Id, Name, Voucher_Code__c, Status__c, Voucher_Type__c, ' +
            'Reserved_Opportunity__c, Reserved_Opportunity__r.Name, ' +
            'Reserved_Opportunity__r.AccountId, Reserved_Opportunity__r.Account.Name ' +
            'FROM Voucher__c ' +
            'ORDER BY CreatedDate DESC ' +
            'LIMIT 200'
        );
        for (SObject v : voucherRows) {
            VoucherRow row = new VoucherRow();
            row.id = (Id) v.get('Id');
            row.name = String.valueOf(v.get('Name'));
            row.voucherCode = v.get('Voucher_Code__c') != null ? String.valueOf(v.get('Voucher_Code__c')) : null;
            row.status = v.get('Status__c') != null ? String.valueOf(v.get('Status__c')) : null;
            row.voucherType = v.get('Voucher_Type__c') != null ? String.valueOf(v.get('Voucher_Type__c')) : null;

            SObject opp = v.getSObject('Reserved_Opportunity__r');
            if (opp != null) {
                row.opportunityName = String.valueOf(opp.get('Name'));
                SObject acct = opp.getSObject('Account');
                if (acct != null) {
                    row.accountName = String.valueOf(acct.get('Name'));
                }
            }
            rows.add(row);
        }
        return rows;
    }
}
