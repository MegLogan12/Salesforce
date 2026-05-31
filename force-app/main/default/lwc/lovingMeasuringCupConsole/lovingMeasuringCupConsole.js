import { LightningElement, wire, track, api } from 'lwc';
import getActiveToday    from '@salesforce/apex/MeasuringCupController.getActiveToday';
import getKpis           from '@salesforce/apex/MeasuringCupController.getKpis';
import getSchedulingKpis from '@salesforce/apex/SchedulingController.getSchedulingKpis';

const TABS = [
    { id: 'liveCrews',  label: 'Live Crews',   icon: '👥' },
    { id: 'dailyKpis',  label: "Today's KPIs",  icon: '📊' },
    { id: 'pipeline',   label: 'Pipeline',      icon: '🗓️' }
];

export default class LovingMeasuringCupConsole extends LightningElement {

    @api pageTitle = 'Measuring Cup';

    @track activeTab = 'liveCrews';
    @track errorMsg  = null;

    @track kpiData   = null;
    @track crews     = [];
    @track schedData = {};

    // ── Tabs ─────────────────────────────────────
    get tabs() {
        return TABS.map(t => ({
            ...t,
            css: 'tab-btn' + (t.id === this.activeTab ? ' active' : '')
        }));
    }

    get tabLiveCrews()  { return this.activeTab === 'liveCrews'; }
    get tabDailyKpis()  { return this.activeTab === 'dailyKpis'; }
    get tabPipeline()   { return this.activeTab === 'pipeline'; }

    // ── Wire ─────────────────────────────────────
    @wire(getActiveToday)
    wiredCrews({ data, error }) {
        if (data) {
            this.crews = data.map(c => ({
                ...c,
                goalDisplay:     c.goalHours   != null ? Number(c.goalHours).toFixed(1)   : '—',
                actualDisplay:   c.actualHours != null ? Number(c.actualHours).toFixed(1) : '—',
                varianceDisplay: c.varianceHours != null
                    ? (c.varianceHours >= 0 ? '+' : '') + Number(c.varianceHours).toFixed(1)
                    : '—',
                isNegative: c.varianceHours != null && c.varianceHours < 0,
                statusCss:  'chip chip-' + (c.status === 'On Track' ? 'green'
                              : c.status === 'Ahead'     ? 'blue'
                              : c.status === 'Behind'    ? 'amber'
                              : 'gray')
            }));
        } else if (error) {
            this.errorMsg = this._errMsg(error);
        }
    }

    @wire(getKpis)
    wiredKpis({ data, error }) {
        if (data) this.kpiData = data;
        else if (error) this.errorMsg = this._errMsg(error);
    }

    @wire(getSchedulingKpis)
    wiredSchedKpis({ data, error }) {
        if (data) this.schedData = data;
        else if (error) this.errorMsg = this._errMsg(error);
    }

    // ── KPI getters ───────────────────────────────
    get activeCrews()    { return this.kpiData ? (this.kpiData.activeCrews         || 0) : '—'; }
    get bonusEligible()  { return this.kpiData ? (this.kpiData.bonusEligibleCount  || 0) : '—'; }
    get goalHoursDisplay() {
        if (!this.kpiData || this.kpiData.totalGoalHoursToday == null) return '—';
        return Number(this.kpiData.totalGoalHoursToday).toFixed(1) + 'h';
    }
    get actualHoursDisplay() {
        if (!this.kpiData || this.kpiData.totalActualHoursToday == null) return '—';
        return Number(this.kpiData.totalActualHoursToday).toFixed(1) + 'h';
    }
    get varianceDisplay() {
        if (!this.kpiData || this.kpiData.totalVarianceHoursToday == null) return '—';
        const v = this.kpiData.totalVarianceHoursToday;
        return (v >= 0 ? '+' : '') + Number(v).toFixed(1) + 'h';
    }
    get isVarianceNegative() {
        return this.kpiData && this.kpiData.totalVarianceHoursToday != null
            && this.kpiData.totalVarianceHoursToday < 0;
    }
    get utilizationDisplay() {
        if (!this.kpiData) return '—';
        const g = this.kpiData.totalGoalHoursToday;
        const a = this.kpiData.totalActualHoursToday;
        if (!g || g === 0) return '—';
        return Math.round((a / g) * 100) + '%';
    }

    // ── Scheduling getters ────────────────────────
    get schedLockedToday()            { return this.schedData.lockedToday          || 0; }
    get schedPendingProposals()       { return this.schedData.pendingProposals      || 0; }
    get schedCtsQueue()               { return this.schedData.ctsQueue             || 0; }
    get schedThirtyDay()              { return this.schedData.thirtyDayPipeline    || 0; }
    get schedSiteReadinessOverdue()   { return this.schedData.siteReadinessOverdue || 0; }
    get schedOpenPullTickets()        { return this.schedData.openPullTickets      || 0; }

    // ── hasXxx ────────────────────────────────────
    get hasCrews() { return this.crews.length > 0; }
    get crewRows() { return this.crews; }

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