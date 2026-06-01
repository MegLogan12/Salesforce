import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import CM_NAME   from '@salesforce/schema/Account.Construction_Mgr_Name__c';
import CM_EMAIL  from '@salesforce/schema/Account.Construction_Mgr_Email__c';
import CM_PHONE  from '@salesforce/schema/Account.Construction_Mgr_Phone__c';
import SC_NAME   from '@salesforce/schema/Account.Scheduling_Contact_Name__c';
import SC_EMAIL  from '@salesforce/schema/Account.Scheduling_Contact_Email__c';
import SC_PHONE  from '@salesforce/schema/Account.Scheduling_Contact_Phone__c';
import WC_NAME   from '@salesforce/schema/Account.Warranty_Contact_Name__c';
import WC_EMAIL  from '@salesforce/schema/Account.Warranty_Contact_Email__c';
import WC_PHONE  from '@salesforce/schema/Account.Warranty_Contact_Phone__c';
import PC_NAME   from '@salesforce/schema/Account.Purchasing_Contact_Name__c';
import PC_EMAIL  from '@salesforce/schema/Account.Purchasing_Contact_Email__c';
import PC_PHONE  from '@salesforce/schema/Account.Purchasing_Contact_Phone__c';

const FIELDS = [
    CM_NAME, CM_EMAIL, CM_PHONE,
    SC_NAME, SC_EMAIL, SC_PHONE,
    WC_NAME, WC_EMAIL, WC_PHONE,
    PC_NAME, PC_EMAIL, PC_PHONE
];

export default class DivisionKeyContacts extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    account;

    get isLoaded() { return !!this.account.data; }
    get hasError() { return !!this.account.error; }

    _val(field) { return getFieldValue(this.account.data, field) || ''; }

    _contact(id, icon, role, nameField, emailField, phoneField) {
        const email = this._val(emailField) || '';
        const phone = this._val(phoneField) || '';
        return {
            id,
            icon,
            role,
            name:      this._val(nameField) || '—',
            email,
            phone,
            emailHref: email ? `mailto:${email}` : null,
            phoneHref: phone ? `tel:${phone}`    : null
        };
    }

    get contacts() {
        return [
            this._contact('cm', '🔨', 'Construction Manager',  CM_NAME, CM_EMAIL, CM_PHONE),
            this._contact('sc', '📅', 'Scheduling Contact',    SC_NAME, SC_EMAIL, SC_PHONE),
            this._contact('wc', '🛡',  'Warranty Contact',      WC_NAME, WC_EMAIL, WC_PHONE),
            this._contact('pc', '💳', 'Purchasing Contact',    PC_NAME, PC_EMAIL, PC_PHONE)
        ];
    }
}