import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import EXHIBIT_A from '@salesforce/schema/Account.Exhibit_A_Signed__c';
import EXHIBIT_B from '@salesforce/schema/Account.Exhibit_B_Signed__c';
import EXHIBIT_C from '@salesforce/schema/Account.Exhibit_C_Signed__c';
import EXHIBIT_D from '@salesforce/schema/Account.Exhibit_D_Signed__c';
import CERTS_FIELD from '@salesforce/schema/Account.Certs_On_File__c';
import W9_FIELD from '@salesforce/schema/Account.W9_On_File__c';
import ADD_INSURED from '@salesforce/schema/Account.Additional_Insured_Required__c';
import WAIVER_SUBR from '@salesforce/schema/Account.Waiver_Of_Subrogation_Required__c';
import LICENSE_NUM from '@salesforce/schema/Account.LOVING_License_Number__c';

const FIELDS = [EXHIBIT_A, EXHIBIT_B, EXHIBIT_C, EXHIBIT_D, CERTS_FIELD, W9_FIELD, ADD_INSURED, WAIVER_SUBR, LICENSE_NUM];

export default class ParentUpsellOpportunities extends LightningElement {
    @api recordId;
    _record;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) { this._record = data; }
        else if (error) { this._record = null; }
    }

    get checkItems() {
        if (!this._record) return [];
        const items = [
            { id: 'exhibitA', label: 'Exhibit A Signed', done: getFieldValue(this._record, EXHIBIT_A) === true },
            { id: 'exhibitB', label: 'Exhibit B Signed', done: getFieldValue(this._record, EXHIBIT_B) === true },
            { id: 'exhibitC', label: 'Exhibit C Signed', done: getFieldValue(this._record, EXHIBIT_C) === true },
            { id: 'exhibitD', label: 'Exhibit D Signed', done: getFieldValue(this._record, EXHIBIT_D) === true },
            { id: 'certs', label: 'Certs On File', done: getFieldValue(this._record, CERTS_FIELD) === true },
            { id: 'w9', label: 'W9 On File', done: getFieldValue(this._record, W9_FIELD) === true },
            { id: 'license', label: 'License Number', done: !!(getFieldValue(this._record, LICENSE_NUM)) }
        ];
        return items.map(item => ({
            ...item,
            status: item.done ? 'done' : 'pending',
            statusLabel: item.done ? '✓ Complete' : 'Action needed',
            chipClass: item.done ? 'chip cg' : 'chip ca'
        }));
    }

    get pendingCount() {
        return this.checkItems.filter(i => i.status !== 'done').length;
    }

    get hasPending() { return this.pendingCount > 0; }
}