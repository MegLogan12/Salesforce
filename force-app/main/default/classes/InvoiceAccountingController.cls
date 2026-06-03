/**
 * InvoiceAccountingController
 * Returns the invoice queue: completed WorkOrders where Invoice_Amount__c
 * has not yet been set. Supports the Invoice & Accounting Console (Screen 26).
 */
public with sharing class InvoiceAccountingController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class InvoiceRow {
        @AuraEnabled public Id      woId;
        @AuraEnabled public String  woNumber;
        @AuraEnabled public String  builderName;        // Account.Name
        @AuraEnabled public String  communityName;      // Community__r.Name
        @AuraEnabled public Decimal amount;             // GrandTotal (formula)
        @AuraEnabled public Decimal invoiceAmount;      // Invoice_Amount__c
        @AuraEnabled public Boolean hasVariance;        // Invoice_Amount__c != null && differs from GrandTotal
        @AuraEnabled public Date    fieldCompleteDate;  // Field_Complete_Date__c
        @AuraEnabled public String  status;
        @AuraEnabled public String  invoiceNotes;       // Invoice_Notes__c
    }

    public class InvoiceView {
        @AuraEnabled public Integer         readyToInvoice; // count of rows
        @AuraEnabled public Integer         withVariance;   // rows where hasVariance = true
        @AuraEnabled public Decimal         totalPipeline;  // sum of GrandTotal across all rows
        @AuraEnabled public List<InvoiceRow> rows;
    }

    // ─── AuraEnabled entry point ─────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static InvoiceView getQueue() {

        // FLS: WorkOrder object access
        Schema.DescribeSObjectResult woDesc = Schema.SObjectType.WorkOrder;
        if (!woDesc.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to WorkOrder object.');
        }

        List<WorkOrder> wos = [
            SELECT Id, WorkOrderNumber,
                   Account.Name,
                   Community__r.Name,
                   GrandTotal,
                   Invoice_Amount__c,
                   Field_Complete_Date__c,
                   Status,
                   Invoice_Notes__c
            FROM   WorkOrder
            WHERE  Status = 'Completed'
            AND    Invoice_Amount__c = null
            ORDER BY Field_Complete_Date__c DESC NULLS LAST
            LIMIT  100
        ];

        return buildView(wos);
    }

    // ─── Testable builder ─────────────────────────────────────────────────────

    @TestVisible
    private static InvoiceView buildView(List<WorkOrder> wos) {
        InvoiceView v   = new InvoiceView();
        v.rows          = new List<InvoiceRow>();
        Decimal pipeline = 0;
        Integer varianceCount = 0;

        for (WorkOrder wo : wos) {
            InvoiceRow r         = new InvoiceRow();
            r.woId               = wo.Id;
            r.woNumber           = wo.WorkOrderNumber;
            r.builderName        = (wo.Account != null) ? wo.Account.Name : null;
            r.communityName      = (wo.Community__r != null)
                                    ? wo.Community__r.Name
                                    : null;
            r.amount             = wo.GrandTotal;
            r.invoiceAmount      = wo.Invoice_Amount__c;
            // hasVariance: Invoice_Amount__c is populated but differs from GrandTotal
            r.hasVariance        = (wo.Invoice_Amount__c != null
                                    && wo.GrandTotal != null
                                    && wo.Invoice_Amount__c != wo.GrandTotal);
            r.fieldCompleteDate  = wo.Field_Complete_Date__c;
            r.status             = wo.Status;
            r.invoiceNotes       = wo.Invoice_Notes__c;

            if (r.hasVariance) varianceCount++;
            if (wo.GrandTotal != null) pipeline += wo.GrandTotal;

            v.rows.add(r);
        }

        v.readyToInvoice = v.rows.size();
        v.withVariance   = varianceCount;
        v.totalPipeline  = pipeline;
        return v;
    }
}
