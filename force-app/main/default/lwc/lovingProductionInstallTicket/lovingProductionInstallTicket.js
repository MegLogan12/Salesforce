import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getWoRecord from '@salesforce/apex/LovingProductionInstallController.getWoRecord';
import submitFieldComplete from '@salesforce/apex/LovingProductionInstallController.submitFieldComplete';

export default class LovingProductionInstallTicket extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isLoading = false;
    @track errorMessage = null;
    @track toastMessage = null;
    @track toastVariant = 'success';
    @track dto = null;

    _wiredWo;

    @wire(getWoRecord, { woId: '$recordId' })
    wiredWo(result) {
        this._wiredWo = result;
        if (result.data) {
            this.dto = result.data;
            this.errorMessage = null;
        } else if (result.error) {
            this.errorMessage = result.error.body ? result.error.body.message : 'Failed to load Work Order.';
            this.dto = null;
        }
    }

    // ── State ─────────────────────────────────────────────────────────────────

    get hasRecord() { return !!this.dto; }

    get hasLineItems() {
        return this.dto && this.dto.lineItems && this.dto.lineItems.length > 0;
    }

    get submitDisabled() {
        return !this.dto || !this.dto.canSubmit;
    }

    get submitBlocked() {
        return this.dto && !this.dto.canSubmit && !!this.dto.submitBlockReason;
    }

    // ── Display helpers ───────────────────────────────────────────────────────

    get statusDisplay()   { return this.dto ? this.dto.status : '--'; }
    get photoDisplay()    { return this.dto ? String(this.dto.photoCount) : '0'; }
    get divisionDisplay() { return (this.dto && this.dto.divisionName) ? this.dto.divisionName : '--'; }
    get communityDisplay(){ return (this.dto && this.dto.communityName) ? this.dto.communityName : '--'; }
    get lotDisplay()      { return (this.dto && this.dto.lotName) ? this.dto.lotName : '--'; }
    get sourcePoDisplay() { return (this.dto && this.dto.sourcePo) ? this.dto.sourcePo : '--'; }

    get goalHoursDisplay() {
        if (!this.dto || this.dto.goalHours == null) return '--';
        return String(this.dto.goalHours) + ' hrs';
    }

    get toastClass() {
        return this.toastVariant === 'success'
            ? 'lpwi-alert lpwi-alert-green'
            : 'lpwi-alert lpwi-alert-red';
    }

    // Photo slot classes — lit green when at least 1 photo exists
    get beforeFrontClass() {
        return (this.dto && this.dto.photoCount > 0)
            ? 'lpwi-photo-slot lpwi-photo-done'
            : 'lpwi-photo-slot';
    }
    get beforeBackClass() {
        return (this.dto && this.dto.photoCount > 1)
            ? 'lpwi-photo-slot lpwi-photo-done'
            : 'lpwi-photo-slot';
    }
    get closeoutClass() {
        return (this.dto && this.dto.photoCount > 0)
            ? 'lpwi-photo-slot lpwi-photo-done'
            : 'lpwi-photo-slot';
    }

    // ── Precomputed gates array (no function calls in template) ───────────────

    get gatesWithClasses() {
        if (!this.dto || !this.dto.gates) return [];
        return this.dto.gates.map(gate => {
            let cssClass = 'lpwi-step';
            let dotCssClass = 'lpwi-dot';
            let dotLabel = String(gate.stepNum);
            if (gate.state === 'done') {
                cssClass = 'lpwi-step lpwi-step-done';
                dotCssClass = 'lpwi-dot lpwi-dot-done';
                dotLabel = '✓';
            } else if (gate.state === 'active') {
                cssClass = 'lpwi-step lpwi-step-active';
                dotCssClass = 'lpwi-dot lpwi-dot-active';
            }
            return Object.assign({}, gate, { cssClass, dotCssClass, dotLabel });
        });
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    handleOpenSa() {
        if (!this.dto || !this.dto.serviceAppointmentId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.dto.serviceAppointmentId, actionName: 'view' }
        });
    }

    handleAddPhotos() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'view' }
        });
    }

    handleSubmitFieldComplete() {
        if (!this.dto || !this.dto.canSubmit) return;
        this.isLoading = true;
        this.toastMessage = null;
        submitFieldComplete({ woId: this.recordId })
            .then(result => {
                if (result.success) {
                    this._showToast('success', result.message);
                    return refreshApex(this._wiredWo);
                }
                this._showToast('error', result.message);
                return null;
            })
            .catch(err => {
                this._showToast('error', err.body ? err.body.message : 'Submit failed.');
            })
            .finally(() => { this.isLoading = false; });
    }

    _showToast(variant, message) {
        this.toastVariant = variant;
        this.toastMessage = message;
        this.dispatchEvent(new ShowToastEvent({
            title: variant === 'success' ? 'Success' : 'Error',
            message,
            variant
        }));
    }
}