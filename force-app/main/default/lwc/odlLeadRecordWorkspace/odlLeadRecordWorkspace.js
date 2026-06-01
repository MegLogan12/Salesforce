import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLLeadRecordController.getPageData';

const EDIT_ACTION = 'Lead.Edit';
const NEW_TASK_ACTION = 'Global.NewTask';
const LOG_CALL_ACTION = 'Global.LogACall';

export default class OdlLeadRecordWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;

    pageData;
    error;

    @wire(getPageData, { leadId: '$recordId' })
    wiredPageData({ data, error }) {
        if (data) {
            this.pageData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.pageData = undefined;
        }
    }

    get leadRecord() {
        return this.pageData?.leadRecord || {};
    }

    get hasData() {
        return Boolean(this.pageData);
    }

    get pathLabel() {
        return this.pageData?.odPath || '';
    }

    get statusPathItems() {
        const current = this.leadRecord.Status;
        let currentSeen = false;
        return (this.pageData?.statusPath || []).map((label) => {
            const isCurrent = label === current || (label === 'Converted' && this.leadRecord.ConvertedAccountId);
            const state = currentSeen ? 'upcoming' : (isCurrent ? 'current' : 'done');
            if (isCurrent) currentSeen = true;
            return { label, className: `path-step ${state}` };
        });
    }

    get hasServiceInterests() {
        return (this.pageData?.serviceInterests || []).length > 0;
    }

    get serviceInterestText() {
        return (this.pageData?.serviceInterests || []).join(', ');
    }

    get hasInteractions() {
        return (this.pageData?.interactions || []).length > 0;
    }

    get hasCampaign() {
        return Boolean(this.pageData?.latestCampaign);
    }

    get hasVoucher() {
        return Boolean(this.pageData?.voucherRecord);
    }

    get hasConvertedAccount() {
        return Boolean(this.pageData?.convertedAccountUrl);
    }

    get hasMissingData() {
        return (this.pageData?.missingData || []).length > 0;
    }

    get lastAction() {
        return this.normalizeFallback(this.pageData?.lastAction);
    }

    get lastActionDate() {
        return this.normalizeFallback(this.pageData?.lastActionDate);
    }

    get nextFollowUpSubject() {
        return this.normalizeFallback(this.pageData?.nextFollowUpSubject);
    }

    get nextFollowUpDate() {
        return this.normalizeFallback(this.pageData?.nextFollowUpDate);
    }

    get voicemailStatus() {
        return this.pageData?.lastActionWasVoicemail ? 'Yes' : 'No';
    }

    get smsConsentLabel() {
        return this.leadRecord.SMS_Consent__c ? 'Yes' : 'No';
    }

    normalizeFallback(value) {
        const text = String(value || '').trim();
        if (!text) {
            return '';
        }
        return text.toLowerCase().startsWith('no ') ? '' : text;
    }

    get errorMessage() {
        if (!this.error) return '';
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((item) => item.message).join(', ');
        }
        return this.error.body ? this.error.body.message : this.error.message;
    }

    handleEditLead() {
        this.navigateAction(EDIT_ACTION);
    }

    handleNewTask() {
        this.navigateAction(NEW_TASK_ACTION);
    }

    handleLogCall() {
        this.navigateAction(LOG_CALL_ACTION);
    }

    navigateAction(apiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName },
            state: { recordId: this.recordId }
        });
    }
}