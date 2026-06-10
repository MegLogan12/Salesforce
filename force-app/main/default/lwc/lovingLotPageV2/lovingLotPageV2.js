import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getLotDetail from '@salesforce/apex/LovingLotWorkspaceController.getLotDetail';

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
export default class LovingLotPageV2 extends NavigationMixin(LightningElement) {
    static shellStyleId = 'loving-lot-record-v2-shell-style';

    @api recordId;

    activeTab = 'details';
    errorMsg = '';
    isEditModalOpen = false;
    editingField;
    editingLabel;
    editingObjectApiName = 'Lot__c';
    wiredDetail;
    lot;

    connectedCallback() {
        this.ensureShellStyle();
    }

    disconnectedCallback() {
        this.removeShellStyle();
    }

    @wire(getLotDetail, { lotId: '$recordId' })
    wiredLotDetail(result) {
        this.wiredDetail = result;
        if (result.data) {
            this.lot = result.data;
            this.errorMsg = '';
        } else if (result.error) {
            this.errorMsg = this.normalizeError(result.error);
        }
    }

    ensureShellStyle() {
        if (typeof window === 'undefined' || typeof document === 'undefined') {
            return;
        }
        if (!window.location.pathname.includes('/lightning/r/Lot__c/')) {
            return;
        }
        if (document.getElementById(LovingLotPageV2.shellStyleId)) {
            return;
        }
        const style = document.createElement('style');
        style.id = LovingLotPageV2.shellStyleId;
        style.textContent = `
            .flexipageHeader,
            app-flexipage-header {
                display: none !important;
            }
            .recordHomeFlexipage,
            .oneRecordHomeFlexipage2,
            .slds-template__container,
            .slds-template_default,
            .forcegenerated-flexipage_loving_lot_record_page_lot__c__view_js,
            .forcegenerated-flexipage_loving_lot_record_page_v2_lot__c__view_js,
            .forcegenerated-flexipage_loving_lot_record_page_lot__c__view_js .region-main,
            .forcegenerated-flexipage_loving_lot_record_page_v2_lot__c__view_js .region-main,
            .forcegenerated-flexipage_loving_lot_record_page_lot__c__view_js .flexipageComponent,
            .forcegenerated-flexipage_loving_lot_record_page_v2_lot__c__view_js .flexipageComponent,
            [class*="forcegenerated-flexipage_loving_lot_record_page_v2"] {
                max-width: none !important;
                width: 100% !important;
            }
            [class*="forcegenerated-flexipage_loving_lot_record_page_v2"] .slds-grid,
            [class*="forcegenerated-flexipage_loving_lot_record_page_v2"] .slds-col,
            [class*="forcegenerated-flexipage_loving_lot_record_page_v2"] .slds-col--padded,
            [class*="forcegenerated-flexipage_loving_lot_record_page_v2"] .flexipageComponent {
                box-sizing: border-box !important;
                flex: 1 1 100% !important;
                max-width: none !important;
                width: 100% !important;
            }
        `;
        document.head.appendChild(style);
    }

    removeShellStyle() {
        if (typeof document === 'undefined') {
            return;
        }
        document.getElementById(LovingLotPageV2.shellStyleId)?.remove();
    }

    get isLoading() {
        return !this.lot && !this.errorMsg;
    }

    get lotInfoFields() {
        if (!this.lot) return [];
        return [...(this.lot.lotInformationLeft || []), ...(this.lot.lotInformationRight || [])];
    }

    get propertyFields() {
        if (!this.lot) return [];
        return [...(this.lot.propertyDetailsLeft || []), ...(this.lot.propertyDetailsRight || [])];
    }

    get showDetails() {
        return this.activeTab === 'details';
    }

    get showPipeline() {
        return this.activeTab === 'pipeline';
    }

    get showWorkOrderPanel() {
        return this.activeTab === 'workorders';
    }

    get showPhotos() {
        return this.activeTab === 'photos';
    }

    get showAqua() {
        return this.activeTab === 'aqua';
    }

    get photoMessage() {
        return `${this.lot?.photoCount || 0} photos are linked through the latest takeoff/photo count.`;
    }

    get aquaStatus() {
        const aqua = (this.lot?.propertyDetailsRight || []).find((field) => field.label === 'Aqua Service');
        return aqua?.value || 'N/A';
    }

    setTab(event) {
        this.activeTab = event.detail;
    }

    showWorkOrders() {
        this.activeTab = 'workorders';
    }

    handleEditField(event) {
        this.editingField = event.detail.fieldApiName;
        this.editingLabel = event.detail.label;
        this.editingObjectApiName = event.detail.objectApiName || 'Lot__c';
        this.isEditModalOpen = true;
    }

    closeEditModal() {
        this.isEditModalOpen = false;
        this.editingField = null;
        this.editingLabel = null;
        this.editingObjectApiName = 'Lot__c';
    }

    async handleEditSuccess() {
        this.closeEditModal();
        await refreshApex(this.wiredDetail);
        this.dispatchEvent(new ShowToastEvent({ title: 'Lot updated', message: 'The field was saved.', variant: 'success' }));
    }

    handleEditError(event) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Could not save field', message: this.normalizeError(event.detail), variant: 'error' }));
    }

    handleEditRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: 'Lot__c', actionName: 'edit' }
        });
    }

    handleNewWorkOrder() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'WorkOrder', actionName: 'new' }
        });
    }

    normalizeError(error) {
        return error?.body?.message || error?.message || 'Something went wrong loading the lot page.';
    }
    renderedCallback() {
        applyFullWidthLayout(this.template.host);
    }

}