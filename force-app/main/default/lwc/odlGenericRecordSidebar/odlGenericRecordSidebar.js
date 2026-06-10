import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class OdlGenericRecordSidebar extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    get recordUrl() {
        return this.recordId ? `/${this.recordId}` : '#';
    }

    handleEditRecord() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'edit' }
        });
    }

    handleViewRecord() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'view' }
        });
    }
}
