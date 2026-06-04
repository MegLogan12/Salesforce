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
        if (!this.pageData) return [];
        const actions = [];
        if (this.pageData.nextActionText) {
            const btn = this.pageData.nextActionButton ? ` → ${this.pageData.nextActionButton}` : '';
            actions.push(`${this.pageData.nextActionText}${btn}`);
        }
        if (this.pageData.nextFollowUpSubject && this.pageData.nextFollowUpSubject !== 'No follow-up task') {
            actions.push(`Follow-up: ${this.pageData.nextFollowUpSubject} by ${this.pageData.nextFollowUpDate}.`);
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

    handleCreateTask() {
        console.log('handleCreateTask');
    }

    handleLogActivity() {
        console.log('handleLogActivity');
    }
}