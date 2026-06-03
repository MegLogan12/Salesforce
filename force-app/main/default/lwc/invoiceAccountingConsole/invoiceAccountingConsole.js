import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReadyToInvoice from '@salesforce/apex/InvoiceAccountingController.getReadyToInvoice';
import getInvoiced from '@salesforce/apex/InvoiceAccountingController.getInvoiced';
import getPaid from '@salesforce/apex/InvoiceAccountingController.getPaid';
import generateInvoice from '@salesforce/apex/InvoiceAccountingController.generateInvoice';
import markPaid from '@salesforce/apex/InvoiceAccountingController.markPaid';
import sendReminder from '@salesforce/apex/InvoiceAccountingController.sendReminder';

const READY_COLS = [
    { label: 'Work Order',     fieldName: 'name',         type: 'text' },
    { label: 'Builder',        fieldName: 'builder',      type: 'text' },
    { label: 'Community',      fieldName: 'community',    type: 'text' },
    { label: 'Total Revenue',  fieldName: 'totalRevenue', type: 'currency', typeAttributes: { currencyCode: 'USD' } },
    { label: 'Total Cost',     fieldName: 'totalCost',    type: 'currency', typeAttributes: { currencyCode: 'USD' } },
    { label: 'Status',         fieldName: 'status',       type: 'text' },
];

const INVOICE_COLS = [
    { label: 'Invoice',        fieldName: 'invoiceName',   type: 'text' },
    { label: 'Work Order',     fieldName: 'workOrderName', type: 'text' },
    { label: 'Builder',        fieldName: 'builder',       type: 'text' },
    { label: 'Total Revenue',  fieldName: 'totalRevenue',  type: 'currency', typeAttributes: { currencyCode: 'USD' } },
    { label: 'Balance Due',    fieldName: 'balance',       type: 'currency', typeAttributes: { currencyCode: 'USD' } },
    { label: 'Status',         fieldName: 'status',        type: 'text' },
    { label: 'Invoice Date',   fieldName: 'invoiceDate',   type: 'date' },
    { label: 'Due Date',       fieldName: 'dueDate',       type: 'date' },
    { label: 'GP Status',      fieldName: 'gpStatus',      type: 'text' },
];

const PAID_COLS = [
    { label: 'Invoice',        fieldName: 'invoiceName',  type: 'text' },
    { label: 'Builder',        fieldName: 'builder',      type: 'text' },
    { label: 'Total Revenue',  fieldName: 'totalRevenue', type: 'currency', typeAttributes: { currencyCode: 'USD' } },
    { label: 'Date Paid',      fieldName: 'datePaid',     type: 'date' },
    { label: 'Status',         fieldName: 'status',       type: 'text' },
];

const READY_ACTIONS  = [{ label: 'Generate Invoice', name: 'generate' }];
const INVOICED_ACTIONS = [
    { label: 'Mark Paid',      name: 'markpaid' },
    { label: 'Send Reminder',  name: 'reminder' },
];

export default class InvoiceAccountingConsole extends LightningElement {
    @track activeTab = 'ready';

    // Wire results stored so refreshApex can target them
    _wiredReady;
    _wiredInvoiced;
    _wiredPaid;

    readyRows    = [];
    invoicedRows = [];
    paidRows     = [];

    // Column / action configs
    readyCols      = READY_COLS;
    invoiceCols    = INVOICE_COLS;
    paidCols       = PAID_COLS;
    readyActions   = READY_ACTIONS;
    invoicedActions = INVOICED_ACTIONS;

    // G5 gate — export blocked until resolved
    g5Resolved = false;

    // ── Wire adapters ──────────────────────────────────────────────────────────

    @wire(getReadyToInvoice)
    wiredReady(result) {
        this._wiredReady = result;
        if (result.data) {
            this.readyRows = result.data;
        } else if (result.error) {
            this._showToast('Error', 'Failed to load ready-to-invoice work orders.', 'error');
        }
    }

    @wire(getInvoiced)
    wiredInvoiced(result) {
        this._wiredInvoiced = result;
        if (result.data) {
            this.invoicedRows = result.data;
        } else if (result.error) {
            this._showToast('Error', 'Failed to load invoiced records.', 'error');
        }
    }

    @wire(getPaid)
    wiredPaid(result) {
        this._wiredPaid = result;
        if (result.data) {
            this.paidRows = result.data;
        } else if (result.error) {
            this._showToast('Error', 'Failed to load paid invoices.', 'error');
        }
    }

    // ── Computed KPI properties ────────────────────────────────────────────────

    get readyCount()         { return this.readyRows    ? this.readyRows.length    : 0; }
    get invoicedCount()      { return this.invoicedRows ? this.invoicedRows.length : 0; }
    get paidCount()          { return this.paidRows     ? this.paidRows.length     : 0; }
    get pendingExportCount() { return this.paidRows     ? this.paidRows.length     : 0; }

    get hasReadyRows()    { return this.readyRows    && this.readyRows.length    > 0; }
    get hasInvoicedRows() { return this.invoicedRows && this.invoicedRows.length > 0; }
    get hasPaidRows()     { return this.paidRows     && this.paidRows.length     > 0; }

    // ── Tab state ──────────────────────────────────────────────────────────────

    get isReadyTab()    { return this.activeTab === 'ready'; }
    get isInvoicedTab() { return this.activeTab === 'invoiced'; }
    get isPaidTab()     { return this.activeTab === 'paid'; }

    get readyTabClass()    { return 'subtab' + (this.activeTab === 'ready'    ? ' active' : ''); }
    get invoicedTabClass() { return 'subtab' + (this.activeTab === 'invoiced' ? ' active' : ''); }
    get paidTabClass()     { return 'subtab' + (this.activeTab === 'paid'     ? ' active' : ''); }

    // ── Tab handler ────────────────────────────────────────────────────────────

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    // ── Row action handlers ────────────────────────────────────────────────────

    handleReadyAction(event) {
        const action = event.detail.action;
        const row    = event.detail.row;
        if (action.name === 'generate') {
            this._generateInvoice(row.workOrderId);
        }
    }

    handleInvoicedAction(event) {
        const action = event.detail.action;
        const row    = event.detail.row;
        if (action.name === 'markpaid') {
            this._markPaid(row.invoiceId);
        } else if (action.name === 'reminder') {
            this._sendReminder(row.invoiceId);
        }
    }

    // ── Imperative action methods ──────────────────────────────────────────────

    _generateInvoice(workOrderId) {
        generateInvoice({ workOrderId })
            .then(() => {
                this._showToast('Success', 'Invoice generated successfully.', 'success');
                return Promise.all([
                    refreshApex(this._wiredReady),
                    refreshApex(this._wiredInvoiced),
                ]);
            })
            .catch(error => {
                this._showToast('Error', this._errorMessage(error), 'error');
            });
    }

    _markPaid(invoiceId) {
        markPaid({ invoiceId })
            .then(() => {
                this._showToast('Success', 'Invoice marked as Paid.', 'success');
                return Promise.all([
                    refreshApex(this._wiredInvoiced),
                    refreshApex(this._wiredPaid),
                ]);
            })
            .catch(error => {
                this._showToast('Error', this._errorMessage(error), 'error');
            });
    }

    _sendReminder(invoiceId) {
        sendReminder({ invoiceId })
            .then(() => {
                this._showToast('Success', 'Reminder task created.', 'success');
            })
            .catch(error => {
                this._showToast('Error', this._errorMessage(error), 'error');
            });
    }

    // ── Utility ───────────────────────────────────────────────────────────────

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _errorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'An unexpected error occurred.';
    }
}
