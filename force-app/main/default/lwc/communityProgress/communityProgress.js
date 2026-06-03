import { LightningElement, api, wire } from 'lwc';
import getProgress from '@salesforce/apex/CommunityRecordController.getProgress';

export default class CommunityProgress extends LightningElement {
    @api recordId;
    _data;
    error;

    @wire(getProgress, { communityId: '$recordId' })
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

    get openWoCount() {
        return this._data?.openWorkOrderCount ?? 0;
    }

    get recentActivityCount() {
        return this._data?.recentActivity?.length ?? 0;
    }

    get changeOrderCount() {
        return this._data?.changeOrders?.length ?? 0;
    }

    get hasOpenWos() {
        return this.openWoCount > 0;
    }

    get totalWoCapacity() {
        // Use a soft capacity of 10 for display purposes
        return Math.max(this.openWoCount, 10);
    }

    get woProgressValue() {
        if (this.totalWoCapacity === 0) return 0;
        return Math.min(100, Math.round((this.openWoCount / this.totalWoCapacity) * 100));
    }
}
