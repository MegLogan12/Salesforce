import { LightningElement, api, wire } from 'lwc';
import getStageNodes from '@salesforce/apex/WorkOrderRecordController.getStageNodes';

export default class WorkOrderStageRail extends LightningElement {
    @api recordId;
    nodes = [];
    err;

    @wire(getStageNodes, { workOrderId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.nodes = data.map((n, i) => ({
                key: `${i}-${n.label}`,
                label: n.label,
                state: n.state,
                circleClass: `sc sc-${n.state}`,
                labelClass: `sl sl-${n.state}`
            }));
        } else if (error) this.err = error;
    }
}