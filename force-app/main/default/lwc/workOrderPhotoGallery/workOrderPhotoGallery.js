import { LightningElement, api, wire, track } from 'lwc';
import getPhotos from '@salesforce/apex/WorkOrderRecordController.getPhotos';

const TYPE_ORDER = [
    'Pre-Install',
    'Hero',
    'Line Item Submission',
    'QI',
    'Issue',
    'Incomplete',
    'Site Not Ready',
    'FJ Evidence',
    'FJ Complete',
    'Before',
    'After'
];

export default class WorkOrderPhotoGallery extends LightningElement {
    @api recordId;
    @track sections = [];
    error;
    loading = true;

    @wire(getPhotos, { workOrderId: '$recordId' })
    wired({ data, error }) {
        this.loading = false;
        if (data) {
            this.error = undefined;
            this.sections = this.buildSections(data);
        } else if (error) {
            this.error = error;
            this.sections = [];
        }
    }

    buildSections(groups) {
        const out = [];
        const seen = new Set();
        TYPE_ORDER.forEach((key) => {
            const items = groups[key];
            if (items && items.length) {
                out.push({ key, label: key, count: items.length, items: this.decorate(items) });
                seen.add(key);
            }
        });
        Object.keys(groups || {}).forEach((key) => {
            if (!seen.has(key)) {
                const items = groups[key];
                if (items && items.length) {
                    out.push({ key, label: key, count: items.length, items: this.decorate(items) });
                }
            }
        });
        return out;
    }

    decorate(items) {
        return items.map((p) => {
            const badge = p.geotagValid ? 'Geo OK' : 'Geo Missing';
            const badgeClass = p.geotagValid ? 'geo-badge geo-ok' : 'geo-badge geo-warn';
            return Object.assign({}, p, { badge, badgeClass });
        });
    }

    get hasSections() {
        return this.sections && this.sections.length > 0;
    }

    get emptyState() {
        return !this.loading && !this.hasSections;
    }
}