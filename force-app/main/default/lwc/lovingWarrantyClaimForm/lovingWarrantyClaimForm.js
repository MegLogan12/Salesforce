import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LovingWarrantyClaimForm extends LightningElement {
    static renderMode = 'light';

    @track saved = false;

    handleSuccess() {
        this.saved = true;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Warranty claim saved',
            message: 'The claim has been recorded.',
            variant: 'success'
        }));
    }

    handleError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Save failed',
            message: e.detail.message,
            variant: 'error'
        }));
    }

    handleNew() {
        this.saved = false;
    }
}
