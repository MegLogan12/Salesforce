import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getCooKpis       from '@salesforce/apex/LovingCooController.getCooKpis';
import getWoPipeline    from '@salesforce/apex/LovingCooController.getWoPipeline';
import getGpSummary     from '@salesforce/apex/LovingCooController.getGpSummary';
import getAquaSummary   from '@salesforce/apex/LovingCooController.getAquaSummary';
import getSchedulingKpis         from '@salesforce/apex/SchedulingController.getSchedulingKpis';
import getOpenHireRequests        from '@salesforce/apex/HomeDashboardController.getOpenHireRequests';
import getThisWeekOneOnOnes       from '@salesforce/apex/HomeDashboardController.getThisWeekOneOnOnes';
import getScorecards              from '@salesforce/apex/FMScorecardController.getScorecards';

const TABS = [
    { id: 'overview',     label: 'Overview',       icon: '📊' },
    { id: 'workOrders',   label: 'Work Orders',     icon: '📋' },
    { id: 'scheduling',   label: 'Scheduling',      icon: '📅' },
    { id: 'finance',      label: 'Finance / GP',    icon: '💰' },
    { id: 'quality',      label: 'Quality',         icon: '⭐' },
    { id: 'customerCare', label: 'Customer Care',   icon: '📞' },
    { id: 'people',       label: 'People',          icon: '👥' },
    { id: 'aqua',         label: 'Aqua',            icon: '💧' }
];

export default class LovingCooConsole extends NavigationMixin(LightningElement) {

    @api pageTitle = 'LOVING Operations';

    @track activeTab  = 'overview';
    @track isLoading  = false;
    @track errorMsg   = null;

    // Raw data
    @track kpis         = {};
    @track woPipeline   = [];
    @track gpData       = {};
    @track aquaData     = {};
    @track schedKpis    = {};
    @track hireRequests = [];
    @track oneOnOnes    = [];
    @track scorecards   = [];

    // ── Tab list ─────────────────────────────────
    get tabs() {
        return TABS.map(t => ({
            ...t,
            css: 'tab-btn' + (t.id === this.activeTab ? ' active' : '')
        }));
    }

    // ── Tab booleans ─────────────────────────────
    get tabOverview()     { return this.activeTab === 'overview'; }
    get tabWorkOrders()   { return this.activeTab === 'workOrders'; }
    get tabScheduling()   { return this.activeTab === 'scheduling'; }
    get tabFinance()      { return this.activeTab === 'finance'; }
    get tabQuality()      { return this.activeTab === 'quality'; }
    get tabCustomerCare() { return this.activeTab === 'customerCare'; }
    get tabPeople()       { return this.activeTab === 'people'; }
    get tabAqua()         { return this.activeTab === 'aqua'; }

    // ── WIRE ─────────────────────────────────────
    @wire(getCooKpis)
    wiredKpis({ data, error }) {
        if (data) this.kpis = data;
        else if (error) this.errorMsg = this._errMsg(error);
    }

    @wire(getWoPipeline)
    wiredWoPipeline({ data, error }) {
        if (data) this.woPipeline = data;
        else if (error) this.errorMsg = this._errMsg(error);
    }

    @wire(getGpSummary)
    wiredGp({ data, error }) {
        if (data) this.gpData = data;
        else if (error) this.errorMsg = this._errMsg(error);
    }

    @wire(getAquaSummary)
    wiredAqua({ data, error }) {
        if (data) this.aquaData = data;
        else if (error) this.errorMsg = this._errMsg(error);
    }

    @wire(getSchedulingKpis)
    wiredSchedKpis({ data, error }) {
        if (data) this.schedKpis = data;
        else if (error) this.errorMsg = this._errMsg(error);
    }

    @wire(getOpenHireRequests)
    wiredHireRequests({ data, error }) {
        if (data) this.hireRequests = data.map(r => ({
            ...r,
            costDisplay: r.totalCost ? '$' + Number(r.totalCost).toLocaleString() : '—',
            roiDisplay:  r.y1ROI    ? '$' + Number(r.y1ROI).toLocaleString()    : '—'
        }));
        else if (error) this.errorMsg = this._errMsg(error);
    }

    @wire(getThisWeekOneOnOnes)
    wiredOneOnOnes({ data, error }) {
        if (data) this.oneOnOnes = data.map(o => ({
            ...o,
            dateDisplay: o.meetingDate ? this._fmtDatetime(o.meetingDate) : '—'
        }));
        else if (error) this.errorMsg = this._errMsg(error);
    }

    @wire(getScorecards)
    wiredScorecards({ data, error }) {
        if (data) this.scorecards = data.map(r => ({
            ...r,
            qiAvgDisplay:  r.qiAverage   != null ? Number(r.qiAverage).toFixed(1)  : '—',
            lastQiDisplay: r.lastQiScore != null ? Number(r.lastQiScore).toFixed(1) : '—',
            fjPctDisplay:  r.fjPercent   != null ? Number(r.fjPercent).toFixed(0) + '%' : '—',
            avatarStyle:   'background:' + (r.avatarColor || '#4f46e5')
        }));
        else if (error) this.errorMsg = this._errMsg(error);
    }

