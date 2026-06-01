import { LightningElement, api, wire } from 'lwc';
import getPageData from '@salesforce/apex/CommunityRecordController.getPageData';

export default class CommunityIdentity extends LightningElement {
    @api recordId;
    _data;
    error;

    @wire(getPageData, { communityId: '$recordId' })
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
