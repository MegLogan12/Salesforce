public with sharing class ODLWorkspaceListController {
    private static final Integer ROW_LIMIT = 100;

    public class MetricTile {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String tone;
    }

    public class FilterOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class HeaderAction {
        @AuraEnabled public String label;
        @AuraEnabled public String actionType;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public Boolean disabled;
        @AuraEnabled public String disabledReason;
    }

    public class WorkspaceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String name;
        @AuraEnabled public String pathLabel;
        @AuraEnabled public String pathValue;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String statusValue;
        @AuraEnabled public String contextOne;
        @AuraEnabled public String contextTwo;
        @AuraEnabled public String contextThree;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String dateText;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String openItem;
        @AuraEnabled public String filterOneValue;
        @AuraEnabled public String filterTwoValue;
        @AuraEnabled public String filterThreeValue;
        @AuraEnabled public String searchText;
    }

    public class WorkspaceData {
        @AuraEnabled public String workspaceType;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String emptyMessage;
        @AuraEnabled public String searchPlaceholder;
        @AuraEnabled public String nameLabel;
        @AuraEnabled public String pathLabel;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String contextOneLabel;
        @AuraEnabled public String contextTwoLabel;
        @AuraEnabled public String contextThreeLabel;
        @AuraEnabled public String amountLabel;
        @AuraEnabled public String dateLabel;
        @AuraEnabled public String ownerLabel;
        @AuraEnabled public String openItemLabel;
        @AuraEnabled public String primaryFilterLabel;
        @AuraEnabled public String secondaryFilterLabel;
        @AuraEnabled public String tertiaryFilterLabel;
        @AuraEnabled public String newRecordObjectApiName;
        @AuraEnabled public List<MetricTile> metricTiles;
        @AuraEnabled public List<FilterOption> primaryFilterOptions;
        @AuraEnabled public List<FilterOption> secondaryFilterOptions;
        @AuraEnabled public List<FilterOption> tertiaryFilterOptions;
        @AuraEnabled public List<HeaderAction> actions;
        @AuraEnabled public List<String> nextActions;
        @AuraEnabled public List<WorkspaceRow> rows;
    }

    @AuraEnabled(cacheable=true)
    public static WorkspaceData getWorkspaceData(String workspaceType) {
        String normalized = String.isBlank(workspaceType) ? 'voucher' : workspaceType.toLowerCase();
        switch on normalized {
            when 'voucher' {
                return buildVoucherWorkspace();
            }
            when 'campaign' {
                return buildCampaignWorkspace();
            }
            when 'quote' {
                return buildQuoteWorkspace();
            }
            when 'workorder' {
                return buildWorkOrderWorkspace();
            }
            when else {
                throw new AuraHandledException('Unsupported ODL workspace type: ' + normalized);
            }
        }
    }

    private static WorkspaceData newWorkspace(String workspaceType, String title, String subtitle) {
        WorkspaceData data = new WorkspaceData();
        data.workspaceType = workspaceType;
        data.title = title;
        data.subtitle = subtitle;
        data.metricTiles = new List<MetricTile>();
        data.primaryFilterOptions = new List<FilterOption>();
        data.secondaryFilterOptions = new List<FilterOption>();
        data.tertiaryFilterOptions = new List<FilterOption>();
        data.actions = new List<HeaderAction>();
        data.nextActions = new List<String>();
        data.rows = new List<WorkspaceRow>();
        return data;
    }

    private static HeaderAction action(String label, String actionType, String objectApiName) {
        HeaderAction item = new HeaderAction();
        item.label = label;
        item.actionType = actionType;
        item.objectApiName = objectApiName;
        item.disabled = false;
        return item;
    }

    private static HeaderAction disabledAction(String label, String reason) {
        HeaderAction item = new HeaderAction();
        item.label = label;
        item.actionType = 'disabled';
        item.disabled = true;
        item.disabledReason = reason;
        return item;
    }

    private static MetricTile metric(String label, Object value, String tone) {
        MetricTile tile = new MetricTile();
        tile.label = label;
        tile.value = value == null ? '0' : String.valueOf(value);
        tile.tone = tone;
        return tile;
    }

    private static FilterOption option(String label, String value) {
        FilterOption item = new FilterOption();
        item.label = label;
        item.value = value;
        return item;
    }

    private static WorkspaceData buildVoucherWorkspace() {
        WorkspaceData data = newWorkspace(
            'voucher',
            'Voucher Workspace',
            'Outdoor Living vouchers with entitlement, reimbursement, and quote application context.'
        );
        data.emptyMessage = 'No vouchers match the current filters.';
        data.searchPlaceholder = 'Search vouchers';
        data.nameLabel = 'Voucher';
        data.pathLabel = 'Voucher Type';
        data.statusLabel = 'Status';
        data.contextOneLabel = 'Builder Account';
        data.contextTwoLabel = 'Campaign';
        data.contextThreeLabel = 'Sponsor Payment Responsibility';
        data.amountLabel = 'Reimbursement';
        data.dateLabel = 'Expiration';
        data.ownerLabel = 'Related Opportunity';
        data.openItemLabel = 'Open Item';
        data.primaryFilterLabel = 'Status';
        data.secondaryFilterLabel = 'Voucher Type';
        data.tertiaryFilterLabel = 'Builder Account';
        data.newRecordObjectApiName = 'Voucher__c';
        data.actions.add(action('New Voucher', 'newRecord', 'Voucher__c'));
        data.actions.add(disabledAction('Validate', 'Open a voucher record first. Lifecycle movement remains controlled.'));
        data.actions.add(disabledAction('Apply to Quote', 'Open a voucher record first. Lifecycle movement remains controlled.'));
        data.actions.add(disabledAction('Mark Builder Invoiced', 'Open a voucher record first. Lifecycle movement remains controlled.'));
        data.actions.add(disabledAction('Mark Paid by Builder', 'Open a voucher record first. Lifecycle movement remains controlled.'));

        List<Voucher__c> vouchers = [
            SELECT Id, Name, Voucher_Code__c, Voucher_Type__c, Status__c,
                   Builder_Account__c, Builder_Account__r.Name, Campaign__c, Campaign__r.Name,
                   Reserved_Opportunity__c, Reserved_Opportunity__r.Name, Expiration_Date__c,
                   Builder_Invoice_Status__c, Voucher_Face_Value__c
            FROM Voucher__c
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ];

        Map<String, Integer> statusCounts = new Map<String, Integer>();
        Set<String> typeValues = new Set<String>();
        Set<String> builderValues = new Set<String>();
        for (Voucher__c voucherRow : vouchers) {
            increment(statusCounts, voucherRow.Status__c);
            if (!String.isBlank(voucherRow.Voucher_Type__c)) typeValues.add(voucherRow.Voucher_Type__c);
            if (voucherRow.Builder_Account__r != null) builderValues.add(voucherRow.Builder_Account__r.Name);

            WorkspaceRow row = new WorkspaceRow();
            row.id = voucherRow.Id;
            row.url = '/' + voucherRow.Id;
            row.name = firstNonBlank(new List<String>{ voucherRow.Voucher_Code__c, voucherRow.Name });
            row.pathLabel = voucherRow.Voucher_Type__c;
            row.pathValue = voucherRow.Voucher_Type__c;
            row.statusLabel = voucherRow.Status__c;
            row.statusValue = voucherRow.Status__c;
            row.contextOne = voucherRow.Builder_Account__r != null ? voucherRow.Builder_Account__r.Name : 'No builder sponsor';
            row.contextTwo = voucherRow.Campaign__r != null ? voucherRow.Campaign__r.Name : 'No campaign';
            row.contextThree = voucherRow.Builder_Invoice_Status__c;
            row.ownerName = voucherRow.Reserved_Opportunity__r != null ? voucherRow.Reserved_Opportunity__r.Name : 'No opportunity';
            row.dateText = voucherRow.Expiration_Date__c == null ? 'No expiration' : String.valueOf(voucherRow.Expiration_Date__c);
            row.amount = voucherRow.Voucher_Face_Value__c;
            row.openItem = deriveVoucherOpenItem(voucherRow);
            row.filterOneValue = voucherRow.Status__c;
            row.filterTwoValue = voucherRow.Voucher_Type__c;
            row.filterThreeValue = voucherRow.Builder_Account__r != null ? voucherRow.Builder_Account__r.Name : 'none';
            row.searchText = String.join(new List<String>{
                row.name, row.pathLabel, row.statusLabel, row.contextOne, row.contextTwo, row.contextThree, row.ownerName, row.openItem
            }, ' ').toLowerCase();
            data.rows.add(row);
        }

        data.metricTiles.add(metric('Active', statusCounts.get('Active'), 'neutral'));
        data.metricTiles.add(metric('Submitted', statusCounts.get('Submitted'), 'warning'));
        data.metricTiles.add(metric('Validated', statusCounts.get('Validated'), 'success'));
        data.metricTiles.add(metric('Reserved', statusCounts.get('Reserved'), 'neutral'));
        data.metricTiles.add(metric('Applied to Quote', statusCounts.get('Applied to Quote'), 'neutral'));
        data.metricTiles.add(metric('Builder Invoice Pending', statusCounts.get('Builder Invoice Pending'), 'warning'));
        data.metricTiles.add(metric('Builder Invoiced', statusCounts.get('Builder Invoiced'), 'warning'));
        data.metricTiles.add(metric('Paid by Builder', statusCounts.get('Paid by Builder'), 'success'));
        data.metricTiles.add(metric('Redeemed', statusCounts.get('Redeemed'), 'success'));
        data.metricTiles.add(metric('Rejected / Expired', (safeCount(statusCounts, 'Rejected') + safeCount(statusCounts, 'Expired')), 'danger'));

        data.primaryFilterOptions.add(option('All Statuses', 'all'));
        for (String statusValue : new List<String>{'Active','Submitted','Validated','Reserved','Applied to Quote','Builder Invoice Pending','Builder Invoiced','Paid by Builder','Redeemed','Rejected','Expired'}) {
            data.primaryFilterOptions.add(option(statusValue, statusValue));
        }
        data.secondaryFilterOptions.add(option('All Voucher Types', 'all'));
        for (String value : sortedValues(typeValues)) data.secondaryFilterOptions.add(option(value, value));
        data.tertiaryFilterOptions.add(option('All Builder Accounts', 'all'));
        for (String value : sortedValues(builderValues)) data.tertiaryFilterOptions.add(option(value, value));

        data.nextActions.add('Review Submitted and Validated vouchers first.');
        data.nextActions.add('Builder invoice actions stay on the voucher record page during the current controlled-production window.');
        return data;
    }

    private static WorkspaceData buildCampaignWorkspace() {
        WorkspaceData data = newWorkspace(
            'campaign',
            'Campaign Workspace',
            'Outdoor Living campaigns with builder sponsor, voucher funnel, and ROI context.'
        );
        data.emptyMessage = 'No campaigns match the current filters.';
        data.searchPlaceholder = 'Search campaigns';
        data.nameLabel = 'Campaign';
        data.pathLabel = 'Record Type';
        data.statusLabel = 'Status';
        data.contextOneLabel = 'Builder Sponsor';
        data.contextTwoLabel = 'Offer';
        data.contextThreeLabel = 'Voucher Funnel';
        data.amountLabel = 'Expected Revenue';
        data.dateLabel = 'Start Date';
        data.ownerLabel = 'Owner';
        data.openItemLabel = 'Open Item';
        data.primaryFilterLabel = 'Record Type';
        data.secondaryFilterLabel = 'Builder Account';
        data.tertiaryFilterLabel = 'Status';
        data.newRecordObjectApiName = 'Campaign';
        data.actions.add(action('New Campaign', 'newRecord', 'Campaign'));

        List<Campaign> campaigns = [
            SELECT Id, Name, Status, Type, StartDate, EndDate, ExpectedRevenue, Owner.Name,
                   RecordType.Name, Builder_Account__c, Builder_Account__r.Name, Offer_Description__c
            FROM Campaign
            WHERE (Builder_Account__c != null OR Offer_Description__c != null OR RecordType.Name IN ('UpgradeMyBackyard Digital','UpgradeMyBackyard Referral','Builder-Sponsored Voucher','Model Home QR','Community Buyer Offer','Re-Engagement','Blog Newsletter'))
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ];

        Set<Id> campaignIds = new Set<Id>();
        Set<String> recordTypeNames = new Set<String>();
        Set<String> builderNames = new Set<String>();
        Map<Id, Integer> voucherCounts = new Map<Id, Integer>();
        Map<Id, Integer> submittedCounts = new Map<Id, Integer>();
        Map<Id, Integer> validatedCounts = new Map<Id, Integer>();
        Map<Id, Integer> redeemedCounts = new Map<Id, Integer>();
        for (Campaign row : campaigns) {
            campaignIds.add(row.Id);
            if (row.RecordType != null) recordTypeNames.add(row.RecordType.Name);
            if (row.Builder_Account__r != null) builderNames.add(row.Builder_Account__r.Name);
        }
        if (!campaignIds.isEmpty()) {
            for (Voucher__c voucherRow : [
                SELECT Campaign__c, Status__c
                FROM Voucher__c
                WHERE Campaign__c IN :campaignIds
            ]) {
                increment(voucherCounts, voucherRow.Campaign__c);
                if (voucherRow.Status__c == 'Submitted') increment(submittedCounts, voucherRow.Campaign__c);
                if (voucherRow.Status__c == 'Validated') increment(validatedCounts, voucherRow.Campaign__c);
                if (voucherRow.Status__c == 'Redeemed') increment(redeemedCounts, voucherRow.Campaign__c);
            }
        }

        Integer activeCampaigns = 0;
        Integer voucherBackedCampaigns = 0;
        for (Campaign campaignRow : campaigns) {
            if (campaignRow.Status == 'In Progress') activeCampaigns++;
            if (safeCount(voucherCounts, campaignRow.Id) > 0) voucherBackedCampaigns++;

            WorkspaceRow row = new WorkspaceRow();
            row.id = campaignRow.Id;
            row.url = '/' + campaignRow.Id;
            row.name = campaignRow.Name;
            row.pathLabel = campaignRow.RecordType != null ? campaignRow.RecordType.Name : 'Master';
            row.pathValue = row.pathLabel;
            row.statusLabel = campaignRow.Status;
            row.statusValue = campaignRow.Status;
            row.contextOne = campaignRow.Builder_Account__r != null ? campaignRow.Builder_Account__r.Name : 'No builder sponsor';
            row.contextTwo = firstNonBlank(new List<String>{ campaignRow.Offer_Description__c, campaignRow.Type, 'No offer description' });
            row.contextThree = 'Vouchers ' + safeCount(voucherCounts, campaignRow.Id) + ' | Submitted ' + safeCount(submittedCounts, campaignRow.Id) + ' | Validated ' + safeCount(validatedCounts, campaignRow.Id) + ' | Redeemed ' + safeCount(redeemedCounts, campaignRow.Id);
            row.ownerName = campaignRow.Owner != null ? campaignRow.Owner.Name : null;
            row.dateText = campaignRow.StartDate == null ? 'No start date' : String.valueOf(campaignRow.StartDate);
            row.amount = campaignRow.ExpectedRevenue;
            row.openItem = campaignRow.Builder_Account__c == null ? 'Builder sponsor missing' : (String.isBlank(campaignRow.Offer_Description__c) ? 'Offer description missing' : 'Campaign ready');
            row.filterOneValue = row.pathValue;
            row.filterTwoValue = campaignRow.Builder_Account__r != null ? campaignRow.Builder_Account__r.Name : 'none';
            row.filterThreeValue = campaignRow.Status;
            row.searchText = String.join(new List<String>{
                row.name, row.pathLabel, row.statusLabel, row.contextOne, row.contextTwo, row.contextThree, row.ownerName, row.openItem
            }, ' ').toLowerCase();
            data.rows.add(row);
        }

        data.metricTiles.add(metric('Campaigns', campaigns.size(), 'neutral'));
        data.metricTiles.add(metric('Active Campaigns', activeCampaigns, 'success'));
        data.metricTiles.add(metric('Voucher-Backed', voucherBackedCampaigns, 'neutral'));
        data.metricTiles.add(metric('Submitted', sumMap(submittedCounts), 'warning'));
        data.metricTiles.add(metric('Validated', sumMap(validatedCounts), 'success'));
        data.metricTiles.add(metric('Redeemed', sumMap(redeemedCounts), 'success'));

        data.primaryFilterOptions.add(option('All Record Types', 'all'));
        for (String value : sortedValues(recordTypeNames)) data.primaryFilterOptions.add(option(value, value));
        data.secondaryFilterOptions.add(option('All Builder Accounts', 'all'));
        for (String value : sortedValues(builderNames)) data.secondaryFilterOptions.add(option(value, value));
        data.tertiaryFilterOptions.add(option('All Statuses', 'all'));
        for (String value : distinctCampaignStatuses(campaigns)) data.tertiaryFilterOptions.add(option(value, value));

        data.nextActions.add('Review campaigns without builder sponsor or offer description.');
        data.nextActions.add('Campaign ROI depends on voucher and campaign member linkage being present.');
        return data;
    }

    private static WorkspaceData buildQuoteWorkspace() {
        WorkspaceData data = newWorkspace(
            'quote',
            'Quote Workspace',
            'Outdoor Living quotes with voucher application, payment readiness, and release gating.'
        );
        data.emptyMessage = 'No quotes match the current filters.';
        data.searchPlaceholder = 'Search quotes';
        data.nameLabel = 'Quote';
        data.pathLabel = 'Project Path';
        data.statusLabel = 'Quote Status';
        data.contextOneLabel = 'Opportunity';
        data.contextTwoLabel = 'Voucher';
        data.contextThreeLabel = 'Package / Release';
        data.amountLabel = 'Quote Total';
        data.dateLabel = 'Updated';
        data.ownerLabel = 'Owner';
        data.openItemLabel = 'Blocked Reason';
        data.primaryFilterLabel = 'Quote Status';
        data.secondaryFilterLabel = 'Project Path';
        data.tertiaryFilterLabel = 'Package';
        data.newRecordObjectApiName = 'Quote';
        data.actions.add(action('New Quote', 'newRecord', 'Quote'));

        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Status, GrandTotal, LastModifiedDate, Owner.Name,
                   OpportunityId, Opportunity.Name, Opportunity.Type, Opportunity.StageName, Opportunity.BMG_Package__c,
                   Voucher__c, Voucher__r.Voucher_Code__c,
                   Voucher_Credit_Amount__c
            FROM Quote
            WHERE (Opportunity.Type IN ('UpgradeMyBackyard','Design Build') OR Voucher__c != null)
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ];

        Set<Id> quoteIds = new Set<Id>();
        Set<String> packageValues = new Set<String>();
        for (Quote quoteRow : quotes) {
            quoteIds.add(quoteRow.Id);
            if (quoteRow.Opportunity != null && !String.isBlank(quoteRow.Opportunity.BMG_Package__c)) packageValues.add(quoteRow.Opportunity.BMG_Package__c);
        }
        Map<Id, Boolean> depositPaidByQuote = new Map<Id, Boolean>();
        Map<Id, Integer> milestoneCountByQuote = new Map<Id, Integer>();
        if (!quoteIds.isEmpty()) {
            for (Payment_Milestone__c milestoneRow : [
                SELECT Quote__c, Type__c, Status__c
                FROM Payment_Milestone__c
                WHERE Quote__c IN :quoteIds
            ]) {
                increment(milestoneCountByQuote, milestoneRow.Quote__c);
                if (milestoneRow.Type__c == 'Deposit' && milestoneRow.Status__c == 'Paid') {
                    depositPaidByQuote.put(milestoneRow.Quote__c, true);
                }
            }
        }

        Integer blockedReleaseCount = 0;
        for (Quote quoteRow : quotes) {
            Boolean depositPaid = depositPaidByQuote.containsKey(quoteRow.Id) && depositPaidByQuote.get(quoteRow.Id);
            Boolean releaseReady = quoteRow.Opportunity != null && quoteRow.Opportunity.StageName == 'Contract Signed' && depositPaid;
            if (!releaseReady) blockedReleaseCount++;

            WorkspaceRow row = new WorkspaceRow();
            row.id = quoteRow.Id;
            row.url = '/' + quoteRow.Id;
            row.name = firstNonBlank(new List<String>{ quoteRow.Name, quoteRow.QuoteNumber });
            row.pathLabel = quoteRow.Opportunity != null ? normalizeProjectPath(quoteRow.Opportunity.Type) : 'No project path';
            row.pathValue = row.pathLabel;
            row.statusLabel = quoteRow.Status;
            row.statusValue = quoteRow.Status;
            row.contextOne = quoteRow.Opportunity != null ? quoteRow.Opportunity.Name : 'No opportunity';
            row.contextTwo = quoteRow.Voucher__r != null ? quoteRow.Voucher__r.Voucher_Code__c : 'No voucher';
            row.contextThree = firstNonBlank(new List<String>{
                quoteRow.Opportunity != null ? quoteRow.Opportunity.BMG_Package__c : null,
                releaseReady ? 'Release ready' : 'Release blocked'
            });
            row.ownerName = quoteRow.Owner != null ? quoteRow.Owner.Name : null;
            row.dateText = quoteRow.LastModifiedDate.format('M/d/yyyy');
            row.amount = quoteRow.GrandTotal;
            row.openItem = releaseReady ? 'Ready' : deriveQuoteBlocker(quoteRow, depositPaid);
            row.filterOneValue = quoteRow.Status;
            row.filterTwoValue = row.pathValue;
            row.filterThreeValue = quoteRow.Opportunity != null ? quoteRow.Opportunity.BMG_Package__c : 'none';
            row.searchText = String.join(new List<String>{
                row.name, row.pathLabel, row.statusLabel, row.contextOne, row.contextTwo, row.contextThree, row.ownerName, row.openItem
            }, ' ').toLowerCase();
            data.rows.add(row);
        }

        data.metricTiles.add(metric('Quotes', quotes.size(), 'neutral'));
        data.metricTiles.add(metric('Voucher-Linked', countQuotesWithVoucher(quotes), 'neutral'));
        data.metricTiles.add(metric('Blocked Release', blockedReleaseCount, 'warning'));
        data.metricTiles.add(metric('Contract Signed', countQuotesByOppStage(quotes, 'Contract Signed'), 'success'));
        data.metricTiles.add(metric('Deposit Paid', countTrueValues(depositPaidByQuote), 'success'));

        data.primaryFilterOptions.add(option('All Quote Statuses', 'all'));
        for (String value : distinctQuoteStatuses(quotes)) data.primaryFilterOptions.add(option(value, value));
        data.secondaryFilterOptions.add(option('All Project Paths', 'all'));
        data.secondaryFilterOptions.add(option('UpgradeMyBackyard', 'UpgradeMyBackyard'));
        data.secondaryFilterOptions.add(option('Design Build', 'Design Build'));
        data.tertiaryFilterOptions.add(option('All Packages', 'all'));
        for (String value : sortedValues(packageValues)) data.tertiaryFilterOptions.add(option(value, value));

        data.nextActions.add('Review blocked-release quotes before work is handed off.');
        data.nextActions.add('Voucher credit should stay visible on the quote instead of manual discount notes.');
        return data;
    }

    private static WorkspaceData buildWorkOrderWorkspace() {
        WorkspaceData data = newWorkspace(
            'workorder',
            'Work Order Workspace',
            'Outdoor Living work orders with field readiness, schedule, and handoff context.'
        );
        data.emptyMessage = 'No work orders match the current filters.';
        data.searchPlaceholder = 'Search work orders';
        data.nameLabel = 'Work Order';
        data.pathLabel = 'Project Path';
        data.statusLabel = 'Status';
        data.contextOneLabel = 'Homeowner / Account';
        data.contextTwoLabel = 'Work Type';
        data.contextThreeLabel = 'Field Context';
        data.amountLabel = 'Appointments';
        data.dateLabel = 'Scheduled Date';
        data.ownerLabel = 'Field Manager';
        data.openItemLabel = 'Open Item';
        data.primaryFilterLabel = 'Status';
        data.secondaryFilterLabel = 'Project Path';
        data.tertiaryFilterLabel = 'Work Type';
        data.newRecordObjectApiName = 'WorkOrder';
        data.actions.add(action('New Work Order', 'newRecord', 'WorkOrder'));

        Boolean hasOpportunityField = Schema.SObjectType.WorkOrder.fields.getMap().containsKey('Opportunity__c');
        String soql = 'SELECT Id, WorkOrderNumber, Subject, Status, AccountId, Account.Name, ContactId, Contact.Name, Work_Order_Type__c, Scheduled_Date__c, Field_Manager__r.Name';
        if (hasOpportunityField) {
            soql += ', Opportunity__c, Opportunity__r.Name, Opportunity__r.Type, Opportunity__r.StageName';
        }
        soql += ' FROM WorkOrder WHERE (Account.Type = \'Homeowner\' OR Contact.Account.Type = \'Homeowner\'';
        if (hasOpportunityField) {
            soql += ' OR Opportunity__r.Type IN (\'UpgradeMyBackyard\', \'Design Build\')';
        }
        soql += ') AND (Work_Order_Type__c = null OR Work_Order_Type__c != \'Lawn Care\') ORDER BY LastModifiedDate DESC LIMIT ' + ROW_LIMIT;
        List<WorkOrder> workOrders = Database.query(soql);

        Set<Id> workOrderIds = new Set<Id>();
        Set<String> workTypes = new Set<String>();
        for (WorkOrder row : workOrders) {
            workOrderIds.add(row.Id);
            if (!String.isBlank(row.Work_Order_Type__c)) workTypes.add(row.Work_Order_Type__c);
        }
        Map<Id, Integer> appointmentCountByWo = new Map<Id, Integer>();
        if (!workOrderIds.isEmpty()) {
            for (ServiceAppointment appt : [
                SELECT ParentRecordId
                FROM ServiceAppointment
                WHERE ParentRecordId IN :workOrderIds
            ]) {
                increment(appointmentCountByWo, appt.ParentRecordId);
            }
        }

        for (WorkOrder workOrderRow : workOrders) {
            SObject relatedOpportunity = hasOpportunityField ? workOrderRow.getSObject('Opportunity__r') : null;
            String projectPath = normalizeProjectPath(relatedOpportunity != null ? String.valueOf(relatedOpportunity.get('Type')) : 'UpgradeMyBackyard');
            WorkspaceRow row = new WorkspaceRow();
            row.id = workOrderRow.Id;
            row.url = '/' + workOrderRow.Id;
            row.name = firstNonBlank(new List<String>{ workOrderRow.WorkOrderNumber, workOrderRow.Subject });
            row.pathLabel = projectPath;
            row.pathValue = projectPath;
            row.statusLabel = workOrderRow.Status;
            row.statusValue = workOrderRow.Status;
            row.contextOne = workOrderRow.Contact != null ? workOrderRow.Contact.Name : (workOrderRow.Account != null ? workOrderRow.Account.Name : 'No homeowner');
            row.contextTwo = firstNonBlank(new List<String>{ workOrderRow.Work_Order_Type__c, 'No work type' });
            row.contextThree = relatedOpportunity != null ? String.valueOf(relatedOpportunity.get('StageName')) : 'No linked opportunity';
            row.ownerName = workOrderRow.getSObject('Field_Manager__r') != null ? String.valueOf(workOrderRow.getSObject('Field_Manager__r').get('Name')) : 'No field manager';
            row.dateText = workOrderRow.Scheduled_Date__c == null ? 'No scheduled date' : String.valueOf(workOrderRow.Scheduled_Date__c);
            row.amount = appointmentCountByWo.containsKey(workOrderRow.Id) ? Decimal.valueOf(appointmentCountByWo.get(workOrderRow.Id)) : 0;
            row.openItem = deriveWorkOrderOpenItem(workOrderRow, appointmentCountByWo.get(workOrderRow.Id));
            row.filterOneValue = workOrderRow.Status;
            row.filterTwoValue = projectPath;
            row.filterThreeValue = workOrderRow.Work_Order_Type__c;
            row.searchText = String.join(new List<String>{
                row.name, row.pathLabel, row.statusLabel, row.contextOne, row.contextTwo, row.contextThree, row.ownerName, row.openItem
            }, ' ').toLowerCase();
            data.rows.add(row);
        }

        data.metricTiles.add(metric('Work Orders', workOrders.size(), 'neutral'));
        data.metricTiles.add(metric('Scheduled', countWorkOrdersByStatus(workOrders, 'Scheduled'), 'success'));
        data.metricTiles.add(metric('Missing Appointments', countWorkOrdersWithoutAppointments(workOrders, appointmentCountByWo), 'warning'));
        data.metricTiles.add(metric('UpgradeMyBackyard', countWorkOrdersByPath(workOrders, hasOpportunityField, 'UpgradeMyBackyard'), 'neutral'));
        data.metricTiles.add(metric('Design Build', countWorkOrdersByPath(workOrders, hasOpportunityField, 'Design Build'), 'neutral'));

        data.primaryFilterOptions.add(option('All Statuses', 'all'));
        for (String value : distinctWorkOrderStatuses(workOrders)) data.primaryFilterOptions.add(option(value, value));
        data.secondaryFilterOptions.add(option('All Project Paths', 'all'));
        data.secondaryFilterOptions.add(option('UpgradeMyBackyard', 'UpgradeMyBackyard'));
        data.secondaryFilterOptions.add(option('Design Build', 'Design Build'));
        data.tertiaryFilterOptions.add(option('All Work Types', 'all'));
        for (String value : sortedValues(workTypes)) data.tertiaryFilterOptions.add(option(value, value));

        data.nextActions.add('Review work orders with no service appointments or no scheduled date.');
        data.nextActions.add('Lawn Care is excluded from this workspace by query logic.');
        return data;
    }

    private static void increment(Map<String, Integer> counts, String key) {
        if (String.isBlank(key)) return;
        counts.put(key, safeCount(counts, key) + 1);
    }

    private static void increment(Map<Id, Integer> counts, Id key) {
        if (key == null) return;
        counts.put(key, (counts.containsKey(key) ? counts.get(key) : 0) + 1);
    }

    private static Integer safeCount(Map<String, Integer> counts, String key) {
        return counts.containsKey(key) ? counts.get(key) : 0;
    }

    private static Integer safeCount(Map<Id, Integer> counts, Id key) {
        return counts.containsKey(key) ? counts.get(key) : 0;
    }

    private static List<String> sortedValues(Set<String> values) {
        List<String> output = new List<String>();
        output.addAll(values);
        output.sort();
        return output;
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String normalizeProjectPath(String rawValue) {
        if (rawValue == 'UMB' || rawValue == 'UpgradeMyBackyard') return 'UpgradeMyBackyard';
        if (rawValue == 'Custom Build' || rawValue == 'Design and Build' || rawValue == 'Design Build') return 'Design Build';
        return rawValue;
    }

    private static String deriveVoucherOpenItem(Voucher__c voucherRow) {
        if (voucherRow.Campaign__c == null) return 'Campaign missing';
        if (voucherRow.Builder_Account__c == null) return 'Builder sponsor missing';
        if (voucherRow.Reserved_Opportunity__c == null) return 'Opportunity missing';
        if (voucherRow.Builder_Invoice_Status__c == 'Pending' || voucherRow.Builder_Invoice_Status__c == 'Ready to Invoice') return 'Finance review';
        return 'Ready';
    }

    private static Integer sumMap(Map<Id, Integer> counts) {
        Integer total = 0;
        for (Integer value : counts.values()) total += value;
        return total;
    }

    private static List<String> distinctCampaignStatuses(List<Campaign> campaigns) {
        Set<String> values = new Set<String>();
        for (Campaign row : campaigns) if (!String.isBlank(row.Status)) values.add(row.Status);
        return sortedValues(values);
    }

    private static String deriveQuoteBlocker(Quote quoteRow, Boolean depositPaid) {
        if (quoteRow.Opportunity == null) return 'Opportunity missing';
        if (quoteRow.Opportunity.StageName != 'Contract Signed') return 'Contract not signed';
        if (!depositPaid) return 'Deposit not paid';
        return 'Review release';
    }

    private static Integer countQuotesWithVoucher(List<Quote> quotes) {
        Integer count = 0;
        for (Quote row : quotes) if (row.Voucher__c != null) count++;
        return count;
    }

    private static Integer countQuotesByOppStage(List<Quote> quotes, String stageName) {
        Integer count = 0;
        for (Quote row : quotes) if (row.Opportunity != null && row.Opportunity.StageName == stageName) count++;
        return count;
    }

    private static Integer countTrueValues(Map<Id, Boolean> values) {
        Integer count = 0;
        for (Boolean value : values.values()) if (value == true) count++;
        return count;
    }

    private static List<String> distinctQuoteStatuses(List<Quote> quotes) {
        Set<String> values = new Set<String>();
        for (Quote row : quotes) if (!String.isBlank(row.Status)) values.add(row.Status);
        return sortedValues(values);
    }

    private static String deriveWorkOrderOpenItem(WorkOrder workOrderRow, Integer appointmentCount) {
        if (workOrderRow.Scheduled_Date__c == null) return 'Scheduled date missing';
        if (appointmentCount == null || appointmentCount == 0) return 'Service appointment missing';
        if (workOrderRow.ContactId == null) return 'Homeowner contact missing';
        return 'Ready';
    }

    private static Integer countWorkOrdersByStatus(List<WorkOrder> workOrders, String statusValue) {
        Integer count = 0;
        for (WorkOrder row : workOrders) if (row.Status == statusValue) count++;
        return count;
    }

    private static List<String> distinctWorkOrderStatuses(List<WorkOrder> workOrders) {
        Set<String> values = new Set<String>();
        for (WorkOrder row : workOrders) {
            if (!String.isBlank(row.Status)) {
                values.add(row.Status);
            }
        }
        return sortedValues(values);
    }

    private static Integer countWorkOrdersWithoutAppointments(List<WorkOrder> workOrders, Map<Id, Integer> counts) {
        Integer count = 0;
        for (WorkOrder row : workOrders) {
            if (safeCount(counts, row.Id) == 0) count++;
        }
        return count;
    }

    private static Integer countWorkOrdersByPath(List<WorkOrder> workOrders, Boolean hasOpportunityField, String path) {
        Integer count = 0;
        for (WorkOrder row : workOrders) {
            SObject opp = hasOpportunityField ? row.getSObject('Opportunity__r') : null;
            String resolved = normalizeProjectPath(opp != null ? String.valueOf(opp.get('Type')) : 'UpgradeMyBackyard');
            if (resolved == path) count++;
        }
        return count;
    }
}