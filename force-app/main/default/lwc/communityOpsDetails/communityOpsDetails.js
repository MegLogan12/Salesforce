import { LightningElement, api, wire } from 'lwc';
import getOperational from '@salesforce/apex/CommunityRecordController.getOperational';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CommunityOpsDetails extends LightningElement {
    @api recordId;
    rows = [];
    isEditing = false;
    wiredOperationalResult;
    loadError;

    @wire(getOperational, { communityId: '$recordId' })
    wired(result) {
        this.wiredOperationalResult = result;
        if (result.data) {
            this.rows = result.data;
            this.loadError = undefined;
        } else if (result.error) {
            this.rows = [];
            this.loadError = result.error;
        }
    }

    get hasRows() { return this.rows && this.rows.length > 0; }

    get emptyMessage() {
        return this.loadError?.body?.message || this.loadError?.message || '0 populated operational fields on this community.';
    }

    get editButtonLabel() {
        return this.isEditing ? 'Close Editor' : 'Edit Operations';
    }

    handleToggleEdit() {
        this.isEditing = !this.isEditing;
    }

    handleCancel() {
        this.isEditing = false;
    }

    async handleSuccess() {
        this.isEditing = false;
        await refreshApex(this.wiredOperationalResult);
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Operational details updated',
                message: 'Community operations were saved successfully.',
                variant: 'success'
            })
        );
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Unable to save operational details',
                message: event.detail?.message || 'Review the highlighted fields and try again.',
                variant: 'error'
            })
        );
    }
}