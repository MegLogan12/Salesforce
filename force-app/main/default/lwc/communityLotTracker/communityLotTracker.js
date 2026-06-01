import { LightningElement, api, wire } from 'lwc';
import getLots from '@salesforce/apex/CommunityRecordController.getLots';

const COLUMNS = [
    { label: 'Lot Number', fieldName: 'lotNumber', type: 'text' },
    { label: 'Lot Name', fieldName: 'name', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Active WO', fieldName: 'hasActiveWo', type: 'boolean' }
];

export default class CommunityLotTracker extends LightningElement {
    @api recordId;
    lots = [];
    error;
    _loaded = false;
    columns = COLUMNS;

    @wire(getLots, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.lots = data;
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
