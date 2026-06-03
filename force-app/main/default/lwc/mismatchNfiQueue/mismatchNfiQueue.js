import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMismatches from '@salesforce/apex/MismatchNfiController.getMismatches';

const BADGE_PRICE = 'slds-badge slds-theme_warning slds-m-right_x-small';
const BADGE_QTY   = 'slds-badge slds-theme_error slds-m-right_x-small';
const BADGE_BOTH  = 'slds-badge slds-theme_shade slds-m-right_x-small';
const BADGE_LIGHT = 'slds-badge slds-badge_lightest slds-m-right_x-small';

export default class MismatchNfiQueue extends LightningElement {
    @track view;
    @track isLoading = true;
    @track error;

    @wire(getMismatches)
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

    get priceChipClass() {
        return (this.view && this.view.priceCount > 0)
            ? BADGE_PRICE
            : BADGE_LIGHT;
    }

    get qtyChipClass() {
        return (this.view && this.view.qtyCount > 0)
            ? BADGE_QTY
            : BADGE_LIGHT;
    }

    get bothChipClass() {
        return (this.view && this.view.bothCount > 0)
            ? BADGE_BOTH
            : BADGE_LIGHT;
    }

    // ── Handlers ─────────────────────────────────────────────────────────────

    handleMarkReviewed(event) {
        const poId = event.currentTarget.dataset.id;
        this.dispatchEvent(
            new ShowToastEvent({
                title:   'Mark Reviewed',
                message: 'Review action for PO ' + poId + ' is not yet implemented.',
                variant: 'info'
            })
        );
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    _enrichRows(data) {
        const rows = (data.rows || []).map(r => ({
            ...r,
            badgeClass: this._badgeClass(r.mismatchType)
        }));
        return { ...data, rows };
    }

    _badgeClass(type) {
        if (type === 'Price') return BADGE_PRICE;
        if (type === 'Qty')   return BADGE_QTY;
        if (type === 'Both')  return BADGE_BOTH;
        return BADGE_LIGHT;
    }
}
