import { LightningElement, wire } from 'lwc';
import getOpenHireRequests from '@salesforce/apex/HomeDashboardController.getOpenHireRequests';

const COLUMNS = [
    { label: 'HR #', fieldName: 'url', type: 'url',
      typeAttributes: { label: { fieldName: 'hrNumber' }, target: '_self' } },
    { label: 'Submitted By', fieldName: 'submittedBy', type: 'text' },
    { label: 'Service Line', fieldName: 'serviceLine', type: 'text' },
    { label: 'Role', fieldName: 'roleType', type: 'text' },
    { label: 'Total Cost', fieldName: 'totalCost', type: 'currency',
      typeAttributes: { currencyCode: 'USD' }, cellAttributes: { alignment: 'right' } },
    { label: 'Y1 ROI', fieldName: 'y1ROI', type: 'currency',
      typeAttributes: { currencyCode: 'USD' }, cellAttributes: { alignment: 'right' } },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Submitted', fieldName: 'submittedDate', type: 'date' }
];

export default class OpenHireRequestsList extends LightningElement {
    rows = [];
    columns = COLUMNS;

    @wire(getOpenHireRequests)
    onRows({ data }) {
        if (data) this.rows = data;
    }

    get count() {
        return this.rows.length;
    }
}