import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReadyToInvoice from '@salesforce/apex/InvoiceAccountingController.getReadyToInvoice';
import getInvoiced from '@salesforce/apex/InvoiceAccountingController.getInvoiced';
import getPaid from '@salesforce/apex/InvoiceAccountingController.getPaid';
import generateInvoice from '@salesforce/apex/InvoiceAccountingController.generateInvoice';
import markPaid from '@salesforce/apex/InvoiceAccountingController.markPaid';
import sendReminder from '@salesforce/apex/InvoiceAccountingController.sendReminder';

const USD_FORMAT = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});

function fmtCurrency(val) {
    if (val == null) return '—';
    return USD_FORMAT.format(val);
}

function applyFullWidthLayout(host) {
    try {
        if (typeof window === 'undefined' || !host) return false;
        const rect = host.getBoundingClientRect();
        if (!rect || rect.width === 0) return false;
        const vw = window.innerWidth;
        if (rect.right < vw - 20) {
            host.style.setProperty('width', `${vw - rect.left}px`, 'important');
            host.style.setProperty('max-width', 'none', 'important');
        }
        if (rect.top > 95) {
            host.style.setProperty('margin-top', `-${Math.round(rect.top - 90)}px`, 'important');
        }
        return true;
    } catch (e) {
        return false;
    }
}
export default class InvoiceAccountingConsole extends LightningElement {
    @track activeTab = 'ready';

    _wiredReady;
    _wiredInvoiced;
    _wiredPaid;

    readyRows    = [];
    invoicedRows = [];
    paidRows     = [];

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

    // ── Computed row formatters ────────────────────────────────────────────────

    get readyRowsFormatted() {
        if (!this.readyRows) return [];
        return this.readyRows.map(row => Object.assign({}, row, {
            totalRevenueFormatted: fmtCurrency(row.totalRevenue),
            totalCostFormatted:    fmtCurrency(row.totalCost)
        }));
    }

    get invoicedRowsFormatted() {
        if (!this.invoicedRows) return [];
        return this.invoicedRows.map(row => Object.assign({}, row, {
            totalRevenueFormatted: fmtCurrency(row.totalRevenue),
            balanceFormatted:      fmtCurrency(row.balance)
        }));
    }

    get paidRowsFormatted() {
        if (!this.paidRows) return [];
        return this.paidRows.map(row => Object.assign({}, row, {
            totalRevenueFormatted: fmtCurrency(row.totalRevenue)
        }));
    }

    // ── Computed KPI properties ────────────────────────────────────────────────

    get readyCount()    { return this.readyRows    ? this.readyRows.length    : 0; }
    get invoicedCount() { return this.invoicedRows ? this.invoicedRows.length : 0; }
    get paidCount()     { return this.paidRows     ? this.paidRows.length     : 0; }

    get arOpenFormatted() {
        if (!this.invoicedRows || this.invoicedRows.length === 0) return '$0';
        const total = this.invoicedRows.reduce((sum, row) => sum + (row.totalRevenue || 0), 0);
        return fmtCurrency(total);
    }

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

    // ── Tab handlers ───────────────────────────────────────────────────────────

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleWorkQueue() {
        this.activeTab = 'ready';
    }

    handleExportBatch() {
        this._showToast('Export batch', 'Accounting export is pending Gate G5 resolution.', 'info');
    }

    // ── Inline row action handlers ─────────────────────────────────────────────

    handleGenerateInvoice(event) {
        const workOrderId = event.currentTarget.dataset.id;
        this._generateInvoice(workOrderId);
    }

    handleMarkPaid(event) {
        const invoiceId = event.currentTarget.dataset.id;
        this._markPaid(invoiceId);
    }

    handleSendReminder(event) {
        const invoiceId = event.currentTarget.dataset.id;
        this._sendReminder(invoiceId);
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
    renderedCallback() {
        applyFullWidthLayout(this.template.host);
    }

}
