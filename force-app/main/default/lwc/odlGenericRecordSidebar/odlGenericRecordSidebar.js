import { LightningElement, api, wire } from 'lwc';
import getPageData from '@salesforce/apex/ODLVisibleWorkspaceController.getPageData';

export default class OdlGenericRecordSidebar extends LightningElement {
    @api recordId;

    pageData;
    error;

    @wire(getPageData, { recordId: '$recordId' })
    wiredPageData({ data, error }) {
        if (data) {
            this.pageData = {
                ...data,
                healthItems: (data.healthItems || []).filter((item) => item && item.value)
            };
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.pageData = undefined;
        }
    }

    get hasData() {
        return Boolean(this.pageData);
    }

    get hasNextActions() {
        return this.hasData && (this.pageData.nextActions || []).length > 0;
    }

    get hasHealthItems() {
        return this.hasData && (this.pageData.healthItems || []).length > 0;
    }

    get hasOpenItems() {
        return this.hasData && (this.pageData.openItems || []).length > 0;
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
}