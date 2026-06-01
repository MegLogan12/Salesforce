import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPhotos from '@salesforce/apex/WorkOrderRecordController.getPhotos';
import createPhotoRecord from '@salesforce/apex/WorkOrderPhotoController.createPhotoRecord';

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
    'Takeoff',
    'Site Check',
    'Before',
    'After'
];

export default class WorkOrderPhotoGallery extends LightningElement {
    @api recordId;
    @track sections = [];
    error;
    loading = true;

    uploadModalOpen = false;
    selectedType = 'Hero';
    notesInput = '';
    uploading = false;
    acceptedFormats = '.jpg,.jpeg,.png,.heic,.heif';

    _wiredPhotos;

    @wire(getPhotos, { workOrderId: '$recordId' })
    wired(result) {
        this._wiredPhotos = result;
        this.loading = false;
        if (result.data) {
            this.error = undefined;
            this.sections = this.buildSections(result.data);
        } else if (result.error) {
            this.error = result.error;
            this.sections = [];
        }
    }

    get typeOptions() {
        return TYPE_ORDER.map(t => ({ label: t, value: t }));
    }

    openUploadModal() {
        this.uploadModalOpen = true;
    }

    closeUploadModal() {
        this.uploadModalOpen = false;
        this.notesInput = '';
    }

    handleTypeChange(event) {
        this.selectedType = event.detail.value;
    }

    handleNotesChange(event) {
        this.notesInput = event.detail.value;
    }

    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files || [];
        if (!uploadedFiles.length) return;
        this.uploading = true;
        try {
            for (const f of uploadedFiles) {
                await createPhotoRecord({
                    workOrderId: this.recordId,
                    contentDocumentId: f.documentId,
                    photoType: this.selectedType,
                    notes: this.notesInput
                });
            }
            this.dispatchEvent(new ShowToastEvent({
                title: 'Uploaded',
                message: `${uploadedFiles.length} photo(s) saved as ${this.selectedType}`,
                variant: 'success'
            }));
            await refreshApex(this._wiredPhotos);
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Upload failed',
                message: (err.body && err.body.message) || err.message || 'Unknown error',
                variant: 'error'
            }));
        } finally {
            this.uploading = false;
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
