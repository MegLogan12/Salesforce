import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getWorkOrdersForAccount from '@salesforce/apex/ParentAccountRollupController.getWorkOrdersForAccount';

function statusPillCls(status) {
    if (!status) return 'pill pgr';
    const s = status.toLowerCase();
    if (s.includes('complete') || s.includes('closed')) return 'pill pg';
    if (s.includes('scheduled')) return 'pill pb';
    if (s.includes('progress')) return 'pill pa';
    if (s.includes('breach') || s.includes('hold') || s.includes('block')) return 'pill pr';
    return 'pill pgr';
}

function qiPillCls(qi) {
    if (!qi) return 'pill pgr';
    const s = qi.toLowerCase();
    if (s.includes('approved') || s.includes('complete')) return 'pill pg';
    if (s.includes('due')) return 'pill pa';
    return 'pill pgr';
}

export default class WorkOrdersList extends NavigationMixin(LightningElement) {
    @api recordId;
    rows;
    error;
    communityFilter = '';
    statusFilter = '';

    @wire(getWorkOrdersForAccount, { accountId: '$recordId' })
    wired({ data, error }) {
        if (data) { this.rows = data; this.error = undefined; }
        else if (error) this.error = error.body ? error.body.message : error.message;
    }

    get hasRows() { return this.filtered && this.filtered.length > 0; }
    get count() { return this.filtered ? this.filtered.length : 0; }
    get totalCount() { return this.rows ? this.rows.length : 0; }

    get completeCount() { return this._countBy(s => s.includes('complete') || s.includes('closed')); }
    get scheduledCount() { return this._countBy(s => s.includes('scheduled')); }
    get inProgressCount() { return this._countBy(s => s.includes('progress')); }
    get breachCount() { return this._countBy(s => s.includes('breach') || s.includes('hold')); }

    _countBy(pred) {
        if (!this.rows) return 0;
        return this.rows.filter(r => pred((r.status || '').toLowerCase())).length;
    }

    get communityOptions() {
        const opts = [{ label: 'All Communities', value: '' }];
        if (!this.rows) return opts;
        const seen = new Set();
        this.rows.forEach(r => {
            if (r.communityName && !seen.has(r.communityName)) {
                seen.add(r.communityName);
                opts.push({ label: r.communityName, value: r.communityName });
            }
        });
        return opts;
    }

    get statusOptions() {
        const opts = [{ label: 'All Statuses', value: '' }];
        if (!this.rows) return opts;
        const seen = new Set();
        this.rows.forEach(r => {
            if (r.status && !seen.has(r.status)) {
                seen.add(r.status);
                opts.push({ label: r.status, value: r.status });
            }
        });
        return opts;
    }

    get filtered() {
        if (!this.rows) return [];
        return this.rows.filter(r =>
            (!this.communityFilter || r.communityName === this.communityFilter) &&
            (!this.statusFilter || r.status === this.statusFilter)
            ).map(r => ({
                ...r,
                statusPill: statusPillCls(r.status),
                qiPill: qiPillCls(r.qiStatus),
                qiLabel: r.qiStatus || ''
            }));
    }

    handleCommunityChange(event) { this.communityFilter = event.detail.value; }
    handleStatusChange(event) { this.statusFilter = event.detail.value; }

    handleNewWorkOrder() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'WorkOrder', actionName: 'new' }
        });
    }

    get showingNote() {
        return `Showing ${this.count} of ${this.totalCount} work orders`;
    }
}