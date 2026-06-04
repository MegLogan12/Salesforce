import { LightningElement, api } from 'lwc';

export default class OdlPaymentSchedule extends LightningElement {
    @api paymentData;
    @api isUmb;

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
        console.log('handleDownloadPdf');
    }

    handleRecordPayment() {
        console.log('handleRecordPayment');
    }
}
