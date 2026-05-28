import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getWorkOrderRecord from '@salesforce/apex/ODL_WorkController.getWorkOrderRecord';

const WO_STAGES = ['Created', 'Scheduled', 'In Progress', 'Punch', 'Closeout', 'Closed'];

export default class OdlWorkOrder extends LightningElement {
    @api recordId;
    @track workOrder = {};
    @track lineItems = [];
    isLoaded = false;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getWorkOrderRecord, { workOrderId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.workOrder = data.workOrder || {};
            this.lineItems = (data.lineItems || []).map(li => ({
                ...li,
                statusChipClass: li.Status === 'Completed' ? 'chip cg' : li.Status === 'In Progress' ? 'chip ca' : 'chip cgr'
            }));
            this.isLoaded = true;
        } else if (error) {
            this.isLoaded = true;
        }
    }

    get pathSteps() {
        const current = this.workOrder.Status || '';
        let found = false;
        return WO_STAGES.map(s => {
            let cssClass = 'path-step';
            if (s === current) { cssClass = 'path-step on'; found = true; }
            else if (!found) cssClass = 'path-step done';
            return { label: s, cssClass };
        });
    }

    get startDateFormatted() { return this.workOrder.StartDate ? new Date(this.workOrder.StartDate + 'T12:00:00').toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'; }
    get endDateFormatted() { return this.workOrder.EndDate ? new Date(this.workOrder.EndDate + 'T12:00:00').toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'; }
    get statusChipClass() {
        const s = this.workOrder.Status;
        if (s === 'Closed' || s === 'Completed') return 'chip cg';
        if (s === 'In Progress') return 'chip ca';
        return 'chip cb2';
    }
    get noLineItems() { return this.lineItems.length === 0; }
}
