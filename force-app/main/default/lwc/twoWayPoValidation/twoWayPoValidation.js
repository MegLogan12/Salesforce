import { LightningElement, api, wire } from 'lwc';
import getPoRecord from '@salesforce/apex/PoValidationController.getPoRecord';

export default class TwoWayPoValidation extends LightningElement {
    @api recordId;
    poView;
    error;
    isLoading = true;

    @wire(getPoRecord, { recordId: '$recordId' })
    wiredPo({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.poView = data;
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message ?? error?.message ?? 'An error occurred loading the PO record.';
            this.poView = undefined;
        }
    }

    get overallBadgeClass() {
        const status = this.poView?.validationStatus;
        if (status === 'Validated') return 'slds-badge slds-badge_success';
        if (status === 'Held — Price' || status === 'Held — NFI') return 'slds-badge slds-badge_warning';
        return 'slds-badge';
    }

    get overallLabel() {
        return this.poView?.validationStatus ?? 'Not Validated';
    }

    get checks() {
        const pv = this.poView;
        if (!pv) return [];
        return [
            {
                label: 'Price check',
                actual: pv.poAmount != null ? `$${Number(pv.poAmount).toLocaleString()}` : '—',
                expected: pv.priceBookAmount != null ? `$${Number(pv.priceBookAmount).toLocaleString()}` : '—',
                variance: pv.priceVariancePct != null ? `${pv.priceVariancePct}%` : '—',
                result: pv.priceCheckPass ? 'PASS' : 'FAIL',
                badgeClass: pv.priceCheckPass ? 'slds-badge slds-badge_success' : 'slds-badge slds-badge_error'
            },
            {
                label: 'Qty check (NFI)',
                actual: pv.nfiCount != null ? String(pv.nfiCount) : '—',
                expected: '0',
                variance: '—',
                result: pv.qtyCheckPass ? 'PASS' : 'FAIL',
                badgeClass: pv.qtyCheckPass ? 'slds-badge slds-badge_success' : 'slds-badge slds-badge_error'
            }
        ];
    }
}
