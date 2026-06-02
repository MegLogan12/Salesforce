public with sharing class ODLQuoteAutomationService {
    private static final Set<String> ODL_TYPES = new Set<String>{
        'UMB',
        'UpgradeMyBackyard',
        'Upgrade My Backyard',
        'Design Build',
        'Design_Build'
    };
    private static final Set<String> FINALIZED_PAYMENT_STATUSES = new Set<String>{ 'Paid', 'Refunded', 'Written Off' };
    private static final Set<String> BLOCKED_VOUCHER_STATUSES = new Set<String>{ 'Expired', 'Voided', 'Rejected' };
    private static final String STANDARD_GRILL_SKU = 'GI-STD';
    private static final String DELUXE_GRILL_SKU = 'GI-DLX';

    private class QuoteVoucherComputation {
        Decimal homeownerBalance;
        Decimal appliedCredit;
        Decimal homeownerUpgradeDelta;
        Boolean zeroDollarException;
    }

    public static void afterUpsert(List<Quote> newList, Map<Id, Quote> oldMap) {
        Set<Id> quoteIds = new Set<Id>();
        for (Quote quoteRow : newList) {
            if (quoteRow.Id != null) {
                quoteIds.add(quoteRow.Id);
            }
        }
        if (quoteIds.isEmpty()) {
            return;
        }

        Map<Id, Quote> quotesById = new Map<Id, Quote>([
            SELECT Id, GrandTotal, Subtotal, Voucher__c, Voucher__r.Status__c, Voucher_Credit_Amount__c,
                   Voucher__r.Voucher_Type__c, Voucher__r.Voucher_Face_Value__c, Voucher__r.Builder_Invoice_Status__c,
                   Voucher__r.Finance_Exception_Approved__c,
                   ContractId, OpportunityId, Opportunity.Type, Opportunity.StageName, Opportunity.Deposit_Paid__c,
                   Opportunity.Deposit_Paid_Date__c
            FROM Quote
            WHERE Id IN :quoteIds
        ]);

        Map<Id, List<QuoteLineItem>> lineItemsByQuote = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem lineRow : [
            SELECT Id, QuoteId, Quantity, UnitPrice, TotalPrice, PricebookEntry.Product2.ProductCode, PricebookEntry.Product2.Name
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
        ]) {
            if (!lineItemsByQuote.containsKey(lineRow.QuoteId)) {
                lineItemsByQuote.put(lineRow.QuoteId, new List<QuoteLineItem>());
            }
            lineItemsByQuote.get(lineRow.QuoteId).add(lineRow);
        }

        Map<Id, List<Payment_Milestone__c>> milestonesByQuote = new Map<Id, List<Payment_Milestone__c>>();
        for (Payment_Milestone__c milestoneRow : [
            SELECT Id, Quote__c, Opportunity__c, Type__c, Status__c, Amount__c, Due_Date__c,
                   Paid_Date__c, Exception_Approved__c, Voucher__c
            FROM Payment_Milestone__c
            WHERE Quote__c IN :quoteIds
        ]) {
            if (!milestonesByQuote.containsKey(milestoneRow.Quote__c)) {
                milestonesByQuote.put(milestoneRow.Quote__c, new List<Payment_Milestone__c>());
            }
            milestonesByQuote.get(milestoneRow.Quote__c).add(milestoneRow);
        }

        List<Payment_Milestone__c> milestonesToUpsert = new List<Payment_Milestone__c>();
        List<Payment_Milestone__c> milestonesToDelete = new List<Payment_Milestone__c>();
        List<Voucher__c> vouchersToUpdate = new List<Voucher__c>();

        for (Quote quoteRow : quotesById.values()) {
            if (quoteRow.OpportunityId == null || quoteRow.Opportunity == null || !ODL_TYPES.contains(quoteRow.Opportunity.Type)) {
                continue;
            }
            if (quoteRow.GrandTotal == null && quoteRow.Voucher_Credit_Amount__c == null) {
                continue;
            }

            List<Payment_Milestone__c> existingMilestones = milestonesByQuote.containsKey(quoteRow.Id)
                ? milestonesByQuote.get(quoteRow.Id)
                : new List<Payment_Milestone__c>();

            QuoteVoucherComputation computation = computeVoucherOutcome(
                quoteRow,
                lineItemsByQuote.containsKey(quoteRow.Id) ? lineItemsByQuote.get(quoteRow.Id) : new List<QuoteLineItem>()
            );
            if (quoteRow.Voucher__c != null && computation != null) {
                vouchersToUpdate.add(buildVoucherUpdate(quoteRow, computation));
            }

            if (computation != null && computation.zeroDollarException) {
                milestonesToUpsert.add(upsertMilestone(existingMilestones, quoteRow, 'Deposit', 0, 'Paid', Date.today(), false));
                milestonesToUpsert.add(upsertMilestone(existingMilestones, quoteRow, 'Final Payment', 0, 'Paid', Date.today(), false));
                milestonesToUpsert.add(upsertMilestone(existingMilestones, quoteRow, 'Exception', 0, 'Exception Approved', Date.today(), true));
                continue;
            }

            Decimal homeownerBalance = computation == null || computation.homeownerBalance == null
                ? (quoteRow.GrandTotal == null ? 0 : quoteRow.GrandTotal.setScale(2))
                : computation.homeownerBalance.setScale(2);
            Decimal deposit = (homeownerBalance / 2).setScale(2);
            Decimal finalPayment = (homeownerBalance - deposit).setScale(2);

            milestonesToUpsert.add(upsertMilestone(existingMilestones, quoteRow, 'Deposit', deposit, 'Not Sent', null, false));
            milestonesToUpsert.add(upsertMilestone(existingMilestones, quoteRow, 'Final Payment', finalPayment, 'Not Sent', null, false));
            for (Payment_Milestone__c milestoneRow : existingMilestones) {
                if (milestoneRow.Type__c == 'Exception') {
                    milestonesToDelete.add(milestoneRow);
                }
            }
        }

        if (!milestonesToUpsert.isEmpty()) {
            upsert milestonesToUpsert;
        }
        if (!milestonesToDelete.isEmpty()) {
            delete milestonesToDelete;
        }
        if (!vouchersToUpdate.isEmpty()) {
            update vouchersToUpdate;
        }
    }

    private static Payment_Milestone__c upsertMilestone(List<Payment_Milestone__c> existingMilestones, Quote quoteRow,
            String typeValue, Decimal amount, String status, Date paidDate, Boolean exceptionApproved) {
        Payment_Milestone__c target;
        for (Payment_Milestone__c candidate : existingMilestones) {
            if (candidate.Type__c == typeValue) {
                target = candidate;
                break;
            }
        }
        if (target == null) {
            target = new Payment_Milestone__c(
                Quote__c = quoteRow.Id,
                Opportunity__c = quoteRow.OpportunityId,
                Type__c = typeValue
            );
        } else if (FINALIZED_PAYMENT_STATUSES.contains(target.Status__c) && typeValue != 'Exception') {
            return target;
        }

        target.Status__c = status;
        target.Amount__c = amount;
        target.Paid_Date__c = paidDate;
        if (Schema.SObjectType.Payment_Milestone__c.fields.getMap().containsKey('Exception_Approved__c')) {
            target.Exception_Approved__c = exceptionApproved;
        }
        if (Schema.SObjectType.Payment_Milestone__c.fields.getMap().containsKey('Voucher__c')) {
            target.Voucher__c = (Id) quoteRow.get('Voucher__c');
        }
        return target;
    }

    private static QuoteVoucherComputation computeVoucherOutcome(Quote quoteRow, List<QuoteLineItem> lineItems) {
        QuoteVoucherComputation result = new QuoteVoucherComputation();
        Decimal total = quoteRow.GrandTotal == null ? 0 : quoteRow.GrandTotal.setScale(2);
        result.homeownerBalance = total;
        result.appliedCredit = 0;
        result.homeownerUpgradeDelta = 0;
        result.zeroDollarException = false;

        if (quoteRow.get('Voucher__c') == null || quoteRow.Voucher__r == null) {
            return result;
        }
        if (BLOCKED_VOUCHER_STATUSES.contains(quoteRow.Voucher__r.Status__c)) {
            return result;
        }

        Decimal availableCredit = resolveVoucherCredit(quoteRow);
        if (availableCredit <= 0) {
            return result;
        }

        Integer nonZeroLineCount = 0;
        QuoteLineItem primaryLine;
        for (QuoteLineItem lineRow : lineItems) {
            Decimal lineTotal = lineRow.TotalPrice == null ? 0 : lineRow.TotalPrice.setScale(2);
            if (lineTotal > 0) {
                nonZeroLineCount++;
                if (primaryLine == null) {
                    primaryLine = lineRow;
                }
            }
        }

        if (primaryLine != null && nonZeroLineCount == 1) {
            String productCode = primaryLine.PricebookEntry != null && primaryLine.PricebookEntry.Product2 != null
                ? primaryLine.PricebookEntry.Product2.ProductCode
                : null;
            Decimal primaryTotal = primaryLine.TotalPrice == null ? total : primaryLine.TotalPrice.setScale(2);
            if (productCode == STANDARD_GRILL_SKU) {
                result.appliedCredit = smallerOf(availableCredit, primaryTotal);
                result.homeownerBalance = (primaryTotal - result.appliedCredit).setScale(2);
                result.zeroDollarException = result.homeownerBalance <= 0;
                return result;
            }
            if (productCode == DELUXE_GRILL_SKU) {
                result.appliedCredit = smallerOf(availableCredit, primaryTotal);
                result.homeownerBalance = (primaryTotal - result.appliedCredit).setScale(2);
                result.homeownerUpgradeDelta = result.homeownerBalance;
                result.zeroDollarException = result.homeownerBalance <= 0;
                return result;
            }
        }

        result.appliedCredit = smallerOf(availableCredit, total);
        result.homeownerBalance = (total - result.appliedCredit).setScale(2);
        result.zeroDollarException = result.homeownerBalance <= 0 && nonZeroLineCount == 1;
        return result;
    }

    private static Decimal resolveVoucherCredit(Quote quoteRow) {
        if (quoteRow.Voucher_Credit_Amount__c != null && quoteRow.Voucher_Credit_Amount__c > 0) {
            return quoteRow.Voucher_Credit_Amount__c.setScale(2);
        }
        Object voucherFaceValue = quoteRow.Voucher__r.get('Voucher_Face_Value__c');
        if (voucherFaceValue instanceof Decimal && ((Decimal) voucherFaceValue) > 0) {
            return ((Decimal) voucherFaceValue).setScale(2);
        }
        return 0;
    }

    private static Voucher__c buildVoucherUpdate(Quote quoteRow, QuoteVoucherComputation computation) {
        Voucher__c updateRow = new Voucher__c(
            Id = (Id) quoteRow.get('Voucher__c'),
            Redeemed_Quote__c = quoteRow.Id,
            Customer_Invoice_Amount__c = computation.homeownerBalance,
            Customer_Paid_Upgrade_Amount__c = computation.homeownerUpgradeDelta
        );
        if (quoteRow.Voucher__r != null && !BLOCKED_VOUCHER_STATUSES.contains(quoteRow.Voucher__r.Status__c)) {
            updateRow.Status__c = determineVoucherStatus(quoteRow, computation);
        }
        return updateRow;
    }

    private static String determineVoucherStatus(Quote quoteRow, QuoteVoucherComputation computation) {
        if (!computation.zeroDollarException) {
            return 'Applied to Quote';
        }

        String builderInvoiceStatus = (String) quoteRow.Voucher__r.get('Builder_Invoice_Status__c');
        Object financeExceptionApproved = quoteRow.Voucher__r.get('Finance_Exception_Approved__c');
        Boolean financeApproved = financeExceptionApproved instanceof Boolean && (Boolean) financeExceptionApproved;

        if (builderInvoiceStatus != 'Paid' && !financeApproved) {
            return 'Applied to Quote';
        }
        return 'Redeemed';
    }

    private static Decimal smallerOf(Decimal leftValue, Decimal rightValue) {
        if (leftValue == null) {
            return rightValue;
        }
        if (rightValue == null) {
            return leftValue;
        }
        return leftValue <= rightValue ? leftValue : rightValue;
    }
}