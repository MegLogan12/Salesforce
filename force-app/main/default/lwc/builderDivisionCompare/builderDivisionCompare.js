import { LightningElement, api, wire, track } from 'lwc';
import getCompare from '@salesforce/apex/DivisionCompareController.getCompare';

export default class BuilderDivisionCompare extends LightningElement {
    @api recordId;
    @track selectedMetric = 'revenue';
    compareView;
    error;
    isLoading = true;

    @wire(getCompare, { parentAccountId: '$recordId', metric: '$selectedMetric' })
    wiredCompare({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.compareView = data;
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message ?? error?.message ?? 'An error occurred loading division data.';
            this.compareView = undefined;
        }
    }

    get isBlocked() {
        return this.compareView?.blocked;
    }

    get blockerReason() {
        return this.compareView?.blockerReason;
    }

    get rows() {
        const raw = this.compareView?.rows ?? [];
        const max = Math.max(...raw.map(r => r.metricValue), 1);
        return raw.map(r => ({
            ...r,
            barStyle: `width: ${Math.round((r.metricValue / max) * 100)}%`,
            metricFormatted: this._formatValue(r.metricValue)
        }));
    }

    get hasRows() {
        return (this.compareView?.rows ?? []).length > 0;
    }

    get revenueButtonClass() {
        return this.selectedMetric === 'revenue'
            ? 'slds-button slds-button_brand'
            : 'slds-button slds-button_neutral';
    }

    get ontimeButtonClass() {
        return this.selectedMetric === 'ontime'
            ? 'slds-button slds-button_brand'
            : 'slds-button slds-button_neutral';
    }

    get gpButtonClass() {
        return this.selectedMetric === 'gp'
            ? 'slds-button slds-button_brand'
            : 'slds-button slds-button_neutral';
    }

    handleMetric(event) {
        this.selectedMetric = event.target.dataset.metric;
    }

    _formatValue(value) {
        if (value == null) return '—';
        if (this.selectedMetric === 'revenue') {
            return '$' + Number(value).toLocaleString();
        }
        return Number(value).toFixed(1) + '%';
    }
}
