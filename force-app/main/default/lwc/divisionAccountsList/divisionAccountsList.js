import { LightningElement, api, wire } from 'lwc';
import getDivisionAccounts from '@salesforce/apex/ParentAccountRollupController.getDivisionAccounts';

const COLUMNS = [
    {
        label: 'Division Account',
        fieldName: 'recordUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'name' }, target: '_self' }
    },
    { label: 'Status', fieldName: 'accountStatus' },
    { label: 'Division / Region', fieldName: 'division' },
    { label: 'Phone', fieldName: 'phone' },
    { label: 'Website', fieldName: 'website', type: 'url',
        typeAttributes: { label: { fieldName: 'website' }, target: '_blank' } }
];

export default class DivisionAccountsList extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    rows;
    error;

    @wire(getDivisionAccounts, { parentAccountId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.rows = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
            this.rows = undefined;
        }
    }

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    get countLabel() {
        return this.rows ? `(${this.rows.length})` : '';
    }
}