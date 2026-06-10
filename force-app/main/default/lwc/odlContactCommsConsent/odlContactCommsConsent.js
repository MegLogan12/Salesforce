import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class OdlContactCommsConsent extends LightningElement {
    @api pageData;

    get phoneDisplay() {
        const c = this.pageData?.contactRecord;
        return c?.MobilePhone ?? c?.Phone ?? '—';
    }

    get emailSubtext() {
        if (!this.pageData?.contactRecord?.Email) return 'No email on record';
        if (this.pageData.emailOptedOut) return 'Opted out of marketing emails';
        return 'Receiving marketing emails';
    }

    get emailStatusClass() {
        const s = this.pageData?.emailStatus;
        if (s === 'Subscribed') return 'chan-val consent-on';
        if (s === 'Bounced')    return 'chan-val consent-warn';
        return 'chan-val consent-off';
    }

    get smsStatusLabel() {
        return this.pageData?.smsConsent ? 'Opted in' : 'Not opted in';
    }

    get smsStatusClass() {
        return this.pageData?.smsConsent ? 'chan-val consent-on' : 'chan-val consent-off';
    }

    get smsSubtext() {
        const date = this.pageData?.smsOptInDate;
        const src  = this.pageData?.smsOptInSource;
        if (!this.pageData?.smsConsent) return 'Consent required before texting';
        if (date && src) return date + ', ' + src;
        if (date)        return date;
        return 'Opted in';
    }

    get sendTextDisabled() {
        return !this.pageData?.smsConsent;
    }

    get sendTextBtnClass() {
        return this.sendTextDisabled
            ? 'sms-btn sms-btn-disabled'
            : 'sms-btn sms-btn-active';
    }

    get sendTextLabel() {
        return this.sendTextDisabled ? 'Send Text (consent required)' : 'Send Text';
    }

    get commsChipClass() {
        const cls = this.pageData?.commsChipClass;
        return 'comms-chip ' + (cls ?? 'chip-slate');
    }

    handleSendText() {
        if (this.sendTextDisabled) return;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Send Text',
            message: 'SMS action — wire to your SMS provider.',
            variant: 'info'
        }));
    }
}
