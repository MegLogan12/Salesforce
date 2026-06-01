import { LightningElement, api, wire } from 'lwc';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { getFieldValue } from 'lightning/uiRecordApi';
import TRADE_TYPE_FIELD from '@salesforce/schema/Account.Trade_Type_Code__c';

export default class ParentLobCoverageHeatmap extends LightningElement {
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

    get lobCoverage() {
        if (!this._children) return [];
        const lobMap = {};
        this._children.forEach(r => {
            const lob = getFieldValue(r, TRADE_TYPE_FIELD) || 'Other';
            if (!lobMap[lob]) lobMap[lob] = { lob, count: 0 };
            lobMap[lob].count++;
        });
        return Object.values(lobMap).map((l, i) => ({
            ...l,
            id: `lob-${i}`,
            chipClass: 'chip cb2'
        }));
    }

    get hasLobs() { return this.lobCoverage.length > 0; }
    get isLoaded() { return this._children !== undefined; }
}