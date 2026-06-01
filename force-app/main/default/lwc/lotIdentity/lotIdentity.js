import { LightningElement, api, wire } from 'lwc';
import getHeader from '@salesforce/apex/LotRecordController.getHeader';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LotIdentity extends LightningElement {
    @api recordId;
    header;
    error;
    isEditing = false;
    wiredHeaderResult;

    @wire(getHeader, { lotId: '$recordId' })
    onHeader(result) {
        this.wiredHeaderResult = result;
        if (result.data) {
            this.header = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.header = undefined;
            this.error = (result.error.body && result.error.body.message)
                ? result.error.body.message
                : 'Unable to load lot identity.';
        }
    }

    get editButtonLabel() {
        return this.isEditing ? 'Close Editor' : 'Edit Lot';
    }

    handleToggleEdit() {
        this.isEditing = !this.isEditing;
    }

    handleCancel() {
        this.isEditing = false;
    }

    async handleSuccess() {
        this.isEditing = false;
        await refreshApex(this.wiredHeaderResult);
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Lot updated',
                message: 'Lot identity was saved successfully.',
                variant: 'success'
            })
        );
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Unable to save lot identity',
                message: event.detail?.message || 'Review the highlighted fields and try again.',
                variant: 'error'
            })
        );
    }

    get communityUrl() {
        return this.header?.communityId ? '/lightning/r/Community__c/' + this.header.communityId + '/view' : '#';
    }
}