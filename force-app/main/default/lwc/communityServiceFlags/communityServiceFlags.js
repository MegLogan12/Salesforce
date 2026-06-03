import { LightningElement, api, wire } from 'lwc';
import getServiceFlags from '@salesforce/apex/CommunityRecordController.getServiceFlags';

const TODAY = new Date();

export default class CommunityServiceFlags extends LightningElement {
    @api recordId;
    _data;
    error;

    @wire(getServiceFlags, { communityId: '$recordId' })
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

    get overdueTasks() {
        const tasks = this._data?.recentActivity || [];
        return tasks.filter((t) => {
            if (!t.activityDate) return false;
            return new Date(t.activityDate) < TODAY && t.status !== 'Completed';
        }).map((t) => ({
            id: t.id,
            subject: t.subject,
            activityDate: t.activityDate
        }));
    }

    get hasOverdueTasks() {
        return this.overdueTasks.length > 0;
    }

    get flags() {
        const result = [];
        const woCount = this._data?.openWorkOrderCount ?? 0;
        if (woCount >= 3) {
            result.push({
                id: 'wo-high',
                icon: '⚠',
                message: `${woCount} open work orders — high activity volume`,
                cls: 'flag-row flag-warn'
            });
        }
        if (this.hasOverdueTasks) {
            result.push({
                id: 'overdue-tasks',
                icon: '!',
                message: `${this.overdueTasks.length} overdue task(s) require attention`,
                cls: 'flag-row flag-alert'
            });
        }
        return result;
    }

    get hasFlags() {
        return this.flags.length > 0;
    }
}
