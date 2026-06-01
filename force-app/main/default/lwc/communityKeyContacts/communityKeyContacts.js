import { LightningElement, api, wire } from 'lwc';
import getKeyContacts from '@salesforce/apex/CommunityRecordController.getKeyContacts';

export default class CommunityKeyContacts extends LightningElement {
    @api recordId;
    rows = [];
    error;

    @wire(getKeyContacts, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.rows = data;
            this.error = undefined;
        } else if (error) {
            this.rows = [];
            this.error = (error.body && error.body.message) ? error.body.message : 'Unable to load key contacts.';
        }
    }

    get hasRows() { return this.rows && this.rows.length > 0; }
    get hasError() { return !!this.error; }
}