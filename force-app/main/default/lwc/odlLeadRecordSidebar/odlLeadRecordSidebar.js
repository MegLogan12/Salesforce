import { LightningElement, api, wire } from 'lwc';
import getPageData from '@salesforce/apex/ODLLeadRecordController.getPageData';

export default class OdlLeadRecordSidebar extends LightningElement {
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

    get hasError() {
        return Boolean(this.error);
    }

    get errorMessage() {
        if (!this.error) return '';
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((row) => row.message).join(', ');
        }
        return this.error.body?.message || this.error.message || 'Unable to load sidebar.';
    }

    get nextActions() {
        if (!this.pageData) {
            return [];
        }
        const actions = [];
        const nextSubject = String(this.pageData.nextFollowUpSubject || '').trim();
        const nextDate = String(this.pageData.nextFollowUpDate || '').trim();
        if (nextSubject && !nextSubject.toLowerCase().startsWith('no ')) {
            actions.push(nextDate ? `${nextSubject} by ${nextDate}.` : nextSubject);
        }
        if ((this.pageData.serviceInterests || []).length === 0) {
            actions.push('Capture service interest before qualifying the lead further.');
        }
        if (!this.pageData.latestCampaign) {
            actions.push('Link a Campaign Member so attribution is visible on this lead.');
        }
        return actions.slice(0, 3);
    }

    get latestInteraction() {
        return this.pageData?.interactions?.[0];
    }

    get openItems() {
        return (this.pageData?.missingData || []).slice(0, 4);
    }

    get hasOpenItems() {
        return this.openItems.length > 0;
    }
}