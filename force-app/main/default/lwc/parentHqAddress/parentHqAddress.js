import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import BILLING_STREET from '@salesforce/schema/Account.BillingStreet';
import BILLING_CITY from '@salesforce/schema/Account.BillingCity';
import BILLING_STATE from '@salesforce/schema/Account.BillingState';
import BILLING_ZIP from '@salesforce/schema/Account.BillingPostalCode';
import BILLING_COUNTRY from '@salesforce/schema/Account.BillingCountry';
import CORP_ADDRESS from '@salesforce/schema/Account.Corporate_Office_Address__c';
import PHONE_FIELD from '@salesforce/schema/Account.Phone';
import WEBSITE_FIELD from '@salesforce/schema/Account.Website';

const FIELDS = [BILLING_STREET, BILLING_CITY, BILLING_STATE, BILLING_ZIP, BILLING_COUNTRY, CORP_ADDRESS, PHONE_FIELD, WEBSITE_FIELD];

export default class ParentHqAddress extends LightningElement {
    @api recordId;
    _record;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) { this._record = data; }
        else if (error) { this._record = null; }
    }

    get billingStreet() { return getFieldValue(this._record, BILLING_STREET) || ''; }
    get billingCity() { return getFieldValue(this._record, BILLING_CITY) || ''; }
    get billingState() { return getFieldValue(this._record, BILLING_STATE) || ''; }
    get billingZip() { return getFieldValue(this._record, BILLING_ZIP) || ''; }
    get billingCountry() { return getFieldValue(this._record, BILLING_COUNTRY) || ''; }
    get corporateAddress() { return getFieldValue(this._record, CORP_ADDRESS) || ''; }
    get phone() { return getFieldValue(this._record, PHONE_FIELD) || ''; }
    get website() { return getFieldValue(this._record, WEBSITE_FIELD) || ''; }

    get hasBillingAddress() {
        return !!(this.billingStreet || this.billingCity || this.billingState);
    }

    get billingCityStateZip() {
        const parts = [];
        if (this.billingCity) parts.push(this.billingCity);
        if (this.billingState) parts.push(this.billingState);
        if (this.billingZip) parts.push(this.billingZip);
        return parts.join(', ');
    }

    get phoneHref() { return this.phone ? `tel:${this.phone}` : '#'; }
}