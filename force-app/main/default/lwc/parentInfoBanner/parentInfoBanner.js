import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/Account.Name';
import TYPE_FIELD from '@salesforce/schema/Account.Type';
import MARKET_FIELD from '@salesforce/schema/Account.Market__c';
import TERRITORY_FIELD from '@salesforce/schema/Account.Territory__c';
import TRADE_TYPE_FIELD from '@salesforce/schema/Account.Trade_Type_Code__c';
import CERTS_FIELD from '@salesforce/schema/Account.Certs_On_File__c';
import W9_FIELD from '@salesforce/schema/Account.W9_On_File__c';

const FIELDS = [NAME_FIELD, TYPE_FIELD, MARKET_FIELD, TERRITORY_FIELD, TRADE_TYPE_FIELD, CERTS_FIELD, W9_FIELD];

export default class ParentInfoBanner extends LightningElement {
    @api recordId;
    _record;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) { this._record = data; }
        else if (error) { this._record = null; }
    }

    get name() { return getFieldValue(this._record, NAME_FIELD) || ''; }
    get accountType() { return getFieldValue(this._record, TYPE_FIELD) || ''; }
    get market() { return getFieldValue(this._record, MARKET_FIELD) || ''; }
    get territory() { return getFieldValue(this._record, TERRITORY_FIELD) || ''; }
    get tradeTypeCode() { return getFieldValue(this._record, TRADE_TYPE_FIELD) || ''; }
    get certsOnFile() { return getFieldValue(this._record, CERTS_FIELD) || false; }
    get w9OnFile() { return getFieldValue(this._record, W9_FIELD) || false; }

    get certsClass() { return this.certsOnFile ? 'chip cg' : 'chip cr'; }
    get w9Class() { return this.w9OnFile ? 'chip cg' : 'chip cr'; }
}