import { LightningElement, api } from 'lwc';

export default class OdlGenericRecordSidebar extends LightningElement {
    @api recordId;
    @api objectApiName;

    get recordUrl() {
        return this.recordId ? `/${this.recordId}` : '#';
    }

    handleEditRecord() {
        console.log('handleEditRecord');
    }

    handleViewRecord() {
        console.log('handleViewRecord');
    }
}
