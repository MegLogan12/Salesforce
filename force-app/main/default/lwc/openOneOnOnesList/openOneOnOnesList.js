import { LightningElement, wire } from 'lwc';
import getThisWeekOneOnOnes from '@salesforce/apex/HomeDashboardController.getThisWeekOneOnOnes';

const COLUMNS = [
    { label: 'Number', fieldName: 'url', type: 'url',
      typeAttributes: { label: { fieldName: 'name' }, target: '_self' } },
    { label: 'Manager', fieldName: 'manager', type: 'text' },
    { label: 'Direct Report', fieldName: 'directReport', type: 'text' },
    { label: 'Meeting Date', fieldName: 'meetingDate', type: 'date',
      typeAttributes: { year: 'numeric', month: 'short', day: 'numeric',
                        hour: '2-digit', minute: '2-digit' } },
    { label: 'Status', fieldName: 'status', type: 'text' }
];

export default class OpenOneOnOnesList extends LightningElement {
    rows = [];
    columns = COLUMNS;

    @wire(getThisWeekOneOnOnes)
    onRows({ data }) {
        if (data) this.rows = data;
    }

    get count() {
        return this.rows.length;
    }
}