    // ── Tab nav ───────────────────────────────────
    handleTabClick(evt) {
        this.activeTab = evt.currentTarget.dataset.tabid;
    }

    // ── KPI getters ───────────────────────────────
    get kpiActiveWOs()             { return this.kpis.activeWOs            || 0; }
    get kpiScheduledToday()        { return this.kpis.scheduledToday       || 0; }
    get kpiPendingProposals()      { return this.kpis.pendingProposals      || 0; }
    get kpiPendingCloseout()       { return this.kpis.pendingCloseout       || 0; }
    get kpiPaidThisMonth()         { return this.kpis.paidThisMonth         || 0; }
    get kpiOpenEscalations()       { return this.kpis.openEscalations       || 0; }
    get kpiOpenHireRequests()      { return this.kpis.openHireRequests      || 0; }
    get kpiSiteReadinessOverdue()  { return this.kpis.siteReadinessOverdue  || 0; }

    // ── Scheduling KPI getters ────────────────────
    get schedKpiPendingProposals()     { return this.schedKpis.pendingProposals    || 0; }
    get schedKpiCtsQueue()             { return this.schedKpis.ctsQueue            || 0; }
    get schedKpiLockedToday()          { return this.schedKpis.lockedToday         || 0; }
    get schedKpiActiveCrews()          { return this.schedKpis.activeCrews         || 0; }
    get schedKpiSiteReadinessOverdue() { return this.schedKpis.siteReadinessOverdue || 0; }
    get schedKpiOpenPullTickets()      { return this.schedKpis.openPullTickets     || 0; }
    get schedKpiOpenLoadingTickets()   { return this.schedKpis.openLoadingTickets  || 0; }
    get schedKpiThirtyDay()            { return this.schedKpis.thirtyDayPipeline   || 0; }

    // ── GP getters ────────────────────────────────
    get gpGreenCount()    { return this.gpData.greenCount   || 0; }
    get gpYellowCount()   { return this.gpData.yellowCount  || 0; }
    get gpRedCount()      { return this.gpData.redCount     || 0; }
    get gpBlockedCount()  { return this.gpData.blockedCount || 0; }
    get gpRevenueDisplay() {
        const rev = this.gpData.totalRevenuePending;
        if (!rev) return '$0';
        return '$' + Number(rev).toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
    }

    // ── Aqua getters ──────────────────────────────
    get aquaUpcomingInstalls() { return this.aquaData.upcomingInstalls  || 0; }
    get aquaUpcomingChecks()   { return this.aquaData.upcomingChecks    || 0; }
    get aquaOpenPickups()      { return this.aquaData.openPickupTickets || 0; }

    // ── hasXxx ────────────────────────────────────
    get hasWoPipeline()    { return this.woPipeline.length  > 0; }
    get hasScorecards()    { return this.scorecards.length  > 0; }
    get hasHireRequests()  { return this.hireRequests.length > 0; }
    get hasOneOnOnes()     { return this.oneOnOnes.length   > 0; }

    get headerSubtitle() {
        const active = this.kpiActiveWOs || 0;
        const scheduled = this.kpiScheduledToday || 0;
        const closeout = this.kpiPendingCloseout || 0;
        const escalations = this.kpiOpenEscalations || 0;
        if (active === 0 && scheduled === 0 && closeout === 0 && escalations === 0) {
            return 'Live operations summary unavailable';
        }
        return `Active ${active} · Scheduled ${scheduled} · Closeout ${closeout} · Escalations ${escalations}`;
    }

    get qualitySubtitle() {
        if (!this.hasScorecards) {
            return 'Live FM scorecard data unavailable';
        }
        return `${this.scorecards.length} FM scorecards in scope`;
    }

    get customerCareSubtitle() {
        const pending = this.kpiPendingProposals || 0;
        const escalations = this.kpiOpenEscalations || 0;
        if (pending === 0 && escalations === 0) {
            return 'Live Customer Success summary unavailable';
        }
        return `Pending proposals ${pending} · Escalations ${escalations}`;
    }

    get customerCareBanner() {
        const pending = this.kpiPendingProposals || 0;
        const escalations = this.kpiOpenEscalations || 0;
        if (pending === 0 && escalations === 0) {
            return 'Customer Success queue summary';
        }
        return `${pending} pending proposals · ${escalations} escalations`;
    }

    get customerCareDetail() {
        const pending = this.kpiPendingProposals || 0;
        const escalations = this.kpiOpenEscalations || 0;
        if (pending === 0 && escalations === 0) {
            return 'Live Customer Success queue detail is unavailable in this summary view.';
        }
        return `${pending} pending proposals and ${escalations} escalations are currently in scope.`;
    }

    // ── Navigation ────────────────────────────────
    handleNavToRecord(evt) {
        const recordId = evt.currentTarget.dataset.recordid;
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    // ── Helpers ───────────────────────────────────
    _fmtDatetime(dt) {
        if (!dt) return '—';
        const d = new Date(dt);
        return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
    }

    _errMsg(err) {
        if (typeof err === 'string') return err;
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'Unexpected error.';
    }
}