import { LightningElement, wire } from 'lwc';
import getDashboard from '@salesforce/apex/CooCommandCenterController.getDashboard';

export default class CooCommandCenter extends LightningElement {

    view         = null;
    errorMessage = null;
    isLoading    = true;

    @wire(getDashboard)
    wiredDashboard({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.view         = this._enrichView(data);
            this.errorMessage = null;
        } else if (error) {
            this.view         = null;
            this.errorMessage = this._errMsg(error);
        }
    }

    // ── Derived getters ───────────────────────────────────────────────────────

    get hasView()       { return this.view != null; }
    get hasError()      { return this.errorMessage != null; }
    get hasDivisions()  { return this.view && this.view.divisions  && this.view.divisions.length  > 0; }
    get hasExceptions() { return this.view && this.view.exceptions && this.view.exceptions.length > 0; }
    get hasGates()      { return this.view && this.view.gates      && this.view.gates.length      > 0; }

    get exceptionRows() {
        if (!this.view || !this.view.exceptions) return [];
        return this.view.exceptions.map(ex => ({
            ...ex,
            severityCss:   this._severityCss(ex.severity),
            severityLabel: ex.severity === 'red'   ? 'Red'
                         : ex.severity === 'amber' ? 'Amber'
                         :                           'Green'
        }));
    }

    // KPI strip: pull specific exception counts by description prefix
    get heldPOCount() {
        return this._exceptionCount('Held PO');
    }

    get closeoutCount() {
        return this._exceptionCount('Closeout');
    }

    get heldPosCss() {
        const base = 'slds-text-heading_medium';
        return this.heldPOCount > 0 ? base + ' slds-text-color_warning' : base;
    }

    get closeoutCss() {
        const base = 'slds-text-heading_medium';
        return this.closeoutCount > 0 ? base + ' slds-text-color_warning' : base;
    }

    get openGatesCss() {
        const base = 'slds-text-heading_medium';
        if (!this.view) return base;
        return this.view.totalOpenGates > 0 ? base + ' slds-text-color_error' : base;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    _enrichView(raw) {
        // Add boolean health flags to each division for conditional rendering
        const divisions = (raw.divisions || []).map(d => ({
            ...d,
            isGood:  d.health === 'good',
            isWatch: d.health === 'watch',
            isAlert: d.health === 'alert'
        }));
        return { ...raw, divisions };
    }

    _exceptionCount(keyword) {
        if (!this.view || !this.view.exceptions) return 0;
        const found = this.view.exceptions.find(
            ex => ex.description && ex.description.toLowerCase().includes(keyword.toLowerCase())
        );
        return found ? found.count : 0;
    }

    _severityCss(severity) {
        if (severity === 'red')   return 'slds-badge slds-badge_error';
        if (severity === 'amber') return 'slds-badge slds-badge_warning';
        return 'slds-badge slds-badge_success';
    }

    _errMsg(err) {
        if (typeof err === 'string') return err;
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'Unexpected error loading COO dashboard.';
    }
}
