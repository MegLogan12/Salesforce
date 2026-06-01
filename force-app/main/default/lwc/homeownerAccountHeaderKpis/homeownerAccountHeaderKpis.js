import { LightningElement, api, wire } from 'lwc';
import getKpis from '@salesforce/apex/HomeownerAccountKpisController.getKpis';

const CURRENCY_FORMATTER = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});

export default class HomeownerAccountHeaderKpis extends LightningElement {
    @api recordId;

    kpisData = null;
    error = null;
    isLoading = true;

    @wire(getKpis, { accountId: '$recordId' })
    wiredKpis({ data, error }) {
        if (data) {
            this.kpisData  = data;
            this.error     = null;
            this.isLoading = false;
        } else if (error) {
            this.error     = error?.body?.message || 'Unable to load KPIs.';
            this.isLoading = false;
        }
    }

    get hasError() {
        return !!this.error;
    }

    get openOpps() {
        return this.kpisData?.openOpps ?? '—';
    }

    get totalPipelineFormatted() {
        const v = this.kpisData?.totalPipeline;
        return v != null ? CURRENCY_FORMATTER.format(v) : '—';
    }

    get wonOpps() {
        return this.kpisData?.wonOpps ?? '—';
    }

    get totalClosedFormatted() {
        const v = this.kpisData?.totalClosed;
        return v != null ? CURRENCY_FORMATTER.format(v) : '—';
    }

    get openLeads() {
        return this.kpisData?.openLeads ?? '—';
    }

    get openTasks() {
        return this.kpisData?.openTasks ?? '—';
    }

    get openCases() {
        return this.kpisData?.openCases ?? '—';
    }
}
