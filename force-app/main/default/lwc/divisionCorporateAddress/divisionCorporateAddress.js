import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import DIV_OFFICE_ADDR  from '@salesforce/schema/Account.Division_Office_Address__c';
import DIV_PHONE        from '@salesforce/schema/Account.Division_Phone__c';
import DIV_EMAIL        from '@salesforce/schema/Account.Division_Email__c';
import CORP_ADDR        from '@salesforce/schema/Account.Corporate_Office_Address__c';
import PHYS_STREET      from '@salesforce/schema/Account.Physical_Street__c';
import PHYS_CITY        from '@salesforce/schema/Account.Physical_City__c';
import PHYS_STATE       from '@salesforce/schema/Account.Physical_State__c';
import PHYS_ZIP         from '@salesforce/schema/Account.Physical_Zip__c';
import MAIL_SAME        from '@salesforce/schema/Account.Mailing_Same_As_Physical__c';
import MAIL_STREET      from '@salesforce/schema/Account.Mailing_Street__c';
import MAIL_CITY        from '@salesforce/schema/Account.Mailing_City__c';
import MAIL_STATE       from '@salesforce/schema/Account.Mailing_State__c';
import MAIL_ZIP         from '@salesforce/schema/Account.Mailing_Zip__c';
import AP_EMAIL         from '@salesforce/schema/Account.AP_Invoicing_Email__c';

const FIELDS = [
    DIV_OFFICE_ADDR, DIV_PHONE, DIV_EMAIL, CORP_ADDR,
    PHYS_STREET, PHYS_CITY, PHYS_STATE, PHYS_ZIP,
    MAIL_SAME, MAIL_STREET, MAIL_CITY, MAIL_STATE, MAIL_ZIP,
    AP_EMAIL
];

export default class DivisionCorporateAddress extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    account;

    get isLoaded() { return !!this.account.data; }
    get hasError() { return !!this.account.error; }

    get divOfficeAddr()  { return getFieldValue(this.account.data, DIV_OFFICE_ADDR) || '—'; }
    get divPhone()       { return getFieldValue(this.account.data, DIV_PHONE)       || '—'; }
    get divEmail()       { return getFieldValue(this.account.data, DIV_EMAIL)       || '—'; }
    get corpAddr()       { return getFieldValue(this.account.data, CORP_ADDR)       || '—'; }
    get apEmail()        { return getFieldValue(this.account.data, AP_EMAIL)        || '—'; }
    get mailSameAsPhys() { return getFieldValue(this.account.data, MAIL_SAME); }

    get physAddress() {
        const street = getFieldValue(this.account.data, PHYS_STREET) || '';
        const city   = getFieldValue(this.account.data, PHYS_CITY)   || '';
        const state  = getFieldValue(this.account.data, PHYS_STATE)  || '';
        const zip    = getFieldValue(this.account.data, PHYS_ZIP)    || '';
        if (!street && !city) return '—';
        const line2 = [city, state, zip].filter(Boolean).join(' ');
        return [street, line2].filter(Boolean).join('\n');
    }

    get physAddressLines() {
        const addr = this.physAddress;
        if (addr === '—') return [{ id: 0, text: '—' }];
        return addr.split('\n').map((t, i) => ({ id: i, text: t }));
    }

    get mailAddress() {
        if (this.mailSameAsPhys) return this.physAddress;
        const street = getFieldValue(this.account.data, MAIL_STREET) || '';
        const city   = getFieldValue(this.account.data, MAIL_CITY)   || '';
        const state  = getFieldValue(this.account.data, MAIL_STATE)  || '';
        const zip    = getFieldValue(this.account.data, MAIL_ZIP)    || '';
        if (!street && !city) return '—';
        const line2  = [city, state, zip].filter(Boolean).join(' ');
        return [street, line2].filter(Boolean).join('\n');
    }

    get mailAddressLines() {
        const addr = this.mailAddress;
        if (addr === '—') return [{ id: 0, text: '—' }];
        return addr.split('\n').map((t, i) => ({ id: i, text: t }));
    }

    get mailSameLabel() {
        return this.mailSameAsPhys ? 'Same as physical address' : null;
    }

    get divPhoneHref()  { return this.divPhone  !== '—' ? `tel:${this.divPhone}`    : null; }
    get divEmailHref()  { return this.divEmail  !== '—' ? `mailto:${this.divEmail}` : null; }
    get apEmailHref()   { return this.apEmail   !== '—' ? `mailto:${this.apEmail}`  : null; }
}