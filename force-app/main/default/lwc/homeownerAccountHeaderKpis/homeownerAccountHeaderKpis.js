import { LightningElement, api, wire } from 'lwc';
import getPageData from '@salesforce/apex/HomeownerAccountPageController.getPageData';

export default class HomeownerAccountHeaderKpis extends LightningElement {
    @api recordId;

    pageData;
    errorMessage;

    @wire(getPageData, { accountId: '$recordId' })
    wiredPageData({ data, error }) {
        if (data) {
            this.pageData = data;
            this.errorMessage = undefined;
        } else if (error) {
            this.pageData = undefined;
            this.errorMessage = this.reduceError(error);
        }
    }

    reduceError(error) {
        if (!error) {
            return '';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error.body ? error.body.message : error.message;
    }

    get openOpportunities() {
        return this.pageData?.kpis?.openOpportunities ?? 0;
    }

    get openWorkOrders() {
        return this.pageData?.kpis?.openWorkOrders ?? 0;
    }

    get openTasks() {
        return this.pageData?.kpis?.openTasks ?? 0;
    }

    get depositPosted() {
        const milestones = this.pageData?.paymentMilestones || [];
        return milestones.reduce((sum, row) => {
            const value = Number(String(row.notesPreview || '0').replace(/[^0-9.-]/g, ''));
            return sum + (Number.isFinite(value) ? value : 0);
        }, 0);
    }

    get depositPostedLabel() {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(this.depositPosted);
    }
}