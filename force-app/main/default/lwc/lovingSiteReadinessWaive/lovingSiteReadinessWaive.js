import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import waiveReadiness from '@salesforce/apex/SiteReadinessService.waiveReadiness';

export default class LovingSiteReadinessWaive extends LightningElement {
    @api recordId;

    @track reason = '';
    isLoading    = false;
    errorMessage = null;
    reasonError  = false;

    get reasonClass() {
        return 'lsrw-textarea' + (this.reasonError ? ' lsrw-textarea-error' : '');
    }

    handleReasonChange(event) {
        this.reason = event.target.value;
        if (this.reasonError && this.reason.trim()) {
            this.reasonError = false;
        }
    }

    handleWaive() {
        if (!this.reason || !this.reason.trim()) {
            this.reasonError = true;
            return;
        }

        this.isLoading = true;
        this.errorMessage = null;

        waiveReadiness({ workOrderId: this.recordId, waiverReason: this.reason.trim() })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Site Readiness Waived',
                    message: 'Waiver recorded. Work Order returned to Scheduled — install can proceed.',
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