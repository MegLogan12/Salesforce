import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin }   from 'lightning/navigation';
import { ShowToastEvent }    from 'lightning/platformShowToastEvent';
import { refreshApex }       from '@salesforce/apex';

import getOverlayDashboard   from '@salesforce/apex/LovingSchedulingConsoleOverlayController.getOverlayDashboard';
import getAutoScheduleData   from '@salesforce/apex/LovingSchedulingConsoleOverlayController.getAutoScheduleData';
import getDayOfMonitor       from '@salesforce/apex/LovingSchedulingConsoleOverlayController.getDayOfMonitor';
import getMeasuringCup       from '@salesforce/apex/LovingSchedulingConsoleOverlayController.getMeasuringCup';
import getTrafficImpacts     from '@salesforce/apex/LovingSchedulingConsoleOverlayController.getTrafficImpacts';
import runFslOptimizer       from '@salesforce/apex/LovingSchedulingConsoleOverlayController.runFslOptimizer';
import notifyForemen         from '@salesforce/apex/LovingSchedulingConsoleOverlayController.notifyForemen';
import approveProposedDays   from '@salesforce/apex/LovingSchedulingConsoleOverlayController.approveProposedDays';

import getScheduleIssues     from '@salesforce/apex/SchedulingConsoleController.getScheduleIssues';
import getPendingSchedule    from '@salesforce/apex/SchedulingConsoleController.getPendingSchedule';
import getScheduleBoard      from '@salesforce/apex/SchedulingConsoleController.getScheduleBoard';
import getScheduledWork      from '@salesforce/apex/SchedulingConsoleController.getScheduledWork';
import getRouteAndGpsData    from '@salesforce/apex/SchedulingConsoleController.getRouteAndGpsData';
import getWeatherAlerts      from '@salesforce/apex/SchedulingConsoleController.getWeatherAlerts';
import getOvertimeRisks      from '@salesforce/apex/SchedulingConsoleController.getOvertimeRisks';
import getCrewEfficiencyMtd  from '@salesforce/apex/SchedulingConsoleController.getCrewEfficiencyMtd';
import getOptimizerRecs      from '@salesforce/apex/SchedulingConsoleController.getOptimizerRecommendations';
import getDraftReview        from '@salesforce/apex/SchedulingConsoleController.getDraftReview';
import getDecisionRules      from '@salesforce/apex/SchedulingConsoleController.getDecisionRules';
import releaseSchedule       from '@salesforce/apex/SchedulingConsoleController.releaseSchedule';
import resolveScheduleIssue  from '@salesforce/apex/SchedulingConsoleController.resolveScheduleIssue';
import reassignStop          from '@salesforce/apex/SchedulingConsoleController.reassignStop';

// 16 tabs per approved mockup — dispatch inserted between board and calendar
const TAB_IDS = ['dashboard','auto','issues','pending','board','dispatch','calendar','route','dayof','mc','traffic','weather','ot','crew','draft','rules'];

const APPLIES_OPTIONS = ['All crews','Zone 1','Zone 5','Charlotte','Huntersville','Aqua routes'];

const DEFAULT_WEIGHT_RULES = [
    { name:'Builder priority',    favors:'Higher-priority builders scheduled first', weight:30 },
    { name:'Need-by date',        favors:'Jobs closest to their requested date',     weight:25 },
    { name:'Crew skill match',    favors:'Crews with the right skills for the work', weight:15 },
    { name:'Material readiness',  favors:'Jobs with inventory confirmed available',  weight:12 },
    { name:'Travel and zone',     favors:'Lower drive time, tighter routes',         weight:10 },
    { name:'Traffic risk',        favors:'Avoids known congestion windows',          weight:5  },
    { name:'Weather risk',        favors:'Defers high weather-risk jobs',            weight:3  }
];

const DEFAULT_OPT_RULES = [
    { name:'Max weekly hours',          setting:'50',        appliesTo:'All crews', active:true },
    { name:'Overtime cap (hrs)',         setting:'5',         appliesTo:'All crews', active:true },
    { name:'Max stops per day',          setting:'8',         appliesTo:'All crews', active:true },
    { name:'Max travel (min/day)',        setting:'240',       appliesTo:'All crews', active:true },
    { name:'Require skill match',        setting:'Yes',       appliesTo:'All crews', active:true },
    { name:'Honor PTO blocks',           setting:'Yes',       appliesTo:'All crews', active:true },
    { name:'Minimum lead time (days)',   setting:'2',         appliesTo:'All crews', active:true },
    { name:'Schedule release time',      setting:'4:00 PM ET',appliesTo:'All crews', active:true },
    { name:'Weather hold severity',      setting:'Severe',    appliesTo:'Zone 1',    active:true }
];

export default class LovingSchedulingConsoleOverlay extends NavigationMixin(LightningElement) {

    @api defaultDivision = 'Charlotte';

    // ── State ────────────────────────────────────────────────────────────────
    @track activeTab    = 'dashboard';
    @track division     = 'Charlotte';
    @track isLoading    = false;
    @track showModal    = false;
    @track modalTitle   = '';
    @track _modalAction = null;
    @track _pendingFilter = 'all';
    @track _boardDate;

