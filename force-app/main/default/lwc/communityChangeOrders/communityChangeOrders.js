import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import COMMUNITY_NAME from '@salesforce/schema/Community__c.Name';
import NUM_LOTS from '@salesforce/schema/Community__c.Number_Of_Lots__c';
import SCOPE_NOTES from '@salesforce/schema/Community__c.Scope_Notes__c';

const FIELDS = [COMMUNITY_NAME, NUM_LOTS, SCOPE_NOTES];

export default class CommunityChangeOrders extends LightningElement {
    @api recordId;
    _record;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) { this._record = data; }
        else if (error) { this._record = undefined; }
    }

    get isLoaded() { return this._record !== undefined; }
    get communityName() { return getFieldValue(this._record, COMMUNITY_NAME) || '—'; }
    get numLots() { return getFieldValue(this._record, NUM_LOTS) || '—'; }

    handleViewLots() {
        // eslint-disable-next-line no-console
        console.log('Navigate to Lot Tracker tab — wire up via App Builder or NavigationMixin as needed.');
    }
}