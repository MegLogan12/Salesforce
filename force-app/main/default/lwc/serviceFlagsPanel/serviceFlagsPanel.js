import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import SERVICES from '@salesforce/schema/Account.Services_Offered__c';
import CONTRACT_START from '@salesforce/schema/Account.Contract_Start_Date__c';
import CONTRACT_RENEW from '@salesforce/schema/Account.Contract_Renewal_Date__c';
import SERVICE_DAY from '@salesforce/schema/Account.Designated_Service_Day__c';
import MARKET from '@salesforce/schema/Account.Market__c';

const FIELDS = [SERVICES, CONTRACT_START, CONTRACT_RENEW, SERVICE_DAY, MARKET];

// 8 toggle pills required by the design.
const ALL_SERVICES = [
    'Aqua Service',
    'Irrigation',
    'Grading',
    'Lawn Care',
    'Refreshes',
    'Production Landscaping',
    'Signature Builds',
    'Finishing Touches'
];

export default class ServiceFlagsPanel extends LightningElement {
    @api recordId;
    account;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wired({ data }) {
        if (data) this.account = data;
    }

    get flags() {
        const raw = this.account ? getFieldValue(this.account, SERVICES) : null;
        const selected = raw ? raw.split(';').map(s => s.trim()) : [];
        return ALL_SERVICES.map(s => {
            const active = selected.includes(s);
            return {
                label: s,
                cls: active ? 'flag fon' : 'flag foff',
                dotCls: active ? 'fdot don' : 'fdot doff'
            };
        });
    }

    get contractStart() { return this.account ? getFieldValue(this.account, CONTRACT_START) : null; }
    get contractRenew() { return this.account ? getFieldValue(this.account, CONTRACT_RENEW) : null; }
    get serviceDay() { return this.account ? getFieldValue(this.account, SERVICE_DAY) : null; }
    get market() { return this.account ? getFieldValue(this.account, MARKET) : null; }

    get hasStart() { return !!this.contractStart; }
    get hasRenew() { return !!this.contractRenew; }
    get hasServiceDay() { return !!this.serviceDay; }
    get hasMarket() { return !!this.market; }
}