public with sharing class ODLVoucherLifecycleService {

    public class ActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id recordId;

        public ActionResult(Boolean success, String message, Id recordId) {
            this.success = success;
            this.message = message;
            this.recordId = recordId;
        }
    }

    private static final List<String> CAMPAIGN_MEMBER_STATUSES = new List<String>{
        'Sent',
        'Viewed',
        'Submitted',
        'Validated',
        'Contacted',
        'Consult Scheduled',
        'Quote Sent',
        'Contract Signed',
        'Deposit Paid',
        'Builder Invoiced',
        'Closed Won',
        'Closed Lost',
        'Expired',
        'Rejected'
    };

    private static final Set<String> PACKAGE_VALUES = new Set<String>{
        'Retreat',
        'Entertainer',
        'Signature',
        'Design Build'
    };

    private static final Map<String, Integer> STATUS_RANK = new Map<String, Integer>{
        'Draft' => 0,
        'Active' => 1,
        'Submitted' => 2,
        'Validated' => 3,
        'Reserved' => 4,
        'Applied to Quote' => 5,
        'Contract Signed' => 6,
        'Deposit Paid' => 7,
        'Builder Invoice Pending' => 8,
        'Builder Invoiced' => 9,
        'Paid by Builder' => 10,
        'Redeemed' => 11,
        'Expired' => 12,
        'Voided' => 13,
        'Rejected' => 14
    };

    private static final Set<String> TERMINAL_STATUSES = new Set<String>{ 'Redeemed', 'Expired', 'Voided', 'Rejected' };

    public static void handleVoucherBefore(List<Voucher__c> newList, Map<Id, Voucher__c> oldMap) {
        for (Voucher__c voucherRow : newList) {
            if (voucherRow.Voucher_Type__c == 'Standard Grilling Island') {
                voucherRow.Upsell_Eligible__c = true;
                voucherRow.Upsell_Recommended__c = true;
                if (String.isBlank(voucherRow.Voucher_Entitlement__c)) {
                    voucherRow.Voucher_Entitlement__c = 'Standard Grilling Island';
                }
                if (String.isBlank(voucherRow.Recommended_Upsells__c)) {
                    voucherRow.Recommended_Upsells__c =
                        'Retreat;Entertainer;Signature;Ventilation Package;Gas Line / Propane Setup;Paver Patio Expansion';
                }
            }
            if (String.isBlank(voucherRow.Builder_Invoice_Status__c)) {
                voucherRow.Builder_Invoice_Status__c = 'Pending';
            }
        }
    }

    public static void handleVoucherAfter(List<Voucher__c> newList) {
        syncCampaignMemberStatus(new Map<Id, Voucher__c>(newList).keySet());
    }

    @AuraEnabled
    public static ActionResult submitVoucherForLead(Id leadId, Id campaignId, String voucherCode) {
        requireCreate(CampaignMember.SObjectType, 'Campaign Member create access is required.');
        requireUpdate(Voucher__c.SObjectType, 'Voucher update access is required.');

        if (leadId == null || campaignId == null || String.isBlank(voucherCode)) {
            return new ActionResult(false, 'Lead, Campaign, and Voucher Code are required.', null);
        }

        Lead leadRow = [
            SELECT Id
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        Campaign campaignRow = [
            SELECT Id, Builder_Account__c
            FROM Campaign
            WHERE Id = :campaignId
            LIMIT 1
        ];
        Voucher__c voucherRow = [
            SELECT Id, Status__c, Builder_Account__c, Campaign__c, Homeowner_Lead__c
            FROM Voucher__c
            WHERE Voucher_Code__c = :voucherCode
            LIMIT 1
        ];

        if (voucherRow.Status__c != 'Active' && voucherRow.Status__c != 'Draft') {
            return new ActionResult(false, 'Voucher is not in an active state for submission.', voucherRow.Id);
        }

        voucherRow.Campaign__c = campaignRow.Id;
        voucherRow.Homeowner_Lead__c = leadRow.Id;
        if (voucherRow.Builder_Account__c == null) {
            voucherRow.Builder_Account__c = campaignRow.Builder_Account__c;
        }
        voucherRow.Status__c = 'Submitted';
        update voucherRow;

        upsertCampaignMember(campaignId, leadId, null, 'Submitted');
        return new ActionResult(true, 'Voucher submitted.', voucherRow.Id);
    }

    @AuraEnabled
    public static ActionResult validateVoucher(Id voucherId) {
        requireUpdate(Voucher__c.SObjectType, 'Voucher update access is required.');
        Voucher__c voucherRow = [
            SELECT Id, Status__c, Expiration_Date__c, Redeemed_Quote__c
            FROM Voucher__c
            WHERE Id = :voucherId
            LIMIT 1
        ];

        if (voucherRow.Status__c == 'Rejected' || voucherRow.Status__c == 'Voided' || voucherRow.Status__c == 'Redeemed') {
            return new ActionResult(false, 'Voucher cannot be validated from its current status.', voucherRow.Id);
        }
        if (voucherRow.Expiration_Date__c != null && voucherRow.Expiration_Date__c < Date.today()) {
            return new ActionResult(false, 'Voucher is expired and cannot be validated without an approved exception.', voucherRow.Id);
        }

        voucherRow.Status__c = 'Validated';
        update voucherRow;
        return new ActionResult(true, 'Voucher validated.', voucherRow.Id);
    }

    @AuraEnabled
    public static ActionResult reserveVoucher(Id voucherId, Id opportunityId) {
        requireUpdate(Voucher__c.SObjectType, 'Voucher update access is required.');
        if (voucherId == null || opportunityId == null) {
            return new ActionResult(false, 'Voucher and Opportunity are required.', null);
        }

        Opportunity oppRow = [
            SELECT Id, Type, Account.IsPersonAccount, Account.PersonContactId, Account.ODL_Secondary_Contact__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        Voucher__c voucherRow = [
            SELECT Id, Status__c, Contact__c
            FROM Voucher__c
            WHERE Id = :voucherId
            LIMIT 1
        ];

        voucherRow.Reserved_Opportunity__c = oppRow.Id;
        if (voucherRow.Contact__c == null && oppRow.Account != null) {
            voucherRow.Contact__c = ODLHouseholdService.preferredHouseholdContactId(oppRow.Account);
        }
        applyMinimumStatus(voucherRow, 'Reserved');
        if (isDesignBuildOpportunityType(oppRow.Type)) {
            voucherRow.Upsell_Outcome__c = 'Routed to Design Build';
            voucherRow.Voucher_Attach_Rate_Category__c = 'Voucher + Design Build';
        }
        update voucherRow;
        return new ActionResult(true, 'Voucher reserved against the opportunity.', voucherRow.Id);
    }

    @AuraEnabled
    public static ActionResult markBuilderInvoiced(Id voucherId, String invoiceNumber, Date invoiceDate, Decimal reimbursementAmount) {
        requireUpdate(Voucher__c.SObjectType, 'Voucher update access is required.');
        Voucher__c voucherRow = new Voucher__c(
            Id = voucherId,
            Builder_Invoice_Number__c = invoiceNumber,
            Builder_Invoice_Date__c = invoiceDate,
            Builder_Invoice_Status__c = 'Invoiced',
            Status__c = 'Builder Invoiced'
        );
        update voucherRow;
        return new ActionResult(true, 'Voucher marked as builder invoiced.', voucherId);
    }

    @AuraEnabled
    public static ActionResult markBuilderPaid(Id voucherId, Date paidDate) {
        requireUpdate(Voucher__c.SObjectType, 'Voucher update access is required.');
        Voucher__c voucherRow = new Voucher__c(
            Id = voucherId,
            Builder_Invoice_Status__c = 'Paid',
            Builder_Paid_Date__c = paidDate,
            Status__c = 'Paid by Builder'
        );
        update voucherRow;
        return new ActionResult(true, 'Voucher marked as paid by builder.', voucherId);
    }

    @AuraEnabled
    public static ActionResult markRedeemed(Id voucherId) {
        requireUpdate(Voucher__c.SObjectType, 'Voucher update access is required.');
        update new Voucher__c(Id = voucherId, Status__c = 'Redeemed');
        return new ActionResult(true, 'Voucher redeemed.', voucherId);
    }

    public static void ensureCampaignMemberStatuses(List<Campaign> newList) {
        Set<Id> campaignIds = new Set<Id>();
        for (Campaign campaignRow : newList) {
            if (campaignRow.Builder_Account__c != null || !String.isBlank(campaignRow.Offer_Description__c)) {
                campaignIds.add(campaignRow.Id);
            }
        }
        if (campaignIds.isEmpty()) {
            return;
        }

        Map<Id, Campaign> fullCampaigns = new Map<Id, Campaign>([
            SELECT Id, Builder_Account__c, Offer_Description__c
            FROM Campaign
            WHERE Id IN :campaignIds
        ]);

        Map<Id, Set<String>> existingByCampaign = new Map<Id, Set<String>>();
        for (CampaignMemberStatus statusRow : [
            SELECT CampaignId, Label
            FROM CampaignMemberStatus
            WHERE CampaignId IN :campaignIds
        ]) {
            if (!existingByCampaign.containsKey(statusRow.CampaignId)) {
                existingByCampaign.put(statusRow.CampaignId, new Set<String>());
            }
            existingByCampaign.get(statusRow.CampaignId).add(statusRow.Label);
        }

        List<CampaignMemberStatus> rowsToInsert = new List<CampaignMemberStatus>();
        for (Campaign campaignRow : fullCampaigns.values()) {
            if (campaignRow.Builder_Account__c == null && String.isBlank(campaignRow.Offer_Description__c)) {
                continue;
            }
            Set<String> existing = existingByCampaign.containsKey(campaignRow.Id) ? existingByCampaign.get(campaignRow.Id) : new Set<String>();
            Integer sortOrder = 1;
            for (String statusLabel : CAMPAIGN_MEMBER_STATUSES) {
                if (!existing.contains(statusLabel)) {
                    rowsToInsert.add(new CampaignMemberStatus(
                        CampaignId = campaignRow.Id,
                        Label = statusLabel,
                        SortOrder = sortOrder,
                        IsDefault = (statusLabel == 'Sent'),
                        HasResponded = statusLabel != 'Sent' && statusLabel != 'Viewed'
                    ));
                }
                sortOrder++;
            }
        }
        if (!rowsToInsert.isEmpty()) {
            Database.insert(rowsToInsert, false);
        }
    }

    public static void syncVoucherFromQuotes(Set<Id> quoteIds) {
        if (quoteIds.isEmpty()) {
            return;
        }
        List<Quote> quoteRows = [
            SELECT Id, OpportunityId, Voucher__c, Opportunity.Type,
                   Opportunity.BMG_Package__c, Voucher_Credit_Amount__c
            FROM Quote
            WHERE Id IN :quoteIds AND Voucher__c != null
        ];
        if (quoteRows.isEmpty()) {
            return;
        }

        Map<Id, List<QuoteLineItem>> lineItemsByQuote = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem lineRow : [
            SELECT Id, QuoteId, TotalPrice, UnitPrice, Quantity, PricebookEntry.Product2.Name, PricebookEntry.Product2.Family
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
        ]) {
            if (!lineItemsByQuote.containsKey(lineRow.QuoteId)) {
                lineItemsByQuote.put(lineRow.QuoteId, new List<QuoteLineItem>());
            }
            lineItemsByQuote.get(lineRow.QuoteId).add(lineRow);
        }

        Set<Id> voucherIds = new Set<Id>();
        for (Quote quoteRow : quoteRows) {
            voucherIds.add(quoteRow.Voucher__c);
        }

        Map<Id, Voucher__c> vouchers = new Map<Id, Voucher__c>([
            SELECT Id, Status__c, Voucher_Type__c, Voucher_Entitlement__c, Reserved_Opportunity__c, Redeemed_Quote__c,
                   Voucher_Attach_Rate_Category__c, Upsell_Outcome__c, Upsell_Revenue__c
            FROM Voucher__c
            WHERE Id IN :voucherIds
        ]);

        List<Voucher__c> updates = new List<Voucher__c>();
        for (Quote quoteRow : quoteRows) {
            Voucher__c voucherRow = vouchers.get(quoteRow.Voucher__c);
            if (voucherRow == null) {
                continue;
            }

            Decimal entitlementAmount = 0;
            Decimal nonEntitlementAmount = 0;
            List<QuoteLineItem> lineRows = lineItemsByQuote.containsKey(quoteRow.Id)
                ? lineItemsByQuote.get(quoteRow.Id)
                : new List<QuoteLineItem>();
            for (QuoteLineItem lineRow : lineRows) {
                Boolean isEntitlement = isEntitlementLine(voucherRow, lineRow);
                if (isEntitlement) {
                    entitlementAmount += lineRow.TotalPrice == null ? 0 : lineRow.TotalPrice;
                } else {
                    nonEntitlementAmount += lineRow.TotalPrice == null ? 0 : lineRow.TotalPrice;
                }
            }

            Voucher__c updateRow = new Voucher__c(Id = voucherRow.Id);
            updateRow.Redeemed_Quote__c = quoteRow.Id;
            if (voucherRow.Reserved_Opportunity__c == null) {
                updateRow.Reserved_Opportunity__c = quoteRow.OpportunityId;
            }
            setUpdateStatus(updateRow, voucherRow.Status__c, 'Applied to Quote');
            updateRow.Upsell_Revenue__c = nonEntitlementAmount;

            String packageValue = quoteRow.Opportunity != null ? quoteRow.Opportunity.BMG_Package__c : null;
            String oppType = quoteRow.Opportunity != null ? quoteRow.Opportunity.Type : null;
            if (isDesignBuildOpportunityType(oppType)) {
                updateRow.Voucher_Attach_Rate_Category__c = 'Voucher + Design Build';
                updateRow.Upsell_Outcome__c = 'Routed to Design Build';
            } else if (PACKAGE_VALUES.contains(packageValue)) {
                updateRow.Voucher_Attach_Rate_Category__c = 'Voucher + Package Upgrade';
                updateRow.Upsell_Outcome__c = 'Accepted';
            } else if (nonEntitlementAmount > 0) {
                updateRow.Voucher_Attach_Rate_Category__c = 'Voucher + Add-Ons';
                updateRow.Upsell_Outcome__c = 'Accepted';
            } else {
                updateRow.Voucher_Attach_Rate_Category__c = 'Voucher Only';
                updateRow.Upsell_Outcome__c = 'Presented';
            }

            updates.add(updateRow);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public static void syncVoucherFromOpportunity(Set<Id> opportunityIds) {
        if (opportunityIds.isEmpty()) {
            return;
        }
        Map<Id, Opportunity> opps = new Map<Id, Opportunity>([
            SELECT Id, StageName, Deposit_Paid__c, Deposit_Paid_Date__c, Type,
                   Account.IsPersonAccount, Account.PersonContactId, Account.ODL_Secondary_Contact__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]);
        List<Voucher__c> updates = new List<Voucher__c>();
        for (Voucher__c voucherRow : [
            SELECT Id, Status__c, Builder_Invoice_Status__c,
                   Reserved_Opportunity__c, Contact__c
            FROM Voucher__c
            WHERE Reserved_Opportunity__c IN :opportunityIds
        ]) {
            Opportunity oppRow = opps.get(voucherRow.Reserved_Opportunity__c);
            if (oppRow == null) {
                continue;
            }
            Voucher__c updateRow = new Voucher__c(Id = voucherRow.Id);
            if (voucherRow.Contact__c == null && oppRow.Account != null) {
                updateRow.Contact__c = ODLHouseholdService.preferredHouseholdContactId(oppRow.Account);
            }
            if (isContractSignedStage(oppRow.StageName)) {
                setUpdateStatus(updateRow, voucherRow.Status__c, 'Contract Signed');
            }
            if (oppRow.Deposit_Paid__c == true) {
                setUpdateStatus(updateRow, voucherRow.Status__c, 'Deposit Paid');
                if (String.isBlank(voucherRow.Builder_Invoice_Status__c) || voucherRow.Builder_Invoice_Status__c == 'Not Required') {
                    updateRow.Builder_Invoice_Status__c = 'Ready to Invoice';
                } 
            }
            updates.add(updateRow);
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public static void syncVoucherFromPaymentMilestones(Set<Id> milestoneIds) {
        if (milestoneIds.isEmpty()) {
            return;
        }
        List<Payment_Milestone__c> milestones = [
            SELECT Id, Opportunity__c, Voucher__c, Type__c, Status__c, Paid_Date__c
            FROM Payment_Milestone__c
            WHERE Id IN :milestoneIds
        ];
        List<Opportunity> oppUpdates = new List<Opportunity>();
        List<Voucher__c> voucherUpdates = new List<Voucher__c>();
        for (Payment_Milestone__c milestoneRow : milestones) {
            if (milestoneRow.Type__c == 'Deposit' && milestoneRow.Status__c == 'Paid') {
                if (milestoneRow.Opportunity__c != null) {
                    oppUpdates.add(new Opportunity(
                        Id = milestoneRow.Opportunity__c,
                        Deposit_Paid__c = true,
                        Deposit_Paid_Date__c = milestoneRow.Paid_Date__c == null ? Date.today() : milestoneRow.Paid_Date__c
                    ));
                }
                if (milestoneRow.Voucher__c != null) {
                    voucherUpdates.add(new Voucher__c(
                        Id = milestoneRow.Voucher__c,
                        Payment_Milestone__c = milestoneRow.Id
                    ));
                }
            }
        }
        if (!oppUpdates.isEmpty()) {
            update oppUpdates;
        }
        if (!voucherUpdates.isEmpty()) {
            update voucherUpdates;
        }
    }

    private static void syncCampaignMemberStatus(Set<Id> voucherIds) {
        if (voucherIds.isEmpty()) {
            return;
        }
        for (Voucher__c voucherRow : [
            SELECT Id, Status__c, Campaign__c, Homeowner_Lead__c, Contact__c
            FROM Voucher__c
            WHERE Id IN :voucherIds
        ]) {
            if (voucherRow.Campaign__c == null) {
                continue;
            }
            String targetStatus = campaignStatusForVoucherStatus(voucherRow.Status__c);
            if (targetStatus == null) {
                continue;
            }
            upsertCampaignMember(voucherRow.Campaign__c, voucherRow.Homeowner_Lead__c, voucherRow.Contact__c, targetStatus);
        }
    }

    private static void upsertCampaignMember(Id campaignId, Id leadId, Id contactId, String statusValue) {
        List<CampaignMember> existing;
        if (leadId != null) {
            existing = [
                SELECT Id, Status
                FROM CampaignMember
                WHERE CampaignId = :campaignId AND LeadId = :leadId
                LIMIT 1
            ];
        } else if (contactId != null) {
            existing = [
                SELECT Id, Status
                FROM CampaignMember
                WHERE CampaignId = :campaignId AND ContactId = :contactId
                LIMIT 1
            ];
        } else {
            return;
        }

        if (!existing.isEmpty()) {
            CampaignMember row = existing[0];
            row.Status = statusValue;
            update row;
            return;
        }

        CampaignMember newRow = new CampaignMember(
            CampaignId = campaignId,
            Status = statusValue
        );
        if (leadId != null) {
            newRow.LeadId = leadId;
        } else {
            newRow.ContactId = contactId;
        }
        insert newRow;
    }

    private static Boolean isEntitlementLine(Voucher__c voucherRow, QuoteLineItem lineRow) {
        String entitlement = String.isBlank(voucherRow.Voucher_Entitlement__c) ? voucherRow.Voucher_Type__c : voucherRow.Voucher_Entitlement__c;
        String productName = lineRow.PricebookEntry != null && lineRow.PricebookEntry.Product2 != null ? lineRow.PricebookEntry.Product2.Name : null;
        String family = lineRow.PricebookEntry != null && lineRow.PricebookEntry.Product2 != null ? lineRow.PricebookEntry.Product2.Family : null;
        return (entitlement != null && entitlement == productName) || (entitlement != null && entitlement == family);
    }

    private static Boolean isContractSignedStage(String stageName) {
        return stageName == 'Contract Signed'
            || stageName == 'Deposit Paid'
            || stageName == 'Pre-Production'
            || stageName == 'In Progress'
            || stageName == 'Pre Close'
            || stageName == 'Job Completed';
    }

    private static Boolean isDesignBuildOpportunityType(String oppType) {
        return oppType == 'Design Build' || oppType == 'Design and Build';
    }

    private static void applyMinimumStatus(Voucher__c voucherRow, String targetStatus) {
        if (voucherRow.Status__c == null || TERMINAL_STATUSES.contains(voucherRow.Status__c)) {
            return;
        }
        Integer currentRank = STATUS_RANK.containsKey(voucherRow.Status__c) ? STATUS_RANK.get(voucherRow.Status__c) : -1;
        Integer targetRank = STATUS_RANK.get(targetStatus);
        if (targetRank > currentRank) {
            voucherRow.Status__c = targetStatus;
        }
    }

    private static void setUpdateStatus(Voucher__c updateRow, String currentStatus, String targetStatus) {
        if (currentStatus == null || TERMINAL_STATUSES.contains(currentStatus)) {
            return;
        }
        Integer currentRank = STATUS_RANK.containsKey(currentStatus) ? STATUS_RANK.get(currentStatus) : -1;
        Integer targetRank = STATUS_RANK.get(targetStatus);
        if (targetRank > currentRank) {
            updateRow.Status__c = targetStatus;
        }
    }

    private static String campaignStatusForVoucherStatus(String voucherStatus) {
        if (voucherStatus == 'Submitted') return 'Submitted';
        if (voucherStatus == 'Validated') return 'Validated';
        if (voucherStatus == 'Reserved') return 'Contacted';
        if (voucherStatus == 'Applied to Quote') return 'Quote Sent';
        if (voucherStatus == 'Contract Signed') return 'Contract Signed';
        if (voucherStatus == 'Deposit Paid') return 'Deposit Paid';
        if (voucherStatus == 'Builder Invoiced') return 'Builder Invoiced';
        if (voucherStatus == 'Paid by Builder' || voucherStatus == 'Redeemed') return 'Closed Won';
        if (voucherStatus == 'Rejected') return 'Rejected';
        if (voucherStatus == 'Expired') return 'Expired';
        return null;
    }

    private static void requireCreate(Schema.SObjectType objectType, String message) {
        if (!objectType.getDescribe().isCreateable()) {
            throw new AuraHandledException(message);
        }
    }

    private static void requireUpdate(Schema.SObjectType objectType, String message) {
        if (!objectType.getDescribe().isUpdateable()) {
            throw new AuraHandledException(message);
        }
    }
}