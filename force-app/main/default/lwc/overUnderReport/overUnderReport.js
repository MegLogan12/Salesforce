import { LightningElement, api, wire } from 'lwc';
import getReport from '@salesforce/apex/OverUnderController.getReport';

export default class OverUnderReport extends LightningElement {
    @api recordId;
    report;
    error;
    isLoading = true;

    @wire(getReport, { workOrderId: '$recordId' })
    wiredReport({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.report = data;
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message ?? error?.message ?? 'An error occurred loading the report.';
            this.report = undefined;
        }
    }

    get lines() {
        return (this.report?.lines ?? []).map(line => ({
            ...line,
            varianceBadgeClass: this._varianceBadgeClass(line.variance)
        }));
    }

    get summary() {
        return this.report?.summary;
    }

    get hasLines() {
        return (this.report?.lines ?? []).length > 0;
    }

    _varianceBadgeClass(variance) {
        if (variance == null) return 'slds-badge';
        const v = Number(variance);
        if (isNaN(v) || v === 0) return 'slds-badge slds-badge_success';
        if (v > 0) return 'slds-badge slds-badge_warning';
        return 'slds-badge slds-badge_error';
    }
}
