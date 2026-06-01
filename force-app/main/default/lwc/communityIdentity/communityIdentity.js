import { LightningElement, api, wire } from 'lwc';
import getIdentity from '@salesforce/apex/CommunityRecordController.getIdentity';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CommunityIdentity extends LightningElement {
    @api recordId;
    rows = [];
    isEditing = false;
    wiredIdentityResult;
    loadError;

    @wire(getIdentity, { communityId: '$recordId' })
    wired(result) {
        this.wiredIdentityResult = result;
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
        return this.loadError?.body?.message || this.loadError?.message || '0 populated identity fields on this community.';
    }

    get editButtonLabel() {
        return this.isEditing ? 'Close Editor' : 'Edit Identity';
    }

    handleToggleEdit() {
        this.isEditing = !this.isEditing;
    }

    handleCancel() {
        this.isEditing = false;
    }

    async handleSuccess() {
        this.isEditing = false;
        await refreshApex(this.wiredIdentityResult);
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Community updated',
                message: 'Community identity was saved successfully.',
                variant: 'success'
            })
        );
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Unable to save community identity',
                message: event.detail?.message || 'Review the highlighted fields and try again.',
                variant: 'error'
            })
        );
    }
}