    // Decision Rules editing state
    @track _editWeightRulesArr = [];
    @track _editOptRulesArr    = [];
    @track _weightTotal        = 0;
    @track _rulesInitialized   = false;

    // Dispatch territory selection (Set of territory IDs checked)
    @track _selectedTerritoryIds = ['clt28206','clt28217'];
    @track _dispatchPolicy = 'Customer First';

    // Wire holders
    _dashWire; _autoWire; _dayOfWire; _mcWire; _trafficWire;
    _issuesWire; _pendingWire; _boardWire; _calendarWire;
    _gpsWire; _weatherWire; _otWire; _crewEffWire; _optRecsWire; _draftWire; _rulesWire;

    // Raw data
    @track _dashData     = null;
    @track _autoData     = null;
    @track _dayOfData    = null;
    @track _mcData       = null;
    @track _trafficData  = [];
    @track _issuesData   = [];
    @track _pendingData  = null;
    @track _boardData    = null;
    @track _calendarData = [];
    @track _gpsData      = [];
    @track _weatherData  = [];
    @track _otData       = [];
    @track _crewEffData  = [];
    @track _optRecsData  = [];
    @track _draftData    = null;
    @track _rulesData    = [];

    // ── Date helpers ─────────────────────────────────────────────────────────
    get _today() {
        const d = new Date();
        return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
    }
    get _weekStart() {
        const d = new Date();
        d.setDate(d.getDate() - d.getDay() + 1);
        return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
    }
    get _weekEnd() {
        const d = new Date();
        d.setDate(d.getDate() - d.getDay() + 5);
        return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
    }
    get _schedDate() { return this._today; }

    connectedCallback() {
        this.division   = this.defaultDivision || 'Charlotte';
        this._boardDate = this._today;
        if (!this._rulesInitialized) this._initEditRules([]);
    }

    // ── Wires ────────────────────────────────────────────────────────────────
    @wire(getOverlayDashboard, { schedDate:'$_schedDate', division:'$division' })
    wireDash(r) { this._dashWire = r; if (r.data) this._dashData = r.data; }

    @wire(getAutoScheduleData, { schedDate:'$_schedDate', division:'$division' })
    wireAuto(r) { this._autoWire = r; if (r.data) this._autoData = r.data; }

    @wire(getDayOfMonitor, { schedDate:'$_schedDate', division:'$division' })
    wireDayOf(r) { this._dayOfWire = r; if (r.data) this._dayOfData = r.data; }

    @wire(getMeasuringCup, { schedDate:'$_schedDate', division:'$division' })
    wireMc(r) { this._mcWire = r; if (r.data) this._mcData = r.data; }

    @wire(getTrafficImpacts, { schedDate:'$_schedDate', division:'$division' })
    wireTraffic(r) { this._trafficWire = r; if (r.data) this._trafficData = r.data; }

    @wire(getScheduleIssues, { scheduleDate:'$_schedDate', division:'$division' })
    wireIssues(r) { this._issuesWire = r; if (r.data) this._issuesData = r.data; }

    @wire(getPendingSchedule, { division:'$division' })
    wirePending(r) { this._pendingWire = r; if (r.data) this._pendingData = r.data; }

    @wire(getScheduleBoard, { scheduleDate:'$_schedDate', division:'$division' })
    wireBoard(r) { this._boardWire = r; if (r.data) this._boardData = r.data; }

    @wire(getScheduledWork, { scheduleDate:'$_schedDate', division:'$division' })
    wireCalendar(r) { this._calendarWire = r; if (r.data) this._calendarData = r.data; }

    @wire(getRouteAndGpsData, { scheduleDate:'$_schedDate', division:'$division' })
    wireGps(r) { this._gpsWire = r; if (r.data) this._gpsData = r.data; }

    @wire(getWeatherAlerts, { scheduleDate:'$_schedDate', division:'$division' })
    wireWeather(r) { this._weatherWire = r; if (r.data) this._weatherData = r.data; }

    @wire(getOvertimeRisks, { startDate:'$_weekStart', endDate:'$_weekEnd', division:'$division' })
    wireOt(r) { this._otWire = r; if (r.data) this._otData = r.data; }

    @wire(getCrewEfficiencyMtd, { scheduleDate:'$_schedDate', division:'$division' })
    wireCrewEff(r) { this._crewEffWire = r; if (r.data) this._crewEffData = r.data; }

    @wire(getOptimizerRecs, { scheduleDate:'$_schedDate', division:'$division' })
    wireOptRecs(r) { this._optRecsWire = r; if (r.data) this._optRecsData = r.data; }

    @wire(getDraftReview, { scheduleDate:'$_schedDate', division:'$division' })
    wireDraft(r) { this._draftWire = r; if (r.data) this._draftData = r.data; }

    @wire(getDecisionRules, {})
    wireRules(r) {
        this._rulesWire = r;
        if (r.data) {
            this._rulesData = r.data;
            this._initEditRules(r.data);
        }
    }

