import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getLotDetail from '@salesforce/apex/LovingLotWorkspaceController.getLotDetail';

export default class LovingLotPage extends NavigationMixin(LightningElement) {
    @api recordId;

    activeTab = 'details';
    errorMsg = '';
    isEditModalOpen = false;
    editingField;
    editingLabel;
    editingObjectApiName = 'Lot__c';
    wiredDetail;

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

    lot;

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
}