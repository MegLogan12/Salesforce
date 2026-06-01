public with sharing class ODLOpportunityCloseController {

    public class ReadinessGate {
        @AuraEnabled public Boolean voucherLinked;
        @AuraEnabled public String voucherStatus;
        @AuraEnabled public String voucherCode;
        @AuraEnabled public Boolean quoteAccepted;
        @AuraEnabled public String quoteStatus;
        @AuraEnabled public Boolean contractSigned;
        @AuraEnabled public String contractStatus;
        @AuraEnabled public Boolean depositPaid;
        @AuraEnabled public Boolean woReady;
        @AuraEnabled public String blockerLine;
        @AuraEnabled public String readinessBadge;
        @AuraEnabled public String badgeClass;
        @AuraEnabled public Boolean isUmb;
    }

    public class PaymentSchedule {
        @AuraEnabled public Decimal contractTotal;
        @AuraEnabled public Decimal voucherCredit;
        @AuraEnabled public Decimal customerBalance;
        @AuraEnabled public Decimal depositDue;
        @AuraEnabled public Boolean depositIsPaid;
        @AuraEnabled public Date depositPaidDate;
        @AuraEnabled public Decimal remainingBalance;
        @AuraEnabled public String voucherCode;
        @AuraEnabled public Boolean hasVoucher;
        @AuraEnabled public String formattedContractTotal;
        @AuraEnabled public String formattedVoucherCredit;
        @AuraEnabled public String formattedCustomerBalance;
        @AuraEnabled public String formattedDepositDue;
        @AuraEnabled public String formattedRemainingBalance;
    }

    public class ClosePageData {
        @AuraEnabled public Opportunity opportunityRecord;
        @AuraEnabled public String recordTypeName;
        @AuraEnabled public Boolean isUmb;
        @AuraEnabled public ReadinessGate readiness;
        @AuraEnabled public PaymentSchedule paymentSchedule;
    }

    @AuraEnabled(cacheable=true)
    public static ClosePageData getClosePageData(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }
        Opportunity opp;
        try {
            opp = [
                SELECT Id, Name, StageName, Amount, AccountId, Account.Name,
                       RecordType.DeveloperName, RecordTypeId,
                       Quote_Status__c, Contract_Status__c,
                       Deposit_Paid__c, Deposit_Paid_Date__c, Deposit_Due__c
                FROM Opportunity
                WHERE Id = :opportunityId
                WITH SECURITY_ENFORCED
            ];
        } catch (System.QueryException ex) {
            throw new AuraHandledException('Opportunity not found or access denied.');
        }

        ClosePageData data = new ClosePageData();
        data.opportunityRecord = opp;
        data.recordTypeName = opp.RecordType != null ? opp.RecordType.DeveloperName : null;
        data.isUmb = data.recordTypeName == 'UMB';

        SObject voucher = voucherLookup(opportunityId);
        data.readiness = buildReadiness(opp, voucher);
        data.paymentSchedule = buildPaymentSchedule(opp, voucher);
        return data;
    }

    @AuraEnabled
    public static void markClosedWon(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }
        Opportunity opp;
        try {
            opp = [
                SELECT Id, Quote_Status__c, Contract_Status__c, Deposit_Paid__c, StageName
                FROM Opportunity
                WHERE Id = :opportunityId
                WITH SECURITY_ENFORCED
            ];
        } catch (System.QueryException ex) {
            throw new AuraHandledException('Opportunity not found or access denied.');
        }
        if (opp.StageName == 'Closed Won') {
            throw new AuraHandledException('Opportunity is already Closed Won.');
        }
        Boolean woReady = opp.Quote_Status__c == 'Accepted'
            && opp.Contract_Status__c == 'Signed'
            && opp.Deposit_Paid__c;
        if (!woReady) {
            throw new AuraHandledException(
                'All readiness gates must be complete (Quote Accepted, Contract Signed, Deposit Paid) before closing as Won.'
            );
        }
        try {
            update new Opportunity(Id = opportunityId, StageName = 'Closed Won');
        } catch (DmlException ex) {
            throw new AuraHandledException('Failed to close opportunity: ' + ex.getDmlMessage(0));
        }
    }

    // Exact same voucher lookup pattern as ODLOpportunityRecordController — dynamic SOQL,
    // silently returns null when Reserved_Opportunity__c field is absent or query fails.
    private static SObject voucherLookup(Id opportunityId) {
        if (!Schema.getGlobalDescribe().containsKey('Voucher__c')) return null;
        try {
            List<SObject> rows = Database.query(
                'SELECT Id, Name, Voucher_Code__c, Status__c, Voucher_Face_Value__c ' +
                'FROM Voucher__c WHERE Reserved_Opportunity__c = :opportunityId ' +
                'ORDER BY CreatedDate DESC LIMIT 1'
            );
            return rows.isEmpty() ? null : rows[0];
        } catch (Exception ex) {
            return null;
        }
    }

    // Exact same logic as ODLOpportunityRecordController.buildReadiness
    private static ReadinessGate buildReadiness(Opportunity opp, SObject voucher) {
        ReadinessGate gate = new ReadinessGate();
        String rtName = opp.RecordType != null ? opp.RecordType.DeveloperName : null;
        gate.isUmb = rtName == 'UMB';

        gate.voucherLinked = voucher != null;
        gate.voucherCode = voucher != null ? String.valueOf(voucher.get('Voucher_Code__c')) : null;
        gate.voucherStatus = voucher != null ? String.valueOf(voucher.get('Status__c')) : null;

        gate.quoteStatus = opp.Quote_Status__c;
        gate.quoteAccepted = opp.Quote_Status__c == 'Accepted';

        gate.contractStatus = opp.Contract_Status__c;
        gate.contractSigned = opp.Contract_Status__c == 'Signed';

        gate.depositPaid = opp.Deposit_Paid__c;

        gate.woReady = gate.quoteAccepted && gate.contractSigned && gate.depositPaid;

        if (gate.woReady) {
            gate.readinessBadge = 'WO Ready';
            gate.badgeClass = 'badge badge-green';
            gate.blockerLine = null;
        } else if (!gate.quoteAccepted) {
            gate.readinessBadge = 'Blocked';
            gate.badgeClass = 'badge badge-red';
            gate.blockerLine = 'Quote has not been accepted';
        } else if (!gate.contractSigned) {
            gate.readinessBadge = 'Blocked';
            gate.badgeClass = 'badge badge-red';
            gate.blockerLine = 'Contract has not been signed';
        } else if (!gate.depositPaid) {
            gate.readinessBadge = 'Blocked';
            gate.badgeClass = 'badge badge-amber';
            gate.blockerLine = 'Deposit has not been collected';
        } else {
            gate.readinessBadge = 'In Progress';
            gate.badgeClass = 'badge badge-blue';
            gate.blockerLine = null;
        }
        return gate;
    }

    // Financial math: contractTotal − voucherCredit = customerBalance
    private static PaymentSchedule buildPaymentSchedule(Opportunity opp, SObject voucher) {
        PaymentSchedule ps = new PaymentSchedule();
        ps.contractTotal = opp.Amount ?? 0;
        ps.hasVoucher = voucher != null;
        ps.depositIsPaid = opp.Deposit_Paid__c;
        ps.depositPaidDate = opp.Deposit_Paid_Date__c;

        if (voucher != null) {
            Object faceValue = voucher.get('Voucher_Face_Value__c');
            ps.voucherCredit = faceValue instanceof Decimal ? (Decimal) faceValue : 0;
            ps.voucherCode = String.valueOf(voucher.get('Voucher_Code__c'));
        } else {
            ps.voucherCredit = 0;
        }

        ps.customerBalance = ps.contractTotal - ps.voucherCredit;
        ps.depositDue = opp.Deposit_Due__c ?? 0;
        ps.remainingBalance = ps.depositIsPaid
            ? (ps.customerBalance - ps.depositDue)
            : ps.customerBalance;

        ps.formattedContractTotal = formatCurrency(ps.contractTotal);
        ps.formattedVoucherCredit = ps.hasVoucher ? formatCurrency(ps.voucherCredit) : null;
        ps.formattedCustomerBalance = formatCurrency(ps.customerBalance);
        ps.formattedDepositDue = formatCurrency(ps.depositDue);
        ps.formattedRemainingBalance = formatCurrency(ps.remainingBalance);
        return ps;
    }

    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '$0';
        Decimal rounded = amount.setScale(0, System.RoundingMode.HALF_UP);
        Long val = rounded.longValue();
        Boolean negative = val < 0;
        String s = String.valueOf(Math.abs(val));
        String result = '';
        Integer len = s.length();
        for (Integer i = 0; i < len; i++) {
            if (i > 0 && Math.mod(len - i, 3) == 0) result += ',';
            result += s.substring(i, i + 1);
        }
        return (negative ? '-$' : '$') + result;
    }
}
