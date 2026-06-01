import { LightningElement, api, wire } from 'lwc';
import getInvoicesForAccount from '@salesforce/apex/ParentAccountRollupController.getInvoicesForAccount';

function chipCls(status, daysOverdue) {
    const s = (status || '').toLowerCase();
    if (s === 'paid') return 'stat-chip chip-g';
    if (daysOverdue != null && daysOverdue > 0) return 'stat-chip chip-r';
    if (s === 'overdue') return 'stat-chip chip-r';
    if (s === 'sent' || s === 'open') return 'stat-chip chip-b';
    if (s === 'draft') return 'stat-chip chip-a';
    return 'stat-chip chip-b';
}

export default class InvoicesTable extends LightningElement {
    @api recordId;
    rows;
    error;

    @wire(getInvoicesForAccount, { accountId: '$recordId' })
    wired({ data, error }) {
        if (data) { this.rows = data; this.error = undefined; }
        else if (error) this.error = error.body ? error.body.message : error.message;
    }

    get hasRows() { return this.rows && this.rows.length > 0; }
    get count() { return this.rows ? this.rows.length : 0; }

    get viewRows() {
        if (!this.rows) return [];
        return this.rows.map(r => ({
            ...r,
            chipCls: chipCls(r.status, r.daysOverdue),
            statusLabel: r.status || '-'
        }));
    }
}