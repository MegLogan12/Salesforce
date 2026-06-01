import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import createPhotoRecord from '@salesforce/apex/WorkOrderPhotoController.createPhotoRecord';
import uploadCameraPhoto from '@salesforce/apex/WorkOrderPhotoController.uploadCameraPhoto';

const PHOTO_TYPES = [
    { value: 'Before',                label: 'Before' },
    { value: 'After',                 label: 'After' },
    { value: 'Pre-Install',           label: 'Pre-Install' },
    { value: 'Hero',                  label: 'Hero' },
    { value: 'Line Item Submission',  label: 'Line Item Submission' },
    { value: 'QI',                    label: 'QI Inspection' },
    { value: 'Issue',                 label: 'Issue' },
    { value: 'Incomplete',            label: 'Incomplete' },
    { value: 'Site Not Ready',        label: 'Site Not Ready' },
    { value: 'FJ Evidence',           label: 'FJ Evidence' },
    { value: 'FJ Complete',           label: 'FJ Complete' },
    { value: 'Takeoff',               label: 'Takeoff' },
    { value: 'Site Check',            label: 'Site Check' }
];

const ACCEPTED_FORMATS = ['.jpg', '.jpeg', '.png', '.heic', '.webp'];

export default class LovingAddPhoto extends LightningElement {
    @api recordId;

    @track photoType = '';
    @track photoNotes = '';
    @track error = null;
    @track successMsg = null;
    @track showForm = true;
    @track uploading = false;

    // Camera capture state
    @track pendingFileName = null;
    _pendingFileBase64 = null;
    _pendingFileMime = null;

    get acceptedFormats() { return ACCEPTED_FORMATS; }

    get photoTypeOptions() {
        return PHOTO_TYPES.map(o => ({
            value: o.value,
            label: o.label,
            selected: o.value === this.photoType
        }));
    }

    // ── Handlers ────────────────────────────────────────────────

    handleTypeChange(evt) {
        this.photoType = evt.target.value;
        this.error = null;
    }

    handleNotesChange(evt) {
        this.photoNotes = evt.target.value;
    }

    // lightning-file-upload finished (attaches to record automatically via ContentDocument)
    handleFileUpload(evt) {
        const files = evt.detail.files;
        if (!files || files.length === 0) return;

        if (!this.photoType) {
            this.error = 'Please select a Photo Type before uploading.';
            return;
        }

        // Create Photo__c record linked to this content document
        const contentDocId = files[0].documentId;
        createPhotoRecord({
            workOrderId: this.recordId,
            contentDocumentId: contentDocId,
            photoType: this.photoType,
            notes: this.photoNotes
        })
        .then(() => {
            this._done('Photo uploaded successfully!');
        })
        .catch(err => {
            this.error = (err.body && err.body.message) || 'Upload failed.';
            this._toast('Error', this.error, 'error');
        });
    }

    // Camera file input change
    handleCameraCapture(evt) {
        const file = evt.target.files[0];
        if (!file) return;
        if (!this.photoType) {
            this.error = 'Please select a Photo Type first.';
            return;
        }
        this.error = null;
        this.pendingFileName = file.name;
        this._pendingFileMime = file.type;

        // Read as base64
        const reader = new FileReader();
        reader.onload = (e) => {
            // e.target.result = "data:image/jpeg;base64,/9j/4AA..."
            const base64Full = e.target.result;
            const commaIdx = base64Full.indexOf(',');
            this._pendingFileBase64 = commaIdx >= 0
                ? base64Full.substring(commaIdx + 1)
                : base64Full;
        };
        reader.readAsDataURL(file);
    }

    clearPending() {
        this.pendingFileName = null;
        this._pendingFileBase64 = null;
        this._pendingFileMime = null;
    }

    handleUploadCamera() {
        if (!this._pendingFileBase64) {
            this.error = 'No photo data captured. Please try again.';
            return;
        }
        if (!this.photoType) {
            this.error = 'Please select a Photo Type.';
            return;
        }
        this.uploading = true;
        this.error = null;

        uploadCameraPhoto({
            workOrderId: this.recordId,
            base64Data: this._pendingFileBase64,
            fileName: this.pendingFileName || ('photo_' + Date.now() + '.jpg'),
            mimeType: this._pendingFileMime || 'image/jpeg',
            photoType: this.photoType,
            notes: this.photoNotes
        })
        .then(() => {
            this._done('Photo saved successfully!');
        })
        .catch(err => {
            this.error = (err.body && err.body.message) || 'Upload failed.';
            this._toast('Error', this.error, 'error');
        })
        .finally(() => { this.uploading = false; });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // ── Private ─────────────────────────────────────────────────

    _done(msg) {
        this._toast('Success', msg, 'success');
        this.showForm = false;
        this.successMsg = msg;
        // Auto-close after 1.5s
        window.setTimeout(() => {
            this.dispatchEvent(new CloseActionScreenEvent());
        }, 1500);
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}