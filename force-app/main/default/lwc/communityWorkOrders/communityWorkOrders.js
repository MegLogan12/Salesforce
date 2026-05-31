import { LightningElement, api, wire } from 'lwc';
import getWorkOrders from '@salesforce/apex/CommunityRecordController.getWorkOrders';

export default class CommunityWorkOrders extends LightningElement {
    @api recordId;
    data;

    @wire(getWorkOrders, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.data = data;
        } else if (error) {
            this.data = { rows: [], completeCount: 0, scheduledCount: 0, qiDueCount: 0 };
        }
    }

    get loaded() { return !!this.data; }
    get hasRows() { return this.data && this.data.rows && this.data.rows.length > 0; }
}