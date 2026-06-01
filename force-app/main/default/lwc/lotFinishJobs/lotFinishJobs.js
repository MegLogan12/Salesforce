import { LightningElement, api, wire } from 'lwc';
import getFinishJobs from '@salesforce/apex/LotRecordController.getFinishJobs';

const COLUMNS = [
    { label: 'FJ #', fieldName: 'url', type: 'url',
      typeAttributes: { label: { fieldName: 'woNumber' }, target: '_self' } },
    { label: 'Type', fieldName: 'jobType', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Scheduled', fieldName: 'scheduledDate', type: 'date' },
    { label: 'Foreman', fieldName: 'foreman', type: 'text' }
];

export default class LotFinishJobs extends LightningElement {
    @api recordId;
    rows = [];
    columns = COLUMNS;

    @wire(getFinishJobs, { lotId: '$recordId' })
    onFJs({ data }) {
        if (data) this.rows = data;
    }

    get count() {
        return this.rows.length;
    }
}