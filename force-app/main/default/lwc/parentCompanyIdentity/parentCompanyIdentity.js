import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/Account.Name';
import TYPE_FIELD from '@salesforce/schema/Account.Type';
import MARKET_FIELD from '@salesforce/schema/Account.Market__c';
import TERRITORY_FIELD from '@salesforce/schema/Account.Territory__c';
import TRADE_TYPE_FIELD from '@salesforce/schema/Account.Trade_Type_Code__c';
import CSM_NAME_FIELD from '@salesforce/schema/Account.Loving_CSM__r.Name';
import FM_NAME_FIELD from '@salesforce/schema/Account.Loving_FM__r.Name';
import VP_NAME_FIELD from '@salesforce/schema/Account.Loving_VP_Field_Ops__r.Name';
import SCHEDULER_NAME_FIELD from '@salesforce/schema/Account.Loving_Scheduler__r.Name';
import AP_NAME_FIELD from '@salesforce/schema/Account.Loving_AP__r.Name';
import WARRANTY_NAME_FIELD from '@salesforce/schema/Account.Loving_Warranty__r.Name';

const FIELDS = [
    NAME_FIELD, TYPE_FIELD, MARKET_FIELD, TERRITORY_FIELD, TRADE_TYPE_FIELD,
    CSM_NAME_FIELD, FM_NAME_FIELD, VP_NAME_FIELD, SCHEDULER_NAME_FIELD, AP_NAME_FIELD, WARRANTY_NAME_FIELD
];

export default class ParentCompanyIdentity extends LightningElement {
    @api recordId;
    _record;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) { this._record = data; }
        else if (error) { this._record = null; }
    }

    get accountType() { return getFieldValue(this._record, TYPE_FIELD) || ''; }
    get accountTypeDisplay() { return getFieldValue(this._record, TYPE_FIELD) || '—'; }
    get marketDisplay() { return getFieldValue(this._record, MARKET_FIELD) || '—'; }
    get territoryDisplay() { return getFieldValue(this._record, TERRITORY_FIELD) || '—'; }
    get tradeTypeDisplay() { return getFieldValue(this._record, TRADE_TYPE_FIELD) || '—'; }
    get csmName() { return getFieldValue(this._record, CSM_NAME_FIELD) || 'N/A'; }
    get fmName() { return getFieldValue(this._record, FM_NAME_FIELD) || 'N/A'; }
    get vpName() { return getFieldValue(this._record, VP_NAME_FIELD) || 'N/A'; }
    get schedulerName() { return getFieldValue(this._record, SCHEDULER_NAME_FIELD) || 'N/A'; }
    get apName() { return getFieldValue(this._record, AP_NAME_FIELD) || 'N/A'; }
    get warrantyName() { return getFieldValue(this._record, WARRANTY_NAME_FIELD) || 'N/A'; }
}