import { LightningElement, api, wire } from 'lwc';
import getHeader from '@salesforce/apex/CommunityRecordController.getHeader';

export default class CommunityHeaderKpis extends LightningElement {
    @api recordId;
    data;
    err;

    @wire(getHeader, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.data = data;
            this.err = undefined;
        } else if (error) {
            this.data = undefined;
            this.err = (error.body && error.body.message) ? error.body.message : 'Unable to load community header.';
        }
    }

    get loaded() { return !!this.data; }
    get hasError() { return !!this.err; }
}