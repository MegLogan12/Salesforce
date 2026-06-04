import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class OdlPaymentSchedule extends NavigationMixin(LightningElement) {
    @api paymentData;
    @api isUmb;
    @api recordId;

    get depositPaidDateDisplay() {
        const d = this.paymentData?.depositPaidDate;
        if (!d) return null;
        return new Date(d).toLocaleDateString('en-US', {
            month: 'short', day: 'numeric', year: 'numeric'
        });
    }

    get remainingClass() {
        const rem = this.paymentData?.remainingBalance ?? 0;
        return rem <= 0
            ? 'payment-value payment-value-strong payment-remaining-paid'
            : 'payment-value payment-value-strong payment-remaining-due';
    }

    handleDownloadPdf() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'view' }
        });
    }

    handleRecordPayment() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'edit' }
        });
    }
}
