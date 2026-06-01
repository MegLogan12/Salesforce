import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import flagNotReady from '@salesforce/apex/SiteReadinessService.flagNotReady';

export default class LovingSiteReadinessFlag extends LightningElement {
    @api recordId;

    @track notes = '';
    isLoading  = false;
    errorMessage = null;
    notesError = false;

    get notesClass() {
        return 'lsrf-textarea' + (this.notesError ? ' lsrf-textarea-error' : '');
    }

    handleNotesChange(event) {
        this.notes = event.target.value;
        if (this.notesError && this.notes.trim()) {
            this.notesError = false;
        }
    }

    handleFlag() {
        if (!this.notes || !this.notes.trim()) {
            this.notesError = true;
            return;
        }

        this.isLoading = true;
        this.errorMessage = null;

        flagNotReady({ workOrderId: this.recordId, notes: this.notes.trim() })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Site Flagged — Not Ready',
                    message: 'Work Order placed On Hold. FM must resolve site issues before install can proceed.',
                    variant: 'warning'
                }));
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.errorMessage = error?.body?.message || 'An unexpected error occurred. Please try again.';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}