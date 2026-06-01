import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCurrentSnapshot    from '@salesforce/apex/CapacityForecastService.getCurrentSnapshot';
import calculateROI          from '@salesforce/apex/CapacityForecastService.calculateROI';
import getOpenHireRequests   from '@salesforce/apex/HomeDashboardController.getOpenHireRequests';

const TABS = [
    { id: 'capacity',     label: 'Capacity vs Demand', icon: '📊' },
    { id: 'hireRequests', label: 'Hire Requests',      icon: '📋' },
    { id: 'roiCalc',      label: 'ROI Calculator',     icon: '🧮' }
];

export default class LovingForecastingConsole extends NavigationMixin(LightningElement) {

    @api pageTitle = 'Forecasting & Hiring';

    @track activeTab       = 'capacity';
    @track errorMsg        = null;

    @track snapshot        = null;
    @track hireRequests    = [];

    // ROI calc state
    @track calcQuantity       = 1;
    @track calcAnnualCost     = 70000;
    @track calcHoursPerWeek   = 40;
    @track calcRevenuePerHour = 95;
    @track calcUtilizationPct = 80;
    @track roiResult          = null;

    // ── Tabs ─────────────────────────────────────
    get tabs() {
        return TABS.map(t => ({
            ...t,
            css: 'tab-btn' + (t.id === this.activeTab ? ' active' : '')
        }));
    }

    get tabCapacity()     { return this.activeTab === 'capacity'; }
    get tabHireRequests() { return this.activeTab === 'hireRequests'; }
    get tabRoiCalc()      { return this.activeTab === 'roiCalc'; }

    // ── Wire ─────────────────────────────────────
    @wire(getCurrentSnapshot)
    wiredSnapshot({ data, error }) {
        if (data) {
            const copy = JSON.parse(JSON.stringify(data));
            copy.serviceLines = (copy.serviceLines || []).map(sl => {
                const width = Math.min(sl.utilizationPct || 0, 150);
                return {
                    ...sl,
                    barStyle:      'width: ' + width + '%;',
                    barCss:        'fc-bar-fill fc-bar-' + (sl.status || 'gray'),
                    statusChipCss: 'chip chip-' + (sl.status === 'green' ? 'green'
                                    : sl.status === 'amber' ? 'amber'
                                    : sl.status === 'red'   ? 'red'
                                    : 'gray')
                };
            });
            this.snapshot = copy;
        } else if (error) {
            this.errorMsg = this._errMsg(error);
        }
    }

    @wire(getOpenHireRequests)
    wiredHireRequests({ data, error }) {
        if (data) {
            this.hireRequests = data.map(r => ({
                ...r,
                costDisplay: r.totalCost ? '$' + Number(r.totalCost).toLocaleString() : '—',
                roiDisplay:  r.y1ROI     ? '$' + Number(r.y1ROI).toLocaleString()     : '—',
                statusCss:   'chip chip-' + (r.status === 'Approved'  ? 'green'
                               : r.status === 'Pending'   ? 'amber'
                               : r.status === 'Denied'    ? 'red'
                               : 'gray')
            }));
        } else if (error) {
            this.errorMsg = this._errMsg(error);
        }
    }

    // ── Snapshot getters ──────────────────────────
    get hasSnapshot()  { return this.snapshot && this.snapshot.serviceLines && this.snapshot.serviceLines.length > 0; }
    get serviceLines() { return this.snapshot ? this.snapshot.serviceLines : []; }
    get totalDemandHours() {
        return this.snapshot && this.snapshot.totalDemand != null ? this.snapshot.totalDemand : 0;
    }
    get totalCapacityHours() {
        return this.snapshot && this.snapshot.totalCapacity != null ? this.snapshot.totalCapacity : 0;
    }
    get totalUtilizationPct() {
        return this.snapshot && this.snapshot.totalUtilization != null ? this.snapshot.totalUtilization : 0;
    }
    get snapshotDate() {
        if (!this.snapshot || !this.snapshot.asOfDate) return '';
        return new Date(this.snapshot.asOfDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    // ── Hire request getters ──────────────────────
    get hasHireRequests() { return this.hireRequests.length > 0; }

    // ── ROI Calculator ────────────────────────────
    handleCalcField(evt) {
        this[evt.target.dataset.field] = evt.target.value;
    }

    async computeRoi() {
        try {
            const raw = await calculateROI({
                hoursPerWeek:   parseFloat(this.calcHoursPerWeek),
                revenuePerHour: parseFloat(this.calcRevenuePerHour),
                utilizationPct: parseFloat(this.calcUtilizationPct),
                annualCost:     parseFloat(this.calcAnnualCost),
                quantity:       parseInt(this.calcQuantity, 10)
            });
            this.roiResult = {
                ...raw,
                y1RevenueCapacityDisplay: raw.y1RevenueCapacity != null ? '$' + Number(raw.y1RevenueCapacity).toLocaleString() : '—',
                totalAnnualCostDisplay:   raw.totalAnnualCost   != null ? '$' + Number(raw.totalAnnualCost).toLocaleString()   : '—',
                roiPctDisplay:            raw.roiPct            != null ? Number(raw.roiPct).toFixed(1) + '%'                  : '—',
                y1RoiDisplay:             raw.y1ROI             != null ? '$' + Number(raw.y1ROI).toLocaleString()             : '—',
                monthsToPaybackDisplay:   raw.monthsToPayback   != null ? Number(raw.monthsToPayback).toFixed(1) + ' mo'       : '—'
            };
        } catch (e) {
            this.errorMsg = this._errMsg(e);
        }
    }

    // ── Navigation ────────────────────────────────
    handleNavToRecord(evt) {
        evt.preventDefault();
        const recordId = evt.currentTarget.dataset.recordid;
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    // ── Tab nav ───────────────────────────────────
    handleTabClick(evt) {
        this.activeTab = evt.currentTarget.dataset.tabid;
    }

    // ── Helpers ───────────────────────────────────
    _errMsg(err) {
        if (typeof err === 'string') return err;
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'Unexpected error.';
    }
}