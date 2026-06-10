import { LightningElement, api, wire } from 'lwc';
import getLotTracker from '@salesforce/apex/CommunityRecordController.getLotTracker';

const COLUMNS = [
    { label: 'Lot', fieldName: 'lotLabel', type: 'text' },
    { label: 'Work Order', fieldName: 'workOrderName', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Foreman', fieldName: 'foreman', type: 'text' },
    { label: 'Scheduled', fieldName: 'scheduled', type: 'text' }
];

export default class CommunityLotTracker extends LightningElement {
    @api recordId;
    lots = [];
    error;
    _loaded = false;
    columns = COLUMNS;

    @wire(getLotTracker, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.lots = data.rows ?? [];
            this.error = null;
            this._loaded = true;
        } else if (error) {
            this.error = error;
            this.lots = [];
            this._loaded = true;
        }
    }

    get loaded() {
        return this._loaded;
    }

    get hasLots() {
        return this.lots.length > 0;
    }
}
