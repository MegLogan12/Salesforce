import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLOpportunityRecordController.getPageData';

const NEW_TASK_ACTION = 'Global.NewTask';

export default class OdlOpportunityRecordWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;

    pageData;
    error;

    @wire(getPageData, { opportunityId: '$recordId' })
    wiredPageData({ data, error }) {
        if (data) {
            this.pageData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.pageData = undefined;
        }
    }

    get opportunityRecord() {
        return this.pageData?.opportunityRecord || {};
    }

    get hasData() {
        return Boolean(this.pageData);
    }

    get accountUrl() {
        return this.pageData?.accountUrl;
    }

    get accountName() {
        return this.pageData?.accountName || 'No account linked';
    }

    get projectPath() {
        return this.pageData?.projectPath || 'Not classified';
    }

    get hasInteractions() {
        return (this.pageData?.interactions || []).length > 0;
    }

    get stagePath() {
        return this.pageData?.stagePath || [];
    }

    get hasStagePath() {
        return this.stagePath.length > 0;
    }

    get stagePathItems() {
        let currentSeen = false;
        return this.stagePath.map((label) => {
            const isCurrent = label === this.opportunityRecord.StageName;
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

    get lastAction() {
        return this.pageData?.lastAction || 'No action logged';
    }

    get lastActionDate() {
        return this.pageData?.lastActionDate || 'No activity';
    }

    get voicemailStatus() {
        return this.pageData?.lastActionWasVoicemail ? 'Yes' : 'No';
    }

    get hasDesignReviews() {
        return (this.pageData?.designReviews || []).length > 0;
    }

    get hasPaymentMilestones() {
        return (this.pageData?.paymentMilestones || []).length > 0;
    }

    get hasQuotes() {
        return (this.pageData?.quotes || []).length > 0;
    }

    get hasFiles() {
        return (this.pageData?.files || []).length > 0;
    }

    get hasVoucher() {
        return Boolean(this.pageData?.voucherRecord);
    }

    get hasProperty() {
        return Boolean(this.pageData?.propertyRecord);
    }

    get missingData() {
        return this.pageData?.missingData || [];
    }

    get hasMissingData() {
        return this.missingData.length > 0;
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