import { LightningElement, api, wire } from 'lwc';
import getWorkOrders from '@salesforce/apex/LotRecordController.getWorkOrders';

const COLUMNS = [
    { label: 'WO #', fieldName: 'url', type: 'url',
      typeAttributes: { label: { fieldName: 'woNumber' }, target: '_self' } },
    { label: 'Type', fieldName: 'jobType', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Scheduled', fieldName: 'scheduledDate', type: 'date' },
    { label: 'Foreman', fieldName: 'foreman', type: 'text' }
];

export default class LotRelatedWorkOrders extends LightningElement {
    @api recordId;
    rows = [];
    columns = COLUMNS;

    @wire(getWorkOrders, { lotId: '$recordId' })
    onWOs({ data }) {
        if (data) this.rows = data;
    }
}