import { LightningElement, wire, track, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getMeasuringCup from '@salesforce/apex/LovingSchedulingConsoleOverlayController.getMeasuringCup';

export default class LovingMeasuringCupConsole extends LightningElement {
    @api defaultDivision = 'Charlotte';

    @track division;
    @track _wiredResult;
    @track _data = null;
    @track _error = null;
    @track isLoading = true;

    get _today() {
        const d = new Date();
        return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
    }

    connectedCallback() {
        this.division = this.defaultDivision || 'Charlotte';
    }

    @wire(getMeasuringCup, { schedDate: '$_today', division: '$division' })
    wiredMc(result) {
        this._wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this._data  = result.data;
            this._error = null;
        } else if (result.error) {
            this._error = result.error && result.error.body ? result.error.body.message : 'Failed to load measuring cup data.';
            this._data  = null;
        }
    }

    get kpi() {
        const d = this._data || {};
        const variance = d.dayVariance != null ? d.dayVariance : null;
        return {
            goalHours:   d.goalHours   != null ? d.goalHours   : '—',
            actualHours: d.actualHours != null ? d.actualHours : '—',
            dayVariance: variance != null ? (variance > 0 ? '+' + variance : variance) : '—',
            varianceCss: variance != null ? (variance > 0 ? 'kpi-tile amber' : 'kpi-tile green') : 'kpi-tile gray',
            crewsGreen:  d.crewsGreen  != null ? d.crewsGreen  : '—',
            crewsTotal:  d.crewsTotal  != null ? d.crewsTotal  : '—',
        };
    }

    get mcRows() {
        if (!this._data || !this._data.rows) return [];
        return this._data.rows.map(r => ({
            ...r,
            varianceCss: (r.variance > 0) ? 'var-cell over' : (r.variance < -0.5 ? 'var-cell behind' : 'var-cell ok'),
            statusCss:   r.status === 'Green' ? 'chip green' : r.status === 'Red' ? 'chip red' : 'chip amber'
        }));
    }
    get hasMcRows()  { return this.mcRows.length > 0; }
    get hasData()    { return !!this._data; }
    get hasError()   { return !!this._error; }
    get errorMsg()   { return this._error; }
    get todayLabel() {
        return new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => { this.isLoading = false; });
    }

    handleDivisionChange(event) {
        this.division = event.target.value;
    }
}
