import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import { applyFullWidthLayout } from 'c/lovingLayoutUtils';
export default class OdlGenericRecordWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    handleEditRecord() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'edit' }
        });
    }
    renderedCallback() {
        applyFullWidthLayout(this.template.host);
    }

}
