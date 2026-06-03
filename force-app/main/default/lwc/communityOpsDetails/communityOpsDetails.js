import { LightningElement, api, wire } from 'lwc';
import getHeader from '@salesforce/apex/CommunityRecordController.getHeader';

export default class CommunityOpsDetails extends LightningElement {
    @api recordId;
    _data;
    error;

    @wire(getHeader, { communityId: '$recordId' })
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

    get latestWo() {
        const wos = this._data?.openWorkOrders;
        return wos && wos.length > 0 ? wos[0] : null;
    }

    get latestWoStatus() {
        return this.latestWo?.status || '—';
    }

    get latestWoNumber() {
        return this.latestWo?.workOrderNumber || '—';
    }

    get latestTask() {
        const tasks = this._data?.recentActivity;
        return tasks && tasks.length > 0 ? tasks[0] : null;
    }

    get latestTaskDate() {
        return this.latestTask?.activityDate || null;
    }

    get latestTaskSubject() {
        return this.latestTask?.subject || '—';
    }
}
