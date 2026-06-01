import { LightningElement, api, wire } from 'lwc';
import getHeader from '@salesforce/apex/LotRecordController.getHeader';

export default class LotHeaderKpis extends LightningElement {
    @api recordId;
    header;
    error;

    @wire(getHeader, { lotId: '$recordId' })
    onHeader({ data, error }) {
        if (data) {
            this.header = data;
            this.error = undefined;
        } else if (error) {
            this.header = undefined;
            this.error = (error.body && error.body.message) ? error.body.message : 'Unable to load lot header.';
        }
    }

    get statusClass() {
        if (!this.header) return 'kpi-tile';
        const s = this.header.status;
        if (s === 'Complete') return 'kpi-tile kpi-good';
        if (s === 'In Production' || s === 'Scheduled') return 'kpi-tile kpi-info';
        if (s === 'FJ Open') return 'kpi-tile kpi-bad';
        if (s === 'Pending') return 'kpi-tile kpi-warn';
        return 'kpi-tile';
    }

    get fjClass() {
        return this.header?.hasOpenFJ ? 'kpi-tile kpi-bad' : 'kpi-tile kpi-good';
    }

    get fjLabel() {
        return this.header?.hasOpenFJ ? 'OPEN' : 'NONE';
    }

    get daysClass() {
        if (!this.header || this.header.daysUntilInstall == null) return 'kpi-tile';
        const d = this.header.daysUntilInstall;
        if (d < 0) return 'kpi-tile kpi-bad';
        if (d <= 7) return 'kpi-tile kpi-warn';
        return 'kpi-tile kpi-info';
    }
}