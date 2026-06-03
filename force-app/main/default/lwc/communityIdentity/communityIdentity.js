import { LightningElement, api, wire } from 'lwc';
import getIdentity from '@salesforce/apex/CommunityRecordController.getIdentity';

export default class CommunityIdentity extends LightningElement {
    @api recordId;
    _data;
    error;

    @wire(getIdentity, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this._data = data;
            this.error = null;
        } else if (error) {
            this.error = error;
            this._data = null;
        }
    }

    get loaded() {
        return !!this._data;
    }

    get communityName() {
        return this._data?.community?.Name || '—';
    }

    get builderAccountId() {
        return this._data?.community?.Builder_Account__c || '—';
    }

    get createdDate() {
        return this._data?.community?.CreatedDate || null;
    }
}