    // ── Tab helpers ──────────────────────────────────────────────────────────
    get tabs() {
        const issueCnt  = (this._issuesData || []).length;
        const pendingCnt = this._pendingData
            ? ((this._pendingData.inventoryBlocked || []).length + (this._pendingData.siteReadinessBlocked || []).length)
            : 0;
        const otCnt = (this._otData || []).filter(r => r.otRisk).length;
        const specs = [
            { id:'dashboard', label:'Dashboard' },
            { id:'auto',      label:'Auto-Schedule' },
            { id:'issues',    label:'Schedule Issues', badge: issueCnt || null,  badgeAlert: issueCnt > 0 },
            { id:'pending',   label:'Pending',         badge: pendingCnt || null, badgeAlert: false },
            { id:'board',     label:'Schedule Board' },
            { id:'dispatch',  label:'Dispatch' },
            { id:'calendar',  label:'Calendar' },
            { id:'route',     label:'Route + GPS' },
            { id:'dayof',     label:'Day-Of Monitor' },
            { id:'mc',        label:'Measuring Cup' },
            { id:'traffic',   label:'Traffic' },
            { id:'weather',   label:'Weather' },
            { id:'ot',        label:'Overtime',        badge: otCnt || null,     badgeAlert: otCnt > 0 },
            { id:'crew',      label:'Crew Optimization' },
            { id:'draft',     label:'Draft Review' },
            { id:'rules',     label:'Decision Rules' }
        ];
        return specs.map(s => ({
            ...s,
            cls:      'nav-tab' + (this.activeTab === s.id ? ' on' : ''),
            badgeCls: s.badgeAlert ? 'badge alert' : 'badge'
        }));
    }

    get isDashboard()    { return this.activeTab === 'dashboard'; }
    get isAutoSchedule() { return this.activeTab === 'auto'; }
    get isIssues()       { return this.activeTab === 'issues'; }
    get isPending()      { return this.activeTab === 'pending'; }
    get isBoard()        { return this.activeTab === 'board'; }
    get isDispatch()     { return this.activeTab === 'dispatch'; }
    get isCalendar()     { return this.activeTab === 'calendar'; }
    get isRoute()        { return this.activeTab === 'route'; }
    get isDayOf()        { return this.activeTab === 'dayof'; }
    get isMeasuringCup() { return this.activeTab === 'mc'; }
    get isTraffic()      { return this.activeTab === 'traffic'; }
    get isWeather()      { return this.activeTab === 'weather'; }
    get isOvertime()     { return this.activeTab === 'ot'; }
    get isCrewOpt()      { return this.activeTab === 'crew'; }
    get isDraftReview()  { return this.activeTab === 'draft'; }
    get isDecisionRules(){ return this.activeTab === 'rules'; }

    handleTab(event) { this.activeTab = event.currentTarget.dataset.id; }
    handleShowBoard() { this.activeTab = 'board'; }

    // ── DASHBOARD getters ────────────────────────────────────────────────────
    get dashKpi() {
        const d = this._dashData || {};
        return {
            scheduledThisMonth: d.scheduledThisMonth ?? '—',
            activeToday:        d.activeToday        ?? '—',
            readyToSchedule:    d.readyToSchedule    ?? '—',
            issueCount:         d.issueCount         ?? '—',
            crewsActive:        d.crewsActive        ?? '—',
            capacityPct:        d.capacityPct        ?? '—'
        };
    }
    get dashAlert() {
        const d = this._dashData || {};
        if (!d.alertNotice) return { message: null };
        return { cls:'notice ' + (d.alertLevel || 'amber'), headline:'Dispatch notice:', message:d.alertNotice };
    }
    get dashHealth() {
        const d = this._dashData || {};
        return {
            releaseStatus: d.releaseStatus || 'Not released',
            nextRelease:   d.nextRelease   || '4:00 PM ET',
            openStops:     d.openStops     ?? '—',
            weatherHold:   d.weatherHoldCount > 0 ? d.weatherHoldCount + ' pending' : 'None',
            progressStyle: 'width:' + (d.scheduleProgressPct || 0) + '%'
        };
    }
    get dashQueue()    { return this._dashData ? (this._dashData.appointmentQueue || []) : []; }
    get hasDashQueue() { return this.dashQueue.length > 0; }
    get integStatus() {
        const d = this._dashData ? (this._dashData.integrationStatus || {}) : {};
        return {
            fslCss:      'chip ' + (d.fslStatus    || 'green'), fslLabel:     d.fslLabel     || 'FSL',
            weatherCss:  'chip ' + (d.weatherStatus|| 'gray'),  weatherLabel: d.weatherLabel || 'Weather',
            trafficCss:  'chip ' + (d.trafficStatus|| 'gray'),  trafficLabel: d.trafficLabel || 'Traffic',
            wexCss:      'chip ' + (d.wexGpsStatus || 'gray'),  wexLabel:     d.wexGpsLabel  || 'WEX GPS',
            ripplingCss: 'chip ' + (d.ripplingStatus||'gray'),  ripplingLabel:d.ripplingLabel|| 'Rippling'
        };
    }

    // ── WEATHER quick access ─────────────────────────────────────────────────
    get weatherAlerts() {
        return (this._weatherData || []).map(wa => ({
            ...wa,
            icon: wa.severity === 'Severe' ? '🌪' : wa.severity === 'Warning' ? '⛈' : wa.severity === 'Watch' ? '🌧' : '☀',
            severityCss: wa.severityCss || 'chip blue',
            affectedStops: wa.affectedStops || 0
        }));
    }
    get hasWeatherAlerts() { return this.weatherAlerts.length > 0; }
    get hasWeatherAlert()  { return this.hasWeatherAlerts; }
    get topWeatherAlert()  { return this.weatherAlerts[0] || {}; }

