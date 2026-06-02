public with sharing class ODLWorkspaceEmailController {
    private static final Integer ROW_LIMIT = 15;

    public class WorkspaceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String subStatus;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String relatedName;
        @AuraEnabled public String email;
        @AuraEnabled public Datetime activityDate;
        @AuraEnabled public Decimal amount;
    }

    public class WorkspaceData {
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public Boolean backendMissing;
        @AuraEnabled public String backendMissingReason;
        @AuraEnabled public List<WorkspaceRow> rows;
    }

    private class SortableRow implements Comparable {
        Datetime sortValue;
        WorkspaceRow row;

        SortableRow(WorkspaceRow rowValue, Datetime sortDate) {
            row = rowValue;
            sortValue = sortDate;
        }

        public Integer compareTo(Object otherValue) {
            SortableRow otherRow = (SortableRow) otherValue;
            Long left = sortValue == null ? 0 : sortValue.getTime();
            Long right = otherRow.sortValue == null ? 0 : otherRow.sortValue.getTime();
            if (left == right) {
                return 0;
            }
            return left > right ? -1 : 1;
        }
    }

    @AuraEnabled(cacheable=true)
    public static WorkspaceData getWorkspaceData(String workspaceType) {
        String normalizedType = String.isBlank(workspaceType) ? 'sales' : workspaceType.toLowerCase();
        switch on normalizedType {
            when 'sales' {
                return buildSalesWorkspace();
            }
            when 'lead' {
                return buildLeadWorkspace();
            }
            when 'opportunity' {
                return buildOpportunityWorkspace();
            }
            when 'quote' {
                return buildQuoteWorkspace();
            }
            when 'workorder' {
                return buildWorkOrderWorkspace();
            }
            when 'voucher' {
                return buildVoucherWorkspace();
            }
            when else {
                WorkspaceData data = new WorkspaceData();
                data.title = 'Outdoor Living Workspace';
                data.subtitle = 'Unsupported workspace type.';
                data.rows = new List<WorkspaceRow>();
                return data;
            }
        }
    }

    private static WorkspaceData buildSalesWorkspace() {
        WorkspaceData data = new WorkspaceData();
        data.title = 'Outdoor Living Sales';
        data.subtitle = 'Recent Outdoor Living leads and opportunities with live email history on the selected record.';
        List<SortableRow> rows = new List<SortableRow>();

        if (Schema.SObjectType.Opportunity.isAccessible()) {
            for (Opportunity opp : [
                SELECT Id, Name, Type, StageName, Amount, LastActivityDate, Owner.Name, Account.Name, IsClosed, CreatedDate
                FROM Opportunity
                WHERE (Type = 'UMB' OR Type = 'Home Builder' OR Type = 'New Business' OR Name LIKE '%Backyard%' OR Name LIKE '%Voucher%')
                ORDER BY LastModifiedDate DESC
                LIMIT :ROW_LIMIT
            ]) {
                WorkspaceRow row = new WorkspaceRow();
                row.id = opp.Id;
                row.objectApiName = 'Opportunity';
                row.name = opp.Name;
                row.status = opp.StageName;
                row.subStatus = opp.Type;
                row.ownerName = opp.Owner != null ? opp.Owner.Name : null;
                row.relatedName = opp.Account != null ? opp.Account.Name : null;
                row.activityDate = opp.LastActivityDate == null ? opp.CreatedDate : Datetime.newInstance(opp.LastActivityDate, Time.newInstance(12, 0, 0, 0));
                row.amount = opp.Amount;
                rows.add(new SortableRow(row, row.activityDate));
            }
        }

        if (Schema.SObjectType.Lead.isAccessible()) {
            for (Lead leadRow : [
                SELECT Id, Name, Status, LeadSource, Email, LastActivityDate, Owner.Name, CreatedDate
                FROM Lead
                WHERE LeadSource IN ('Lennar Voucher', 'Web - Design Form', 'UMB Builder Pop Up', 'Web - Consultation Form', 'Homebuilder Event')
                ORDER BY LastModifiedDate DESC
                LIMIT :ROW_LIMIT
            ]) {
                WorkspaceRow row = new WorkspaceRow();
                row.id = leadRow.Id;
                row.objectApiName = 'Lead';
                row.name = leadRow.Name;
                row.status = leadRow.Status;
                row.subStatus = leadRow.LeadSource;
                row.ownerName = leadRow.Owner != null ? leadRow.Owner.Name : null;
                row.email = leadRow.Email;
                row.activityDate = leadRow.LastActivityDate == null ? leadRow.CreatedDate : Datetime.newInstance(leadRow.LastActivityDate, Time.newInstance(12, 0, 0, 0));
                rows.add(new SortableRow(row, row.activityDate));
            }
        }

        rows.sort();
        data.rows = unwrap(rows, ROW_LIMIT);
        return data;
    }

    private static WorkspaceData buildLeadWorkspace() {
        WorkspaceData data = new WorkspaceData();
        data.title = 'Outdoor Living Leads';
        data.subtitle = 'Lead workspace with live email history on the selected lead.';
        data.rows = new List<WorkspaceRow>();
        if (!Schema.SObjectType.Lead.isAccessible()) {
            return data;
        }
        for (Lead leadRow : [
            SELECT Id, Name, Status, LeadSource, Email, Phone, Owner.Name, LastActivityDate, CreatedDate
            FROM Lead
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ]) {
            WorkspaceRow row = new WorkspaceRow();
            row.id = leadRow.Id;
            row.objectApiName = 'Lead';
            row.name = leadRow.Name;
            row.status = leadRow.Status;
            row.subStatus = leadRow.LeadSource;
            row.ownerName = leadRow.Owner != null ? leadRow.Owner.Name : null;
            row.email = firstNonBlank(new List<String>{leadRow.Email, leadRow.Phone});
            row.activityDate = leadRow.LastActivityDate == null ? leadRow.CreatedDate : Datetime.newInstance(leadRow.LastActivityDate, Time.newInstance(12, 0, 0, 0));
            data.rows.add(row);
        }
        return data;
    }

    private static WorkspaceData buildOpportunityWorkspace() {
        WorkspaceData data = new WorkspaceData();
        data.title = 'Outdoor Living Opportunities';
        data.subtitle = 'Opportunity workspace with live email history on the selected opportunity.';
        data.rows = new List<WorkspaceRow>();
        if (!Schema.SObjectType.Opportunity.isAccessible()) {
            return data;
        }
        for (Opportunity opp : [
            SELECT Id, Name, StageName, Type, Amount, LastActivityDate, Owner.Name, Account.Name, CreatedDate
            FROM Opportunity
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ]) {
            WorkspaceRow row = new WorkspaceRow();
            row.id = opp.Id;
            row.objectApiName = 'Opportunity';
            row.name = opp.Name;
            row.status = opp.StageName;
            row.subStatus = opp.Type;
            row.ownerName = opp.Owner != null ? opp.Owner.Name : null;
            row.relatedName = opp.Account != null ? opp.Account.Name : null;
            row.activityDate = opp.LastActivityDate == null ? opp.CreatedDate : Datetime.newInstance(opp.LastActivityDate, Time.newInstance(12, 0, 0, 0));
            row.amount = opp.Amount;
            data.rows.add(row);
        }
        return data;
    }

    private static WorkspaceData buildQuoteWorkspace() {
        WorkspaceData data = new WorkspaceData();
        data.title = 'Outdoor Living Quotes';
        data.subtitle = 'Quote workspace with live email history on the selected quote.';
        data.rows = new List<WorkspaceRow>();
        if (!Schema.SObjectType.Quote.isAccessible()) {
            return data;
        }
        for (Quote quoteRow : [
            SELECT Id, Name, QuoteNumber, Status, GrandTotal, Opportunity.Name, Owner.Name, CreatedDate, LastModifiedDate
            FROM Quote
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ]) {
            WorkspaceRow row = new WorkspaceRow();
            row.id = quoteRow.Id;
            row.objectApiName = 'Quote';
            row.name = firstNonBlank(new List<String>{quoteRow.Name, quoteRow.QuoteNumber});
            row.status = quoteRow.Status;
            row.ownerName = quoteRow.Owner != null ? quoteRow.Owner.Name : null;
            row.relatedName = quoteRow.Opportunity != null ? quoteRow.Opportunity.Name : null;
            row.activityDate = quoteRow.LastModifiedDate;
            row.amount = quoteRow.GrandTotal;
            data.rows.add(row);
        }
        return data;
    }

    private static WorkspaceData buildWorkOrderWorkspace() {
        WorkspaceData data = new WorkspaceData();
        data.title = 'Outdoor Living Work Orders';
        data.subtitle = 'Outdoor Living work-order workspace with live email history on the selected work order.';
        data.rows = new List<WorkspaceRow>();
        if (!Schema.SObjectType.WorkOrder.isAccessible()) {
            return data;
        }
        for (WorkOrder workOrderRow : [
            SELECT Id, WorkOrderNumber, Subject, Status, Work_Order_Type__c, Account.Name, CreatedDate, LastModifiedDate
            FROM WorkOrder
            WHERE RecordType.DeveloperName = 'Outdoor_Living' OR Work_Order_Type__c = 'Outdoor Living Install'
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ]) {
            WorkspaceRow row = new WorkspaceRow();
            row.id = workOrderRow.Id;
            row.objectApiName = 'WorkOrder';
            row.name = firstNonBlank(new List<String>{workOrderRow.Subject, workOrderRow.WorkOrderNumber});
            row.status = workOrderRow.Status;
            row.subStatus = workOrderRow.Work_Order_Type__c;
            row.relatedName = workOrderRow.Account != null ? workOrderRow.Account.Name : null;
            row.activityDate = workOrderRow.LastModifiedDate;
            data.rows.add(row);
        }
        return data;
    }

    private static WorkspaceData buildVoucherWorkspace() {
        WorkspaceData data = new WorkspaceData();
        data.title = 'Outdoor Living Vouchers';
        data.subtitle = 'Voucher email history can only be enabled after a live voucher object exists in this org.';
        data.backendMissing = true;
        data.backendMissingReason = 'Voucher history is unavailable because Voucher__c does not exist in this org.';
        data.rows = new List<WorkspaceRow>();
        return data;
    }

    private static List<WorkspaceRow> unwrap(List<SortableRow> rows, Integer maxRows) {
        List<WorkspaceRow> output = new List<WorkspaceRow>();
        Integer rowCount = Math.min(rows.size(), maxRows);
        for (Integer index = 0; index < rowCount; index++) {
            output.add(rows[index].row);
        }
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
}