import { LightningElement, api, wire } from 'lwc';
import getScope from '@salesforce/apex/LotRecordController.getScope';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LotInstallScope extends LightningElement {
    @api recordId;
    scope;
    isEditing = false;
    wiredScopeResult;

    @wire(getScope, { lotId: '$recordId' })
    onScope(result) {
        this.wiredScopeResult = result;
        if (result.data) this.scope = result.data;
    }

    get editButtonLabel() {
        return this.isEditing ? 'Close Editor' : 'Edit Scope';
    }

    handleToggleEdit() {
        this.isEditing = !this.isEditing;
    }

    handleCancel() {
        this.isEditing = false;
    }

    async handleSuccess() {
        this.isEditing = false;
        await refreshApex(this.wiredScopeResult);
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Install scope updated',
                message: 'Lot scope values were saved successfully.',
                variant: 'success'
            })
        );
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Unable to save install scope',
                message: event.detail?.message || 'Review the highlighted fields and try again.',
                variant: 'error'
            })
        );
    }
}