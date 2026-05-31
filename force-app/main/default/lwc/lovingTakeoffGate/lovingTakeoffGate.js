import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getKpiSummary from '@salesforce/apex/LovingTakeoffGateController.getKpiSummary';
import getTakeoffRecord from '@salesforce/apex/LovingTakeoffGateController.getTakeoffRecord';
import approveTakeoff from '@salesforce/apex/LovingTakeoffGateController.approveTakeoff';
import returnTakeoff from '@salesforce/apex/LovingTakeoffGateController.returnTakeoff';

export default class LovingTakeoffGate extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isLoading = false;
    @track errorMessage = null;
    @track toastMessage = null;
    @track toastVariant = 'success';
    @track dto = null;
    @track kpi = { totalTakeoffs: 0, returned: 0, matched: 0, submitted: 0 };
    @track showReturnPanel = false;
    @track nfiReason = '';

    _wiredTakeoff;
    _wiredKpi;

    @wire(getKpiSummary)
    wiredKpi(result) {
        this._wiredKpi = result;
        if (result.data) {
            this.kpi = result.data;
        }
    }

    @wire(getTakeoffRecord, { takeoffId: '$recordId' })
    wiredTakeoff(result) {
        this._wiredTakeoff = result;
        if (result.data) {
            this.dto = result.data;
            this.errorMessage = null;
        } else if (result.error) {
            this.errorMessage = result.error.body
                ? result.error.body.message
                : 'Failed to load Takeoff data.';
            this.dto = null;
        }
    }

    // ── Basic state ──────────────────────────────────────────────────────────

    get hasRecord() {
        return !!this.dto;
    }

    get hasLineItems() {
        return this.dto && this.dto.lineItems && this.dto.lineItems.length > 0;
    }

    get approveDisabled() {
        return !this.dto || !this.dto.canApprove;
    }

    get returnDisabled() {
        return !this.nfiReason || this.nfiReason.trim().length === 0;
    }

    get woDisabled() {
        return !this.dto || !this.dto.canCreateWo;
    }

    // ── Precomputed arrays (no function calls allowed in LWC templates) ──────

    get gatesWithClasses() {
        if (!this.dto || !this.dto.gates) return [];
        return this.dto.gates.map(gate => {
            let cssClass = 'ltg-step';
            let dotCssClass = 'ltg-dot';
            let dotLabel = String(gate.stepNum);
            if (gate.state === 'done') {
                cssClass = 'ltg-step ltg-step-done';
                dotCssClass = 'ltg-dot ltg-dot-done';
                dotLabel = '✓';
            } else if (gate.state === 'active') {
                cssClass = 'ltg-step ltg-step-active';
                dotCssClass = 'ltg-dot ltg-dot-active';
            } else if (gate.state === 'blocked') {
                cssClass = 'ltg-step ltg-step-blocked';
                dotCssClass = 'ltg-dot ltg-dot-blocked';
            }
            return Object.assign({}, gate, { cssClass, dotCssClass, dotLabel });
        });
    }

    get lineItemsWithClasses() {
        if (!this.dto || !this.dto.lineItems) return [];
        return this.dto.lineItems.map(li => {
            let decisionClass = 'ltg-chip ltg-chip-amber';
            if (li.decision === 'Match')    decisionClass = 'ltg-chip ltg-chip-green';
            if (li.decision === 'Mismatch') decisionClass = 'ltg-chip ltg-chip-red';
            if (li.decision === 'Missing')  decisionClass = 'ltg-chip ltg-chip-red';
            return Object.assign({}, li, { decisionClass });
        });
    }

    // ── Display helpers ───────────────────────────────────────────────────────

    get statusChipClass() {
        if (!this.dto) return 'ltg-chip';
        const s = this.dto.status;
        if (s === 'Approved')    return 'ltg-chip ltg-chip-green';
        if (s === 'Returned')    return 'ltg-chip ltg-chip-red';
        if (s === 'Submitted')   return 'ltg-chip ltg-chip-blue';
        if (s === 'In Progress') return 'ltg-chip ltg-chip-amber';
        return 'ltg-chip ltg-chip-gray';
    }

    get toastClass() {
        return this.toastVariant === 'success'
            ? 'ltg-alert ltg-alert-green'
            : 'ltg-alert ltg-alert-red';
    }

    get woBlockedReason() {
        if (!this.dto) return '';
        if (this.dto.status !== 'Approved') return 'Takeoff must be in Approved status.';
        if (!this.dto.csApproved)           return 'Purchase Order approval process must be complete.';
        return 'Gates not yet passed.';
    }

    get divisionDisplay()   { return (this.dto && this.dto.divisionName)   ? this.dto.divisionName   : '--'; }
    get communityDisplay()  { return (this.dto && this.dto.communityName)  ? this.dto.communityName  : '--'; }
    get lotDisplay()        { return (this.dto && this.dto.lotName)        ? this.dto.lotName        : '--'; }
    get packageDisplay()    { return (this.dto && this.dto.packageCode)    ? this.dto.packageCode    : 'Not set'; }
    get approvedByDisplay() { return (this.dto && this.dto.approvedByName) ? this.dto.approvedByName : '--'; }
    get fmDisplay()         { return (this.dto && this.dto.fmName)         ? this.dto.fmName         : '--'; }

    get poApprovalDisplay() {
        if (!this.dto) return '--';
        return this.dto.csApproved ? 'Complete' : 'Pending';
    }

    get photoDisplay() {
        const count = (this.dto && this.dto.photoCount) ? this.dto.photoCount : 0;
        return count > 0 ? String(count) : '0 — required before approval';
    }

    get checklistDisplay() {
        if (!this.dto) return '--';
        return this.dto.checklistComplete ? 'Complete' : 'Incomplete — required before approval';
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    handleApproveTakeoff() {
        if (!this.dto || !this.dto.canApprove) return;
        this.isLoading = true;
        this.toastMessage = null;
        approveTakeoff({ takeoffId: this.recordId })
            .then(result => {
                if (result.success) {
                    this._showToast('success', result.message);
                    return Promise.all([
                        refreshApex(this._wiredTakeoff),
                        refreshApex(this._wiredKpi)
                    ]);
                }
                this._showToast('error', result.message);
                return null;
            })
            .catch(err => {
                this._showToast('error', err.body ? err.body.message : 'Approve failed.');
            })
            .finally(() => { this.isLoading = false; });
    }

    handleReturnTakeoff() {
        this.showReturnPanel = true;
        this.nfiReason = '';
    }

    handleCancelReturn() {
        this.showReturnPanel = false;
        this.nfiReason = '';
    }

    handleNfiReasonChange(event) {
        this.nfiReason = event.target.value;
    }

    handleConfirmReturn() {
        if (!this.nfiReason || this.nfiReason.trim().length === 0) return;
        this.isLoading = true;
        this.toastMessage = null;
        returnTakeoff({ takeoffId: this.recordId, nfiReason: this.nfiReason })
            .then(result => {
                if (result.success) {
                    this.showReturnPanel = false;
                    this.nfiReason = '';
                    this._showToast('success', result.message);
                    return Promise.all([
                        refreshApex(this._wiredTakeoff),
                        refreshApex(this._wiredKpi)
                    ]);
                }
                this._showToast('error', result.message);
                return null;
            })
            .catch(err => {
                this._showToast('error', err.body ? err.body.message : 'Return failed.');
            })
            .finally(() => { this.isLoading = false; });
    }

    handleOpenPO() {
        if (!this.dto || !this.dto.poId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.dto.poId, actionName: 'view' }
        });
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