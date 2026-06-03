import { LightningElement, api, wire } from 'lwc';
import getView from '@salesforce/apex/SiteReadinessController.getView';

export default class SiteReadinessConsole extends LightningElement {

    @api recordId;

    view         = null;
    errorMessage = null;
    isLoading    = true;

    @wire(getView, { serviceAppointmentId: '$recordId' })
    wiredView({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.view         = data;
            this.errorMessage = null;
        } else if (error) {
            this.view         = null;
            this.errorMessage = this._errMsg(error);
        }
    }

    // ── Derived getters ───────────────────────────────────────────────────

    get hasView()  { return this.view != null; }
    get hasError() { return this.errorMessage != null; }

    get communityDisplay() {
        return (this.view && this.view.communityName)
            ? this.view.communityName
            : '—';
    }

    get scheduledDateDisplay() {
        if (!this.view || !this.view.scheduledDate) return '—';
        return new Date(this.view.scheduledDate).toLocaleDateString(
            'en-US', { month: 'short', day: 'numeric', year: 'numeric' }
        );
    }

    get overallBadgeCss() {
        const base = 'slds-badge slds-m-left_x-small';
        return this.view && this.view.allGatesPassed
            ? base + ' slds-badge_lightest srcons-badge-green'
            : base + ' srcons-badge-amber';
    }

    get overallBadgeLabel() {
        return this.view && this.view.allGatesPassed
            ? 'All Gates Clear'
            : 'Gates Open';
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    _errMsg(err) {
        if (typeof err === 'string') return err;
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'Unexpected error loading site readiness data.';
    }
}
