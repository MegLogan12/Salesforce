import { LightningElement, api, wire } from 'lwc';
import getPageData from '@salesforce/apex/ODLOpportunityRecordController.getPageData';

export default class OdlOpportunityRecordSidebar extends LightningElement {
    @api recordId;
    pageData;

    @wire(getPageData, { opportunityId: '$recordId' })
    wiredPageData({ data }) {
        if (data) {
            this.pageData = data;
        }
    }

    get nextActions() {
        if (!this.pageData) {
            return [];
        }
        const actions = [];
        if (this.pageData.nextFollowUpSubject && this.pageData.nextFollowUpSubject !== 'No follow-up task') {
            actions.push(`${this.pageData.nextFollowUpSubject} by ${this.pageData.nextFollowUpDate}.`);
        }
        if ((this.pageData.paymentMilestones || []).length === 0) {
            actions.push('Create or link Payment Milestones before using this page for payment tracking.');
        }
        if ((this.pageData.quotes || []).length === 0) {
            actions.push('Link a Quote before using this page for quote and contract tracking.');
        }
        if (actions.length === 0) {
            actions.push('No immediate action is blocking this opportunity.');
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