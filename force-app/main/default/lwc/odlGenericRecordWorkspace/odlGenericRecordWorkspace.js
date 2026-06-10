import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

function applyFullWidthLayout(host) {
    try {
        if (typeof window === 'undefined' || !host) return false;
        const rect = host.getBoundingClientRect();
        if (!rect || rect.width === 0) return false;
        const vw = window.innerWidth;
        if (rect.right < vw - 20) {
            host.style.setProperty('width', `${vw - rect.left}px`, 'important');
            host.style.setProperty('max-width', 'none', 'important');
        }
        if (rect.top > 95) {
            host.style.setProperty('margin-top', `-${Math.round(rect.top - 90)}px`, 'important');
        }
        return true;
    } catch (e) {
        return false;
    }
}
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
