import { LightningElement, api, wire } from 'lwc';
import getLotTracker from '@salesforce/apex/CommunityRecordController.getLotTracker';

export default class CommunityLotTracker extends LightningElement {
    @api recordId;
    data;
    error;

    @wire(getLotTracker, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.data = data;
            this.error = undefined;
        } else if (error) {
            this.data = undefined;
            this.error = (error.body && error.body.message) ? error.body.message : 'Unable to load lot tracker.';
        }
    }

    get loaded() { return !!this.data; }
    get hasError() { return !!this.error; }
    get hasSquares() { return this.data && this.data.squares && this.data.squares.length > 0; }
    get hasRows() { return this.data && this.data.rows && this.data.rows.length > 0; }
    get qiStyle() { return 'font-weight:500;'; }
}