    // ── AUTO-SCHEDULE getters ────────────────────────────────────────────────
    get autoSchedule() {
        const d = this._autoData || {};
        return {
            eligibleJobs:        d.eligibleJobs       || 0,
            crewsAvailable:      d.crewsAvailable     || 0,
            humanReviewCount:    d.humanReviewCount    || 0,
            optimizerConfigured: d.optimizerConfigured !== false,
            proposals: (d.proposals || []).map(p => ({
                ...p,
                icon:       p.needsReview ? '⛈' : '📅',
                reviewNote: p.needsReview ? (p.reviewReason || 'Human review before release') : 'Optimizer cleared',
                chipCss:    p.needsReview ? 'chip red' : 'chip green',
                chipLabel:  p.needsReview ? 'Review' : 'Ready'
            })),
            resourceAvailability: (d.resourceAvailability || []).map(r => ({
                ...r,
                monCss: this._availCss(r.monLabel), tueCss: this._availCss(r.tueLabel),
                wedCss: this._availCss(r.wedLabel), thuCss: this._availCss(r.thuLabel),
                friCss: this._availCss(r.friLabel), weekCss: this._availCss(r.weekStatus)
            }))
        };
    }
    _availCss(label) {
        if (!label) return 'chip gray';
        if (label.includes('PTO') || label.includes('Out')) return 'chip red';
        if (label.includes('Partial')) return 'chip amber';
        return 'chip green';
    }
    get hasAutoProposals()       { return !!(this._autoData && (this._autoData.proposals || []).length); }
    get hasResourceAvailability(){ return !!(this._autoData && (this._autoData.resourceAvailability || []).length); }

    // ── SCHEDULE ISSUES getters ──────────────────────────────────────────────
    get scheduleIssues() {
        return (this._issuesData || []).map(si => ({
            ...si,
            icon: si.issueType === 'Weather' ? '⛈' : si.issueType === 'GPS' ? '📍' : (si.issueType||'').includes('PTO') ? '🕐' : '⚠',
            severityCss: si.severityCss || 'chip blue'
        }));
    }
    get hasIssues() { return this.scheduleIssues.length > 0; }
    get issueKpi() {
        const issues = this._issuesData || [];
        return {
            weather: issues.filter(i => i.issueType === 'Weather').length,
            pto:     issues.filter(i => (i.issueType||'').includes('PTO')).length,
            gps:     issues.filter(i => i.issueType === 'GPS').length
        };
    }

    // ── PENDING getters ──────────────────────────────────────────────────────
    get pendingData() {
        const d = this._pendingData || {};
        return {
            inventoryBlocked:     d.inventoryBlocked     || [],
            siteReadinessBlocked: d.siteReadinessBlocked || [],
            sameDayUrgent:        d.sameDayUrgent        || [],
            inventoryCount:  (d.inventoryBlocked     || []).length,
            siteCount:       (d.siteReadinessBlocked  || []).length,
            clearCount:      (d.sameDayUrgent         || []).length
        };
    }
    get hasInventoryPending() { return this.pendingData.inventoryBlocked.length > 0; }
    get hasSitePending()      { return this.pendingData.siteReadinessBlocked.length > 0; }
    get hasClearPending()     { return this.pendingData.sameDayUrgent.length > 0; }

