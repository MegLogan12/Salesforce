import { LightningElement, api, wire } from 'lwc';
import getContactPageData from '@salesforce/apex/ODLContactRecordController.getContactPageData';

export default class OdlContactRecordSidebar extends LightningElement {
    @api recordId;

    @wire(getContactPageData, { contactId: '$recordId' })
    wiredData;

    get pageData()  { return this.wiredData?.data ?? null; }
    get hasData()   { return this.pageData != null; }
    get hasActivity() {
        return (this.pageData?.recentActivity ?? []).length > 0;
    }

    get accountInitials() {
        const name = this.pageData?.accountName ?? '';
        return name.split(' ').map(w => w[0]).join('').toUpperCase().substring(0, 2);
    }

    get ownerInitials() {
        const name = this.pageData?.ownerName ?? '';
        return name.split(' ').map(w => w[0]).join('').toUpperCase().substring(0, 2);
    }
}
