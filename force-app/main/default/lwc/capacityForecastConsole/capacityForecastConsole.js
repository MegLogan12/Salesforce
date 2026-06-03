import { LightningElement, api, wire } from 'lwc';
import getForecast from '@salesforce/apex/CapacityForecastController.getForecast';

export default class CapacityForecastConsole extends LightningElement {

    /** Optional division filter. Set via App Builder or parent component. */
    @api division = '';

    view         = null;
    errorMessage = null;
    isLoading    = true;

    @wire(getForecast, { division: '$division' })
    wiredForecast({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.view         = data;
            this.errorMessage = null;
        } else if (error) {
            this.view         = null;
            this.errorMessage = this._errMsg(error);
        }
    }

    // ── Derived getters ───────────────────────────────────────────────────────

    get hasView()    { return this.view != null; }
    get hasError()   { return this.errorMessage != null; }
    get hasZones()   { return this.view && this.view.zones  && this.view.zones.length  > 0; }
    get hasBacklog() { return this.view && this.view.backlog && this.view.backlog.length > 0; }

    get weekRows() {
        return (this.view && this.view.weeks) ? this.view.weeks : [];
    }

    get weeksOverCapacityCss() {
        const base = 'slds-text-heading_medium';
        if (!this.view) return base;
        return this.view.weeksOverCapacity > 0
            ? base + ' slds-text-color_error'
            : base;
    }

    get backlogCss() {
        const base = 'slds-text-heading_medium';
        if (!this.view) return base;
        return this.view.backlogCount > 0
            ? base + ' slds-text-color_warning'
            : base;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    _errMsg(err) {
        if (typeof err === 'string') return err;
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'Unexpected error loading forecast data.';
    }
}
