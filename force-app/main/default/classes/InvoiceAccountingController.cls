/**
 * InvoiceAccountingController
 *
 * Backend controller for the Invoice Accounting Console LWC.
 * Provides read-only wire methods and action methods for invoice lifecycle
 * management: Generate Invoice, Mark Paid, and Send Reminder.
 *
 * Work_Order__c is the CUSTOM object (prefix 'a' namespace).
 * Invoice__c lookup fields Builder_WorkOrder__c, LOVING_Work_Order__c, and
 * Work_Order__c all point to the STANDARD WorkOrder object — never pass a
 * custom Work_Order__c Id to those fields.
 *
 * Gate G5 (accounting system export target) is unresolved.
 * AccountingExportBatch is blocked until G5 is decided.
 */
public with sharing class InvoiceAccountingController {

    // ─── Inner row classes ────────────────────────────────────────────────────

    public class WoRow {
        @AuraEnabled public Id      workOrderId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  builder;
        @AuraEnabled public String  community;
        @AuraEnabled public Decimal totalRevenue;
        @AuraEnabled public Decimal totalCost;
        @AuraEnabled public String  status;
        @AuraEnabled public Date    closeoutDate;
    }

    public class InvoiceRow {
        @AuraEnabled public Id      invoiceId;
        @AuraEnabled public String  invoiceName;
        @AuraEnabled public String  workOrderName;
        @AuraEnabled public String  builder;
        @AuraEnabled public Decimal totalRevenue;
        @AuraEnabled public Decimal balance;
        @AuraEnabled public String  status;
        @AuraEnabled public Date    invoiceDate;
        @AuraEnabled public Date    dueDate;
        @AuraEnabled public Date    datePaid;
        @AuraEnabled public String  gpStatus;
    }

    // ─── Read-only wire methods ───────────────────────────────────────────────

    /**
     * Returns Work_Order__c records that are ready to be invoiced:
     * Invoice_Generated__c = false AND Status__c = 'Closeout Approved'.
     * Limited to 200 records ordered by LastModifiedDate DESC.
     */
    @AuraEnabled(cacheable=true)
    public static List<WoRow> getReadyToInvoice() {
        List<WoRow> rows = new List<WoRow>();
        for (Work_Order__c wo : [
            SELECT Id, Name, Builder__c, Community__c,
                   Total_Revenue__c, Total_Cost__c, Status__c,
                   LastModifiedDate
            FROM   Work_Order__c
            WHERE  Invoice_Generated__c = false
              AND  Status__c = 'Closeout Approved'
            ORDER BY LastModifiedDate DESC
            LIMIT  200
        ]) {
            WoRow r = new WoRow();
            r.workOrderId  = wo.Id;
            r.name         = wo.Name;
            r.builder      = wo.Builder__c;
            r.community    = wo.Community__c;
            r.totalRevenue = wo.Total_Revenue__c;
            r.totalCost    = wo.Total_Cost__c;
            r.status       = wo.Status__c;
            r.closeoutDate = wo.LastModifiedDate.date();
            rows.add(r);
        }
        return rows;
    }

    /**
     * Returns open invoices (Status__c not 'Paid' and not null).
     * Limited to 200 records ordered by Invoice_Date__c DESC.
     */
    @AuraEnabled(cacheable=true)
    public static List<InvoiceRow> getInvoiced() {
        List<InvoiceRow> rows = new List<InvoiceRow>();
        for (Invoice__c inv : [
            SELECT Id, Name, Builder__c,
                   Total_Revenue__c, Balance_Due__c, Status__c,
                   Invoice_Date__c, Due_Date__c, Date_Paid__c,
                   GP_Status__c
            FROM   Invoice__c
            WHERE  Status__c != 'Paid'
              AND  Status__c != null
            ORDER BY Invoice_Date__c DESC NULLS LAST
            LIMIT  200
        ]) {
            rows.add(toInvoiceRow(inv));
        }
        return rows;
    }

    /**
     * Returns paid invoices, ordered by Date_Paid__c DESC.
     * Limited to 200 records.
     */
    @AuraEnabled(cacheable=true)
    public static List<InvoiceRow> getPaid() {
        List<InvoiceRow> rows = new List<InvoiceRow>();
        for (Invoice__c inv : [
            SELECT Id, Name, Builder__c,
                   Total_Revenue__c, Balance_Due__c, Status__c,
                   Invoice_Date__c, Due_Date__c, Date_Paid__c,
                   GP_Status__c
            FROM   Invoice__c
            WHERE  Status__c = 'Paid'
            ORDER BY Date_Paid__c DESC NULLS LAST
            LIMIT  200
        ]) {
            rows.add(toInvoiceRow(inv));
        }
        return rows;
    }

    // ─── Action methods ───────────────────────────────────────────────────────

    /**
     * Generates an Invoice__c from a custom Work_Order__c record.
     *
     * IMPORTANT: The lookup fields Builder_WorkOrder__c, LOVING_Work_Order__c,
     * and Work_Order__c on Invoice__c all point to the STANDARD WorkOrder
     * object.  The Id passed here is a custom Work_Order__c Id, so those
     * fields are intentionally left null.  The source is captured in Notes__c.
     *
     * @param  workOrderId  Id of a custom Work_Order__c record
     * @return              Id of the newly created Invoice__c
     */
    @AuraEnabled
    public static Id generateInvoice(Id workOrderId) {
        Work_Order__c wo = [
            SELECT Id, Name, Builder__c,
                   Total_Revenue__c, Total_Cost__c,
                   Builder_Market_Account__c, Division_Account__c,
                   Community__c
            FROM   Work_Order__c
            WHERE  Id = :workOrderId
            LIMIT  1
        ];

        Invoice__c inv = new Invoice__c(
            Status__c                  = 'Pending Send',
            Invoice_Date__c            = Date.today(),
            Due_Date__c                = Date.today().addDays(30),
            Total_Revenue__c           = wo.Total_Revenue__c,
            Total_Cost__c              = wo.Total_Cost__c,
            Builder_Market_Account__c  = wo.Builder_Market_Account__c,
            Division_Account__c        = wo.Division_Account__c,
            Notes__c                   = 'Generated from Work Order: ' + wo.Name
        );
        insert inv;

        // Mark the source Work Order as invoiced and link the closing invoice
        Work_Order__c woUpdate = new Work_Order__c(
            Id                  = wo.Id,
            Invoice_Generated__c = true,
            Closing_Invoice__c  = inv.Id
        );
        update woUpdate;

        return inv.Id;
    }

    /**
     * Marks an invoice as Paid and updates the linked Work_Order__c.
     *
     * @param invoiceId  Id of the Invoice__c to mark paid
     */
    @AuraEnabled
    public static void markPaid(Id invoiceId) {
        Invoice__c inv = [
            SELECT Id, Status__c, Payment_Status__c
            FROM   Invoice__c
            WHERE  Id = :invoiceId
            LIMIT  1
        ];

        inv.Status__c          = 'Paid';
        inv.Date_Paid__c       = Date.today();
        inv.Payment_Status__c  = 'Paid';
        update inv;

        // Update linked Work_Order__c.Paid__c if it points to this invoice
        List<Work_Order__c> linkedWOs = [
            SELECT Id, Paid__c
            FROM   Work_Order__c
            WHERE  Closing_Invoice__c = :invoiceId
            LIMIT  200
        ];
        if (!linkedWOs.isEmpty()) {
            for (Work_Order__c wo : linkedWOs) {
                wo.Paid__c = true;
            }
            update linkedWOs;
        }
    }

    /**
     * Creates a follow-up Task as a reminder for an outstanding invoice.
     * Email is intentionally NOT sent — task creation only.
     *
     * @param invoiceId  Id of the Invoice__c that needs a reminder
     */
    @AuraEnabled
    public static void sendReminder(Id invoiceId) {
        Invoice__c inv = [
            SELECT Id, Name
            FROM   Invoice__c
            WHERE  Id = :invoiceId
            LIMIT  1
        ];

        Task t = new Task(
            Subject      = 'Invoice Reminder: ' + inv.Name,
            WhatId       = invoiceId,
            ActivityDate = Date.today().addDays(3),
            Type         = 'Reminder',
            Status       = 'Open'
        );
        insert t;
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    private static InvoiceRow toInvoiceRow(Invoice__c inv) {
        InvoiceRow r = new InvoiceRow();
        r.invoiceId    = inv.Id;
        r.invoiceName  = inv.Name;
        r.builder      = inv.Builder__c;
        r.totalRevenue = inv.Total_Revenue__c;
        r.balance      = inv.Balance_Due__c;
        r.status       = inv.Status__c;
        r.invoiceDate  = inv.Invoice_Date__c;
        r.dueDate      = inv.Due_Date__c;
        r.datePaid     = inv.Date_Paid__c;
        r.gpStatus     = inv.GP_Status__c;
        return r;
    }
}
