import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getWorkspaceData from '@salesforce/apex/ODLWorkspaceEmailController.getWorkspaceData';

export default class OdlEmailWorkspaceBase extends NavigationMixin(LightningElement) {
    @api workspaceType;
    data;
    error;
    wiredResult;
    selectedRecordId;
    selectedObjectApiName;

    @wire(getWorkspaceData, { workspaceType: '$workspaceType' })
    wiredWorkspace(result) {
        this.wiredResult = result;
        if (result.data) {
            this.data = result.data;
            this.error = undefined;
            if (!this.selectedRecordId && this.data.rows && this.data.rows.length > 0) {
                this.selectedRecordId = this.data.rows[0].id;
                this.selectedObjectApiName = this.data.rows[0].objectApiName;
            }
        } else if (result.error) {
            this.error = result.error;
            this.data = undefined;
        }
    }

    get title() {
        return this.data ? this.data.title : 'Outdoor Living Workspace';
    }

    get subtitle() {
        return this.data ? this.data.subtitle : '';
    }

    get rows() {
        return (this.data?.rows || []).map((row) => ({
            ...row,
            contextValue: row.relatedName || row.subStatus || row.email || '',
            rowClass: row.id === this.selectedRecordId ? 'selected-row' : ''
        }));
    }

    get isLoading() {
        return !this.data && !this.error;
    }

    get showError() {
        return Boolean(this.error);
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((row) => row.message).join(', ');
        }
        return this.error.body ? this.error.body.message : this.error.message;
    }

    get showBackendMissing() {
        return this.data && this.data.backendMissing;
    }

    get backendMissingReason() {
        return this.data ? this.data.backendMissingReason : '';
    }

    get showWorkspace() {
        return this.data && !this.data.backendMissing;
    }

    selectRecord(event) {
        this.selectedRecordId = event.currentTarget.dataset.id;
        this.selectedObjectApiName = event.currentTarget.dataset.object;
    }

    openRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    async refreshWorkspace() {
        await refreshApex(this.wiredResult);
    }
}