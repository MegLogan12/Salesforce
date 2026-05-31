import { LightningElement, api, wire } from 'lwc';
import getFinishJobs from '@salesforce/apex/WorkOrderRecordController.getFinishJobs';

export default class WorkOrderFinishJobs extends LightningElement {
    @api recordId;
    jobs = [];
    error;
    loading = true;

    @wire(getFinishJobs, { workOrderId: '$recordId' })
    wired({ data, error }) {
        this.loading = false;
        if (data) {
            this.jobs = data.map((j) => Object.assign({}, j, {
                statusClass: this.classFor(j.status)
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.jobs = [];
        }
    }

    classFor(status) {
        if (!status) return 'pill pill-neutral';
        const s = String(status).toLowerCase();
        if (s.indexOf('closed') > -1) return 'pill pill-done';
        if (s.indexOf('progress') > -1) return 'pill pill-active';
        if (s.indexOf('scheduled') > -1) return 'pill pill-warn';
        return 'pill pill-neutral';
    }

    get hasJobs() {
        return this.jobs && this.jobs.length > 0;
    }
}