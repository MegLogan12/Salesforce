import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQueue from '@salesforce/apex/InvoiceAccountingController.getQueue';

const USD = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

export default class InvoiceAccountingConsole extends LightningElement {

    view         = null;
    errorMessage = null;
    isLoading    = true;

    @wire(getQueue)
    wiredQueue({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.view         = this._enrichView(data);
            this.errorMessage = null;
        } else if (error) {
            this.view         = null;
            this.errorMessage = this._errMsg(error);
        }
    }

    // ── Derived getters ───────────────────────────────────────────────────────

    get hasView()  { return this.view != null; }
    get hasError() { return this.errorMessage != null; }
    get hasRows()  { return this.view && this.view.rows && this.view.rows.length > 0; }

    get rows() {
        return (this.view && this.view.rows) ? this.view.rows : [];
    }

    get totalPipelineDisplay() {
        if (!this.view || this.view.totalPipeline == null) return '$0';
        return USD.format(this.view.totalPipeline);
    }

    get varianceCss() {
        const base = 'slds-text-heading_medium';
        if (!this.view) return base;
        return this.view.withVariance > 0
            ? base + ' slds-text-color_warning'
            : base;
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    handleGenerateInvoice(evt) {
        const woNumber = evt.currentTarget.dataset.wonumber || 'this work order';
        this.dispatchEvent(new ShowToastEvent({
            title:   'G5 Accounting Export',
            message: `G5 accounting export: open gate — cannot export ${woNumber} until G5 · Finance / Meg gate is resolved.`,
            variant: 'warning',
            mode:    'dismissible'
        }));
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    _enrichView(raw) {
        const rows = (raw.rows || []).map(r => ({
            ...r,
            amountDisplay:          r.amount        != null ? USD.format(r.amount)        : '—',
            invoiceAmountDisplay:   r.invoiceAmount != null ? USD.format(r.invoiceAmount) : '—',
            fieldCompleteDateDisplay: r.fieldCompleteDate
                ? new Date(r.fieldCompleteDate).toLocaleDateString(
                    'en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                : '—'
        }));
        return { ...raw, rows };
    }

    _errMsg(err) {
        if (typeof err === 'string') return err;
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'Unexpected error loading invoice data.';
    }
}
