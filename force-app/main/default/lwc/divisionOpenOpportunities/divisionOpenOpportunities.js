import { LightningElement, api, wire } from 'lwc';
import getOpenOpportunities from '@salesforce/apex/ParentAccountRollupController.getOpenOpportunities';

const COLUMNS = [
    {
        label: 'Opportunity',
        fieldName: 'recordUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'name' }, target: '_self' }
    },
    { label: 'Division Account', fieldName: 'accountName' },
    { label: 'Stage', fieldName: 'stageName' },
    { label: 'Amount', fieldName: 'amount', type: 'currency',
        typeAttributes: { currencyDisplayAs: 'symbol' } },
    { label: 'Close Date', fieldName: 'closeDate', type: 'date-local',
        typeAttributes: { month: '2-digit', day: '2-digit', year: 'numeric' } }
];

export default class DivisionOpenOpportunities extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    rows;
    error;

    @wire(getOpenOpportunities, { parentAccountId: '$recordId' })
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

    get totalAmount() {
        if (!this.rows) return 0;
        return this.rows.reduce((sum, r) => sum + (r.amount || 0), 0);
    }
}