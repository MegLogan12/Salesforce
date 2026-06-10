import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLLeadRecordController.getPageData';

export default class OdlLeadRecordSidebar extends NavigationMixin(LightningElement) {
    @api recordId;
    pageData;

    @wire(getPageData, { leadId: '$recordId' })
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
        if ((this.pageData.missingData || []).length > 0) {
            actions.push('Resolve data gaps listed in the Missing Data section below.');
        }
        if ((this.pageData.serviceInterests || []).length === 0) {
            actions.push('Flag at least one service interest on this lead.');
        }
        if (actions.length === 0) {
            actions.push('No immediate action is blocking this lead.');
        }
        return actions.slice(0, 3);
    }

    get missingData() {
        return (this.pageData?.missingData || []).slice(0, 4);
    }

    get hasMissingData() {
        return this.missingData.length > 0;
    }

    get serviceInterests() {
        return this.pageData?.serviceInterests || [];
    }

    get hasServiceInterests() {
        return this.serviceInterests.length > 0;
    }

    handleDisqualify() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'edit' }
        });
    }

    handleLogActivity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: this.recordId }
        });
    }

    handleSendEmail() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.SendEmail' },
            state: { recordId: this.recordId }
        });
    }
}
