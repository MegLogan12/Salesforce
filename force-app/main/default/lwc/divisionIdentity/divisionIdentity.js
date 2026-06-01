import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import ACCOUNT_NAME        from '@salesforce/schema/Account.Name';
import ACCOUNT_TYPE        from '@salesforce/schema/Account.Type';
import MARKET              from '@salesforce/schema/Account.Market__c';
import TERRITORY           from '@salesforce/schema/Account.Territory__c';
import TRADE_TYPE          from '@salesforce/schema/Account.Trade_Type_Code__c';
import PARENT_NAME         from '@salesforce/schema/Account.Parent.Name';
import CSM_NAME            from '@salesforce/schema/Account.Loving_CSM__r.Name';
import FM_NAME             from '@salesforce/schema/Account.Loving_FM__r.Name';
import VP_NAME             from '@salesforce/schema/Account.Loving_VP_Field_Ops__r.Name';
import SCHEDULER_NAME      from '@salesforce/schema/Account.Loving_Scheduler__r.Name';
import AP_NAME             from '@salesforce/schema/Account.Loving_AP__r.Name';
import WARRANTY_NAME       from '@salesforce/schema/Account.Loving_Warranty__r.Name';

const FIELDS = [
    ACCOUNT_NAME, ACCOUNT_TYPE, MARKET, TERRITORY,
    TRADE_TYPE, PARENT_NAME,
    CSM_NAME, FM_NAME, VP_NAME, SCHEDULER_NAME, AP_NAME, WARRANTY_NAME
];

export default class DivisionIdentity extends LightningElement {
    @api recordId;
    isEditing = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    account;

    get isLoaded()  { return !!this.account.data; }
    get hasError()  { return !!this.account.error; }
    get errorMessage() { return this.account.error?.body?.message || this.account.error?.message || 'Unable to load account data.'; }

    get accountName()      { return getFieldValue(this.account.data, ACCOUNT_NAME)   || '—'; }
    get accountType()      { return getFieldValue(this.account.data, ACCOUNT_TYPE)   || ''; }
    get division()         { return getFieldValue(this.account.data, MARKET)         || '—'; }
    get territory()        { return getFieldValue(this.account.data, TERRITORY)      || '—'; }
    get tradeTypeCode()    { return getFieldValue(this.account.data, TRADE_TYPE)     || ''; }
    get parentName()       { return getFieldValue(this.account.data, PARENT_NAME)    || '—'; }
    get csmName()          { return getFieldValue(this.account.data, CSM_NAME)       || '—'; }
    get fmName()           { return getFieldValue(this.account.data, FM_NAME)        || '—'; }
    get vpFieldOpsName()   { return getFieldValue(this.account.data, VP_NAME)        || '—'; }
    get schedulerName()    { return getFieldValue(this.account.data, SCHEDULER_NAME) || '—'; }
    get apName()           { return getFieldValue(this.account.data, AP_NAME)        || '—'; }
    get warrantyName()     { return getFieldValue(this.account.data, WARRANTY_NAME)  || '—'; }

    get teamRows() {
        return [
            { label: 'Customer Success (CSM)', value: this.csmName },
            { label: 'Field Manager',           value: this.fmName },
            { label: 'VP Field Ops',             value: this.vpFieldOpsName },
            { label: 'Scheduling',               value: this.schedulerName },
            { label: 'Accounting / AP',          value: this.apName },
            { label: 'Warranty',                 value: this.warrantyName }
        ];
    }

    get editButtonLabel() {
        return this.isEditing ? 'Close Editor' : 'Edit Division';
    }

    handleToggleEdit() {
        this.isEditing = !this.isEditing;
    }

    handleCancel() {
        this.isEditing = false;
    }

    async handleSuccess() {
        this.isEditing = false;
        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Division updated',
                message: 'Division details were saved successfully.',
                variant: 'success'
            })
        );
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Unable to save division',
                message: event.detail?.message || 'Review the highlighted fields and try again.',
                variant: 'error'
            })
        );
    }
}