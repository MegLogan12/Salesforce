import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQueue        from '@salesforce/apex/CloseoutApprovalController.getQueue';
import approveCloseout from '@salesforce/apex/CloseoutApprovalController.approveCloseout';

export default class CloseoutApprovalQueue extends LightningElement {
    @track view;
    @track isLoading = true;
    @track error;

    @wire(getQueue)
    wiredData({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.view  = this._enrichRows(data);
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : String(error);
            this.view  = undefined;
        }
    }

    // ── Derived getters ──────────────────────────────────────────────────────

    get hasRows() {
        return this.view && this.view.rows && this.view.rows.length > 0;
    }

    get varianceChipClass() {
        return (this.view && this.view.variance > 0)
            ? 'slds-badge slds-theme_error slds-m-right_x-small'
            : 'slds-badge slds-badge_lightest slds-m-right_x-small';
    }

    // ── Handlers ─────────────────────────────────────────────────────────────

    handleApproveClick(event) {
        const woId = event.currentTarget.dataset.id;
        this.view = this._setRowProp(woId, 'approving', true);
    }

    handleCancelApproval(event) {
        const woId = event.currentTarget.dataset.id;
        this.view = this._setRowProp(woId, 'approving', false);
    }

    handleNotesChange(event) {
        const woId = event.currentTarget.dataset.id;
        this.view = this._setRowProp(woId, 'draftNotes', event.detail.value);
    }

    handleConfirmApproval(event) {
        const woId = event.currentTarget.dataset.id;
        const row  = (this.view.rows || []).find(r => r.woId === woId);
        const notes = row ? (row.draftNotes || '') : '';

        approveCloseout({ workOrderId: woId, notes })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title:   'Approved',
                        message: 'Closeout approved successfully.',
                        variant: 'success'
                    })
                );
                // Remove the approved row from the local list
                const updatedRows = (this.view.rows || []).filter(r => r.woId !== woId);
                const newVariance = updatedRows.filter(r => r.variance).length;
                this.view = { ...this.view, rows: updatedRows, total: updatedRows.length, variance: newVariance };
            })
            .catch(err => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title:   'Error',
                        message: err.body ? err.body.message : String(err),
                        variant: 'error'
                    })
                );
            });
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    _enrichRows(data) {
        const rows = (data.rows || []).map(r => ({
            ...r,
            approving:        false,
            draftNotes:       r.notes || '',
            invoiceAmtDisplay: r.invoiceAmt != null ? r.invoiceAmt : '—',
            invoiceAmtClass:   r.variance
                ? 'slds-text-body_small slds-text-color_error slds-m-right_small'
                : 'slds-text-body_small slds-m-right_small'
        }));
        return { ...data, rows };
    }

    _setRowProp(woId, prop, value) {
        const rows = (this.view.rows || []).map(r =>
            r.woId === woId ? { ...r, [prop]: value } : r
        );
        return { ...this.view, rows };
    }
}
