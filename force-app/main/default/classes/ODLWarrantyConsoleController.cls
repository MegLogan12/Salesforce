public with sharing class ODLWarrantyConsoleController {
    public class RowData {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String homeownerName;
        @AuraEnabled public String homeownerUrl;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String workOrderUrl;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String caseUrl;
        @AuraEnabled public String caseStatus;
    }

    public class PageData {
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer openCount;
        @AuraEnabled public Integer noCaseCount;
        @AuraEnabled public Integer noWorkOrderCount;
        @AuraEnabled public List<RowData> rows;
    }

    @AuraEnabled(cacheable=true)
    public static PageData getPageData() {
        PageData data = new PageData();
        data.rows = new List<RowData>();
        data.totalCount = 0;
        data.openCount = 0;
        data.noCaseCount = 0;
        data.noWorkOrderCount = 0;

        for (Warranty_Record__c row : [
            SELECT Id, Name, Status__c, Homeowner_Account__c, Homeowner_Account__r.Name,
                   WorkOrder__c, WorkOrder__r.WorkOrderNumber, Case__c, Case__r.CaseNumber, Case__r.Status
            FROM Warranty_Record__c
            ORDER BY LastModifiedDate DESC
            LIMIT 75
        ]) {
            RowData out = new RowData();
            out.id = row.Id;
            out.url = '/' + row.Id;
            out.name = row.Name;
            out.status = row.Status__c;
            out.homeownerName = row.Homeowner_Account__r == null ? null : row.Homeowner_Account__r.Name;
            out.homeownerUrl = row.Homeowner_Account__c == null ? null : '/' + row.Homeowner_Account__c;
            out.workOrderNumber = row.WorkOrder__r == null ? null : row.WorkOrder__r.WorkOrderNumber;
            out.workOrderUrl = row.WorkOrder__c == null ? null : '/' + row.WorkOrder__c;
            out.caseNumber = row.Case__r == null ? null : row.Case__r.CaseNumber;
            out.caseUrl = row.Case__c == null ? null : '/' + row.Case__c;
            out.caseStatus = row.Case__r == null ? null : row.Case__r.Status;
            data.rows.add(out);
            data.totalCount++;
            if (!String.isBlank(row.Status__c) && row.Status__c != 'Closed' && row.Status__c != 'Resolved') data.openCount++;
            if (row.Case__c == null) data.noCaseCount++;
            if (row.WorkOrder__c == null) data.noWorkOrderCount++;
        }
        return data;
    }
}