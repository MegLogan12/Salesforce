import { LightningElement, api, wire } from 'lwc';
import getPageData from '@salesforce/apex/CommunityRecordController.getPageData';

export default class CommunityScope extends LightningElement {
    @api recordId;
    _data;
    error;

    @wire(getPageData, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this._data = data;
            this.error = null;
        } else if (error) {
            this.error = error;
            this._data = null;
        }
    }

    get loaded() {
        return !!this._data;
    }

    get workTypeRows() {
        const wos = this._data?.openWorkOrders || [];
        const counts = {};
        for (const wo of wos) {
            const wt = wo.workType || 'Unspecified';
            counts[wt] = (counts[wt] || 0) + 1;
        }
        return Object.entries(counts).map(([workType, count]) => ({ workType, count }));
    }

    get hasWorkTypeRows() {
        return this.workTypeRows.length > 0;
    }

    get changeOrders() {
        return this._data?.changeOrders || [];
    }

    get hasChangeOrders() {
        return this.changeOrders.length > 0;
    }
}
