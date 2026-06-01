import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import CONTRACT_STATUS from '@salesforce/schema/Account.Contract_Status__c';
import CONTRACT_START from '@salesforce/schema/Account.Contract_Start_Date__c';
import CONTRACT_RENEW from '@salesforce/schema/Account.Contract_Renewal_Date__c';
import CONTRACT_LINK from '@salesforce/schema/Account.Contract_Link__c';
import BMG_LINK from '@salesforce/schema/Account.BMG_Pricing_Link__c';
import COI_LINK from '@salesforce/schema/Account.Insurance_COI_Link__c';

const FIELDS = [CONTRACT_STATUS, CONTRACT_START, CONTRACT_RENEW, CONTRACT_LINK, BMG_LINK, COI_LINK];

function statusCls(status) {
    if (!status) return 'pill pgr';
    const s = status.toLowerCase();
    if (s.includes('active') || s.includes('contract')) return 'pill pg';
    if (s.includes('renew')) return 'pill pb';
    if (s.includes('expired') || s.includes('terminated')) return 'pill pr';
    if (s.includes('draft') || s.includes('pending')) return 'pill pa';
    return 'pill pgr';
}

export default class DivisionContractSummary extends LightningElement {
    @api recordId;
    account;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wired({ data }) {
        if (data) this.account = data;
    }

    get status() { return this.account ? getFieldValue(this.account, CONTRACT_STATUS) : null; }
    get hasStatus() { return !!this.status; }
    get statusCls() { return statusCls(this.status); }
    get contractStart() { return this.account ? getFieldValue(this.account, CONTRACT_START) : null; }
    get contractRenew() { return this.account ? getFieldValue(this.account, CONTRACT_RENEW) : null; }
    get contractLink() { return this.account ? getFieldValue(this.account, CONTRACT_LINK) : null; }
    get bmgLink() { return this.account ? getFieldValue(this.account, BMG_LINK) : null; }
    get coiLink() { return this.account ? getFieldValue(this.account, COI_LINK) : null; }

    get hasStart() { return !!this.contractStart; }
    get hasRenew() { return !!this.contractRenew; }
    get hasContract() { return !!this.contractLink; }
    get hasBmg() { return !!this.bmgLink; }
    get hasCoi() { return !!this.coiLink; }
}