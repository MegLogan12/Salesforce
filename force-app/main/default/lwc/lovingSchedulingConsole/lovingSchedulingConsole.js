import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getDivisions              from '@salesforce/apex/SchedulingConsoleController.getDivisions';
import getTodaySchedule          from '@salesforce/apex/SchedulingConsoleController.getTodaySchedule';
import getUnscheduledWork        from '@salesforce/apex/SchedulingConsoleController.getUnscheduledWork';
import getScheduledWork          from '@salesforce/apex/SchedulingConsoleController.getScheduledWork';
import getBlockedWork            from '@salesforce/apex/SchedulingConsoleController.getBlockedWork';
import getFieldManagerSummary    from '@salesforce/apex/SchedulingConsoleController.getFieldManagerSummary';
import getServiceTerritorySummary from '@salesforce/apex/SchedulingConsoleController.getServiceTerritorySummary';
import getServiceAppointmentSummary from '@salesforce/apex/SchedulingConsoleController.getServiceAppointmentSummary';
import getScheduleRequests       from '@salesforce/apex/SchedulingConsoleController.getScheduleRequests';
import getDataIssues             from '@salesforce/apex/SchedulingConsoleController.getDataIssues';
import getRouteAndGpsData        from '@salesforce/apex/SchedulingConsoleController.getRouteAndGpsData';
import getCrewUtilization        from '@salesforce/apex/SchedulingConsoleController.getCrewUtilization';
import getRipplingTimeOff        from '@salesforce/apex/SchedulingConsoleController.getRipplingTimeOff';
import getOvertimeRisks          from '@salesforce/apex/SchedulingConsoleController.getOvertimeRisks';
import markReadyForScheduling    from '@salesforce/apex/SchedulingConsoleController.markReadyForScheduling';
import sendToScheduling          from '@salesforce/apex/SchedulingConsoleController.sendToScheduling';
import createSchedulingRequest   from '@salesforce/apex/SchedulingConsoleController.createSchedulingRequest';
import clearWorkOrderBlocker     from '@salesforce/apex/SchedulingConsoleController.clearWorkOrderBlocker';
import refreshSchedulingConsole  from '@salesforce/apex/SchedulingConsoleController.refreshSchedulingConsole';

const DEFAULT_TERRITORY = 'Charlotte Metro';
const DEFAULT_COORDS    = { lat: 35.2271, lon: -80.8431 };

export default class LovingSchedulingConsole extends NavigationMixin(LightningElement) {

    @api pageTitle = 'Field Service Console';

    // ── State ──────────────────────────────────────────────────────────────────
    @track activeTab         = 'dashboard';
    @track territory         = 'Charlotte Metro';
    @track activeDivIdx      = 0;
    @track filterWoType      = 'All';
    @track isLoading         = false;
    @track showOptimizerModal = false;

    // Wire result holders for refreshApex
    _todayWire;
    _unscheduledWire;
    _scheduledWire;
    _blockedWire;
    _fmWire;
    _territoryWire;
    _saWire;
    _requestsWire;
    _dataIssuesWire;

    // Raw wire data
    @track _todayData;
    @track _unscheduledData = [];
    @track _scheduledData   = [];
    @track _blockedData     = [];
    @track _fmData          = [];
    @track _territoryData   = [];
    @track _saData          = [];
    @track _requestsData    = [];
    @track _dataIssuesData  = [];
    @track _gpsData         = [];
    @track _utilizationData = [];
    @track _timeOffData     = [];
    @track _otData          = [];

    // ── Date helpers ───────────────────────────────────────────────────────────
    get schedDateStr() {
        const d = new Date();
        return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
    }
    get todayDisplay() {
        return new Date().toLocaleDateString('en-US', { weekday:'long', month:'long', day:'numeric', year:'numeric' });
    }

    // ── Wires ──────────────────────────────────────────────────────────────────
    @wire(getTodaySchedule, { scheduleDate: '$schedDateStr', division: '$territory' })
    wireTodaySchedule(result) {
        this._todayWire = result;
        if (result.data) { this._todayData = result.data; }
        else if (result.error) { this._todayData = null; }
    }

    @wire(getUnscheduledWork, { division: '$territory', woType: '$filterWoType' })
    wireUnscheduled(result) {
        this._unscheduledWire = result;
        if (result.data) this._unscheduledData = result.data;
    }

    @wire(getScheduledWork, { scheduleDate: '$schedDateStr', division: '$territory' })
    wireScheduled(result) {
        this._scheduledWire = result;
        if (result.data) this._scheduledData = result.data;
    }

