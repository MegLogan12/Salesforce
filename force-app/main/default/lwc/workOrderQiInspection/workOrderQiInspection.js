import { LightningElement, api, wire } from 'lwc';
import getQiInspection from '@salesforce/apex/WorkOrderRecordController.getQiInspection';

export default class WorkOrderQiInspection extends LightningElement {
    @api recordId;
    payload;
    err;

    @wire(getQiInspection, { workOrderId: '$recordId' })
    wired({ data, error }) {
        if (data) this.payload = data;
        else if (error) this.err = error;
    }

    get hasInspection() { return !!(this.payload && this.payload.inspection); }
    get thresholds() { return this.payload ? this.payload.thresholds : []; }
    get lineItems() {
        if (!this.payload) return [];
        return this.payload.lineItems.map((l) => ({
            ...l,
            rowClass: l.scoreFlag ? 'qi-row flagged' : 'qi-row'
        }));
    }
}