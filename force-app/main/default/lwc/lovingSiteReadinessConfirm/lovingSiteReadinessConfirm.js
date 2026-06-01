import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import confirmReady from '@salesforce/apex/SiteReadinessService.confirmReady';

export default class LovingSiteReadinessConfirm extends LightningElement {
    @api recordId;

    isLoading = false;
    errorMessage = null;

    handleConfirm() {
        this.isLoading = true;
        this.errorMessage = null;

        confirmReady({ workOrderId: this.recordId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Site Readiness Confirmed',
                    message: 'Site marked as Ready. Install can proceed as scheduled.',
                    variant: 'success'
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