    @wire(getBlockedWork, { division: '$territory' })
    wireBlocked(result) {
        this._blockedWire = result;
        if (result.data) this._blockedData = result.data;
    }

    @wire(getFieldManagerSummary, { scheduleDate: '$schedDateStr', division: '$territory' })
    wireFM(result) {
        this._fmWire = result;
        if (result.data) this._fmData = result.data;
    }

    @wire(getServiceTerritorySummary, { scheduleDate: '$schedDateStr', division: '$territory' })
    wireTerritory(result) {
        this._territoryWire = result;
        if (result.data) this._territoryData = result.data;
    }

    @wire(getServiceAppointmentSummary, { scheduleDate: '$schedDateStr', division: '$territory' })
    wireSA(result) {
        this._saWire = result;
        if (result.data) this._saData = result.data;
    }

    @wire(getScheduleRequests, { division: '$territory' })
    wireRequests(result) {
        this._requestsWire = result;
        if (result.data) this._requestsData = result.data;
    }

    @wire(getDataIssues, { division: '$territory' })
    wireDataIssues(result) {
        this._dataIssuesWire = result;
        if (result.data) this._dataIssuesData = result.data;
    }

    @wire(getRouteAndGpsData, { scheduleDate: '$schedDateStr', division: '$territory' })
    wireGps(result) {
        this._gpsWire = result;
        if (result.data) this._gpsData = result.data;
    }

    @wire(getCrewUtilization, { startDate: '$schedDateStr', endDate: '$schedDateStr', division: '$territory' })
    wireUtilization(result) {
        this._utilizationWire = result;
        if (result.data) this._utilizationData = result.data;
    }

    @wire(getRipplingTimeOff, { startDate: '$schedDateStr', endDate: '$schedDateStr', division: '$territory' })
    wireTimeOff(result) {
        this._timeOffWire = result;
        if (result.data) this._timeOffData = result.data;
    }

    @wire(getOvertimeRisks, { startDate: '$schedDateStr', endDate: '$schedDateStr', division: '$territory' })
    wireOtRisks(result) {
        this._otWire = result;
        if (result.data) this._otData = result.data;
    }

    // ── Tab definitions (15 tabs) ──────────────────────────────────────────────
    get tabs() {
        const blockedCount  = (this._blockedData  || []).length;
        const issueCount    = (this._dataIssuesData || []).length;
        const requestCount  = (this._requestsData || []).length;
        const issueTotal    = blockedCount + issueCount;
        return [
            { id:'dashboard',     label:'Dashboard',        cls: this._tcls('dashboard'),                       badge: null },
            { id:'autoSchedule',  label:'Auto-Schedule',    cls: this._tcls('autoSchedule'),                    badge: null },
            { id:'scheduleIssues',label:'Schedule Issues',  cls: this._tcls('scheduleIssues', issueTotal > 0 ? 'alert' : ''), badge: issueTotal || null },
            { id:'pending',       label:'Pending',          cls: this._tcls('pending'),                         badge: requestCount || null },
            { id:'scheduleBoard', label:'Schedule Board',   cls: this._tcls('scheduleBoard'),                   badge: null },
            { id:'calendar',      label:'Calendar',         cls: this._tcls('calendar'),                        badge: null },
            { id:'gps',           label:'🛰 Route+GPS',      cls: this._tcls('gps'),                             badge: null },
            { id:'dayOf',         label:'Day-Of Monitor',   cls: this._tcls('dayOf'),                           badge: null },
            { id:'measuringCup',  label:'Measuring Cup',    cls: this._tcls('measuringCup'),                    badge: null },
            { id:'traffic',       label:'🚦 Traffic',        cls: this._tcls('traffic'),                         badge: null },
            { id:'weather',       label:'⛅ Weather',         cls: this._tcls('weather'),                         badge: null },
            { id:'overtime',      label:'⏱ Overtime',         cls: this._tcls('overtime'),                        badge: null },
            { id:'crewOpt',       label:'Crew Optimization', cls: this._tcls('crewOpt'),                         badge: null },
            { id:'draftReview',   label:'Draft Review',     cls: this._tcls('draftReview'),                     badge: null },
            { id:'decisionRules', label:'Decision Rules',   cls: this._tcls('decisionRules'),                   badge: null }
        ];
    }
    _tcls(id, extra) {
        let c = 'sf-tab';
        if (extra) c += ' ' + extra;
        if (this.activeTab === id) c += ' on';
        return c;
    }

