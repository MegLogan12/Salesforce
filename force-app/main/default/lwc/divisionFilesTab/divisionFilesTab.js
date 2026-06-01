import { LightningElement, api, wire, track } from 'lwc';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAccountFiles from '@salesforce/apex/LovingAccountHierarchyController.getAccountFiles';

const CATEGORIES = [
    { value: 'All', label: 'All' },
    { value: 'MSA & Legal', label: 'MSA & Legal' },
    { value: 'Pricing & Rate Sheets', label: 'Pricing & Rate Sheets' },
    { value: 'Scope of Work', label: 'Scope of Work' },
    { value: 'Community Maps', label: 'Community Maps' },
    { value: 'Permits', label: 'Permits' },
    { value: 'Correspondence', label: 'Correspondence' },
    { value: 'Other', label: 'Other' }
];

export default class DivisionFilesTab extends LightningElement {
    @api recordId;
    @track files = [];
    @track activeCategory = 'All';
    @track searchTerm = '';
    @track canPin = false;
    isLoading = true;

    @wire(getAccountFiles, { accountId: '$recordId' })
    wired({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.files = data.map(f => ({
                id: f.id,
                title: f.title,
                category: f.category || 'Other',
                uploadedBy: f.uploadedBy,
                dateStr: f.contentModifiedDate ? new Date(f.contentModifiedDate).toLocaleDateString() : '',
                sizeStr: f.contentSize ? this._formatSize(f.contentSize) : '',
                downloadUrl: '/sfc/servlet.shepherd/document/download/' + f.contentDocumentId,
                isPinned: f.isPinned || false,
                contentDocumentId: f.contentDocumentId
            }));
        } else if (error) {
            this.files = [];
        }
    }

    get categoryChips() {
        return CATEGORIES.map(c => ({
            ...c,
            cls: 'filter-chip' + (c.value === this.activeCategory ? ' on' : '')
        }));
    }

    get pinnedFiles() {
        return this.files.filter(f => f.isPinned);
    }

    get filteredFiles() {
        return this.files.filter(f => {
            if (f.isPinned) return false;
            if (this.activeCategory !== 'All' && f.category !== this.activeCategory) return false;
            if (this.searchTerm && !f.title.toLowerCase().includes(this.searchTerm.toLowerCase())) return false;
            return true;
        });
    }

    get hasFiles() { return this.filteredFiles.length > 0 || this.pinnedFiles.length > 0; }
    get hasPinned() { return this.pinnedFiles.length > 0; }
    get fileCount() { return this.files.length > 0 ? this.files.length : null; }

    handleCategoryFilter(event) {
        this.activeCategory = event.target.dataset.value;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleUpload() {
        this.dispatchEvent(new ShowToastEvent({ title: 'Upload File', message: 'Use the Files related list to upload files to this record.', variant: 'info' }));
    }

    handlePreview(event) {
        const id = event.target.dataset.id;
        const f = this.files.find(x => x.id === id);
        if (f) window.open('/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId=' + f.id, '_blank');
    }

    handlePin(event) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Pin File', message: 'Pinning requires the Division Account owner or COO/VP Field Ops permission.', variant: 'info' }));
    }

    handleUnpin(event) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Unpin File', message: 'Unpinning requires the Division Account owner or COO/VP Field Ops permission.', variant: 'info' }));
    }

    _formatSize(bytes) {
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }
}