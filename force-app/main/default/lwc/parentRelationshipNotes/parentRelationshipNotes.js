import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import SCOPE_SUMMARY from '@salesforce/schema/Account.Scope_Summary__c';
import ADDITIONAL_NOTES from '@salesforce/schema/Account.Additional_Scope_Notes__c';
import HOME_TYPES from '@salesforce/schema/Account.Home_Types__c';

const FIELDS = [SCOPE_SUMMARY, ADDITIONAL_NOTES, HOME_TYPES];

export default class ParentRelationshipNotes extends LightningElement {
    @api recordId;
    _record;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) { this._record = data; }
        else if (error) { this._record = null; }
    }

    get scopeSummary() { return getFieldValue(this._record, SCOPE_SUMMARY) || ''; }
    get additionalNotes() { return getFieldValue(this._record, ADDITIONAL_NOTES) || ''; }
    get homeTypes() { return getFieldValue(this._record, HOME_TYPES) || ''; }

    get hasAnyContent() {
        return !!(this.scopeSummary || this.additionalNotes || this.homeTypes);
    }
}