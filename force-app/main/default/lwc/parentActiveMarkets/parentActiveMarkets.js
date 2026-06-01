import { LightningElement, api, wire } from 'lwc';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { getFieldValue } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/Account.Name';
import TYPE_FIELD from '@salesforce/schema/Account.Type';
import MARKET_FIELD from '@salesforce/schema/Account.Market__c';
import TERRITORY_FIELD from '@salesforce/schema/Account.Territory__c';

export default class ParentActiveMarkets extends LightningElement {
    @api recordId;
    _children;

    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'ChildAccounts',
        fields: ['Account.Name', 'Account.Type', 'Account.Market__c', 'Account.Territory__c', 'Account.Trade_Type_Code__c']
    })
    wiredChildren({ error, data }) {
        if (data) { this._children = data.records; }
        else if (error) { this._children = []; }
    }

    get divisions() {
        if (!this._children) return [];
        return this._children.map(r => ({
            id: r.id,
            name: getFieldValue(r, NAME_FIELD) || '—',
            market: getFieldValue(r, MARKET_FIELD) || '—',
            territory: getFieldValue(r, TERRITORY_FIELD) || '—',
            type: getFieldValue(r, TYPE_FIELD) || '—'
        }));
    }

    get divisionCount() { return this.divisions.length; }
    get hasDivisions() { return this.divisions.length > 0; }
    get isLoaded() { return this._children !== undefined; }
}