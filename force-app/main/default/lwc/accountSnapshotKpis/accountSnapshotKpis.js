import { LightningElement, api, wire } from 'lwc';
import getDivisionKpis from '@salesforce/apex/ParentAccountRollupController.getDivisionKpis';

export default class AccountSnapshotKpis extends LightningElement {
    @api recordId;
    kpis;
    error;

    @wire(getDivisionKpis, { accountId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.kpis = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
        }
    }

    get activeCommunities() { return this.kpis ? this.kpis.activeCommunities : 0; }
    get openWorkOrders() { return this.kpis ? this.kpis.openWorkOrders : 0; }
    get pendingChangeOrders() { return this.kpis ? this.kpis.pendingChangeOrders : 0; }

    get pendingClass() {
        const n = this.pendingChangeOrders || 0;
        return n > 0 ? 'kn kn-amber' : 'kn';
    }

    get ytdInvoicedDisplay() {
        const v = this.kpis ? Number(this.kpis.ytdInvoiced) : 0;
        if (!v || v <= 0) return '$0';
        if (v >= 1000000) return '$' + (v / 1000000).toFixed(1) + 'M';
        if (v >= 1000) return '$' + Math.round(v / 1000) + 'K';
        return '$' + Math.round(v);
    }
}