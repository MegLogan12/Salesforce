import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getOpenHireRequests from '@salesforce/apex/VpEscalationsController.getOpenHireRequests';
import getEscalationTasks  from '@salesforce/apex/VpEscalationsController.getEscalationTasks';
import approveHireRequest  from '@salesforce/apex/VpEscalationsController.approveHireRequest';
import denyHireRequest     from '@salesforce/apex/VpEscalationsController.denyHireRequest';
import deferHireRequest    from '@salesforce/apex/VpEscalationsController.deferHireRequest';
import markTaskComplete    from '@salesforce/apex/VpEscalationsController.markTaskComplete';

export default class VpEscalationsTab extends NavigationMixin(LightningElement) {

    @track hireRequests  = [];
    @track escalTasks    = [];
    @track isLoadingHR   = true;
    @track isLoadingTask = true;
    @track hrError       = null;
    @track taskError     = null;

    // Action confirmation modal state
    @track modalOpen      = false;
    @track modalAction    = null;   // 'approve' | 'deny' | 'defer'
    @track modalHrId      = null;
    @track modalHrName    = '';
    @track modalNotes     = '';
    @track actionInFlight = false;

    // Wired result refs (needed for refreshApex)
    _wiredHR;
    _wiredTask;

    get totalEscalations() {
        return this.hireRequests.length + this.escalTasks.length;
    }

    get hasHireRequests()  { return this.hireRequests.length > 0; }
    get hasEscalTasks()    { return this.escalTasks.length > 0; }
    get hasAnyData()       { return this.hasHireRequests || this.hasEscalTasks; }
    get nothingOpen()      { return !this.isLoadingHR && !this.isLoadingTask && !this.hasAnyData; }

    get modalTitle() {
        if (this.modalAction === 'approve') return 'Approve Hire Request';
        if (this.modalAction === 'deny')    return 'Deny Hire Request';
        return 'Defer Hire Request';
    }
    get modalButtonLabel() {
        if (this.modalAction === 'approve') return 'Confirm Approval';
        if (this.modalAction === 'deny')    return 'Confirm Denial';
        return 'Confirm Deferral';
    }
    get modalButtonClass() {
        if (this.modalAction === 'approve') return 'sf-btn success';
        if (this.modalAction === 'deny')    return 'sf-btn danger';
        return 'sf-btn warning';
    }

    // ── Wire ──────────────────────────────────────
    @wire(getOpenHireRequests)
    wiredHireRequests(result) {
        this._wiredHR = result;
        this.isLoadingHR = false;
        const { data, error } = result;
        if (data) {
            this.hireRequests = data.map((r, idx) => ({
                ...r,
                index           : idx + 1,
                totalCount      : data.length,
                openedLabel     : r.createdDate ? this._formatDate(r.createdDate) : '—',
                costDisplay     : r.totalAnnualCost != null
                                  ? '$' + this._commas(Math.round(r.totalAnnualCost)) + '/yr'
                                  : '—',
                roiDisplay      : r.y1ROI != null ? r.y1ROI + '%' : '—'
            }));
            this.hrError = null;
        } else if (error) {
            this.hrError = this._errorMessage(error);
        }
    }

    @wire(getEscalationTasks)
    wiredEscalTasks(result) {
        this._wiredTask = result;
        this.isLoadingTask = false;
        const { data, error } = result;
        if (data) {
            this.escalTasks = data.map(r => ({
                ...r,
                dueDateDisplay  : r.activityDate ? this._formatDate(r.activityDate) : '—',
                chipCss         : 'chip ' + (r.statusClass || 'chip-blue'),
                cardClass       : r.statusClass === 'chip-red'
                                  ? 'strat-card urgent'
                                  : 'strat-card'
            }));
            this.taskError = null;
        } else if (error) {
            this.taskError = this._errorMessage(error);
        }
    }

    // ── Hire Request Actions ───────────────────────
    handleApproveClick(evt) { this._openModal('approve', evt); }
    handleDenyClick(evt)    { this._openModal('deny', evt); }
    handleDeferClick(evt)   { this._openModal('defer', evt); }

    _openModal(action, evt) {
        this.modalAction  = action;
        this.modalHrId    = evt.currentTarget.dataset.hrid;
        this.modalHrName  = evt.currentTarget.dataset.hrname;
        this.modalNotes   = '';
        this.modalOpen    = true;
    }

    handleNotesChange(evt) {
        this.modalNotes = evt.target.value;
    }

    handleModalCancel() {
        this.modalOpen = false;
    }

    handleModalConfirm() {
        if (!this.modalHrId || this.actionInFlight) return;
        this.actionInFlight = true;

        const apex = this.modalAction === 'approve' ? approveHireRequest
                   : this.modalAction === 'deny'    ? denyHireRequest
                   : deferHireRequest;

        apex({ hrId: this.modalHrId, decisionNotes: this.modalNotes })
            .then(() => {
                this.modalOpen      = false;
                this.actionInFlight = false;
                return refreshApex(this._wiredHR);
            })
            .catch(err => {
                this.actionInFlight = false;
                // eslint-disable-next-line no-console
                console.error('Action failed:', err);
            });
    }

    // ── Task Actions ────────────────────────────────
    handleTaskComplete(evt) {
        const taskId = evt.currentTarget.dataset.taskid;
        if (!taskId) return;
        markTaskComplete({ taskId })
            .then(() => refreshApex(this._wiredTask))
            .catch(err => {
                // eslint-disable-next-line no-console
                console.error('markTaskComplete failed:', err);
            });
    }

    // ── Navigate to record ─────────────────────────
    handleNavToRecord(evt) {
        const recordId = evt.currentTarget.dataset.recordid;
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    // ── Helpers ────────────────────────────────────
    _formatDate(dateStr) {
        if (!dateStr) return '—';
        const d = new Date(dateStr);
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    _commas(n) {
        return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }

    _errorMessage(err) {
        if (typeof err === 'string') return err;
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'Unexpected error loading escalation data.';
    }
}