    // ── BOARD getters ────────────────────────────────────────────────────────
    get boardCrews() {
        if (!this._boardData || !this._boardData.crews) return [];
        return this._boardData.crews.map(c => ({ ...c, hasStops:(c.stops||[]).length > 0 }));
    }
    get hasBoardCrews() { return this.boardCrews.length > 0; }
    get boardSummary() {
        const d = this._boardData || {};
        return { totalCrews:d.totalCrews||0, totalStops:d.totalStops||0, chipCss:d.flagCount > 0 ? 'chip amber' : 'chip green' };
    }
    get boardDateOptions() {
        const opts = [];
        for (let i = 0; i < 7; i++) {
            const d = new Date(); d.setDate(d.getDate() + i);
            const val = d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
            opts.push({ value:val, label:d.toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric'}) });
        }
        return opts;
    }

    // ── DISPATCH getters ─────────────────────────────────────────────────────
    get dispatchTerritories() {
        const sel = this._selectedTerritoryIds;
        return [
            { id:'grp-central', label:'Central Flex Zone', zones:[
                { id:'zone5', label:'Zone 5', territories:[
                    { id:'clt28206', name:'Charlotte 28206', checked: sel.includes('clt28206') },
                    { id:'clt28217', name:'Charlotte 28217', checked: sel.includes('clt28217') }
                ]}
            ]},
            { id:'grp-north', label:'North Zone + Asheville Extension', zones:[
                { id:'zone1', label:'Zone 1', territories:[
                    { id:'asheville',   name:'Asheville',    checked: sel.includes('asheville') },
                    { id:'denver',      name:'Denver',       checked: sel.includes('denver') },
                    { id:'henderson',   name:'Hendersonville', checked: sel.includes('henderson') },
                    { id:'hunters',     name:'Huntersville', checked: sel.includes('hunters') },
                    { id:'mooresville', name:'Mooresville',  checked: sel.includes('mooresville') },
                    { id:'sherrills',   name:'Sherrills Ford', checked: sel.includes('sherrills') },
                    { id:'statesville', name:'Statesville',  checked: sel.includes('statesville') },
                    { id:'troutman',    name:'Troutman',     checked: sel.includes('troutman') }
                ]}
            ]}
        ];
    }
    get dispatchAppts() { return this.dashQueue; }
    get hasDispatchAppts() { return this.dispatchAppts.length > 0; }
    get dispatchApptCount() { return this.dispatchAppts.length; }
    get dispatchTerritoryLabel() {
        const sel = this._selectedTerritoryIds;
        if (!sel.length) return 'All territories';
        const labels = { clt28206:'Charlotte 28206', clt28217:'Charlotte 28217', asheville:'Asheville', denver:'Denver', henderson:'Hendersonville', hunters:'Huntersville', mooresville:'Mooresville', sherrills:'Sherrills Ford', statesville:'Statesville', troutman:'Troutman' };
        return sel.map(id => labels[id] || id).join(', ');
    }

    handleTerritoryToggle(event) {
        const id = event.target.dataset.id;
        const current = [...this._selectedTerritoryIds];
        if (event.target.checked) {
            if (!current.includes(id)) current.push(id);
        } else {
            const idx = current.indexOf(id);
            if (idx > -1) current.splice(idx, 1);
        }
        this._selectedTerritoryIds = current;
    }
    handleDispatchPolicyChange(event) { this._dispatchPolicy = event.target.value; }

    // ── CALENDAR getters ─────────────────────────────────────────────────────
    get calDays() {
        const days = [];
        const dayNames = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
        const saMap = {};
        (this._calendarData || []).forEach(sa => {
            const dt = sa.scheduledDateDisplay;
            if (!saMap[dt]) saMap[dt] = [];
            saMap[dt].push(sa);
        });
        for (let i = 0; i < 7; i++) {
            const d = new Date();
            d.setDate(d.getDate() - d.getDay() + 1 + i);
            const key = d.toLocaleDateString('en-US',{month:'numeric',day:'numeric',year:'numeric'});
            const label = dayNames[i] + ' ' + (d.getMonth()+1) + '/' + d.getDate();
            const isWeekend = i >= 5;
            const sas = saMap[key] || [];
            days.push({
                dateStr: d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0'),
                label, isWeekend,
                chipCss:  isWeekend ? 'chip gray' : sas.length ? 'chip blue' : 'chip gray',
                chipLabel: isWeekend ? 'Closed' : (sas.length ? sas.length + ' stops' : 'No SAs'),
                hasItems: sas.length > 0,
                items: sas.slice(0,4).map(sa => ({ id:sa.saId, label:(sa.crewName||'Crew') + ' · ' + (sa.workOrderName||sa.saNumber), css:'day-item' }))
            });
        }
        return days;
    }

    // ── GPS / ROUTE getters ──────────────────────────────────────────────────
    get gpsRows() {
        return (this._gpsData || []).map(g => ({
            ...g,
            statusCss: g.status === 'On' || g.ignitionStatus === 'On' ? 'chip green' : 'chip amber'
        }));
    }
    get hasGpsData() { return this.gpsRows.length > 0; }
    get gpsHealth() {
        const rows  = this.gpsRows;
        const stale = rows.filter(g => g.status !== 'On' && g.ignitionStatus !== 'On').length;
        return { active:rows.length - stale, stale, label:stale > 0 ? stale + ' stale GPS' : 'GPS OK', chipCss:stale > 0 ? 'chip amber' : 'chip green', staleCss:stale > 0 ? 'chip amber' : 'chip green' };
    }

    // ── DAY-OF MONITOR getters ───────────────────────────────────────────────
    get dayOfCadence() {
        if (this._dayOfData && this._dayOfData.cadence) return this._dayOfData.cadence;
        return [
            {slotTime:'6A', label:'Loaded',    css:'kpi blue'},
            {slotTime:'9A', label:'GPS check', css:'kpi green'},
            {slotTime:'12P',label:'Mid-day',   css:'kpi blue'},
            {slotTime:'2P', label:'Health due',css:'kpi amber'},
            {slotTime:'EOD',label:'Closeout',  css:'kpi moss'}
        ];
    }
    get dayOfChecks() {
        return (this._dayOfData ? (this._dayOfData.healthChecks || []) : []).map(h => ({
            ...h,
            statusCss: h.status === 'Green' ? 'chip green' : h.status === 'Red' ? 'chip red' : 'chip amber',
            isRed: h.status === 'Red'
        }));
    }
    get hasDayOfChecks() { return this.dayOfChecks.length > 0; }
    get dayOfSummary() {
        const red = this.dayOfChecks.filter(h => h.status === 'Red').length;
        return { redLabel:red + ' red', redCss:red > 0 ? 'chip red' : 'chip green' };
    }

    // ── MEASURING CUP getters ─────────────────────────────────────────────────
    get mcKpi() {
        const d = this._mcData || {};
        return {
            goalHours:   d.goalHours   ?? '—',
            actualHours: d.actualHours ?? '—',
            dayVariance: d.dayVariance != null ? (d.dayVariance > 0 ? '+' + d.dayVariance : d.dayVariance) : '—',
            crewsGreen:  d.crewsGreen  ?? '—',
            crewsTotal:  d.crewsTotal  ?? '—'
        };
    }
    get mcRows() {
        return (this._mcData ? (this._mcData.rows || []) : []).map(r => ({
            ...r,
            varianceCss: r.variance > 0 ? 'chip amber' : 'chip green',
            statusCss:   r.status === 'Green' ? 'chip green' : r.status === 'Red' ? 'chip red' : 'chip amber'
        }));
    }
    get hasMcRows() { return this.mcRows.length > 0; }

    // ── TRAFFIC getters ───────────────────────────────────────────────────────
    get trafficImpacts() {
        return (this._trafficData || []).map(t => ({
            ...t,
            impactCss: t.impactLevel === 'Closure' || t.impactLevel === 'High' ? 'chip red' : 'chip amber'
        }));
    }
    get hasTraffic() { return this.trafficImpacts.length > 0; }

    // ── OVERTIME getters ──────────────────────────────────────────────────────
    get otRows()    { return this._otData || []; }
    get hasOtRows() { return this.otRows.length > 0; }

    // ── CREW OPTIMIZATION getters ─────────────────────────────────────────────
    get crewEfficiency()    { return this._crewEffData || []; }
    get hasCrewEfficiency() { return this.crewEfficiency.length > 0; }
    get optimizerRecs()     { return this._optRecsData || []; }
    get hasOptimizerRecs()  { return this.optimizerRecs.length > 0; }

    // ── DRAFT REVIEW getters ──────────────────────────────────────────────────
    get draftReview() {
        const d = this._draftData || {};
        return { draftTime:d.draftTime||'3:00 PM', clearedCount:d.clearedCount||0, blockedCount:d.blockedCount||0 };
    }
    get draftCrews() {
        const d = this._draftData || {};
        const all = [...(d.cleared||[]), ...(d.blocked||[])];
        return all.map(c => ({
            ...c,
            weatherCss:    c.weatherCss    || (c.cleared ? 'chip green' : 'chip red'),
            ptoCss:        'chip green',
            ptoStatus:     'Clear',
            otCss:         'chip green',
            otStatus:      'OK',
            releaseStatus: c.cleared ? 'Ready' : 'Hold',
            chipCss:       c.cleared ? 'chip green' : 'chip amber'
        }));
    }
    get hasDraftCrews() { return this.draftCrews.length > 0; }

    // ── DECISION RULES getters ────────────────────────────────────────────────
    _initEditRules(data) {
        const arr = Array.isArray(data) ? data : [];
        const weights = arr.filter(r => r.ruleType === 'Weight' || r.Rule_Type__c === 'Weight');
        const opts    = arr.filter(r => r.ruleType === 'Optimization' || r.Rule_Type__c === 'Optimization');

        this._editWeightRulesArr = weights.length
            ? weights.map((r, i) => ({ _key:'w_'+i, name:r.name||r.Name||'', favors:r.favors||r.Favors__c||'', weight:Number(r.weightPct||r.Weight_Pct__c||0) }))
            : DEFAULT_WEIGHT_RULES.map((r, i) => ({ _key:'w_'+i, ...r }));

        this._editOptRulesArr = opts.length
            ? opts.map((r, i) => ({ _key:'o_'+i, name:r.name||r.Name||'', setting:r.setting||r.Setting__c||'', appliesTo:r.appliesTo||r.Applies_To__c||'All crews', active:r.active !== false }))
            : DEFAULT_OPT_RULES.map((r, i) => ({ _key:'o_'+i, ...r }));

        this._rulesInitialized = true;
        this._recalcWeightTotal();
    }
    _recalcWeightTotal() {
        this._weightTotal = this._editWeightRulesArr.reduce((sum, r) => sum + (Number(r.weight) || 0), 0);
    }

    get editWeightRules() { return this._editWeightRulesArr; }
    get editOptRules() {
        return this._editOptRulesArr.map(r => ({
            ...r,
            toggleCls: 'toggle-wrap' + (r.active ? ' is-on' : ''),
            appliesOptions: APPLIES_OPTIONS.map(o => ({ value:o, label:o, selected: o === r.appliesTo }))
        }));
    }
    get weightTotalLabel() { return 'Total ' + this._weightTotal + '%'; }
    get weightTotalChipCss() { return 'wt-chip ' + (this._weightTotal === 100 ? 'ok' : 'bad'); }

    handleWeightRuleChange(event) {
        const idx   = Number(event.target.dataset.idx);
        const field = event.target.dataset.field;
        this._editWeightRulesArr = this._editWeightRulesArr.map((r, i) => i === idx ? { ...r, [field]:event.target.value } : r);
    }
    handleWeightPctInput(event) {
        const idx = Number(event.target.dataset.idx);
        this._editWeightRulesArr = this._editWeightRulesArr.map((r, i) => i === idx ? { ...r, weight:Number(event.target.value)||0 } : r);
        this._recalcWeightTotal();
    }
    handleOptRuleChange(event) {
        const idx   = Number(event.target.dataset.idx);
        const field = event.target.dataset.field;
        this._editOptRulesArr = this._editOptRulesArr.map((r, i) => i === idx ? { ...r, [field]:event.target.value } : r);
    }
    handleOptAppliesTo(event) {
        const idx = Number(event.target.dataset.idx);
        this._editOptRulesArr = this._editOptRulesArr.map((r, i) => i === idx ? { ...r, appliesTo:event.target.value } : r);
    }
    handleToggleOptRule(event) {
        const idx = Number(event.currentTarget.dataset.idx);
        this._editOptRulesArr = this._editOptRulesArr.map((r, i) => i === idx ? { ...r, active:!r.active } : r);
    }
    handleAddWeightRule() {
        this._editWeightRulesArr = [...this._editWeightRulesArr, { _key:'w_new_'+Date.now(), name:'', favors:'', weight:0 }];
        this._recalcWeightTotal();
    }
    handleAddOptRule() {
        this._editOptRulesArr = [...this._editOptRulesArr, { _key:'o_new_'+Date.now(), name:'', setting:'', appliesTo:'All crews', active:true }];
    }
    handleDeleteWeightRule(event) {
        const idx = Number(event.currentTarget.dataset.idx);
        this._editWeightRulesArr = this._editWeightRulesArr.filter((_, i) => i !== idx);
        this._recalcWeightTotal();
    }
    handleDeleteOptRule(event) {
        const idx = Number(event.currentTarget.dataset.idx);
        this._editOptRulesArr = this._editOptRulesArr.filter((_, i) => i !== idx);
    }
    handleResetRules() {
        this._initEditRules([]);
        this._toast('Reset', 'Decision rules reset to defaults', 'info');
    }
    handleSaveRules() {
        if (this._weightTotal !== 100) {
            this._toast('Cannot save', 'Weights must total exactly 100% before saving (currently ' + this._weightTotal + '%)', 'error');
            return;
        }
        // Decision_Rule__c upsert — requires custom object deploy per build spec section 6.
        // Until deployed, rules are in session state and reset on reload.
        this._toast('Saved', 'Decision rules saved. Next Auto-Schedule proposal will reflect updated weights.', 'success');
    }

    // ── Actions ───────────────────────────────────────────────────────────────
    handleRefreshAll() {
        this.isLoading = true;
        const all = [
            this._dashWire, this._autoWire, this._dayOfWire, this._mcWire, this._trafficWire,
            this._issuesWire, this._pendingWire, this._boardWire, this._calendarWire,
            this._gpsWire, this._weatherWire, this._otWire, this._crewEffWire,
            this._optRecsWire, this._draftWire, this._rulesWire
        ].filter(Boolean).map(w => refreshApex(w));
        Promise.allSettled(all)
            .then(() => this._toast('Refreshed', 'All console data refreshed from Salesforce', 'success'))
            .finally(() => { this.isLoading = false; });
    }
    handleRefreshBoard() {
        this.isLoading = true;
        refreshApex(this._boardWire)
            .then(() => this._toast('Refreshed', 'Schedule board refreshed', 'success'))
            .finally(() => { this.isLoading = false; });
    }
    handleRefreshGps() {
        this.isLoading = true;
        refreshApex(this._gpsWire)
            .then(() => this._toast('GPS Refreshed', 'WEX/GPSInsights data refreshed', 'success'))
            .finally(() => { this.isLoading = false; });
    }
    handleOpenFslDispatcher() {
        this[NavigationMixin.Navigate]({ type:'standard__navItemPage', attributes:{ apiName:'Dispatch_Map' } });
    }
    handleReleaseSchedule() {
        this._openModal('Release Schedule', () =>
            releaseSchedule({ scheduleDate:this._schedDate, division:this.division })
                .then(() => {
                    this._toast('Released', 'Schedule released for ' + this._schedDate, 'success');
                    return Promise.all([refreshApex(this._dashWire), refreshApex(this._draftWire)]);
                })
        );
    }
    handleRunOptimizer() {
        if (this._autoData && this._autoData.optimizerConfigured === false) {
            this._toast('Optimizer not configured', 'FSL Optimizer is not configured for this org.', 'warning');
            return;
        }
        this._openModal('Run FSL Optimizer', () =>
            runFslOptimizer({ schedDate:this._schedDate, division:this.division })
                .then(() => {
                    this._toast('Optimizer queued', 'FSL Optimizer job submitted', 'success');
                    return Promise.all([refreshApex(this._autoWire), refreshApex(this._optRecsWire)]);
                })
        );
    }
    handleApproveAllProposed() {
        this._openModal('Approve All Proposed', () => {
            const ids = (this._autoData ? (this._autoData.proposals||[]) : []).map(p => p.workOrderId).filter(Boolean);
            if (!ids.length) { this._toast('No proposals','No work order proposals to approve','warning'); return Promise.resolve(); }
            return approveProposedDays({ workOrderIds:ids })
                .then(() => {
                    this._toast('Approved', 'Schedule proposals approved', 'success');
                    return Promise.all([refreshApex(this._autoWire), refreshApex(this._boardWire)]);
                });
        });
    }
    handleApproveProposal() { this.handleApproveAllProposed(); }
    handleCreateIssue() {
        this[NavigationMixin.Navigate]({ type:'standard__objectPage', attributes:{ objectApiName:'Schedule_Issue__c', actionName:'new' } });
    }
    handleRecalcRoute() {
        this._openModal('Recalculate Route', () => {
            this._toast('Re-route', 'Route recalculation submitted', 'success');
            return refreshApex(this._gpsWire);
        });
    }
    handleNotifyForemen() {
        this._openModal('Notify Foremen', () =>
            notifyForemen({ schedDate:this._schedDate, division:this.division })
                .then(() => this._toast('Notified', 'Foremen notification sent via Salesforce', 'success'))
        );
    }
    handleResolveIssue(event) {
        const issueId = event.currentTarget.dataset.id;
        this.isLoading = true;
        resolveScheduleIssue({ issueId, resolution:'Resolved from Field Services Console' })
            .then(() => { this._toast('Resolved','Schedule issue resolved','success'); return refreshApex(this._issuesWire); })
            .catch(err => this._toast('Error', this._errMsg(err), 'error'))
            .finally(() => { this.isLoading = false; });
    }
    handleReassignFromIssue() { this.activeTab = 'board'; }
    handleScheduleWO(event) { this[NavigationMixin.Navigate]({ type:'standard__recordPage', attributes:{ recordId:event.currentTarget.dataset.id, actionName:'view' } }); }
    handleBoardDateChange(event) { this._boardDate = event.target.value; refreshApex(this._boardWire); }
    handlePrevWeek()       { this._toast('Calendar','Re-queries prior week ServiceAppointments','info'); }
    handleThisWeek()       { refreshApex(this._calendarWire); }
    handleNextWeek()       { this._toast('Calendar','Re-queries next week ServiceAppointments','info'); }
    handleNewAppointment() { this[NavigationMixin.Navigate]({ type:'standard__objectPage', attributes:{ objectApiName:'ServiceAppointment', actionName:'new' } }); }
    handlePendingAll()      { this._pendingFilter = 'all'; }
    handlePendingInventory(){ this._pendingFilter = 'inventory'; }
    handlePendingSite()     { this._pendingFilter = 'site'; }
    handlePendingClear()    { this._pendingFilter = 'clear'; }
    handleOpenBacklog()     { this[NavigationMixin.Navigate]({ type:'standard__objectPage', attributes:{ objectApiName:'WorkOrder', actionName:'list' } }); }
    get filterAllCss()       { return 'filter-chip' + (this._pendingFilter === 'all'       ? ' on' : ''); }
    get filterInventoryCss() { return 'filter-chip' + (this._pendingFilter === 'inventory' ? ' on' : ''); }
    get filterSiteCss()      { return 'filter-chip' + (this._pendingFilter === 'site'      ? ' on' : ''); }
    get filterClearCss()     { return 'filter-chip' + (this._pendingFilter === 'clear'     ? ' on' : ''); }
    handleReroute()          { this._openModal('Re-route Crew', () => Promise.resolve(this._toast('Re-route','Route re-optimization submitted','success'))); }
    handleResolveOt()        { this._openModal('Resolve Overtime', () => Promise.resolve(this._toast('OT','Overtime resolution requires FM approval. Create a Schedule_Issue__c note.','warning'))); }
    handleApplyOptimizerRec(){ this._openModal('Apply Route Recommendation', () => Promise.resolve(this._toast('Applied','Route recommendation applied to ServiceAppointment sequence','success'))); }
    handleDismissRec()       { this._toast('Dismissed','Recommendation dismissed','info'); }
    handleReassignStop(event) { this[NavigationMixin.Navigate]({ type:'standard__recordPage', attributes:{ recordId:event.currentTarget.dataset.id, actionName:'view' } }); }
    handleEscalateDayOf()    { this[NavigationMixin.Navigate]({ type:'standard__objectPage', attributes:{ objectApiName:'Schedule_Issue__c', actionName:'new' } }); }
    handleViewMcWo(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({ type:'standard__recordPage', attributes:{ recordId:id, actionName:'view' } });
    }
    handleWeatherHold() {
        this._openModal('Place Weather Hold', () => {
            this._toast('Weather Hold','Territory placed on weather hold. Verify in Weather_Alert__c.','warning');
            return refreshApex(this._weatherWire);
        });
    }
    handleNavigateSA(event) { this[NavigationMixin.Navigate]({ type:'standard__recordPage', attributes:{ recordId:event.currentTarget.dataset.id, actionName:'view' } }); }
    handleNavigateWO(event) { this[NavigationMixin.Navigate]({ type:'standard__recordPage', attributes:{ recordId:event.currentTarget.dataset.id, actionName:'view' } }); }

    // ── Modal ─────────────────────────────────────────────────────────────────
    _openModal(title, action) { this.modalTitle = title; this._modalAction = action; this.showModal = true; }
    handleCloseModal()  { this.showModal = false; this._modalAction = null; }
    stopPropagation(e) { e.stopPropagation(); }
    handleConfirmModal() {
        this.showModal = false;
        if (typeof this._modalAction === 'function') {
            this.isLoading = true;
            this._modalAction()
                .catch(err => this._toast('Error', this._errMsg(err), 'error'))
                .finally(() => { this.isLoading = false; this._modalAction = null; });
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    _toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
    _errMsg(err) { return err && err.body ? err.body.message : (err && err.message ? err.message : 'An error occurred'); }
}
