import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getWarrantyCase from '@salesforce/apex/ODL_DashboardController.getWarrantyCase';

const CASE_STAGES = ['New', 'Review', 'Scheduled', 'Resolved', 'Closed'];

export default class OdlWarrantyCase extends LightningElement {
    @api recordId;
    @track caseRecord = {};
    isLoaded = false;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getWarrantyCase, { caseId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.caseRecord = data.caseRecord || {};
            this.isLoaded = true;
        } else if (error) {
            this.isLoaded = true;
        }
    }

    get pathSteps() {
        const current = this.caseRecord.Status || '';
        let found = false;
        return CASE_STAGES.map(s => {
            let cssClass = 'path-step';
            if (s === current) { cssClass = 'path-step on'; found = true; }
            else if (!found) cssClass = 'path-step done';
            return { label: s, cssClass };
        });
    }

    get createdDateFormatted() { return this.caseRecord.CreatedDate ? new Date(this.caseRecord.CreatedDate).toLocaleDateString('en-US', {month:'short', day:'numeric', year:'numeric'}) : '—'; }
    get priorityChipClass() {
        const p = this.caseRecord.Priority;
        if (p === 'High') return 'chip cr';
        if (p === 'Medium') return 'chip ca';
        return 'chip cgr';
    }

    get coverageItems() {
        return [
            { id: '1', claimArea: 'Paver settling', coverage: 'Workmanship', action: 'Schedule inspection', status: 'Review', chipClass: 'chip cb2' },
            { id: '2', claimArea: 'Lighting fixture', coverage: 'Manufacturer', action: 'Request replacement part', status: 'Pending', chipClass: 'chip ca' }
        ];
    }
    get noCoverageItems() { return false; }
}
