import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLLeadRecordController.getPageData';

const NEW_TASK_ACTION = 'Global.NewTask';

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

    get convertedAccountUrl() {
        return this.pageData?.convertedAccountUrl;
    }

    get hasInteractions() {
        return (this.pageData?.interactions || []).length > 0;
    }

    get statusPath() {
        return this.pageData?.statusPath || [];
    }

    get hasStatusPath() {
        return this.statusPath.length > 0;
    }

    get statusPathItems() {
        let currentSeen = false;
        return this.statusPath.map((label) => {
            const isCurrent = label === this.leadRecord.Status;
            const state = currentSeen ? 'upcoming' : (isCurrent ? 'current' : 'done');
            if (isCurrent) {
                currentSeen = true;
            }
            return {
                label,
                className: `path-step ${state}`
            };
        });
    }

    get voicemailStatus() {
        return this.pageData?.lastActionWasVoicemail ? 'Yes' : 'No';
    }

    get hasVoucher() {
        return Boolean(this.pageData?.voucherRecord);
    }

    get hasCampaign() {
        return Boolean(this.pageData?.latestCampaign);
    }

    get hasVoucherOrCampaign() {
        return this.hasVoucher || this.hasCampaign;
    }

    get hasMissingData() {
        return (this.pageData?.missingData || []).length > 0;
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((item) => item.message).join(', ');
        }
        return this.error.body ? this.error.body.message : this.error.message;
    }

    handleNewTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: NEW_TASK_ACTION
            },
            state: {
                recordId: this.recordId
            }
        });
    }
}
