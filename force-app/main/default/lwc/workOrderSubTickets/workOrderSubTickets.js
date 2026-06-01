import { LightningElement, api, wire } from 'lwc';
import getSubTickets from '@salesforce/apex/WorkOrderRecordController.getSubTickets';

export default class WorkOrderSubTickets extends LightningElement {
    @api recordId;
    data;
    error;
    loading = true;

    @wire(getSubTickets, { workOrderId: '$recordId' })
    wired({ data, error }) {
        this.loading = false;
        if (data) {
            this.data = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.data = undefined;
        }
    }

    get sections() {
        const d = this.data || {};
        return [
            { key: 'pull', label: 'Pull Tickets', rows: d.pullTickets || [] },
            { key: 'loading', label: 'Loading Tickets', rows: d.loadingTickets || [] },
            { key: 'aquaCheck', label: 'Aqua Check Tickets', rows: d.aquaCheckTickets || [] },
            { key: 'aquaInstall', label: 'Aqua Install Tickets', rows: d.aquaInstallTickets || [] }
        ].map((s) => Object.assign({}, s, {
            count: s.rows.length,
            isEmpty: s.rows.length === 0
        }));
    }
}