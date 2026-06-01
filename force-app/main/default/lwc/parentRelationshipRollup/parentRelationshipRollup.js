import { LightningElement, api, wire } from 'lwc';
import getParentRollup from '@salesforce/apex/ParentAccountRollupController.getParentRollup';

export default class ParentRelationshipRollup extends LightningElement {
    @api recordId;
    data;
    error;

    @wire(getParentRollup, { parentAccountId: '$recordId' })
    wired({ data, error }) {
        if (data) { this.data = data; this.error = undefined; }
        else if (error) { this.error = error.body ? error.body.message : error.message; }
    }

    get hasError() { return !!this.error; }

    get divisions() { return this.data ? this.data.divisionCount : 0; }
    get activeCommunities() { return this.data ? this.data.activeCommunities : 0; }
    get contractedLots() { return this.data ? this.data.contractedLots : 0; }
    get lotsComplete() { return this.data ? this.data.lotsComplete : 0; }
    get openWorkOrders() { return this.data ? this.data.openWorkOrders : 0; }
    get ytdRevenue() { return this.data ? this.formatMoney(this.data.ytdRevenue) : '$0'; }
    get avgGp() {
        if (!this.data || this.data.avgGp == null) return '0%';
        return Math.round(this.data.avgGp) + '%';
    }

    formatMoney(v) {
        if (!v) return '$0';
        if (v >= 1000000) return '$' + (v / 1000000).toFixed(1) + 'M';
        if (v >= 1000) return '$' + Math.round(v / 1000) + 'K';
        return '$' + Math.round(v);
    }
}