public with sharing class ODLVisibleWorkspaceController {
    private static final Integer ROW_LIMIT = 5;

    public class FieldItem {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String url;
        @AuraEnabled public String subtext;
    }

    public class RowData {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String url;
        @AuraEnabled public String status;
        @AuraEnabled public String subtext;
        @AuraEnabled public String secondaryText;
        @AuraEnabled public String dateText;
    }

    public class ActionItem {
        @AuraEnabled public String label;
        @AuraEnabled public String actionType;
        @AuraEnabled public Boolean disabled;
        @AuraEnabled public String disabledReason;
        @AuraEnabled public String url;
    }

    public class SectionData {
        @AuraEnabled public String title;
        @AuraEnabled public String kind;
        @AuraEnabled public String emptyMessage;
        @AuraEnabled public List<FieldItem> fields;
        @AuraEnabled public List<RowData> rows;
    }

    public class PageData {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String eyebrow;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public List<String> badges;
        @AuraEnabled public List<ActionItem> actions;
        @AuraEnabled public List<SectionData> sections;
        @AuraEnabled public List<String> nextActions;
        @AuraEnabled public List<FieldItem> healthItems;
        @AuraEnabled public List<String> openItems;
    }

    @AuraEnabled(cacheable=true)
    public static PageData getPageData(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }

        String apiName = recordId.getSObjectType().getDescribe().getName();
        if (apiName == 'Voucher__c') return buildVoucherPage(recordId);
        if (apiName == 'Campaign') return buildCampaignPage(recordId);
        if (apiName == 'Opportunity') return buildOpportunityClosePage(recordId);
        if (apiName == 'Quote') return buildQuotePage(recordId);
        if (apiName == 'WorkOrder') return buildWorkOrderPage(recordId);
        if (apiName == 'Design_Review__c') return buildDesignReviewPage(recordId);
        if (apiName == 'Homeowner_Property__c') return buildHomeownerPropertyPage(recordId);
        if (apiName == 'Payment_Milestone__c') return buildPaymentMilestonePage(recordId);
        if (apiName == 'Change_Order__c') return buildChangeOrderPage(recordId);
        if (apiName == 'Warranty_Record__c') return buildWarrantyRecordPage(recordId);
        if (apiName == 'Case') return buildWarrantyCasePage(recordId);

        throw new AuraHandledException('Unsupported ODL record page for object: ' + apiName);
    }

    private static PageData newPage(String apiName, String eyebrow, String title, String subtitle) {
        PageData page = new PageData();
        page.objectApiName = apiName;
        page.eyebrow = eyebrow;
        page.title = title;
        page.subtitle = subtitle;
        page.badges = new List<String>();
        page.actions = new List<ActionItem>();
        page.sections = new List<SectionData>();
        page.nextActions = new List<String>();
        page.healthItems = new List<FieldItem>();
        page.openItems = new List<String>();
        return page;
    }

    private static ActionItem action(String label, String actionType) {
        ActionItem item = new ActionItem();
        item.label = label;
        item.actionType = actionType;
        item.disabled = false;
        return item;
    }

    private static ActionItem disabledAction(String label, String reason) {
        ActionItem item = new ActionItem();
        item.label = label;
        item.actionType = 'disabled';
        item.disabled = true;
        item.disabledReason = reason;
        return item;
    }

    private static FieldItem field(String label, Object value) {
        FieldItem item = new FieldItem();
        item.label = label;
        item.value = stringify(value);
        return item;
    }

    private static FieldItem linkField(String label, String value, Id idValue, String subtext) {
        FieldItem item = new FieldItem();
        item.label = label;
        item.value = value;
        item.url = idValue == null ? null : '/' + idValue;
        item.subtext = subtext;
        return item;
    }

    private static SectionData fieldSection(String title, List<FieldItem> fields, String emptyMessage) {
        SectionData section = new SectionData();
        section.title = title;
        section.kind = 'fields';
        section.fields = fields;
        section.rows = new List<RowData>();
        section.emptyMessage = emptyMessage;
        return section;
    }

    private static SectionData rowSection(String title, List<RowData> rows, String emptyMessage) {
        SectionData section = new SectionData();
        section.title = title;
        section.kind = 'rows';
        section.fields = new List<FieldItem>();
        section.rows = rows;
        section.emptyMessage = emptyMessage;
        return section;
    }

    private static String stringify(Object value) {
        if (value == null) return null;
        if (value instanceof Date) return String.valueOf((Date) value);
        if (value instanceof Decimal) return String.valueOf((Decimal) value);
        if (value instanceof Boolean) return ((Boolean) value) ? 'Yes' : 'No';
        String textValue = String.valueOf(value);
        return String.isBlank(textValue) ? null : textValue;
    }

    private static String safeName(SObject recordRow, String fieldName) {
        if (recordRow == null || String.isBlank(fieldName)) return null;
        try {
            SObject relatedRow = recordRow.getSObject(fieldName);
            if (relatedRow == null) return null;
            Object nameValue = relatedRow.get('Name');
            return nameValue == null ? null : String.valueOf(nameValue);
        } catch (Exception ignored) {
            return null;
        }
    }

    private static List<RowData> fileRows(Id parentId) {
        List<RowData> rows = new List<RowData>();
        for (ContentDocumentLink linkRow : [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType, ContentDocument.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :parentId
            ORDER BY ContentDocument.LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ]) {
            RowData row = new RowData();
            row.id = linkRow.ContentDocumentId;
            row.label = linkRow.ContentDocument != null ? linkRow.ContentDocument.Title : 'File';
            row.url = '/' + linkRow.ContentDocumentId;
            row.status = linkRow.ContentDocument != null ? linkRow.ContentDocument.FileType : null;
            row.dateText = linkRow.ContentDocument != null ? linkRow.ContentDocument.LastModifiedDate.format('M/d/yyyy') : null;
            rows.add(row);
        }
        return rows;
    }

    private static List<RowData> activityRows(Id recordId) {
        List<RowData> rows = new List<RowData>();
        for (Task taskRow : [
            SELECT Id, Subject, Status, ActivityDate, Description
            FROM Task
            WHERE WhatId = :recordId
            ORDER BY CreatedDate DESC
            LIMIT :ROW_LIMIT
        ]) {
            RowData row = new RowData();
            row.id = taskRow.Id;
            row.label = taskRow.Subject;
            row.url = '/' + taskRow.Id;
            row.status = taskRow.Status;
            row.subtext = 'Task';
            row.secondaryText = trimPreview(taskRow.Description);
            row.dateText = taskRow.ActivityDate == null ? null : String.valueOf(taskRow.ActivityDate);
            rows.add(row);
        }
        for (Event eventRow : [
            SELECT Id, Subject, Type, ActivityDateTime, Description
            FROM Event
            WHERE WhatId = :recordId
            ORDER BY CreatedDate DESC
            LIMIT :ROW_LIMIT
        ]) {
            RowData row = new RowData();
            row.id = eventRow.Id;
            row.label = eventRow.Subject;
            row.url = '/' + eventRow.Id;
            row.status = eventRow.Type;
            row.subtext = 'Event';
            row.secondaryText = trimPreview(eventRow.Description);
            row.dateText = eventRow.ActivityDateTime == null ? null : eventRow.ActivityDateTime.format('M/d/yyyy h:mm a');
            rows.add(row);
        }
        return rows;
    }

    private static String trimPreview(String value) {
        if (String.isBlank(value)) return null;
        String normalized = value.replace('\r', ' ').replace('\n', ' ').trim();
        return normalized.length() <= 80 ? normalized : normalized.substring(0, 77) + '...';
    }

    private static PageData buildVoucherPage(Id recordId) {
        Voucher__c voucherRow = [
            SELECT Id, Name, Voucher_Code__c, Voucher_Type__c, Status__c,
                   Builder_Account__c, Builder_Account__r.Name,
                   Campaign__c, Campaign__r.Name, Homeowner_Lead__c, Homeowner_Lead__r.Name,
                   Contact__c, Contact__r.Name, Reserved_Opportunity__c, Reserved_Opportunity__r.Name,
                   Redeemed_Quote__c, Redeemed_Quote__r.Name, Eligible_Product__c,
                   Eligible_Product__r.Name, Expiration_Date__c, Voucher_Face_Value__c,
                   Builder_Invoice_Status__c, Builder_Invoice_Number__c, Builder_Invoice_Date__c,
                   Builder_Paid_Date__c, Rejection_Reason__c,
                   Redemption_Notes__c, Finance_Exception_Approved__c, Finance_Exception_Notes__c,
                   Upsell_Outcome__c, Upsell_Revenue__c, Voucher_Attach_Rate_Category__c,
                   Recommended_Upsells__c, Voucher_Entitlement__c
            FROM Voucher__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        PageData page = newPage('Voucher__c', 'Voucher', voucherRow.Voucher_Code__c, 'Lennar standard grill entitlement with builder invoice tracking.');
        page.badges.add(voucherRow.Status__c);
        page.badges.add(voucherRow.Voucher_Type__c);
        page.actions.add(action('Edit Voucher', 'edit'));
        page.actions.add(action('New Task', 'newTask'));

        page.sections.add(fieldSection('Voucher Summary', new List<FieldItem>{
            field('Voucher Number', voucherRow.Name),
            field('Voucher Code', voucherRow.Voucher_Code__c),
            field('Voucher Type', voucherRow.Voucher_Type__c),
            field('Status', voucherRow.Status__c),
            field('Voucher Face Value', voucherRow.Voucher_Face_Value__c),
            field('Expiration Date', voucherRow.Expiration_Date__c)
        }, 'No voucher summary data.'));

        page.sections.add(fieldSection('Homeowner / Lead / Contact', new List<FieldItem>{
            linkField('Homeowner Lead', safeName(voucherRow, 'Homeowner_Lead__r'), voucherRow.Homeowner_Lead__c, null),
            linkField('Contact', safeName(voucherRow, 'Contact__r'), voucherRow.Contact__c, null),
            linkField('Reserved Opportunity', safeName(voucherRow, 'Reserved_Opportunity__r'), voucherRow.Reserved_Opportunity__c, null),
            linkField('Redeemed Quote', safeName(voucherRow, 'Redeemed_Quote__r'), voucherRow.Redeemed_Quote__c, null)
        }, 'No homeowner relationship is linked.'));

        page.sections.add(fieldSection('Campaign and Builder Sponsor', new List<FieldItem>{
            linkField('Campaign', safeName(voucherRow, 'Campaign__r'), voucherRow.Campaign__c, null),
            linkField('Builder Account', safeName(voucherRow, 'Builder_Account__r'), voucherRow.Builder_Account__c, null),
            field('Builder Invoice Status', voucherRow.Builder_Invoice_Status__c)
        }, 'No campaign or builder sponsor is linked.'));

        page.sections.add(fieldSection('Entitlement', new List<FieldItem>{
            field('Voucher Entitlement', voucherRow.Voucher_Entitlement__c),
            linkField('Eligible Product', safeName(voucherRow, 'Eligible_Product__r'), (Id) voucherRow.get('Eligible_Product__c'), null),
            field('Voucher Type', voucherRow.Voucher_Type__c)
        }, 'No entitlement data is stored.'));

        page.sections.add(fieldSection('Quote Application', new List<FieldItem>{
            linkField('Reserved Opportunity', safeName(voucherRow, 'Reserved_Opportunity__r'), voucherRow.Reserved_Opportunity__c, null),
            linkField('Redeemed Quote', safeName(voucherRow, 'Redeemed_Quote__r'), voucherRow.Redeemed_Quote__c, null),
            field('Rejection Reason', voucherRow.Rejection_Reason__c),
            field('Redemption Notes', voucherRow.Redemption_Notes__c)
        }, 'No quote application is linked.'));

        page.sections.add(fieldSection('Builder Invoice / Payment', new List<FieldItem>{
            field('Builder Invoice Status', voucherRow.Builder_Invoice_Status__c),
            field('Builder Invoice Number', voucherRow.Builder_Invoice_Number__c),
            field('Builder Invoice Date', voucherRow.Builder_Invoice_Date__c),
            field('Builder Paid Date', voucherRow.Builder_Paid_Date__c),
            field('Voucher Face Value', voucherRow.Voucher_Face_Value__c),
            field('Finance Exception Approved', voucherRow.Finance_Exception_Approved__c)
        }, 'No builder invoice fields are populated.'));

        page.sections.add(fieldSection('Status and Exceptions', new List<FieldItem>{
            field('Status', voucherRow.Status__c),
            field('Rejection Reason', voucherRow.Rejection_Reason__c),
            field('Redemption Notes', voucherRow.Redemption_Notes__c),
            field('Finance Exception Notes', voucherRow.Finance_Exception_Notes__c)
        }, 'No status exception fields are populated.'));

        page.sections.add(fieldSection('Upsell Tracking', new List<FieldItem>{
            field('Recommended Upsells', voucherRow.Recommended_Upsells__c),
            field('Upsell Outcome', voucherRow.Upsell_Outcome__c),
            field('Upsell Revenue', voucherRow.Upsell_Revenue__c),
            field('Voucher Attach Rate Category', voucherRow.Voucher_Attach_Rate_Category__c)
        }, 'No upsell tracking data is stored.'));

        page.sections.add(rowSection('Activity / Notes', activityRows(recordId), 'No Tasks or Events are logged on this voucher.'));

        List<RowData> relatedRows = new List<RowData>();
        if (voucherRow.Campaign__c != null) relatedRows.add(makeLinkRow(voucherRow.Campaign__c, safeName(voucherRow, 'Campaign__r'), 'Campaign', null, null));
        if (voucherRow.Builder_Account__c != null) relatedRows.add(makeLinkRow(voucherRow.Builder_Account__c, safeName(voucherRow, 'Builder_Account__r'), 'Builder Sponsor', null, null));
        if (voucherRow.Reserved_Opportunity__c != null) relatedRows.add(makeLinkRow(voucherRow.Reserved_Opportunity__c, safeName(voucherRow, 'Reserved_Opportunity__r'), 'Opportunity', null, null));
        if (voucherRow.Redeemed_Quote__c != null) relatedRows.add(makeLinkRow(voucherRow.Redeemed_Quote__c, safeName(voucherRow, 'Redeemed_Quote__r'), 'Quote', null, null));
        page.sections.add(rowSection('Related Records', relatedRows, 'No related records are linked.'));
        page.sections.add(rowSection('Files', fileRows(recordId), 'No files are linked to this voucher.'));

        if (voucherRow.Campaign__c == null) page.openItems.add('Campaign is blank. Submitted and later voucher states require campaign attribution.');
        if (voucherRow.Builder_Account__c == null) page.openItems.add('Builder Account is required for Lennar vouchers.');
        if (voucherRow.Reserved_Opportunity__c == null) page.openItems.add('Voucher is not linked to an opportunity.');
        if (voucherRow.Redeemed_Quote__c == null) page.openItems.add('Voucher is not linked to a quote.');

        page.healthItems.add(field('Last visible status', voucherRow.Status__c));
        page.healthItems.add(field('Builder invoice status', voucherRow.Builder_Invoice_Status__c));
        page.healthItems.add(field('Expiration date', voucherRow.Expiration_Date__c));
        return page;
    }

    private static PageData buildCampaignPage(Id recordId) {
        Campaign campaignRow = [
            SELECT Id, Name, Type, Status, StartDate, EndDate, BudgetedCost, ActualCost, ExpectedRevenue,
                   Builder_Account__c, Builder_Account__r.Name, Offer_Description__c, Owner.Name
            FROM Campaign
            WHERE Id = :recordId
            LIMIT 1
        ];

        List<Voucher__c> vouchers = [
            SELECT Id, Name, Voucher_Code__c, Status__c, Voucher_Type__c, Reserved_Opportunity__c, Redeemed_Quote__c,
                   Upsell_Revenue__c, Voucher_Face_Value__c, Builder_Invoice_Status__c, Voucher_Attach_Rate_Category__c
            FROM Voucher__c
            WHERE Campaign__c = :recordId
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
        List<CampaignMember> members = [
            SELECT Id, LeadId, ContactId, Status, CreatedDate, Lead.Name, Contact.Name
            FROM CampaignMember
            WHERE CampaignId = :recordId
            ORDER BY CreatedDate DESC
            LIMIT :ROW_LIMIT
        ];
        Set<Id> oppIds = new Set<Id>();
        for (Voucher__c voucherRow : vouchers) if (voucherRow.Reserved_Opportunity__c != null) oppIds.add(voucherRow.Reserved_Opportunity__c);
        Map<Id, Opportunity> opportunities = oppIds.isEmpty() ? new Map<Id, Opportunity>() : new Map<Id, Opportunity>([
            SELECT Id, Name, Type, StageName, Amount
            FROM Opportunity
            WHERE Id IN :oppIds
        ]);

        Decimal upsellRevenue = 0;
        Map<String, Integer> statusCounts = new Map<String, Integer>();
        for (Voucher__c voucherRow : vouchers) {
            statusCounts.put(voucherRow.Status__c, 1 + (statusCounts.containsKey(voucherRow.Status__c) ? statusCounts.get(voucherRow.Status__c) : 0));
            if (voucherRow.Upsell_Revenue__c != null) upsellRevenue += voucherRow.Upsell_Revenue__c;
        }

        PageData page = newPage('Campaign', 'Campaign', campaignRow.Name, 'Builder-sponsored voucher, campaign member, and ROI tracking for Outdoor Living.');
        if (!String.isBlank(campaignRow.Type)) page.badges.add(campaignRow.Type);
        if (!String.isBlank(campaignRow.Status)) page.badges.add(campaignRow.Status);
        page.actions.add(action('Edit Campaign', 'edit'));
        page.actions.add(action('New Task', 'newTask'));

        page.sections.add(fieldSection('Campaign Summary', new List<FieldItem>{
            field('Campaign Name', campaignRow.Name),
            field('Campaign Type', campaignRow.Type),
            field('Status', campaignRow.Status),
            field('Start Date', campaignRow.StartDate),
            field('End Date', campaignRow.EndDate),
            field('Budgeted Cost', campaignRow.BudgetedCost),
            field('Actual Cost', campaignRow.ActualCost),
            field('Expected Revenue', campaignRow.ExpectedRevenue)
        }, 'No campaign summary.'));

        page.sections.add(fieldSection('Builder Sponsor', new List<FieldItem>{
            linkField('Builder Account', safeName(campaignRow, 'Builder_Account__r'), (Id) campaignRow.get('Builder_Account__c'), null),
            field('Offer Description', campaignRow.Offer_Description__c),
            field('Owner', campaignRow.Owner != null ? campaignRow.Owner.Name : null)
        }, 'No builder sponsor fields are populated.'));

        page.sections.add(fieldSection('Offer / Voucher Details', new List<FieldItem>{
            field('Voucher Count', vouchers.size()),
            field('Submitted Count', statusCounts.get('Submitted')),
            field('Validated Count', statusCounts.get('Validated')),
            field('Reserved Count', statusCounts.get('Reserved')),
            field('Applied to Quote Count', statusCounts.get('Applied to Quote')),
            field('Contract Signed Count', statusCounts.get('Contract Signed')),
            field('Deposit Paid Count', statusCounts.get('Deposit Paid')),
            field('Builder Invoiced Count', statusCounts.get('Builder Invoiced')),
            field('Paid by Builder Count', statusCounts.get('Paid by Builder')),
            field('Redeemed Count', statusCounts.get('Redeemed'))
        }, 'No voucher metrics are available.'));

        List<RowData> memberRows = new List<RowData>();
        List<RowData> leadRows = new List<RowData>();
        for (CampaignMember memberRow : members) {
            RowData row = new RowData();
            row.id = memberRow.Id;
            row.label = memberRow.LeadId != null ? memberRow.Lead.Name : (memberRow.ContactId != null ? memberRow.Contact.Name : 'Campaign Member');
            row.url = memberRow.LeadId != null ? '/' + memberRow.LeadId : (memberRow.ContactId != null ? '/' + memberRow.ContactId : null);
            row.status = memberRow.Status;
            row.dateText = memberRow.CreatedDate.format('M/d/yyyy');
            row.subtext = memberRow.LeadId != null ? 'Lead' : 'Contact';
            memberRows.add(row);
            if (memberRow.LeadId != null) {
                leadRows.add(makeLinkRow(memberRow.LeadId, memberRow.Lead.Name, memberRow.Status, 'Lead', memberRow.CreatedDate.format('M/d/yyyy')));
            }
        }
        page.sections.add(rowSection('Campaign Members', memberRows, 'No Campaign Members are linked.'));
        page.sections.add(rowSection('Leads', leadRows, 'No Leads are linked through Campaign Members.'));

        List<RowData> voucherRows = new List<RowData>();
        for (Voucher__c voucherRow : vouchers) {
            voucherRows.add(makeLinkRow(voucherRow.Id, voucherRow.Voucher_Code__c, voucherRow.Status__c, voucherRow.Voucher_Type__c, null));
        }
        page.sections.add(rowSection('Vouchers', voucherRows, 'No vouchers are linked to this campaign.'));

        List<RowData> opportunityRows = new List<RowData>();
        for (Opportunity oppRow : opportunities.values()) {
            opportunityRows.add(makeLinkRow(oppRow.Id, oppRow.Name, oppRow.StageName, oppRow.Type, oppRow.Amount == null ? null : String.valueOf(oppRow.Amount)));
        }
        page.sections.add(rowSection('Opportunities', opportunityRows, 'No opportunities are linked through vouchers.'));

        List<RowData> quoteRows = new List<RowData>();
        List<RowData> paymentRows = new List<RowData>();
        Decimal builderInvoiceTotal = 0;
        Set<Id> quoteIds = new Set<Id>();
        for (Voucher__c voucherRow : vouchers) {
            if (voucherRow.Redeemed_Quote__c != null) {
                quoteIds.add(voucherRow.Redeemed_Quote__c);
            }
            if (voucherRow.Voucher_Face_Value__c != null) {
                builderInvoiceTotal += voucherRow.Voucher_Face_Value__c;
            }
            if (voucherRow.Status__c == 'Deposit Paid' || voucherRow.Status__c == 'Builder Invoice Pending' || voucherRow.Status__c == 'Builder Invoiced' || voucherRow.Status__c == 'Paid by Builder' || voucherRow.Status__c == 'Redeemed') {
                paymentRows.add(makeLinkRow(voucherRow.Id, voucherRow.Voucher_Code__c, voucherRow.Status__c, 'Voucher payment progress', voucherRow.Builder_Invoice_Status__c));
            }
        }
        if (!quoteIds.isEmpty()) {
            for (Quote quoteRow : [
                SELECT Id, Name, Status, OpportunityId
                FROM Quote
                WHERE Id IN :quoteIds
                ORDER BY CreatedDate DESC
                LIMIT 20
            ]) {
                quoteRows.add(makeLinkRow(quoteRow.Id, quoteRow.Name, quoteRow.Status, 'Quote', null));
            }
        }
        page.sections.add(rowSection('Quotes / Contracts', quoteRows, 'No Quotes are linked through vouchers.'));
        page.sections.add(rowSection('Deposit / Payment Progress', paymentRows, 'No deposit or payment progress is linked to this campaign.'));
        page.sections.add(fieldSection('Builder Invoice Summary', new List<FieldItem>{
            field('Builder Invoiced Count', statusCounts.get('Builder Invoiced')),
            field('Paid by Builder Count', statusCounts.get('Paid by Builder')),
            field('Builder Reimbursement Total', builderInvoiceTotal)
        }, 'No builder invoice summary is available.'));

        page.sections.add(fieldSection('Upsell / ROI Summary', new List<FieldItem>{
            field('Upsell Revenue', upsellRevenue),
            field('Voucher + Design Build Count', countAttachCategory(vouchers, 'Voucher + Design Build')),
            field('Voucher + Package Upgrade Count', countAttachCategory(vouchers, 'Voucher + Package Upgrade')),
            field('Voucher + Add-Ons Count', countAttachCategory(vouchers, 'Voucher + Add-Ons'))
        }, 'No upsell data is stored.'));

        if (campaignRow.Builder_Account__c == null) page.openItems.add('Builder Account is blank on this campaign.');
        if (String.isBlank(campaignRow.Offer_Description__c)) page.openItems.add('Offer Description is blank on this campaign.');
        if (members.isEmpty()) page.openItems.add('No Campaign Members are linked.');
        if (vouchers.isEmpty()) page.openItems.add('No vouchers are linked to this campaign.');
        page.healthItems.add(field('Campaign Status', campaignRow.Status));
        page.healthItems.add(field('Voucher Count', vouchers.size()));
        page.healthItems.add(field('Builder Sponsor', safeName(campaignRow, 'Builder_Account__r')));
        return page;
    }

    private static Integer countAttachCategory(List<Voucher__c> vouchers, String category) {
        Integer count = 0;
        for (Voucher__c voucherRow : vouchers) if (voucherRow.Voucher_Attach_Rate_Category__c == category) count++;
        return count;
    }

    private static PageData buildOpportunityClosePage(Id recordId) {
        Opportunity oppRow = [
            SELECT Id, Name, Type, StageName, Amount, CloseDate, AccountId, Account.Name,
                   ODL_Path__c, BMG_Package__c, Selected_Package__c, Services_Selected__c,
                   Selected_Requirements__c, Quote_Status__c, Contract_Status__c,
                   Deposit_Due__c, Deposit_Paid__c, Deposit_Paid_Date__c,
                   ContractId, Contract.ContractNumber, Contract.Status, Contract.StartDate,
                   Contract.ActivatedDate, Contract.Owner.Name, Owner.Name
            FROM Opportunity
            WHERE Id = :recordId
            LIMIT 1
        ];

        List<Quote> quotes = [
            SELECT Id, Name, Status, QuoteNumber, GrandTotal, Subtotal, CreatedDate,
                   Voucher__c, Voucher__r.Voucher_Code__c, Voucher__r.Status__c,
                   Voucher__r.Voucher_Face_Value__c, Voucher_Credit_Amount__c
            FROM Quote
            WHERE OpportunityId = :recordId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Quote quoteRow = quotes.isEmpty() ? null : quotes[0];
        Id quoteId = quoteRow == null ? null : quoteRow.Id;

        List<QuoteLineItem> lineItems = quoteId == null
            ? new List<QuoteLineItem>()
            : [
                SELECT Id, Quantity, UnitPrice, TotalPrice, PricebookEntry.Product2.Name
                FROM QuoteLineItem
                WHERE QuoteId = :quoteId
                ORDER BY CreatedDate ASC
                LIMIT 20
            ];

        List<WorkOrder> workOrders = Schema.SObjectType.WorkOrder.fields.getMap().containsKey('Opportunity__c')
            ? Database.query('SELECT Id, WorkOrderNumber, Subject, Status FROM WorkOrder WHERE Opportunity__c = :recordId ORDER BY CreatedDate DESC LIMIT 5')
            : new List<WorkOrder>();

        List<Voucher__c> vouchers = [
            SELECT Id, Voucher_Code__c, Status__c, Voucher_Face_Value__c
            FROM Voucher__c
            WHERE Reserved_Opportunity__c = :recordId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Voucher__c voucherRow = quoteRow != null && quoteRow.Voucher__c != null
            ? quoteRow.Voucher__r
            : (vouchers.isEmpty() ? null : vouchers[0]);

        String quoteStatus = firstNonBlank(new List<String>{
            quoteRow == null ? null : quoteRow.Status,
            oppRow.Quote_Status__c,
            oppRow.StageName
        });
        Decimal quoteTotal = quoteRow == null ? oppRow.Amount : quoteRow.GrandTotal;
        Decimal voucherCredit = quoteRow != null && quoteRow.Voucher_Credit_Amount__c != null
            ? quoteRow.Voucher_Credit_Amount__c
            : (voucherRow == null ? 0 : voucherRow.Voucher_Face_Value__c);
        Decimal customerBalance = quoteRow == null ? safeDecimal(oppRow.Amount) : safeDecimal(quoteTotal) - safeDecimal(voucherCredit);
        Decimal depositDue = safeDecimal(oppRow.Deposit_Due__c);
        Decimal collectedTotal = oppRow.Deposit_Paid__c ? depositDue : 0;
        String contractStatus = firstNonBlank(new List<String>{
            oppRow.Contract_Status__c,
            oppRow.Contract == null ? null : oppRow.Contract.Status
        });
        Boolean quoteSent = quoteStatus == 'Sent' || quoteStatus == 'Presented' || quoteStatus == 'Approved' || quoteStatus == 'Accepted' || oppRow.StageName == 'Quote Sent';
        Boolean quoteAccepted = quoteStatus == 'Approved' || quoteStatus == 'Accepted';
        Boolean contractSent = String.isNotBlank(contractStatus) || oppRow.StageName == 'Contract Sent' || oppRow.StageName == 'Contract Signed' || oppRow.StageName == 'Deposit Paid';
        Boolean contractSigned = contractStatus == 'Activated' || contractStatus == 'Signed' || oppRow.StageName == 'Contract Signed' || oppRow.StageName == 'Deposit Paid';
        Boolean depositExists = oppRow.Deposit_Due__c != null;
        Boolean depositPaid = oppRow.Deposit_Paid__c == true;
        String workOrderStatus = workOrders.isEmpty() ? null : workOrders[0].Status;
        Boolean workOrderReleased = workOrderStatus == 'Released';
        String releaseState = readinessState(quoteAccepted, contractSigned, depositPaid, workOrderReleased);
        String releaseBlocker = readinessBlocker(quoteAccepted, contractSigned, depositExists, depositPaid, workOrderReleased);

        PageData page = newPage('Opportunity', 'Opportunity Close', oppRow.Name, 'Quote, contract, payment, and release context for the homeowner project.');
        page.badges.add(oppRow.StageName);
        if (!String.isBlank(oppRow.Type)) page.badges.add(oppRow.Type);
        page.actions.add(quoteRow == null ? disabledAction('View Quote', 'No quote exists.') : action('View Quote', 'viewQuote'));
        page.actions.add(oppRow.ContractId == null ? disabledAction('View Contract', 'No contract exists.') : action('View Contract', 'viewContract'));
        page.actions.add(disabledAction('Send Payment Link', 'Payment integration is not connected.'));

        page.sections.add(fieldSection('Quote Summary', new List<FieldItem>{
            linkField('Quote', quoteRow == null ? null : quoteRow.Name, quoteId, quoteStatus),
            field('Quote Name', quoteRow == null ? null : quoteRow.Name),
            field('Quote Number', quoteRow == null ? oppRow.Name : quoteRow.QuoteNumber),
            field('Status', quoteStatus),
            field('Expiration Date', null),
            linkField('Account', oppRow.Account != null ? oppRow.Account.Name : null, oppRow.AccountId, null),
            linkField('Opportunity', oppRow.Name, oppRow.Id, oppRow.Type)
        }, 'No quote has been created for this opportunity.'));

        page.sections.add(fieldSection('Opportunity / Project Path', new List<FieldItem>{
            field('Project Path', firstNonBlank(new List<String>{ oppRow.ODL_Path__c, oppRow.Type })),
            field('Opportunity Stage', oppRow.StageName),
            field('Owner', oppRow.Owner != null ? oppRow.Owner.Name : null),
            field('Contract Linked', oppRow.ContractId == null ? 'No' : 'Yes')
        }, 'No opportunity context is linked.'));

        page.sections.add(fieldSection('Package / Scope', new List<FieldItem>{
            field('Selected Package', firstNonBlank(new List<String>{ oppRow.BMG_Package__c, oppRow.Selected_Package__c })),
            field('Services', oppRow.Services_Selected__c),
            field('Requirements', oppRow.Selected_Requirements__c)
        }, 'No package or scope fields are populated.'));

        page.sections.add(fieldSection('Voucher Application', new List<FieldItem>{
            linkField('Voucher', voucherRow == null ? null : voucherRow.Voucher_Code__c, voucherRow == null ? null : voucherRow.Id, voucherRow == null ? null : voucherRow.Status__c),
            field('Voucher Credit Amount', voucherCredit),
            field('Voucher Face Value', voucherRow == null ? null : voucherRow.Voucher_Face_Value__c)
        }, 'No voucher is linked to this opportunity.'));

        List<RowData> lineRows = new List<RowData>();
        for (QuoteLineItem lineRow : lineItems) {
            RowData row = new RowData();
            row.id = lineRow.Id;
            row.label = lineRow.PricebookEntry != null && lineRow.PricebookEntry.Product2 != null ? lineRow.PricebookEntry.Product2.Name : 'Quote Line';
            row.url = '/' + lineRow.Id;
            row.status = 'Qty ' + String.valueOf(lineRow.Quantity);
            row.subtext = lineRow.UnitPrice == null ? null : 'Unit ' + String.valueOf(lineRow.UnitPrice);
            row.secondaryText = lineRow.TotalPrice == null ? null : 'Total ' + String.valueOf(lineRow.TotalPrice);
            lineRows.add(row);
        }
        page.sections.add(rowSection('Products / Quote Lines', lineRows, 'No scope lines on the quote.'));

        page.sections.add(fieldSection('Pricing Summary', new List<FieldItem>{
            field('Subtotal', quoteRow == null ? oppRow.Amount : quoteRow.Subtotal),
            field('Grand Total', quoteTotal),
            field('Voucher Credit Amount', voucherCredit),
            field('Customer Balance', customerBalance)
        }, 'No pricing fields are populated.'));

        page.sections.add(fieldSection('Contract / Signature', new List<FieldItem>{
            linkField('Contract', oppRow.Contract == null ? null : oppRow.Contract.ContractNumber, oppRow.ContractId, contractStatus),
            field('Contract Status', contractStatus),
            field('Contract Sent Date', oppRow.Contract == null ? null : oppRow.Contract.StartDate),
            field('Contract Activated / Signed Date', firstNonBlank(new List<String>{
                oppRow.Contract == null || oppRow.Contract.ActivatedDate == null ? null : String.valueOf(oppRow.Contract.ActivatedDate),
                oppRow.StageName == 'Contract Signed' || oppRow.StageName == 'Deposit Paid' ? String.valueOf(oppRow.CloseDate) : null
            })),
            field('Contract Owner', oppRow.Contract != null && oppRow.Contract.Owner != null ? oppRow.Contract.Owner.Name : null),
            field('Opportunity Stage', oppRow.StageName)
        }, 'No contract has been created yet.'));

        page.sections.add(rowSection('Payment Milestones', new List<RowData>(), 'No payment milestones have been created.'));

        page.sections.add(fieldSection('Work Order Release', new List<FieldItem>{
            field('Quote Sent', quoteSent),
            field('Quote Accepted', quoteAccepted),
            field('Contract Sent', contractSent),
            field('Contract Signed', contractSigned),
            field('Deposit Paid', depositPaid),
            field('Work Order Released', workOrderReleased),
            field('Release State', releaseState),
            field('Release Blocker', releaseBlocker),
            field('Work Order', workOrders.isEmpty() ? null : workOrders[0].WorkOrderNumber),
            field('Work Order Status', workOrderStatus)
        }, 'No work-order release context is available.'));

        page.sections.add(fieldSection('Financial Summary', new List<FieldItem>{
            field('Contract Total', quoteTotal),
            field('Voucher Credit', voucherCredit),
            field('Customer Balance', customerBalance),
            field('Deposit Due', depositDue),
            field('Collected', collectedTotal),
            field('Remaining', customerBalance - collectedTotal)
        }, 'No financial summary is available.'));

        page.sections.add(rowSection('Activity / Notes', activityRows(recordId), 'No Tasks or Events are logged on this opportunity.'));
        page.sections.add(rowSection('Files', fileRows(recordId), 'No files are linked to this opportunity.'));

        if (quoteRow == null) page.openItems.add('No quote has been created for this opportunity.');
        page.openItems.add('Payment integration is not connected. Send Payment Link is disabled.');
        if (!String.isBlank(releaseBlocker)) page.openItems.add(releaseBlocker);
        page.nextActions.add(nextCloseAction(quoteStatus, quoteAccepted, contractSent, contractSigned, depositExists, depositPaid, releaseState));
        page.healthItems.add(field('Quote Status', quoteStatus));
        page.healthItems.add(field('Opportunity Stage', oppRow.StageName));
        page.healthItems.add(field('Payment Milestones', 0));
        page.healthItems.add(field('Readiness', releaseState));
        return page;
    }

    private static PageData buildQuotePage(Id recordId) {
        Quote quoteRow = [
            SELECT Id, Name, Status, ExpirationDate, QuoteNumber, GrandTotal, Subtotal, AccountId, Account.Name,
                   OpportunityId, Opportunity.Name, Opportunity.Type, Opportunity.StageName, Opportunity.BMG_Package__c,
                   Opportunity.Services_Selected__c, Opportunity.Selected_Requirements__c, Opportunity.Amount,
                   Opportunity.Owner.Name, ContractId, Contract.ContractNumber, Contract.Status, Contract.StartDate,
                   Contract.ActivatedDate, Contract.Owner.Name, Voucher__c, Voucher__r.Voucher_Code__c,
                   Voucher__r.Status__c, Voucher__r.Voucher_Face_Value__c, Voucher_Credit_Amount__c
            FROM Quote
            WHERE Id = :recordId
            LIMIT 1
        ];
        List<QuoteLineItem> lineItems = [
            SELECT Id, Quantity, UnitPrice, TotalPrice, PricebookEntry.Product2.Name
            FROM QuoteLineItem
            WHERE QuoteId = :recordId
            ORDER BY CreatedDate ASC
            LIMIT 20
        ];
        List<Payment_Milestone__c> milestones = new List<Payment_Milestone__c>();
        List<WorkOrder> workOrders = quoteRow.OpportunityId == null
            ? new List<WorkOrder>()
            : [
                SELECT Id, WorkOrderNumber, Subject, Status
                FROM WorkOrder
                WHERE Opportunity__c = :quoteRow.OpportunityId
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];

        PageData page = newPage('Quote', 'Quote', quoteRow.Name, 'Quote, payment, and release context for the homeowner project.');
        page.badges.add(quoteRow.Status);
        if (quoteRow.Opportunity != null && !String.isBlank(quoteRow.Opportunity.Type)) page.badges.add(quoteRow.Opportunity.Type);
        page.actions.add(action('View Quote', 'viewQuote'));
        page.actions.add(quoteRow.ContractId == null ? disabledAction('View Contract', 'No contract exists.') : action('View Contract', 'viewContract'));
        page.actions.add(disabledAction('Send Payment Link', 'Payment integration is not connected.'));

        page.sections.add(fieldSection('Quote Summary', new List<FieldItem>{
            field('Quote Name', quoteRow.Name),
            field('Quote Number', quoteRow.QuoteNumber),
            field('Status', quoteRow.Status),
            field('Expiration Date', quoteRow.ExpirationDate),
            linkField('Account', quoteRow.Account != null ? quoteRow.Account.Name : null, quoteRow.AccountId, null),
            linkField('Opportunity', quoteRow.Opportunity != null ? quoteRow.Opportunity.Name : null, quoteRow.OpportunityId, quoteRow.Opportunity != null ? quoteRow.Opportunity.Type : null)
        }, 'No quote summary.'));

        page.sections.add(fieldSection('Opportunity / Project Path', new List<FieldItem>{
            field('Project Path', quoteRow.Opportunity != null ? quoteRow.Opportunity.Type : null),
            field('Opportunity Stage', quoteRow.Opportunity != null ? quoteRow.Opportunity.StageName : null),
            field('Owner', quoteRow.Opportunity != null && quoteRow.Opportunity.Owner != null ? quoteRow.Opportunity.Owner.Name : null),
            field('Contract Linked', quoteRow.ContractId == null ? 'No' : 'Yes')
        }, 'No opportunity context is linked.'));

        page.sections.add(fieldSection('Package / Scope', new List<FieldItem>{
            field('Selected Package', quoteRow.Opportunity != null ? quoteRow.Opportunity.BMG_Package__c : null),
            field('Services', quoteRow.Opportunity != null ? quoteRow.Opportunity.Services_Selected__c : null),
            field('Requirements', quoteRow.Opportunity != null ? quoteRow.Opportunity.Selected_Requirements__c : null)
        }, 'No package or scope fields are populated.'));

        page.sections.add(fieldSection('Voucher Application', new List<FieldItem>{
            linkField('Voucher', quoteRow.Voucher__r != null ? quoteRow.Voucher__r.Voucher_Code__c : null, (Id) quoteRow.get('Voucher__c'), quoteRow.Voucher__r != null ? quoteRow.Voucher__r.Status__c : null),
            field('Voucher Credit Amount', quoteRow.Voucher_Credit_Amount__c),
            field('Voucher Face Value', quoteRow.Voucher__r != null ? quoteRow.Voucher__r.Voucher_Face_Value__c : null)
        }, 'No voucher is linked to this quote.'));

        List<RowData> lineRows = new List<RowData>();
        for (QuoteLineItem lineRow : lineItems) {
            RowData row = new RowData();
            row.id = lineRow.Id;
            row.label = lineRow.PricebookEntry != null && lineRow.PricebookEntry.Product2 != null ? lineRow.PricebookEntry.Product2.Name : 'Quote Line';
            row.url = '/' + lineRow.Id;
            row.status = 'Qty ' + String.valueOf(lineRow.Quantity);
            row.subtext = lineRow.UnitPrice == null ? null : 'Unit ' + String.valueOf(lineRow.UnitPrice);
            row.secondaryText = lineRow.TotalPrice == null ? null : 'Total ' + String.valueOf(lineRow.TotalPrice);
            lineRows.add(row);
        }
        page.sections.add(rowSection('Products / Quote Lines', lineRows, 'No quote lines are present.'));

        page.sections.add(fieldSection('Pricing Summary', new List<FieldItem>{
            field('Subtotal', quoteRow.Subtotal),
            field('Grand Total', quoteRow.GrandTotal),
            field('Voucher Credit Amount', quoteRow.Voucher_Credit_Amount__c),
            field('Customer Balance', safeDecimal(quoteRow.GrandTotal) - safeDecimal(quoteRow.Voucher_Credit_Amount__c))
        }, 'No pricing fields are populated.'));

        page.sections.add(fieldSection('Contract / Signature', new List<FieldItem>{
            linkField('Contract', quoteRow.Contract == null ? null : quoteRow.Contract.ContractNumber, quoteRow.ContractId, quoteRow.Contract == null ? null : quoteRow.Contract.Status),
            field('Contract Status', quoteRow.Contract == null ? null : quoteRow.Contract.Status),
            field('Contract Sent Date', quoteRow.Contract == null ? null : quoteRow.Contract.StartDate),
            field('Contract Activated / Signed Date', quoteRow.Contract == null ? null : quoteRow.Contract.ActivatedDate),
            field('Contract Owner', quoteRow.Contract != null && quoteRow.Contract.Owner != null ? quoteRow.Contract.Owner.Name : null),
            field('Opportunity Stage', quoteRow.Opportunity != null ? quoteRow.Opportunity.StageName : null)
        }, 'No contract has been created yet.'));

        List<RowData> milestoneRows = new List<RowData>();
        Boolean depositPaid = false;
        Boolean depositExists = false;
        Decimal collectedTotal = 0;
        Decimal depositAmount = 0;
        for (Payment_Milestone__c milestoneRow : milestones) {
            milestoneRows.add(makeLinkRow(milestoneRow.Id, milestoneRow.Name, null, null, null));
        }
        page.sections.add(rowSection('Payment Milestones', milestoneRows, 'No payment milestones have been created.'));

        Decimal customerBalance = safeDecimal(quoteRow.GrandTotal) - safeDecimal(quoteRow.Voucher_Credit_Amount__c);
        String contractStatus = quoteRow.Contract == null ? null : quoteRow.Contract.Status;
        Boolean quoteSent = quoteRow.Status == 'Sent' || quoteRow.Status == 'Presented' || quoteRow.Status == 'Accepted';
        Boolean quoteAccepted = quoteRow.Status == 'Accepted';
        Boolean contractSent = String.isNotBlank(contractStatus);
        Boolean contractSigned = contractStatus == 'Activated' || contractStatus == 'Signed';
        String workOrderStatus = workOrders.isEmpty() ? null : workOrders[0].Status;
        Boolean workOrderReleased = workOrderStatus == 'Released';
        String releaseState = readinessState(quoteAccepted, contractSigned, depositPaid, workOrderReleased);
        String releaseBlocker = readinessBlocker(quoteAccepted, contractSigned, depositExists, depositPaid, workOrderReleased);
        page.sections.add(fieldSection('Work Order Release', new List<FieldItem>{
            field('Quote Sent', quoteSent),
            field('Quote Accepted', quoteAccepted),
            field('Contract Sent', contractSent),
            field('Contract Signed', contractSigned),
            field('Deposit Paid', depositPaid),
            field('Work Order Released', workOrderReleased),
            field('Release State', releaseState),
            field('Release Blocker', releaseBlocker),
            field('Work Order', workOrders.isEmpty() ? null : workOrders[0].WorkOrderNumber),
            field('Work Order Status', workOrderStatus)
        }, 'No work-order release context is available.'));
        page.sections.add(fieldSection('Financial Summary', new List<FieldItem>{
            field('Contract Total', quoteRow.GrandTotal),
            field('Voucher Credit', quoteRow.Voucher_Credit_Amount__c),
            field('Customer Balance', customerBalance),
            field('Deposit Due', depositAmount),
            field('Collected', collectedTotal),
            field('Remaining', customerBalance - collectedTotal)
        }, 'No financial summary is available.'));

        page.sections.add(rowSection('Activity / Notes', activityRows(recordId), 'No Tasks or Events are logged on this quote.'));
        page.sections.add(rowSection('Files', fileRows(recordId), 'No files are linked to this quote.'));

        if (milestones.isEmpty()) page.openItems.add('No payment milestones have been created.');
        if (!String.isBlank(releaseBlocker)) page.openItems.add(releaseBlocker);
        page.nextActions.add(nextCloseAction(quoteRow.Status, quoteAccepted, contractSent, contractSigned, depositExists, depositPaid, releaseState));
        page.healthItems.add(field('Quote Status', quoteRow.Status));
        page.healthItems.add(field('Opportunity Stage', quoteRow.Opportunity != null ? quoteRow.Opportunity.StageName : null));
        page.healthItems.add(field('Payment Milestones', milestones.size()));
        page.healthItems.add(field('Readiness', releaseState));
        return page;
    }

    private static Decimal safeDecimal(Decimal value) {
        return value == null ? 0 : value;
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (!String.isBlank(value)) return value;
        }
        return null;
    }

    private static String readinessState(Boolean quoteAccepted, Boolean contractSigned, Boolean depositPaid, Boolean workOrderReleased) {
        if (workOrderReleased) return 'Released';
        if (quoteAccepted && contractSigned && depositPaid) return 'Ready';
        if (quoteAccepted || contractSigned) return 'Blocked';
        return 'Not Ready';
    }

    private static String readinessBlocker(Boolean quoteAccepted, Boolean contractSigned, Boolean depositExists, Boolean depositPaid, Boolean workOrderReleased) {
        if (workOrderReleased) return null;
        if (!quoteAccepted) return 'Blocked until the quote is accepted.';
        if (!contractSigned) return 'Blocked until the contract is signed.';
        if (!depositExists) return 'Blocked until a deposit milestone is created.';
        if (!depositPaid) return 'Blocked until the deposit is paid.';
        return null;
    }

    private static String nextCloseAction(String quoteStatus, Boolean quoteAccepted, Boolean contractSent, Boolean contractSigned, Boolean depositExists, Boolean depositPaid, String readinessState) {
        if (readinessState == 'Ready') return 'Release work order';
        if (contractSigned && depositExists && !depositPaid) return 'Collect the deposit';
        if (contractSent && !contractSigned) return 'Get the contract signed';
        if (quoteAccepted && !contractSent) return 'Send the contract';
        if (quoteStatus == 'Sent' || quoteStatus == 'Presented') return 'Follow up on the quote';
        if (quoteStatus == 'Draft') return 'Finalize and send the quote';
        return 'Review the close';
    }

    private static PageData buildWorkOrderPage(Id recordId) {
        Boolean hasOpportunityField = Schema.SObjectType.WorkOrder.fields.getMap().containsKey('Opportunity__c');
        String soql =
            'SELECT Id, WorkOrderNumber, Subject, Status, AccountId, Account.Name, ContactId, Contact.Name, ' +
            'Community__c, Community__r.Name, Lot_Number__c, Field_Manager__c, Field_Manager__r.Name, ' +
            'Scheduled_Date__c, Work_Order_Type__c, Division__c, Job_Type__c, Job_Description__c, Red_Flag_Notes__c';
        if (hasOpportunityField) {
            soql += ', Opportunity__c';
            soql += ', Opportunity__r.Name, Opportunity__r.Type, Opportunity__r.StageName';
        }
        soql += ' FROM WorkOrder WHERE Id = :recordId LIMIT 1';
        WorkOrder workOrderRow = (WorkOrder) Database.query(soql);
        SObject relatedOpportunity = hasOpportunityField ? workOrderRow.getSObject('Opportunity__r') : null;
        List<Voucher__c> relatedVouchers = new List<Voucher__c>();
        if (hasOpportunityField && (Id) workOrderRow.get('Opportunity__c') != null) {
            relatedVouchers = [
                SELECT Id, Voucher_Code__c, Status__c
                FROM Voucher__c
                WHERE Reserved_Opportunity__c = :(Id) workOrderRow.get('Opportunity__c')
                ORDER BY CreatedDate DESC
                LIMIT :ROW_LIMIT
            ];
        }

        List<ServiceAppointment> appointments = [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, ParentRecordId
            FROM ServiceAppointment
            WHERE ParentRecordId = :recordId
            ORDER BY SchedStartTime ASC
            LIMIT 20
        ];

        List<RowData> appointmentRows = new List<RowData>();
        for (ServiceAppointment appt : appointments) {
            appointmentRows.add(makeLinkRow(appt.Id, appt.AppointmentNumber, appt.Status, 'Service Appointment', appt.SchedStartTime == null ? null : appt.SchedStartTime.format('M/d/yyyy h:mm a')));
        }

        List<RowData> relatedChangeOrders = new List<RowData>();
        if (hasOpportunityField && workOrderRow.get('Opportunity__c') != null) {
            for (Change_Order__c changeRow : [
                SELECT Id, Name
                FROM Change_Order__c
                WHERE Opportunity__c = :(Id) workOrderRow.get('Opportunity__c')
                ORDER BY CreatedDate DESC
                LIMIT :ROW_LIMIT
            ]) {
                relatedChangeOrders.add(makeLinkRow(changeRow.Id, changeRow.Name, 'Change Order', null, null));
            }
        }

        List<RowData> warrantyRows = new List<RowData>();
        for (Warranty_Record__c warrantyRow : [
            SELECT Id, Name, Status__c
            FROM Warranty_Record__c
            WHERE WorkOrder__c = :recordId
            ORDER BY CreatedDate DESC
            LIMIT :ROW_LIMIT
        ]) {
            warrantyRows.add(makeLinkRow(warrantyRow.Id, warrantyRow.Name, warrantyRow.Status__c, 'Warranty Record', null));
        }

        PageData page = newPage('WorkOrder', 'Work Order', workOrderRow.WorkOrderNumber, 'Field execution, schedule, and closeout context for Outdoor Living work.');
        page.badges.add(workOrderRow.Status);
        if (!String.isBlank(workOrderRow.Work_Order_Type__c)) page.badges.add(workOrderRow.Work_Order_Type__c);
        page.actions.add(action('Edit Work Order', 'edit'));
        page.actions.add(action('New Task', 'newTask'));

        page.sections.add(fieldSection('Work Order Summary', new List<FieldItem>{
            field('Work Order Number', workOrderRow.WorkOrderNumber),
            field('Subject', workOrderRow.Subject),
            field('Status', workOrderRow.Status),
            field('Work Type', workOrderRow.Work_Order_Type__c),
            field('Job Type', workOrderRow.Job_Type__c),
            field('Division', workOrderRow.Division__c)
        }, 'No work order summary.'));

        page.sections.add(fieldSection('Homeowner / Property', new List<FieldItem>{
            linkField('Account', workOrderRow.Account != null ? workOrderRow.Account.Name : null, workOrderRow.AccountId, null),
            linkField('Contact', workOrderRow.Contact != null ? workOrderRow.Contact.Name : null, workOrderRow.ContactId, null),
            linkField('Community', safeName(workOrderRow, 'Community__r'), (Id) workOrderRow.get('Community__c'), null),
            field('Lot', workOrderRow.Lot_Number__c)
        }, 'No homeowner or property context is linked.'));

        page.sections.add(fieldSection('Opportunity Context', new List<FieldItem>{
            linkField('Opportunity', relatedOpportunity != null ? String.valueOf(relatedOpportunity.get('Name')) : null, hasOpportunityField ? (Id) workOrderRow.get('Opportunity__c') : null, relatedOpportunity != null ? String.valueOf(relatedOpportunity.get('StageName')) : null),
            field('Opportunity Type', relatedOpportunity != null ? String.valueOf(relatedOpportunity.get('Type')) : null)
        }, 'No opportunity context is linked.'));

        page.sections.add(fieldSection('Execution Details', new List<FieldItem>{
            field('Scheduled Date', workOrderRow.Scheduled_Date__c),
            field('Field Manager', safeName(workOrderRow, 'Field_Manager__r')),
            field('Job Description', workOrderRow.Job_Description__c),
            field('Red Flag Notes', workOrderRow.Red_Flag_Notes__c)
        }, 'No execution details are populated.'));

        page.sections.add(fieldSection('Work Type / Territory', new List<FieldItem>{
            field('Work Type', workOrderRow.Work_Order_Type__c),
            field('Job Type', workOrderRow.Job_Type__c),
            field('Division', workOrderRow.Division__c),
            field('Field Manager', safeName(workOrderRow, 'Field_Manager__r'))
        }, 'No work type fields are populated.'));

        page.sections.add(fieldSection('Offer Context', new List<FieldItem>{
            field('Voucher Count', relatedVouchers.size()),
            field('Latest Voucher Status', relatedVouchers.isEmpty() ? null : relatedVouchers[0].Status__c)
        }, 'No voucher-backed offer is linked to this work order opportunity.'));

        page.sections.add(rowSection('Related Service Appointments', appointmentRows, 'No Service Appointments are linked.'));
        page.sections.add(rowSection('Change Orders', relatedChangeOrders, 'No Change Orders are linked through this work order opportunity context.'));
        page.sections.add(rowSection('Closeout / Warranty Handoff', warrantyRows, 'No Warranty Record is linked to this Work Order.'));
        page.sections.add(rowSection('Activity / Notes', activityRows(recordId), 'No Tasks or Events are logged on this Work Order.'));
        page.sections.add(rowSection('Files / Photos', fileRows(recordId), 'No files are linked to this Work Order.'));

        if (workOrderRow.ContactId == null) page.openItems.add('Homeowner Contact is blank on this Work Order.');
        if (workOrderRow.Scheduled_Date__c == null) page.openItems.add('Scheduled Date is blank on this Work Order.');
        if (appointments.isEmpty()) page.openItems.add('No Service Appointments are linked to this Work Order.');
        page.nextActions.add(appointments.isEmpty() ? 'Schedule or link Service Appointments.' : 'Review service appointment timing and field readiness.');
        page.healthItems.add(field('Work Order Status', workOrderRow.Status));
        page.healthItems.add(field('Scheduled Date', workOrderRow.Scheduled_Date__c));
        page.healthItems.add(field('Service Appointments', appointments.size()));
        return page;
    }

    private static PageData buildDesignReviewPage(Id recordId) {
        Design_Review__c reviewRow = [
            SELECT Id, Name, Status__c, Opportunity__c, Opportunity__r.Name, Opportunity__r.Type, Opportunity__r.StageName,
                   Opportunity__r.Budget__c, Opportunity__r.Timeline__c, Opportunity__r.BMG_Package__c,
                   Opportunity__r.Services_Selected__c, Opportunity__r.Selected_Requirements__c, Opportunity__r.Design_Link__c,
                   Opportunity__r.AccountId, Opportunity__r.Account.Name
            FROM Design_Review__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        Homeowner_Property__c propertyRow;
        List<Homeowner_Property__c> properties = [
            SELECT Id, Name, Community__r.Name, Lot__r.Name
            FROM Homeowner_Property__c
            WHERE Opportunity__c = :reviewRow.Opportunity__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!properties.isEmpty()) propertyRow = properties[0];
        List<Quote> quotes = reviewRow.Opportunity__c == null ? new List<Quote>() : [
            SELECT Id, Name, Status
            FROM Quote
            WHERE OpportunityId = :reviewRow.Opportunity__c
            ORDER BY CreatedDate DESC
            LIMIT :ROW_LIMIT
        ];
        PageData page = newPage('Design_Review__c', 'Design Review', reviewRow.Name, 'Package review and quote context for the homeowner project.');
        if (!String.isBlank(reviewRow.Status__c)) page.badges.add(reviewRow.Status__c);
        if (reviewRow.Opportunity__r != null && !String.isBlank((String) reviewRow.Opportunity__r.get('Type'))) page.badges.add((String) reviewRow.Opportunity__r.get('Type'));
        page.actions.add(action('Edit Design Review', 'edit'));
        page.actions.add(action('New Task', 'newTask'));

        page.sections.add(fieldSection('Design Review Summary', new List<FieldItem>{
            field('Design Review Number', reviewRow.Name),
            field('Status', reviewRow.Status__c),
            linkField('Opportunity', reviewRow.Opportunity__r != null ? reviewRow.Opportunity__r.Name : null, reviewRow.Opportunity__c, reviewRow.Opportunity__r != null ? (String) reviewRow.Opportunity__r.get('Type') : null),
            linkField('Customer', reviewRow.Opportunity__r != null && (Id) reviewRow.Opportunity__r.get('AccountId') != null ? (String) reviewRow.Opportunity__r.getSObject('Account').get('Name') : null, reviewRow.Opportunity__r == null ? null : (Id) reviewRow.Opportunity__r.get('AccountId'), null)
        }, 'No design review summary.'));

        page.sections.add(fieldSection('Customer / Property', new List<FieldItem>{
            linkField('Homeowner Property', propertyRow != null ? propertyRow.Name : null, propertyRow == null ? null : propertyRow.Id, propertyRow != null && propertyRow.Community__r != null ? propertyRow.Community__r.Name : null),
            field('Community', propertyRow != null && propertyRow.Community__r != null ? propertyRow.Community__r.Name : null),
            field('Lot', propertyRow != null && propertyRow.Lot__r != null ? propertyRow.Lot__r.Name : null)
        }, 'No Homeowner Property is linked to this design review.'));

        page.sections.add(fieldSection('Desired Features / Budget / Timeline', new List<FieldItem>{
            field('Desired Features', reviewRow.Opportunity__r != null ? (String) reviewRow.Opportunity__r.get('Services_Selected__c') : null),
            field('Requirements', reviewRow.Opportunity__r != null ? (String) reviewRow.Opportunity__r.get('Selected_Requirements__c') : null),
            field('Budget', reviewRow.Opportunity__r != null ? reviewRow.Opportunity__r.get('Budget__c') : null),
            field('Timeline', reviewRow.Opportunity__r != null ? reviewRow.Opportunity__r.get('Timeline__c') : null)
        }, 'No design input fields are populated.'));

        page.sections.add(fieldSection('Package Selection', new List<FieldItem>{
            field('Selected Package', reviewRow.Opportunity__r != null ? (String) reviewRow.Opportunity__r.get('BMG_Package__c') : null),
            field('Design Review Status', reviewRow.Status__c)
        }, 'No package selection fields are populated.'));

        page.sections.add(fieldSection('Portal / Design Link', new List<FieldItem>{
            field('Portal / Design Link', reviewRow.Opportunity__r != null ? (String) reviewRow.Opportunity__r.get('Design_Link__c') : null)
        }, 'No portal or design link is populated.'));

        page.sections.add(fieldSection('Consult Status', new List<FieldItem>{
            field('Consult Status', reviewRow.Opportunity__r != null ? (String) reviewRow.Opportunity__r.get('StageName') : null)
        }, 'No consult status is populated.'));

        page.sections.add(fieldSection('Quote Generation', new List<FieldItem>{
            field('QA Review Status', reviewRow.Status__c),
            field('Quote Count', quotes.size())
        }, 'No QA or portal data is populated.'));

        List<RowData> quoteRows = new List<RowData>();
        for (Quote quoteRow : quotes) quoteRows.add(makeLinkRow(quoteRow.Id, quoteRow.Name, quoteRow.Status, 'Quote', null));
        page.sections.add(rowSection('Related Quotes', quoteRows, 'No Quote is linked to this design review opportunity.'));

        if (String.isBlank(reviewRow.Status__c)) page.openItems.add('Design Review status is blank.');
        if (reviewRow.Opportunity__r == null || String.isBlank((String) reviewRow.Opportunity__r.get('BMG_Package__c'))) page.openItems.add('Selected package is missing, so quote generation should remain blocked.');
        if (String.isBlank(reviewRow.Opportunity__r == null ? null : (String) reviewRow.Opportunity__r.get('Design_Link__c'))) page.openItems.add('Portal / design link is blank.');
        page.nextActions.add(String.isBlank(reviewRow.Status__c) ? 'Assign a Design Review status before using this page operationally.' : 'Review QA status and package selection before generating quotes.');
        page.healthItems.add(field('Design Review Status', reviewRow.Status__c));
        page.healthItems.add(field('Quote Count', quotes.size()));
        page.healthItems.add(field('Package', reviewRow.Opportunity__r != null ? (String) reviewRow.Opportunity__r.get('BMG_Package__c') : null));
        return page;
    }

    private static PageData buildHomeownerPropertyPage(Id recordId) {
        Homeowner_Property__c propertyRow = [
            SELECT Id, Name, Homeowner_Account__c, Homeowner_Account__r.Name, Opportunity__c, Opportunity__r.Name, Opportunity__r.Type,
                   Community__c, Community__r.Name, Lot__c, Lot__r.Name
            FROM Homeowner_Property__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        Id propertyOpportunityId = propertyRow.Opportunity__c;
        List<Design_Review__c> reviews = propertyRow.Opportunity__c == null ? new List<Design_Review__c>() : [
            SELECT Id, Name, Status__c
            FROM Design_Review__c
            WHERE Opportunity__c = :propertyRow.Opportunity__c
            ORDER BY CreatedDate DESC
            LIMIT :ROW_LIMIT
        ];
        List<WorkOrder> workOrders = propertyOpportunityId == null || !Schema.SObjectType.WorkOrder.fields.getMap().containsKey('Opportunity__c') ? new List<WorkOrder>() : Database.query(
            'SELECT Id, WorkOrderNumber, Status, Scheduled_Date__c FROM WorkOrder WHERE Opportunity__c = :propertyOpportunityId ORDER BY CreatedDate DESC LIMIT :ROW_LIMIT'
        );
        List<ServiceAppointment> appointments = new List<ServiceAppointment>();
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : workOrders) woIds.add(wo.Id);
        if (!woIds.isEmpty()) {
            appointments = [
                SELECT Id, AppointmentNumber, Status, SchedStartTime
                FROM ServiceAppointment
                WHERE ParentRecordId IN :woIds
                ORDER BY SchedStartTime ASC
                LIMIT :ROW_LIMIT
            ];
        }

        PageData page = newPage('Homeowner_Property__c', 'Homeowner Property', propertyRow.Name, 'Property anchor for homeowner opportunity, work, and appointment context.');
        if (propertyRow.Opportunity__r != null && !String.isBlank((String) propertyRow.Opportunity__r.get('Type'))) page.badges.add((String) propertyRow.Opportunity__r.get('Type'));
        page.actions.add(action('Edit Property', 'edit'));
        page.actions.add(action('New Task', 'newTask'));

        page.sections.add(fieldSection('Property Summary', new List<FieldItem>{
            field('Property Name', propertyRow.Name),
            linkField('Homeowner Account', safeName(propertyRow, 'Homeowner_Account__r'), propertyRow.Homeowner_Account__c, null),
            linkField('Opportunity', propertyRow.Opportunity__r != null ? propertyRow.Opportunity__r.Name : null, propertyRow.Opportunity__c, propertyRow.Opportunity__r != null ? (String) propertyRow.Opportunity__r.get('Type') : null)
        }, 'No property summary data.'));

        page.sections.add(fieldSection('Community / Lot', new List<FieldItem>{
            field('Community', propertyRow.Community__r != null ? propertyRow.Community__r.Name : null),
            field('Lot', propertyRow.Lot__r != null ? propertyRow.Lot__r.Name : null)
        }, 'No community or lot fields are linked.'));

        List<RowData> reviewRows = new List<RowData>();
        for (Design_Review__c reviewRow : reviews) reviewRows.add(makeLinkRow(reviewRow.Id, reviewRow.Name, reviewRow.Status__c, 'Design Review', null));
        page.sections.add(rowSection('Related Design Reviews', reviewRows, 'No Design Reviews are linked.'));

        List<RowData> opportunityRows = new List<RowData>();
        if (propertyRow.Opportunity__c != null) opportunityRows.add(makeLinkRow(propertyRow.Opportunity__c, propertyRow.Opportunity__r.Name, propertyRow.Opportunity__r.Type, 'Opportunity', null));
        page.sections.add(rowSection('Related Opportunities', opportunityRows, 'No Opportunity is linked.'));

        List<RowData> workOrderRows = new List<RowData>();
        for (WorkOrder wo : workOrders) workOrderRows.add(makeLinkRow(wo.Id, wo.WorkOrderNumber, wo.Status, 'Work Order', wo.get('Scheduled_Date__c') == null ? null : String.valueOf((Date) wo.get('Scheduled_Date__c'))));
        page.sections.add(rowSection('Related Work Orders', workOrderRows, 'No Work Orders are linked.'));

        List<RowData> appointmentRows = new List<RowData>();
        for (ServiceAppointment appt : appointments) appointmentRows.add(makeLinkRow(appt.Id, appt.AppointmentNumber, appt.Status, 'Service Appointment', appt.SchedStartTime == null ? null : appt.SchedStartTime.format('M/d/yyyy h:mm a')));
        page.sections.add(rowSection('Related Service Appointments', appointmentRows, 'No Service Appointments are linked.'));

        page.sections.add(rowSection('Files / Photos', fileRows(recordId), 'No files are linked to this Homeowner Property record.'));

        if (propertyRow.Opportunity__c == null) page.openItems.add('Homeowner Property is not linked to an opportunity.');
        page.nextActions.add(propertyRow.Opportunity__c == null ? 'Link the homeowner property to the active opportunity.' : 'Review property readiness and linked work orders.');
        page.healthItems.add(field('Design Reviews', reviews.size()));
        page.healthItems.add(field('Work Orders', workOrders.size()));
        page.healthItems.add(field('Appointments', appointments.size()));
        return page;
    }

    private static PageData buildPaymentMilestonePage(Id recordId) {
        Payment_Milestone__c milestoneRow = [
            SELECT Id, Name, CreatedDate, LastModifiedDate, Owner.Name
            FROM Payment_Milestone__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        PageData page = newPage('Payment_Milestone__c', 'Payment Milestone', milestoneRow.Name, 'Deposit and payment tracking for the homeowner project.');
        page.badges.add('Schema incomplete');
        page.actions.add(action('Edit Payment Milestone', 'edit'));
        page.actions.add(action('New Task', 'newTask'));

        page.sections.add(fieldSection('Milestone Summary', new List<FieldItem>{
            field('Payment Milestone Number', milestoneRow.Name),
            field('Owner', milestoneRow.Owner != null ? milestoneRow.Owner.Name : null),
            field('Created Date', milestoneRow.CreatedDate),
            field('Last Modified Date', milestoneRow.LastModifiedDate)
        }, 'No milestone summary.'));

        page.sections.add(fieldSection('Opportunity / Quote / Contract', new List<FieldItem>{
            field('Required Field', 'Payment_Milestone__c.Opportunity__c'),
            field('Required Field', 'Payment_Milestone__c.Type__c'),
            field('Required Field', 'Payment_Milestone__c.Status__c'),
            field('Required Field', 'Payment_Milestone__c.Amount__c'),
            field('Required Field', 'Payment_Milestone__c.Due_Date__c')
        }, 'Payment milestone close fields are not deployed in production.'));

        page.sections.add(rowSection('Activity / Notes', activityRows(recordId), 'No Tasks or Events are logged on this payment milestone.'));

        page.openItems.add('Payment milestone close fields are not deployed in production. Do not use this record as payment proof yet.');
        page.nextActions.add('Deploy the payment milestone close fields before using milestones for deposit readiness.');
        page.healthItems.add(field('Schema Status', 'Incomplete'));
        return page;
    }

    private static PageData buildChangeOrderPage(Id recordId) {
        Change_Order__c changeRow = [
            SELECT Id, Name, Opportunity__c, Opportunity__r.Name, Opportunity__r.Type, Opportunity__r.StageName,
                   Voucher__c, Voucher__r.Voucher_Code__c
            FROM Change_Order__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        PageData page = newPage('Change_Order__c', 'Change Order', changeRow.Name, 'Scope-control page for work that should not proceed without explicit change-order approval.');
        page.actions.add(action('Edit Change Order', 'edit'));
        page.actions.add(action('New Task', 'newTask'));

        page.sections.add(fieldSection('Change Order Summary', new List<FieldItem>{
            field('Change Order Number', changeRow.Name),
            linkField('Opportunity', changeRow.Opportunity__r != null ? changeRow.Opportunity__r.Name : null, changeRow.Opportunity__c, changeRow.Opportunity__r != null ? changeRow.Opportunity__r.Type : null),
            linkField('Voucher', changeRow.Voucher__r != null ? changeRow.Voucher__r.Voucher_Code__c : null, changeRow.Voucher__c, null)
        }, 'No Change Order summary.'));

        page.sections.add(rowSection('Files / Photos', fileRows(recordId), 'No files are linked to this Change Order.'));

        page.healthItems.add(field('Opportunity Linked', changeRow.Opportunity__c != null));
        return page;
    }

    private static PageData buildWarrantyRecordPage(Id recordId) {
        Warranty_Record__c warrantyRow = [
            SELECT Id, Name, Status__c, Homeowner_Account__c, Homeowner_Account__r.Name,
                   WorkOrder__c, WorkOrder__r.WorkOrderNumber, Case__c, Case__r.CaseNumber, Case__r.Status
            FROM Warranty_Record__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        PageData page = newPage('Warranty_Record__c', 'Warranty Record', warrantyRow.Name, 'Warranty coverage anchor across homeowner, case, and field follow-up.');
        if (!String.isBlank(warrantyRow.Status__c)) page.badges.add(warrantyRow.Status__c);
        page.actions.add(action('Edit Warranty Record', 'edit'));
        page.actions.add(action('New Task', 'newTask'));

        page.sections.add(fieldSection('Warranty Summary', new List<FieldItem>{
            field('Warranty Record Number', warrantyRow.Name),
            field('Status', warrantyRow.Status__c),
            linkField('Homeowner Account', safeName(warrantyRow, 'Homeowner_Account__r'), warrantyRow.Homeowner_Account__c, null),
            linkField('Work Order', warrantyRow.WorkOrder__r != null ? warrantyRow.WorkOrder__r.WorkOrderNumber : null, warrantyRow.WorkOrder__c, null),
            linkField('Case', warrantyRow.Case__r != null ? warrantyRow.Case__r.CaseNumber : null, warrantyRow.Case__c, warrantyRow.Case__r != null ? warrantyRow.Case__r.Status : null)
        }, 'No warranty record summary.'));

        page.sections.add(rowSection('Activity / Notes', activityRows(recordId), 'No Tasks or Events are logged on this Warranty Record.'));
        page.sections.add(rowSection('Files', fileRows(recordId), 'No files are linked to this Warranty Record.'));

        if (warrantyRow.Case__c == null) page.openItems.add('No Case is linked to this Warranty Record.');
        if (warrantyRow.WorkOrder__c == null) page.openItems.add('No Work Order is linked to this Warranty Record.');
        page.healthItems.add(field('Warranty Status', warrantyRow.Status__c));
        page.healthItems.add(field('Linked Case', warrantyRow.Case__c != null));
        page.healthItems.add(field('Linked Work Order', warrantyRow.WorkOrder__c != null));
        return page;
    }

    private static PageData buildWarrantyCasePage(Id recordId) {
        Case caseRow = [
            SELECT Id, CaseNumber, Subject, Status, Priority, Type, AccountId, Account.Name, ContactId, Contact.Name, Owner.Name
            FROM Case
            WHERE Id = :recordId
            LIMIT 1
        ];
        List<Warranty_Record__c> warrantyRecords = [
            SELECT Id, Name, Status__c, WorkOrder__c, WorkOrder__r.WorkOrderNumber
            FROM Warranty_Record__c
            WHERE Case__c = :recordId
            ORDER BY CreatedDate DESC
            LIMIT :ROW_LIMIT
        ];
        Set<Id> workOrderIds = new Set<Id>();
        for (Warranty_Record__c warrantyRow : warrantyRecords) if (warrantyRow.WorkOrder__c != null) workOrderIds.add(warrantyRow.WorkOrder__c);
        List<ServiceAppointment> appointments = workOrderIds.isEmpty() ? new List<ServiceAppointment>() : [
            SELECT Id, AppointmentNumber, Status, SchedStartTime
            FROM ServiceAppointment
            WHERE ParentRecordId IN :workOrderIds
            ORDER BY SchedStartTime ASC
            LIMIT :ROW_LIMIT
        ];

        PageData page = newPage('Case', 'Warranty Case', caseRow.CaseNumber, 'Post-project warranty and support view across case, warranty record, and field follow-up.');
        if (!String.isBlank(caseRow.Status)) page.badges.add(caseRow.Status);
        if (!String.isBlank(caseRow.Type)) page.badges.add(caseRow.Type);
        page.actions.add(action('Edit Case', 'edit'));
        page.actions.add(action('New Task', 'newTask'));

        page.sections.add(fieldSection('Warranty Case Summary', new List<FieldItem>{
            field('Case Number', caseRow.CaseNumber),
            field('Subject', caseRow.Subject),
            field('Status', caseRow.Status),
            field('Priority', caseRow.Priority),
            field('Case Type', caseRow.Type),
            linkField('Account', caseRow.Account != null ? caseRow.Account.Name : null, caseRow.AccountId, null),
            linkField('Contact', caseRow.Contact != null ? caseRow.Contact.Name : null, caseRow.ContactId, null)
        }, 'No case summary.'));

        List<RowData> warrantyRows = new List<RowData>();
        for (Warranty_Record__c warrantyRow : warrantyRecords) {
            warrantyRows.add(makeLinkRow(warrantyRow.Id, warrantyRow.Name, warrantyRow.Status__c, warrantyRow.WorkOrder__r != null ? warrantyRow.WorkOrder__r.WorkOrderNumber : 'Warranty Record', null));
        }
        page.sections.add(rowSection('Related Warranty Records', warrantyRows, 'No Warranty Record is linked to this Case.'));

        List<RowData> appointmentRows = new List<RowData>();
        for (ServiceAppointment appt : appointments) {
            appointmentRows.add(makeLinkRow(appt.Id, appt.AppointmentNumber, appt.Status, 'Service Appointment', appt.SchedStartTime == null ? null : appt.SchedStartTime.format('M/d/yyyy h:mm a')));
        }
        page.sections.add(rowSection('Related Service Appointments', appointmentRows, 'No Service Appointments are linked to the related warranty work.'));

        page.sections.add(rowSection('Activity / Notes', activityRows(recordId), 'No Tasks or Events are logged on this Case.'));
        page.sections.add(rowSection('Files', fileRows(recordId), 'No files are linked to this Case.'));

        if (warrantyRecords.isEmpty()) page.openItems.add('No Warranty Record is linked to this case.');
        page.healthItems.add(field('Case Status', caseRow.Status));
        page.healthItems.add(field('Warranty Records', warrantyRecords.size()));
        page.healthItems.add(field('Service Appointments', appointments.size()));
        return page;
    }

    private static RowData makeLinkRow(Id idValue, String label, String status, String subtext, String dateText) {
        RowData row = new RowData();
        row.id = idValue;
        row.label = label;
        row.url = idValue == null ? null : '/' + idValue;
        row.status = status;
        row.subtext = subtext;
        row.dateText = dateText;
        return row;
    }
}