    // ── Tab content visibility ─────────────────────────────────────────────────
    get isDashboard()     { return this.activeTab === 'dashboard'; }
    get isAutoSchedule()  { return this.activeTab === 'autoSchedule'; }
    get isScheduleIssues(){ return this.activeTab === 'scheduleIssues'; }
    get isPending()       { return this.activeTab === 'pending'; }
    get isScheduleBoard() { return this.activeTab === 'scheduleBoard'; }
    get isCalendar()      { return this.activeTab === 'calendar'; }
    get isGps()           { return this.activeTab === 'gps'; }
    get isDayOf()         { return this.activeTab === 'dayOf'; }
    get isMeasuringCup()  { return this.activeTab === 'measuringCup'; }
    get isTraffic()       { return this.activeTab === 'traffic'; }
    get isWeather()       { return this.activeTab === 'weather'; }
    get isOvertime()      { return this.activeTab === 'overtime'; }
    get isCrewOpt()       { return this.activeTab === 'crewOpt'; }
    get isDraftReview()   { return this.activeTab === 'draftReview'; }
    get isDecisionRules() { return this.activeTab === 'decisionRules'; }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.id;
    }

    // ── TODAY / DASHBOARD getters ──────────────────────────────────────────────
    get todayKpi() {
        const d = this._todayData || {};
        return {
            crewsOut:       d.crewsOut       || 0,
            stopsTotal:     d.stopsTotal     || 0,
            stopsCompleted: d.stopsCompleted || 0,
            stopsRemaining: d.stopsRemaining || 0,
            issueCount:     d.issueCount     || 0,
            readyCount:     d.readyCount     || 0
        };
    }
    get todayStops() {
        return (this._todayData ? (this._todayData.stops || []) : []).map(s => ({
            id:            s.stopId,
            woName:        s.workOrderName,
            community:     s.communityName,
            lot:           s.lotName,
            crew:          s.crewName,
            fm:            s.fmName,
            scheduledTime: s.scheduledTime || '—',
            goalHours:     s.goalHours || '—',
            statusLabel:   s.statusLabel || 'Scheduled',
            statusCls:     this._statusChip(s.statusLabel)
        }));
    }
    get hasTodayStops() { return this.todayStops.length > 0; }

    get todayFMCards() {
        return (this._fmData || []).map(fm => ({
            id:           fm.fmId,
            name:         fm.fmName,
            initials:     this._initials(fm.fmName),
            territory:    fm.territory || '—',
            openWOs:      fm.openWOs || 0,
            scheduledWOs: fm.scheduledWOs || 0,
            blockedWOs:   fm.blockedWOs || 0,
            crewsToday:   fm.crewsToday || 0,
            statusCls:    fm.hasIssue ? 'chip cr' : 'chip cg',
            statusLabel:  fm.hasIssue ? 'Action needed' : 'On track',
            blockedStyle: (fm.blockedWOs || 0) > 0 ? 'color:#c23934;font-weight:500' : ''
        }));
    }
    get hasTodayFMs() { return this.todayFMCards.length > 0; }

    // ── UNSCHEDULED getters ────────────────────────────────────────────────────
    get unscheduledRows() {
        return (this._unscheduledData || []).map(wo => ({
            id:           wo.woId,
            woName:       wo.woName,
            woType:       wo.woType || '—',
            community:    wo.communityName || '—',
            lot:          wo.lotName || '—',
            fm:           wo.fmName || '—',
            daysWaiting:  wo.daysWaiting || 0,
            daysStyle:    (wo.daysWaiting || 0) > 7 ? 'color:#c23934;font-weight:500' : ((wo.daysWaiting || 0) > 3 ? 'color:#92400e' : ''),
            readiness:    wo.readinessLabel || '—',
            readinessCls: wo.readinessReady ? 'chip cg' : 'chip ca',
            statusLabel:  wo.status || '—',
            statusCls:    this._statusChip(wo.status)
        }));
    }
    get hasUnscheduledRows() { return this.unscheduledRows.length > 0; }
    get unscheduledCount()   { return (this._unscheduledData || []).length; }

    get woTypeFilters() {
        const types = ['All', 'Production_Install', 'Warranty', 'Customer_Care', 'Finished_Job', 'Aqua_New_Install', 'Inground_Irrigation', 'Plant_Sod_Grading'];
        return types.map(t => ({
            label: t.replace(/_/g,' '), value: t,
            cls: 'div-chip' + (this.filterWoType === t ? ' on' : '')
        }));
    }
    handleWoTypeFilter(event) {
        this.filterWoType = event.currentTarget.dataset.type;
    }

    // ── SCHEDULED / SCHEDULE BOARD getters ────────────────────────────────────
    get scheduledRows() {
        return (this._scheduledData || []).map(sa => ({
            id:            sa.saId,
            saNumber:      sa.saNumber || '—',
            woName:        sa.workOrderName || '—',
            community:     sa.communityName || '—',
            territory:     sa.territory || '—',
            crew:          sa.crewName || '—',
            scheduledDate: sa.scheduledDateDisplay || '—',
            duration:      sa.durationHrs ? (sa.durationHrs + ' hrs') : '—',
            isPinned:      sa.isPinned,
            pinnedCls:     sa.isPinned ? 'chip cb2' : 'chip cgr',
            pinnedLabel:   sa.isPinned ? 'Pinned' : 'Flexible',
            statusLabel:   sa.status || '—',
            statusCls:     this._statusChip(sa.status)
        }));
    }
    get hasScheduledRows() { return this.scheduledRows.length > 0; }

    // ── BLOCKED getters ────────────────────────────────────────────────────────
    get blockedRows() {
        return (this._blockedData || []).map(wo => ({
            id:           wo.woId,
            woName:       wo.woName || '—',
            woType:       wo.woType || '—',
            community:    wo.communityName || '—',
            lot:          wo.lotName || '—',
            fm:           wo.fmName || '—',
            blockReason:  wo.blockReason || '—',
            blockedSince: wo.blockedSince || '—',
            blockCls:     wo.severity === 'High' ? 'chip cr' : 'chip ca',
            blockLabel:   wo.severity || 'Blocked'
        }));
    }
    get hasBlockedRows()     { return this.blockedRows.length > 0; }
    get blockedCount()       { return (this._blockedData || []).length; }
    get highSeverityCount()  { return (this._blockedData || []).filter(w => w.severity === 'High').length; }

    // ── FM getters ─────────────────────────────────────────────────────────────
    get fmRows() {
        return (this._fmData || []).map(fm => ({
            id:           fm.fmId,
            name:         fm.fmName,
            initials:     this._initials(fm.fmName),
            territory:    fm.territory || '—',
            openWOs:      fm.openWOs || 0,
            scheduledWOs: fm.scheduledWOs || 0,
            blockedWOs:   fm.blockedWOs || 0,
            crewsAssigned: fm.crewsAssigned || 0,
            crewsToday:   fm.crewsToday || 0,
            statusLabel:  fm.hasIssue ? 'Action needed' : 'On track',
            statusCls:    fm.hasIssue ? 'chip cr' : 'chip cg',
            blockedStyle: (fm.blockedWOs || 0) > 0 ? 'color:#c23934;font-weight:500' : ''
        }));
    }
    get hasFMRows() { return this.fmRows.length > 0; }

    // ── TERRITORY getters ──────────────────────────────────────────────────────
    get territoryRows() {
        return (this._territoryData || []).map(t => ({
            id:           t.territoryId,
            name:         t.territoryName || '—',
            division:     t.division || '—',
            capacity:     t.weeklyCapacity || '—',
            scheduledSA:  t.scheduledSACount || 0,
            openWOs:      t.openWOCount || 0,
            blockedWOs:   t.blockedWOCount || 0,
            utilizationPct: t.utilizationPct || 0,
            statusLabel:  t.isOverCapacity ? 'Over capacity' : (t.utilizationPct >= 80 ? 'Near capacity' : 'Available'),
            statusCls:    t.isOverCapacity ? 'chip cr' : (t.utilizationPct >= 80 ? 'chip ca' : 'chip cg'),
            utilizationBar: 'width:' + Math.min(t.utilizationPct || 0, 100) + '%;background:' + (t.isOverCapacity ? '#c23934' : (t.utilizationPct >= 80 ? '#fe9339' : '#2c7a4b'))
        }));
    }
    get hasTerritoryRows() { return this.territoryRows.length > 0; }

    // ── SCHEDULE REQUESTS getters ──────────────────────────────────────────────
    get requestRows() {
        return (this._requestsData || []).map(r => ({
            id:           r.requestId,
            woName:       r.workOrderName || '—',
            woType:       r.woType || '—',
            community:    r.communityName || '—',
            lot:          r.lotName || '—',
            fm:           r.fmName || '—',
            requestedDate: r.requestedDateDisplay || '—',
            notes:        r.notes || '—',
            statusLabel:  r.status || 'Pending',
            statusCls:    r.status === 'Approved' ? 'chip cg' : (r.status === 'Rejected' ? 'chip cr' : 'chip ca')
        }));
    }
    get hasRequestRows() { return this.requestRows.length > 0; }
    get requestCount()   { return (this._requestsData || []).length; }

    // ── DATA ISSUES getters ────────────────────────────────────────────────────
    get dataIssueRows() {
        return (this._dataIssuesData || []).map(i => ({
            id:           i.issueId,
            recordName:   i.recordName || '—',
            objectType:   i.objectType || '—',
            fieldName:    i.fieldName || '—',
            issueType:    i.issueType || '—',
            description:  i.description || '—',
            severity:     i.severity || 'Low',
            severityCls:  i.severity === 'High' ? 'chip cr' : (i.severity === 'Medium' ? 'chip ca' : 'chip cgr'),
            suggestedFix: i.suggestedFix || '—'
        }));
    }
    get hasDataIssueRows() { return this.dataIssueRows.length > 0; }
    get highIssueCount()   { return (this._dataIssuesData || []).filter(i => i.severity === 'High').length; }

    // ── GPS getters ────────────────────────────────────────────────────────────
    get gpsRows()  { return this._gpsData || []; }
    get gpsEmpty() { return this.gpsRows.length === 0; }

    // ── Overtime getters ───────────────────────────────────────────────────────
    get otRows()           { return this._otData || []; }
    get otEmpty()          { return this.otRows.length === 0; }
    get utilizationRows()  { return this._utilizationData || []; }
    get utilizationEmpty() { return this.utilizationRows.length === 0; }
    get timeOffRows()      { return this._timeOffData || []; }
    get timeOffEmpty()     { return this.timeOffRows.length === 0; }

    // ── Banner KPI chip classes ────────────────────────────────────────────────
    get blockedBannerCls() { return 'sc-bk' + (this.blockedCount  > 0 ? ' sc-bk-alert' : ''); }
    get requestBannerCls() { return 'sc-bk' + (this.requestCount  > 0 ? ' sc-bk-warn'  : ''); }

    // ── Map URLs ───────────────────────────────────────────────────────────────
    get _coords() {
        const match = this._divisions.find(d => d.label === this.territory);
        if (match && match.latitude != null && match.longitude != null) {
            return { lat: match.latitude, lon: match.longitude };
        }
        return DEFAULT_COORDS;
    }
    get weatherMapUrl() {
        const c = this._coords;
        return 'https://embed.windy.com/embed2.html?lat=' + c.lat + '&lon=' + c.lon +
               '&zoom=9&level=surface&overlay=rain&menu=&message=true&marker=&calendar=now' +
               '&pressure=&type=map&location=coordinates&detail=&metricWind=mph&metricTemp=%C2%B0F&radarRange=-1';
    }
    get trafficMapUrl() {
        const c = this._coords;
        return 'https://embed.waze.com/iframe?zoom=12&lat=' + c.lat + '&lon=' + c.lon + '&ct=livemap&pin=0';
    }

    // ── Division / filter chips ────────────────────────────────────────────────
    @track _divisions = [];

    @wire(getDivisions)
    wiredDivisions({ data }) {
        if (data) this._divisions = data;
    }

    get divisionChips() {
        return this._divisions.map((d, i) => ({
            label: d.label,
            value: d.value,
            cls: 'div-chip' + (i === this.activeDivIdx ? ' on' : '')
        }));
    }
    handleDivChip(event) {
        const val = event.currentTarget.dataset.div;
        this.activeDivIdx = this._divisions.findIndex(d => d.value === val);
        if (this.activeDivIdx < 0) this.activeDivIdx = 0;
        if (val === 'All') {
            this.territory = DEFAULT_TERRITORY;
        } else {
            const match = this._divisions.find(d => d.value === val);
            this.territory = match ? match.label : val;
        }
    }

    // ── Optimizer modal ────────────────────────────────────────────────────────
    handleRunOptimizer() {
        this.showOptimizerModal = true;
    }
    handleDraftPreview() {
        this.activeTab = 'draftReview';
    }
    handleCloseOptimizerModal() {
        this.showOptimizerModal = false;
    }
    handleOptimizerBackdrop(event) {
        if (event.target === event.currentTarget) this.showOptimizerModal = false;
    }
    handleModalStopProp(event) {
        event.stopPropagation();
    }
    handleConfirmOptimizer() {
        this.showOptimizerModal = false;
        this._toast('FSL Optimizer', 'Optimizer run queued — results will appear in Schedule Board', 'info');
        this.activeTab = 'scheduleBoard';
    }

    // ── Calendar navigation ────────────────────────────────────────────────────
    handleOpenCalendar() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Calendar' }
        });
    }

    // ── FSL actions ───────────────────────────────────────────────────────────
    handleMarkReady(event) {
        const woId = event.currentTarget.dataset.id;
        this.isLoading = true;
        markReadyForScheduling({ woId })
            .then(() => {
                this._toast('Updated', 'Work Order moved to Takeoff Complete', 'success');
                return refreshApex(this._unscheduledWire);
            })
            .catch(err => this._toast('Error', err.body ? err.body.message : 'Update failed', 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleSendToScheduling(event) {
        const woId = event.currentTarget.dataset.id;
        this.isLoading = true;
        sendToScheduling({ woId })
            .then(() => {
                this._toast('Sent to Scheduling', 'Work Order sent to FSL scheduling queue', 'success');
                return Promise.all([refreshApex(this._unscheduledWire), refreshApex(this._saWire)]);
            })
            .catch(err => this._toast('Error', err.body ? err.body.message : 'Send failed', 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleClearBlocker(event) {
        const woId = event.currentTarget.dataset.id;
        this.isLoading = true;
        clearWorkOrderBlocker({ woId })
            .then(() => {
                this._toast('Blocker Cleared', 'Work Order blocker cleared', 'success');
                return Promise.all([refreshApex(this._blockedWire), refreshApex(this._unscheduledWire)]);
            })
            .catch(err => this._toast('Error', err.body ? err.body.message : 'Clear failed', 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleApproveRequest(event) {
        const requestId = event.currentTarget.dataset.id;
        this.isLoading = true;
        createSchedulingRequest({ requestId, action: 'Approve' })
            .then(() => {
                this._toast('Approved', 'Schedule request approved', 'success');
                return refreshApex(this._requestsWire);
            })
            .catch(err => this._toast('Error', err.body ? err.body.message : 'Approve failed', 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleRejectRequest(event) {
        const requestId = event.currentTarget.dataset.id;
        this.isLoading = true;
        createSchedulingRequest({ requestId, action: 'Reject' })
            .then(() => {
                this._toast('Rejected', 'Schedule request rejected', 'warning');
                return refreshApex(this._requestsWire);
            })
            .catch(err => this._toast('Error', err.body ? err.body.message : 'Reject failed', 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleRefreshAll() {
        this.isLoading = true;
        refreshSchedulingConsole()
            .then(() => Promise.all([
                refreshApex(this._todayWire),
                refreshApex(this._unscheduledWire),
                refreshApex(this._scheduledWire),
                refreshApex(this._blockedWire),
                refreshApex(this._fmWire),
                refreshApex(this._territoryWire),
                refreshApex(this._saWire),
                refreshApex(this._requestsWire),
                refreshApex(this._dataIssuesWire)
            ]))
            .then(() => this._toast('Refreshed', 'Console data refreshed', 'success'))
            .catch(() => this._toast('Partial refresh', 'Some data may not have updated', 'warning'))
            .finally(() => { this.isLoading = false; });
    }

    handleNavigateWO(event) {
        const woId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: woId, actionName: 'view' }
        });
    }

    handleNavigateSA(event) {
        const saId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: saId, actionName: 'view' }
        });
    }

    // ── Helpers ────────────────────────────────────────────────────────────────
    _statusChip(status) {
        if (!status) return 'chip cgr';
        const s = status.toLowerCase().replace(/ /g,'_');
        if (s.includes('complete') || s.includes('closed') || s.includes('approved')) return 'chip cg';
        if (s.includes('progress') || s.includes('active') || s.includes('scheduled')) return 'chip cb2';
        if (s.includes('blocked') || s.includes('failed') || s.includes('error')) return 'chip cr';
        if (s.includes('pending') || s.includes('waiting') || s.includes('hold')) return 'chip ca';
        return 'chip cgr';
    }
    _initials(name) {
        if (!name) return '??';
        const parts = name.split(' ');
        return (parts[0].charAt(0) + (parts.length > 1 ? parts[parts.length-1].charAt(0) : '')).toUpperCase();
    }
    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
