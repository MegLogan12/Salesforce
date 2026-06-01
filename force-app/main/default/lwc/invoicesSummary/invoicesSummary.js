import { LightningElement, api, wire } from 'lwc';
import getInvoiceSummary from '@salesforce/apex/ParentAccountRollupController.getInvoiceSummary';

export default class InvoicesSummary extends LightningElement {
    @api recordId;
    summary;
    error;

    @wire(getInvoiceSummary, { accountId: '$recordId' })
    wired({ data, error }) {
        if (data) this.summary = data;
        else if (error) this.error = error.body ? error.body.message : error.message;
    }

    get ytdInvoiced() { return this.summary ? this.summary.ytdInvoiced : 0; }
    get outstandingBalance() { return this.summary ? this.summary.outstandingBalance : 0; }
    get overdueAmount() { return this.summary ? this.summary.overdueAmount : 0; }
    get avgDaysToPay() {
        const v = this.summary ? this.summary.avgDaysToPay : 0;
        return v ? Math.round(v) + ' days' : '-';
    }
}