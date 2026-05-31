import { LightningElement, api, wire } from 'lwc';
import getHeader from '@salesforce/apex/WorkOrderRecordController.getHeader';

export default class WorkOrderHeader extends LightningElement {
    @api recordId;
    data;
    err;

    @wire(getHeader, { workOrderId: '$recordId' })
    wired({ data, error }) {
        if (data) this.data = data;
        else if (error) this.err = error;
    }

    get loaded() { return !!this.data; }

    get countdown() {
        if (!this.data || !this.data.foremanSubmitAt || this.data.qiSubmittedAt) return '';
        const submit = new Date(this.data.foremanSubmitAt).getTime();
        const deadline = submit + 48 * 60 * 60 * 1000;
        const remaining = deadline - Date.now();
        if (remaining <= 0) return 'QI overdue';
        const hrs = Math.floor(remaining / 3600000);
        const mins = Math.floor((remaining % 3600000) / 60000);
        return `${hrs}h ${mins}m to QI`;
    }

    get showCountdown() { return this.countdown !== ''; }

    get statusClass() {
        const s = (this.data && this.data.status) ? this.data.status.toLowerCase() : '';
        if (s.includes('complete') || s.includes('closed') || s.includes('approved')) return 'pill pg';
        if (s.includes('progress')) return 'pill pb';
        if (s.includes('cannot') || s.includes('cancel')) return 'pill pr';
        return 'pill pgr';
    }
}