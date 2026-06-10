import { LightningElement, api, wire } from 'lwc';
import getLineItems from '@salesforce/apex/WorkOrderRecordController.getLineItems';

export default class WorkOrderLineItems extends LightningElement {
    @api recordId;
    items = [];
    err;

    @wire(getLineItems, { workOrderId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.items = data.map((li) => ({
                ...li,
                cardClass: li.scoreFlag ? 'li-card flagged' : 'li-card',
                scoreLabel: li.foremanScore == null ? '-' : li.foremanScore,
                scoreClass: this.scorePillClass(li.foremanScore)
            }));
        } else if (error) this.err = error;
    }

    scorePillClass(s) {
        if (s == null) return 'pill pgr';
        if (s >= 8) return 'pill pg';
        if (s >= 5) return 'pill pa';
        return 'pill pr';
    }

    get hasItems() { return this.items.length > 0; }
}